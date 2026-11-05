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
  }) : liveRepo = liveRepo ?? FakeLiveRepository(),
       appRepo = appRepo ?? FakeApplicationRepository() {
    followingState = StateProvider<AsyncValue<List<OshiSummary>>>(
      (ref) => following ?? AsyncData([g1, p1]),
    );
    container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue(uid),
        followingOshisProvider.overrideWith((ref) => ref.watch(followingState)),
        liveRepositoryProvider.overrideWithValue(this.liveRepo),
        applicationRepositoryProvider.overrideWithValue(this.appRepo),
        nowProvider.overrideWithValue(now),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
  }

  final FakeLiveRepository liveRepo;
  final FakeApplicationRepository appRepo;
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
  group('followTargetsProvider', () {
    test('フォロー中のグループ・推し・推しの所属グループから作る', () {
      final env = _Env();
      expect(
        env.read(followTargetsProvider).requireValue,
        const FollowTargets(groupIds: {'g1', 'g2'}, oshiIds: {'p1'}),
      );
    });

    test('読み込み中・エラーをそのまま伝える', () {
      final loading = _Env(following: const AsyncLoading());
      expect(loading.read(followTargetsProvider), isA<AsyncLoading<Object?>>());
      final error = _Env(
        following: AsyncError(permissionDenied(), StackTrace.empty),
      );
      expect(error.read(followTargetsProvider).hasError, isTrue);
    });
  });

  group('livesProvider など', () {
    test('未ログインなら [] で、リポジトリを呼ばない', () async {
      final env = _Env(uid: null);
      env.read(livesProvider);
      env.read(performancesProvider);
      env.read(receptionsProvider);
      env.read(applicationsProvider);
      await settle();
      expect(env.container.read(livesProvider).requireValue, isEmpty);
      expect(env.container.read(performancesProvider).requireValue, isEmpty);
      expect(env.container.read(receptionsProvider).requireValue, isEmpty);
      expect(env.container.read(applicationsProvider).requireValue, isEmpty);
      expect(env.liveRepo.targetsSeen, isEmpty);
    });

    test('フォロー0件なら、空の対象でリポジトリを呼ぶ（リポジトリは問い合わせずに [] を返す契約）', () async {
      final env = _Env(following: const AsyncData([]));
      env.read(livesProvider);
      await settle();
      expect(env.liveRepo.targetsSeen, [FollowTargets.empty]);
    });

    test('フォローの読み込み中は読み込み中のまま、リポジトリを呼ばない', () async {
      final env = _Env(following: const AsyncLoading());
      env.read(livesProvider);
      await settle();
      expect(env.container.read(livesProvider).isLoading, isTrue);
      expect(env.liveRepo.targetsSeen, isEmpty);
    });

    test('フォローのエラーは、そのままエラーとして流す', () async {
      final env = _Env(
        following: AsyncError(permissionDenied(), StackTrace.empty),
      );
      env.read(livesProvider);
      await settle();
      expect(env.container.read(livesProvider).error, isA<Object>());
      expect(env.liveRepo.targetsSeen, isEmpty);
    });

    test('中身が同じフォロー状態に変わっても、購読し直さない', () async {
      final env = _Env();
      env.read(livesProvider);
      await settle();
      expect(env.liveRepo.targetsSeen, hasLength(1));

      // 新しいリスト（順序も違う）だが、対象は同じ
      env.setFollowing(AsyncData([p1, g1]));
      await settle();
      expect(env.liveRepo.targetsSeen, hasLength(1));
    });

    test('フォローが変われば、新しい対象で購読し直す', () async {
      final env = _Env();
      env.read(livesProvider);
      await settle();
      env.setFollowing(AsyncData([g1]));
      await settle();
      expect(
        env.liveRepo.targetsSeen.last,
        const FollowTargets(groupIds: {'g1'}),
      );
    });

    test('リポジトリのエラーはエラーになる', () async {
      final env = _Env(liveRepo: FakeLiveRepository()..fail = true);
      env.read(livesProvider);
      await settle();
      expect(env.container.read(livesProvider).hasError, isTrue);
    });
  });

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
}
