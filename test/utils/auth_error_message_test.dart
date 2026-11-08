import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/utils/auth_error_message.dart';

void main() {
  test('自分でポップアップを閉じたときは null（何も出さない）', () {
    expect(authErrorMessage('popup-closed-by-user'), isNull);
    expect(authErrorMessage('cancelled-popup-request'), isNull);
  });

  test('計画書 4.6 の表のとおり', () {
    const wrong = 'メールアドレスかパスワードが違います。';
    final expected = <String, String>{
      'popup-blocked': 'ポップアップがブロックされました。ブラウザの設定でこのサイトのポップアップを許可してください。',
      'invalid-email': 'メールアドレスの形が正しくありません。',
      'invalid-credential': wrong,
      'invalid-login-credentials': wrong,
      'wrong-password': wrong,
      'user-not-found': wrong,
      'email-already-in-use': 'このメールアドレスはすでに登録されています。「ログイン」から入ってください。',
      'weak-password': 'パスワードが弱すぎます。8文字以上にしてください。',
      'too-many-requests': '試した回数が多すぎます。しばらく待ってから、もう一度お試しください。',
      'user-disabled': 'このアカウントは使えなくなっています。',
      'network-request-failed': '通信できませんでした。電波の良いところで、もう一度お試しください。',
      'operation-not-allowed':
          'この方法でのログインは、いま使えません。（管理者: Firebase コンソールで有効にしてください）',
      'account-exists-with-different-credential':
          'このメールアドレスは、別の方法で登録されています。登録したときの方法でログインしてください。',
      'requires-recent-login': 'もう一度ログインしてから、お試しください。',
    };
    expected.forEach((code, message) {
      expect(authErrorMessage(code), message, reason: code);
    });
  });

  test('知らない code は、code を添えた文言', () {
    expect(authErrorMessage('xyz-unknown'), 'うまくいきませんでした（xyz-unknown）。');
    expect(authErrorMessage(''), 'うまくいきませんでした（）。');
  });
}
