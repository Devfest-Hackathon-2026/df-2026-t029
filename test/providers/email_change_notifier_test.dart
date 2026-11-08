// EmailChangeNotifier（メールアドレス変更の流れ）のテスト。
// 偽の AuthRepository と、短くしたタイミングで動かす。時間は tester.pump で進める
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/providers/email_change_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';

import '../features/auth_test_helpers.dart';

const _newEmail = 'new@example.com';
const _formatError = 'メールアドレスの形式が正しくありません。（例：example@mail.com）';

FirebaseAuthException _ex(String code) => FirebaseAuthException(code: code);

/// 1 秒ごとに自動確認・待ちは 3 秒
const _timing = EmailChangeTiming(
  pollInterval: Duration(seconds: 1),
  resendCooldown: 3,
);

({ProviderContainer c, FakeAuthRepository repo}) _setup() {
  final repo = FakeAuthRepository()..email = 'now@example.com';
  final c = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      emailChangeTimingProvider.overrideWithValue(_timing),
    ],
  );
  // autoDispose を生かしておく
  c.listen(emailChangeProvider, (_, _) {});
  _open.add(c);
  return (c: c, repo: repo);
}

EmailChangeNotifier _n(ProviderContainer c) =>
    c.read(emailChangeProvider.notifier);
EmailChangeState _s(ProviderContainer c) => c.read(emailChangeProvider);

/// テストの終わりに Notifier を破棄して、タイマーを止める
/// （testWidgets は終わりに、保留のタイマーが無いことを確かめるため）
void _test(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    for (final c in _open) {
      c.dispose();
    }
    _open.clear();
  });
}

final _open = <ProviderContainer>[];

