import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/utils/auth_validators.dart';

void main() {
  group('validateEmail', () {
    test('空・null・空白だけは「入れてください」', () {
      for (final v in [null, '', '   ']) {
        expect(validateEmail(v), 'メールアドレスを入れてください。');
      }
    });

    test('形が正しければ null（前後の空白は除いて見る）', () {
      for (final v in ['a@example.com', '  a@example.com  ', 'a.b+c@x.co.jp']) {
        expect(validateEmail(v), isNull, reason: v);
      }
    });

    test('形が違えばエラー', () {
      for (final v in [
        'abc',
        'a@',
        '@b.com',
        'a@b',
        'a@b.',
        'a b@c.com',
        'a@@b.com',
        'a@b .com',
      ]) {
        expect(validateEmail(v), 'メールアドレスの形が正しくありません。', reason: v);
      }
    });
  });

  group('validatePassword', () {
    test('空・null は、どちらのモードでもエラー', () {
      for (final signUp in [true, false]) {
        for (final v in [null, '']) {
          expect(validatePassword(v, isSignUp: signUp), 'パスワードを入れてください。');
        }
      }
    });

    test('新規登録: 8文字未満はエラー、8文字は通る（境界）', () {
      expect(validatePassword('a' * 7, isSignUp: true), 'パスワードは8文字以上にしてください。');
      expect(validatePassword('a' * 8, isSignUp: true), isNull);
      expect(validatePassword('a' * 9, isSignUp: true), isNull);
    });

    test('ログイン: 短くても長さは見ない', () {
      expect(validatePassword('a', isSignUp: false), isNull);
    });

    test('前後の空白は除かない（空白だけでも1文字以上と数える）', () {
      expect(validatePassword('        ', isSignUp: true), isNull);
      expect(validatePassword('       ', isSignUp: true), isNotNull);
      expect(validatePassword(' ', isSignUp: false), isNull);
    });

    test('minPasswordLength は 8', () => expect(minPasswordLength, 8));
  });

  group('validatePasswordConfirm', () {
    test('同じなら null、違えば「一致しません」', () {
      expect(validatePasswordConfirm('abc', 'abc'), isNull);
      expect(validatePasswordConfirm('abc', 'abd'), 'パスワードが一致しません。');
      expect(validatePasswordConfirm(null, 'abc'), 'パスワードが一致しません。');
      expect(validatePasswordConfirm('abc ', 'abc'), 'パスワードが一致しません。');
    });

    test('両方空なら一致とみなす（空の検査はパスワード欄の役目）', () {
      expect(validatePasswordConfirm('', ''), isNull);
      expect(validatePasswordConfirm(null, ''), isNull);
    });
  });
}
