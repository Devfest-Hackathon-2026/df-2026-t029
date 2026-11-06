import '../models/application.dart';
import '../models/reception.dart';

/// 当選者のみの受付を見られるライブの ID（仕様書 4.2、計画書 4.1）。
///
/// 自分の申込状況が 当選（won）か 入金済（paid）のライブ。
/// 申込済・落選・未申込（ドキュメントなし）は含めない。
/// Firestore や画面に依存しない純粋関数（Step6 の通知でも使う）。
Set<String> winnerLiveIds(Map<String, Application> applications) => {
  for (final a in applications.values)
    if (a.status == ApplicationStatus.won || a.status == ApplicationStatus.paid)
      a.liveId,
};

/// その受付を、見る場面（次の締切・ライブ詳細・カレンダーの追加シート）で
/// 表示してよいか。
///
/// winnersOnly でなければ常に true。winnersOnly なら、そのライブ
/// （[Reception.liveId]）で当選している人だけ true。liveId が無い受付は false。
/// 差分の確認・編集では使わない（直す場面では隠さない）。
bool isReceptionVisible(Reception reception, Set<String> winnerLiveIds) {
  if (!reception.winnersOnly) return true;
  final liveId = reception.liveId;
  return liveId != null && winnerLiveIds.contains(liveId);
}

/// ライブ詳細用: 見せる受付と、隠した（当選すると表示される）受付の件数
class VisibleReceptions {
  const VisibleReceptions({required this.visible, required this.hiddenCount});

  final List<Reception> visible;
  final int hiddenCount;
}

/// [receptions] を見せる分と隠す件数に分ける（順序は保つ）
VisibleReceptions splitVisibleReceptions(
  List<Reception> receptions,
  Set<String> winnerLiveIds,
) {
  final visible = <Reception>[
    for (final r in receptions)
      if (isReceptionVisible(r, winnerLiveIds)) r,
  ];
  return VisibleReceptions(
    visible: List.unmodifiable(visible),
    hiddenCount: receptions.length - visible.length,
  );
}
