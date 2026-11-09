/// 公開プロフィール（`publicProfiles/{uid}`。add_I 3.2）。
/// ログイン済みなら誰でも読める。アイコンをほかの人に出すのに使う
class PublicProfile {
  const PublicProfile({this.displayName, this.iconPath});

  /// ハンドルネーム（プロフィールの保存のときに書く。まだ無いこともある）
  final String? displayName;

  /// アイコンの Storage のパス（`userIcons/{uid}/...`）。無ければ null
  final String? iconPath;

  factory PublicProfile.fromMap(Map<String, dynamic> data) {
    String? text(Object? v) => v is String && v.isNotEmpty ? v : null;
    return PublicProfile(
      displayName: text(data['displayName']),
      iconPath: text(data['iconPath']),
    );
  }
}
