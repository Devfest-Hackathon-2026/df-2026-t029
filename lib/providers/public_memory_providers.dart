import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/oshi.dart';
import '../models/public_memory.dart';
import '../repositories/public_memory_repository.dart';
import 'oshi_providers.dart';

/// 公開メモリーのリポジトリ。テストでは `overrideWithValue` で差し替える
final publicMemoryRepositoryProvider = Provider<PublicMemoryRepository>(
  (ref) => FirestorePublicMemoryRepository(FirebaseFirestore.instance),
);

/// 推し1つあたりに読む公開メモリーの件数（add_K 6.1）
const publicMemoriesPerOshi = 30;

/// その推しが出演するライブの公開メモリー（更新日時の新しい順）
final publicMemoriesForProvider = StreamProvider.autoDispose
    .family<List<PublicMemory>, ({OshiKind kind, String id})>(
      (ref, target) => ref
          .watch(publicMemoryRepositoryProvider)
          .watchFor(target.kind, target.id, limit: publicMemoriesPerOshi),
      retry: firestoreRetry,
    );

/// 公開メモリー1件（`uid_performanceId`）。無ければ null
final publicMemoryProvider = StreamProvider.autoDispose
    .family<PublicMemory?, String>(
      (ref, id) => ref.watch(publicMemoryRepositoryProvider).watch(id),
      retry: firestoreRetry,
    );