import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/live.dart';
import '../models/performance.dart';
import '../models/reception.dart';

/// 保存したライブ・公演・受付（ID と複製項目を付けたもの）
typedef SavedLive = ({
  Live live,
  List<Performance> performances,
  List<Reception> receptions,
});

/// ライブ・公演・受付（共通データ）の保存
abstract class LiveRepository {
  /// ライブと、その公演・受付をまとめて新規作成し、保存したものを返す。
  ///
  /// - 公演・受付の `liveId`・`groupIds`・`oshiIds` は、ここでライブの値を付ける
  ///   （DB 設計案 5章「複製した項目の整合」）
  /// - 作成者・更新者は [uid]、作成日時・更新日時はサーバー時刻
  /// - 1つのバッチで書くため、途中で失敗したら何も保存されない
  Future<SavedLive> create({
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
  Future<SavedLive> create({
    required Live live,
    required List<Performance> performances,
    required List<Reception> receptions,
    required String uid,
  }) async {
    final batch = _db.batch();
    final liveRef = _db.collection('lives').doc();

    // 書き込む前に ID を決め、ID 付きの形を作っておく
    final saved = (
      live: live.copyWithId(liveRef.id),
      performances: [
        for (final p in performances)
          p.copyWithIds(
            id: _db.collection('performances').doc().id,
            liveId: liveRef.id,
            groupIds: live.groupIds,
            oshiIds: live.oshiIds,
          ),
      ],
      receptions: [
        for (final r in receptions)
          r.copyWithIds(
            id: _db.collection('receptions').doc().id,
            liveId: liveRef.id,
            groupIds: live.groupIds,
            oshiIds: live.oshiIds,
          ),
      ],
    );

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
    for (final p in saved.performances) {
      batch.set(
        _db.collection('performances').doc(p.id),
        {...p.toFirestore(), ...copied, ...meta},
      );
    }
    for (final r in saved.receptions) {
      batch.set(
        _db.collection('receptions').doc(r.id),
        {...r.toFirestore(), ...copied, ...meta},
      );
    }

    await batch.commit();
    return saved;
  }
}