import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/history_entry.dart';
import '../models/live.dart';
import '../models/oshi.dart';
import '../models/performance.dart';
import '../models/reception.dart';
import '../utils/live_diff.dart';

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

/// 保存したライブ・公演・受付（ID と複製項目を付けたもの）
typedef SavedLive = ({
  Live live,
  List<Performance> performances,
  List<Reception> receptions,
});

/// 既存のライブ一式（照合・差分の確認・編集用。Step4）
@immutable
class ExistingLive {
  const ExistingLive({
    required this.live,
    required this.performances,
    required this.receptions,
    this.versions = const {},
  });

  /// ID 付き
  final Live live;

  /// 開演日時の順
  final List<Performance> performances;

  /// 申込期限の順
  final List<Reception> receptions;

  /// ドキュメントのパス（例: `lives/abc`・`performances/def`）→ 読んだときの
  /// `updatedAt`（Firestore の値のまま。欠けていれば null）。
  /// [LiveRepository.applyMerge] が同時更新の検出に使う
  final Map<String, Object?> versions;

  /// 最初の公演（開演日時が最も早いもの）。無ければ null
  Performance? get firstPerformance =>
      performances.isEmpty ? null : performances.first;
}

/// 読んだ後に、ほかの人がドキュメントを更新していた（何も書いていない）。
///
/// [LiveRepository.applyMerge] では「ほかの人が先に更新しました」、
/// [LiveRepository.revert] では「その後に別の変更があります」と知らせる。
class LiveConflictException implements Exception {
  const LiveConflictException(this.paths);

  /// 変わっていた（または消えていた）ドキュメントのパス
  final List<String> paths;

  @override
  String toString() => 'LiveConflictException($paths)';
}

