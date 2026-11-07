import 'package:cloud_firestore/cloud_firestore.dart';

import 'converters.dart';

/// チャットのメッセージ（chats/{chatId}/messages。DB 設計案 3.13）。
/// 文字のみで、作成後の編集・削除はできない
class TradeMessage {
  const TradeMessage({
    required this.id,
    required this.uid,
    required this.text,
    this.createdAt,
  });

  /// 本文の上限（セキュリティルールと同じ）
  static const int maxTextLength = 1000;

  final String id;

  /// 送信者の uid
  final String uid;
  final String text;

  /// 送信中（サーバー時刻がまだ決まっていない）なら null
  final DateTime? createdAt;

  factory TradeMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return TradeMessage(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: toDateTime(data['createdAt']),
    );
  }
}
