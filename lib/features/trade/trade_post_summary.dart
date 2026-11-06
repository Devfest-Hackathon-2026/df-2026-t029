import '../../models/oshi.dart';
import '../../models/trade_post.dart';

/// 表示名を最初の [max] 個まで「、」でつなぎ、残りは「ほか N 件」にする。
/// 同じ表示名は1つにまとめる
String summarizeLabels(List<String> labels, {int max = 3}) {
  final unique = labels.toSet().toList();
  if (unique.length <= max) return unique.join('、');
  return '${unique.take(max).join('、')} ほか${unique.length - max}件';
}

/// 投稿の対象の推しの名前（グループ → 個人の順。読み込めていないものは省く）
String targetNames(TradePost post, List<OshiSummary> all) {
  final byKey = {for (final o in all) (o.kind, o.id): o.name};
  return [
    for (final id in post.groupIds) ?byKey[(OshiKind.group, id)],
    for (final id in post.oshiIds) ?byKey[(OshiKind.person, id)],
  ].join('、');
}
