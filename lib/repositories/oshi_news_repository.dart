import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/oshi_news.dart';

/// 推しのお知らせ（`oshiNews`。add_P 5.1）。読むだけ
abstract class OshiNewsRepository {
  /// [keys] の推しのお知らせを、新しい順に [limit] 件。[keys] が空なら空のリスト。
  /// [keys] は30件まで（Firestore の whereIn の上限）
  Stream<List<OshiNews>> watchByOshiKeys(
    List<String> keys, {
    required int limit,
  });
}

/// Firestore 版の [OshiNewsRepository]
class FirestoreOshiNewsRepository implements OshiNewsRepository {
  FirestoreOshiNewsRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<OshiNews>> watchByOshiKeys(
    List<String> keys, {
    required int limit,
  }) {
    if (keys.isEmpty) return Stream.value(const []);
    return _db
        .collection('oshiNews')
        .where('oshiKey', whereIn: keys.take(30).toList())
        .orderBy('publishedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => [
            for (final doc in snap.docs)
              ?OshiNews.fromFirestore(doc.id, doc.data()),
          ],
        );
  }
}