// lib/providers/live_providers.dart（D6）のテスト。リポジトリは偽物に差し替え、
// フォロー中の推し（followingOshisProvider）は外から切り替えられるようにする。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/application.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/models/reception.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/repositories/live_repository.dart';
import 'package:oshiashi/utils/deadline.dart';

import '../features/live_test_helpers.dart';
import '../features/oshi_test_helpers.dart';

final now = DateTime(2026, 11, 5, 12);
DateTime h(int hours) => now.add(Duration(hours: hours));

final g1 = oshi('g1', 'グループ1');
const p1 = OshiSummary(
  id: 'p1',
  kind: OshiKind.person,
  name: '個人1',
  genre: OshiGenre.idol,
  status: OshiStatus.approved,
  groupIds: ['g2'],
);

class _Env {
  _Env({
    String? uid = 'u1',
    AsyncValue<List<OshiSummary>>? following,
    FakeLiveRepository? liveRepo,
    FakeApplicationRepository? appRepo,
    FakeMyLiveRepository? myRepo,
  }) : liveRepo = liveRepo ?? FakeLiveRepository(),
       appRepo = appRepo ?? FakeApplicationRepository() {
    // 指定が無ければ、偽リポジトリのライブをすべて自分のライブ一覧に入れておく
    this.myRepo =
        myRepo ??
        FakeMyLiveRepository(
          ids: [
            for (final l in this.liveRepo.lives)
              if (l.id != null) l.id!,
          ],
        );
    followingState = StateProvider<AsyncValue<List<OshiSummary>>>(
      (ref) => following ?? AsyncData([g1, p1]),
    );
    container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue(uid),
        followingOshisProvider.overrideWith((ref) => ref.watch(followingState)),
        liveRepositoryProvider.overrideWithValue(this.liveRepo),
        applicationRepositoryProvider.overrideWithValue(this.appRepo),
        myLiveRepositoryProvider.overrideWithValue(this.myRepo),
        nowProvider.overrideWithValue(now),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
  }

  final FakeLiveRepository liveRepo;
  final FakeApplicationRepository appRepo;
  late final FakeMyLiveRepository myRepo;
  late final StateProvider<AsyncValue<List<OshiSummary>>> followingState;
  late final ProviderContainer container;

  /// 購読者がいないプロバイダは止まるので、先に listen してから読む
  T read<T>(ProviderListenable<T> p) {
    container.listen(p, (_, _) {});
    return container.read(p);
  }

  void setFollowing(AsyncValue<List<OshiSummary>> v) =>
      container.read(followingState.notifier).state = v;
}

Future<void> settle() => pumpEventQueue();

