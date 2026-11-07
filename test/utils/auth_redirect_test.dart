import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/utils/auth_redirect.dart';

String? redirect(
  String location, {
  bool loggedIn = true,
  bool verify = false,
  bool profile = false,
}) => decideRedirect(
  location: location,
  loggedIn: loggedIn,
  needsEmailVerification: verify,
  needsProfile: profile,
);

void main() {
  group('needsEmailVerification', () {
    test('password があって未確認のときだけ true', () {
      expect(
        needsEmailVerification(emailVerified: false, providerIds: ['password']),
        isTrue,
      );
      expect(
        needsEmailVerification(emailVerified: true, providerIds: ['password']),
        isFalse,
      );
    });

    test('Google だけの人は、未確認でも対象外', () {
      expect(
        needsEmailVerification(
          emailVerified: false,
          providerIds: ['google.com'],
        ),
        isFalse,
      );
    });

    test('password と google.com の両方があれば、未確認なら対象', () {
      expect(
        needsEmailVerification(
          emailVerified: false,
          providerIds: ['google.com', 'password'],
        ),
        isTrue,
      );
    });

    test('ログインの方法が無ければ false', () {
      expect(
        needsEmailVerification(emailVerified: false, providerIds: []),
        isFalse,
      );
    });
  });

  group('decideRedirect（計画書 4.5 の表）', () {
    test('未ログイン: /welcome・/login はそのまま', () {
      expect(redirect('/welcome', loggedIn: false), isNull);
      expect(redirect('/login', loggedIn: false), isNull);
    });

    test('未ログイン: それ以外（/verify-email を含む）は /welcome', () {
      for (final l in [
        '/',
        '/verify-email',
        '/profile',
        '/lives/1',
        '/trade',
      ]) {
        expect(redirect(l, loggedIn: false), '/welcome', reason: l);
      }
    });

    test('未ログインなら、確認待ち・プロフィール無しの値は関係ない', () {
      expect(
        redirect('/verify-email', loggedIn: false, verify: true, profile: true),
        '/welcome',
      );
    });

    test('未確認: /verify-email はそのまま', () {
      expect(redirect('/verify-email', verify: true), isNull);
    });

    test('未確認: それ以外はすべて /verify-email（URL を直接打っても出られない）', () {
      for (final l in [
        '/',
        '/welcome',
        '/login',
        '/profile',
        '/lives/1',
        '/trade',
      ]) {
        expect(redirect(l, verify: true), '/verify-email', reason: l);
      }
    });

    test('未確認はプロフィール無しより先に判定する', () {
      expect(
        redirect('/profile', verify: true, profile: true),
        '/verify-email',
      );
      expect(redirect('/', verify: true, profile: true), '/verify-email');
    });

    test('プロフィール無し: /profile はそのまま、それ以外は /profile', () {
      expect(redirect('/profile', profile: true), isNull);
      for (final l in [
        '/',
        '/welcome',
        '/login',
        '/verify-email',
        '/lives/1',
      ]) {
        expect(redirect(l, profile: true), '/profile', reason: l);
      }
    });

    test('ログイン済み: /welcome・/login・/verify-email は /', () {
      for (final l in ['/welcome', '/login', '/verify-email']) {
        expect(redirect(l), '/', reason: l);
      }
    });

    test('ログイン済み: それ以外はそのまま（/profile も）', () {
      for (final l in ['/', '/profile', '/lives/1', '/trade', '/register']) {
        expect(redirect(l), isNull, reason: l);
      }
    });
  });
}
