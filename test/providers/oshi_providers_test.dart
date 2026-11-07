import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/repositories/follow_repository.dart';
import 'package:oshiashi/repositories/oshi_repository.dart';

/// watchAll / watch の中身を外から流し込めるリポジトリ
class _ControlledOshiRepository implements OshiRepository {
  final controller = StreamController<List<OshiSummary>>.broadcast();
  int watchCount = 0;

  @override
  Stream<List<OshiSummary>> watchAll() {
    watchCount++;
    return controller.stream;
  }

  @override
  Future<String> request(OshiRequest request, {required String uid}) =>
      throw UnimplementedError();

  @override
  Future<String> requestGroupWithMembers(
    OshiRequest group,
    List<String> memberNames, {
    required String uid,
  }) => throw UnimplementedError();
}

class _ControlledFollowRepository implements FollowRepository {
  final controller = StreamController<FollowState>.broadcast();
  final watchedUids = <String>[];

  @override
  Stream<FollowState> watch(String uid) {
    watchedUids.add(uid);
    return controller.stream;
  }

  @override
  Future<void> follow(String uid, OshiSummary target, {String? displayName}) =>
      throw UnimplementedError();

  @override
  Future<void> unfollow(String uid, OshiSummary target) =>
      throw UnimplementedError();
}

class _Uid extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void set(String? value) => state = value;
}

/// permission-denied 以外は firestoreRetry で再試行されるので、エラー状態の確認にはこれを使う
final _permissionDenied = FirebaseException(
  plugin: 'cloud_firestore',
  code: 'permission-denied',
);

OshiSummary _oshi(
  String id,
  String name, {
  OshiKind kind = OshiKind.group,
  OshiStatus status = OshiStatus.approved,
}) => OshiSummary(
  id: id,
  kind: kind,
  name: name,
  genre: OshiGenre.idol,
  status: status,
);

