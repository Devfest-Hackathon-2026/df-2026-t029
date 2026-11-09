import 'package:cloud_firestore/cloud_firestore.dart';

/// 「推しの新しいライブ」の既読（`users/{uid}/settings/newLives`。fix_Ff Ff-7）
abstract class NewLivesReadRepository {
  /// 既読にしたライブの ID
  Stream<Set<String>> watch(String uid);

  /// [liveIds] を既読にする
  Future<void> markRead(String uid, Iterable<String> liveIds);
}

/// Firestore 版の [NewLivesReadRepository]
class FirestoreNewLivesReadRepository implements NewLivesReadRepository {
  FirestoreNewLivesReadRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('newLives');

  @override
  Stream<Set<String>> watch(String uid) => _doc(uid).snapshots().map((snap) {
    final v = snap.data()?['readLiveIds'];
    return v is List ? {for (final x in v) if (x is String) x} : <String>{};
  });

  @override
  Future<void> markRead(String uid, Iterable<String> liveIds) async {
    final ids = liveIds.toSet().toList();
    if (ids.isEmpty) return;
    await _doc(uid).set({
      'readLiveIds': FieldValue.arrayUnion(ids),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}