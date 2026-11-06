import '../models/goods.dart';
import 'text_normalizer.dart';

/// グッズを検索する。Firestore に依存しない純粋関数（推しの検索と同じ考え方）。
///
/// - [query] を正規化して空文字なら、すべてを名前順に返す
/// - それ以外は、正規化した名前・別名のどれかに [query] を含むものを返す
/// - 並び順: 完全一致 → 前方一致 → 部分一致。同順位なら名前順
List<Goods> searchGoods(List<Goods> all, String query) {
  final q = normalizeName(query);
  if (q.isEmpty) return [...all]..sort(_byName);

  final ranked = <(Goods, int)>[];
  for (final g in all) {
    final rank = _rank(g, q);
    if (rank != null) ranked.add((g, rank));
  }
  ranked.sort((a, b) {
    final byRank = a.$2.compareTo(b.$2);
    return byRank != 0 ? byRank : _byName(a.$1, b.$1);
  });
  return [for (final r in ranked) r.$1];
}

Set<String> _keysOf(Goods g) => {
  for (final s in [g.name, ...g.aliases]) normalizeName(s),
}..remove('');

/// 0: 完全一致、1: 前方一致、2: 部分一致、null: 一致しない
int? _rank(Goods g, String q) {
  int? best;
  for (final key in _keysOf(g)) {
    final int? r = key == q
        ? 0
        : key.startsWith(q)
            ? 1
            : key.contains(q)
                ? 2
                : null;
    if (r != null && (best == null || r < best)) best = r;
  }
  return best;
}

int _byName(Goods a, Goods b) {
  final byNormalized = normalizeName(a.name).compareTo(normalizeName(b.name));
  if (byNormalized != 0) return byNormalized;
  return a.name.compareTo(b.name);
}