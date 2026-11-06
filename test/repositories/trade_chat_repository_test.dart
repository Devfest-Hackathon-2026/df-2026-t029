// lib/repositories/trade_chat_repository.dart の承認（G-5-3）のテスト
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/trade_post.dart';
import 'package:oshiashi/models/trade_reply.dart';
import 'package:oshiashi/repositories/trade_chat_repository.dart';

TradePost post({
  List<GiveSet> gives = const [],
  List<WantSet> wants = const [],
}) => TradePost(
  id: 'p1',
  uid: 'owner',
  displayName: '匿名',
  tags: const [TradeTag.trade],
  handover: const [HandoverMethod.mail],
  gives: gives,
  wants: wants,
);

const reply = TradeReply(
  id: 'r1',
  uid: 'replier',
  displayName: '匿名2',
  text: 'お願いします',
);

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreTradeChatRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = FirestoreTradeChatRepository(db);
    await db
        .collection('tradePosts')
        .doc('p1')
        .collection('replies')
        .doc('r1')
        .set({
          'uid': 'replier',
          'displayName': '匿名2',
          'text': 'お願いします',
          'approved': false,
          'createdAt': Timestamp.now(),
        });
  });

  test('chatIdFor：{投稿の ID}_{返信した人の uid}', () {
    expect(chatIdFor('p1', 'u2'), 'p1_u2');
  });

  group('chatPostSummary', () {
    test('譲の最初の品目、なければ求の最初の対象、どちらもなければ null', () {
      expect(
        chatPostSummary(
          post(
            gives: const [
              GiveSet(
                items: [GiveItem(goodsId: 'a', variantId: 'v', label: '譲A')],
              ),
            ],
            wants: const [
              WantSet(
                targets: [
                  WantTarget(type: WantType.goods, goodsId: 'b', label: '求B'),
                ],
              ),
            ],
          ),
        ),
        '譲A',
      );
      expect(
        chatPostSummary(
          post(
            wants: const [
              WantSet(
                targets: [
                  WantTarget(type: WantType.goods, goodsId: 'b', label: '求B'),
                ],
              ),
            ],
          ),
        ),
        '求B',
      );
      expect(chatPostSummary(post()), isNull);
    });

    test('100文字で切る', () {
      final long = 'あ' * 150;
      final s = chatPostSummary(
        post(
          gives: [
            GiveSet(
              items: [GiveItem(goodsId: 'a', variantId: 'v', label: long)],
            ),
          ],
        ),
      );
      expect(s, hasLength(100));
    });
  });

  test('approveReply：返信を承認済みにし、チャットを作る', () async {
    final id = await repo.approveReply(
      post: post(
        gives: const [
          GiveSet(
            items: [GiveItem(goodsId: 'a', variantId: 'v', label: 'アクスタ')],
          ),
        ],
      ),
      reply: reply,
    );
    expect(id, 'p1_replier');

    final r = await db
        .collection('tradePosts')
        .doc('p1')
        .collection('replies')
        .doc('r1')
        .get();
    expect(r.data()!['approved'], isTrue);

    final chat = (await db.collection('chats').doc(id).get()).data()!;
    expect(chat['postId'], 'p1');
    expect(chat['replyId'], 'r1');
    expect(chat['memberUids'], ['owner', 'replier']);
    expect(chat['memberNames'], {'owner': '匿名', 'replier': '匿名2'});
    expect(chat['postSummary'], 'アクスタ');
    expect(chat['status'], 'open');
    expect(chat['lastMessageAt'], isA<Timestamp>());
    expect(chat['createdAt'], isA<Timestamp>());
    // 作成時は書かない項目
    expect(chat.containsKey('lastMessage'), isFalse);
    expect(chat.containsKey('lastReadAt'), isFalse);
  });

  test('approveReply：品目がなければ postSummary を書かない', () async {
    final id = await repo.approveReply(post: post(), reply: reply);
    final chat = (await db.collection('chats').doc(id).get()).data()!;
    expect(chat.containsKey('postSummary'), isFalse);
  });

  test('exists：チャットがあるか', () async {
    expect(await repo.exists('p1_replier'), isFalse);
    await repo.approveReply(post: post(), reply: reply);
    expect(await repo.exists('p1_replier'), isTrue);
  });
}
