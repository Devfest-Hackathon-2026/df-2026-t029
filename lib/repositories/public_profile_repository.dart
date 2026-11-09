import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/public_profile.dart';

/// 公開プロフィール（`publicProfiles/{uid}`。add_I 3.2）
abstract class PublicProfileRepository {
  /// 公開プロフィール。無ければ null
  Stream<PublicProfile?> watch(String uid);

  /// ハンドルネームを書く（プロフィールの保存のとき）
  Future<void> saveName(String uid, String displayName);

  /// アイコンを決める。[path] が null なら外す
  Future<void> setIcon(String uid, String? path);
}

/// Firestore 版の [PublicProfileRepository]
class FirestorePublicProfileRepository implements PublicProfileRepository {
  FirestorePublicProfileRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('publicProfiles').doc(uid);

  @override
  Stream<PublicProfile?> watch(String uid) => _doc(uid).snapshots().map((snap) {
    final data = snap.data();
    return data == null ? null : PublicProfile.fromMap(data);
  });

  @override
  Future<void> saveName(String uid, String displayName) => _doc(uid).set({
    'displayName': displayName.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  @override
  Future<void> setIcon(String uid, String? path) => _doc(uid).set({
    'iconPath': path ?? FieldValue.delete(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
