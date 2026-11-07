import 'package:cloud_firestore/cloud_firestore.dart';

/// 推しの色（個人の設定。`users/{uid}/settings/oshiColors`。Fc 5.3）。
///
/// `colors` に「推しの色のキー（`group:xxx`・`person:xxx`）→ 色（ARGB の数）」を持つ
abstract class OshiColorRepository {
  /// 推しの色のキー → 色（ARGB）。無ければ空
  Stream<Map<String, int>> watch(String uid);

  /// 色を決める。[argb] が null なら色を外す
  Future<void> setColor(String uid, String key, int? argb);
}

/// Firestore 版の [OshiColorRepository]
class FirestoreOshiColorRepository implements OshiColorRepository {
  FirestoreOshiColorRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('oshiColors');

  @override
  Stream<Map<String, int>> watch(String uid) => _doc(uid).snapshots().map((
    snap,
  ) {
    final colors = snap.data()?['colors'];
    if (colors is! Map) return const {};
    return {
      for (final e in colors.entries)
        if (e.key is String && e.value is num)
          e.key as String: (e.value as num).toInt(),
    };
  });

  @override
  Future<void> setColor(String uid, String key, int? argb) => _doc(uid).set({
    'colors': {key: argb ?? FieldValue.delete()},
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}