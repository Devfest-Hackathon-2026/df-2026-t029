// ホームのウィジェットテスト（A1）。幅違い・長い文字でのはみ出しと、主な区画の表示。
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/home/home_page.dart';
import 'package:oshiashi/models/expense.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/live_memory.dart';
import 'package:oshiashi/models/user_profile.dart';
import 'package:oshiashi/providers/expense_providers.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/memory_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/providers/profile_providers.dart';
import 'package:oshiashi/providers/trade_post_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/utils/expense_summary.dart';
import 'package:oshiashi/utils/memory_album.dart';

import 'live_test_helpers.dart';
import 'oshi_test_helpers.dart';
import 'trade_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

final _now = DateTime(2026, 11, 5, 12);

Future<GoRouter> pumpHome(
  WidgetTester tester, {
  required double width,
  double textScale = 1,
  double height = 900,
  bool withData = true,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(
        path: '/lives/add',
        builder: (_, _) => const Text('route:/lives/add'),
      ),
      GoRoute(path: '/expenses', builder: (_, _) => const Text('route:exp')),
      GoRoute(path: '/trade', builder: (_, _) => const Text('route:/trade')),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Text('route:/profile'),
      ),
    ],
  );
  addTearDown(router.dispose);
  final lives = [
    for (var i = 0; i < 4; i++)
      Live(id: 'l$i', title: 'とても長いライブ名' * 6, groupIds: const ['g1']),
  ];
  final live = FakeLiveRepository(
    lives: withData ? lives : const [],
    performances: [
      if (withData)
        for (var i = 0; i < 4; i++)
          perfOf('p$i', 'l$i', _now.add(Duration(days: 2 + i * 3))),
    ],
    receptions: [
      if (withData)
        for (var i = 0; i < 4; i++)
          recOf(
            'r$i',
            'l$i',
            applyEndAt: _now.add(Duration(days: 1 + i)),
            name: '長い受付名' * 5,
          ),
    ],
  );
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
        liveRepositoryProvider.overrideWithValue(live),
        myLiveRepositoryProvider.overrideWithValue(
          FakeMyLiveRepository(ids: [for (final l in live.lives) l.id!]),
        ),
        applicationRepositoryProvider.overrideWithValue(
          FakeApplicationRepository(),
        ),
        nowProvider.overrideWithValue(_now),
        myProfileProvider.overrideWithValue(
          const AsyncData(UserProfile(displayName: 'とても長いハンドルネームの人です')),
        ),
        homeTradePostsProvider.overrideWithValue(
          AsyncData(withData ? [postOf('a'), postOf('b'), postOf('c')] : []),
        ),
        expenseItemsProvider.overrideWithValue(
          AsyncData(
            withData
                ? [
                    ExpenseItem(
                      source: ExpenseSource.manual,
                      sourceId: 'x',
                      category: ExpenseCategory.values.first,
                      title: 'グッズ',
                      amount: 12000,
                      date: DateTime.now(),
                    ),
                  ]
                : const <ExpenseItem>[],
          ),
        ),
        myBudgetProvider.overrideWith((ref) => Stream.value(10000)),
        memoryAlbumProvider.overrideWithValue(
          AsyncData(
            MemoryAlbum(
              upcoming: const [],
              attended: [
                if (withData)
                  LiveMemory(
                    performanceId: 'p9',
                    liveId: 'l9',
                    liveTitle: 'とても長いライブ名' * 6,
                    startAt: DateTime(2026, 10, 1, 18),
                    venue: '長い会場名' * 6,
                  ),
              ],
            ),
          ),
        ),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('主な区画が出る（あいさつ・追加・次の締切・今後のライブ・新しい交換・推し活費）', (tester) async {
    await pumpHome(tester, width: 390, height: 3000);
    expect(_key('home_greeting'), findsOneWidget);
    expect(find.textContaining('こんにちは'), findsOneWidget);
    expect(find.text('次の締切'), findsOneWidget);
    expect(find.text('今後のライブ'), findsOneWidget);
    expect(find.text('新しい交換'), findsOneWidget);
    expect(_key('home_new_trades'), findsOneWidget);
  });

  testWidgets('幅 390: 上のバーに「おしあし」とアカウントのボタン。PC の幅では上のバーが出ない', (tester) async {
    await pumpHome(tester, width: 390);
    expect(_key('hako_app_bar'), findsOneWidget);
    expect(find.text('おしあし'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsWidgets);
    await pumpHome(tester, width: 1000);
    expect(_key('hako_app_bar'), findsNothing);
    expect(_key('hako_page_title'), findsNothing);
  });

  testWidgets('アカウントのメニューから「ログアウト」「プロフィール」が選べる', (tester) async {
    await pumpHome(tester, width: 390);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('ログアウト'), findsOneWidget);
    await tester.tap(find.text('プロフィール'));
    await tester.pumpAndSettle();
    expect(find.text('route:/profile'), findsOneWidget);
  });

  for (final w in [320.0, 360.0, 390.0, 430.0, 720.0, 1000.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('幅 ${w.toInt()}・文字 $scale 倍ではみ出さない', (tester) async {
        await pumpHome(tester, width: w, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('データが無くても幅 320 で例外が出ない', (tester) async {
    await pumpHome(tester, width: 320, withData: false);
    expect(tester.takeException(), isNull);
  });
}
