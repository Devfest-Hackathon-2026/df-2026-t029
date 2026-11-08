// GoogleCalendarService の Google アカウントのつなぎ込み（計画書 4.8）
// 予定が空の upsertEvents は、トークンを取るだけで通信しない
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/services/google_calendar_service.dart';

import '../features/auth_test_helpers.dart';

const _alreadyUsed =
    'この Google アカウントは、別のおしあしのアカウントで使われています。別の Google アカウントを選んでください';

Future<UserCredential> _ok(AuthProvider _) async =>
    FakeUserCredential(credential: FakeCredential('tok'));

Future<UserCredential> Function(AuthProvider) _fail(String code) =>
    (_) async => throw authError(code);

Matcher _stateError(String message) =>
    isA<StateError>().having((e) => e.message, 'message', message);

void main() {
  late FakeFirebaseAuth auth;
  late GoogleCalendarService service;

  FakeUser login(FakeUser user) {
    auth.currentUser = user;
    return user;
  }

  setUp(() {
    auth = FakeFirebaseAuth();
    service = GoogleCalendarService(auth);
  });

  test('ログインしていなければ StateError', () async {
    await expectLater(
      service.upsertEvents([]),
      throwsA(_stateError('ログインしていません')),
    );
  });

  group('google.com がある人（今までどおり）', () {
    test('reauthenticateWithPopup を使い、つなぎ直しはしない。login_hint を付ける', () async {
      final user = login(
        FakeUser(email: 'me@example.com', providerIds: ['google.com'])
          ..onReauth = _ok,
      );
      await service.upsertEvents([]);
      expect(user.reauthCalls, hasLength(1));
      expect(user.linkCalls, isEmpty);
      final provider = user.reauthCalls.single as GoogleAuthProvider;
      expect(
        provider.scopes,
        contains('https://www.googleapis.com/auth/calendar.events'),
      );
      expect(provider.parameters, {'login_hint': 'me@example.com'});
    });

    test('password も持っていても、google.com があれば reauthenticate', () async {
      final user = login(
        FakeUser(providerIds: ['password', 'google.com'])..onReauth = _ok,
      );
      await service.upsertEvents([]);
      expect(user.reauthCalls, hasLength(1));
      expect(user.linkCalls, isEmpty);
    });

    test('user-mismatch は、アカウントを選び直す案内の StateError', () async {
      login(
        FakeUser(email: 'me@example.com', providerIds: ['google.com'])
          ..onReauth = _fail('user-mismatch'),
      );
      await expectLater(
        service.upsertEvents([]),
        throwsA(_stateError('ログイン中のアカウント（me@example.com）を選んでください')),
      );
    });

    test('それ以外の FirebaseAuthException はそのまま投げる', () async {
      login(
        FakeUser(providerIds: ['google.com'])
          ..onReauth = _fail('popup-blocked'),
      );
      await expectLater(
        service.upsertEvents([]),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'popup-blocked',
          ),
        ),
      );
    });

    test('トークンが取れなければ StateError', () async {
      login(
        FakeUser(providerIds: ['google.com'])
          ..onReauth = (_) async => FakeUserCredential(),
      );
      await expectLater(
        service.upsertEvents([]),
        throwsA(_stateError('カレンダーの権限を取得できませんでした')),
      );
    });

    test('取れたトークンは使い回す（2回目はポップアップを出さない）', () async {
      final user = login(FakeUser(providerIds: ['google.com'])..onReauth = _ok);
      await service.upsertEvents([]);
      await service.upsertEvents([]);
      expect(user.reauthCalls, hasLength(1));
    });
  });

  group('google.com が無い人（メールで登録）', () {
    test('linkWithPopup でつなぐ。login_hint は付けない', () async {
      final user = login(FakeUser()..onLink = _ok);
      await service.upsertEvents([]);
      expect(user.linkCalls, hasLength(1));
      expect(user.reauthCalls, isEmpty);
      final provider = user.linkCalls.single as GoogleAuthProvider;
      expect(
        provider.scopes,
        contains('https://www.googleapis.com/auth/calendar.events'),
      );
      expect(provider.parameters, isEmpty);
    });

    test('つないだ後のトークンも使い回す', () async {
      final user = login(FakeUser()..onLink = _ok);
      await service.upsertEvents([]);
      await service.upsertEvents([]);
      expect(user.linkCalls, hasLength(1));
    });

    test('credential-already-in-use は、別の Google を選ぶ案内の StateError', () async {
      login(FakeUser()..onLink = _fail('credential-already-in-use'));
      await expectLater(
        service.upsertEvents([]),
        throwsA(_stateError(_alreadyUsed)),
      );
    });

    test('email-already-in-use も同じ案内', () async {
      login(FakeUser()..onLink = _fail('email-already-in-use'));
      await expectLater(
        service.upsertEvents([]),
        throwsA(_stateError(_alreadyUsed)),
      );
    });

    test('provider-already-linked は reauthenticateWithPopup でやり直す', () async {
      final user = login(
        FakeUser()
          ..onLink = _fail('provider-already-linked')
          ..onReauth = _ok,
      );
      await service.upsertEvents([]);
      expect(user.linkCalls, hasLength(1));
      expect(user.reauthCalls, hasLength(1));
    });

    test('やり直しの reauthenticate も失敗したら、その例外を投げる', () async {
      login(
        FakeUser()
          ..onLink = _fail('provider-already-linked')
          ..onReauth = _fail('popup-closed-by-user'),
      );
      await expectLater(
        service.upsertEvents([]),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'popup-closed-by-user',
          ),
        ),
      );
    });

    test('それ以外（ポップアップを閉じたなど）はそのまま投げる', () async {
      login(FakeUser()..onLink = _fail('popup-closed-by-user'));
      await expectLater(
        service.upsertEvents([]),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'popup-closed-by-user',
          ),
        ),
      );
    });

    test('トークンが取れなければ StateError', () async {
      login(FakeUser()..onLink = (_) async => FakeUserCredential());
      await expectLater(
        service.upsertEvents([]),
        throwsA(_stateError('カレンダーの権限を取得できませんでした')),
      );
    });
  });
}
