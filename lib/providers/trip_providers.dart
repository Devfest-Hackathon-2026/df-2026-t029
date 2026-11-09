import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip.dart';
import '../repositories/trip_repository.dart';
import '../utils/trip_plans.dart';
import 'live_providers.dart';
import 'oshi_providers.dart';

/// 遠征メモのリポジトリ
final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => FirestoreTripRepository(FirebaseFirestore.instance),
);

/// ログイン中のユーザーの遠征メモ（performanceId → 遠征メモ）。未ログインなら空の Map
final myTripsProvider = StreamProvider<Map<String, Trip>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const {});
  return ref.watch(tripRepositoryProvider).watchAll(uid);
}, retry: firestoreRetry);

/// 遠征の一覧（これから・これまで。add_E 6章）。
/// 自分のライブ・公演・遠征メモがそろってから作る
final tripPlansProvider = Provider<AsyncValue<TripPlans>>((ref) {
  final now = ref.watch(nowProvider);
  final lives = ref.watch(myLivesProvider);
  final performances = ref.watch(myPerformancesProvider);
  final trips = ref.watch(myTripsProvider);
  if ((lives.value, performances.value, trips.value) case (
    final l?,
    final p?,
    final t?,
  )) {
    return AsyncData(buildTripPlans(l, p, t, now));
  }
  for (final v in <AsyncValue<Object?>>[lives, performances, trips]) {
    if (v case AsyncError(:final error, :final stackTrace)) {
      return AsyncError(error, stackTrace);
    }
  }
  return const AsyncLoading();
});
