import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/live/upcoming_deadlines_section.dart';
import 'package:oshiashi/models/application.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';
import 'package:oshiashi/repositories/live_repository.dart';

import 'live_test_helpers.dart';
import 'oshi_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

// 「今」は固定する（nowProvider の1分のタイマーも止まる）
final now = DateTime(2026, 11, 5, 12);
DateTime h(int hours) => now.add(Duration(hours: hours));

const live1 = Live(id: 'l1', title: 'ライブ1', groupIds: ['g1']);
const live2 = Live(id: 'l2', title: 'ライブ2', oshiIds: ['p1']);

/// UpcomingDeadlinesSection を、遷移先を確かめられるルーターの中に置く
Future<void> pumpSection(
  WidgetTester tester, {
  required FakeOshiRepository oshiRepo,
  required FakeFollowRepository followRepo,
  FakeLiveRepository? liveRepo,
  FakeApplicationRepository? appRepo,
  bool settle = true,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: ListView(children: const [UpcomingDeadlinesSection()]),
        ),
        routes: [
          GoRoute(
            path: 'oshi/search',
            builder: (_, _) => const Text('route:/oshi/search'),
          ),
          GoRoute(
            path: 'lives',
            builder: (_, _) => const Text('route:/lives'),
            routes: [
              GoRoute(
                path: ':liveId',
                builder: (_, s) =>
                    Text('route:/lives/${s.pathParameters['liveId']}'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        oshiRepositoryProvider.overrideWithValue(oshiRepo),
        followRepositoryProvider.overrideWithValue(followRepo),
        liveRepositoryProvider.overrideWithValue(
          liveRepo ?? FakeLiveRepository(),
        ),
        applicationRepositoryProvider.overrideWithValue(
          appRepo ?? FakeApplicationRepository(),
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

final oshis = [
  oshi('g1', 'グループ1'),
  oshi('g2', '所属グループ'),
  OshiSummary(
    id: 'p1',
    kind: OshiKind.person,
    name: '個人1',
    genre: OshiGenre.idol,
    status: OshiStatus.approved,
    groupIds: const ['g2'],
  ),
];

FakeFollowRepository following() =>
    FakeFollowRepository(const FollowState(groupIds: {'g1'}, oshiIds: {'p1'}));

void main() {
  testWidgets('読み込み中（フォローの読み込み前）', (tester) async {
    await pumpSection(
      tester,
      oshiRepo: FakeOshiRepository(oshis),
      followRepo: following()..emitInitial = false,
      settle: false,
    );
    expect(_key('home_deadlines_loading'), findsOneWidget);
  });

  testWidgets('読み込み中（締切の読み込み前）', (tester) async {
    await pumpSection(
      tester,
      oshiRepo: FakeOshiRepository(oshis),
      followRepo: following(),
      liveRepo: FakeLiveRepository()..emitInitial = false,
      settle: false,
    );
    await tester.pump();
    expect(_key('home_deadlines_loading'), findsOneWidget);
    expect(_key('home_deadlines_empty'), findsNothing);
  });

  testWidgets('フォロー0件: 問い合わせず、「推しを探す」へ行ける', (tester) async {
    final liveRepo = FakeLiveRepository();
    await pumpSection(
      tester,
      oshiRepo: FakeOshiRepository(oshis),
      followRepo: FakeFollowRepository(),
      liveRepo: liveRepo,
    );
    expect(_key('home_deadlines_no_follow'), findsOneWidget);
    // リポジトリには空の対象だけが渡る（空なら Firestore に問い合わせない契約。
    // live_repository_test.dart で確かめている）
    expect(liveRepo.targetsSeen.every((t) => t.isEmpty), isTrue);

    await tester.tap(_key('home_deadlines_search_button'));
    await tester.pumpAndSettle();
    expect(find.text('route:/oshi/search'), findsOneWidget);
  });

  testWidgets('フォロー中で締切0件: 「近い締切はありません」', (tester) async {
    await pumpSection(
      tester,
      oshiRepo: FakeOshiRepository(oshis),
      followRepo: following(),
      liveRepo: FakeLiveRepository(
        lives: [live1],
        receptions: [
          // 期限切れだけ
          recOf('old', 'l1', applyEndAt: h(-1)),
        ],
      ),
    );
    expect(_key('home_deadlines_empty'), findsOneWidget);
    expect(_key('home_deadlines_list'), findsNothing);
  });

  testWidgets('対象: フォロー中のグループ・推しの所属グループ・推しで問い合わせる', (tester) async {
    final liveRepo = FakeLiveRepository();
    await pumpSection(
      tester,
      oshiRepo: FakeOshiRepository(oshis),
      followRepo: following(),
      liveRepo: liveRepo,
    );
    expect(liveRepo.targetsSeen.toSet(), {
      const FollowTargets(groupIds: {'g1', 'g2'}, oshiIds: {'p1'}),
    });
  });

  testWidgets('エラー → もう一度読み込む', (tester) async {
    final liveRepo = FakeLiveRepository(
      lives: [live1],
      receptions: [recOf('r1', 'l1', applyEndAt: h(48))],
    )..fail = true;
    await pumpSection(
      tester,
      oshiRepo: FakeOshiRepository(oshis),
      followRepo: following(),
      liveRepo: liveRepo,
    );
    expect(_key('home_deadlines_error'), findsOneWidget);
    expect(find.text('締切を読み込めませんでした'), findsOneWidget);

    liveRepo.fail = false;
    await tester.tap(_key('home_deadlines_retry_button'));
    await tester.pumpAndSettle();
    expect(_key('home_deadlines_list'), findsOneWidget);
    expect(_key('home_deadline_tile_r1'), findsOneWidget);
  });

  testWidgets('申込状況の読み込みエラーもエラー表示', (tester) async {
    await pumpSection(
      tester,
      oshiRepo: FakeOshiRepository(oshis),
      followRepo: following(),
      liveRepo: FakeLiveRepository(
        lives: [live1],
        receptions: [recOf('r1', 'l1', applyEndAt: h(48))],
      ),
      appRepo: FakeApplicationRepository()..fail = true,
    );
    expect(_key('home_deadlines_error'), findsOneWidget);
  });

  testWidgets('近い順に5件まで。期限切れ・ライブが見つからない受付は出さない', (tester) async {
    await pumpSection(
      tester,
      oshiRepo: FakeOshiRepository(oshis),
      followRepo: following(),
      liveRepo: FakeLiveRepository(
        lives: [live1, live2],
        receptions: [
          recOf('r7', 'l1', applyEndAt: h(70)),
          recOf('r3', 'l2', applyEndAt: h(30)),
          recOf('r1', 'l1', applyEndAt: h(10)),
          recOf('expired', 'l1', applyEndAt: h(-1)),
          recOf('orphan', 'unknown', applyEndAt: h(1)),
          recOf('r5', 'l1', applyEndAt: h(50)),
          recOf('r2', 'l2', applyEndAt: h(20)),
          recOf('r6', 'l2', applyEndAt: h(60)),
          recOf('r4', 'l1', applyEndAt: h(40)),
        ],
      ),
    );
    final tiles = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('home_deadline_tile_'),
    );
    final keys = [
      for (final w in tester.widgetList(tiles))
        (w.key! as ValueKey<String>).value.replaceFirst(
          'home_deadline_tile_',
          '',
        ),
    ];
    expect(homeDeadlineLimit, 5);
    expect(keys, ['r1', 'r2', 'r3', 'r4', 'r5']);
    // 上から順に並ぶ
    final ys = [
      for (final k in keys) tester.getTopLeft(_key('home_deadline_tile_$k')).dy,
    ];
    expect(ys, orderedEquals([...ys]..sort()));
  });

  testWidgets('1行の中身: ライブ名・受付名・次にやること', (tester) async {
    await pumpSection(
      tester,
      oshiRepo: FakeOshiRepository(oshis),
      followRepo: following(),
      liveRepo: FakeLiveRepository(
        lives: [live1],
        receptions: [
          recOf('r1', 'l1', applyEndAt: h(48), name: 'FC1次先行'),
          recOf(
            'r2',
            'l1',
            applyEndAt: h(72),
            applyStartAt: DateTime(2026, 11, 6, 10),
            name: 'アプグレ',
            winnersOnly: true,
          ),
        ],
      ),
    );
    final tile1 = _key('home_deadline_tile_r1');
    expect(
      find.descendant(of: tile1, matching: find.text('ライブ1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile1, matching: find.text('FC1次先行')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile1, matching: find.text('申込期限まであと2日')),
      findsOneWidget,
    );

    final tile2 = _key('home_deadline_tile_r2');
    expect(
      find.descendant(of: tile2, matching: find.text('アプグレ 【当選者のみ】')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tile2,
        matching: find.text('受付開始 2026/11/6(金) 10:00〜'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('24時間以内は、色だけでなくアイコンと文字でも示す', (tester) async {
    await pumpSection(
      tester,
      oshiRepo: FakeOshiRepository(oshis),
      followRepo: following(),
      liveRepo: FakeLiveRepository(
        lives: [live1],
        receptions: [
          recOf('soon', 'l1', applyEndAt: h(5)),
          recOf('later', 'l1', applyEndAt: h(48)),
        ],
      ),
    );
    final soon = _key('home_deadline_tile_soon');
    expect(
      find.descendant(of: soon, matching: find.text('申込期限まであと5時間')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: soon,
        matching: find.byIcon(Icons.warning_amber_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('home_deadline_tile_later'),
        matching: find.byIcon(Icons.warning_amber_rounded),
      ),
      findsNothing,
    );
  });

  testWidgets('申込状況が変わると、次の締切が切り替わる', (tester) async {
    final appRepo = FakeApplicationRepository();
    await pumpSection(
      tester,
      oshiRepo: FakeOshiRepository(oshis),
      followRepo: following(),
      liveRepo: FakeLiveRepository(
        lives: [live1],
        receptions: [
          recOf(
            'r1',
            'l1',
            applyEndAt: h(48),
            resultAt: DateTime(2026, 11, 20, 18),
            paymentDeadline: h(5),
          ),
        ],
      ),
      appRepo: appRepo,
    );
    Finder text(String t) => find.descendant(
      of: _key('home_deadline_tile_r1'),
      matching: find.text(t),
    );
    expect(text('申込期限まであと2日'), findsOneWidget);

    final r = recOf('r1', 'l1', applyEndAt: h(48));
    await appRepo.setStatus('u1', r, ApplicationStatus.applied);
    await tester.pumpAndSettle();
    expect(text('当落発表 2026/11/20(金) 18:00'), findsOneWidget);

    await appRepo.setStatus('u1', r, ApplicationStatus.won);
    await tester.pumpAndSettle();
    expect(text('入金期限まであと5時間'), findsOneWidget);

    await appRepo.setStatus('u1', r, ApplicationStatus.paid);
    await tester.pumpAndSettle();
    expect(_key('home_deadline_tile_r1'), findsNothing);
    expect(_key('home_deadlines_empty'), findsOneWidget);

    await appRepo.setStatus('u1', r, null);
    await tester.pumpAndSettle();
    expect(text('申込期限まであと2日'), findsOneWidget);
  });

  testWidgets('受付が増えると一覧に出る（購読が続いている）', (tester) async {
    final liveRepo = FakeLiveRepository(lives: [live1]);
    await pumpSection(
      tester,
      oshiRepo: FakeOshiRepository(oshis),
      followRepo: following(),
      liveRepo: liveRepo,
    );
    expect(_key('home_deadlines_empty'), findsOneWidget);
    liveRepo.setReceptions([recOf('r1', 'l1', applyEndAt: h(48))]);
    await tester.pumpAndSettle();
    expect(_key('home_deadline_tile_r1'), findsOneWidget);
  });

  testWidgets('行を押すとライブ詳細、「すべて見る」でライブ一覧へ', (tester) async {
    Future<void> pump() => pumpSection(
      tester,
      oshiRepo: FakeOshiRepository(oshis),
      followRepo: following(),
      liveRepo: FakeLiveRepository(
        lives: [live2],
        receptions: [recOf('r1', 'l2', applyEndAt: h(48))],
      ),
    );
    await pump();
    await tester.tap(_key('home_deadline_tile_r1'));
    await tester.pumpAndSettle();
    expect(find.text('route:/lives/l2'), findsOneWidget);

    await pump();
    await tester.tap(_key('home_deadlines_see_all_button'));
    await tester.pumpAndSettle();
    expect(find.text('route:/lives'), findsOneWidget);
  });

  testWidgets('スマホの幅（360px）で、長い名前でもはみ出さない', (tester) async {
    usePhoneSize(tester);
    await pumpSection(
      tester,
      oshiRepo: FakeOshiRepository(oshis),
      followRepo: following(),
      liveRepo: FakeLiveRepository(
        lives: [
          Live(id: 'l1', title: 'ラ' * 100, groupIds: const ['g1']),
        ],
        receptions: [
          recOf(
            'r1',
            'l1',
            applyEndAt: h(5),
            applyStartAt: h(1),
            name: '受' * 50,
            winnersOnly: true,
          ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(_key('home_deadline_tile_r1'), findsOneWidget);
  });
}
