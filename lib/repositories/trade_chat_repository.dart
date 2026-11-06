import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trade_post.dart';
import '../models/trade_reply.dart';

/// 個人チャットの ID（DB 設計案 3.12。同じ投稿で同じ相手とのチャットは1つ）
String chatIdFor(String postId, String replierUid) => '${postId}_$replierUid';

/// チャットの一覧に出す、投稿の要約（譲の最初の品目、なければ求の最初の対象。
/// ルールに合わせて100文字まで）。品目がなければ null
String? chatPostSummary(TradePost post) {
  final first = [
    for (final s in post.gives)
      for (final i in s.items) i.label,
    for (final s in post.wants)
      for (final t in s.targets) t.label,
  ].where((l) => l.isNotEmpty).firstOrNull;
  if (first == null) return null;
  return first.length <= 100 ? first : first.substring(0, 100);
}

/// 返信の承認と、個人チャット（G-5-4・G-5-5 で一覧・メッセージを足す）
abstract class TradeChatRepository {
  /// チャットがすでにあるか
  Future<bool> exists(String chatId);

  /// 返信を承認し、返信した人とのチャットを作る（1回のバッチで書く）。
  /// 作ったチャットの ID を返す。投稿者だけが行える（ルールで確かめる）
  Future<String> approveReply({
    required TradePost post,
    required TradeReply reply,
  });
}

/// Firestore 版の [TradeChatRepository]
class FirestoreTradeChatRepository implements TradeChatRepository {
  FirestoreTradeChatRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  @override
  Future<bool> exists(String chatId) async =>
      (await _chats.doc(chatId).get()).exists;

  @override
  Future<String> approveReply({
    required TradePost post,
    required TradeReply reply,
  }) async {
    final postId = post.id!;
    final chatId = chatIdFor(postId, reply.uid);
    final summary = chatPostSummary(post);
    final batch = _db.batch()
      ..update(
        _db
            .collection('tradePosts')
            .doc(postId)
            .collection('replies')
            .doc(reply.id),
        {'approved': true},
      )
      ..set(_chats.doc(chatId), {
        'postId': postId,
        'replyId': reply.id,
        'memberUids': [post.uid, reply.uid],
        'memberNames': {
          post.uid: post.displayName,
          reply.uid: reply.displayName,
        },
        'postSummary': ?summary,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
    await batch.commit();
    return chatId;
  }
}
