import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/live_form/live_draft_to_models.dart';
import '../models/application.dart';
import '../models/history_entry.dart';
import '../models/live.dart';
import '../models/performance.dart';
import '../models/reception.dart';
import '../repositories/application_repository.dart';
import '../repositories/live_repository.dart';
import '../repositories/my_live_repository.dart';
import '../utils/deadline.dart';
import '../utils/live_diff.dart';
import '../utils/live_match.dart';
import '../utils/live_search.dart';
import '../utils/winners_only.dart';
import 'oshi_providers.dart';

/// ライブ・公演・受付のリポジトリ。テストでは `overrideWithValue` で差し替える
final liveRepositoryProvider = Provider<LiveRepository>(
  (ref) => FirestoreLiveRepository(FirebaseFirestore.instance),
);

/// 申込状況のリポジトリ。テストでは `overrideWithValue` で差し替える
final applicationRepositoryProvider = Provider<ApplicationRepository>(
  (ref) => FirestoreApplicationRepository(FirebaseFirestore.instance),
);

/// 自分のライブ一覧のリポジトリ。テストでは `overrideWithValue` で差し替える
final myLiveRepositoryProvider = Provider<MyLiveRepository>(
  (ref) => FirestoreMyLiveRepository(FirebaseFirestore.instance),
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

/// ライブ一覧画面の行（[buildLiveList] で並べたもの）
final liveListProvider = Provider<AsyncValue<List<LiveListEntry>>>((ref) {
  final now = ref.watch(nowProvider);
  return _combine2(
    ref.watch(myLivesProvider),
    ref.watch(myPerformancesProvider),
    (lives, performances) => buildLiveList(lives, performances, now),
  );
});

/// 自分のライブ一覧の ID の集合。未ログインなら空
final myLiveIdsProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <String>{});
  return ref
      .watch(myLiveRepositoryProvider)
      .watchAll(uid)
      .map((list) => {for (final m in list) m.liveId});
}, retry: firestoreRetry);

/// 自分のライブ一覧のライブ（順序は不定）。ID の集合が決まってから購読する
final myLivesProvider = StreamProvider<List<Live>>((ref) {
  return _watchMine(ref, (repo, ids) => repo.watchLivesByIds(ids));
}, retry: firestoreRetry);

/// 自分のライブ一覧の公演（順序は不定）
final myPerformancesProvider = StreamProvider<List<Performance>>((ref) {
  return _watchMine(ref, (repo, ids) => repo.watchPerformancesOfLives(ids));
}, retry: firestoreRetry);

/// 自分のライブ一覧の受付（順序は不定）
final myReceptionsProvider = StreamProvider<List<Reception>>((ref) {
  return _watchMine(ref, (repo, ids) => repo.watchReceptionsOfLives(ids));
}, retry: firestoreRetry);

/// liveId → 自分のライブ一覧に入っているか
final isInMyLivesProvider = Provider.family<AsyncValue<bool>, String>(
  (ref, liveId) =>
      ref.watch(myLiveIdsProvider).whenData((ids) => ids.contains(liveId)),
);

/// ライブを追加する画面の検索対象（選んだ推しから作る）のライブ（順序は不定）
final searchLivesSourceProvider = StreamProvider.autoDispose
    .family<List<Live>, FollowTargets>(
      (ref, targets) => ref.watch(liveRepositoryProvider).watchLives(targets),
      retry: firestoreRetry,
    );

/// ライブを追加する画面の検索対象の公演（順序は不定）
final searchPerformancesSourceProvider = StreamProvider.autoDispose
    .family<List<Performance>, FollowTargets>(
      (ref, targets) =>
          ref.watch(liveRepositoryProvider).watchPerformances(targets),
      retry: firestoreRetry,
    );

