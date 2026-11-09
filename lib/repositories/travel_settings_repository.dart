import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/travel_settings.dart';

/// 遠征の個人の設定（`users/{uid}/settings/travel`。add_M 3.1）
abstract class TravelSettingsRepository {
  Stream<TravelSettings> watch(String uid);

  /// 帰りの駅を決める。null か空なら消す
  Future<void> setHomeStation(String uid, String? station);
}

/// Firestore 版の [TravelSettingsRepository]
class FirestoreTravelSettingsRepository implements TravelSettingsRepository {
  FirestoreTravelSettingsRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('travel');

  @override
  Stream<TravelSettings> watch(String uid) =>
      _doc(uid).snapshots().map((snap) => TravelSettings.fromMap(snap.data()));

  @override
  Future<void> setHomeStation(String uid, String? station) {
    final s = station?.trim() ?? '';
    return _doc(uid).set({
      'homeStation': s.isEmpty ? FieldValue.delete() : s,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}