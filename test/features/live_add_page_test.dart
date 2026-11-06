// ライブを追加する画面（/lives/add）のウィジェットテスト（Q4）。
// 本物のプロバイダを使い、リポジトリだけを偽物に差し替える。
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/live_add/live_add_page.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';
import 'package:oshiashi/repositories/live_repository.dart';

import 'live_test_helpers.dart';
import 'oshi_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

final now = DateTime(2026, 11, 5, 12);
DateTime h(int hours) => now.add(Duration(hours: hours));

final g1 = oshi('g1', 'グループ1');
final g2 = oshi('g2', 'グループ2');
const p1 = OshiSummary(
  id: 'p1',
  kind: OshiKind.person,
  name: '個人1',
  genre: OshiGenre.idol,
  status: OshiStatus.approved,
  groupIds: ['g9'],
);

FakeLiveRepository liveRepo() => FakeLiveRepository(
  lives: const [
    Live(id: 'a', title: 'ＬＩＶＥ ツアー', groupIds: ['g1']),
    Live(id: 'b', title: 'フェス', groupIds: ['g1']),
  ],
  performances: [perfOf('pa', 'a', h(48)), perfOf('pb', 'b', h(24))],
);

Future<void> pumpAdd(
  WidgetTester tester, {
  FakeLiveRepository? live,
  FakeMyLiveRepository? myRepo,
  List<OshiSummary>? follows,
  bool settle = true,
}) async {
  final f = follows ?? [g1, g2];
  final router = GoRouter(
    initialLocation: '/lives/add',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('route:/')),
      GoRoute(path: '/lives/add', builder: (_, _) => const LiveAddPage()),
      GoRoute(
        path: '/lives/:id',
        builder: (_, s) => Text('route:/lives/${s.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => const Text('route:/register'),
      ),
      GoRoute(
        path: '/oshi/search',
        builder: (_, _) => const Text('route:/oshi/search'),
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
          FakeOshiRepository([g1, g2, p1]),
        ),
        followRepositoryProvider.overrideWithValue(
          FakeFollowRepository(
            FollowState(
              groupIds: {
                for (final o in f)
                  if (o.kind == OshiKind.group) o.id,
              },
              oshiIds: {
                for (final o in f)
                  if (o.kind == OshiKind.person) o.id,
              },
            ),
          ),
        ),
        liveRepositoryProvider.overrideWithValue(live ?? liveRepo()),
        myLiveRepositoryProvider.overrideWithValue(
          myRepo ?? FakeMyLiveRepository(),
        ),
        applicationRepositoryProvider.overrideWithValue(
          FakeApplicationRepository(),
        ),
        nowProvider.overrideWithValue(now),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('推しを選ぶ前は、ライブを読まない（フォロー0件なら案内）', (tester) async {
    final live = liveRepo();
    await pumpAdd(tester, live: live, follows: const []);
    expect(_key('live_add_no_oshi'), findsOneWidget);
    expect(live.targetsSeen, isEmpty);
    await tester.tap(_key('live_add_search_oshi_button'));
    await tester.pumpAndSettle();
    expect(find.text('route:/oshi/search'), findsOneWidget);
  });

  testWidgets('先頭の推しのライブが近い順に出る。他の推しのチップで切り替わる', (tester) async {
    final live = liveRepo();
    await pumpAdd(tester, live: live);
    expect(_key('live_add_results'), findsOneWidget);
    expect(live.targetsSeen.last, const FollowTargets(groupIds: {'g1'}));
    double y(String id) => tester.getTopLeft(_key('live_add_tile_$id')).dy;
    expect(y('b'), lessThan(y('a')));

    await tester.tap(_key('live_add_oshi_chip_group/g2'));
    await tester.pumpAndSettle();
    expect(live.targetsSeen.last, const FollowTargets(groupIds: {'g2'}));
  });

  testWidgets('個人の推しを選ぶと、所属グループも対象に含めて探す', (tester) async {
    final live = liveRepo();
    await pumpAdd(tester, live: live, follows: [p1]);
    expect(
      live.targetsSeen.last,
      const FollowTargets(groupIds: {'g9'}, oshiIds: {'p1'}),
    );
  });

  testWidgets('ライブ名で絞り込める（全角・半角・大小文字の揺れを吸収）。無ければ「見つかりませんでした」', (tester) async {
    await pumpAdd(tester);
    await tester.enterText(_key('live_add_query_field'), 'live');
    await tester.pumpAndSettle();
    expect(_key('live_add_tile_a'), findsOneWidget);
    expect(_key('live_add_tile_b'), findsNothing);

    await tester.enterText(_key('live_add_query_field'), 'ないよ');
    await tester.pumpAndSettle();
    expect(_key('live_add_empty'), findsOneWidget);
    expect(find.textContaining('見つかりませんでした'), findsOneWidget);

    await tester.tap(_key('live_add_register_fab'));
    await tester.pumpAndSettle();
    expect(find.text('route:/register'), findsOneWidget);
  });

  testWidgets('追加 → 追加済み → 押すと外れる', (tester) async {
    final my = FakeMyLiveRepository();
    await pumpAdd(tester, myRepo: my);
    expect(_key('live_add_add_button_a'), findsOneWidget);
    await tester.tap(_key('live_add_add_button_a'));
    await tester.pumpAndSettle();
    expect(my.ids, {'a'});
    expect(_key('live_add_remove_button_a'), findsOneWidget);
    expect(find.text('追加済み'), findsOneWidget);
    expect(_key('live_add_add_button_b'), findsOneWidget);

    await tester.tap(_key('live_add_remove_button_a'));
    await tester.pumpAndSettle();
    expect(my.ids, isEmpty);
    expect(_key('live_add_add_button_a'), findsOneWidget);
  });

  testWidgets('連打しても書き込みは1回。処理中はボタンが無効', (tester) async {
    final my = FakeMyLiveRepository()..writeGate = Completer<void>();
    await pumpAdd(tester, myRepo: my);
    await tester.tap(_key('live_add_add_button_a'));
    await tester.pump();
    expect(onPressedOf(tester, _key('live_add_add_button_a')), isNull);
    await tester.tap(_key('live_add_add_button_a'), warnIfMissed: false);
    await tester.pump();
    expect(my.added, hasLength(1));
    my.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(my.ids, {'a'});
  });

  testWidgets('書き込みに失敗したら日本語の SnackBar。状態は元のまま', (tester) async {
    final my = FakeMyLiveRepository()..writeError = Exception('失敗');
    await pumpAdd(tester, myRepo: my);
    await tester.tap(_key('live_add_add_button_a'));
    await tester.pumpAndSettle();
    expect(find.text('ライブ一覧を更新できませんでした。もう一度お試しください'), findsOneWidget);
    expect(_key('live_add_add_button_a'), findsOneWidget);
  });

  testWidgets('エラー → もう一度読み込む', (tester) async {
    final live = liveRepo()..fail = true;
    await pumpAdd(tester, live: live);
    expect(_key('live_add_error'), findsOneWidget);
    live.fail = false;
    await tester.tap(_key('live_add_retry_button'));
    await tester.pumpAndSettle();
    expect(_key('live_add_tile_a'), findsOneWidget);
  });

  testWidgets('読み込み中', (tester) async {
    await pumpAdd(tester, live: liveRepo()..emitInitial = false, settle: false);
    await tester.pump();
    expect(_key('live_add_loading'), findsOneWidget);
  });

  testWidgets('行を押すとライブ詳細へ', (tester) async {
    await pumpAdd(tester);
    await tester.tap(_key('live_add_tile_a'));
    await tester.pumpAndSettle();
    expect(find.text('route:/lives/a'), findsOneWidget);
  });

  testWidgets('スマホの幅（360px）で、長い名前でもはみ出さない', (tester) async {
    usePhoneSize(tester);
    await pumpAdd(
      tester,
      live: FakeLiveRepository(
        lives: [
          Live(id: 'a', title: 'ラ' * 100, groupIds: const ['g1']),
        ],
        performances: [perfOf('pa', 'a', h(24))],
      ),
    );
    expect(_key('live_add_tile_a'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