ProviderContainer _container(List overrides) {
  final c = ProviderContainer(
    overrides: [...overrides],
    // エラーの自動再試行を止める（エラー状態をそのまま確かめるため）
    retry: (_, _) => null,
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('未ログイン', () {
    test(
      'allOshisProvider は空、followStateProvider は empty、リポジトリは呼ばない',
      () async {
        final oshiRepo = _ControlledOshiRepository();
        final followRepo = _ControlledFollowRepository();
        final c = _container([
          currentUidProvider.overrideWithValue(null),
          oshiRepositoryProvider.overrideWithValue(oshiRepo),
          followRepositoryProvider.overrideWithValue(followRepo),
        ]);
        // Riverpod 3 は購読者のいないプロバイダを一時停止するので、先に listen する
        c.listen(allOshisProvider, (_, _) {});
        c.listen(followStateProvider, (_, _) {});

        expect(await c.read(allOshisProvider.future), isEmpty);
        expect((await c.read(followStateProvider.future)).isEmpty, isTrue);
        expect(oshiRepo.watchCount, 0);
        expect(followRepo.watchedUids, isEmpty);
      },
    );
  });

  group('fake_cloud_firestore につないだ場合', () {
    late FakeFirebaseFirestore db;

    setUp(() {
      db = FakeFirebaseFirestore();
    });

    Future<void> seed(
      OshiKind kind,
      String id,
      String name, {
      String status = 'approved',
    }) => db.collection(kind.collection).doc(id).set({
      'name': name,
      'genre': 'idol',
      'status': status,
      'createdBy': 'x',
      'createdAt': Timestamp.now(),
    });

    test('フォロー中で承認済みの推しだけを個人から、名前順に返す（削除済み・申請中・未フォローは出さない）', () async {
      await seed(OshiKind.group, 'g1', 'B');
      await seed(OshiKind.group, 'g2', 'A');
      await seed(OshiKind.group, 'g3', 'C（未フォロー）');
      await seed(OshiKind.person, 'p1', 'D', status: 'pending');
      await seed(OshiKind.person, 'p2', 'E');
      await db.collection('users').doc('u1').set({
        'followingGroupIds': ['g1', 'g2', 'gone'],
        'followingOshiIds': ['p1', 'p2'],
      });

      final c = _container([
        currentUidProvider.overrideWithValue('u1'),
        oshiRepositoryProvider.overrideWithValue(FirestoreOshiRepository(db)),
        followRepositoryProvider.overrideWithValue(
          FirestoreFollowRepository(db),
        ),
      ]);
      c.listen(followingOshisProvider, (_, _) {});
      await c.read(allOshisProvider.future);
      await c.read(followStateProvider.future);

      final value = c.read(followingOshisProvider);
      expect(value.value!.map((o) => o.key).toList(), [
        'person/p2',
        'group/g2',
        'group/g1',
      ]);
    });

    test('同じ ID でも種別が違えばフォロー中にしない', () async {
      await seed(OshiKind.person, 'x', '個人X');
      await db.collection('users').doc('u1').set({
        'followingGroupIds': ['x'],
      });
      final c = _container([
        currentUidProvider.overrideWithValue('u1'),
        oshiRepositoryProvider.overrideWithValue(FirestoreOshiRepository(db)),
        followRepositoryProvider.overrideWithValue(
          FirestoreFollowRepository(db),
        ),
      ]);
      c.listen(followingOshisProvider, (_, _) {});
      await c.read(allOshisProvider.future);
      await c.read(followStateProvider.future);
      expect(c.read(followingOshisProvider).value, isEmpty);
    });
  });

  group('followingOshisProvider の状態', () {
    late _ControlledOshiRepository oshiRepo;
    late _ControlledFollowRepository followRepo;
    late ProviderContainer c;

    setUp(() {
      oshiRepo = _ControlledOshiRepository();
      followRepo = _ControlledFollowRepository();
      c = _container([
        currentUidProvider.overrideWithValue('u1'),
        oshiRepositoryProvider.overrideWithValue(oshiRepo),
        followRepositoryProvider.overrideWithValue(followRepo),
      ]);
      c.listen(followingOshisProvider, (_, _) {});
    });

    test('どちらも届く前は読み込み中', () async {
      await pumpEventQueue();
      expect(c.read(followingOshisProvider), isA<AsyncLoading>());
    });

    test('片方だけ届いた状態でも読み込み中', () async {
      await pumpEventQueue();
      oshiRepo.controller.add([_oshi('g1', 'A')]);
      await pumpEventQueue();
      expect(c.read(followingOshisProvider), isA<AsyncLoading>());

      followRepo.controller.add(const FollowState(groupIds: {'g1'}));
      await pumpEventQueue();
      expect(c.read(followingOshisProvider).value!.single.id, 'g1');
    });

    test('推しの一覧がエラーならエラー（フォロー状態が届いていても）', () async {
      await pumpEventQueue();
      followRepo.controller.add(FollowState.empty);
      oshiRepo.controller.addError(_permissionDenied);
      await pumpEventQueue();
      expect(c.read(followingOshisProvider), isA<AsyncError>());
    });

    test('フォロー状態がエラーならエラー（推しの一覧が届いていても）', () async {
      await pumpEventQueue();
      oshiRepo.controller.add([_oshi('g1', 'A')]);
      followRepo.controller.addError(_permissionDenied);
      await pumpEventQueue();
      expect(c.read(followingOshisProvider), isA<AsyncError>());
    });

    test('承認済みが申請中に戻されると一覧から消える', () async {
      await pumpEventQueue();
      followRepo.controller.add(const FollowState(groupIds: {'g1'}));
      oshiRepo.controller.add([_oshi('g1', 'A')]);
      await pumpEventQueue();
      expect(c.read(followingOshisProvider).value, hasLength(1));

      oshiRepo.controller.add([_oshi('g1', 'A', status: OshiStatus.pending)]);
      await pumpEventQueue();
      expect(c.read(followingOshisProvider).value, isEmpty);
    });
  });

  group('uid の切り替え', () {
    test('ログインし直すと、新しい uid で購読し直す', () async {
      final followRepo = _ControlledFollowRepository();
      final oshiRepo = _ControlledOshiRepository();
      final uid = NotifierProvider<_Uid, String?>(_Uid.new);
      final c = _container([
        currentUidProvider.overrideWith((ref) => ref.watch(uid)),
        oshiRepositoryProvider.overrideWithValue(oshiRepo),
        followRepositoryProvider.overrideWithValue(followRepo),
      ]);
      c.listen(followStateProvider, (_, _) {});
      c.listen(allOshisProvider, (_, _) {});
      await pumpEventQueue();
      expect(followRepo.watchedUids, ['u1']);

      c.read(uid.notifier).set('u2');
      await pumpEventQueue();
      expect(followRepo.watchedUids, ['u1', 'u2']);

      c.read(uid.notifier).set(null);
      await pumpEventQueue();
      expect((await c.read(followStateProvider.future)).isEmpty, isTrue);
      expect(await c.read(allOshisProvider.future), isEmpty);
    });
  });
}
