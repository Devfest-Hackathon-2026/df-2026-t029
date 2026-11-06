import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trade_reply.dart';

/// 投稿への返信の取得・作成・削除（承認は G-5-3 で足す）
abstract class TradeReplyRepository {
  /// 投稿の返信（書いた順）
  Stream<List<TradeReply>> watchReplies(String postId);

  /// 返信を作成し、ID を返す。承認前（approved: false）・作成日時は
  /// サーバー時刻で作る。[linkedPostId] は、書いた人自身の投稿のみ
  Future<String> create(
    String postId, {
    required String uid,
    required String displayName,
    required String text,
    String? linkedPostId,
  });

  /// 返信を削除する（書いた本人・承認前のみ。ルールで確かめる）
  Future<void> delete(String postId, String replyId);
}

/// Firestore 版の [TradeReplyRepository]
class FirestoreTradeReplyRepository implements TradeReplyRepository {
  FirestoreTradeReplyRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _replies(String postId) =>
      _db.collection('tradePosts').doc(postId).collection('replies');

  @override
  Stream<List<TradeReply>> watchReplies(String postId) =>
      _replies(postId)
          .orderBy('createdAt')
          .snapshots()
          .map((s) => [for (final d in s.docs) TradeReply.fromFirestore(d)]);

  @override
  Future<String> create(
    String postId, {
    required String uid,
    required String displayName,
    required String text,
    String? linkedPostId,
  }) async {
    final ref = _replies(postId).doc();
    await ref.set({
      'uid': uid,
      'displayName': displayName,
      'text': text,
      'linkedPostId': ?linkedPostId,
      'approved': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<void> delete(String postId, String replyId) =>
      _replies(postId).doc(replyId).delete();
}
