import 'package:cloud_firestore/cloud_firestore.dart';

/// 推しの画像（個人の設定。`users/{uid}/settings/oshiImages`。add_I 3.1b）。
///
/// `images` に「推しの色のキー（`group:xxx`・`person:xxx`）→ Storage のパス」を持つ
abstract class OshiImageRepository {
  /// 推しの色のキー → Storage のパス。無ければ空
  Stream<Map<String, String>> watch(String uid);

  /// 画像を決める。[path] が null なら外す
  Future<void> setImage(String uid, String key, String? path);
}

/// Firestore 版の [OshiImageRepository]
class FirestoreOshiImageRepository implements OshiImageRepository {
  FirestoreOshiImageRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('oshiImages');

  @override
  Stream<Map<String, String>> watch(String uid) => _doc(uid).snapshots().map((
    snap,
  ) {
    final images = snap.data()?['images'];
    if (images is! Map) return const {};
    return {
      for (final e in images.entries)
        if (e.key is String && e.value is String && (e.value as String).isNotEmpty)
          e.key as String: e.value as String,
    };
  });

  @override
  Future<void> setImage(String uid, String key, String? path) =>
      _doc(uid).set({
        'images': {key: path ?? FieldValue.delete()},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}