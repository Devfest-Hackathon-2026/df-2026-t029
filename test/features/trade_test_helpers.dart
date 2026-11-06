import 'dart:async';

import 'package:oshiashi/models/goods.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/models/trade_post.dart';
import 'package:oshiashi/repositories/goods_repository.dart';
import 'package:oshiashi/repositories/trade_post_repository.dart';

/// 呼ばれた引数を記録する、投稿の偽のリポジトリ
class FakeTradePostRepository implements TradePostRepository {
  final posts = <String, TradePost>{};
  final mine = StreamController<List<TradePost>>.broadcast();
  final watchedUids = <String>[];
  int fetchCount = 0;

  /// create に渡されたもの
  final created = <({TradePost post, String uid, String displayName})>[];

  /// update に渡されたもの
  final updated = <TradePost>[];

  /// setStatus に渡されたもの
  final statusChanges = <(String, TradePostStatus)>[];

  /// 設定すると、create・update・setStatus はこれを投げる
  Object? error;

  @override
  Future<TradePost?> fetch(String id) async {
    fetchCount++;
    return posts[id];
  }

  /// 設定すると、watchMine は購読した時点でこの一覧を流す
  /// （本物の Firestore と同じく、あとから購読しても今の値が届く）
  List<TradePost>? mineInitial;

  @override
  Stream<List<TradePost>> watchMine(String uid) {
    watchedUids.add(uid);
    // async* は購読の開始が一拍遅れるので、初期値がないときは使わない
    final initial = mineInitial;
    if (initial == null) return mine.stream;
    return _withInitial(initial, mine.stream);
  }

  static Stream<T> _withInitial<T>(T initial, Stream<T> rest) async* {
    yield initial;
    yield* rest;
  }

  /// watchOpenFor の中身（推しの種類と ID → 流すストリーム）
  final open = StreamController<List<TradePost>>.broadcast();
  final watchedOpen = <(OshiKind, String, int)>[];

  /// 設定すると、watchOpenFor は推しごとにこの一覧を返す（[open] は使わない）
  Map<(OshiKind, String), List<TradePost>>? openByTarget;

  @override
  Stream<List<TradePost>> watchOpenFor(
    OshiKind kind,
    String oshiId, {
    required int limit,
  }) {
    watchedOpen.add((kind, oshiId, limit));
    if (openByTarget case final m?) {
      return Stream.value((m[(kind, oshiId)] ?? const []).take(limit).toList());
    }
    return open.stream;
  }

  /// fetchOpenGiving で返す投稿（giveKeys と status で絞って返す）
  List<TradePost> allPosts = const [];

  /// fetchOpenGiving に渡されたキー
  final givingQueries = <List<String>>[];

  @override
  Future<List<TradePost>> fetchOpenGiving(Iterable<String> keys) async {
    final k = keys.toSet();
    givingQueries.add(k.toList());
    return [
      for (final p in allPosts)
        if (p.status == TradePostStatus.open && p.giveKeys.any(k.contains)) p,
    ];
  }

  @override
  Future<String> create(
    TradePost post, {
    required String uid,
    required String displayName,
  }) async {
    if (error case final e?) throw e;
    created.add((post: post, uid: uid, displayName: displayName));
    return 'new-post';
  }

  @override
  Future<void> update(TradePost post) async {
    if (error case final e?) throw e;
    updated.add(post);
  }

  @override
  Future<void> setStatus(String postId, TradePostStatus status) async {
    if (error case final e?) throw e;
    statusChanges.add((postId, status));
  }
}

/// 投稿を短く作る
TradePost postOf(
  String id, {
  String uid = 'u1',
  List<String> groupIds = const ['g1'],
  List<TradeTag> tags = const [TradeTag.trade],
  List<HandoverMethod> handover = const [HandoverMethod.mail],
  TradePostStatus status = TradePostStatus.open,
  List<GiveSet> gives = const [],
  List<WantSet> wants = const [],
  List<String> performanceIds = const [],
}) => TradePost(
  id: id,
  uid: uid,
  displayName: '匿名',
  groupIds: groupIds,
  tags: tags,
  handover: handover,
  status: status,
  gives: gives,
  wants: wants,
  performanceIds: performanceIds,
);

/// fetchFor で、対象の推しに当てはまるグッズを返す偽のリポジトリ
class FakeGoodsRepository implements GoodsRepository {
  FakeGoodsRepository([this.goods = const []]);

  List<Goods> goods;
  int fetchForCount = 0;

  @override
  Future<List<Goods>> fetchFor({
    List<String> groupIds = const [],
    List<String> oshiIds = const [],
  }) async {
    fetchForCount++;
    return [
      for (final g in goods)
        if (g.groupIds.any(groupIds.contains) ||
            g.oshiIds.any(oshiIds.contains))
          g,
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  /// fetch に渡された ID
  final fetchedIds = <String>[];

  @override
  Future<Goods?> fetch(String id) async {
    fetchedIds.add(id);
    return goods.where((g) => g.id == id).firstOrNull;
  }

  @override
  Future<String> create(Goods goods, {required String uid}) =>
      throw UnimplementedError();

  @override
  Future<void> update({
    required Goods before,
    required Goods after,
    required String uid,
  }) => throw UnimplementedError();
}
