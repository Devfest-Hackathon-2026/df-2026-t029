import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/repositories/auth_repository.dart';

import '../features/auth_test_helpers.dart';

// テストのパスワードは架空の値
const _pw = 'dummy-pass-0000';

void main() {
  late FakeFirebaseAuth auth;
  late AuthRepository repo;

  setUp(() {
    auth = FakeFirebaseAuth();
    repo = AuthRepository(auth);
  });

  group('signUpWithEmail', () {
    test('前後の空白を除いてアカウントを作り、確認メールを送る', () async {
      final user = FakeUser();
      auth.userToCreate = user;
      await repo.signUpWithEmail(email: '  a@example.com \n', password: _pw);
      expect(auth.created, [(email: 'a@example.com', password: _pw)]);
      expect(user.verificationMails, 1);
    });

    test('パスワードの前後の空白は除かない', () async {
      await repo.signUpWithEmail(email: 'a@example.com', password: ' $_pw ');
      expect(auth.created.single.password, ' $_pw ');
    });

    test('確認メールの送信に失敗しても、例外にしない', () async {
      final user = FakeUser()
        ..verificationError = authError('too-many-requests');
      auth.userToCreate = user;
      await repo.signUpWithEmail(email: 'a@example.com', password: _pw);
      expect(user.verificationMails, 1);
    });

    test('アカウントの作成に失敗したら、FirebaseAuthException を投げ、メールは送らない', () async {
      final user = FakeUser();
      auth.userToCreate = user;
      auth.createError = authError('email-already-in-use');
      await expectLater(
        repo.signUpWithEmail(email: 'a@example.com', password: _pw),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'email-already-in-use',
          ),
        ),
      );
      expect(user.verificationMails, 0);
    });
  });

  group('signInWithEmail', () {
    test('前後の空白を除いて渡す', () async {
      await repo.signInWithEmail(email: ' a@example.com ', password: _pw);
      expect(auth.signedIn, [(email: 'a@example.com', password: _pw)]);
    });

    test('失敗は FirebaseAuthException のまま投げる', () async {
      auth.signInError = authError('invalid-credential');
      await expectLater(
        repo.signInWithEmail(email: 'a@example.com', password: _pw),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  });

  group('sendPasswordResetEmail', () {
    test('前後の空白を除いて送る', () async {
      await repo.sendPasswordResetEmail(' a@example.com ');
      expect(auth.resetMails, ['a@example.com']);
    });

    test('user-not-found もそのまま投げる（成功扱いは画面側）', () async {
      auth.resetError = authError('user-not-found');
      await expectLater(
        repo.sendPasswordResetEmail('a@example.com'),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'user-not-found',
          ),
        ),
      );
    });
  });

  group('resendEmailVerification', () {
    test('ユーザーがいれば確認メールを送る', () async {
      final user = FakeUser();
      auth.currentUser = user;
      await repo.resendEmailVerification();
      expect(user.verificationMails, 1);
    });

    test('ユーザーがいなければ何もしない', () async {
      await repo.resendEmailVerification();
    });

    test('失敗は FirebaseAuthException のまま投げる', () async {
      auth.currentUser = FakeUser()
        ..verificationError = authError('too-many-requests');
      await expectLater(
        repo.resendEmailVerification(),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  });

  group('reloadEmailVerified', () {
    test('ユーザーがいなければ false', () async {
      expect(await repo.reloadEmailVerified(), isFalse);
    });

    test('未確認のままなら false。reload はするが、トークンは取り直さない', () async {
      final user = FakeUser();
      auth.currentUser = user;
      expect(await repo.reloadEmailVerified(), isFalse);
      expect(user.reloads, 1);
      expect(user.tokenRefreshes, isEmpty);
    });

    test('reload で確認済みになったら true、トークンを取り直す', () async {
      final user = FakeUser();
      user.onReload = () => user.emailVerified = true;
      auth.currentUser = user;
      expect(await repo.reloadEmailVerified(), isTrue);
      expect(user.tokenRefreshes, [true]);
    });

    test('reload 後に currentUser が新しい User になっても、そちらを見る', () async {
      final old = FakeUser();
      final fresh = FakeUser(emailVerified: true);
      old.onReload = () => auth.currentUser = fresh;
      auth.currentUser = old;
      expect(await repo.reloadEmailVerified(), isTrue);
      expect(fresh.tokenRefreshes, [true]);
    });

    test('reload 中にログアウトされたら false', () async {
      final user = FakeUser();
      user.onReload = () => auth.currentUser = null;
      auth.currentUser = user;
      expect(await repo.reloadEmailVerified(), isFalse);
    });
  });

  group('currentUserNeedsEmailVerification', () {
    test('ユーザーがいなければ false', () {
      expect(repo.currentUserNeedsEmailVerification, isFalse);
    });

    test('メールで登録して未確認なら true、確認済みなら false', () {
      final user = FakeUser();
      auth.currentUser = user;
      expect(repo.currentUserNeedsEmailVerification, isTrue);
      user.emailVerified = true;
      expect(repo.currentUserNeedsEmailVerification, isFalse);
    });

    test('Google だけの人は、emailVerified が false でも false', () {
      auth.currentUser = FakeUser(providerIds: ['google.com']);
      expect(repo.currentUserNeedsEmailVerification, isFalse);
    });
  });

  test('signInWithGoogle・signOut は FirebaseAuth に任せる', () async {
    await repo.signInWithGoogle();
    expect(auth.popups, 1);
    await repo.signOut();
    expect(auth.signOuts, 1);
  });
}
