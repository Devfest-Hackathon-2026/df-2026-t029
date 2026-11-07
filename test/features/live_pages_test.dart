// ライブ一覧（/lives）とライブ詳細（/lives/:liveId）のウィジェットテスト（Q4）。
// 本物のプロバイダを使い、リポジトリだけを偽物に差し替える。
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/live/live_detail_page.dart';
import 'package:oshiashi/features/live/live_list_page.dart';
import 'package:oshiashi/models/application.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/models/reception.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';

import 'live_test_helpers.dart';
import 'oshi_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

// 「今」は固定する（2026/11/5(木) 12:00、端末の時刻）
final now = DateTime(2026, 11, 5, 12);
DateTime h(int hours) => now.add(Duration(hours: hours));

final oshis = [
  oshi('g1', 'グループ1'),
  OshiSummary(
    id: 'p1',
    kind: OshiKind.person,
    name: '個人1',
    genre: OshiGenre.idol,
    status: OshiStatus.approved,
  ),
];

FakeFollowRepository following() =>
    FakeFollowRepository(const FollowState(groupIds: {'g1'}, oshiIds: {'p1'}));

Future<GoRouter> pumpAt(
  WidgetTester tester,
  String location, {
  FakeLiveRepository? liveRepo,
  FakeApplicationRepository? appRepo,
  FakeMyLiveRepository? myRepo,
  FakeFollowRepository? followRepo,
  FakeOshiRepository? oshiRepo,
  bool settle = true,
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Text('route:/'),
        routes: [
          GoRoute(
            path: 'lives',
            builder: (_, _) => const LiveListPage(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (_, _) => const Text('route:/lives/add'),
              ),
              GoRoute(
                path: ':liveId',
                builder: (_, s) =>
                    LiveDetailPage(liveId: s.pathParameters['liveId']!),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/live-form',
        builder: (_, _) => const Text('route:/live-form'),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => const Text('route:/register'),
      ),
    ],
  );
  addTearDown(router.dispose);
  final live = liveRepo ?? FakeLiveRepository();
  // 指定が無ければ、偽リポジトリのライブをすべて自分のライブ一覧に入れておく
  final mine =
      myRepo ??
      FakeMyLiveRepository(
        ids: [
          for (final l in live.lives)
            if (l.id != null) l.id!,
        ],
      );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        oshiRepositoryProvider.overrideWithValue(
          oshiRepo ?? FakeOshiRepository(oshis),
        ),
        followRepositoryProvider.overrideWithValue(followRepo ?? following()),
        liveRepositoryProvider.overrideWithValue(live),
        myLiveRepositoryProvider.overrideWithValue(mine),
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
  return router;
}

/// [key] の中に [text] がある
Finder textIn(String key, String text) =>
    find.descendant(of: _key(key), matching: find.text(text), matchRoot: true);

void main() {
  group('ライブ一覧', () {
    testWidgets('読み込み中', (tester) async {
      await pumpAt(
        tester,
        '/lives',
        liveRepo: FakeLiveRepository()..emitInitial = false,
        settle: false,
      );
      await tester.pump();
      expect(_key('live_list_loading'), findsOneWidget);
    });

    testWidgets('0件: 右下の「ライブを追加する」からライブを追加する画面へ行ける', (tester) async {
      await pumpAt(tester, '/lives');
      expect(_key('live_list_empty'), findsOneWidget);
      expect(
        find.text('ライブ一覧はまだ空です。\n右下の「ライブを追加する」から、行くライブを追加しましょう'),
        findsOneWidget,
      );
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('ライブを追加する'), findsWidgets);
      await tester.tap(_key('live_list_register_fab'));
      await tester.pumpAndSettle();
      expect(find.text('route:/lives/add'), findsOneWidget);
    });

    testWidgets('フォローしているだけ（自分のライブ一覧が空）では、ライブが登録されていても出ない', (tester) async {
      await pumpAt(
        tester,
        '/lives',
        liveRepo: FakeLiveRepository(
          lives: const [
            Live(id: 'l1', title: 'A', groupIds: ['g1']),
          ],
        ),
        myRepo: FakeMyLiveRepository(),
      );
      expect(_key('live_list_empty'), findsOneWidget);
      expect(_key('live_list_tile_l1'), findsNothing);
    });

    testWidgets('フォロー0件でも 0件の表示で、右下に「ライブを追加する」を出す', (tester) async {
      await pumpAt(tester, '/lives', followRepo: FakeFollowRepository());
      expect(_key('live_list_empty'), findsOneWidget);
      expect(_key('live_list_register_fab'), findsOneWidget);
    });

    testWidgets('エラー → もう一度読み込む', (tester) async {
      final liveRepo = FakeLiveRepository(
        lives: [
          const Live(id: 'l1', title: 'A', groupIds: ['g1']),
        ],
        performances: [perfOf('p1', 'l1', h(24))],
      )..fail = true;
      await pumpAt(tester, '/lives', liveRepo: liveRepo);
      expect(_key('live_list_error'), findsOneWidget);
      expect(find.text('ライブを読み込めませんでした'), findsOneWidget);

      liveRepo.fail = false;
      await tester.tap(_key('live_list_retry_button'));
      await tester.pumpAndSettle();
      expect(_key('live_list_tile_l1'), findsOneWidget);
    });

    testWidgets('これから（近い順）→ 公演未登録 → 「終了」の見出しの下に終了したライブ', (tester) async {
      await pumpAt(
        tester,
        '/lives',
        liveRepo: FakeLiveRepository(
          lives: const [
            Live(id: 'ended', title: '終わったライブ', groupIds: ['g1']),
            Live(id: 'far', title: '先のライブ', groupIds: ['g1']),
            Live(id: 'none', title: '日程未定', oshiIds: ['p1']),
            Live(id: 'today', title: '今日のライブ', groupIds: ['g1']),
          ],
          performances: [
            perfOf('e1', 'ended', DateTime(2026, 11, 4, 18)),
            perfOf('f1', 'far', DateTime(2026, 12, 1, 18)),
            perfOf('f2', 'far', DateTime(2026, 12, 2, 18)),
            // 今日の 10:00 開演。いまは 12:00 だが、日単位なので「終了」にしない
            perfOf('t1', 'today', DateTime(2026, 11, 5, 10)),
          ],
        ),
      );
      double y(String id) => tester.getTopLeft(_key('live_list_tile_$id')).dy;
      final header = tester.getTopLeft(_key('live_list_finished_header')).dy;
      expect(y('today'), lessThan(y('far')));
      expect(y('far'), lessThan(y('none')));
      expect(y('none'), lessThan(header));
      expect(header, lessThan(y('ended')));

      expect(
        textIn('live_list_tile_far', 'グループ1\n次の公演 2026/12/1(火) 18:00（全2公演）'),
        findsOneWidget,
      );
      expect(textIn('live_list_tile_none', '個人1\n公演の日程は未登録です'), findsOneWidget);
      expect(
        textIn('live_list_tile_ended', 'グループ1\n終了（最終公演 2026/11/4(水) 18:00）'),
        findsOneWidget,
      );
    });

    testWidgets('終了したライブが無ければ「終了」の見出しを出さない', (tester) async {
      await pumpAt(
        tester,
        '/lives',
        liveRepo: FakeLiveRepository(
          lives: const [
            Live(id: 'l1', title: 'A', groupIds: ['g1']),
          ],
          performances: [perfOf('p1', 'l1', h(24))],
        ),
      );
      expect(_key('live_list_tile_l1'), findsOneWidget);
      expect(_key('live_list_finished_header'), findsNothing);
    });

    testWidgets('行を押すとライブ詳細へ', (tester) async {
      await pumpAt(
        tester,
        '/lives',
        liveRepo: FakeLiveRepository(
          lives: const [
            Live(id: 'l1', title: 'ライブA', groupIds: ['g1']),
          ],
          performances: [perfOf('p1', 'l1', h(24))],
        ),
      );
      await tester.tap(_key('live_list_tile_l1'));
      await tester.pumpAndSettle();
      expect(_key('live_detail_title'), findsOneWidget);
      expect(textIn('live_detail_title', 'ライブA'), findsOneWidget);
    });

    testWidgets('ライブが増えると一覧に出る（購読が続いている）', (tester) async {
      final liveRepo = FakeLiveRepository();
      final myRepo = FakeMyLiveRepository();
      await pumpAt(tester, '/lives', liveRepo: liveRepo, myRepo: myRepo);
      expect(_key('live_list_empty'), findsOneWidget);
      expect(_key('live_list_register_fab'), findsOneWidget);
      liveRepo
        ..setLives(const [
          Live(id: 'l1', title: 'A', groupIds: ['g1']),
        ])
        ..setPerformances([perfOf('p1', 'l1', h(24))]);
      await tester.pumpAndSettle();
      // ライブが登録されただけでは、自分のライブ一覧に入っていないので出ない
      expect(_key('live_list_tile_l1'), findsNothing);
      await myRepo.add('u1', 'l1');
      await tester.pumpAndSettle();
      expect(_key('live_list_tile_l1'), findsOneWidget);
      // Fa-3: 件数によらず「ライブを追加する」を出し続ける（1件以上でも消えない）
      expect(_key('live_list_register_fab'), findsOneWidget);
    });

    testWidgets('スマホの幅（360px）で、長い名前でもはみ出さない', (tester) async {
      usePhoneSize(tester);
      await pumpAt(
        tester,
        '/lives',
        liveRepo: FakeLiveRepository(
          lives: [
            Live(
              id: 'l1',
              title: 'ラ' * 100,
              groupIds: const ['g1', 'missing'],
              oshiIds: const ['p1'],
            ),
          ],
          performances: [perfOf('p1', 'l1', h(24)), perfOf('p2', 'l1', h(48))],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(_key('live_list_tile_l1'), findsOneWidget);
    });
  });

  group('ライブ詳細', () {
    const live = Live(
      id: 'l1',
      title: 'ツアー2026',
      groupIds: ['g1'],
      oshiIds: ['p1'],
      officialUrl: 'https://example.com/tour',
    );

    FakeLiveRepository detailRepo({List<Reception>? receptions}) =>
        FakeLiveRepository(
          lives: const [live],
          performances: [
            perfOf('past', 'l1', DateTime(2026, 11, 4, 23, 59)),
            perfOf('todayBefore', 'l1', DateTime(2026, 11, 5, 18)),
            perfOf('todayAfter', 'l1', DateTime(2026, 11, 5, 10)),
            perfOf('future', 'l1', DateTime(2026, 11, 6)),
          ],
          receptions:
              receptions ??
              [
                recOf(
                  'r1',
                  'l1',
                  name: 'FC先行',
                  applyEndAt: h(48),
                  resultAt: DateTime(2026, 11, 20, 18),
                  paymentDeadline: h(5),
                ),
              ],
        );

    /// 詳細は ListView（遅延で作る）なので、見えるまでスクロールしてから使う
    Future<void> scrollTo(WidgetTester tester, Finder f) async {
      if (f.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          f,
          200,
          scrollable: find
              .descendant(
                of: _key('live_detail'),
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
    }

    /// 申込状況を選ぶ（未申込は null）
    Future<void> choose(
      WidgetTester tester,
      String receptionId,
      String label,
    ) async {
      final dropdown = _key('live_detail_status_$receptionId');
      await scrollTo(tester, dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pump();
    }

    testWidgets('読み込み中', (tester) async {
      await pumpAt(
        tester,
        '/lives/l1',
        liveRepo: FakeLiveRepository()..emitInitial = false,
        settle: false,
      );
      await tester.pump();
      expect(_key('live_detail_loading'), findsOneWidget);
    });

    testWidgets('見つからない', (tester) async {
      await pumpAt(tester, '/lives/none', liveRepo: detailRepo());
      expect(_key('live_detail_not_found'), findsOneWidget);
      expect(find.text('このライブは見つかりませんでした'), findsOneWidget);
    });

    testWidgets('エラー → もう一度読み込む', (tester) async {
      final repo = detailRepo()..fail = true;
      await pumpAt(tester, '/lives/l1', liveRepo: repo);
      expect(_key('live_detail_error'), findsOneWidget);
      repo.fail = false;
      await tester.tap(_key('live_detail_retry_button'));
      await tester.pumpAndSettle();
      expect(_key('live_detail_title'), findsOneWidget);
    });

    testWidgets('申込状況の読み込みエラーもエラー表示', (tester) async {
      await pumpAt(
        tester,
        '/lives/l1',
        liveRepo: detailRepo(),
        appRepo: FakeApplicationRepository()..fail = true,
      );
      expect(_key('live_detail_error'), findsOneWidget);
    });

    testWidgets('ライブ名・出演者・公式 URL', (tester) async {
      await pumpAt(tester, '/lives/l1', liveRepo: detailRepo());
      expect(textIn('live_detail_title', 'ツアー2026'), findsOneWidget);
      expect(textIn('live_detail_performers', 'グループ1、個人1'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('live_detail_official_url'),
          matching: find.text('https://example.com/tour'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('公演: 開演順、日単位のラベル（前日まで「（終了）」・当日「（本日）」・以降なし）', (tester) async {
      await pumpAt(tester, '/lives/l1', liveRepo: detailRepo());
      expect(
        textIn('live_detail_performance_past', '2026/11/4(水) 23:59 開演（終了）'),
        findsOneWidget,
      );
      // 当日は開演の前も後も「本日」
      expect(
        textIn(
          'live_detail_performance_todayAfter',
          '2026/11/5(木) 10:00 開演（本日）',
        ),
        findsOneWidget,
      );
      expect(
        textIn(
          'live_detail_performance_todayBefore',
          '2026/11/5(木) 18:00 開演（本日）',
        ),
        findsOneWidget,
      );
      // 翌日 0:00 はラベルなし
      expect(
        textIn('live_detail_performance_future', '2026/11/6(金) 0:00 開演'),
        findsNothing,
      );
      expect(
        textIn('live_detail_performance_future', '2026/11/6(金) 00:00 開演'),
        findsOneWidget,
      );

      double y(String id) =>
          tester.getTopLeft(_key('live_detail_performance_$id')).dy;
      expect(y('past'), lessThan(y('todayAfter')));
      expect(y('todayAfter'), lessThan(y('todayBefore')));
      expect(y('todayBefore'), lessThan(y('future')));
    });

    testWidgets('公演・受付が0件', (tester) async {
      await pumpAt(
        tester,
        '/lives/l1',
        liveRepo: FakeLiveRepository(lives: const [live]),
      );
      expect(_key('live_detail_performances_empty'), findsOneWidget);
      expect(_key('live_detail_receptions_empty'), findsOneWidget);
    });

    testWidgets('受付: 種別・料金・当選者のみのラベル（当選者には見える）', (tester) async {
      await pumpAt(
        tester,
        '/lives/l1',
        appRepo: FakeApplicationRepository({
          'won1': const Application(
            receptionId: 'won1',
            liveId: 'l1',
            status: ApplicationStatus.won,
          ),
        }),
        liveRepo: detailRepo(
          receptions: [
            recOf('r1', 'l1', name: 'FC先行', applyEndAt: h(48)),
            Reception(
              id: 'up',
              liveId: 'l1',
              type: ReceptionType.upgrade,
              name: 'アプグレ',
              applyEndAt: h(72),
              prices: const [Price(seat: 'S席', amount: 1000000)],
              winnersOnly: true,
            ),
          ],
        ),
      );
      final up = _key('live_detail_reception_up');
      await scrollTo(tester, up);
      expect(_key('live_detail_winners_only_up'), findsOneWidget);
      expect(_key('live_detail_winners_only_r1'), findsNothing);
      expect(
        find.descendant(of: up, matching: find.text('1,000,000円')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: up, matching: find.text('入金期限')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: up, matching: find.text('未発表')),
        findsOneWidget,
      );
    });

    testWidgets('当選者でなければ、当選者のみの受付を出さず、件数を知らせる。当選すると出る', (tester) async {
      final appRepo = FakeApplicationRepository();
      await pumpAt(
        tester,
        '/lives/l1',
        appRepo: appRepo,
        liveRepo: detailRepo(
          receptions: [
            recOf('r1', 'l1', name: 'FC先行', applyEndAt: h(48)),
            recOf('up', 'l1', applyEndAt: h(72), winnersOnly: true),
          ],
        ),
      );
      await scrollTo(tester, _key('live_detail_hidden_receptions'));
      expect(_key('live_detail_reception_r1'), findsOneWidget);
      expect(_key('live_detail_reception_up'), findsNothing);
      expect(find.text('当選すると表示される受付が1件あります'), findsOneWidget);

      await appRepo.setStatus(
        'u1',
        recOf('r1', 'l1', applyEndAt: h(48)),
        ApplicationStatus.won,
      );
      await tester.pumpAndSettle();
      expect(_key('live_detail_hidden_receptions'), findsNothing);
      await scrollTo(tester, _key('live_detail_reception_up'));
      expect(_key('live_detail_reception_up'), findsOneWidget);
    });

    testWidgets('受付が当選者のみだけなら、「受付なし」ではなく隠した件数を出す', (tester) async {
      await pumpAt(
        tester,
        '/lives/l1',
        liveRepo: detailRepo(
          receptions: [recOf('up', 'l1', applyEndAt: h(72), winnersOnly: true)],
        ),
      );
      await scrollTo(tester, _key('live_detail_hidden_receptions'));
      expect(_key('live_detail_receptions_empty'), findsNothing);
    });

    testWidgets('申込状況を変えると、保存し、次にやることが切り替わる（未申込→申込済→当選→入金済→未申込）', (
      tester,
    ) async {
      final appRepo = FakeApplicationRepository();
      await pumpAt(
        tester,
        '/lives/l1',
        liveRepo: detailRepo(),
        appRepo: appRepo,
      );
      Finder next(String text) => textIn('live_detail_next_action_r1', text);
      await scrollTo(tester, _key('live_detail_next_action_r1'));
      expect(next('申込期限まであと2日'), findsOneWidget);

      await choose(tester, 'r1', '申込済');
      await tester.pumpAndSettle();
      expect(appRepo.calls.last, ('r1', ApplicationStatus.applied));
      expect(next('当落発表 2026/11/20(金) 18:00'), findsOneWidget);

      await choose(tester, 'r1', '当選');
      await tester.pumpAndSettle();
      expect(next('入金期限まであと5時間'), findsOneWidget);

      await choose(tester, 'r1', '入金済');
      await tester.pumpAndSettle();
      expect(next('入金済みです。やることはありません'), findsOneWidget);

      await choose(tester, 'r1', '未申込');
      await tester.pumpAndSettle();
      expect(appRepo.calls.last, ('r1', null));
      expect(appRepo.current, isEmpty);
      expect(next('申込期限まであと2日'), findsOneWidget);
    });

    testWidgets('残り時間は、いまの「次にやること」の期限の行にだけ出す', (tester) async {
      final appRepo = FakeApplicationRepository();
      await pumpAt(
        tester,
        '/lives/l1',
        liveRepo: detailRepo(),
        appRepo: appRepo,
      );
      final card = _key('live_detail_reception_r1');
      Finder inCard(String t) =>
          find.descendant(of: card, matching: find.textContaining(t));
      await scrollTo(tester, card);
      // 未申込: 申込期限の行に「あと2日」、入金期限の行には残り時間なし
      expect(inCard('あと2日'), findsWidgets);
      expect(inCard('あと5時間'), findsNothing);

      await choose(tester, 'r1', '当選');
      await tester.pumpAndSettle();
      expect(inCard('あと2日'), findsNothing);
      expect(inCard('あと5時間'), findsWidgets);
    });

    testWidgets('変更中は選べず進捗を出す。同じ値を選んでも保存しない', (tester) async {
      final appRepo = FakeApplicationRepository()..gate = Completer<void>();
      await pumpAt(
        tester,
        '/lives/l1',
        liveRepo: detailRepo(),
        appRepo: appRepo,
      );

      await choose(tester, 'r1', '申込済');
      expect(appRepo.calls, hasLength(1));
      expect(_key('live_detail_status_busy_r1'), findsOneWidget);
      final dropdown = tester.widget<DropdownButton<ApplicationStatus?>>(
        _key('live_detail_status_r1'),
      );
      expect(dropdown.onChanged, isNull);

      appRepo.gate!.complete();
      appRepo.gate = null;
      await tester.pumpAndSettle();
      expect(_key('live_detail_status_busy_r1'), findsNothing);

      // 今と同じ「申込済」を選び直しても保存しない
      await choose(tester, 'r1', '申込済');
      await tester.pumpAndSettle();
      expect(appRepo.calls, hasLength(1));
    });

    testWidgets('保存に失敗したら日本語の SnackBar、状態は元のまま', (tester) async {
      final appRepo = FakeApplicationRepository()..error = permissionDenied();
      await pumpAt(
        tester,
        '/lives/l1',
        liveRepo: detailRepo(),
        appRepo: appRepo,
      );
      await choose(tester, 'r1', '当選');
      await tester.pumpAndSettle();
      expect(find.text('申込状況を変更できませんでした。もう一度お試しください'), findsOneWidget);
      expect(
        textIn('live_detail_next_action_r1', '申込期限まであと2日'),
        findsOneWidget,
      );
      final dropdown = tester.widget<DropdownButton<ApplicationStatus?>>(
        _key('live_detail_status_r1'),
      );
      expect(dropdown.value, isNull);
      expect(dropdown.onChanged, isNotNull);
    });

    testWidgets('期限切れ: 「申込期限を過ぎました」', (tester) async {
      await pumpAt(
        tester,
        '/lives/l1',
        liveRepo: detailRepo(
          receptions: [recOf('r1', 'l1', applyEndAt: h(-1))],
        ),
      );
      await scrollTo(tester, _key('live_detail_next_action_r1'));
      expect(
        textIn('live_detail_next_action_r1', '申込期限を過ぎました'),
        findsOneWidget,
      );
    });

    testWidgets('画面を離れると、ライブ詳細の購読をやめる（autoDispose）', (tester) async {
      final repo = detailRepo();
      final router = await pumpAt(tester, '/lives', liveRepo: repo);
      router.push('/lives/l1');
      await tester.pumpAndSettle();
      expect(_key('live_detail_title'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LiveDetailPage)),
      );
      expect(container.exists(liveProvider('l1')), isTrue);

      router.pop();
      await tester.pumpAndSettle();
      expect(container.exists(liveProvider('l1')), isFalse);
      expect(container.exists(receptionsOfLiveProvider('l1')), isFalse);
      expect(container.exists(performancesOfLiveProvider('l1')), isFalse);
    });

    testWidgets('スマホの幅（360px）で、長い名前でもはみ出さない', (tester) async {
      usePhoneSize(tester);
      await pumpAt(
        tester,
        '/lives/l1',
        appRepo: FakeApplicationRepository({
          'won1': const Application(
            receptionId: 'won1',
            liveId: 'l1',
            status: ApplicationStatus.won,
          ),
        }),
        liveRepo: FakeLiveRepository(
          lives: [
            Live(
              id: 'l1',
              title: 'ラ' * 100,
              groupIds: const ['g1'],
              officialUrl: 'https://example.com/${'a' * 180}',
            ),
          ],
          performances: [perfOf('p1', 'l1', h(24))],
          receptions: [
            Reception(
              id: 'r1',
              liveId: 'l1',
              type: ReceptionType.upgrade,
              name: '受' * 50,
              applyStartAt: h(1),
              applyEndAt: h(5),
              prices: [
                for (var i = 0; i < 10; i++)
                  Price(seat: '席' * 50, amount: 1000000),
              ],
              winnersOnly: true,
            ),
          ],
        ),
      );
      await scrollTo(tester, _key('live_detail_status_r1'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('自分のライブ一覧に入っていなければ「追加」。申込状況の代わりにヒントを出す', (tester) async {
      final my = FakeMyLiveRepository();
      await pumpAt(tester, '/lives/l1', liveRepo: detailRepo(), myRepo: my);
      expect(_key('live_detail_remove_mine_button'), findsNothing);
      await tester.scrollUntilVisible(
        _key('live_detail_add_hint_r1'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('ライブ一覧に追加すると、申込状況を記録できます'), findsOneWidget);
      expect(_key('live_detail_status_r1'), findsNothing);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tester.tap(_key('live_detail_add_mine_button'));
      await tester.pumpAndSettle();
      expect(my.ids, {'l1'});
      expect(_key('live_detail_remove_mine_button'), findsOneWidget);
      expect(_key('live_detail_add_hint_r1'), findsNothing);
    });

    testWidgets('「ライブ一覧から外す」は確認ダイアログを出す。やめるなら外さない', (tester) async {
      final my = FakeMyLiveRepository(ids: ['l1']);
      await pumpAt(tester, '/lives/l1', liveRepo: detailRepo(), myRepo: my);
      expect(_key('live_detail_add_mine_button'), findsNothing);

      await tester.tap(_key('live_detail_remove_mine_button'));
      await tester.pumpAndSettle();
      expect(find.text('ライブ一覧から外しますか？'), findsOneWidget);
      await tester.tap(_key('live_detail_remove_cancel'));
      await tester.pumpAndSettle();
      expect(my.ids, {'l1'});
      expect(my.removed, isEmpty);

      await tester.tap(_key('live_detail_remove_mine_button'));
      await tester.pumpAndSettle();
      await tester.tap(_key('live_detail_remove_confirm'));
      await tester.pumpAndSettle();
      expect(my.ids, isEmpty);
      expect(_key('live_detail_add_mine_button'), findsOneWidget);
    });

    testWidgets('一覧の更新に失敗したら日本語の SnackBar', (tester) async {
      final my = FakeMyLiveRepository()..writeError = Exception('失敗');
      await pumpAt(tester, '/lives/l1', liveRepo: detailRepo(), myRepo: my);
      await tester.tap(_key('live_detail_add_mine_button'));
      await tester.pumpAndSettle();
      expect(find.text('ライブ一覧を更新できませんでした。もう一度お試しください'), findsOneWidget);
      expect(_key('live_detail_add_mine_button'), findsOneWidget);
    });

    testWidgets('自分のライブ一覧の読み込み中は、ボタンも申込状況も出さない', (tester) async {
      await pumpAt(
        tester,
        '/lives/l1',
        liveRepo: detailRepo(),
        myRepo: FakeMyLiveRepository()..emitInitial = false,
        settle: false,
      );
      await tester.pump();
      await tester.pump();
      expect(_key('live_detail_add_mine_button'), findsNothing);
      expect(_key('live_detail_remove_mine_button'), findsNothing);
      expect(_key('live_detail_status_r1'), findsNothing);
    });
  });
}
