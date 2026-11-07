import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip.dart';
import '../repositories/trip_repository.dart';
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