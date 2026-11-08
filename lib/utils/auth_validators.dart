/// パスワードの最小の長さ（新規登録のとき）
const minPasswordLength = 8;

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// メールアドレスの検査。正しければ null
String? validateEmail(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'メールアドレスを入れてください。';
  if (!_emailPattern.hasMatch(v)) return 'メールアドレスの形が正しくありません。';
  return null;
}

/// パスワードの検査。長さは新規登録のときだけ見る。前後の空白は除かない
String? validatePassword(String? value, {required bool isSignUp}) {
  final v = value ?? '';
  if (v.isEmpty) return 'パスワードを入れてください。';
  if (isSignUp && v.length < minPasswordLength) {
    return 'パスワードは$minPasswordLength文字以上にしてください。';
  }
  return null;
}

/// 確認用パスワードの検査
String? validatePasswordConfirm(String? value, String password) {
  if ((value ?? '') != password) return 'パスワードが一致しません。';
  return null;
}