void main() {
  _test('送る: 成功すると waiting・sentTo・再送の待ちが始まる', (tester) async {
    final t = _setup();
    await _n(t.c).submit(newEmail: '  $_newEmail ');
    final s = _s(t.c);
    expect(s.step, EmailChangeStep.waiting);
    expect(s.sentTo, _newEmail);
    expect(s.resendLeft, 3);
    expect(s.busy, isFalse);
    expect(s.error, isNull);
    expect(t.repo.emailChanges, [_newEmail]);
  });

  _test('形式エラー・同じアドレスでは repository を呼ばない', (tester) async {
    final t = _setup();
    await _n(t.c).submit(newEmail: 'abc');
    expect(_s(t.c).error, _formatError);
    expect(_s(t.c).step, EmailChangeStep.input);
    await _n(t.c).submit(newEmail: 'NOW@example.com');
    expect(_s(t.c).error, contains('同じです'));
    expect(t.repo.emailChanges, isEmpty);
    expect(t.repo.reauths, 0);
  });

  _test('email-already-in-use のエラー文', (tester) async {
    final t = _setup();
    t.repo.errors['startEmailChange'] = _ex('email-already-in-use');
    await _n(t.c).submit(newEmail: _newEmail);
    expect(_s(t.c).error, 'このメールアドレスは、すでに別のアカウントで使われています。');
    expect(_s(t.c).step, EmailChangeStep.input);
    expect(_s(t.c).busy, isFalse);
  });

  _test('FirebaseAuthException 以外は、中身を出さない文', (tester) async {
    final t = _setup();
    t.repo.errors['startEmailChange'] = StateError('secret-detail');
    await _n(t.c).submit(newEmail: _newEmail);
    expect(_s(t.c).error, 'うまくいきませんでした。もう一度お試しください。');
    expect(_s(t.c).error, isNot(contains('secret')));
  });

  _test('requires-recent-login → needsPassword（文は出ない）→ 再認証して送る', (
    tester,
  ) async {
    final t = _setup();
    t.repo.errors['startEmailChange'] = _ex('requires-recent-login');
    await _n(t.c).submit(newEmail: _newEmail);
    expect(_s(t.c).needsPassword, isTrue);
    expect(_s(t.c).error, isNull);
    expect(_s(t.c).step, EmailChangeStep.input);
    expect(t.repo.reauths, 0);

    await _n(t.c).submit(newEmail: _newEmail, password: 'dummy-pass');
    expect(t.repo.reauths, 1);
    expect(_s(t.c).step, EmailChangeStep.waiting);
    expect(_s(t.c).needsPassword, isFalse);
    expect(t.repo.emailChanges, [_newEmail, _newEmail]);
  });

  _test('パスワードが違う（invalid-credential）', (tester) async {
    final t = _setup();
    t.repo.errors['startEmailChange'] = _ex('requires-recent-login');
    await _n(t.c).submit(newEmail: _newEmail);
    t.repo.errors['reauth'] = _ex('invalid-credential');
    await _n(t.c).submit(newEmail: _newEmail, password: 'dummy-pass');
    expect(_s(t.c).error, 'パスワードが違います。');
    expect(_s(t.c).needsPassword, isTrue);
    expect(_s(t.c).step, EmailChangeStep.input);
    expect(t.repo.emailChanges, [_newEmail]); // 再認証で止まり、送っていない
  });

  _test('パスワードを state に残さない', (tester) async {
    final t = _setup();
    t.repo.errors['startEmailChange'] = _ex('requires-recent-login');
    await _n(t.c).submit(newEmail: _newEmail);
    await _n(t.c).submit(newEmail: _newEmail, password: 'dummy-pass');
    expect(_s(t.c).toString(), isNot(contains('dummy-pass')));
    final s = _s(t.c);
    for (final v in [s.newEmail, s.sentTo, s.error ?? '']) {
      expect(v, isNot(contains('dummy-pass')));
    }
  });

  _test('自動の確認: アドレスが変わったら done（大文字小文字は区別しない）', (tester) async {
    final t = _setup();
    await _n(t.c).submit(newEmail: _newEmail);
    t.repo.reloadedEmail = 'now@example.com';
    await tester.pump(const Duration(seconds: 2));
    expect(_s(t.c).step, EmailChangeStep.waiting);
    expect(_s(t.c).error, isNull); // 自動のときは何も出さない
    t.repo.reloadedEmail = 'NEW@Example.com';
    await tester.pump(const Duration(seconds: 1));
    expect(_s(t.c).step, EmailChangeStep.done);
    expect(_s(t.c).sessionEnded, isFalse);
    // 止まる
    final before = t.repo.emailChanges.length;
    await tester.pump(const Duration(seconds: 5));
    expect(t.repo.emailChanges.length, before);
  });

  _test('自動の確認の失敗（通信など）は黙って waiting のまま', (tester) async {
    final t = _setup();
    await _n(t.c).submit(newEmail: _newEmail);
    t.repo.errors['reloadCurrentEmail'] = _ex('network-request-failed');
    await tester.pump(const Duration(seconds: 1));
    expect(_s(t.c).step, EmailChangeStep.waiting);
    expect(_s(t.c).error, isNull);
  });

  _test('手動の確認: まだなら文、できたら done', (tester) async {
    final t = _setup();
    await _n(t.c).submit(newEmail: _newEmail);
    t.repo.reloadedEmail = 'now@example.com';
    await _n(t.c).check(manual: true);
    expect(_s(t.c).error, startsWith('まだ確認できていません。'));
    expect(_s(t.c).busy, isFalse);
    expect(_s(t.c).step, EmailChangeStep.waiting);
    t.repo.reloadedEmail = _newEmail;
    await _n(t.c).check(manual: true);
    expect(_s(t.c).step, EmailChangeStep.done);
    expect(_s(t.c).error, isNull);
  });

  _test('user-token-expired は sessionEnded の done', (tester) async {
    final t = _setup();
    await _n(t.c).submit(newEmail: _newEmail);
    t.repo.errors['reloadCurrentEmail'] = _ex('user-token-expired');
    await tester.pump(const Duration(seconds: 1));
    expect(_s(t.c).step, EmailChangeStep.done);
    expect(_s(t.c).sessionEnded, isTrue);
  });

  _test('waiting 以外では check は何もしない', (tester) async {
    final t = _setup();
    t.repo.errors['reloadCurrentEmail'] = _ex('user-token-expired');
    await _n(t.c).check(manual: true);
    expect(_s(t.c).step, EmailChangeStep.input);
    expect(_s(t.c).sessionEnded, isFalse);
  });

  _test('再送: 待ちの間は呼ばれない。待ちが終わると送れて 60 秒（ここでは 3 秒）に戻る', (tester) async {
    final t = _setup();
    await _n(t.c).submit(newEmail: _newEmail);
    await _n(t.c).resend();
    expect(t.repo.emailChanges.length, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(_s(t.c).resendLeft, 2);
    await tester.pump(const Duration(seconds: 2));
    expect(_s(t.c).resendLeft, 0);
    await _n(t.c).resend();
    expect(t.repo.emailChanges, [_newEmail, _newEmail]);
    expect(_s(t.c).resendLeft, 3);
    expect(_s(t.c).busy, isFalse);
  });

  _test('再送で requires-recent-login → 入力に戻りパスワード欄', (tester) async {
    final t = _setup();
    await _n(t.c).submit(newEmail: _newEmail);
    await tester.pump(const Duration(seconds: 3));
    t.repo.errors['startEmailChange'] = _ex('requires-recent-login');
    await _n(t.c).resend();
    expect(_s(t.c).step, EmailChangeStep.input);
    expect(_s(t.c).needsPassword, isTrue);
    expect(_s(t.c).newEmail, _newEmail);
    expect(_s(t.c).error, isNull);
    // タイマーは止まっている（保留のタイマーが残ればテストが失敗する）
  });

  _test('再送の失敗は文を出し、waiting のまま', (tester) async {
    final t = _setup();
    await _n(t.c).submit(newEmail: _newEmail);
    await tester.pump(const Duration(seconds: 3));
    t.repo.errors['startEmailChange'] = _ex('too-many-requests');
    await _n(t.c).resend();
    expect(_s(t.c).step, EmailChangeStep.waiting);
    expect(_s(t.c).error, startsWith('試した回数が多すぎます'));
    expect(_s(t.c).busy, isFalse);
  });

  _test('入力し直す: 入力が残り、タイマーが止まる', (tester) async {
    final t = _setup();
    await _n(t.c).submit(newEmail: _newEmail);
    _n(t.c).backToInput();
    expect(_s(t.c).step, EmailChangeStep.input);
    expect(_s(t.c).newEmail, _newEmail);
    expect(_s(t.c).resendLeft, 0);
    // 止まっていれば、アドレスが変わっても done にならない
    t.repo.reloadedEmail = _newEmail;
    await tester.pump(const Duration(seconds: 5));
    expect(_s(t.c).step, EmailChangeStep.input);
  });

  _test('二重送信しない（busy の間）', (tester) async {
    final t = _setup();
    t.repo.gate = Completer<void>();
    final first = _n(t.c).submit(newEmail: _newEmail);
    await tester.pump();
    expect(_s(t.c).busy, isTrue);
    await _n(t.c).submit(newEmail: _newEmail);
    t.repo.gate!.complete();
    t.repo.gate = null;
    await first;
    expect(t.repo.emailChanges, [_newEmail]);
    expect(_s(t.c).step, EmailChangeStep.waiting);
  });

  testWidgets('破棄するとタイマーが止まる', (tester) async {
    final repo = FakeAuthRepository()..email = 'now@example.com';
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        emailChangeTimingProvider.overrideWithValue(_timing),
      ],
    );
    final sub = c.listen(emailChangeProvider, (_, _) {});
    await c.read(emailChangeProvider.notifier).submit(newEmail: _newEmail);
    expect(c.read(emailChangeProvider).step, EmailChangeStep.waiting);
    sub.close();
    await tester.pump(); // autoDispose
    repo.reloadedEmail = _newEmail;
    await tester.pump(const Duration(seconds: 5));
    c.dispose();
    // 保留のタイマーが残っていれば、テストの終わりで失敗する
  });

  _test('clearError はエラーの行だけ消す', (tester) async {
    final t = _setup();
    await _n(t.c).submit(newEmail: 'abc');
    expect(_s(t.c).error, isNotNull);
    _n(t.c).clearError();
    expect(_s(t.c).error, isNull);
    expect(_s(t.c).newEmail, 'abc');
  });
}
