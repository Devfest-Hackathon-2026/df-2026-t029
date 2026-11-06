import '../models/goods.dart';
import '../models/trade_post.dart';
import 'trade_keys.dart';

/// 自分の投稿1件と相手の投稿1件の組のマッチ
class PostPairMatch {
  const PostPairMatch({
    required this.mine,
    required this.theirs,
    required this.theyGive,
    required this.iGive,
    required this.isMutual,
  });

  /// 自分の投稿
  final TradePost mine;

  /// 相手の投稿
  final TradePost theirs;

  /// 相手の譲のうち、自分の求に一致した品目（重複なし・相手の投稿の順）
  final List<GiveItem> theyGive;

  /// 自分の譲のうち、相手の求に一致した品目（片方マッチなら空）
  final List<GiveItem> iGive;

  /// 相互マッチか（自分の譲が相手の求にも一致している）
  final bool isMutual;
}

/// 相手の投稿1件のマッチ（自分の投稿との組をまとめたもの）
class TradeMatch {
  const TradeMatch({required this.theirs, required this.pairs});

  final TradePost theirs;

  /// 一致した自分の投稿との組（相互マッチの組 → 片方マッチの組の順。1件以上）
  final List<PostPairMatch> pairs;

  bool get isMutual => pairs.first.isMutual;

  /// いちばん良い組（相互マッチがあればその1つ目）
  PostPairMatch get best => pairs.first;
}

/// マッチの判定（DB 設計案 5章「マッチングの検索」）。
///
/// 自分の募集中の投稿 [mine] と、相手の投稿の候補 [candidates] の組ごとに、
/// - 相手の `giveKeys` と自分の `wantKeys` が1つでも一致 → 片方マッチ
/// - さらに相手の `wantKeys` と自分の `giveKeys` も一致 → 相互マッチ
///
/// とする。判定は保存済みの検索用キーで行い、一致した品目の表示には
/// [goodsById]（品目のグッズ。種類のメンバーを調べる）を使う。
/// 自分の投稿・募集中でない投稿は除く。
///
/// 結果は相手の投稿ごとにまとめ、相互マッチ → 片方マッチの順、
/// 同じ中では相手の投稿の更新日時の新しい順に並べる。
List<TradeMatch> matchTradePosts({
  required List<TradePost> mine,
  required List<TradePost> candidates,
  required Map<String, Goods> goodsById,
}) {
  final myOpen = [
    for (final m in mine)
      if (m.status == TradePostStatus.open) m,
  ];
  final myUids = {for (final m in mine) m.uid};
  final result = <TradeMatch>[];
  for (final theirs in candidates) {
    if (theirs.status != TradePostStatus.open) continue;
    if (myUids.contains(theirs.uid)) continue;
    final pairs = <PostPairMatch>[];
    for (final m in myOpen) {
      final theyGiveKeys = theirs.giveKeys.toSet()
        ..retainAll(m.wantKeys.toSet());
      if (theyGiveKeys.isEmpty) continue;
      final iGiveKeys = m.giveKeys.toSet()..retainAll(theirs.wantKeys.toSet());
      pairs.add(
        PostPairMatch(
          mine: m,
          theirs: theirs,
          theyGive: _itemsMatching(theirs, theyGiveKeys, goodsById),
          iGive: _itemsMatching(m, iGiveKeys, goodsById),
          isMutual: iGiveKeys.isNotEmpty,
        ),
      );
    }
    if (pairs.isEmpty) continue;
    // 相互マッチの組を先に（同じ中では元の順のまま）
    final sorted = [
      ...pairs.where((p) => p.isMutual),
      ...pairs.where((p) => !p.isMutual),
    ];
    result.add(TradeMatch(theirs: theirs, pairs: sorted));
  }

  int byUpdated(TradeMatch a, TradeMatch b) {
    final at = a.theirs.updatedAt;
    final bt = b.theirs.updatedAt;
    if (at == null || bt == null) {
      return (at == null ? 0 : 1) - (bt == null ? 0 : 1);
    }
    return bt.compareTo(at);
  }

  return [
    ...result.where((m) => m.isMutual).toList()..sort(byUpdated),
    ...result.where((m) => !m.isMutual).toList()..sort(byUpdated),
  ];
}

/// [post] の譲の品目のうち、キーが [keys] のどれかに当たるもの（重複なし）
List<GiveItem> _itemsMatching(
  TradePost post,
  Set<String> keys,
  Map<String, Goods> goodsById,
) {
  if (keys.isEmpty) return const [];
  final seen = <String>{};
  return [
    for (final s in post.gives)
      for (final item in s.items)
        if (giveItemKeys(item, goodsById).any(keys.contains) &&
            seen.add('${item.goodsId}#${item.variantId}'))
          item,
  ];
}

/// 一致した品目の表示に必要なグッズの ID（[mine] と [candidates] の譲の品目）
Set<String> goodsIdsForMatching(
  List<TradePost> mine,
  List<TradePost> candidates,
) => {
  for (final p in [...mine, ...candidates])
    for (final s in p.gives)
      for (final i in s.items) i.goodsId,
};
