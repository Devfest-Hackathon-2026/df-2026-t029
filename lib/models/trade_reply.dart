import 'package:cloud_firestore/cloud_firestore.dart';

import 'converters.dart';

/// 投稿への返信（tradePosts/{postId}/replies。DB 設計案 3.11）
class TradeReply {
  const TradeReply({
    this.id,
    required this.uid,
    required this.displayName,
    required this.text,
    this.linkedPostId,
    this.approved = false,
    this.createdAt,
  });

  /// 本文の上限（セキュリティルールと同じ）
  static const int maxTextLength = 1000;

  final String? id;
  final String uid;

  /// 書いた人の表示名（複製）
  final String displayName;
  final String text;

  /// 添付した、書いた人自身の投稿の ID
  final String? linkedPostId;

  /// 投稿者が承認したか（G-5-3）
  final bool approved;

  /// 送信中（サーバー時刻がまだ決まっていない）なら null
  final DateTime? createdAt;

  factory TradeReply.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TradeReply(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      linkedPostId: data['linkedPostId'] as String?,
      approved: data['approved'] as bool? ?? false,
      createdAt: toDateTime(data['createdAt']),
    );
  }
}
