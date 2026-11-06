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
