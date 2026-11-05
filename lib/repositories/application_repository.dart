import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/application.dart';
import '../models/reception.dart';

/// 個人の申込状況（`users/{uid}/applications/{receptionId}`）
abstract class ApplicationRepository {
  /// receptionId → 申込状況。ドキュメントが無い受付は含まない（＝未申込）。
  /// 読めないドキュメント（不明な status など）も含まない。
  Stream<Map<String, Application>> watchAll(String uid);

  /// 申込状況を変える。どの状態からどの状態へも変えられる（計画書 3.4）。
  ///
  /// - [status] が null なら未申込に戻す（ドキュメントを削除する。無ければ何もしない）
  /// - それ以外は `liveId`・`status`・`updatedAt`（サーバー時刻）の3項目で
  ///   ドキュメントを上書きする
  /// - [reception] の id か liveId が null なら `ArgumentError`
  Future<void> setStatus(
    String uid,
    Reception reception,
    ApplicationStatus? status,
  );
}

/// Firestore 版の [ApplicationRepository]
class FirestoreApplicationRepository implements ApplicationRepository {
  FirestoreApplicationRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _applications(String uid) =>
      _db.collection('users').doc(uid).collection('applications');

  @override
  Stream<Map<String, Application>> watchAll(String uid) =>
      _applications(uid).snapshots().map(
        (snap) => {
          for (final doc in snap.docs)
            doc.id: ?Application.fromFirestore(doc.id, doc.data()),
        },
      );

  @override
  Future<void> setStatus(
    String uid,
    Reception reception,
    ApplicationStatus? status,
  ) async {
    final receptionId = reception.id;
    final liveId = reception.liveId;
    if (receptionId == null || liveId == null) {
      throw ArgumentError('保存前の受付の申込状況は変えられません');
    }
    final ref = _applications(uid).doc(receptionId);
    if (status == null) {
      await ref.delete();
      return;
    }
    await ref.set({
      'liveId': liveId,
      'status': status.code,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
