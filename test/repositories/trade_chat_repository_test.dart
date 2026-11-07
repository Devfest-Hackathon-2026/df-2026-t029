// lib/repositories/trade_chat_repository.dart の承認（G-5-3）・一覧（G-5-4）・メッセージ（G-5-5）のテスト
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/trade_chat.dart';
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
    // 承認すると投稿も更新する（募集終了）ので、投稿本体を用意しておく
    await db.collection('tradePosts').doc('p1').set({
      'uid': 'owner',
      'status': 'open',
    });
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

    // 承認と同時に、投稿は募集終了になる
    final p = await db.collection('tradePosts').doc('p1').get();
    expect(p.data()!['status'], 'closed');
    expect(p.data()!['updatedAt'], isA<Timestamp>());

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

  test('watchMyChats：自分が参加しているチャットを、最後のメッセージの新しい順に', () async {
    Future<void> put(String id, List<String> members, int hour) =>
        db.collection('chats').doc(id).set({
          'postId': 'p',
          'replyId': 'r',
          'memberUids': members,
          'memberNames': {for (final m in members) m: '匿名'},
          'lastMessageAt': Timestamp.fromDate(DateTime(2026, 11, 6, hour)),
          'status': 'open',
          'createdAt': Timestamp.fromDate(DateTime(2026, 11, 6, 1)),
        });
    await put('old', ['me', 'x'], 10);
    await put('new', ['y', 'me'], 12);
    await put('others', ['x', 'y'], 13);

    final list = await repo.watchMyChats('me').first;
    expect(list.map((c) => c.id), ['new', 'old']);
  });

  group('チャット画面', () {
    setUp(() => repo.approveReply(post: post(), reply: reply));

    test('sendMessage：メッセージを作り、最後のメッセージと自分の既読を更新する', () async {
      await repo.sendMessage('p1_replier', uid: 'replier', text: 'こんにちは');
      final msgs = await db
          .collection('chats')
          .doc('p1_replier')
          .collection('messages')
          .get();
      final m = msgs.docs.single.data();
      expect(m.keys.toSet(), {'uid', 'text', 'createdAt'});
      expect(m['uid'], 'replier');
      expect(m['text'], 'こんにちは');

      final chat = await repo.watchChat('p1_replier').first;
      expect(chat!.lastMessage, 'こんにちは');
      expect(chat.lastReadAt.keys, ['replier']);
      expect(chat.isUnreadFor('replier'), isFalse);
      expect(chat.isUnreadFor('owner'), isTrue);
    });

    test('watchMessages：送った順', () async {
      final msgs = db
          .collection('chats')
          .doc('p1_replier')
          .collection('messages');
      await msgs.doc('b').set({
        'uid': 'owner',
        'text': '後',
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 6, 12)),
      });
      await msgs.doc('a').set({
        'uid': 'replier',
        'text': '先',
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 6, 10)),
      });
      final list = await repo.watchMessages('p1_replier').first;
      expect(list.map((m) => m.text), ['先', '後']);
    });

    test('markRead：自分の既読だけを更新する', () async {
      await repo.markRead('p1_replier', 'owner');
      final chat = await repo.watchChat('p1_replier').first;
      expect(chat!.lastReadAt.keys, ['owner']);
    });

    test('setStatus：取引終了・再開', () async {
      await repo.setStatus('p1_replier', ChatStatus.closed);
      expect(
        (await repo.watchChat('p1_replier').first)!.status,
        ChatStatus.closed,
      );
      await repo.setStatus('p1_replier', ChatStatus.open);
      expect(
        (await repo.watchChat('p1_replier').first)!.status,
        ChatStatus.open,
      );
    });

    test('watchChat：なければ null', () async {
      expect(await repo.watchChat('none').first, isNull);
    });
  });
}
