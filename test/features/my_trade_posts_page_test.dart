// 自分の投稿の一覧（/trade/mine。G-2-6）と、要約の関数のテスト
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/trade/my_trade_posts_page.dart';
import 'package:oshiashi/features/trade/trade_post_summary.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/models/trade_post.dart';
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
  ),
];

const give = GiveSet(
  items: [
    GiveItem(goodsId: 'a', variantId: 'v1', label: 'アクスタ（A）'),
    GiveItem(goodsId: 'a', variantId: 'v2', label: 'アクスタ（B）'),
  ],
);
const want = WantSet(
  targets: [WantTarget(type: WantType.member, oshiId: 'p1', label: '個人1')],
);

Future<void> pumpList(
  WidgetTester tester,
  FakeTradePostRepository repo, {
  List<TradePost>? posts,
  String? displayName,
}) async {
  usePhoneSize(tester);
  final router = GoRouter(
    initialLocation: '/trade/mine',
    routes: [
      GoRoute(path: '/trade/mine', builder: (_, _) => const MyTradePostsPage()),
      GoRoute(path: '/trade/new', builder: (_, _) => const Text('route:new')),
      GoRoute(
        path: '/trade/:id/edit',
        builder: (_, s) => Text('route:edit:${s.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(repo.mine.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        oshiRepositoryProvider.overrideWithValue(FakeOshiRepository(oshis)),
        followRepositoryProvider.overrideWithValue(FakeFollowRepository()),
        liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
        nowProvider.overrideWithValue(DateTime(2026, 11, 5, 12)),
        tradePostRepositoryProvider.overrideWithValue(repo),
        if (displayName != null)
          myDisplayNameProvider.overrideWithValue(displayName),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  if (posts != null) repo.mine.add(posts);
  await tester.pumpAndSettle();
}

Future<void> openMenu(WidgetTester tester, String postId) async {
  await tester.tap(_key('my_trade_menu_$postId'));
  await tester.pumpAndSettle();
}

void main() {
  group('summarizeLabels', () {
    test('3個までならそのまま、超えたら「ほか N 件」', () {
      expect(summarizeLabels([]), '');
      expect(summarizeLabels(['A', 'B', 'C']), 'A、B、C');
      expect(summarizeLabels(['A', 'B', 'C', 'D', 'E']), 'A、B、C ほか2件');
    });

    test('同じ表示名は1つにまとめる', () {
      expect(summarizeLabels(['A', 'A', 'B']), 'A、B');
    });
  });

  test('targetNames：グループ → 個人の順で、知らない ID は省く', () {
    const post = TradePost(
      groupIds: ['g1', 'gx'],
      oshiIds: ['p1'],
      tags: [TradeTag.trade],
      handover: [HandoverMethod.mail],
    );
    expect(targetNames(post, oshis), 'グループ1、個人1');
  });

  testWidgets('投稿がなければその旨と、投稿者名を出す', (tester) async {
    await pumpList(tester, FakeTradePostRepository(), posts: []);
    expect(find.text('投稿者名：匿名'), findsOneWidget);
    expect(find.text('まだ投稿がありません'), findsOneWidget);
  });

  testWidgets('投稿者名は myDisplayNameProvider から取る', (tester) async {
    await pumpList(
      tester,
      FakeTradePostRepository(),
      posts: [],
      displayName: 'テスト名',
    );
    expect(find.text('投稿者名：テスト名'), findsOneWidget);
  });

  testWidgets('投稿の要約（状態・推し・タグ・譲・求）を出す', (tester) async {
    await pumpList(
      tester,
      FakeTradePostRepository(),
      posts: [
        postOf(
          'a',
          tags: const [TradeTag.trade, TradeTag.buy],
          gives: const [give],
          wants: const [want],
        ),
        postOf('b', status: TradePostStatus.closed),
      ],
    );
    expect(find.text('募集中'), findsOneWidget);
    expect(find.text('募集終了'), findsOneWidget);
    expect(find.text('グループ1'), findsNWidgets(2));
    expect(find.text('交換希望・買取希望'), findsOneWidget);
    expect(find.text('譲：アクスタ（A）、アクスタ（B）'), findsOneWidget);
    expect(find.text('求：個人1'), findsOneWidget);
    expect(find.text('品目なし（自動のマッチングの対象外）'), findsOneWidget);
  });

  testWidgets('募集終了は確認してから変更する', (tester) async {
    final repo = FakeTradePostRepository();
    await pumpList(tester, repo, posts: [postOf('a')]);

    await openMenu(tester, 'a');
    await tester.tap(find.text('募集終了').last);
    await tester.pumpAndSettle();
    expect(find.text('募集を終了しますか？'), findsOneWidget);

    // キャンセルなら変えない
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(repo.statusChanges, isEmpty);

    await openMenu(tester, 'a');
    await tester.tap(find.text('募集終了').last);
    await tester.pumpAndSettle();
    await tester.tap(_key('my_trade_close_confirm'));
    await tester.pumpAndSettle();
    expect(repo.statusChanges, [('a', TradePostStatus.closed)]);
    expect(find.text('募集を終了しました'), findsOneWidget);
  });

  testWidgets('募集終了の投稿は、確認なしで再開する', (tester) async {
    final repo = FakeTradePostRepository();
    await pumpList(
      tester,
      repo,
      posts: [postOf('a', status: TradePostStatus.closed)],
    );
    await openMenu(tester, 'a');
    await tester.tap(find.text('再開'));
    await tester.pumpAndSettle();
    expect(repo.statusChanges, [('a', TradePostStatus.open)]);
  });

  testWidgets('変更に失敗したらメッセージを出す', (tester) async {
    final repo = FakeTradePostRepository()..error = Exception('失敗');
    await pumpList(
      tester,
      repo,
      posts: [postOf('a', status: TradePostStatus.closed)],
    );
    await openMenu(tester, 'a');
    await tester.tap(find.text('再開'));
    await tester.pumpAndSettle();
    expect(find.textContaining('変更できませんでした'), findsOneWidget);
  });

  testWidgets('編集を選ぶと編集画面へ行く', (tester) async {
    await pumpList(tester, FakeTradePostRepository(), posts: [postOf('a')]);
    await openMenu(tester, 'a');
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    expect(find.text('route:edit:a'), findsOneWidget);
  });

  testWidgets('非表示の投稿は操作できず、その旨を出す', (tester) async {
    await pumpList(
      tester,
      FakeTradePostRepository(),
      posts: [postOf('a', status: TradePostStatus.hidden)],
    );
    expect(_key('my_trade_menu_a'), findsNothing);
    expect(find.textContaining('運営により非表示'), findsOneWidget);
  });

  testWidgets('右下のボタンで作成画面へ行く', (tester) async {
    await pumpList(tester, FakeTradePostRepository(), posts: []);
    await tester.tap(_key('my_trade_new_button'));
    await tester.pumpAndSettle();
    expect(find.text('route:new'), findsOneWidget);
  });
}