/// ライブを追加する画面の結果。[targets] は選んだ推しから
/// `FollowTargets.fromFollowing([推し])` で作る。[query] はライブ名の入力
/// （空ならすべて）。結果の並べ方は [searchLives]
final liveSearchProvider = Provider.autoDispose
    .family<
      AsyncValue<List<LiveListEntry>>,
      ({FollowTargets targets, String query})
    >((ref, args) {
      final now = ref.watch(nowProvider);
      return _combine2(
        ref.watch(searchLivesSourceProvider(args.targets)),
        ref.watch(searchPerformancesSourceProvider(args.targets)),
        (lives, performances) =>
            searchLives(lives, performances, args.query, now),
      );
    });

/// ホームの「推しの新しいライブ」に出す日数と件数（Ff 5.1）
const newOshiLiveDays = 14;
const newOshiLivesMax = 5;

/// 推しの新しいライブ（Ff 5.1）：フォロー中の推しのライブのうち、
/// 終わっていない・登録から14日以内・自分のライブ一覧に無いもの。
/// 登録の新しい順に最大5件。どれかがエラーならエラー、読み込み中なら読み込み中
final newOshiLivesProvider =
    Provider.autoDispose<AsyncValue<List<LiveListEntry>>>((ref) {
      final following = ref.watch(followingOshisProvider);
      if (following case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      final oshis = following.value;
      if (oshis == null) return const AsyncLoading();
      final targets = FollowTargets.fromFollowing(oshis);
      if (targets.isEmpty) return const AsyncData([]);

      final result = ref.watch(liveSearchProvider((targets: targets, query: '')));
      final mine = ref.watch(myLiveIdsProvider).value;
      if (mine == null) return const AsyncLoading();
      final since = ref
          .watch(nowProvider)
          .subtract(const Duration(days: newOshiLiveDays));

      List<LiveListEntry> pick(List<LiveListEntry> entries) {
        final list = [
          for (final e in entries)
            if (!e.isEnded &&
                e.nextStartAt != null &&
                e.live.id != null &&
                !mine.contains(e.live.id) &&
                (e.live.createdAt?.isAfter(since) ?? false))
              e,
        ]..sort((a, b) => b.live.createdAt!.compareTo(a.live.createdAt!));
        return list.take(newOshiLivesMax).toList();
      }

      return switch (result) {
        AsyncError(:final error, :final stackTrace) => AsyncError(
          error,
          stackTrace,
        ),
        AsyncValue(value: final entries?) => AsyncData(pick(entries)),
        _ => const AsyncLoading(),
      };
    });

/// ログイン中のユーザーの申込状況（receptionId → 申込状況）。
/// 未ログインなら空の Map
final applicationsProvider = StreamProvider<Map<String, Application>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const {});
  return ref.watch(applicationRepositoryProvider).watchAll(uid);
}, retry: firestoreRetry);

/// 当選者のみの受付を見られるライブの ID（won か paid のあるライブ）。
/// 申込状況が読み込み中・エラーのときは、そのまま伝える
final winnerLiveIdsProvider = Provider<AsyncValue<Set<String>>>(
  (ref) => ref.watch(applicationsProvider).whenData(winnerLiveIds),
);

