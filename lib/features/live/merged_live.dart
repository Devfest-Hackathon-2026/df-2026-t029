import '../../utils/deadline.dart';
import '../../utils/text_normalizer.dart';
import 'live_list_entries.dart' show PerformerNames;

/// 同じライブをまとめた1件（fix_Ff Ff-10）
class MergedLive {
  const MergedLive({
    required this.entry,
    required this.liveIds,
    required this.performers,
  });

  /// 代表（グループに付いているもの → 人が登録したもの → 先頭）
  final LiveListEntry entry;

  /// まとめたライブの ID（代表を含む）
  final List<String> liveIds;

  /// 出演者の名前（重なりを除く。代表の出演者が先）
  final List<String> performers;

  /// [ids] のどれかを含むか（自分の一覧にある・既読、の判定に使う）
  bool containsAny(Set<String> ids) => liveIds.any(ids.contains);
}

/// 同じライブかどうかのキー：ライブ名（そろえたもの）と、次の公演の日（端末の日付）
String _keyOf(LiveListEntry e) {
  final at = (e.nextStartAt ?? e.performances.firstOrNull?.startAt)?.toLocal();
  final day = at == null ? '' : '${at.year}-${at.month}-${at.day}';
  return '${normalizeName(e.live.title)}|$day';
}

/// 同じライブを1件にまとめる。並びは、それぞれが最初に出てきた順のまま
List<MergedLive> mergeSameLives(
  List<LiveListEntry> entries,
  PerformerNames? names,
) {
  final byKey = <String, List<LiveListEntry>>{};
  for (final e in entries) {
    (byKey[_keyOf(e)] ??= []).add(e);
  }
  return [for (final list in byKey.values) _merge(list, names)];
}

MergedLive _merge(List<LiveListEntry> list, PerformerNames? names) {
  final rep =
      list.where((e) => e.live.groupIds.isNotEmpty).firstOrNull ??
      list.where((e) => !e.live.isAi).firstOrNull ??
      list.first;
  final performers = <String>[];
  for (final e in [rep, ...list.where((x) => !identical(x, rep))]) {
    for (final n in names?.of(e.live) ?? const <String>[]) {
      if (!performers.contains(n)) performers.add(n);
    }
  }
  return MergedLive(
    entry: rep,
    liveIds: [for (final e in list) ?e.live.id],
    performers: performers,
  );
}