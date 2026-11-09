/// 遠征の個人の設定（`users/{uid}/settings/travel`。add_M 3.1）
class TravelSettings {
  const TravelSettings({this.homeStation});

  static const empty = TravelSettings();

  /// 帰りの駅の文字数の上限
  static const int maxStationLength = 50;

  /// 帰りの駅（無ければ null）
  final String? homeStation;

  /// 欠けている・型が違う・空のときは [empty]
  factory TravelSettings.fromMap(Map<String, dynamic>? data) {
    final s = data?['homeStation'];
    if (s is! String) return empty;
    final t = s.trim();
    return t.isEmpty ? empty : TravelSettings(homeStation: t);
  }
}