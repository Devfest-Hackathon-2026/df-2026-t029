import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/live.dart';
import '../models/oshi.dart';
import '../models/performance.dart';
import '../models/reception.dart';

/// 一覧の対象（計画書 3.2）
///
/// - [groupIds]: フォロー中のグループ ＋ フォロー中の推しの所属グループ
///   （`groupIds` の array-contains-any に使う）
/// - [oshiIds]: フォロー中の推し（個人）（`oshiIds` の array-contains-any に使う）
@immutable
class FollowTargets {
  const FollowTargets({this.groupIds = const {}, this.oshiIds = const {}});

  static const empty = FollowTargets();

  /// フォロー中の推し（承認済み。`followingOshisProvider` の値）から作る
  factory FollowTargets.fromFollowing(List<OshiSummary> following) {
    final groupIds = <String>{};
    final oshiIds = <String>{};
    for (final o in following) {
      switch (o.kind) {
        case OshiKind.group:
          groupIds.add(o.id);
        case OshiKind.person:
          oshiIds.add(o.id);
          groupIds.addAll(o.groupIds);
      }
    }
    return FollowTargets(
      groupIds: Set.unmodifiable(groupIds),
      oshiIds: Set.unmodifiable(oshiIds),
    );
  }

  final Set<String> groupIds;
  final Set<String> oshiIds;

  /// 両方とも空なら問い合わせない
  bool get isEmpty => groupIds.isEmpty && oshiIds.isEmpty;

  /// 中身（ID の集合）で比べる。順序は問わない
  @override
  bool operator ==(Object other) =>
      other is FollowTargets &&
      setEquals(other.groupIds, groupIds) &&
      setEquals(other.oshiIds, oshiIds);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(groupIds),
    Object.hashAllUnordered(oshiIds),
  );

  @override
  String toString() => 'FollowTargets(groups: $groupIds, oshis: $oshiIds)';
}

/// ライブ・公演・受付（共通データ）
abstract class LiveRepository {
  /// ライブ1件・公演・受付を1つの WriteBatch で新規作成し、ライブの ID を返す
  /// （照合・更新は Step4）。
  ///
  /// - ID は自動 ID。公演・受付には `liveId` と、ライブと同じ `groupIds`・
  ///   `oshiIds` を入れる（引数の Performance・Reception の id・liveId・
  ///   groupIds・oshiIds は無視する）
  /// - 3つとも `createdBy`・`updatedBy` に [uid]、`createdAt`・`updatedAt` に
  ///   サーバー時刻を入れる
  /// - 失敗したら Firestore の例外をそのまま投げる（何も作られない）
  Future<String> create({
    required Live live,
    required List<Performance> performances,
    required List<Reception> receptions,
    required String uid,
  });

  /// [targets] に当たるライブ（ID で重複を除く。順序は不定）。
  /// [targets] が空なら問い合わせず、空のリストを1回流す。
  /// 30件を超える ID は分割して問い合わせ、結果をまとめる。
  /// 読めないドキュメントは飛ばす（計画書 3.7）。
  Stream<List<Live>> watchLives(FollowTargets targets);

  /// [targets] に当たる公演（watchLives と同じ規則）
  Stream<List<Performance>> watchPerformances(FollowTargets targets);

  /// [targets] に当たる受付（watchLives と同じ規則）
  Stream<List<Reception>> watchReceptions(FollowTargets targets);

  /// ライブ1件。無い・読めないときは null
  Stream<Live?> watchLive(String liveId);

  /// そのライブの公演（開演日時の順）。読めないドキュメントは飛ばす
  Stream<List<Performance>> watchPerformancesOf(String liveId);

  /// そのライブの受付（申込期限の順）。読めないドキュメントは飛ばす
  Stream<List<Reception>> watchReceptionsOf(String liveId);
}

/// Firestore 版の [LiveRepository]
class FirestoreLiveRepository implements LiveRepository {
  FirestoreLiveRepository(this._db);

  final FirebaseFirestore _db;

  /// array-contains-any に1回で渡せる値の数
  static const int queryChunkSize = 30;

  CollectionReference<Map<String, dynamic>> get _lives =>
      _db.collection('lives');
  CollectionReference<Map<String, dynamic>> get _performances =>
      _db.collection('performances');
  CollectionReference<Map<String, dynamic>> get _receptions =>
      _db.collection('receptions');

  @override
  Future<String> create({
    required Live live,
    required List<Performance> performances,
    required List<Reception> receptions,
    required String uid,
  }) async {
    final liveRef = _lives.doc();
    final now = FieldValue.serverTimestamp();
    final audit = <String, dynamic>{
      'createdBy': uid,
      'createdAt': now,
      'updatedBy': uid,
      'updatedAt': now,
    };
    final performers = <String, dynamic>{
      'groupIds': List<String>.of(live.groupIds),
      'oshiIds': List<String>.of(live.oshiIds),
    };
    final child = <String, dynamic>{
      'liveId': liveRef.id,
      ...performers,
      ...audit,
    };

    final batch = _db.batch();
    batch.set(liveRef, {...live.toFirestore(), ...performers, ...audit});
    for (final p in performances) {
      batch.set(_performances.doc(), {...p.toFirestore(), ...child});
    }
    for (final r in receptions) {
      batch.set(_receptions.doc(), {...r.toFirestore(), ...child});
    }
    await batch.commit();
    return liveRef.id;
  }

