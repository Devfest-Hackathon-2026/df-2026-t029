import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/my_live.dart';

/// 自分のライブ一覧（`users/{uid}/myLives`）
abstract class MyLiveRepository {
  /// 自分のライブ一覧（順序は不定）
  Stream<List<MyLive>> watchAll(String uid);

  /// 追加する。すでに入っていれば何もしない（addedAt を変えない）
  Future<void> add(String uid, String liveId);

  /// 外す。入っていなければ何もしない。申込状況は消さない
  Future<void> remove(String uid, String liveId);
}

/// Firestore 版。`users/{uid}/myLives/{liveId}`（項目は `addedAt` のみ）
class FirestoreMyLiveRepository implements MyLiveRepository {
  FirestoreMyLiveRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('myLives');

  @override
  Stream<List<MyLive>> watchAll(String uid) => _col(uid).snapshots().map(
    (snap) => [for (final d in snap.docs) MyLive.fromFirestore(d.id, d.data())],
  );

  @override
  Future<void> add(String uid, String liveId) {
    final ref = _col(uid).doc(liveId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) return;
      tx.set(ref, {'addedAt': FieldValue.serverTimestamp()});
    });
  }

  @override
  Future<void> remove(String uid, String liveId) =>
      _col(uid).doc(liveId).delete();
}
