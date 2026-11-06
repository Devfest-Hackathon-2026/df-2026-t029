import 'package:cloud_firestore/cloud_firestore.dart';

import 'converters.dart';

/// チャットの状態（database.md 4章）
enum ChatStatus {
  open('やり取り中'),
  closed('取引終了');

  const ChatStatus(this.label);

  final String label;
}

/// 個人チャット（chats/{chatId}。DB 設計案 3.12）
class TradeChat {
  const TradeChat({
    required this.id,
    required this.postId,
    required this.replyId,
    required this.memberUids,
    required this.memberNames,
    this.postSummary,
    this.lastMessage,
    this.lastMessageAt,
    this.lastReadAt = const {},
    this.status = ChatStatus.open,
    this.createdAt,
  });

  final String id;

  /// きっかけの投稿
  final String postId;

  /// 承認した返信
  final String replyId;

  /// 参加者2人の uid（投稿者・返信した人）
  final List<String> memberUids;

  /// uid → 表示名（複製）
  final Map<String, String> memberNames;

  /// 投稿の要約（一覧の表示用）
  final String? postSummary;

  /// 最後のメッセージ。まだなければ null
  final String? lastMessage;
  final DateTime? lastMessageAt;

  /// uid → 最後に読んだ日時
  final Map<String, DateTime> lastReadAt;
  final ChatStatus status;
  final DateTime? createdAt;

  /// 相手の uid（[me] でないほう）
  String otherUid(String me) =>
      memberUids.firstWhere((u) => u != me, orElse: () => '');

  /// 相手の表示名
  String otherName(String me) => memberNames[otherUid(me)] ?? '';

  /// [me] にとって未読のメッセージがあるか
  /// （最後のメッセージが、最後に読んだ日時より後）
  bool isUnreadFor(String me) {
    final at = lastMessageAt;
    if (lastMessage == null || at == null) return false;
    final read = lastReadAt[me];
    return read == null || at.isAfter(read);
  }

  factory TradeChat.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TradeChat(
      id: doc.id,
      postId: data['postId'] as String? ?? '',
      replyId: data['replyId'] as String? ?? '',
      memberUids: toStringList(data['memberUids']),
      memberNames: {
        for (final e in (data['memberNames'] as Map? ?? const {}).entries)
          '${e.key}': '${e.value}',
      },
      postSummary: data['postSummary'] as String?,
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: toDateTime(data['lastMessageAt']),
      lastReadAt: {
        for (final e in (data['lastReadAt'] as Map? ?? const {}).entries)
          '${e.key}': ?toDateTime(e.value),
      },
      // 知らない値は、やり取りできない側（取引終了）として扱う
      status:
          ChatStatus.values.asNameMap()[data['status']] ?? ChatStatus.closed,
      createdAt: toDateTime(data['createdAt']),
    );
  }
}
