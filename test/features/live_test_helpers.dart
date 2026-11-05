import 'dart:async';

import 'package:oshiashi/models/application.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/performance.dart';
import 'package:oshiashi/models/reception.dart';
import 'package:oshiashi/repositories/application_repository.dart';
import 'package:oshiashi/repositories/live_repository.dart';

import 'oshi_test_helpers.dart';

/// 中身を外から操作できる偽の LiveRepository（Firestore を使わない）。
///
/// watch* は、ライブ・公演・受付それぞれの「今の値」を流し、[setLives] などで
/// 変えると新しい値を流す。対象（FollowTargets）での絞り込みはしない
/// （絞り込みはリポジトリのテストで確かめる）。渡された対象は [targetsSeen] に残す。
class FakeLiveRepository implements LiveRepository {
  FakeLiveRepository({
    this.lives = const [],
    this.performances = const [],
    this.receptions = const [],
  });

  /// 今の値。変えるときは [setLives] などを使う（新しい値が流れる）
  List<Live> lives;
  List<Performance> performances;
  List<Reception> receptions;
  final _changes = StreamController<void>.broadcast();

  /// true なら watch* がエラー（permission-denied）を流す
  bool fail = false;

  /// false なら watch* は値を流さない（読み込み中のまま）
  bool emitInitial = true;

  final targetsSeen = <FollowTargets>[];

  /// create に渡されたもの
  final created =
      <
        ({
          Live live,
          List<Performance> performances,
          List<Reception> receptions,
          String uid,
        })
      >[];

  /// 設定すると、create はこれが完了するまで待つ
  Completer<void>? createGate;

  /// 設定すると、create はこれを投げる
  Object? createError;

  void setLives(List<Live> v) {
    lives = v;
    _changes.add(null);
  }

  void setPerformances(List<Performance> v) {
    performances = v;
    _changes.add(null);
  }

  void setReceptions(List<Reception> v) {
    receptions = v;
    _changes.add(null);
  }

  Stream<T> _watch<T>(T Function() current) async* {
    if (fail) throw permissionDenied();
    if (emitInitial) yield current();
    await for (final _ in _changes.stream) {
      yield current();
    }
  }

  @override
  Future<SavedLive> create({
    required Live live,
    required List<Performance> performances,
    required List<Reception> receptions,
    required String uid,
  }) async {
    created.add((
      live: live,
      performances: performances,
      receptions: receptions,
      uid: uid,
    ));
    await createGate?.future;
    if (createError case final e?) throw e;
    final liveId = 'new-live-${created.length}';
    return (
      live: live.copyWithId(liveId),
      performances: [
        for (final (i, p) in performances.indexed)
          p.copyWithIds(
            id: '$liveId-p$i',
            liveId: liveId,
            groupIds: live.groupIds,
            oshiIds: live.oshiIds,
          ),
      ],
      receptions: [
        for (final (i, r) in receptions.indexed)
          r.copyWithIds(
            id: '$liveId-r$i',
            liveId: liveId,
            groupIds: live.groupIds,
            oshiIds: live.oshiIds,
          ),
      ],
    );
  }

  @override
  Stream<List<Live>> watchLives(FollowTargets targets) {
    targetsSeen.add(targets);
    return _watch(() => lives);
  }

  @override
  Stream<List<Performance>> watchPerformances(FollowTargets targets) {
    targetsSeen.add(targets);
    return _watch(() => performances);
  }

  @override
  Stream<List<Reception>> watchReceptions(FollowTargets targets) {
    targetsSeen.add(targets);
    return _watch(() => receptions);
  }

  @override
  Stream<Live?> watchLive(String liveId) =>
      _watch(() => lives.where((l) => l.id == liveId).firstOrNull);

  @override
  Stream<List<Performance>> watchPerformancesOf(String liveId) => _watch(
    () =>
        performances.where((p) => p.liveId == liveId).toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt)),
  );

  @override
  Stream<List<Reception>> watchReceptionsOf(String liveId) => _watch(
    () =>
        receptions.where((r) => r.liveId == liveId).toList()
          ..sort((a, b) => a.applyEndAt.compareTo(b.applyEndAt)),
  );
}

/// 申込状況を覚えておく偽の ApplicationRepository
class FakeApplicationRepository implements ApplicationRepository {
  FakeApplicationRepository([Map<String, Application>? initial])
    : _current = {...?initial};

  Map<String, Application> _current;
  final _changes = StreamController<void>.broadcast();

  bool fail = false;

  /// setStatus に渡されたもの（receptionId, status）
  final calls = <(String?, ApplicationStatus?)>[];

  /// 設定すると、setStatus はこれが完了するまで待つ
  Completer<void>? gate;

  /// 設定すると、setStatus はこれを投げる
  Object? error;

  Map<String, Application> get current => Map.unmodifiable(_current);

  @override
  Stream<Map<String, Application>> watchAll(String uid) async* {
    if (fail) throw permissionDenied();
    yield current;
    await for (final _ in _changes.stream) {
      yield current;
    }
  }

  @override
  Future<void> setStatus(
    String uid,
    Reception reception,
    ApplicationStatus? status,
  ) async {
    calls.add((reception.id, status));
    await gate?.future;
    if (error case final e?) throw e;
    final id = reception.id!;
    _current = {..._current};
    if (status == null) {
      _current.remove(id);
    } else {
      _current[id] = Application(
        receptionId: id,
        liveId: reception.liveId!,
        status: status,
      );
    }
    _changes.add(null);
  }
}

/// 公演・受付を短く作る
Performance perfOf(String id, String liveId, DateTime startAt) =>
    Performance(id: id, liveId: liveId, startAt: startAt, venue: '会場$id');

Reception recOf(
  String id,
  String liveId, {
  required DateTime applyEndAt,
  DateTime? applyStartAt,
  DateTime? resultAt,
  DateTime? paymentDeadline,
  bool winnersOnly = false,
  String? name,
}) => Reception(
  id: id,
  liveId: liveId,
  type: ReceptionType.fc,
  name: name ?? '受付$id',
  applyStartAt: applyStartAt,
  applyEndAt: applyEndAt,
  resultAt: resultAt,
  paymentDeadline: paymentDeadline,
  winnersOnly: winnersOnly,
);
