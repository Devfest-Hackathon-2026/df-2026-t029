import 'calendar_events.dart';

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../repositories/auth_repository.dart';

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
    final hasGoogle = user.providerData.any(
      (p) => p.providerId == 'google.com',
    );

    UserCredential result;
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
          throw StateError('ログイン中のアカウント（${user.email}）を選んでください');
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
          throw StateError(
            'この Google アカウントは、別のおしあしのアカウントで使われています。別の Google アカウントを選んでください',
          );
        }
        if (e.code == 'provider-already-linked') {
          result = await user.reauthenticateWithPopup(provider);
        } else {
          rethrow;
        }
      }
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
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
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

  /// 予定を追加する。同じ予定（同じ ID）がすでにあれば上書きする。
  /// ボタンを押した処理の中で最初に呼ぶこと（ポップアップのため）
  Future<void> upsertEvents(List<CalendarEvent> events) async {
    final token = await _accessToken();
    for (final e in events) {
      await _upsert(token, e);
    }
  }

  Future<void> _upsert(String token, CalendarEvent e) async {
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode(e.toJson());

    // まず新規に作り、同じ ID の予定がすでにあれば（409）上書きする
    final created = await http.post(
      Uri.parse('$_baseUrl/calendars/primary/events'),
      headers: headers,
      body: body,
    );
    if (created.statusCode == 200) return;

    if (created.statusCode == 409) {
      final updated = await http.put(
        Uri.parse('$_baseUrl/calendars/primary/events/${e.eventId}'),
        headers: headers,
        body: body,
      );
      if (updated.statusCode == 200) return;
      throw Exception('予定の更新に失敗しました（${updated.statusCode}）：${updated.body}');
    }
    throw Exception('予定の追加に失敗しました（${created.statusCode}）：${created.body}');
  }
}

final googleCalendarServiceProvider = Provider<GoogleCalendarService>((ref) {
  // ログアウト・別のユーザーへの切り替えで作り直し、前の人のトークンを捨てる
  ref.watch(authStateProvider.select((a) => a.value?.uid));
  return GoogleCalendarService(FirebaseAuth.instance);
});
