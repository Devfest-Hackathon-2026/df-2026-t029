import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Google カレンダー（Calendar API）との連携
class GoogleCalendarService {
  GoogleCalendarService(this._auth);

  final FirebaseAuth _auth;

  static const _scope = 'https://www.googleapis.com/auth/calendar.events';
  static const _baseUrl = 'https://www.googleapis.com/calendar/v3';

  String? _token;
  DateTime? _tokenExpiresAt;

  /// カレンダーの権限付きのアクセストークンを返す。
  /// 手元に有効なものがなければ、ポップアップで権限を求める。
  /// ボタンを押した処理の中で最初に呼ぶこと（ブラウザにポップアップを止められないため）
  Future<String> _accessToken() async {
    final token = _token;
    final expiresAt = _tokenExpiresAt;
    if (token != null &&
        expiresAt != null &&
        DateTime.now().isBefore(expiresAt)) {
      return token;
    }

    final user = _auth.currentUser;
    if (user == null) throw StateError('ログインしていません');

    // final provider = GoogleAuthProvider()..addScope(_scope);
    // final result = await user.reauthenticateWithPopup(provider);
    final provider = GoogleAuthProvider()
      ..addScope(_scope)
      // ポップアップで、ログイン中のアカウントを最初から選んだ状態にする
      ..setCustomParameters({
        if (user.email != null) 'login_hint': user.email!,
      });

    final UserCredential result;
    try {
      result = await user.reauthenticateWithPopup(provider);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-mismatch') {
        throw StateError('ログイン中のアカウント（${user.email}）を選んでください');
      }
      rethrow;
    }

    final newToken = result.credential?.accessToken;
    if (newToken == null) throw StateError('カレンダーの権限を取得できませんでした');

    _token = newToken;
    // アクセストークンの有効期限は約1時間。余裕を見て50分で取り直す
    _tokenExpiresAt = DateTime.now().add(const Duration(minutes: 50));
    return newToken;
  }

  /// 接続テスト：これからの予定を最大5件読み、件名の一覧を返す
  Future<List<String>> upcomingEventTitles() async {
    final token = await _accessToken();
    final uri = Uri.parse('$_baseUrl/calendars/primary/events').replace(
      queryParameters: {
        'maxResults': '5',
        'singleEvents': 'true',
        'orderBy': 'startTime',
        'timeMin': DateTime.now().toUtc().toIso8601String(),
      },
    );
    final res =
        await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) {
      throw Exception('Calendar API エラー（${res.statusCode}）：${res.body}');
    }
    final items =
        (jsonDecode(res.body) as Map<String, dynamic>)['items'] as List? ??
            const [];
    return [
      for (final e in items)
        (e as Map<String, dynamic>)['summary'] as String? ?? '（件名なし）',
    ];
  }
}

final googleCalendarServiceProvider = Provider<GoogleCalendarService>(
  (ref) => GoogleCalendarService(FirebaseAuth.instance),
);