/// ホームの「次の締切」（近い順・期限切れを除く・件数は絞らない）。
/// ライブが見つからない受付と、当選者でない人の当選者のみの受付は除く
final upcomingDeadlinesProvider = Provider<AsyncValue<List<DeadlineEntry>>>((
  ref,
) {
  final now = ref.watch(nowProvider);
  final receptionsAndApplications = _combine2(
    ref.watch(myReceptionsProvider),
    ref.watch(applicationsProvider),
    (receptions, applications) => (receptions, applications),
  );
  return _combine2(receptionsAndApplications, ref.watch(myLivesProvider), (
    pair,
    lives,
  ) {
    final (receptions, applications) = pair;
    final byId = <String, Live>{for (final l in lives) ?l.id: l};
    return [
      for (final d in upcomingDeadlines(
        receptions,
        applications,
        now,
        winnerLiveIds: winnerLiveIds(applications),
      ))
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

/// ライブ詳細用: 見せる受付と、隠した（当選すると表示される）件数。
/// 差分の確認・編集は絞らない [receptionsOfLiveProvider] を使うこと
final visibleReceptionsOfLiveProvider = Provider.autoDispose
    .family<AsyncValue<VisibleReceptions>, String>(
      (ref, liveId) => _combine2(
        ref.watch(receptionsOfLiveProvider(liveId)),
        ref.watch(winnerLiveIdsProvider),
        splitVisibleReceptions,
      ),
    );

// ---------------------------------------------------------------------------

/// 自分のライブ一覧の ID が決まってから購読する。読み込み中は値を流さず、
/// エラーはそのまま流す。未ログインなら空のリスト。
Stream<List<T>> _watchMine<T>(
  Ref ref,
  Stream<List<T>> Function(LiveRepository repo, Set<String> ids) watch,
) {
  if (ref.watch(currentUidProvider) == null) return Stream.value(const []);
  final ids = ref.watch(myLiveIdsProvider);
  final repo = ref.watch(liveRepositoryProvider);
  return switch (ids) {
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

// ---------------------------------------------------------------------------
// Step4: 照合・変更履歴（D6 で実装）
// ---------------------------------------------------------------------------

/// [input] と同じライブの候補（強い順に最大3件）。出演者が重なるライブを
/// 1回だけ読み、[findLiveCandidates] で判定する。保存ボタンから呼ぶ。
/// 読み取りに失敗したら Firestore の例外をそのまま投げる
Future<List<LiveCandidate>> fetchLiveCandidates(
  LiveRepository repo,
  LiveModels input,
) async {
  final existing = await repo.fetchCandidates(
    groupIds: input.live.groupIds,
    oshiIds: input.live.oshiIds,
  );
  return findLiveCandidates(input, existing);
}

/// ライブ1件の一式（編集用。1回だけ読む）。無い・読めないなら null
final existingLiveProvider = FutureProvider.autoDispose
    .family<ExistingLive?, String>(
      (ref, liveId) => ref.watch(liveRepositoryProvider).fetchExisting(liveId),
      retry: firestoreRetry,
    );

/// ドキュメント1件の変更履歴（新しい順）
final historyProvider = StreamProvider.autoDispose
    .family<List<HistoryEntry>, HistoryTarget>(
      (ref, target) => ref.watch(liveRepositoryProvider).watchHistory(target),
      retry: firestoreRetry,
    );

/// そのライブ本体と公演・受付の作成日時・更新日時
final docStampsProvider = StreamProvider.autoDispose
    .family<List<DocStamp>, String>(
      (ref, liveId) => ref.watch(liveRepositoryProvider).watchDocStamps(liveId),
      retry: firestoreRetry,
    );

/// ライブ詳細の変更履歴: ライブ・公演・受付の変更と、後から追加された
/// 公演・受付を新しい順に並べたもの（[buildLiveChanges]）。
/// ドキュメントごとに履歴を購読し、どれかがエラーならエラー、読み込み中なら
/// 読み込み中
final liveChangesProvider = Provider.autoDispose
    .family<AsyncValue<List<LiveChange>>, String>((ref, liveId) {
      final stamps = ref.watch(docStampsProvider(liveId));
      if (stamps case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (!stamps.hasValue) return const AsyncLoading();
      final docs = stamps.requireValue;
      final history = <HistoryEntry>[];
      var loading = false;
      for (final s in docs) {
        final h = ref.watch(historyProvider(s.target));
        if (h case AsyncError(:final error, :final stackTrace)) {
          return AsyncError(error, stackTrace);
        }
        if (h.hasValue) {
          history.addAll(h.requireValue);
        } else {
          loading = true;
        }
      }
      if (loading) return const AsyncLoading();
      return AsyncData(buildLiveChanges(stamps: docs, history: history));
    });

/// ライブ詳細の「変更あり」: 7日以内に変わったドキュメント → 直近の変更
/// （[latestRecentChangeByTarget]。[nowProvider] を使う）
final recentChangesProvider = Provider.autoDispose
    .family<AsyncValue<Map<HistoryTarget, LiveChange>>, String>((ref, liveId) {
      final now = ref.watch(nowProvider);
      return ref
          .watch(liveChangesProvider(liveId))
          .whenData((changes) => latestRecentChangeByTarget(changes, now));
    });
