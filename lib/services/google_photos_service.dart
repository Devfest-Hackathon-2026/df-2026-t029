import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../repositories/auth_repository.dart';

/// Google フォトとの連携の失敗の種類（文言は `googlePhotosErrorMessage` が決める）
enum GooglePhotosFailure {
  cancelled,
  popupBlocked,
  accountMismatch,
  accountInUse,
  noToken,
  apiUnavailable,
  timeout,
  noneSelected,
  network,
  other,
}

/// 文言を持たない。[email] は accountMismatch の文言に使う。
/// トークン・URL・写真の中身は持たない（[toString] にもメールを出さない）
class GooglePhotosException implements Exception {
  const GooglePhotosException(this.kind, {this.email});

  final GooglePhotosFailure kind;
  final String? email;

  @override
  String toString() => 'GooglePhotosException(${kind.name})';
}

/// Picker API のセッション
class PickerSession {
  const PickerSession({
    required this.id,
    required this.pickerUri,
    required this.pollInterval,
    required this.timeoutAt,
    required this.mediaItemsSet,
  });

  final String id;
  final Uri pickerUri;

  /// 次に確かめるまでの間隔。無ければ 5 秒
  final Duration pollInterval;

  /// 選ぶ時間の期限（取得した時刻 + timeoutIn）
  final DateTime timeoutAt;
  final bool mediaItemsSet;
}

/// 利用者が選んだ写真1枚。[baseUrl] はトークンと同じく、ログ・例外・画面に出さない
class PickedItem {
  const PickedItem({
    required this.id,
    required this.baseUrl,
    required this.mimeType,
    this.createTime,
    this.width,
    this.height,
  });

  final String id;
  final String baseUrl;
  final String mimeType;
  final DateTime? createTime;
  final int? width, height;
}

/// 画面・状態はこの抽象だけに依存する（テストは偽物に差し替える）
abstract class GooglePhotosApi {
  /// このタブで権限（トークン）を持っているか
  bool get hasToken;

  /// ポップアップで権限を求める（カレンダーの `_accessToken()` と同じ分岐）。
  /// **つなぐボタンの処理の中で、最初に呼ぶ**。失敗は [GooglePhotosException]
  Future<void> authorize();

  Future<PickerSession> createSession({int maxItemCount = 30});

  Future<PickerSession> getSession(String sessionId);

  /// 全ページ。動画は除く。30 枚まで
  Future<List<PickedItem>> listPickedItems(String sessionId);

  /// baseUrl に `=w{maxSide}-h{maxSide}` を付け、Authorization つきで取る
  Future<Uint8List> fetchImage(PickedItem item, {required int maxSide});

  /// 失敗しても例外を投げない
  Future<void> deleteSession(String sessionId);
}

/// 選べる候補の最大枚数（`maxPickCandidates` と同じ値。utils に依存しないよう複製）
const _maxItems = 30;

/// ページを辿る回数の上限（無限ループの防止）
const _maxPages = 10;

/// 1回の通信の待ち時間の上限
const _requestTimeout = Duration(seconds: 30);

