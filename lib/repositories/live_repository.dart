import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/live.dart';
import '../models/performance.dart';
import '../models/reception.dart';

/// ライブ・公演・受付（共通データ）の保存
abstract class LiveRepository {
  /// ライブと、その公演・受付をまとめて新規作成し、ライブの ID を返す。
  ///
  /// - 公演・受付の `liveId`・`groupIds`・`oshiIds` は、ここでライブの値を付ける
  ///   （[Performance]・[Reception] 側の値は使わない。DB 設計案 5章「複製した項目の整合」）
  /// - 作成者・更新者は [uid]、作成日時・更新日時はサーバー時刻
  /// - 1つのバッチで書くため、途中で失敗したら何も保存されない
  Future<String> create({
    required Live live,
    required List<Performance> performances,
    required List<Reception> receptions,
    required String uid,
  });
}

/// Firestore 版の [LiveRepository]
class FirestoreLiveRepository implements LiveRepository {
  FirestoreLiveRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<String> create({
    required Live live,
    required List<Performance> performances,
    required List<Reception> receptions,
    required String uid,
  }) async {
    final batch = _db.batch();
    final liveRef = _db.collection('lives').doc();

    final meta = {
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final copied = {
      'liveId': liveRef.id,
      'groupIds': live.groupIds,
      'oshiIds': live.oshiIds,
    };

    batch.set(liveRef, {...live.toFirestore(), ...meta});
    for (final p in performances) {
      batch.set(
        _db.collection('performances').doc(),
        {...p.toFirestore(), ...copied, ...meta},
      );
    }
    for (final r in receptions) {
      batch.set(
        _db.collection('receptions').doc(),
        {...r.toFirestore(), ...copied, ...meta},
      );
    }

    await batch.commit();
    return liveRef.id;
  }
}