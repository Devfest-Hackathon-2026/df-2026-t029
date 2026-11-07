import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trip.dart';

/// 個人の遠征メモ（`users/{uid}/trips/{performanceId}`）
abstract class TripRepository {
  /// performanceId → 遠征メモ。順序は不定
  Stream<Map<String, Trip>> watchAll(String uid);

  /// 遠征メモを保存する（丸ごと書き換える）。作成日時は初回だけ、更新日時は毎回サーバー時刻
  Future<void> save(String uid, Trip trip);

  /// 遠征メモを削除する
  Future<void> delete(String uid, String performanceId);
}

/// Firestore 版の [TripRepository]
class FirestoreTripRepository implements TripRepository {
  FirestoreTripRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _trips(String uid) =>
      _db.collection('users').doc(uid).collection('trips');

  @override
  Stream<Map<String, Trip>> watchAll(String uid) => _trips(uid).snapshots().map(
    (snap) => {for (final doc in snap.docs) doc.id: Trip.fromFirestore(doc)},
  );

  @override
  Future<void> save(String uid, Trip trip) =>
      // 丸ごと書き換えて、空にした項目を消す（作成日時は引き継ぐ）
      _trips(uid).doc(trip.performanceId).set({
        ...trip.toFirestore(),
        'createdAt': trip.createdAt != null
            ? Timestamp.fromDate(trip.createdAt!)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> delete(String uid, String performanceId) =>
      _trips(uid).doc(performanceId).delete();
}