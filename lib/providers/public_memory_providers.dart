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

/// みんなのメモリー（add_K 6.1）。[oshiKey] が null ならフォロー中すべて、
/// あればその推し（OshiSummary.key）だけ。個人は所属グループのライブも含める。
/// 推しごとに購読し、同じ ID を除いて更新日時の新しい順に並べる。
/// どれかがエラーならエラー、どれかが読み込み中なら読み込み中
final sharedMemoriesFeedProvider = Provider.autoDispose
    .family<AsyncValue<List<PublicMemory>>, String?>((ref, oshiKey) {
      final following = ref.watch(followingOshisProvider);
      if (following case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      final oshis = following.value;
      if (oshis == null) return const AsyncLoading();
      final chosen = oshiKey == null
          ? oshis
          : oshis.where((o) => o.key == oshiKey).toList();
      final targets = <String, ({OshiKind kind, String id})>{};
      for (final o in chosen) {
        targets[o.key] = (kind: o.kind, id: o.id);
        if (o.kind == OshiKind.person) {
          for (final g in o.groupIds) {
            targets['${OshiKind.group.name}/$g'] = (
              kind: OshiKind.group,
              id: g,
            );
          }
        }
      }
      if (targets.isEmpty) return const AsyncData([]);
      final values = [
        for (final t in targets.values) ref.watch(publicMemoriesForProvider(t)),
      ];
      for (final v in values) {
        if (v case AsyncError(:final error, :final stackTrace)) {
          return AsyncError(error, stackTrace);
        }
      }
      if (values.any((v) => !v.hasValue)) return const AsyncLoading();
      return AsyncData(
        mergePublicMemories([for (final v in values) v.requireValue]),
      );
    });

/// 推しごとの公開メモリーをまとめる。同じ ID は1つにし、更新日時の新しい順
/// （保存直後で更新日時が確定していないものは先頭）
List<PublicMemory> mergePublicMemories(List<List<PublicMemory>> lists) {
  final byId = <String, PublicMemory>{
    for (final l in lists)
      for (final m in l) m.id: m,
  };
  return byId.values.toList()..sort((a, b) {
    final ta = a.updatedAt;
    final tb = b.updatedAt;
    if (ta == null) return tb == null ? 0 : -1;
    if (tb == null) return 1;
    return tb.compareTo(ta);
  });
}