/// Google フォト（Picker API）との連携。認可はカレンダー
/// （`google_calendar_service.dart`）と同じ作りの書き写し
class GooglePhotosService implements GooglePhotosApi {
  GooglePhotosService(
    this._auth, {
    http.Client? client,
    Future<String> Function()? tokenForTest,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _testToken = tokenForTest,
       _clock = clock ?? DateTime.now;

  final FirebaseAuth _auth;
  final http.Client _client;
  final Future<String> Function()? _testToken;
  final DateTime Function() _clock;

  static const _scope =
      'https://www.googleapis.com/auth/photospicker.mediaitems.readonly';
  static const _baseUrl = 'https://photospicker.googleapis.com/v1';

  // トークンはメモリーだけに持つ（保存しない）。ログ・例外・画面に出さない
  String? _token;
  DateTime? _tokenExpiresAt;

  @override
  bool get hasToken {
    final expiresAt = _tokenExpiresAt;
    return _token != null && expiresAt != null && _clock().isBefore(expiresAt);
  }

  void _clearToken() {
    _token = null;
    _tokenExpiresAt = null;
  }

  void _setToken(String token) {
    _token = token;
    // アクセストークンの有効期限は約1時間。余裕を見て50分で取り直す
    _tokenExpiresAt = _clock().add(const Duration(minutes: 50));
  }

  @override
  Future<void> authorize() async {
    if (hasToken) return;

    final forTest = _testToken;
    if (forTest != null) {
      try {
        _setToken(await forTest());
      } catch (_) {
        throw const GooglePhotosException(GooglePhotosFailure.noToken);
      }
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw const GooglePhotosException(GooglePhotosFailure.noToken);
    }

    final hasGoogle = user.providerData.any(
      (p) => p.providerId == 'google.com',
    );

    UserCredential result;
    try {
      if (hasGoogle) {
        final provider = GoogleAuthProvider()
          ..addScope(_scope)
          // ポップアップで、ログイン中のアカウントを最初から選んだ状態にする
          ..setCustomParameters({
            if (user.email != null) 'login_hint': user.email!,
          });
        try {
          result = await user.reauthenticateWithPopup(provider);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-mismatch') {
            throw GooglePhotosException(
              GooglePhotosFailure.accountMismatch,
              email: user.email,
            );
          }
          rethrow;
        }
      } else {
        // メールで登録した人: 初めて使うときに Google アカウントをつなぐ
        final provider = GoogleAuthProvider()..addScope(_scope);
        try {
          result = await user.linkWithPopup(provider);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use') {
            throw const GooglePhotosException(GooglePhotosFailure.accountInUse);
          }
          if (e.code == 'provider-already-linked') {
            result = await user.reauthenticateWithPopup(provider);
          } else {
            rethrow;
          }
        }
      }
    } on GooglePhotosException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw GooglePhotosException(switch (e.code) {
        'popup-closed-by-user' ||
        'cancelled-popup-request' => GooglePhotosFailure.cancelled,
        'popup-blocked' => GooglePhotosFailure.popupBlocked,
        'user-mismatch' => GooglePhotosFailure.accountMismatch,
        'credential-already-in-use' ||
        'email-already-in-use' => GooglePhotosFailure.accountInUse,
        'network-request-failed' => GooglePhotosFailure.network,
        _ => GooglePhotosFailure.other,
      }, email: e.code == 'user-mismatch' ? user.email : null);
    } catch (_) {
      throw const GooglePhotosException(GooglePhotosFailure.other);
    }

