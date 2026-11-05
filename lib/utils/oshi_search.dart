import '../models/oshi.dart';
import 'text_normalizer.dart';

/// 推しを検索する（計画書 3.1・3.3）。Firestore に依存しない純粋関数。
///
/// - [query] を正規化して空文字なら、承認済みの推しだけを名前順に返す。
/// - それ以外は、正規化した名前・別名のどれかに [query] を含むものを返す。
///   申請中も含む。
/// - 並び順: 完全一致 → 前方一致 → 部分一致。同順位なら承認済み → 申請中、
///   その次に名前（正規化後）順。
List<OshiSummary> searchOshis(List<OshiSummary> all, String query) {
  final q = normalizeName(query);
  if (q.isEmpty) {
    final approved = all.where((o) => o.isApproved).toList();
    approved.sort(_byName);
    return approved;
  }

  final ranked = <(OshiSummary, int)>[];
  for (final o in all) {
    final rank = _rank(o, q);
    if (rank != null) ranked.add((o, rank));
  }
  ranked.sort((a, b) {
    final byRank = a.$2.compareTo(b.$2);
    if (byRank != 0) return byRank;
    final byStatus = _statusOrder(a.$1).compareTo(_statusOrder(b.$1));
    if (byStatus != 0) return byStatus;
    return _byName(a.$1, b.$1);
  });
  return [for (final r in ranked) r.$1];
}

/// 申請しようとしている推しと、正規化後に完全一致する既存の推しを返す（計画書 3.2）。
///
/// 新しい「名前と別名すべて」と、既存の「名前と別名すべて」を突き合わせる
/// （名前どうし・名前と別名・別名どうしのすべて）。対象は [kind] と同じ種別だけで、
/// 申請中も含む。正規化して空文字になるものは比べない。
/// 並び順は、承認済み → 申請中、その次に名前順。
List<OshiSummary> findExactDuplicates(
  List<OshiSummary> all, {
  required OshiKind kind,
  required String name,
  List<String> aliases = const [],
}) {
  final keys = _keysOf(name, aliases);
  if (keys.isEmpty) return const [];
  final result = all
      .where((o) => o.kind == kind)
      .where((o) => _keysOf(o.name, o.aliases).any(keys.contains))
      .toList();
  result.sort((a, b) {
    final byStatus = _statusOrder(a).compareTo(_statusOrder(b));
    if (byStatus != 0) return byStatus;
    return _byName(a, b);
  });
  return result;
}

Set<String> _keysOf(String name, List<String> aliases) => {
  for (final s in [name, ...aliases]) normalizeName(s),
}..remove('');

/// 0: 完全一致、1: 前方一致、2: 部分一致、null: 一致しない
int? _rank(OshiSummary o, String q) {
  int? best;
  for (final key in _keysOf(o.name, o.aliases)) {
    final int? r;
    if (key == q) {
      r = 0;
    } else if (key.startsWith(q)) {
      r = 1;
    } else if (key.contains(q)) {
      r = 2;
    } else {
      r = null;
    }
    if (r != null && (best == null || r < best)) best = r;
    if (best == 0) break;
  }
  return best;
}

int _statusOrder(OshiSummary o) => o.isApproved ? 0 : 1;

int _byName(OshiSummary a, OshiSummary b) {
  final byNormalized = normalizeName(a.name).compareTo(normalizeName(b.name));
  if (byNormalized != 0) return byNormalized;
  final byName = a.name.compareTo(b.name);
  if (byName != 0) return byName;
  final byKind = a.kind.index.compareTo(b.kind.index);
  if (byKind != 0) return byKind;
  return a.id.compareTo(b.id);
}
