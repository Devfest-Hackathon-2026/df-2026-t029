import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/goods.dart';
import '../models/oshi.dart';
import '../models/trade_post.dart';
import '../utils/trade_keys.dart';

/// 交換・売買の投稿の取得・保存
abstract class TradePostRepository {
  /// ID で投稿を1件取得する。見つからなければ null
  Future<TradePost?> fetch(String id);

  /// 自分の投稿（更新日時の新しい順。非表示にされたものも含む）
  Stream<List<TradePost>> watchMine(String uid);

  /// 推しの募集中の投稿（更新日時の新しい順。掲示板で使う）。
  ///
  /// グループ（[kind] が group）なら `groupIds`、個人なら `oshiIds` に
  /// [oshiId] を含む投稿を探す。募集終了・非表示の投稿は含めない。
  /// [limit] 件まで（「もっと見る」で増やす）
  Stream<List<TradePost>> watchOpenFor(
    OshiKind kind,
    String oshiId, {
    required int limit,
  });

  /// 投稿を新規作成し、ID を返す。
  ///
  /// - uid・表示名・状態（募集中）・作成日時・更新日時は、ここで付ける
  /// - 検索用キーは、譲・求からここで作る（DB 設計案 5章）
  Future<String> create(
    TradePost post, {
    required String uid,
    required String displayName,
  });

  /// 投稿の中身を更新する（作成者のみ。ID 付きの [post] を渡す）。
  ///
  /// - 検索用キーは作り直す
  /// - uid・表示名・状態・作成日時は変えない
  /// - 空になった任意項目（価格の区分・X・備考）は消す
  Future<void> update(TradePost post);

  /// 募集終了・再開（[status] は open か closed）
  Future<void> setStatus(String postId, TradePostStatus status);
}

/// Firestore 版の [TradePostRepository]
class FirestoreTradePostRepository implements TradePostRepository {
  FirestoreTradePostRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('tradePosts');

  @override
  Future<TradePost?> fetch(String id) async {
    final doc = await _posts.doc(id).get();
    return doc.exists ? TradePost.fromFirestore(doc) : null;
  }

  @override
  Stream<List<TradePost>> watchMine(String uid) => _posts
      .where('uid', isEqualTo: uid)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) TradePost.fromFirestore(d)]);

  @override
  Stream<List<TradePost>> watchOpenFor(
    OshiKind kind,
    String oshiId, {
    required int limit,
  }) => _posts
      .where(
        kind == OshiKind.group ? 'groupIds' : 'oshiIds',
        arrayContains: oshiId,
      )
      .where('status', isEqualTo: TradePostStatus.open.name)
      .orderBy('updatedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => [for (final d in s.docs) TradePost.fromFirestore(d)]);

  @override
  Future<String> create(
    TradePost post, {
    required String uid,
    required String displayName,
  }) async {
    final keys = await _keysFor(post);
    final ref = _posts.doc();
    await ref.set({
      ...post.toFirestore(),
      'uid': uid,
      'displayName': displayName,
      'giveKeys': keys.giveKeys,
      'wantKeys': keys.wantKeys,
      'status': TradePostStatus.open.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<void> update(TradePost post) async {
    final id = post.id;
    if (id == null) throw ArgumentError('post に ID がありません');

    final data = post.toFirestore();
    final keys = await _keysFor(post);
    await _posts.doc(id).update({
      ...data,
      for (final f in const ['priceType', 'xAccount', 'note'])
        if (!data.containsKey(f)) f: FieldValue.delete(),
      'giveKeys': keys.giveKeys,
      'wantKeys': keys.wantKeys,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setStatus(String postId, TradePostStatus status) async {
    if (status == TradePostStatus.hidden) {
      throw ArgumentError('非表示は運営だけが設定できます');
    }
    await _posts.doc(postId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 譲・求から検索用キーを作る。譲の品目のグッズを読み、種類のメンバーを調べる
  Future<({List<String> giveKeys, List<String> wantKeys})> _keysFor(
    TradePost post,
  ) async {
    final goodsIds = {
      for (final s in post.gives)
        for (final i in s.items) i.goodsId,
    };
    final docs = await Future.wait([
      for (final id in goodsIds) _db.collection('goods').doc(id).get(),
    ]);
    final goodsById = {
      for (final d in docs)
        if (d.exists) d.id: Goods.fromFirestore(d),
    };
    return (
      giveKeys: buildGiveKeys(post.gives, goodsById),
      wantKeys: buildWantKeys(post.wants),
    );
  }
}