/// ライブ・公演・受付（共通データ）
abstract class LiveRepository {
  /// ライブ1件・公演・受付を1つの WriteBatch で新規作成し、ID と複製項目を
  /// 付けたもの（[SavedLive]）を返す（照合・更新は Step4）。
  /// 戻り値は、保存後に Google カレンダーへ予定を追加するときに使う。
  ///
  /// - ID は自動 ID。公演・受付には `liveId` と、ライブと同じ `groupIds`・
  ///   `oshiIds` を入れる（引数の Performance・Reception の id・liveId・
  ///   groupIds・oshiIds は無視する）
  /// - 3つとも `createdBy`・`updatedBy` に [uid]、`createdAt`・`updatedAt` に
  ///   サーバー時刻を入れる
  /// - 同じバッチで `users/{uid}/myLives/{liveId}` も作る（自分のライブ一覧に入る）
  /// - 失敗したら Firestore の例外をそのまま投げる（何も作られない）
  Future<SavedLive> create({
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

  /// ID を指定してライブを購読する（順序は不定。30件ずつ分割。読めないものは
  /// 飛ばす。空なら問い合わせず、空のリストを1回流す）
  Stream<List<Live>> watchLivesByIds(Set<String> liveIds);

  /// 指定したライブの公演（`liveId` の whereIn、30件ずつ分割。順序は不定）
  Stream<List<Performance>> watchPerformancesOfLives(Set<String> liveIds);

  /// 指定したライブの受付（[watchPerformancesOfLives] と同じ規則）
  Stream<List<Reception>> watchReceptionsOfLives(Set<String> liveIds);

  /// ライブ1件。無い・読めないときは null
  Stream<Live?> watchLive(String liveId);

  /// そのライブの公演（開演日時の順）。読めないドキュメントは飛ばす
  Stream<List<Performance>> watchPerformancesOf(String liveId);

  /// そのライブの受付（申込期限の順）。読めないドキュメントは飛ばす
  Stream<List<Reception>> watchReceptionsOf(String liveId);

  // ---- Step4: 照合・更新・変更履歴 ----

  /// 出演者（[groupIds]・[oshiIds]）が1つでも重なるライブ一式を1回だけ読む
  /// （候補探し用。順序は不定）。両方空なら読まずに空のリスト。
  /// 30件を超える ID は分割する。読めないドキュメントは飛ばす。
  Future<List<ExistingLive>> fetchCandidates({
    required List<String> groupIds,
    required List<String> oshiIds,
  });

  /// ライブ1件の一式を読む（編集・差分の確認のやり直し用）。無い・読めないなら null
  Future<ExistingLive?> fetchExisting(String liveId);

  /// 差分（[plan]。`withoutUnselected` を通したもの）を1つのトランザクションで
  /// 反映する。
  ///
  /// - ドキュメント ID は変えない（既存は update、追加は自動 ID で set）
  /// - ライブ本体は必ず読み直し、`updatedBy`・`updatedAt` を必ず書き直す。
  ///   変更する公演・受付も読み直す。`plan.base.versions` の `updatedAt` と
  ///   違っていたら（消えていたら）[LiveConflictException] を投げ、何も書かない
  /// - 変わった項目ごとに `history` を1件作る（ライブ・公演・受付それぞれ）。
  ///   追加した公演・受付には履歴を作らない
  /// - ライブの出演者が増えたら、そのライブの公演・受付すべての `groupIds`・
  ///   `oshiIds` をライブと同じにする（この同期には履歴を作らない）。
  ///   変更する公演・受付には、出演者が変わらなくても常にライブと同じ値を書く
  /// - 戻り値: live は反映後のライブ、performances・receptions は
  ///   追加・変更したものだけ（反映後の値・ID 付き）。カレンダー追加シート用
  /// - 同じトランザクションで、そのライブを自分のライブ一覧
  ///   （`users/{uid}/myLives/{liveId}`）に追加する。既に入っていれば
  ///   `addedAt` を変えない
  /// - `plan.isEmpty` なら何も書かず、[ArgumentError] を投げる
  Future<SavedLive> applyMerge(LiveMergePlan plan, {required String uid});

  /// ドキュメント1件の変更履歴（新しい順。changedAt が未確定のものは先頭）。
  /// 読めない履歴は飛ばさず、欠けた項目を空にして流す
  Stream<List<HistoryEntry>> watchHistory(HistoryTarget target);

  /// そのライブ本体と、その公演・受付の作成日時・更新日時（ライブ詳細の
  /// 「追加」の判定用。順序は不定）
  Stream<List<DocStamp>> watchDocStamps(String liveId);

  /// 履歴1件を元に戻す（トランザクション）。
  ///
  /// - 対象の項目の今の値が [HistoryEntry.after] と同じとき（`hasAfter` が
  ///   false なら項目が無いとき）だけ、[HistoryEntry.before] に戻す
  ///   （`hasBefore` が false なら項目を消す）。違えば [LiveConflictException]
  /// - 戻す操作も「変更」として履歴を1件作る（before = 今の値、after = 戻した値）
  /// - `canRevert(entry)` が false の履歴（出演者など）は [ArgumentError]
  Future<void> revert(HistoryEntry entry, {required String uid});
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
  Future<SavedLive> create({
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

    // 書き込む前に ID を決め、ID 付きの形を作っておく
    final saved = (
      live: live.copyWithId(liveRef.id),
      performances: [
        for (final p in performances)
          p.copyWithIds(
            id: _performances.doc().id,
            liveId: liveRef.id,
            groupIds: live.groupIds,
            oshiIds: live.oshiIds,
          ),
      ],
      receptions: [
        for (final r in receptions)
          r.copyWithIds(
            id: _receptions.doc().id,
            liveId: liveRef.id,
            groupIds: live.groupIds,
            oshiIds: live.oshiIds,
          ),
      ],
    );

    final batch = _db.batch();
    batch.set(liveRef, {...live.toFirestore(), ...performers, ...audit});
    for (final p in saved.performances) {
      batch.set(_performances.doc(p.id), {...p.toFirestore(), ...child});
    }
    for (final r in saved.receptions) {
      batch.set(_receptions.doc(r.id), {...r.toFirestore(), ...child});
    }
    // 自分のライブ一覧にも入れる（同じバッチ。ルールの existsAfter が見る）
    batch.set(_myLives(uid).doc(liveRef.id), {
      'addedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return saved;
  }

  CollectionReference<Map<String, dynamic>> _myLives(String uid) =>
      _db.collection('users').doc(uid).collection('myLives');

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
  Stream<List<Live>> watchLivesByIds(Set<String> liveIds) {
    final queries = [
      for (final chunk in chunks(liveIds, queryChunkSize))
        _lives.where(FieldPath.documentId, whereIn: chunk),
    ];
    if (queries.isEmpty) return Stream.value(const []);
    return _mergeQueries(queries, Live.fromFirestore);
  }

  @override
  Stream<List<Performance>> watchPerformancesOfLives(Set<String> liveIds) =>
      _watchByLiveIds(_performances, liveIds, Performance.fromFirestore);

  @override
  Stream<List<Reception>> watchReceptionsOfLives(Set<String> liveIds) =>
      _watchByLiveIds(_receptions, liveIds, Reception.fromFirestore);

  Stream<List<T>> _watchByLiveIds<T extends Object>(
    CollectionReference<Map<String, dynamic>> collection,
    Set<String> liveIds,
    T Function(DocumentSnapshot<Map<String, dynamic>>) parse,
  ) {
    final queries = [
      for (final chunk in chunks(liveIds, queryChunkSize))
        collection.where('liveId', whereIn: chunk),
    ];
    if (queries.isEmpty) return Stream.value(const []);
    return _mergeQueries(queries, parse);
  }

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

  @override
  Future<List<ExistingLive>> fetchCandidates({
    required List<String> groupIds,
    required List<String> oshiIds,
  }) async {
    final queries = [
      for (final chunk in chunks(groupIds.toSet(), queryChunkSize))
        _lives.where('groupIds', arrayContainsAny: chunk),
      for (final chunk in chunks(oshiIds.toSet(), queryChunkSize))
        _lives.where('oshiIds', arrayContainsAny: chunk),
    ];
    if (queries.isEmpty) return const [];
    final snaps = await Future.wait([for (final q in queries) q.get()]);
    final liveDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{
      for (final snap in snaps)
        for (final doc in snap.docs) doc.id: doc,
    };
    return _withChildren(liveDocs.values.toList());
  }

  @override
  Future<ExistingLive?> fetchExisting(String liveId) async {
    final doc = await _lives.doc(liveId).get();
    if (!doc.exists) return null;
    final found = await _withChildren([doc]);
    return found.firstOrNull;
  }

  /// ライブのドキュメントに、その公演・受付を読んで付ける（読めないライブは飛ばす）
  Future<List<ExistingLive>> _withChildren(
    List<DocumentSnapshot<Map<String, dynamic>>> liveDocs,
  ) async {
    final lives = <String, ({Live live, Object? version})>{};
    for (final doc in liveDocs) {
      final live = _tryParse(doc, Live.fromFirestore);
      if (live != null) {
        lives[doc.id] = (live: live, version: doc.data()?['updatedAt']);
      }
    }
    if (lives.isEmpty) return const [];

    final ids = lives.keys.toSet();
    final childSnaps = await Future.wait([
      for (final chunk in chunks(ids, queryChunkSize)) ...[
        _performances.where('liveId', whereIn: chunk).get(),
        _receptions.where('liveId', whereIn: chunk).get(),
      ],
    ]);
    final perfDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final recDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final (i, snap) in childSnaps.indexed) {
      (i.isEven ? perfDocs : recDocs).addAll(snap.docs);
    }

    final versions = <String, Map<String, Object?>>{
      for (final id in ids) id: {'lives/$id': lives[id]!.version},
    };
    final perfs = <String, List<Performance>>{};
    for (final doc in perfDocs) {
      final p = _tryParse(doc, Performance.fromFirestore);
      final liveId = p?.liveId;
      if (p == null || liveId == null || !ids.contains(liveId)) continue;
      perfs.putIfAbsent(liveId, () => []).add(p);
      versions[liveId]!['performances/${doc.id}'] = doc.data()['updatedAt'];
    }
    final recs = <String, List<Reception>>{};
    for (final doc in recDocs) {
      final r = _tryParse(doc, Reception.fromFirestore);
      final liveId = r?.liveId;
      if (r == null || liveId == null || !ids.contains(liveId)) continue;
      recs.putIfAbsent(liveId, () => []).add(r);
      versions[liveId]!['receptions/${doc.id}'] = doc.data()['updatedAt'];
    }

    return [
      for (final id in ids)
        ExistingLive(
          live: lives[id]!.live,
          performances: List.unmodifiable(
            (perfs[id] ?? [])..sort((a, b) => a.startAt.compareTo(b.startAt)),
          ),
          receptions: List.unmodifiable(
            (recs[id] ?? [])
              ..sort((a, b) => a.applyEndAt.compareTo(b.applyEndAt)),
          ),
          versions: Map.unmodifiable(versions[id]!),
        ),
    ];
  }

  @override
  Future<SavedLive> applyMerge(
    LiveMergePlan plan, {
    required String uid,
  }) async {
    if (plan.isEmpty) throw ArgumentError('反映する変更がありません');
    final base = plan.base;
    final liveId = base.live.id;
    if (liveId == null) throw ArgumentError('既存のライブに ID がありません');

    final merged = plan.mergedLive;
    final performersChanged = plan.liveChanges.any(
      (c) => c.field == 'groupIds' || c.field == 'oshiIds',
    );
    final performers = <String, dynamic>{
      'groupIds': List<String>.of(merged.groupIds),
      'oshiIds': List<String>.of(merged.oshiIds),
    };

    // 書き込む前に ID を決め、戻り値の形を作っておく
    final saved = (
      live: liveWithChanges(base.live, plan.liveChanges),
      performances: [
        for (final d in plan.changedPerformances)
          d.merged.copyWithIds(
            id: d.existing.id!,
            liveId: liveId,
            groupIds: merged.groupIds,
            oshiIds: merged.oshiIds,
          ),
        for (final a in plan.addedPerformances)
          a.doc.copyWithIds(
            id: _performances.doc().id,
            liveId: liveId,
            groupIds: merged.groupIds,
            oshiIds: merged.oshiIds,
          ),
      ],
      receptions: [
        for (final d in plan.changedReceptions)
          d.merged.copyWithIds(
            id: d.existing.id!,
            liveId: liveId,
            groupIds: merged.groupIds,
            oshiIds: merged.oshiIds,
          ),
        for (final a in plan.addedReceptions)
          a.doc.copyWithIds(
            id: _receptions.doc().id,
            liveId: liveId,
            groupIds: merged.groupIds,
            oshiIds: merged.oshiIds,
          ),
      ],
    );

    // 同時更新を確かめるドキュメント: ライブ本体（必ず）と、変更する公演・受付
    final checked = <String>[
      'lives/$liveId',
      for (final d in plan.changedPerformances) 'performances/${d.existing.id}',
      for (final d in plan.changedReceptions) 'receptions/${d.existing.id}',
    ];

    final conflicts = await _db.runTransaction<List<String>>((tx) async {
      // 読み取り（書き込みより先に、すべて読む）
      final snaps = await Future.wait([
        for (final path in checked) tx.get(_db.doc(path)),
      ]);
      final myLiveRef = _myLives(uid).doc(liveId);
      final alreadyMine = (await tx.get(myLiveRef)).exists;
      final changed = <String>[
        for (final (i, snap) in snaps.indexed)
          if (!snap.exists ||
              !firestoreValueEquals(
                snap.data()?['updatedAt'],
                base.versions[checked[i]],
              ))
            checked[i],
      ];
      if (changed.isNotEmpty) return changed;

      final now = FieldValue.serverTimestamp();
      final audit = <String, dynamic>{'updatedBy': uid, 'updatedAt': now};

      void writeChanges(
        DocumentReference<Map<String, dynamic>> ref,
        List<FieldChange> changes, {
        bool syncPerformers = false,
        Map<String, dynamic> extra = const {},
      }) {
        tx.update(ref, {
          for (final c in changes)
            c.field: c.hasAfter ? c.after : FieldValue.delete(),
          if (syncPerformers) ...performers,
          ...extra,
          ...audit,
        });
        for (final c in changes) {
          tx.set(ref.collection('history').doc(), {
            'field': c.field,
            if (c.hasBefore) 'before': c.before,
            if (c.hasAfter) 'after': c.after,
            'changedBy': uid,
            'changedAt': now,
          });
        }
      }

      // ライブ本体: 項目が変わらなくても updatedBy・updatedAt は必ず書く
      writeChanges(_lives.doc(liveId), plan.liveChanges);

      final changedPerfIds = {
        for (final d in plan.changedPerformances) d.existing.id,
      };
      final changedRecIds = {
        for (final d in plan.changedReceptions) d.existing.id,
      };
      for (final d in plan.changedPerformances) {
        // 出演者は常にライブ（反映後）と同じにする。ルールの外で書かれた
        // ずれたデータも、次の変更で直るように（qa の D4 レビュー）
        writeChanges(
          _performances.doc(d.existing.id),
          d.changes,
          syncPerformers: true,
          // 開演日時を変えたら「時間未定」の印を外す（add_L L-4c-2）
          extra: {
            if (d.changes.any((c) => c.field == 'startAt'))
              'startTimeUnknown': FieldValue.delete(),
          },
        );
      }
      for (final d in plan.changedReceptions) {
        writeChanges(
          _receptions.doc(d.existing.id),
          d.changes,
          syncPerformers: true,
        );
      }
      // 出演者が増えたら、変更の無い公演・受付の複製項目もそろえる（履歴なし）
      if (performersChanged) {
        for (final p in base.performances) {
          if (changedPerfIds.contains(p.id)) continue;
          tx.update(_performances.doc(p.id), {...performers, ...audit});
        }
        for (final r in base.receptions) {
          if (changedRecIds.contains(r.id)) continue;
          tx.update(_receptions.doc(r.id), {...performers, ...audit});
        }
      }

      final create = <String, dynamic>{
        'liveId': liveId,
        ...performers,
        'createdBy': uid,
        'createdAt': now,
        ...audit,
      };
      final added = plan.changedPerformances.length;
      for (final p in saved.performances.skip(added)) {
        tx.set(_performances.doc(p.id), {...p.toFirestore(), ...create});
      }
      final addedR = plan.changedReceptions.length;
      for (final r in saved.receptions.skip(addedR)) {
        tx.set(_receptions.doc(r.id), {...r.toFirestore(), ...create});
      }
      // 自分のライブ一覧に追加する（既にあれば addedAt を変えない）
      if (!alreadyMine) {
        tx.set(myLiveRef, {'addedAt': FieldValue.serverTimestamp()});
      }
      return const [];
    });

    if (conflicts.isNotEmpty) throw LiveConflictException(conflicts);
    return saved;
  }

  @override
  Stream<List<HistoryEntry>> watchHistory(HistoryTarget target) => _db
      .collection(target.collection.name)
      .doc(target.docId)
      .collection('history')
      .snapshots()
      .map(
        (snap) => [
          for (final doc in snap.docs) HistoryEntry.fromFirestore(target, doc),
        ]..sort(_historyNewestFirst),
      );

  @override
  Stream<List<DocStamp>> watchDocStamps(String liveId) {
    DocStamp stamp(
      HistoryCollection c,
      DocumentSnapshot<Map<String, dynamic>> doc,
    ) {
      final data = doc.data() ?? const <String, dynamic>{};
      return DocStamp(
        target: HistoryTarget(c, doc.id),
        createdAt: _timestampToDate(data['createdAt']),
        updatedAt: _timestampToDate(data['updatedAt']),
      );
    }

    return _combineLatest<DocStamp>([
      _lives
          .doc(liveId)
          .snapshots()
          .map((doc) => [if (doc.exists) stamp(HistoryCollection.lives, doc)]),
      _performances
          .where('liveId', isEqualTo: liveId)
          .snapshots()
          .map(
            (snap) => [
              for (final doc in snap.docs)
                stamp(HistoryCollection.performances, doc),
            ],
          ),
      _receptions
          .where('liveId', isEqualTo: liveId)
          .snapshots()
          .map(
            (snap) => [
              for (final doc in snap.docs)
                stamp(HistoryCollection.receptions, doc),
            ],
          ),
    ]);
  }

  @override
  Future<void> revert(HistoryEntry entry, {required String uid}) async {
    if (!canRevert(entry)) {
      throw ArgumentError('この変更は元に戻せません（${entry.field}）');
    }
    final ref = _db.doc(entry.target.path);
    final field = entry.field;
    final conflict = await _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return true;
      final data = snap.data() ?? const <String, dynamic>{};
      final hasCurrent = data.containsKey(field) && data[field] != null;
      final current = data[field];
      final same = entry.hasAfter
          ? hasCurrent && firestoreValueEquals(current, entry.after)
          : !hasCurrent;
      if (!same) return true;

      final now = FieldValue.serverTimestamp();
      tx.update(ref, {
        field: entry.hasBefore ? entry.before : FieldValue.delete(),
        'updatedBy': uid,
        'updatedAt': now,
      });
      tx.set(ref.collection('history').doc(), {
        'field': field,
        if (hasCurrent) 'before': current,
        if (entry.hasBefore) 'after': entry.before,
        'changedBy': uid,
        'changedAt': now,
      });
      return false;
    });
    if (conflict) throw LiveConflictException([entry.target.path]);
  }

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

/// 履歴を新しい順に並べる（changedAt が未確定のものは先頭。同じなら ID の順）
int _historyNewestFirst(HistoryEntry a, HistoryEntry b) {
  final at = a.changedAt, bt = b.changedAt;
  if (at == null && bt != null) return -1;
  if (at != null && bt == null) return 1;
  if (at != null && bt != null) {
    final c = bt.compareTo(at);
    if (c != 0) return c;
  }
  return a.id.compareTo(b.id);
}

DateTime? _timestampToDate(Object? v) => v is Timestamp ? v.toDate() : null;

/// 複数のストリームの最新の値をつなげて流す。すべてが1回ずつ値を流してから、
/// 最初の値を流す。どれかがエラーになったら、エラーを1回流して閉じる
Stream<List<T>> _combineLatest<T>(List<Stream<List<T>>> streams) {
  late final StreamController<List<T>> controller;
  final subscriptions = <StreamSubscription<List<T>>>[];
  final latest = List<List<T>?>.filled(streams.length, null);
  var failed = false;

  Future<void> cancelAll() async {
    final subs = [...subscriptions];
    subscriptions.clear();
    await Future.wait([for (final s in subs) s.cancel()]);
  }

  controller = StreamController<List<T>>(
    onListen: () {
      for (final (i, stream) in streams.indexed) {
        subscriptions.add(
          stream.listen(
            (value) {
              if (failed) return;
              latest[i] = value;
              if (latest.any((v) => v == null)) return;
              controller.add([for (final v in latest) ...v!]);
            },
            onError: (Object error, StackTrace stackTrace) {
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