  @override
  Stream<List<Live>> watchLives(FollowTargets targets) =>
      _watchTargets(_lives, targets, Live.fromFirestore);

  @override
  Stream<List<Performance>> watchPerformances(FollowTargets targets) =>
      _watchTargets(_performances, targets, Performance.fromFirestore);

  @override
  Stream<List<Reception>> watchReceptions(FollowTargets targets) =>
      _watchTargets(_receptions, targets, Reception.fromFirestore);

  @override
  Stream<Live?> watchLive(String liveId) => _lives
      .doc(liveId)
      .snapshots()
      .map((snap) => snap.exists ? _tryParse(snap, Live.fromFirestore) : null);

  @override
  Stream<List<Performance>> watchPerformancesOf(String liveId) => _performances
      .where('liveId', isEqualTo: liveId)
      .snapshots()
      .map(
        (snap) =>
            _parseAll(snap.docs, Performance.fromFirestore)
              ..sort((a, b) => a.startAt.compareTo(b.startAt)),
      );

  @override
  Stream<List<Reception>> watchReceptionsOf(String liveId) => _receptions
      .where('liveId', isEqualTo: liveId)
      .snapshots()
      .map(
        (snap) =>
            _parseAll(snap.docs, Reception.fromFirestore)
              ..sort((a, b) => a.applyEndAt.compareTo(b.applyEndAt)),
      );

  /// groupIds・oshiIds を30件ずつに分けて購読し、まとめて流す。
  /// すべてのクエリが1回ずつ値を流してから、最初の値を流す。
  Stream<List<T>> _watchTargets<T extends Object>(
    CollectionReference<Map<String, dynamic>> collection,
    FollowTargets targets,
    T Function(DocumentSnapshot<Map<String, dynamic>>) parse,
  ) {
    final queries = [
      for (final chunk in chunks(targets.groupIds, queryChunkSize))
        collection.where('groupIds', arrayContainsAny: chunk),
      for (final chunk in chunks(targets.oshiIds, queryChunkSize))
        collection.where('oshiIds', arrayContainsAny: chunk),
    ];
    if (queries.isEmpty) return Stream.value(const []);
    return _mergeQueries(queries, parse);
  }
}

/// [ids] を [size] 件ずつに分ける（順序は ID の順）
@visibleForTesting
List<List<String>> chunks(Set<String> ids, int size) {
  final sorted = ids.toList()..sort();
  return [
    for (var i = 0; i < sorted.length; i += size)
      sorted.sublist(i, i + size > sorted.length ? sorted.length : i + size),
  ];
}

/// 複数のクエリを購読し、ドキュメント ID で重複を除いてまとめる。
/// どれかのクエリがエラーになったら、エラーを1回流して閉じる（2つ目以降は無視）
Stream<List<T>> _mergeQueries<T extends Object>(
  List<Query<Map<String, dynamic>>> queries,
  T Function(DocumentSnapshot<Map<String, dynamic>>) parse,
) {
  late final StreamController<List<T>> controller;
  final subscriptions =
      <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
  final latest =
      List<List<QueryDocumentSnapshot<Map<String, dynamic>>>?>.filled(
        queries.length,
        null,
      );

  void emit() {
    if (latest.any((docs) => docs == null)) return;
    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
      for (final docs in latest)
        for (final doc in docs!) doc.id: doc,
    };
    controller.add(_parseAll(byId.values, parse));
  }

  var failed = false;

  Future<void> cancelAll() async {
    final subs = [...subscriptions];
    subscriptions.clear();
    await Future.wait([for (final s in subs) s.cancel()]);
  }

  controller = StreamController<List<T>>(
    onListen: () {
      for (final (i, query) in queries.indexed) {
        subscriptions.add(
          query.snapshots().listen(
            (snap) {
              if (failed) return;
              latest[i] = snap.docs;
              emit();
            },
            onError: (Object error, StackTrace stackTrace) {
              // Step1 の watchAll と同じ: エラーを1回だけ流し、すべての購読を
              // 解除して閉じる（残りのクエリの古い結果を流し続けないため）
              if (failed) return;
              failed = true;
              controller.addError(error, stackTrace);
              cancelAll().whenComplete(controller.close);
            },
          ),
        );
      }
    },
    onPause: () {
      for (final s in subscriptions) {
        s.pause();
      }
    },
    onResume: () {
      for (final s in subscriptions) {
        s.resume();
      }
    },
    onCancel: cancelAll,
  );
  return controller.stream;
}

/// 1件ずつ読み、読めないドキュメントは記録して飛ばす（計画書 3.7）
List<T> _parseAll<T extends Object>(
  Iterable<DocumentSnapshot<Map<String, dynamic>>> docs,
  T Function(DocumentSnapshot<Map<String, dynamic>>) parse,
) => [for (final doc in docs) ?_tryParse(doc, parse)];

T? _tryParse<T extends Object>(
  DocumentSnapshot<Map<String, dynamic>> doc,
  T Function(DocumentSnapshot<Map<String, dynamic>>) parse,
) {
  try {
    return parse(doc);
  } catch (e) {
    debugPrint('読めないドキュメントを飛ばしました: ${doc.reference.path}（$e）');
    return null;
  }
}
