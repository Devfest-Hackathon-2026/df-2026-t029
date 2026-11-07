import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/oshi.dart';

/// 最推し（`users/{uid}/settings/favoriteOshi`。Fc 3.2）。
/// 1つだけ持つ。外すときはドキュメントを消す
abstract class FavoriteOshiRepository {
  /// 最推しの [OshiSummary.key]（`group/xxx`・`person/xxx`）。無ければ null
  Stream<String?> watch(String uid);

  /// [oshi] を最推しにする（前の最推しは置き換わる）
  Future<void> set(String uid, OshiSummary oshi);

  /// 最推しを外す
  Future<void> clear(String uid);
}

/// Firestore 版の [FavoriteOshiRepository]
class FirestoreFavoriteOshiRepository implements FavoriteOshiRepository {
  FirestoreFavoriteOshiRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('favoriteOshi');

  @override
  Stream<String?> watch(String uid) => _doc(uid).snapshots().map((snap) {
    final data = snap.data();
    final kind = OshiKind.values.asNameMap()[data?['kind']];
    final id = data?['id'];
    // 欠けている・型が違うときは「最推しなし」として扱う
    if (kind == null || id is! String || id.isEmpty) return null;
    return '${kind.name}/$id';
  });

  @override
  Future<void> set(String uid, OshiSummary oshi) => _doc(uid).set({
    'kind': oshi.kind.name,
    'id': oshi.id,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> clear(String uid) => _doc(uid).delete();
}