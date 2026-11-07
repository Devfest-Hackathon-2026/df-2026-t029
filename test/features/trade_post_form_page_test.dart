// 投稿の作成・編集画面（/trade/new・/trade/:id/edit。G-2-4・G-2-5）のウィジェットテスト。
// 本物のプロバイダを使い、リポジトリだけを偽物に差し替える。
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/trade/trade_post_form_page.dart';
import 'package:oshiashi/models/goods.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/models/trade_post.dart';
import 'package:oshiashi/models/user_profile.dart';
import 'package:oshiashi/providers/goods_providers.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/providers/profile_providers.dart';
import 'package:oshiashi/providers/trade_post_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';

import 'live_test_helpers.dart';
import 'oshi_test_helpers.dart';
import 'trade_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

final now = DateTime(2026, 11, 5, 12);

final oshis = [
  oshi('g1', 'グループ1'),
  oshi('g3', 'グループ3'),
  const OshiSummary(
    id: 'p1',
    kind: OshiKind.person,
    name: '個人1',
    genre: OshiGenre.idol,
    status: OshiStatus.approved,
  ),
];

/// g1 のメンバー
const m1 = OshiSummary(
  id: 'm1',
  kind: OshiKind.person,
  name: 'メンバー1',
  genre: OshiGenre.idol,
  status: OshiStatus.approved,
  groupIds: ['g1'],
);

const acsta = Goods(
  id: 'acsta',
  name: 'ランダムアクスタ',
  category: GoodsCategory.acrylic,
  groupIds: ['g1'],
  variants: [
    GoodsVariant(id: 'v1', name: 'メンバー1', oshiId: 'm1'),
    GoodsVariant(id: 'v2', name: 'メンバー2'),
  ],
);

/// g1 と p1 をフォロー中（g3 はフォローしていない）
FakeFollowRepository following() =>
    FakeFollowRepository(const FollowState(groupIds: {'g1'}, oshiIds: {'p1'}));

FakeLiveRepository lives() => FakeLiveRepository(
  lives: const [
    Live(id: 'l1', title: 'ツアー2026', groupIds: ['g1']),
  ],
  performances: [
    perfOf(
      'f1',
      'l1',
      DateTime(2026, 11, 20, 18),
    ).copyWithIds(id: 'f1', liveId: 'l1', groupIds: ['g1'], oshiIds: []),
    perfOf(
      'old',
      'l1',
      DateTime(2026, 10, 1, 18),
    ).copyWithIds(id: 'old', liveId: 'l1', groupIds: ['g1'], oshiIds: []),
  ],
);

