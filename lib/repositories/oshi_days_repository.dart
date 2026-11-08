import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/oshi_days.dart';

/// 推しの記念日（個人の設定。`users/{uid}/settings/oshiDays`。add_O 3.1）
abstract class OshiDaysRepository {
  Stream<OshiDays> watch(String uid);

  /// 推し始めた日を決める。[date] が null なら外す
  Future<void> setStartDate(String uid, String key, DateTime? date);

  /// 誕生日（グループは結成日）を決める。[md] が null なら外す
  Future<void> setBirthday(String uid, String key, MonthDay? md);
}

/// Firestore 版の [OshiDaysRepository]
class FirestoreOshiDaysRepository implements OshiDaysRepository {
  FirestoreOshiDaysRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('oshiDays');

  @override
  Stream<OshiDays> watch(String uid) =>
      _doc(uid).snapshots().map((snap) => OshiDays.fromMap(snap.data()));

  @override
  Future<void> setStartDate(String uid, String key, DateTime? date) =>
      _doc(uid).set({
        'startDates': {key: date == null ? FieldValue.delete() : formatYmd(date)},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  @override
  Future<void> setBirthday(String uid, String key, MonthDay? md) =>
      _doc(uid).set({
        'birthdays': {key: md == null ? FieldValue.delete() : formatMd(md)},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}