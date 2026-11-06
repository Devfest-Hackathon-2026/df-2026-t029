import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/live_memory.dart';
import '../repositories/memory_repository.dart';
import '../utils/memory_album.dart';

import 'live_providers.dart';
import 'oshi_providers.dart';

/// ライブの記録のリポジトリ。テストでは `overrideWithValue` で差し替える
final memoryRepositoryProvider = Provider<MemoryRepository>(
  (ref) => FirestoreMemoryRepository(FirebaseFirestore.instance),
);

/// ログイン中のユーザーの記録（performanceId → 記録）。未ログインなら空の Map
final myMemoriesProvider = StreamProvider<Map<String, LiveMemory>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const {});
  return ref.watch(memoryRepositoryProvider).watchAll(uid);
}, retry: firestoreRetry);

/// 公演1件の記録。記録が無ければ null（[myMemoriesProvider] から取り出す）
final memoryProvider = Provider.autoDispose
    .family<AsyncValue<LiveMemory?>, String>(
      (ref, performanceId) => ref
          .watch(myMemoriesProvider)
          .whenData((memories) => memories[performanceId]),
    );

/// メモリー一覧（参戦予定・参戦済み）。[nowProvider] で1分ごとに判定し直す
final memoryAlbumProvider = Provider<AsyncValue<MemoryAlbum>>((ref) {
  final now = ref.watch(nowProvider);
  return ref
      .watch(myMemoriesProvider)
      .whenData((memories) => buildMemoryAlbum(memories.values, now));
});