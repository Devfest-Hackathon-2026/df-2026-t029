// lib/models/trade_chat.dart（G-5-4）のテスト
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/trade_chat.dart';

TradeChat chat({
  String? lastMessage = 'こんにちは',
  DateTime? lastMessageAt,
  Map<String, DateTime> lastReadAt = const {},
}) => TradeChat(
  id: 'p1_b',
  postId: 'p1',
  replyId: 'r1',
  memberUids: const ['a', 'b'],
  memberNames: const {'a': '投稿者', 'b': '返信した人'},
  lastMessage: lastMessage,
  lastMessageAt: lastMessageAt ?? DateTime(2026, 11, 6, 12),
  lastReadAt: lastReadAt,
);

void main() {
  test('相手の uid と表示名', () {
    expect(chat().otherUid('a'), 'b');
    expect(chat().otherName('a'), '返信した人');
    expect(chat().otherName('b'), '投稿者');
  });

  group('isUnreadFor', () {
    test('まだ読んでいなければ未読', () {
      expect(chat().isUnreadFor('a'), isTrue);
    });

    test('最後のメッセージより後に読んでいれば既読、前なら未読', () {
      final c = chat(
        lastReadAt: {
          'a': DateTime(2026, 11, 6, 13),
          'b': DateTime(2026, 11, 6, 11),
        },
      );
      expect(c.isUnreadFor('a'), isFalse);
      expect(c.isUnreadFor('b'), isTrue);
    });

    test('メッセージがまだなければ未読にしない', () {
      expect(chat(lastMessage: null).isUnreadFor('a'), isFalse);
    });
  });

  test('fromFirestore：項目を読み、知らない状態は取引終了として扱う', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('chats').doc('p1_b').set({
      'postId': 'p1',
      'replyId': 'r1',
      'memberUids': ['a', 'b'],
      'memberNames': {'a': '投稿者', 'b': '返信した人'},
      'postSummary': 'アクスタ',
      'lastMessage': 'よろしく',
      'lastMessageAt': Timestamp.fromDate(DateTime(2026, 11, 6, 12)),
      'lastReadAt': {'a': Timestamp.fromDate(DateTime(2026, 11, 6, 13))},
      'status': 'xxx',
      'createdAt': Timestamp.fromDate(DateTime(2026, 11, 6, 10)),
    });
    final c = TradeChat.fromFirestore(
      await db.collection('chats').doc('p1_b').get(),
    );
    expect(c.id, 'p1_b');
    expect(c.memberNames['b'], '返信した人');
    expect(c.postSummary, 'アクスタ');
    expect(c.lastReadAt['a'], DateTime(2026, 11, 6, 13));
    expect(c.status, ChatStatus.closed);
    expect(c.isUnreadFor('a'), isFalse);
  });
}
