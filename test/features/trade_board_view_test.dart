// 交換の掲示板（交換トップの「掲示板」タブ。G-3-2・G-3-3）のウィジェットテスト。
// 本物のプロバイダを使い、リポジトリだけを偽物に差し替える。
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/trade/trade_board_view.dart';
import 'package:oshiashi/models/goods.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/models/trade_post.dart';
import 'package:oshiashi/providers/goods_providers.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/providers/trade_post_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';

import 'live_test_helpers.dart';
import 'oshi_test_helpers.dart';
import 'trade_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

final oshis = [
  oshi('g1', 'グループ1'),
  const OshiSummary(
    id: 'p1',
    kind: OshiKind.person,
    name: '個人1',
    genre: OshiGenre.idol,
    status: OshiStatus.approved,
    groupIds: ['g1'],
  ),
];

FakeFollowRepository following() =>
    FakeFollowRepository(const FollowState(groupIds: {'g1'}, oshiIds: {'p1'}));

TradePost post(
  String id,
  int day, {
  String uid = 'other',
  List<String> groupIds = const ['g1'],
  List<String> oshiIds = const [],
  List<TradeTag> tags = const [TradeTag.trade],
  PriceType? priceType,
  List<GiveSet> gives = const [],
  List<WantSet> wants = const [],
  List<String> performanceIds = const [],
}) => TradePost(
  id: id,
  uid: uid,
  displayName: '匿名',
  groupIds: groupIds,
  oshiIds: oshiIds,
  tags: tags,
  priceType: priceType,
  gives: gives,
  wants: wants,
  performanceIds: performanceIds,
  handover: const [HandoverMethod.mail, HandoverMethod.hand],
  updatedAt: DateTime(2026, 11, day),
);

