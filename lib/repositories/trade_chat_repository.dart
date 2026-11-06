import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trade_chat.dart';
import '../models/trade_message.dart';
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

/// 返信の承認と、個人チャット（一覧・メッセージ・既読・取引終了）
abstract class TradeChatRepository {
  /// チャットがすでにあるか
  Future<bool> exists(String chatId);

  /// 自分が参加しているチャット（最後のメッセージの新しい順）
  Stream<List<TradeChat>> watchMyChats(String uid);

  /// チャット1件。無ければ null
  Stream<TradeChat?> watchChat(String chatId);

  /// チャットのメッセージ（送った順）
  Stream<List<TradeMessage>> watchMessages(String chatId);

  /// メッセージを送る。メッセージの作成と、チャットの最後のメッセージ・
  /// 送った人の既読の更新を、1回のバッチで書く
  Future<void> sendMessage(
    String chatId, {
    required String uid,
    required String text,
  });

  /// [uid] の既読の日時を、今（サーバー時刻）にする
  Future<void> markRead(String chatId, String uid);

  /// 取引終了・再開
  Future<void> setStatus(String chatId, ChatStatus status);

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
  Stream<TradeChat?> watchChat(String chatId) => _chats
      .doc(chatId)
      .snapshots()
      .map((d) => d.exists ? TradeChat.fromFirestore(d) : null);

  @override
  Stream<List<TradeMessage>> watchMessages(String chatId) => _chats
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => [for (final d in s.docs) TradeMessage.fromFirestore(d)]);

  @override
  Future<void> sendMessage(
    String chatId, {
    required String uid,
    required String text,
  }) async {
    final chat = _chats.doc(chatId);
    final batch = _db.batch()
      ..set(chat.collection('messages').doc(), {
        'uid': uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      })
      // 自分が送ったメッセージで、自分の未読の印が付かないよう、既読も更新する
      ..update(chat, {
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastReadAt.$uid': FieldValue.serverTimestamp(),
      });
    await batch.commit();
  }

  @override
  Future<void> markRead(String chatId, String uid) => _chats.doc(chatId).update(
    {'lastReadAt.$uid': FieldValue.serverTimestamp()},
  );

  @override
  Future<void> setStatus(String chatId, ChatStatus status) =>
      _chats.doc(chatId).update({'status': status.name});

  @override
  Stream<List<TradeChat>> watchMyChats(String uid) => _chats
      .where('memberUids', arrayContains: uid)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) TradeChat.fromFirestore(d)]);

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
