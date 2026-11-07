// 交換トップ（/trade。G-3-4）のウィジェットテスト
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/trade/trade_top_page.dart';
import 'package:oshiashi/models/trade_post.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/providers/trade_post_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';

import 'live_test_helpers.dart';
import 'oshi_test_helpers.dart';
import 'trade_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> pumpTop(
  WidgetTester tester,
  FakeTradePostRepository r, {
  String location = '/trade',
}) async {
  usePhoneSize(tester);
  r.mineInitial = [postOf('a', status: TradePostStatus.closed)];
  addTearDown(r.mine.close);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/trade',
        builder: (_, s) => TradeTopPage(
          initialTab: TradeTab.fromQuery(s.uri.queryParameters['tab']),
        ),
      ),
      GoRoute(path: '/trade/new', builder: (_, _) => const Text('route:new')),
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
        followRepositoryProvider.overrideWithValue(FakeFollowRepository()),
        liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
        nowProvider.overrideWithValue(DateTime(2026, 11, 5, 12)),
        tradePostRepositoryProvider.overrideWithValue(r),
        tradeChatRepositoryProvider.overrideWithValue(
          FakeTradeChatRepository()..chatsInitial = const [],
        ),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
}

void main() {
  test('TradeTab.fromQuery：知らない値や指定なしは掲示板', () {
    expect(TradeTab.fromQuery('mine'), TradeTab.mine);
    expect(TradeTab.fromQuery('match'), TradeTab.match);
    expect(TradeTab.fromQuery(null), TradeTab.board);
    expect(TradeTab.fromQuery('xxx'), TradeTab.board);
  });

  testWidgets('最初は掲示板を開き、タブで切り替えられる', (tester) async {
    final repo = FakeTradePostRepository();
    await pumpTop(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('グッズ交換'), findsOneWidget);
    // フォロー中の推しが0件なら、推しを探す案内（Da-6）
    expect(find.text('推しをフォローすると、交換の投稿が見られます'), findsOneWidget);
    expect(_key('trade_board_find_oshi_button'), findsOneWidget);
    expect(find.text('フォロー中の推しがいません。先に推しをフォローしてください'), findsNothing);

    await tester.tap(_key('trade_tab_match'));
    await tester.pumpAndSettle();
    // 求のある募集中の投稿がないので、案内を出す
    expect(_key('trade_match_no_wants'), findsOneWidget);

    await tester.tap(_key('trade_tab_mine'));
    await tester.pumpAndSettle();
    expect(find.text('投稿者名：匿名'), findsOneWidget);
    expect(_key('my_trade_post_a'), findsOneWidget);
  });

  testWidgets('?tab=mine なら自分の投稿を開く', (tester) async {
    final repo = FakeTradePostRepository();
    await pumpTop(tester, repo, location: '/trade?tab=mine');
    await tester.pumpAndSettle();
    expect(_key('my_trade_post_a'), findsOneWidget);
  });

  testWidgets('右下のボタンで作成画面へ行ける（どのタブからでも）', (tester) async {
    await pumpTop(
      tester,
      FakeTradePostRepository(),
      location: '/trade?tab=match',
    );
    await tester.pumpAndSettle();
    await tester.tap(_key('trade_new_button'));
    await tester.pumpAndSettle();
    expect(find.text('route:new'), findsOneWidget);
  });
}
