/// ログインの方法に password があり、メールが未確認か
/// （Google だけでログインした人は対象外）
bool needsEmailVerification({
  required bool emailVerified,
  required Iterable<String> providerIds,
}) {
  return !emailVerified && providerIds.contains('password');
}

/// ルーターの振り分け（計画書 4.5 の表）。そのままなら null
String? decideRedirect({
  required String location,
  required bool loggedIn,
  required bool needsEmailVerification,
  required bool needsProfile,
}) {
  final isPublic = location == '/welcome' || location == '/login';
  if (!loggedIn) return isPublic ? null : '/welcome';
  if (needsEmailVerification) {
    return location == '/verify-email' ? null : '/verify-email';
  }
  if (needsProfile) {
    return location == '/profile' ? null : '/profile';
  }
  if (isPublic || location == '/verify-email') return '/';
  return null;
}
