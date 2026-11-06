import '../models/trade_post.dart';

/// 掲示板に出す投稿と、続きがあるか
class TradeBoard {
  const TradeBoard({required this.posts, required this.hasMore});

  static const TradeBoard empty = TradeBoard(posts: [], hasMore: false);

  final List<TradePost> posts;

  /// 「もっと見る」を出すか
  final bool hasMore;
}

/// 推しごとに検索した投稿（それぞれ更新日時の新しい順・最大 [limit] 件）を
/// まとめて、掲示板の [limit] 件を作る。
///
/// - 同じ投稿（複数の推しが対象のもの）は1つにまとめる
/// - 更新日時の新しい順に並べる。保存中で日時がまだないものは先頭に置く
/// - どれかの検索が [limit] 件ちょうど返していたら、その先にまだ投稿が
///   あるかもしれないので、続きがあるとする
TradeBoard mergeBoardPosts(List<List<TradePost>> lists, int limit) {
  final byId = <String?, TradePost>{
    for (final list in lists)
      for (final p in list) p.id: p,
  };
  final merged = byId.values.toList()
    ..sort((a, b) {
      final at = a.updatedAt;
      final bt = b.updatedAt;
      if (at == null || bt == null) {
        return (at == null ? 0 : 1) - (bt == null ? 0 : 1);
      }
      return bt.compareTo(at);
    });
  return TradeBoard(
    posts: merged.take(limit).toList(),
    hasMore: merged.length > limit || lists.any((l) => l.length >= limit),
  );
}

/// 掲示板のグッズの絞り込みで、譲・求のどちらを見るか
enum BoardSide {
  any('どちらでも'),
  give('譲'),
  want('求');

  const BoardSide(this.label);

  final String label;
}

/// 掲示板の絞り込みの条件（アプリ側で、読み込んだ投稿に対して行う）
class BoardFilter {
  const BoardFilter({
    this.goodsId,
    this.goodsName,
    this.side = BoardSide.any,
    this.tags = const {},
    this.performanceId,
    this.performanceLabel,
  });

  static const BoardFilter none = BoardFilter();

  /// グッズ。null なら指定なし
  final String? goodsId;

  /// グッズ名（条件のチップの表示用）
  final String? goodsName;

  /// グッズを選んだときは、そのグッズを譲・求のどちらに含むか。
  /// グッズを選ばないときは、譲・求があるか
  final BoardSide side;

  /// タグ。どれかを含む投稿を出す。空なら指定なし
  final Set<TradeTag> tags;

  /// 手渡しの公演。null なら指定なし
  final String? performanceId;

  /// 公演の表示名（条件のチップの表示用）
  final String? performanceLabel;

  bool get isEmpty =>
      goodsId == null &&
      side == BoardSide.any &&
      tags.isEmpty &&
      performanceId == null;

  /// 指定している条件の数（ボタンの表示用）
  int get count =>
      (goodsId != null || side != BoardSide.any ? 1 : 0) +
      (tags.isNotEmpty ? 1 : 0) +
      (performanceId != null ? 1 : 0);

  BoardFilter withoutGoods() => BoardFilter(
    tags: tags,
    performanceId: performanceId,
    performanceLabel: performanceLabel,
  );

  BoardFilter withoutTags() => BoardFilter(
    goodsId: goodsId,
    goodsName: goodsName,
    side: side,
    performanceId: performanceId,
    performanceLabel: performanceLabel,
  );

  BoardFilter withoutPerformance() => BoardFilter(
    goodsId: goodsId,
    goodsName: goodsName,
    side: side,
    tags: tags,
  );

  /// 投稿が条件に合うか
  bool matches(TradePost p) {
    if (!_matchesGoods(p)) return false;
    if (tags.isNotEmpty && !p.tags.any(tags.contains)) return false;
    if (performanceId != null &&
        !(p.handover.contains(HandoverMethod.hand) &&
            p.performanceIds.contains(performanceId))) {
      return false;
    }
    return true;
  }

  bool _matchesGoods(TradePost p) {
    final g = goodsId;
    final inGives = p.gives.any(
      (s) => s.items.any((i) => g == null || i.goodsId == g),
    );
    // メンバー指定の求は、グッズの絞り込みでは引っかけない
    final inWants = p.wants.any(
      (s) => s.targets.any(
        (t) => g == null ? true : t.type != WantType.member && t.goodsId == g,
      ),
    );
    return switch (side) {
      BoardSide.give => inGives,
      BoardSide.want => inWants,
      BoardSide.any => g == null || inGives || inWants,
    };
  }
}