Future<void> pumpBoard(
  WidgetTester tester,
  FakeTradePostRepository repo, {
  FakeMyLiveRepository? myRepo,
  FakeFollowRepository? follow,
}) async {
  usePhoneSize(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        oshiRepositoryProvider.overrideWithValue(FakeOshiRepository(oshis)),
        followRepositoryProvider.overrideWithValue(follow ?? following()),
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
        myLiveRepositoryProvider.overrideWithValue(
          myRepo ?? FakeMyLiveRepository(ids: ['l1']),
        ),
        goodsRepositoryProvider.overrideWithValue(
          FakeGoodsRepository(const [
            Goods(
              id: 'acsta',
              name: 'アクスタ',
              category: GoodsCategory.acrylic,
              groupIds: ['g1'],
              variants: [GoodsVariant(id: 'v1', name: 'A')],
            ),
          ]),
        ),
        nowProvider.overrideWithValue(DateTime(2026, 11, 5, 12)),
        tradePostRepositoryProvider.overrideWithValue(repo),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: TradeBoardView()),
            ),
            GoRoute(
              path: '/trade/:id',
              builder: (_, s) => Text('route:detail:${s.pathParameters['id']}'),
            ),
          ],
        ),
      ),
    ),
  );
  // 先頭の推しが自動で選ばれ、投稿の読み込みが始まる。偽物が何も流さないあいだは
  // 読み込み中の表示が動き続けて pumpAndSettle が終わらないので、決まった時間だけ進める
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 推しを選ぶ。読み込み中のまま止まる場合は [settle] を false にする
/// （読み込み中の表示は動き続けるため、pumpAndSettle が終わらない）
Future<void> selectOshi(
  WidgetTester tester,
  String label, {
  bool settle = true,
}) async {
  await tester.tap(_key('trade_board_oshi'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('フォロー中の先頭の推しが、最初から選ばれている', (tester) async {
    final repo = FakeTradePostRepository();
    await pumpBoard(tester, repo);
    // 最初は「フォロー中の推し すべて」（Fc 5.1）。個人も所属グループも読む
    expect(find.text('フォロー中の推し すべて'), findsOneWidget);
    expect(
      {for (final w in repo.watchedOpen) '${w.$1.name}/${w.$2}'},
      {'person/p1', 'group/g1'},
    );
    expect(find.text('推しを選んでください'), findsNothing);
  });

  testWidgets('補足: 絞り込みの下に、いつも出る', (tester) async {
    await pumpBoard(tester, FakeTradePostRepository());
    expect(_key('hint_trade_board'), findsOneWidget);
    expect(find.text('「譲」は手放せるグッズ、「求」はほしいグッズです。'), findsOneWidget);
    expect(
      tester.getTopLeft(_key('trade_board_oshi')).dy,
      lessThan(tester.getTopLeft(_key('hint_trade_board')).dy),
    );
  });

  testWidgets('更新日時は「更新 」＋日付だけ（年は今年なら省略）', (tester) async {
    final repo = FakeTradePostRepository()
      ..openByTarget = {
        (OshiKind.group, 'g1'): [post('new', 3)],
      };
    await pumpBoard(tester, repo);
    await selectOshi(tester, 'グループ1（グループ）');
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            RegExp(r'^更新 (\d{4}/)?11/3\(火\)$').hasMatch(w.data ?? ''),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('更新：'), findsNothing);
  });

  testWidgets('フォロー中の推しが0件なら、推しを探す案内を出す', (tester) async {
    final repo = FakeTradePostRepository();
    await pumpBoard(tester, repo, follow: FakeFollowRepository());
    expect(_key('trade_board_no_oshi'), findsOneWidget);
    expect(find.text('推しをフォローすると、交換の投稿が見られます'), findsOneWidget);
    expect(_key('trade_board_find_oshi_button'), findsOneWidget);
    expect(repo.watchedOpen, isEmpty);
  });

  testWidgets('推しを選ぶと、募集中の投稿を新しい順に出す', (tester) async {
    final repo = FakeTradePostRepository()
      ..openByTarget = {
        (OshiKind.group, 'g1'): [
          post(
            'new',
            3,
            tags: const [TradeTag.trade, TradeTag.sell],
            priceType: PriceType.face,
            gives: const [
              GiveSet(
                items: [GiveItem(goodsId: 'a', variantId: 'v1', label: 'アクスタ')],
              ),
            ],
          ),
          post('mine', 2, uid: 'u1'),
        ],
      };
    await pumpBoard(tester, repo);
    await selectOshi(tester, 'グループ1（グループ）');

    final cards = tester
        .widgetList<Card>(find.byType(Card))
        .map((c) => (c.key as ValueKey<String>).value)
        .toList();
    expect(cards, ['trade_board_post_new', 'trade_board_post_mine']);
    // タグと受け渡しは、1行にまとめて出る（Fd 4）
    expect(find.text('交換希望・譲渡（売ります）／価格：定価 ・ 受け渡し：郵送・手渡し'), findsOneWidget);
    expect(find.text('交換希望 ・ 受け渡し：郵送・手渡し'), findsOneWidget);
    // 「譲」の札と本文は別の Text（S1）
    expect(find.text('譲'), findsOneWidget);
    expect(find.text('アクスタ'), findsOneWidget);
    // 自分の投稿には印を付ける
    expect(find.text('自分'), findsOneWidget);
  });

  testWidgets('投稿を押すと詳細画面へ行く', (tester) async {
    final repo = FakeTradePostRepository()
      ..openByTarget = {
        (OshiKind.group, 'g1'): [post('new', 3)],
      };
    await pumpBoard(tester, repo);
    await selectOshi(tester, 'グループ1（グループ）');
    await tester.tap(_key('trade_board_post_new'));
    await tester.pumpAndSettle();
    expect(find.text('route:detail:new'), findsOneWidget);
  });

  testWidgets('個人を選ぶと、所属グループの投稿もまとめて出す', (tester) async {
    final repo = FakeTradePostRepository()
      ..openByTarget = {
        (OshiKind.person, 'p1'): [
          post('solo', 1, groupIds: const [], oshiIds: const ['p1']),
        ],
        (OshiKind.group, 'g1'): [post('group', 2)],
      };
    await pumpBoard(tester, repo);
    await selectOshi(tester, '個人1（個人）');

    expect(_key('trade_board_post_group'), findsOneWidget);
    expect(_key('trade_board_post_solo'), findsOneWidget);
  });

  testWidgets('投稿がなければその旨を出す', (tester) async {
    final repo = FakeTradePostRepository()..openByTarget = {};
    await pumpBoard(tester, repo);
    await selectOshi(tester, 'グループ1（グループ）');
    expect(find.text('募集中の投稿はまだありません'), findsOneWidget);
  });

  testWidgets('50件を超えると「もっと見る」で続きを読む', (tester) async {
    final repo = FakeTradePostRepository()
      ..openByTarget = {
        (OshiKind.group, 'g1'): [
          for (var i = 0; i < 60; i++)
            post(
              'p$i',
              1,
            ).copyForTest(updatedAt: DateTime(2026, 11, 1, 0, 60 - i)),
        ],
      };
    await pumpBoard(tester, repo);
    await selectOshi(tester, 'グループ1（グループ）');
    expect(repo.watchedOpen.last, (OshiKind.group, 'g1', 50));

    await tester.scrollUntilVisible(
      _key('trade_board_more'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(_key('trade_board_more'));
    await tester.pumpAndSettle();
    expect(repo.watchedOpen.last, (OshiKind.group, 'g1', 100));

    await tester.scrollUntilVisible(
      _key('trade_board_post_p59'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    expect(_key('trade_board_more'), findsNothing);
  });

  testWidgets('読み込めなかったらエラーを出す', (tester) async {
    final repo = FakeTradePostRepository();
    await pumpBoard(tester, repo);
    // 最初から選ばれている推しの投稿が、読み込み中のまま
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repo.open.addError(permissionDenied());
    await tester.pumpAndSettle();
    expect(find.textContaining('投稿を読み込めませんでした'), findsOneWidget);
  });

  group('絞り込み', () {
    const giveAcsta = GiveSet(
      items: [GiveItem(goodsId: 'acsta', variantId: 'v1', label: 'アクスタ（A）')],
    );
    const wantAcsta = WantSet(
      targets: [
        WantTarget(type: WantType.goods, goodsId: 'acsta', label: 'アクスタ（全種類）'),
      ],
    );

    FakeTradePostRepository repoWithPosts() => FakeTradePostRepository()
      ..openByTarget = {
        (OshiKind.group, 'g1'): [
          post('give', 5, gives: const [giveAcsta]),
          post('want', 4, wants: const [wantAcsta]),
          post(
            'sell',
            3,
            tags: const [TradeTag.sell],
            priceType: PriceType.face,
          ),
          post('hand', 2, performanceIds: const ['f1']),
        ],
      };

    // シートの ListView は見えない部分を作らないので、スクロールして作らせる
    Future<void> revealInSheet(WidgetTester tester, Finder f) async {
      if (f.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          f,
          200,
          scrollable: find.byType(Scrollable).last,
        );
      }
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
    }

    // シートは長いので、押す前に見える位置までスクロールする
    Future<void> tapVisible(WidgetTester tester, Finder f) async {
      await revealInSheet(tester, f);
      await tester.tap(f);
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(_key('trade_board_filter'));
      await tester.pumpAndSettle();
    }

    Future<void> apply(WidgetTester tester) async {
      await tapVisible(tester, _key('board_filter_apply'));
      await tester.pumpAndSettle();
    }

    Future<void> pickDropdown(
      WidgetTester tester,
      String key,
      String label,
    ) async {
      await tapVisible(tester, _key(key));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    List<String> shown(WidgetTester tester) => [
      for (final c in tester.widgetList<Card>(find.byType(Card)))
        (c.key as ValueKey<String>).value.replaceFirst('trade_board_post_', ''),
    ];

    testWidgets('グッズ＋譲で絞り込み、チップの × で外せる', (tester) async {
      await pumpBoard(tester, repoWithPosts());
      await selectOshi(tester, 'グループ1（グループ）');
      expect(shown(tester), ['give', 'want', 'sell', 'hand']);

      await openSheet(tester);
      await pickDropdown(tester, 'board_filter_goods', 'アクスタ');
      await tester.tap(find.text('譲').last);
      await tester.pumpAndSettle();
      await apply(tester);

      expect(shown(tester), ['give']);
      expect(find.text('アクスタ（譲）'), findsOneWidget);
      expect(find.text('4件から絞り込んでいます'), findsOneWidget);

      // チップの × を押したときの処理を呼ぶ
      tester.widget<InputChip>(_key('board_chip_goods')).onDeleted!();
      await tester.pumpAndSettle();
      expect(shown(tester), ['give', 'want', 'sell', 'hand']);
    });

    testWidgets('グッズだけなら、譲・求のどちらかに含む投稿', (tester) async {
      await pumpBoard(tester, repoWithPosts());
      await selectOshi(tester, 'グループ1（グループ）');
      await openSheet(tester);
      await pickDropdown(tester, 'board_filter_goods', 'アクスタ');
      await apply(tester);
      expect(shown(tester), ['give', 'want']);
    });

    testWidgets('タグと手渡しの公演で絞り込む', (tester) async {
      await pumpBoard(tester, repoWithPosts());
      await selectOshi(tester, 'グループ1（グループ）');

      await openSheet(tester);
      await tapVisible(tester, _key('board_filter_tag_sell'));
      await tapVisible(tester, _key('board_filter_tag_buy'));
      await tester.pump();
      await apply(tester);
      expect(shown(tester), ['sell']);
      expect(find.text('譲渡（売ります）・買取希望'), findsOneWidget);

      await tester.tap(_key('board_chip_clear'));
      await tester.pumpAndSettle();
      await openSheet(tester);
      await pickDropdown(
        tester,
        'board_filter_performance',
        'ツアー 2026/11/20(金) 18:00 会場f1',
      );
      await apply(tester);
      expect(shown(tester), ['hand']);
    });

    testWidgets('手渡しの公演の候補は自分のライブ一覧の公演だけ', (tester) async {
      await pumpBoard(tester, repoWithPosts(), myRepo: FakeMyLiveRepository());
      await selectOshi(tester, 'グループ1（グループ）');
      await openSheet(tester);
      await tapVisible(tester, _key('board_filter_performance'));
      await tester.pumpAndSettle();
      expect(find.text('ツアー 2026/11/20(金) 18:00 会場f1'), findsNothing);
    });

    testWidgets('条件に合う投稿がなければその旨を出す', (tester) async {
      final repo = FakeTradePostRepository()
        ..openByTarget = {
          (OshiKind.group, 'g1'): [post('a', 1)],
        };
      await pumpBoard(tester, repo);
      await selectOshi(tester, 'グループ1（グループ）');
      await openSheet(tester);
      await tapVisible(tester, _key('board_filter_tag_buy'));
      await tester.pump();
      await apply(tester);
      expect(find.text('条件に合う投稿はありません'), findsOneWidget);
    });

    testWidgets('推しを変えると条件が外れる', (tester) async {
      await pumpBoard(tester, repoWithPosts());
      await selectOshi(tester, 'グループ1（グループ）');
      await openSheet(tester);
      await tapVisible(tester, _key('board_filter_tag_sell'));
      await tester.pump();
      await apply(tester);
      expect(_key('board_chip_tags'), findsOneWidget);

      await selectOshi(tester, '個人1（個人）');
      expect(_key('board_chip_tags'), findsNothing);
    });

    testWidgets('シートの「条件をすべて外す」で条件なしに戻る', (tester) async {
      await pumpBoard(tester, repoWithPosts());
      await selectOshi(tester, 'グループ1（グループ）');
      await openSheet(tester);
      await tapVisible(tester, _key('board_filter_tag_sell'));
      await tester.pump();
      await apply(tester);
      await openSheet(tester);
      await tapVisible(tester, _key('board_filter_clear'));
      await tester.pumpAndSettle();
      expect(_key('board_chip_tags'), findsNothing);
      expect(shown(tester), hasLength(4));
    });
  });
}

extension on TradePost {
  TradePost copyForTest({required DateTime updatedAt}) => TradePost(
    id: id,
    uid: uid,
    displayName: displayName,
    groupIds: groupIds,
    tags: tags,
    handover: handover,
    updatedAt: updatedAt,
  );
}