void main() {
  group('liveListProvider', () {
    test('ライブと公演から buildLiveList で並べる', () async {
      final env = _Env(
        liveRepo: FakeLiveRepository(
          lives: const [
            Live(id: 'far', title: 'B', groupIds: ['g1']),
            Live(id: 'near', title: 'A', groupIds: ['g1']),
          ],
          performances: [
            perfOf('pf', 'far', h(48)),
            perfOf('pn', 'near', h(1)),
          ],
        ),
      );
      env.read(liveListProvider);
      await settle();
      final list = env.container.read(liveListProvider).requireValue;
      expect([for (final e in list) e.live.id], ['near', 'far']);
    });

    test('ライブか公演がエラーならエラー、読み込み中なら読み込み中', () async {
      final err = _Env(liveRepo: FakeLiveRepository()..fail = true);
      err.read(liveListProvider);
      await settle();
      expect(err.container.read(liveListProvider).hasError, isTrue);

      final loading = _Env(liveRepo: FakeLiveRepository()..emitInitial = false);
      loading.read(liveListProvider);
      await settle();
      expect(loading.container.read(liveListProvider).isLoading, isTrue);
    });
  });

  group('upcomingDeadlinesProvider', () {
    test('近い順・期限切れを除く・ライブが見つからない受付を除く', () async {
      final env = _Env(
        liveRepo: FakeLiveRepository(
          lives: const [
            Live(id: 'l1', title: 'A', groupIds: ['g1']),
          ],
          receptions: [
            recOf('late', 'l1', applyEndAt: h(48)),
            recOf('soon', 'l1', applyEndAt: h(1)),
            recOf('expired', 'l1', applyEndAt: h(-1)),
            recOf('orphan', 'missing', applyEndAt: h(2)),
          ],
        ),
      );
      env.read(upcomingDeadlinesProvider);
      await settle();
      final list = env.container.read(upcomingDeadlinesProvider).requireValue;
      expect([for (final e in list) e.deadline.reception.id], ['soon', 'late']);
      expect(list.first.live.id, 'l1');
    });

    test('ID が null のライブと、liveId が null の受付を結び付けない', () async {
      final env = _Env(
        liveRepo: FakeLiveRepository(
          lives: const [
            Live(title: 'ID なし', groupIds: ['g1']),
          ],
          receptions: [
            Reception(
              id: 'r',
              type: ReceptionType.fc,
              name: 'FC',
              applyEndAt: h(1),
            ),
          ],
        ),
      );
      env.read(upcomingDeadlinesProvider);
      await settle();
      expect(
        env.container.read(upcomingDeadlinesProvider).requireValue,
        isEmpty,
      );
    });

    test('申込状況で次の締切が切り替わる', () async {
      final appRepo = FakeApplicationRepository();
      final r = recOf(
        'r1',
        'l1',
        applyEndAt: h(1),
        resultAt: h(10),
        paymentDeadline: h(20),
      );
      final env = _Env(
        liveRepo: FakeLiveRepository(
          lives: const [
            Live(id: 'l1', title: 'A', groupIds: ['g1']),
          ],
          receptions: [r],
        ),
        appRepo: appRepo,
      );
      env.read(upcomingDeadlinesProvider);
      await settle();
      DeadlineKind? kind() => env.container
          .read(upcomingDeadlinesProvider)
          .requireValue
          .firstOrNull
          ?.deadline
          .kind;
      expect(kind(), DeadlineKind.apply);
      await appRepo.setStatus('u1', r, ApplicationStatus.applied);
      await settle();
      expect(kind(), DeadlineKind.result);
      await appRepo.setStatus('u1', r, ApplicationStatus.won);
      await settle();
      expect(kind(), DeadlineKind.payment);
      await appRepo.setStatus('u1', r, ApplicationStatus.paid);
      await settle();
      expect(kind(), isNull);
    });

    test('受付・申込状況・ライブのどれかがエラーならエラー', () async {
      final appErr = _Env(
        liveRepo: FakeLiveRepository(
          lives: const [
            Live(id: 'l1', title: 'A', groupIds: ['g1']),
          ],
        ),
        appRepo: FakeApplicationRepository()..fail = true,
      );
      appErr.read(upcomingDeadlinesProvider);
      await settle();
      expect(appErr.container.read(upcomingDeadlinesProvider).hasError, isTrue);

      final liveErr = _Env(liveRepo: FakeLiveRepository()..fail = true);
      liveErr.read(upcomingDeadlinesProvider);
      await settle();
      expect(
        liveErr.container.read(upcomingDeadlinesProvider).hasError,
        isTrue,
      );
    });

    test('読み込み中なら読み込み中', () async {
      final env = _Env(liveRepo: FakeLiveRepository()..emitInitial = false);
      env.read(upcomingDeadlinesProvider);
      await settle();
      expect(env.container.read(upcomingDeadlinesProvider).isLoading, isTrue);
    });
  });

  group('自分のライブ一覧（myLives）', () {
    FakeLiveRepository repoWith() => FakeLiveRepository(
      lives: const [
        Live(id: 'a', title: 'A', groupIds: ['g1']),
        Live(id: 'b', title: 'B', groupIds: ['g1']),
      ],
      performances: [perfOf('pa', 'a', h(5)), perfOf('pb', 'b', h(6))],
      receptions: [
        recOf('ra', 'a', applyEndAt: h(2)),
        recOf('rb', 'b', applyEndAt: h(3)),
      ],
    );

    List<String?> listIds(_Env env) => [
      for (final e in env.container.read(liveListProvider).requireValue)
        e.live.id,
    ];
    List<String?> deadlineIds(_Env env) => [
      for (final e
          in env.container.read(upcomingDeadlinesProvider).requireValue)
        e.deadline.reception.id,
    ];

    test('フォローしただけ（myLives が空）では、一覧にも次の締切にも出ない。問い合わせもしない', () async {
      final env = _Env(liveRepo: repoWith(), myRepo: FakeMyLiveRepository());
      env.read(liveListProvider);
      env.read(upcomingDeadlinesProvider);
      await settle();
      expect(listIds(env), isEmpty);
      expect(deadlineIds(env), isEmpty);
      // 空の ID でもリポジトリへ渡す（空なら問い合わせず [] を返す契約）。渡す ID は空だけ
      expect(env.liveRepo.idsSeen.every((s) => s.isEmpty), isTrue);
    });

    test('追加したライブだけが出る。追加すると増え、外すと消える', () async {
      final my = FakeMyLiveRepository(ids: ['a']);
      final env = _Env(liveRepo: repoWith(), myRepo: my);
      env.read(liveListProvider);
      env.read(upcomingDeadlinesProvider);
      await settle();
      expect(listIds(env), ['a']);
      expect(deadlineIds(env), ['ra']);

      await my.add('u1', 'b');
      await settle();
      expect(listIds(env), ['a', 'b']);
      expect(deadlineIds(env), ['ra', 'rb']);

      await my.remove('u1', 'a');
      await settle();
      expect(listIds(env), ['b']);
      expect(deadlineIds(env), ['rb']);
    });

    test('ID の集合が変われば、新しい集合で購読し直す', () async {
      final my = FakeMyLiveRepository(ids: ['a']);
      final env = _Env(liveRepo: repoWith(), myRepo: my);
      env.read(myLivesProvider);
      await settle();
      expect(env.liveRepo.idsSeen.last, {'a'});
      await my.add('u1', 'b');
      await settle();
      expect(env.liveRepo.idsSeen.last, {'a', 'b'});
    });

    test('myLives に ID があっても、ライブが無ければ出ない', () async {
      final env = _Env(
        liveRepo: repoWith(),
        myRepo: FakeMyLiveRepository(ids: ['gone']),
      );
      env.read(liveListProvider);
      await settle();
      expect(listIds(env), isEmpty);
    });

    test('未ログインなら空で、リポジトリを呼ばない', () async {
      final env = _Env(uid: null, liveRepo: repoWith());
      env.read(myLivesProvider);
      env.read(myPerformancesProvider);
      env.read(myReceptionsProvider);
      await settle();
      expect(env.container.read(myLivesProvider).requireValue, isEmpty);
      expect(env.container.read(myPerformancesProvider).requireValue, isEmpty);
      expect(env.container.read(myReceptionsProvider).requireValue, isEmpty);
      expect(env.liveRepo.idsSeen, isEmpty);
    });

    test('myLives の読み込み中は読み込み中、エラーはエラー（ライブは購読しない）', () async {
      final loading = _Env(
        liveRepo: repoWith(),
        myRepo: FakeMyLiveRepository()..emitInitial = false,
      );
      loading.read(liveListProvider);
      await settle();
      expect(loading.container.read(liveListProvider).isLoading, isTrue);
      expect(loading.liveRepo.idsSeen, isEmpty);

      final err = _Env(
        liveRepo: repoWith(),
        myRepo: FakeMyLiveRepository()..fail = true,
      );
      err.read(liveListProvider);
      err.read(upcomingDeadlinesProvider);
      await settle();
      expect(err.container.read(liveListProvider).hasError, isTrue);
      expect(err.container.read(upcomingDeadlinesProvider).hasError, isTrue);
    });

    test('isInMyLivesProvider: 入っていれば true、無ければ false、読み込み中は読み込み中', () async {
      final env = _Env(
        liveRepo: repoWith(),
        myRepo: FakeMyLiveRepository(ids: ['a']),
      );
      env.read(isInMyLivesProvider('a'));
      await settle();
      expect(env.container.read(isInMyLivesProvider('a')).requireValue, isTrue);
      expect(
        env.container.read(isInMyLivesProvider('b')).requireValue,
        isFalse,
      );

      final loading = _Env(myRepo: FakeMyLiveRepository()..emitInitial = false);
      loading.read(isInMyLivesProvider('a'));
      await settle();
      expect(
        loading.container.read(isInMyLivesProvider('a')).isLoading,
        isTrue,
      );
    });
  });

  group('liveSearchProvider', () {
    const targets = FollowTargets(groupIds: {'g1'});
    FakeLiveRepository repo() => FakeLiveRepository(
      lives: const [
        Live(id: 'a', title: 'ＬＩＶＥ ツアー', groupIds: ['g1']),
        Live(id: 'b', title: 'フェス', groupIds: ['g1']),
      ],
      performances: [perfOf('pa', 'a', h(5)), perfOf('pb', 'b', h(2))],
    );

    List<String?> ids(_Env env, String q) => [
      for (final e
          in env.container
              .read(liveSearchProvider((targets: targets, query: q)))
              .requireValue)
        e.live.id,
    ];

    test('入力で絞り込み、空なら全件。myLives に入っていなくても出る', () async {
      final env = _Env(liveRepo: repo(), myRepo: FakeMyLiveRepository());
      env.read(liveSearchProvider((targets: targets, query: '')));
      env.read(liveSearchProvider((targets: targets, query: 'live')));
      await settle();
      expect(ids(env, ''), ['b', 'a']);
      expect(ids(env, 'live'), ['a']);
      expect(env.liveRepo.targetsSeen, isNotEmpty);
    });

    test('リポジトリのエラーはエラー', () async {
      final env = _Env(liveRepo: repo()..fail = true);
      env.read(liveSearchProvider((targets: targets, query: '')));
      await settle();
      expect(
        env.container
            .read(liveSearchProvider((targets: targets, query: '')))
            .hasError,
        isTrue,
      );
    });
  });

  group('ライブ詳細のプロバイダ', () {
    test(
      'liveProvider・performancesOfLiveProvider・receptionsOfLiveProvider',
      () async {
        final env = _Env(
          liveRepo: FakeLiveRepository(
            lives: const [
              Live(id: 'l1', title: 'A', groupIds: ['g1']),
            ],
            performances: [perfOf('p2', 'l1', h(2)), perfOf('p1', 'l1', h(1))],
            receptions: [recOf('r1', 'l1', applyEndAt: h(1))],
          ),
        );
        env
          ..read(liveProvider('l1'))
          ..read(liveProvider('none'))
          ..read(performancesOfLiveProvider('l1'))
          ..read(receptionsOfLiveProvider('l1'));
        await settle();
        final c = env.container;
        expect(c.read(liveProvider('l1')).requireValue!.title, 'A');
        expect(c.read(liveProvider('none')).requireValue, isNull);
        expect(
          [
            for (final p
                in c.read(performancesOfLiveProvider('l1')).requireValue)
              p.id,
          ],
          ['p1', 'p2'],
        );
        expect(
          c.read(receptionsOfLiveProvider('l1')).requireValue,
          hasLength(1),
        );
      },
    );
  });

  group('当選者のみの受付（winnersOnly）', () {
    final fcR = recOf('fc', 'l1', applyEndAt: h(48));
    Reception upg() => Reception(
      id: 'up',
      liveId: 'l1',
      type: ReceptionType.upgrade,
      name: 'アプグレ',
      applyEndAt: h(24),
      winnersOnly: true,
    );
    _Env env0(FakeApplicationRepository appRepo) => _Env(
      liveRepo: FakeLiveRepository(
        lives: const [
          Live(id: 'l1', title: 'A', groupIds: ['g1']),
        ],
        receptions: [
          recOf('fc', 'l1', applyEndAt: h(48)),
          upg(),
        ],
      ),
      appRepo: appRepo,
    );
    Application app(ApplicationStatus s) =>
        Application(receptionId: 'fc', liveId: 'l1', status: s);

    test('winnerLiveIdsProvider: won・paid のライブだけ', () async {
      final env = env0(
        FakeApplicationRepository({'fc': app(ApplicationStatus.applied)}),
      );
      env.read(winnerLiveIdsProvider);
      await settle();
      expect(env.container.read(winnerLiveIdsProvider).requireValue, isEmpty);
      await env.appRepo.setStatus('u1', fcR, ApplicationStatus.won);
      await settle();
      expect(env.container.read(winnerLiveIdsProvider).requireValue, {'l1'});
    });

    test('winnerLiveIdsProvider: 読み込み中・エラーはそのまま伝える', () async {
      final err = env0(FakeApplicationRepository()..fail = true);
      err.read(winnerLiveIdsProvider);
      await settle();
      expect(err.container.read(winnerLiveIdsProvider).hasError, isTrue);
    });

    test('次の締切: 当選するまで出ず、当選すると出る。落選すると消える', () async {
      final appRepo = FakeApplicationRepository();
      final env = env0(appRepo);
      env.read(upcomingDeadlinesProvider);
      await settle();
      List<String?> ids() => [
        for (final e
            in env.container.read(upcomingDeadlinesProvider).requireValue)
          e.deadline.reception.id,
      ];
      expect(ids(), ['fc']);
      await appRepo.setStatus('u1', fcR, ApplicationStatus.won);
      await settle();
      expect(ids(), contains('up'));
      await appRepo.setStatus('u1', fcR, ApplicationStatus.lost);
      await settle();
      expect(ids(), isNot(contains('up')));
    });

    test('visibleReceptionsOfLiveProvider: 見せる受付と隠した件数', () async {
      final appRepo = FakeApplicationRepository();
      final env = env0(appRepo);
      env.read(visibleReceptionsOfLiveProvider('l1'));
      await settle();
      var v = env.container
          .read(visibleReceptionsOfLiveProvider('l1'))
          .requireValue;
      expect([for (final r in v.visible) r.id], ['fc']);
      expect(v.hiddenCount, 1);
      await appRepo.setStatus('u1', fcR, ApplicationStatus.paid);
      await settle();
      v = env.container
          .read(visibleReceptionsOfLiveProvider('l1'))
          .requireValue;
      expect(v.visible.length, 2);
      expect(v.hiddenCount, 0);
    });

    test('visibleReceptionsOfLiveProvider: 申込状況のエラーはエラー', () async {
      final env = env0(FakeApplicationRepository()..fail = true);
      env.read(visibleReceptionsOfLiveProvider('l1'));
      await settle();
      expect(
        env.container.read(visibleReceptionsOfLiveProvider('l1')).hasError,
        isTrue,
      );
    });
  });
}
