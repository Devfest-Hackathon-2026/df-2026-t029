import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/live_memory.dart';

/// 個人のライブの記録（`users/{uid}/memories/{performanceId}`）
abstract class MemoryRepository {
  /// performanceId → 記録。順序は不定
  Stream<Map<String, LiveMemory>> watchAll(String uid);

  /// 記録を作る。`createdAt`・`updatedAt` はサーバー時刻
  Future<void> create(String uid, LiveMemory memory);

  /// 座席・セトリ・感想・写真を書き換える。`updatedAt` はサーバー時刻。
  /// 複製した項目（ライブ名・開演日時・会場）は変えない
  Future<void> update(String uid, LiveMemory memory);

  /// 記録を削除する
  Future<void> delete(String uid, String performanceId);

  /// SNS に投稿する操作をした印（`postedAt`）をサーバー時刻で書く。
  /// `updatedAt` は変えない
  Future<void> markPosted(String uid, String performanceId);
}

/// Firestore 版の [MemoryRepository]
class FirestoreMemoryRepository implements MemoryRepository {
  FirestoreMemoryRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _memories(String uid) =>
      _db.collection('users').doc(uid).collection('memories');

  @override
  Stream<Map<String, LiveMemory>> watchAll(String uid) =>
      _memories(uid).snapshots().map(
        (snap) => {
          for (final doc in snap.docs) doc.id: LiveMemory.fromFirestore(doc),
        },
      );

  @override
  Future<void> create(String uid, LiveMemory memory) =>
      _memories(uid).doc(memory.performanceId).set({
        ...memory.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> update(String uid, LiveMemory memory) =>
      _memories(uid).doc(memory.performanceId).update({
        'seat': memory.seat ?? FieldValue.delete(),
        'setlist': memory.setlist,
        'impression': memory.impression ?? FieldValue.delete(),
        'images': memory.images,
        'isPublic': memory.isPublic,
        'publicSeat': memory.publicSeat,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> delete(String uid, String performanceId) =>
      _memories(uid).doc(performanceId).delete();

  @override
  Future<void> markPosted(String uid, String performanceId) =>
      _memories(uid)
          .doc(performanceId)
          .update({'postedAt': FieldValue.serverTimestamp()});
}
