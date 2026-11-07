// 投稿の詳細画面（/trade/:id。G-5-1）と返信（G-5-2）・承認（G-5-3）のウィジェットテスト
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/live/official_url_link.dart';
import 'package:oshiashi/features/trade/trade_post_detail_page.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/models/trade_post.dart';
import 'package:oshiashi/models/trade_reply.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/providers/trade_post_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';

import 'live_test_helpers.dart';
import 'oshi_test_helpers.dart';
import 'trade_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

/// fetch で例外を投げる偽物（非表示の投稿を他人が読んだときなど）
class _ThrowingRepo extends FakeTradePostRepository {
  _ThrowingRepo(this.e);
  final Object e;
  @override
  Future<TradePost?> fetch(String id) async => throw e;
}

TradePost fullPost({
  String uid = 'other',
  String? xAccount = 'oshi_fan',
  TradePostStatus status = TradePostStatus.open,
}) => TradePost(
  id: 'p1',
  uid: uid,
  displayName: '匿名',
  groupIds: const ['g1'],
  tags: const [TradeTag.trade, TradeTag.sell],
  priceType: PriceType.below,
  gives: const [
    GiveSet(
      items: [
        GiveItem(goodsId: 'a', variantId: 'v1', label: 'アクスタ（A）'),
        GiveItem(goodsId: 'a', variantId: 'v2', label: 'アクスタ（B）'),
      ],
      pickCount: 1,
      note: 'どれか1つ',
    ),
  ],
  wants: const [
    WantSet(
      targets: [
        WantTarget(type: WantType.goods, goodsId: 'b', label: 'タオル（全種類）'),
        WantTarget(type: WantType.member, oshiId: 'm1', label: 'メンバー1'),
      ],
    ),
  ],
  handover: const [HandoverMethod.mail, HandoverMethod.hand],
  performanceIds: const ['f1', 'unknown'],
  xAccount: xAccount,
  note: '送料はご負担ください',
  status: status,
  updatedAt: DateTime(2026, 11, 5, 12),
);

Future<List<Uri>> pumpDetail(
  WidgetTester tester,
  FakeTradePostRepository repo, {
  bool launchOk = true,
  FakeTradeReplyRepository? replyRepo,
  FakeTradeChatRepository? chatRepo,
  String location = '/trade/p1',
}) async {
  usePhoneSize(tester);
  final opened = <Uri>[];
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/trade/:id',
        builder: (_, s) => TradePostDetailPage(
          postId: s.pathParameters['id']!,
          initialAttachId: s.uri.queryParameters['attach'],
        ),
      ),
      GoRoute(
        path: '/chats/:id',
        // スナックバーを出せるよう、本物のチャット画面と同じく Scaffold を置く
        builder: (_, s) =>
            Scaffold(body: Text('route:chat:${s.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/trade/:id/edit',
        builder: (_, s) => Text('route:edit:${s.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        oshiRepositoryProvider.overrideWithValue(
          FakeOshiRepository([oshi('g1', 'グループ1')]),
        ),
        followRepositoryProvider.overrideWithValue(
          FakeFollowRepository(const FollowState(groupIds: {'g1'})),
        ),
        liveRepositoryProvider.overrideWithValue(
          FakeLiveRepository(
            lives: const [
              Live(id: 'l1', title: 'ツアー', groupIds: ['g1']),
            ],
            performances: [
              perfOf('f1', 'l1', DateTime(2026, 11, 20, 18)).copyWithIds(
                id: 'f1',
                liveId: 'l1',
                groupIds: ['g1'],
                oshiIds: [],
              ),
            ],
          ),
        ),
        // 手渡しの公演名は、自分のライブ一覧から引く（Step4.5）
        myLiveRepositoryProvider.overrideWithValue(
          FakeMyLiveRepository(ids: const ['l1']),
        ),
        nowProvider.overrideWithValue(DateTime(2026, 11, 5, 12)),
        tradePostRepositoryProvider.overrideWithValue(repo),
        tradeReplyRepositoryProvider.overrideWithValue(
          replyRepo ?? FakeTradeReplyRepository(),
        ),
        tradeChatRepositoryProvider.overrideWithValue(
          chatRepo ?? FakeTradeChatRepository(),
        ),
        urlLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return launchOk;
        }),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

Future<void> scrollTo(WidgetTester tester, Finder f) => tester
    .scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);

