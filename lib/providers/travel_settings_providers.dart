import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/travel_settings.dart';
import '../repositories/travel_settings_repository.dart';
import 'oshi_providers.dart';

/// 遠征の個人の設定のリポジトリ。テストでは `overrideWithValue` で差し替える
final travelSettingsRepositoryProvider = Provider<TravelSettingsRepository>(
  (ref) => FirestoreTravelSettingsRepository(FirebaseFirestore.instance),
);

/// 遠征の個人の設定（帰りの駅。add_M 3.1）。未ログインなら空
final travelSettingsProvider = StreamProvider<TravelSettings>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(TravelSettings.empty);
  return ref.watch(travelSettingsRepositoryProvider).watch(uid);
}, retry: firestoreRetry);