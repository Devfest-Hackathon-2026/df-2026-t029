import 'dart:async';

import 'package:oshiashi/models/application.dart';
import 'package:oshiashi/models/history_entry.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/my_live.dart';
import 'package:oshiashi/models/performance.dart';
import 'package:oshiashi/models/reception.dart';
import 'package:oshiashi/repositories/application_repository.dart';
import 'package:oshiashi/repositories/live_repository.dart';
import 'package:oshiashi/repositories/my_live_repository.dart';
import 'package:oshiashi/utils/live_diff.dart';

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

  /// watch*ByIds・OfLives に渡された ID の集合（呼ばれた順）
  final idsSeen = <Set<String>>[];

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
  Stream<List<Live>> watchLivesByIds(Set<String> liveIds) {
    idsSeen.add(liveIds);
    return _watch(
      () => [
        for (final l in lives)
          if (liveIds.contains(l.id)) l,
      ],
    );
  }

  @override
  Stream<List<Performance>> watchPerformancesOfLives(Set<String> liveIds) {
    idsSeen.add(liveIds);
    return _watch(
      () => [
        for (final p in performances)
          if (liveIds.contains(p.liveId)) p,
      ],
    );
  }

  @override
  Stream<List<Reception>> watchReceptionsOfLives(Set<String> liveIds) {
    idsSeen.add(liveIds);
    return _watch(
      () => [
        for (final r in receptions)
          if (liveIds.contains(r.liveId)) r,
      ],
    );
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

  // ---- Step4: 照合・更新・変更履歴 ----

  /// fetchCandidates が返すもの（出演者での絞り込みはしない）
  List<ExistingLive> candidates = const [];

  /// fetchCandidates に渡されたもの
  final candidateCalls = <({List<String> groupIds, List<String> oshiIds})>[];

  /// fetchExisting が返すもの（ライブ ID → 一式）
  Map<String, ExistingLive> existing = {};

  /// 設定すると、fetchCandidates・fetchExisting はこれを投げる
  Object? fetchError;

  /// applyMerge に渡されたもの
  final merged = <({LiveMergePlan plan, String uid})>[];

  /// 設定すると、applyMerge はこれが完了するまで待つ
  Completer<void>? mergeGate;

  /// 設定すると、applyMerge はこれを投げる（LiveConflictException など）
  Object? mergeError;

  /// watchHistory が流すもの（対象 → 履歴）
  Map<HistoryTarget, List<HistoryEntry>> history = {};

  /// watchDocStamps が流すもの（ライブ ID → 日時）
  Map<String, List<DocStamp>> docStamps = {};

  /// revert に渡されたもの
  final reverted = <({HistoryEntry entry, String uid})>[];

  /// 設定すると、revert はこれを投げる
  Object? revertError;

  void setHistory(HistoryTarget target, List<HistoryEntry> entries) {
    history = {...history, target: entries};
    _changes.add(null);
  }

  void setDocStamps(String liveId, List<DocStamp> stamps) {
    docStamps = {...docStamps, liveId: stamps};
    _changes.add(null);
  }

  @override
  Future<List<ExistingLive>> fetchCandidates({
    required List<String> groupIds,
    required List<String> oshiIds,
  }) async {
    candidateCalls.add((groupIds: groupIds, oshiIds: oshiIds));
    if (fetchError case final e?) throw e;
    return candidates;
  }

  @override
  Future<ExistingLive?> fetchExisting(String liveId) async {
    if (fetchError case final e?) throw e;
    return existing[liveId];
  }

  @override
  Future<SavedLive> applyMerge(
    LiveMergePlan plan, {
    required String uid,
  }) async {
    merged.add((plan: plan, uid: uid));
    await mergeGate?.future;
    if (mergeError case final e?) throw e;
    return (
      live: plan.base.live,
      performances: const <Performance>[],
      receptions: const <Reception>[],
    );
  }

  @override
  Stream<List<HistoryEntry>> watchHistory(HistoryTarget target) =>
      _watch(() => history[target] ?? const <HistoryEntry>[]);

  @override
  Stream<List<DocStamp>> watchDocStamps(String liveId) =>
      _watch(() => docStamps[liveId] ?? const <DocStamp>[]);

  @override
  Future<void> revert(HistoryEntry entry, {required String uid}) async {
    reverted.add((entry: entry, uid: uid));
    if (revertError case final e?) throw e;
  }
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

/// 中身を外から操作できる偽の MyLiveRepository（Firestore を使わない）
class FakeMyLiveRepository implements MyLiveRepository {
  FakeMyLiveRepository({Iterable<String> ids = const []}) : ids = {...ids};

  /// 今入っているライブの ID。変えるときは [add]・[remove] を使う
  final Set<String> ids;
  final _changes = StreamController<void>.broadcast();

  /// true なら watchAll がエラー（permission-denied）を流す
  bool fail = false;

  /// false なら watchAll は値を流さない（読み込み中のまま）
  bool emitInitial = true;

  /// 設定すると、add・remove はこれを投げる
  Object? writeError;

  /// 設定すると、add・remove はこれが完了するまで待つ
  Completer<void>? writeGate;

  final added = <({String uid, String liveId})>[];
  final removed = <({String uid, String liveId})>[];

  @override
  Stream<List<MyLive>> watchAll(String uid) async* {
    if (fail) throw permissionDenied();
    if (emitInitial) yield _current();
    await for (final _ in _changes.stream) {
      yield _current();
    }
  }

  List<MyLive> _current() => [for (final id in ids) MyLive(liveId: id)];

  @override
  Future<void> add(String uid, String liveId) async {
    added.add((uid: uid, liveId: liveId));
    await writeGate?.future;
    if (writeError case final e?) throw e;
    if (ids.add(liveId)) _changes.add(null);
  }

  @override
  Future<void> remove(String uid, String liveId) async {
    removed.add((uid: uid, liveId: liveId));
    await writeGate?.future;
    if (writeError case final e?) throw e;
    if (ids.remove(liveId)) _changes.add(null);
  }
}
