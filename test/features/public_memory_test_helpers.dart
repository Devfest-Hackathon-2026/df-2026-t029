import 'dart:async';

import 'package:oshiashi/models/live_memory.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/models/public_memory.dart';
import 'package:oshiashi/repositories/public_memory_repository.dart';

/// 公開メモリーの偽リポジトリ（Firebase を使わない）。
/// 書いた・消した呼び出しを記録する
class FakePublicMemoryRepository implements PublicMemoryRepository {
  final published = <LiveMemory>[];
  final unpublished = <String>[];

  @override
  Future<void> publish(
    LiveMemory memory, {
    required String uid,
    required String displayName,
    required List<String> groupIds,
    required List<String> oshiIds,
  }) async {
    published.add(memory);
  }

  @override
  Future<void> unpublish(String uid, String performanceId) async {
    unpublished.add('${uid}_$performanceId');
  }

  @override
  Stream<List<PublicMemory>> watchFor(
    OshiKind kind,
    String oshiId, {
    required int limit,
  }) => Stream.value(const []);

  @override
  Stream<PublicMemory?> watch(String id) => Stream.value(null);
}
