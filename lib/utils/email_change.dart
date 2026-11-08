// メールアドレスの変更（プロフィールの「アカウント」）で使う純粋関数。
// Firebase に依存しない。

/// 伏せ字。'ken-oshi@example.com' → 'ke******@example.com'。
/// @ の前の先頭 2 文字だけ出し、* は max(3, 長さ-2) 個。'ab@x.com' → 'ab***@x.com'。
/// @ が無ければ '***'。
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at < 0) return '***';
  final local = email.substring(0, at);
  final domain = email.substring(at);
  final shown = local.length < 2 ? local : local.substring(0, 2);
  final stars = local.length - 2 < 3 ? 3 : local.length - 2;
  return '$shown${'*' * stars}$domain';
}

final _newEmailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// 新しいアドレスの検査（4.5）。正しければ null。
/// 前後の空白を除いて見る。current と同じ（大文字小文字は区別しない）ならエラー。
String? validateNewEmail(String input, {required String? current}) {
  final v = input.trim();
  if (!_newEmailPattern.hasMatch(v)) {
    return 'メールアドレスの形式が正しくありません。（例：example@mail.com）';
  }
  if (current != null && v.toLowerCase() == current.trim().toLowerCase()) {
    return 'いま使っているメールアドレスと同じです。別のメールアドレスを入力してください。';
  }
  return null;
}

/// 登録方法
enum AccountKind { email, google, other }

/// パスワードのログイン方法を持っていれば email、
/// なくて google.com を持っていれば google、どちらも無ければ other。
AccountKind accountKindOf(Iterable<String> providerIds) {
  final ids = providerIds.toSet();
  if (ids.contains('password')) return AccountKind.email;
  if (ids.contains('google.com')) return AccountKind.google;
  return AccountKind.other;
}
