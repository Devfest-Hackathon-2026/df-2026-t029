import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/application.dart';
import '../models/live.dart';
import '../models/performance.dart';
import '../models/reception.dart';
import '../repositories/application_repository.dart';
import '../repositories/live_repository.dart';
import '../utils/deadline.dart';
import 'oshi_providers.dart';

/// ライブ・公演・受付のリポジトリ。テストでは `overrideWithValue` で差し替える
final liveRepositoryProvider = Provider<LiveRepository>(
  (ref) => FirestoreLiveRepository(FirebaseFirestore.instance),
);

/// 申込状況のリポジトリ。テストでは `overrideWithValue` で差し替える
final applicationRepositoryProvider = Provider<ApplicationRepository>(
  (ref) => FirestoreApplicationRepository(FirebaseFirestore.instance),
);

/// 現在時刻。1分ごとに新しい値になる（「24時間以内」「終了」「次の締切」の判定用）。
///
/// テストでは `nowProvider.overrideWithValue(DateTime(...))` で固定する
/// （固定しないと1分のタイマーが残り、ウィジェットテストが失敗する）。
final nowProvider = Provider<DateTime>((ref) {
  final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return DateTime.now();
});

/// 一覧の対象（フォロー中の推しから作る）。
/// [followingOshisProvider] と同じく、読み込み中・エラーをそのまま伝える。
/// 中身が同じなら == で等しいので、下のプロバイダは購読し直さない。
final followTargetsProvider = Provider<AsyncValue<FollowTargets>>((ref) {
  return ref
      .watch(followingOshisProvider)
      .whenData(FollowTargets.fromFollowing);
});

/// フォロー中の推しのライブ（順序は不定。並べたものは [liveListProvider]）
final livesProvider = StreamProvider<List<Live>>((ref) {
  return _watchTargets(ref, (repo, targets) => repo.watchLives(targets));
}, retry: firestoreRetry);

/// フォロー中の推しの公演（順序は不定）
final performancesProvider = StreamProvider<List<Performance>>((ref) {
  return _watchTargets(ref, (repo, targets) => repo.watchPerformances(targets));
}, retry: firestoreRetry);

/// フォロー中の推しの受付（順序は不定）
final receptionsProvider = StreamProvider<List<Reception>>((ref) {
  return _watchTargets(ref, (repo, targets) => repo.watchReceptions(targets));
}, retry: firestoreRetry);

/// ライブ一覧画面の行（[buildLiveList] で並べたもの）
final liveListProvider = Provider<AsyncValue<List<LiveListEntry>>>((ref) {
  final now = ref.watch(nowProvider);
  return _combine2(
    ref.watch(livesProvider),
    ref.watch(performancesProvider),
    (lives, performances) => buildLiveList(lives, performances, now),
  );
});

/// ログイン中のユーザーの申込状況（receptionId → 申込状況）。
/// 未ログインなら空の Map
final applicationsProvider = StreamProvider<Map<String, Application>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const {});
  return ref.watch(applicationRepositoryProvider).watchAll(uid);
}, retry: firestoreRetry);

/// ホームの「次の締切」（近い順・期限切れを除く・件数は絞らない）。
/// ライブが見つからない受付は除く
final upcomingDeadlinesProvider = Provider<AsyncValue<List<DeadlineEntry>>>((
  ref,
) {
  final now = ref.watch(nowProvider);
  final receptionsAndApplications = _combine2(
    ref.watch(receptionsProvider),
    ref.watch(applicationsProvider),
    (receptions, applications) => (receptions, applications),
  );
  return _combine2(receptionsAndApplications, ref.watch(livesProvider), (
    pair,
    lives,
  ) {
    final (receptions, applications) = pair;
    final byId = <String, Live>{for (final l in lives) ?l.id: l};
    return [
      for (final d in upcomingDeadlines(receptions, applications, now))
        if (d.reception.liveId case final liveId?)
          if (byId[liveId] case final live?)
            DeadlineEntry(deadline: d, live: live),
    ];
  });
});

/// ライブ1件（ライブ詳細）。無い・読めないときは null
final liveProvider = StreamProvider.autoDispose.family<Live?, String>(
  (ref, liveId) => ref.watch(liveRepositoryProvider).watchLive(liveId),
  retry: firestoreRetry,
);

/// そのライブの公演（開演日時の順）
final performancesOfLiveProvider = StreamProvider.autoDispose
    .family<List<Performance>, String>(
      (ref, liveId) =>
          ref.watch(liveRepositoryProvider).watchPerformancesOf(liveId),
      retry: firestoreRetry,
    );

/// そのライブの受付（申込期限の順）
final receptionsOfLiveProvider = StreamProvider.autoDispose
    .family<List<Reception>, String>(
      (ref, liveId) =>
          ref.watch(liveRepositoryProvider).watchReceptionsOf(liveId),
      retry: firestoreRetry,
    );

// ---------------------------------------------------------------------------

/// 一覧の対象が決まってから購読する。読み込み中は値を流さず、
/// エラーはそのまま流す。未ログインなら空のリスト。
Stream<List<T>> _watchTargets<T>(
  Ref ref,
  Stream<List<T>> Function(LiveRepository repo, FollowTargets targets) watch,
) {
  if (ref.watch(currentUidProvider) == null) return Stream.value(const []);
  final targets = ref.watch(followTargetsProvider);
  final repo = ref.watch(liveRepositoryProvider);
  return switch (targets) {
    AsyncData(:final value) => watch(repo, value),
    AsyncError(:final error, :final stackTrace) => Stream.error(
      error,
      stackTrace,
    ),
    _ => Stream.fromFuture(Completer<List<T>>().future),
  };
}

/// 2つの AsyncValue をまとめる。どちらかがエラーならエラー、
/// どちらかが読み込み中なら読み込み中
AsyncValue<R> _combine2<A, B, R>(
  AsyncValue<A> a,
  AsyncValue<B> b,
  R Function(A a, B b) combine,
) {
  if (a case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (b case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (!a.hasValue || !b.hasValue) return const AsyncLoading();
  return AsyncData(combine(a.requireValue, b.requireValue));
}
