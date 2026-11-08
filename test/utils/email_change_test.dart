import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/utils/auth_error_message.dart';
import 'package:oshiashi/utils/email_change.dart';

void main() {
  group('maskEmail', () {
    test('先頭2文字だけ出し、残りを * にする', () {
      expect(maskEmail('ken-oshi@example.com'), 'ke******@example.com');
      expect(maskEmail('abcdef@example.com'), 'ab****@example.com');
    });
    test('ちょうど2文字・先頭が1文字なら * は3個', () {
      expect(maskEmail('ab@example.com'), 'ab***@example.com');
      expect(maskEmail('a@example.com'), 'a***@example.com');
    });
    test('3文字・4文字でも * は最低3個', () {
      expect(maskEmail('abc@example.com'), 'ab***@example.com');
      expect(maskEmail('abcde@example.com'), 'ab***@example.com');
    });
    test('長いアドレスは長さ-2 個の *', () {
      final local = 'a' * 30;
      expect(maskEmail('$local@example.com'), 'aa${'*' * 28}@example.com');
    });
    test('@ が無ければ ***', () {
      expect(maskEmail('no-at-mark'), '***');
      expect(maskEmail(''), '***');
    });
  });

  group('validateNewEmail', () {
    const cur = 'now@example.com';
    test('正しい形式は null', () {
      expect(validateNewEmail('new@example.com', current: cur), isNull);
      expect(validateNewEmail('a.b+c@sub.example.co.jp', current: cur), isNull);
    });
    test('前後の空白は除いて見る', () {
      expect(validateNewEmail('  new@example.com \n', current: cur), isNull);
    });
    test('形式エラー', () {
      for (final v in [
        '',
        '   ',
        'example.com',
        'a@b',
        'a@b.c',
        'a b@example.com',
        'a@@example.com',
      ]) {
        expect(
          validateNewEmail(v, current: cur),
          'メールアドレスの形式が正しくありません。（例：example@mail.com）',
          reason: v,
        );
      }
    });
    test('いまと同じ（大文字小文字違い・空白付きも）', () {
      const msg = 'いま使っているメールアドレスと同じです。別のメールアドレスを入力してください。';
      expect(validateNewEmail('now@example.com', current: cur), msg);
      expect(validateNewEmail(' NOW@Example.com ', current: cur), msg);
    });
    test('いまが null なら同じ検査をしない', () {
      expect(validateNewEmail('new@example.com', current: null), isNull);
    });
  });

  group('accountKindOf', () {
    test('password を持てば email', () {
      expect(accountKindOf(['password']), AccountKind.email);
      expect(accountKindOf(['google.com', 'password']), AccountKind.email);
    });
    test('google.com だけなら google', () {
      expect(accountKindOf(['google.com']), AccountKind.google);
    });
    test('空・知らない方法は other', () {
      expect(accountKindOf([]), AccountKind.other);
      expect(accountKindOf(['phone']), AccountKind.other);
    });
  });

  group('emailChangeErrorMessage', () {
    test('requires-recent-login は null', () {
      expect(emailChangeErrorMessage('requires-recent-login'), isNull);
    });
    test('4.5 の表の文言', () {
      expect(
        emailChangeErrorMessage('email-already-in-use'),
        'このメールアドレスは、すでに別のアカウントで使われています。',
      );
      expect(
        emailChangeErrorMessage('invalid-email'),
        'メールアドレスの形式が正しくありません。（例：example@mail.com）',
      );
      for (final c in [
        'invalid-credential',
        'wrong-password',
        'invalid-login-credentials',
      ]) {
        expect(emailChangeErrorMessage(c), 'パスワードが違います。', reason: c);
      }
      expect(
        emailChangeErrorMessage('too-many-requests'),
        '試した回数が多すぎます。しばらく待ってから、もう一度お試しください。',
      );
      expect(
        emailChangeErrorMessage('network-request-failed'),
        '通信できませんでした。電波の良いところで、もう一度お試しください。',
      );
    });
    test('知らないコードは、コードを含まない文', () {
      final m = emailChangeErrorMessage('some-new-code');
      expect(m, 'うまくいきませんでした。もう一度お試しください。');
      expect(m, isNot(contains('some-new-code')));
    });
  });
}