void main() {
  test('xProfileUri：正しいユーザー名だけを x.com のリンクにする', () {
    expect(xProfileUri('oshi_fan').toString(), 'https://x.com/oshi_fan');
    expect(xProfileUri(null), isNull);
    expect(xProfileUri('bad name'), isNull);
    expect(xProfileUri('a/../evil'), isNull);
  });

  testWidgets('投稿の内容をすべて出す', (tester) async {
    final repo = FakeTradePostRepository()..posts['p1'] = fullPost();
    await pumpDetail(tester, repo);

    expect(find.text('対象：グループ1'), findsOneWidget);
    expect(find.text('交換希望・譲渡（売ります）／価格：定価以下'), findsOneWidget);
    expect(find.text('譲セット1（この中から1個）'), findsOneWidget);
    expect(find.text('・アクスタ（A）'), findsOneWidget);
    expect(find.text('・アクスタ（B）'), findsOneWidget);
    expect(find.text('備考：どれか1つ'), findsOneWidget);
    expect(find.text('・タオル（全種類）'), findsOneWidget);
    expect(find.text('・メンバー1（メンバー指定）'), findsOneWidget);

    await scrollTo(tester, _key('trade_detail_note'));
    expect(find.text('郵送・手渡し'), findsOneWidget);
    expect(find.text('・ツアー 2026/11/20(金) 18:00 会場f1'), findsOneWidget);
    expect(find.text('・（公演の情報を表示できません）'), findsOneWidget);
    expect(find.text('送料はご負担ください'), findsOneWidget);
    // 他人の投稿なので編集ボタンはない
    expect(_key('trade_detail_edit'), findsNothing);
  });

  testWidgets('X のリンクを押すと x.com を開く。開けなければ伝える', (tester) async {
    final repo = FakeTradePostRepository()..posts['p1'] = fullPost();
    final opened = await pumpDetail(tester, repo, launchOk: false);
    await scrollTo(tester, _key('trade_detail_x'));
    expect(find.text('X：@oshi_fan'), findsOneWidget);
    await tester.tap(_key('trade_detail_x'));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse('https://x.com/oshi_fan')]);
    expect(find.text('X を開けませんでした'), findsOneWidget);
  });

  testWidgets('X がなければ、返信で連絡できると案内する', (tester) async {
    final repo = FakeTradePostRepository()
      ..posts['p1'] = fullPost(xAccount: null);
    await pumpDetail(tester, repo);
    await scrollTo(tester, _key('trade_detail_no_x'));
    expect(_key('trade_detail_no_x'), findsOneWidget);
  });

  testWidgets('自分の投稿なら編集ボタンを出し、編集画面へ行ける', (tester) async {
    final repo = FakeTradePostRepository()..posts['p1'] = fullPost(uid: 'u1');
    await pumpDetail(tester, repo);
    expect(find.text('自分'), findsOneWidget);
    await tester.tap(_key('trade_detail_edit'));
    await tester.pumpAndSettle();
    expect(find.text('route:edit:p1'), findsOneWidget);
  });

  testWidgets('募集終了なら目立たせる', (tester) async {
    final repo = FakeTradePostRepository()
      ..posts['p1'] = fullPost(status: TradePostStatus.closed);
    await pumpDetail(tester, repo);
    expect(find.text('この投稿は募集終了です'), findsOneWidget);
  });

  testWidgets('見つからない・読めない投稿はその旨を出す', (tester) async {
    await pumpDetail(tester, FakeTradePostRepository());
    expect(find.text('投稿が見つかりません'), findsOneWidget);
  });

  testWidgets('権限がない（非表示）ときは、表示できないと出す', (tester) async {
    await pumpDetail(
      tester,
      _ThrowingRepo(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
    );
    expect(find.textContaining('この投稿は表示できません'), findsOneWidget);
  });

  group('返信', () {
    /// 自分（u1）の募集中の投稿
    final myOpen = TradePost(
      id: 'myOpen',
      uid: 'u1',
      tags: const [TradeTag.trade],
      handover: const [HandoverMethod.mail],
      gives: const [
        GiveSet(
          items: [GiveItem(goodsId: 'b', variantId: 'v1', label: 'タオル')],
        ),
      ],
    );
    final myClosed = TradePost(
      id: 'myClosed',
      uid: 'u1',
      tags: const [TradeTag.trade],
      handover: const [HandoverMethod.mail],
      status: TradePostStatus.closed,
    );

    FakeTradePostRepository repoWithMine() => FakeTradePostRepository()
      ..posts['p1'] = fullPost()
      ..posts['myOpen'] = myOpen
      ..mineInitial = [myOpen, myClosed];

    Future<void> scrollToInput(WidgetTester tester) =>
        scrollTo(tester, _key('trade_reply_send'));

    testWidgets('返信を書いた順に出し、添付した投稿を表示する', (tester) async {
      final replyRepo = FakeTradeReplyRepository({
        'p1': [
          TradeReply(
            id: 'r1',
            uid: 'x',
            displayName: '匿名',
            text: '交換できますか？',
            linkedPostId: 'myOpen',
            createdAt: DateTime(2026, 11, 6, 10),
          ),
          TradeReply(
            id: 'r2',
            uid: 'y',
            displayName: '匿名',
            text: 'B ほしいです',
            approved: true,
            createdAt: DateTime(2026, 11, 6, 11),
          ),
        ],
      });
      await pumpDetail(tester, repoWithMine(), replyRepo: replyRepo);
      await scrollTo(tester, _key('trade_reply_r2'));
      expect(find.text('交換できますか？'), findsOneWidget);
      expect(find.text('添付の投稿\n譲：タオル'), findsOneWidget);
      expect(find.text('承認済み'), findsOneWidget);
      // 他人の返信は削除できない
      expect(_key('trade_reply_delete_r1'), findsNothing);
    });

    testWidgets('自分の募集中の投稿を添付して返信できる', (tester) async {
      final replyRepo = FakeTradeReplyRepository();
      await pumpDetail(tester, repoWithMine(), replyRepo: replyRepo);
      await scrollToInput(tester);
      expect(find.text('まだ返信はありません'), findsOneWidget);

      await tester.enterText(_key('trade_reply_text'), '  交換お願いします  ');
      await tester.tap(_key('trade_reply_attach'));
      await tester.pumpAndSettle();
      // 募集終了の投稿は候補に出さない
      expect(find.textContaining('品目なしの投稿'), findsNothing);
      await tester.tap(find.text('添付：譲：タオル').last);
      await tester.pumpAndSettle();
      await tester.tap(_key('trade_reply_send'));
      await tester.pumpAndSettle();

      final c = replyRepo.created.single;
      expect(c.postId, 'p1');
      expect(c.uid, 'u1');
      expect(c.displayName, '匿名');
      expect(c.text, '交換お願いします');
      expect(c.linkedPostId, 'myOpen');
      // 送ったら入力欄を空にし、一覧に出す
      expect(find.text('交換お願いします'), findsOneWidget);
    });

    testWidgets('マッチから開いたときは、添付を選んだ状態にする', (tester) async {
      final replyRepo = FakeTradeReplyRepository();
      await pumpDetail(
        tester,
        repoWithMine(),
        replyRepo: replyRepo,
        location: '/trade/p1?attach=myOpen',
      );
      await scrollToInput(tester);
      await tester.enterText(_key('trade_reply_text'), 'よろしくお願いします');
      await tester.tap(_key('trade_reply_send'));
      await tester.pumpAndSettle();
      expect(replyRepo.created.single.linkedPostId, 'myOpen');
    });

    testWidgets('本文が空なら送らない', (tester) async {
      final replyRepo = FakeTradeReplyRepository();
      await pumpDetail(tester, repoWithMine(), replyRepo: replyRepo);
      await scrollToInput(tester);
      await tester.enterText(_key('trade_reply_text'), '   ');
      await tester.tap(_key('trade_reply_send'));
      await tester.pumpAndSettle();
      expect(find.text('本文を入力してください'), findsOneWidget);
      expect(replyRepo.created, isEmpty);
    });

    testWidgets('投稿者は返信を書けるが、添付の欄は出さない', (tester) async {
      final repo = repoWithMine()..posts['p1'] = fullPost(uid: 'u1');
      await pumpDetail(tester, repo);
      await scrollToInput(tester);
      expect(_key('trade_reply_text'), findsOneWidget);
      expect(_key('trade_reply_attach'), findsNothing);
    });

    testWidgets('募集中でない投稿には返信できない', (tester) async {
      final repo = repoWithMine()
        ..posts['p1'] = fullPost(status: TradePostStatus.closed);
      await pumpDetail(tester, repo);
      await scrollTo(tester, _key('trade_reply_closed'));
      expect(_key('trade_reply_text'), findsNothing);
    });

    testWidgets('送れなかったら理由を出す', (tester) async {
      final replyRepo = FakeTradeReplyRepository()
        ..error = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      await pumpDetail(tester, repoWithMine(), replyRepo: replyRepo);
      await scrollToInput(tester);
      await tester.enterText(_key('trade_reply_text'), 'こんにちは');
      await tester.tap(_key('trade_reply_send'));
      await tester.pumpAndSettle();
      expect(find.textContaining('募集が終了した可能性があります'), findsOneWidget);
    });

    testWidgets('自分の承認前の返信は、確認してから削除できる', (tester) async {
      final replyRepo = FakeTradeReplyRepository({
        'p1': [
          TradeReply(
            id: 'mine',
            uid: 'u1',
            displayName: '匿名',
            text: '消す返信',
            createdAt: DateTime(2026, 11, 6, 10),
          ),
          TradeReply(
            id: 'approved',
            uid: 'u1',
            displayName: '匿名',
            text: '承認済みの返信',
            approved: true,
            createdAt: DateTime(2026, 11, 6, 11),
          ),
        ],
      });
      await pumpDetail(tester, repoWithMine(), replyRepo: replyRepo);
      await scrollTo(tester, _key('trade_reply_approved'));
      // 承認済みは削除できない
      expect(_key('trade_reply_delete_approved'), findsNothing);

      await tester.tap(_key('trade_reply_delete_mine'));
      await tester.pumpAndSettle();
      await tester.tap(_key('trade_reply_delete_confirm'));
      await tester.pumpAndSettle();
      expect(replyRepo.deleted, [('p1', 'mine')]);
      expect(find.text('消す返信'), findsNothing);
    });
  });

  group('承認', () {
    TradeReply reply(String id, String uid, {bool approved = false}) =>
        TradeReply(
          id: id,
          uid: uid,
          displayName: '匿名',
          text: '返信$id',
          approved: approved,
          createdAt: DateTime(2026, 11, 6, 10),
        );

    /// 自分（u1）の投稿に、他人の返信 r1 と自分の返信 own がある
    (FakeTradePostRepository, FakeTradeReplyRepository) setup() {
      final repo = FakeTradePostRepository()..posts['p1'] = fullPost(uid: 'u1');
      final replyRepo = FakeTradeReplyRepository({
        'p1': [
          reply('r1', 'x'),
          reply('own', 'u1'),
          reply('done', 'y', approved: true),
        ],
      });
      return (repo, replyRepo);
    }

    testWidgets('投稿者には、他人の承認前の返信にだけ承認ボタンを出す', (tester) async {
      final (repo, replyRepo) = setup();
      await pumpDetail(tester, repo, replyRepo: replyRepo);
      await scrollTo(tester, _key('trade_reply_done'));
      expect(_key('trade_reply_approve_r1'), findsOneWidget);
      expect(_key('trade_reply_approve_own'), findsNothing);
      expect(_key('trade_reply_approve_done'), findsNothing);
    });

    testWidgets('投稿者でなければ、承認ボタンは出ない', (tester) async {
      final replyRepo = FakeTradeReplyRepository({
        'p1': [reply('r1', 'x')],
      });
      await pumpDetail(
        tester,
        FakeTradePostRepository()..posts['p1'] = fullPost(),
        replyRepo: replyRepo,
      );
      await scrollTo(tester, _key('trade_reply_r1'));
      expect(_key('trade_reply_approve_r1'), findsNothing);
    });

    testWidgets('確認してから承認し、チャットを作る', (tester) async {
      final (repo, replyRepo) = setup();
      final chatRepo = FakeTradeChatRepository()..replyRepo = replyRepo;
      await pumpDetail(tester, repo, replyRepo: replyRepo, chatRepo: chatRepo);
      await scrollTo(tester, _key('trade_reply_approve_r1'));

      // キャンセルなら何もしない
      await tester.tap(_key('trade_reply_approve_r1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(chatRepo.approved, isEmpty);

      await tester.tap(_key('trade_reply_approve_r1'));
      await tester.pumpAndSettle();
      await tester.tap(_key('trade_reply_approve_confirm'));
      await tester.pumpAndSettle();
      expect(chatRepo.approved, [(postId: 'p1', replyId: 'r1')]);
      expect(find.text('承認して、チャットを作りました（募集を終了しました）'), findsOneWidget);
      // 承認したら、そのままチャットを開く
      expect(find.text('route:chat:p1_x'), findsOneWidget);
    });

    testWidgets('その人とのチャットがすでにあれば、承認せずにそれを開く', (tester) async {
      final (repo, replyRepo) = setup();
      final chatRepo = FakeTradeChatRepository()..existing.add('p1_x');
      await pumpDetail(tester, repo, replyRepo: replyRepo, chatRepo: chatRepo);
      await scrollTo(tester, _key('trade_reply_approve_r1'));
      await tester.tap(_key('trade_reply_approve_r1'));
      await tester.pumpAndSettle();
      await tester.tap(_key('trade_reply_approve_confirm'));
      await tester.pumpAndSettle();
      expect(chatRepo.approved, isEmpty);
      expect(find.text('この人とのチャットはすでにあるので、それを開きます'), findsOneWidget);
      expect(find.text('route:chat:p1_x'), findsOneWidget);
    });

    testWidgets('承認できなければ理由を出す', (tester) async {
      final (repo, replyRepo) = setup();
      final chatRepo = FakeTradeChatRepository()..error = Exception('失敗');
      await pumpDetail(tester, repo, replyRepo: replyRepo, chatRepo: chatRepo);
      await scrollTo(tester, _key('trade_reply_approve_r1'));
      await tester.tap(_key('trade_reply_approve_r1'));
      await tester.pumpAndSettle();
      await tester.tap(_key('trade_reply_approve_confirm'));
      await tester.pumpAndSettle();
      expect(find.textContaining('承認できませんでした'), findsOneWidget);
    });
  });

  group('チャットへの入口', () {
    TradeReply approvedReply(String uid) => TradeReply(
      id: 'r1',
      uid: uid,
      displayName: '匿名',
      text: '承認された返信',
      approved: true,
      createdAt: DateTime(2026, 11, 6, 10),
    );

    testWidgets('投稿者には、承認済みの返信に「チャットを開く」を出す', (tester) async {
      await pumpDetail(
        tester,
        FakeTradePostRepository()..posts['p1'] = fullPost(uid: 'u1'),
        replyRepo: FakeTradeReplyRepository({
          'p1': [approvedReply('x')],
        }),
      );
      await scrollTo(tester, _key('trade_reply_chat_r1'));
      await tester.tap(_key('trade_reply_chat_r1'));
      await tester.pumpAndSettle();
      expect(find.text('route:chat:p1_x'), findsOneWidget);
    });

    testWidgets('返信した本人にも出す', (tester) async {
      await pumpDetail(
        tester,
        FakeTradePostRepository()..posts['p1'] = fullPost(),
        replyRepo: FakeTradeReplyRepository({
          'p1': [approvedReply('u1')],
        }),
      );
      await scrollTo(tester, _key('trade_reply_chat_r1'));
      expect(_key('trade_reply_chat_r1'), findsOneWidget);
    });

    testWidgets('投稿者でも返信した人でもなければ出さない', (tester) async {
      await pumpDetail(
        tester,
        FakeTradePostRepository()..posts['p1'] = fullPost(),
        replyRepo: FakeTradeReplyRepository({
          'p1': [approvedReply('x')],
        }),
      );
      await scrollTo(tester, _key('trade_reply_r1'));
      expect(_key('trade_reply_chat_r1'), findsNothing);
    });
  });

  for (final w in layoutWidths) {
    testWidgets('幅 ${w.toInt()} ではみ出さない', (tester) async {
      phoneWidthOverride = w;
      addTearDown(() => phoneWidthOverride = null);
      await pumpDetail(
        tester,
        FakeTradePostRepository()..posts['p1'] = fullPost(),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