Future<GoRouter> pumpForm(
  WidgetTester tester, {
  required FakeTradePostRepository repo,
  String location = '/trade/new',
  FakeGoodsRepository? goodsRepo,
  FakeMyLiveRepository? myRepo,
  String? displayName,
  UserProfile? profile,
}) async {
  usePhoneSize(tester);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('route:/')),
      GoRoute(path: '/goods', builder: (_, _) => const Text('route:/goods')),
      GoRoute(path: '/trade/new', builder: (_, _) => const TradePostFormPage()),
      GoRoute(
        path: '/trade/:id/edit',
        builder: (_, s) => TradePostFormPage(postId: s.pathParameters['id']),
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
          FakeOshiRepository([...oshis, m1]),
        ),
        followRepositoryProvider.overrideWithValue(following()),
        liveRepositoryProvider.overrideWithValue(lives()),
        myLiveRepositoryProvider.overrideWithValue(
          myRepo ?? FakeMyLiveRepository(ids: ['l1']),
        ),
        applicationRepositoryProvider.overrideWithValue(
          FakeApplicationRepository(),
        ),
        nowProvider.overrideWithValue(now),
        tradePostRepositoryProvider.overrideWithValue(repo),
        if (displayName != null)
          myDisplayNameProvider.overrideWithValue(displayName),
        if (profile != null)
          myProfileProvider.overrideWithValue(AsyncData(profile)),
        goodsRepositoryProvider.overrideWithValue(
          goodsRepo ?? FakeGoodsRepository(const [acsta]),
        ),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push(location);
  await tester.pumpAndSettle();
  return router;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  // ListView は画面外の項目を作らないので、見つかるまで下へスクロールする
  await tester.scrollUntilVisible(_key(key), 200, scrollable: listScrollable());
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('必須項目が空のまま投稿すると、エラーを出して保存しない', (tester) async {
    final repo = FakeTradePostRepository();
    await pumpForm(tester, repo: repo);

    await tapKey(tester, 'trade_save_button');

    expect(find.text('対象の推しを1つ以上選んでください'), findsOneWidget);
    expect(find.text('取引のタグを1つ以上選んでください'), findsOneWidget);
    expect(find.text('受け渡し方法を1つ以上選んでください'), findsOneWidget);
    expect(repo.created, isEmpty);
  });

  testWidgets('フォロー中の推しだけを選択肢に出す', (tester) async {
    await pumpForm(tester, repo: FakeTradePostRepository());
    expect(_key('trade_target_g1'), findsOneWidget);
    expect(_key('trade_target_p1'), findsOneWidget);
    expect(_key('trade_target_g3'), findsNothing);
  });

  testWidgets('入力して投稿すると「匿名」で作成し、前の画面へ戻る', (tester) async {
    final repo = FakeTradePostRepository();
    await pumpForm(tester, repo: repo);

    await tapKey(tester, 'trade_target_g1');
    await tapKey(tester, 'trade_target_p1');
    await tapKey(tester, 'trade_tag_trade');
    await tapKey(tester, 'trade_tag_sell');
    // 譲渡を選ぶと価格の区分が出る
    await tapKey(tester, 'trade_price_below');
    await tapKey(tester, 'trade_handover_hand');
    // 手渡しを選ぶと、今後の公演だけが出る
    expect(_key('trade_performance_old'), findsNothing);
    expect(find.text('ツアー2026'), findsOneWidget);
    await tapKey(tester, 'trade_performance_f1');
    await tester.enterText(_key('trade_x_account'), '@oshi_fan');
    await tester.enterText(_key('trade_note'), '送料はご負担ください');
    await tapKey(tester, 'trade_save_button');

    expect(repo.created, hasLength(1));
    final c = repo.created.single;
    expect(c.uid, 'u1');
    expect(c.displayName, '匿名');
    expect(c.post.groupIds, ['g1']);
    expect(c.post.oshiIds, ['p1']);
    expect(c.post.tags, [TradeTag.trade, TradeTag.sell]);
    expect(c.post.priceType, PriceType.below);
    expect(c.post.handover, [HandoverMethod.hand]);
    expect(c.post.performanceIds, ['f1']);
    expect(c.post.xAccount, 'oshi_fan');
    expect(c.post.note, '送料はご負担ください');
    expect(find.text('route:/'), findsOneWidget);
  });

  testWidgets('表示名は myDisplayNameProvider から取る（G-8 で差し替える所）', (tester) async {
    final repo = FakeTradePostRepository();
    await pumpForm(tester, repo: repo, displayName: 'テスト名');
    expect(find.text('投稿者名は「テスト名」と表示されます'), findsOneWidget);

    await tapKey(tester, 'trade_target_g1');
    await tapKey(tester, 'trade_tag_trade');
    await tapKey(tester, 'trade_handover_mail');
    await tapKey(tester, 'trade_save_button');
    expect(repo.created.single.displayName, 'テスト名');
  });

  testWidgets('新規作成では、プロフィールの X アカウントを初期値にする（G-8）', (tester) async {
    await pumpForm(
      tester,
      repo: FakeTradePostRepository(),
      profile: const UserProfile(displayName: 'テスト名', xAccount: 'oshi_fan'),
    );
    await tester.scrollUntilVisible(
      _key('trade_x_account'),
      200,
      scrollable: listScrollable(),
    );
    expect(
      tester.widget<TextFormField>(_key('trade_x_account')).initialValue,
      'oshi_fan',
    );
  });

  testWidgets('保存に失敗したら、エラーを出して画面に残る', (tester) async {
    final repo = FakeTradePostRepository()..error = Exception('失敗');
    await pumpForm(tester, repo: repo);

    await tapKey(tester, 'trade_target_g1');
    await tapKey(tester, 'trade_tag_trade');
    await tapKey(tester, 'trade_handover_mail');
    await tapKey(tester, 'trade_save_button');

    expect(find.textContaining('保存できませんでした'), findsOneWidget);
    expect(find.text('route:/'), findsNothing);
  });

  group('編集', () {
    testWidgets('保存済みの値を表示し、譲・求を残したまま更新する', (tester) async {
      const give = GiveSet(
        items: [GiveItem(goodsId: 'a', variantId: 'v1', label: 'A')],
      );
      final repo = FakeTradePostRepository()
        ..posts['post1'] = postOf(
          'post1',
          // g3 はフォローしていないが、選択済みなので出す
          groupIds: ['g1', 'g3'],
          gives: [give],
        );
      await pumpForm(tester, repo: repo, location: '/trade/post1/edit');

      expect(find.text('投稿を編集'), findsOneWidget);
      expect(_key('trade_target_g3'), findsOneWidget);
      await tapKey(tester, 'trade_target_g3');
      await tapKey(tester, 'trade_save_button');

      final p = repo.updated.single;
      expect(p.id, 'post1');
      expect(p.groupIds, ['g1']);
      expect([for (final s in p.gives) s.toMap()], [give.toMap()]);
      expect(find.text('route:/'), findsOneWidget);
    });

    testWidgets('手渡しの公演の候補は自分のライブ一覧のものだけ。0件なら追加の案内', (tester) async {
      final repo = FakeTradePostRepository()
        ..posts['post1'] = postOf('post1', handover: [HandoverMethod.hand]);
      await pumpForm(
        tester,
        repo: repo,
        location: '/trade/post1/edit',
        myRepo: FakeMyLiveRepository(),
      );
      await tester.scrollUntilVisible(
        _key('trade_performance_add_live_button'),
        200,
        scrollable: listScrollable(),
      );
      expect(_key('trade_performance_f1'), findsNothing);
      expect(find.text('この推しのライブを、ライブ一覧に追加すると選べます'), findsOneWidget);
      expect(_key('trade_performance_missing'), findsNothing);
    });

    testWidgets('選択済みの公演が一覧に無ければ件数を出し、「外す」で選択を外して保存できる', (tester) async {
      final repo = FakeTradePostRepository()
        ..posts['post1'] = postOf(
          'post1',
          handover: [HandoverMethod.hand],
          performanceIds: ['f1'],
        );
      await pumpForm(
        tester,
        repo: repo,
        location: '/trade/post1/edit',
        myRepo: FakeMyLiveRepository(),
      );
      await tester.scrollUntilVisible(
        _key('trade_performance_missing'),
        200,
        scrollable: listScrollable(),
      );
      expect(find.text('ライブ一覧に無い公演が1件選ばれています'), findsOneWidget);
      await tapKey(tester, 'trade_performance_missing_remove');
      expect(_key('trade_performance_missing'), findsNothing);
      await tapKey(tester, 'trade_save_button');
      expect(repo.updated.single.performanceIds, isEmpty);
    });

    testWidgets('他人の投稿は編集できない', (tester) async {
      final repo = FakeTradePostRepository()
        ..posts['post1'] = postOf('post1', uid: 'other');
      await pumpForm(tester, repo: repo, location: '/trade/post1/edit');
      expect(find.text('自分の投稿だけ編集できます'), findsOneWidget);
    });

    testWidgets('非表示にされた投稿は編集できない', (tester) async {
      final repo = FakeTradePostRepository()
        ..posts['post1'] = postOf('post1', status: TradePostStatus.hidden);
      await pumpForm(tester, repo: repo, location: '/trade/post1/edit');
      expect(find.textContaining('非表示にされているため'), findsOneWidget);
    });

    testWidgets('見つからなければその旨を出す', (tester) async {
      await pumpForm(
        tester,
        repo: FakeTradePostRepository(),
        location: '/trade/none/edit',
      );
      expect(find.text('投稿が見つかりません'), findsOneWidget);
    });
  });

  group('譲セット・求セット', () {
    Future<void> fillRequired(WidgetTester tester) async {
      await tapKey(tester, 'trade_target_g1');
      await tapKey(tester, 'trade_tag_trade');
      await tapKey(tester, 'trade_handover_mail');
    }

    testWidgets('対象の推しを選ぶまで、品目を選ぶボタンは押せない', (tester) async {
      await pumpForm(tester, repo: FakeTradePostRepository());
      await tapKey(tester, 'trade_give_add');
      await tester.scrollUntilVisible(
        _key('trade_give_0_pick'),
        200,
        scrollable: listScrollable(),
      );
      expect(
        tester.widget<ButtonStyleButton>(_key('trade_give_0_pick')).onPressed,
        isNull,
      );
    });

    testWidgets('シートで品目を選んで投稿すると、譲セットに入る', (tester) async {
      final repo = FakeTradePostRepository();
      await pumpForm(tester, repo: repo);
      await fillRequired(tester);

      await tapKey(tester, 'trade_give_add');
      await tapKey(tester, 'trade_give_0_pick');
      // 譲では「全種類」は出さない
      await tester.tap(_key('trade_picker_goods_acsta'));
      await tester.pumpAndSettle();
      expect(_key('trade_picker_whole_acsta'), findsNothing);
      await tester.tap(_key('trade_picker_item_acsta_v1'));
      await tester.tap(_key('trade_picker_item_acsta_v2'));
      await tester.pump();
      await tester.tap(_key('trade_picker_done'));
      await tester.pumpAndSettle();

      expect(find.text('ランダムアクスタ（メンバー1）'), findsOneWidget);
      await tester.scrollUntilVisible(
        _key('trade_give_0_pick_count'),
        200,
        scrollable: listScrollable(),
      );
      await tester.enterText(_key('trade_give_0_pick_count'), '1');
      await tapKey(tester, 'trade_save_button');

      final give = repo.created.single.post.gives.single;
      expect(give.items.map((i) => i.variantId), ['v1', 'v2']);
      expect(give.pickCount, 1);
    });

    testWidgets('求では全種類とメンバーを選べる', (tester) async {
      final repo = FakeTradePostRepository();
      await pumpForm(tester, repo: repo);
      await fillRequired(tester);

      await tapKey(tester, 'trade_want_add');
      await tapKey(tester, 'trade_want_0_pick');
      await tester.tap(_key('trade_picker_goods_acsta'));
      await tester.pumpAndSettle();
      await tester.tap(_key('trade_picker_whole_acsta'));
      await tester.pump();
      await tester.tap(_key('trade_picker_done'));
      await tester.pumpAndSettle();

      await tapKey(tester, 'trade_want_0_members');
      // g1 のメンバーだけが候補
      expect(_key('trade_member_m1'), findsOneWidget);
      expect(_key('trade_member_p1'), findsNothing);
      await tester.tap(_key('trade_member_m1'));
      await tester.pump();
      await tester.tap(_key('trade_member_done'));
      await tester.pumpAndSettle();

      expect(find.text('ランダムアクスタ（全種類）'), findsOneWidget);
      expect(find.text('メンバー1（メンバー指定）'), findsOneWidget);
      await tapKey(tester, 'trade_save_button');

      final targets = repo.created.single.post.wants.single.targets;
      expect(targets.map((t) => t.type), [WantType.goods, WantType.member]);
      expect(targets.last.oshiId, 'm1');
    });

    testWidgets('空のセットのまま投稿するとエラー', (tester) async {
      final repo = FakeTradePostRepository();
      await pumpForm(tester, repo: repo);
      await fillRequired(tester);
      await tapKey(tester, 'trade_give_add');
      await tapKey(tester, 'trade_save_button');

      expect(find.text('譲セット1の品目を1つ以上選ぶか、セットを削除してください'), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    testWidgets('セットを削除できる', (tester) async {
      await pumpForm(tester, repo: FakeTradePostRepository());
      await tapKey(tester, 'trade_give_add');
      expect(find.text('譲セット1'), findsOneWidget);
      await tapKey(tester, 'trade_give_0_remove');
      expect(find.text('譲セット1'), findsNothing);
    });

    testWidgets('グッズを登録する画面へ行き、戻るとグッズを読み直す', (tester) async {
      final goodsRepo = FakeGoodsRepository(const []);
      final router = await pumpForm(
        tester,
        repo: FakeTradePostRepository(),
        goodsRepo: goodsRepo,
      );
      await tapKey(tester, 'trade_target_g1');
      await tapKey(tester, 'trade_give_add');
      await tapKey(tester, 'trade_give_0_pick');
      expect(find.textContaining('グッズが見つかりません'), findsOneWidget);

      await tester.tap(_key('trade_picker_register'));
      await tester.pumpAndSettle();
      expect(find.text('route:/goods'), findsOneWidget);

      goodsRepo.goods = const [acsta];
      router.pop();
      await tester.pumpAndSettle();
      expect(_key('trade_picker_goods_acsta'), findsOneWidget);
    });
  });

  for (final w in layoutWidths) {
    testWidgets('幅 ${w.toInt()} ではみ出さない', (tester) async {
      phoneWidthOverride = w;
      addTearDown(() => phoneWidthOverride = null);
      await pumpForm(tester, repo: FakeTradePostRepository());
      expect(tester.takeException(), isNull);
    });
  }
}
