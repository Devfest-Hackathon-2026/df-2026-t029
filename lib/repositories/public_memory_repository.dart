import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/live_memory.dart';
import '../models/oshi.dart';
import '../models/public_memory.dart';

/// 公開メモリー（`publicMemories/{uid}_{performanceId}`。add_K 3.2）
abstract class PublicMemoryRepository {
  /// 自分の記録の写しを書く（丸ごと書き換える）。
  /// `createdAt` は最初に公開したときだけサーバー時刻、`updatedAt` は毎回サーバー時刻
  Future<void> publish(
    LiveMemory memory, {
    required String uid,
    required String displayName,
    required List<String> groupIds,
    required List<String> oshiIds,
  });

  /// 写しを消す（無くてもエラーにしない）
  Future<void> unpublish(String uid, String performanceId);

  /// その推しが出演するライブの公開メモリー（更新日時の新しい順に [limit] 件）
  Stream<List<PublicMemory>> watchFor(
    OshiKind kind,
    String oshiId, {
    required int limit,
  });

  /// 公開メモリー1件。無ければ null
  Stream<PublicMemory?> watch(String id);
}

/// Firestore 版の [PublicMemoryRepository]
class FirestorePublicMemoryRepository implements PublicMemoryRepository {
  FirestorePublicMemoryRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('publicMemories');

  @override
  Future<void> publish(
    LiveMemory memory, {
    required String uid,
    required String displayName,
    required List<String> groupIds,
    required List<String> oshiIds,
  }) {
    final ref = _col.doc(PublicMemory.idOf(uid, memory.performanceId));
    // 最初の公開日時を残すため、あれば元の createdAt を使う
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final createdAt = snap.data()?['createdAt'];
      tx.set(ref, {
        ...PublicMemory.dataOf(
          memory,
          uid: uid,
          displayName: displayName,
          groupIds: groupIds,
          oshiIds: oshiIds,
        ),
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> unpublish(String uid, String performanceId) =>
      _col.doc(PublicMemory.idOf(uid, performanceId)).delete();

  @override
  Stream<List<PublicMemory>> watchFor(
    OshiKind kind,
    String oshiId, {
    required int limit,
  }) => _col
      .where(
        kind == OshiKind.group ? 'groupIds' : 'oshiIds',
        arrayContains: oshiId,
      )
      .orderBy('updatedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => [for (final d in s.docs) PublicMemory.fromFirestore(d)]);

  @override
  Stream<PublicMemory?> watch(String id) => _col
      .doc(id)
      .snapshots()
      .map((snap) => snap.exists ? PublicMemory.fromFirestore(snap) : null);
}
