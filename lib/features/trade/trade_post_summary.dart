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

/// タグの行（例：交換希望・買取希望／価格：定価以下）
String tagLine(TradePost post) {
  final tags = post.tags.map((t) => t.label).join('・');
  final price = post.priceType;
  return post.hasPrice && price != null ? '$tags／価格：${price.label}' : tags;
}

/// 譲の品目名の要約（なければ空文字）
String giveSummary(TradePost post) => summarizeLabels([
  for (final s in post.gives)
    for (final i in s.items) i.label,
]);

/// 求の対象名の要約（なければ空文字）
String wantSummary(TradePost post) => summarizeLabels([
  for (final s in post.wants)
    for (final t in s.targets) t.label,
]);

/// 一覧に出す写真（1枚目。投稿全体 → 譲セットの順）。無ければ null（G-7）
String? firstPhotoOf(TradePost post) {
  if (post.images.isNotEmpty) return post.images.first;
  for (final s in post.gives) {
    if (s.images.isNotEmpty) return s.images.first;
  }
  return null;
}

/// 投稿のすべての写真（投稿全体 → 譲セットの順）。掲示板のカードで横に並べる（Fd 4）
List<String> allPhotosOf(TradePost post) => [
  ...post.images,
  for (final s in post.gives) ...s.images,
];

/// 日付だけ（例：2026年11月8日）。掲示板のカードの更新日に使う（Fd 4）
String formatDateOnly(DateTime d) {
  final t = d.toLocal();
  return '${t.year}年${t.month}月${t.day}日';
}