/// FirebaseAuthException.code から、利用者に見せる文言を作る。
/// 知らせなくてよいエラー（自分でポップアップを閉じた）は null
String? authErrorMessage(String code) {
  switch (code) {
    case 'popup-closed-by-user':
    case 'cancelled-popup-request':
      return null;
    case 'popup-blocked':
      return 'ポップアップがブロックされました。ブラウザの設定でこのサイトのポップアップを許可してください。';
    case 'invalid-email':
      return 'メールアドレスの形が正しくありません。';
    case 'invalid-credential':
    case 'invalid-login-credentials':
    case 'wrong-password':
    case 'user-not-found':
      return 'メールアドレスかパスワードが違います。';
    case 'email-already-in-use':
      return 'このメールアドレスはすでに登録されています。「ログイン」から入ってください。';
    case 'weak-password':
      return 'パスワードが弱すぎます。8文字以上にしてください。';
    case 'too-many-requests':
      return '試した回数が多すぎます。しばらく待ってから、もう一度お試しください。';
    case 'user-disabled':
      return 'このアカウントは使えなくなっています。';
    case 'network-request-failed':
      return '通信できませんでした。電波の良いところで、もう一度お試しください。';
    case 'operation-not-allowed':
      return 'この方法でのログインは、いま使えません。（管理者: Firebase コンソールで有効にしてください）';
    case 'account-exists-with-different-credential':
      return 'このメールアドレスは、別の方法で登録されています。登録したときの方法でログインしてください。';
    case 'requires-recent-login':
      return 'もう一度ログインしてから、お試しください。';
    default:
      return 'うまくいきませんでした（$code）。';
  }
}
