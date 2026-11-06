import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/goods.dart';

/// グッズ（共通データ）の取得・保存
abstract class GoodsRepository {
  /// 対象の推しのグッズを取得する（名前順）。
  ///
  /// - [groupIds] を `groupIds` に、[oshiIds] を `oshiIds` に含むグッズをまとめて返す
  /// - それぞれ30個まで（Firestore の `array-contains-any` の上限）
  Future<List<Goods>> fetchFor({
    List<String> groupIds = const [],
    List<String> oshiIds = const [],
  });

  /// ID でグッズを1件取得する。見つからなければ null
  Future<Goods?> fetch(String id);

  /// グッズを新規作成し、ID を返す。
  ///
  /// - 作成者・更新者は [uid]、作成日時・更新日時はサーバー時刻
  Future<String> create(Goods goods, {required String uid});

  /// グッズを更新し、変わった項目ごとに変更履歴を残す（DB 設計案 3.6）。
  ///
  /// - [before] は読み込んだときの値（ID 付き）、[after] は変更後の値
  /// - 更新者は [uid]、更新日時はサーバー時刻。作成者・作成日時は変えない
  /// - 1つのバッチで書くため、途中で失敗したら何も保存されない
  /// - 変わった項目がなければ何もしない
  Future<void> update({
    required Goods before,
    required Goods after,
    required String uid,
  });
}

/// Firestore 版の [GoodsRepository]
class FirestoreGoodsRepository implements GoodsRepository {
  FirestoreGoodsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _goods =>
      _db.collection('goods');

  @override
  Future<List<Goods>> fetchFor({
    List<String> groupIds = const [],
    List<String> oshiIds = const [],
  }) async {
    final snapshots = await Future.wait([
      if (groupIds.isNotEmpty)
        _goods.where('groupIds', arrayContainsAny: groupIds).get(),
      if (oshiIds.isNotEmpty)
        _goods.where('oshiIds', arrayContainsAny: oshiIds).get(),
    ]);

    // 両方に当てはまるグッズが重ならないよう、ID でまとめる
    final byId = <String, Goods>{
      for (final snapshot in snapshots)
        for (final doc in snapshot.docs) doc.id: Goods.fromFirestore(doc),
    };
    return byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<Goods?> fetch(String id) async {
    final doc = await _goods.doc(id).get();
    return doc.exists ? Goods.fromFirestore(doc) : null;
  }

  @override
  Future<String> create(Goods goods, {required String uid}) async {
    final ref = _goods.doc();
    await ref.set({
      ...goods.toFirestore(),
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<void> update({
    required Goods before,
    required Goods after,
    required String uid,
  }) async {
    final id = before.id;
    if (id == null) throw ArgumentError('before に ID がありません');

    final oldData = before.toFirestore();
    final newData = after.toFirestore();
    final changedFields = {...oldData.keys, ...newData.keys}
        .where((f) => jsonEncode(oldData[f]) != jsonEncode(newData[f]))
        .toList();
    if (changedFields.isEmpty) return;

    final ref = _goods.doc(id);
    final batch = _db.batch();

    batch.update(ref, {
      for (final f in changedFields)
        f: newData.containsKey(f) ? newData[f] : FieldValue.delete(),
      'updatedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final f in changedFields) {
      batch.set(ref.collection('history').doc(), {
        'field': f,
        if (oldData.containsKey(f)) 'before': oldData[f],
        if (newData.containsKey(f)) 'after': newData[f],
        'changedBy': uid,
        'changedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}