    final newToken = result.credential?.accessToken;
    if (newToken == null) {
      throw const GooglePhotosException(GooglePhotosFailure.noToken);
    }
    _setToken(newToken);
  }

  // ---- 通信 ----

  Map<String, String> _headers() {
    final token = _token;
    if (token == null) {
      throw const GooglePhotosException(GooglePhotosFailure.noToken);
    }
    return {'Authorization': 'Bearer $token'};
  }

  /// 通信を行い、200 以外と通信の失敗を [GooglePhotosException] にする。
  /// 応答の本文・URL・トークンは例外に入れない
  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) call,
  ) async {
    final headers = _headers();
    http.Response res;
    try {
      res = await call(headers).timeout(_requestTimeout);
    } on GooglePhotosException {
      rethrow;
    } catch (_) {
      // 通信の失敗（接続できない・時間切れなど）。中身は残さない
      throw const GooglePhotosException(GooglePhotosFailure.network);
    }
    final code = res.statusCode;
    if (code >= 200 && code < 300) return res;
    if (code == 401) {
      _clearToken();
      throw const GooglePhotosException(GooglePhotosFailure.noToken);
    }
    if (code == 403 || code == 404) {
      throw const GooglePhotosException(GooglePhotosFailure.apiUnavailable);
    }
    throw const GooglePhotosException(GooglePhotosFailure.other);
  }

  Map<String, dynamic> _jsonMap(http.Response res) {
    try {
      final v = jsonDecode(utf8.decode(res.bodyBytes));
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    throw const GooglePhotosException(GooglePhotosFailure.other);
  }

  @override
  Future<PickerSession> createSession({int maxItemCount = 30}) async {
    final res = await _send(
      (h) => _client.post(
        Uri.parse('$_baseUrl/sessions'),
        headers: {...h, 'Content-Type': 'application/json'},
        // 要確認(G0): maxItemCount は文字列で渡す形（公式の例）。上限の値も G0 で確かめる
        body: jsonEncode({
          'pickingConfig': {'maxItemCount': '$maxItemCount'},
        }),
      ),
    );
    return _parseSession(_jsonMap(res));
  }

  @override
  Future<PickerSession> getSession(String sessionId) async {
    final res = await _send(
      (h) => _client.get(
        Uri.parse('$_baseUrl/sessions/${Uri.encodeComponent(sessionId)}'),
        headers: h,
      ),
    );
    return _parseSession(_jsonMap(res));
  }

  PickerSession _parseSession(Map<String, dynamic> json) {
    final id = json['id'];
    final uri = json['pickerUri'] is String
        ? Uri.tryParse(json['pickerUri'] as String)
        : null;
    // 選び終わったあと（mediaItemsSet が true）の応答には pickerUri・pollingConfig が
    // 入らないことがある。選び終わったあとは pickerUri を使わないので、
    // そのときだけ pickerUri が無くても読む（作成直後は必須のまま）
    final picked = json['mediaItemsSet'] == true;
    if (id is! String || id.isEmpty || (uri == null && !picked)) {
      throw const GooglePhotosException(GooglePhotosFailure.other);
    }
    // 要確認(G0): pollingConfig の入れ子と、"5s" の形
    final polling = json['pollingConfig'];
    final pollingMap = polling is Map ? polling : const {};
    var interval =
        _parseDuration(pollingMap['pollInterval']) ??
        _parseDuration(json['pollInterval']) ??
        const Duration(seconds: 5);
    if (interval <= Duration.zero) interval = const Duration(seconds: 5);
    final timeoutIn =
        _parseDuration(pollingMap['timeoutIn']) ??
        _parseDuration(json['timeoutIn']) ??
        const Duration(minutes: 30);
    return PickerSession(
      id: id,
      pickerUri: uri ?? Uri(),
      pollInterval: interval,
      timeoutAt: _clock().add(timeoutIn),
      mediaItemsSet: picked,
    );
  }

  /// "5s"・"1.5s"・数（秒）を Duration にする。読めなければ null
  Duration? _parseDuration(Object? v) {
    num? seconds;
    if (v is num) {
      seconds = v;
    } else if (v is String) {
      final m = RegExp(r'^\s*([0-9]+(?:\.[0-9]+)?)\s*s?\s*$').firstMatch(v);
      if (m != null) seconds = double.parse(m.group(1)!);
    }
    if (seconds == null) return null;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  @override
  Future<List<PickedItem>> listPickedItems(String sessionId) async {
    final items = <PickedItem>[];
    String? pageToken;
    for (var page = 0; page < _maxPages; page++) {
      final res = await _send(
        (h) => _client.get(
          Uri.parse('$_baseUrl/mediaItems').replace(
            queryParameters: {
              'sessionId': sessionId,
              'pageSize': '100',
              'pageToken': ?pageToken,
            },
          ),
          headers: h,
        ),
      );
      final json = _jsonMap(res);
      final list = json['mediaItems'];
      if (list is List) {
        for (final raw in list) {
          final item = _parseItem(raw);
          if (item != null) items.add(item);
          if (items.length >= _maxItems) return items;
        }
      }
      final next = json['nextPageToken'];
      if (next is! String || next.isEmpty) break;
      pageToken = next;
    }
    return items;
  }

  /// 要確認(G0): JSON の入れ子の形。`mediaFile.baseUrl` と `baseUrl` の
  /// どちらでも読めるようにしている。動画・読めないものは null
  PickedItem? _parseItem(Object? raw) {
    if (raw is! Map) return null;
    final fileRaw = raw['mediaFile'];
    final file = fileRaw is Map ? fileRaw : raw;
    final id = raw['id'];
    final baseUrl = file['baseUrl'] ?? raw['baseUrl'];
    final mime = file['mimeType'] ?? raw['mimeType'];
    if (id is! String || baseUrl is! String || baseUrl.isEmpty) return null;
    if (mime is! String || !mime.startsWith('image/')) return null;
    final type = raw['type'];
    if (type is String && type.toUpperCase() == 'VIDEO') return null;

    final metaRaw = file['mediaFileMetadata'] ?? raw['mediaFileMetadata'];
    final meta = metaRaw is Map ? metaRaw : const {};
    int? asInt(Object? v) =>
        v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
    final createRaw = raw['createTime'] ?? meta['createTime'];
    return PickedItem(
      id: id,
      baseUrl: baseUrl,
      mimeType: mime,
      createTime: createRaw is String ? DateTime.tryParse(createRaw) : null,
      width: asInt(meta['width'] ?? file['width'] ?? raw['width']),
      height: asInt(meta['height'] ?? file['height'] ?? raw['height']),
    );
  }

  @override
  Future<Uint8List> fetchImage(PickedItem item, {required int maxSide}) async {
    // 要確認(G0): ブラウザから Authorization つきで取れるか（CORS）
    final uri = Uri.tryParse('${item.baseUrl}=w$maxSide-h$maxSide');
    if (uri == null) {
      throw const GooglePhotosException(GooglePhotosFailure.other);
    }
    final res = await _send((h) => _client.get(uri, headers: h));
    return res.bodyBytes;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    try {
      await _client
          .delete(
            Uri.parse('$_baseUrl/sessions/${Uri.encodeComponent(sessionId)}'),
            headers: _headers(),
          )
          .timeout(_requestTimeout);
    } catch (_) {
      // 失敗しても無視する
    }
  }
}

final googlePhotosApiProvider = Provider<GooglePhotosApi>((ref) {
  // ログアウト・別のユーザーへの切り替えで作り直し、前の人のトークンを捨てる
  ref.watch(authStateProvider.select((a) => a.value?.uid));
  return GooglePhotosService(FirebaseAuth.instance);
});
