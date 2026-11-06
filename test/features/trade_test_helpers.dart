import 'dart:async';

import 'package:oshiashi/models/trade_post.dart';
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

  @override
  Stream<List<TradePost>> watchMine(String uid) {
    watchedUids.add(uid);
    return mine.stream;
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
);
