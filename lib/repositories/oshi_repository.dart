import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/oshi.dart';
import '../utils/oshi_search.dart';

/// 推し（`groups`・`oshis`）の読み取りと追加申請
abstract class OshiRepository {
  /// `groups` と `oshis`（承認済み＋申請中）をまとめて購読する。
  ///
  /// 並び順は決めない（画面では [searchOshis] で並べる）。
  /// 読めないドキュメント（名前が空・status が不明）は含めない。
  Stream<List<OshiSummary>> watchAll();

  /// 申請を `status: pending` で作成し、作成したドキュメントの ID を返す。
  ///
  /// - [OshiRequest.validate] に通らなければ [OshiRequestException]
  /// - 同じ種別に完全一致する推し（申請中を含む）があれば [OshiDuplicateException]
  /// - 所属グループに、存在しない・承認されていないグループがあれば
  ///   [OshiRequestException]
  Future<String> request(OshiRequest request, {required String uid});

  /// グループと、そのメンバー（個人）を、1回のバッチで `status: pending` で作成し、
  /// グループの ID を返す（Fb-3。メンバーのいないグループを作らせないため）。
  ///
  /// - [group] がグループでない、または [OshiRequest.validate] に通らなければ
  ///   [OshiRequestException]
  /// - メンバーの名前が [validateMemberNames] に通らなければ [OshiRequestException]
  /// - 同じ名前のグループ（申請中を含む）があれば [OshiDuplicateException]
  /// - メンバーは、ジャンルをグループと同じにし、所属を新しいグループだけにする
  Future<String> requestGroupWithMembers(
    OshiRequest group,
    List<String> memberNames, {
    required String uid,
  });
}

/// Firestore 版の [OshiRepository]
class FirestoreOshiRepository implements OshiRepository {
  FirestoreOshiRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(OshiKind kind) =>
      _db.collection(kind.collection);

  List<OshiSummary> _parse(
    OshiKind kind,
    QuerySnapshot<Map<String, dynamic>> snap,
  ) => [
    for (final doc in snap.docs)
      ?OshiSummary.fromFirestore(kind, doc.id, doc.data()),
  ];

  /// どちらかの購読でエラーが起きたら、エラーを1回流し、もう一方の購読も
  /// 解除してストリームを閉じる（Firestore の購読はエラーの後は続かないため）。
  /// 再購読は呼び出し側（プロバイダの作り直し）で行う。
  @override
  Stream<List<OshiSummary>> watchAll() {
    late StreamController<List<OshiSummary>> controller;
    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    List<OshiSummary>? groups;
    List<OshiSummary>? persons;

    Future<void> cancelAll() async {
      final pending = [for (final s in subs) s.cancel()];
      subs.clear();
      await Future.wait(pending);
    }

    void emit() {
      final g = groups;
      final p = persons;
      if (g != null && p != null && !controller.isClosed) {
        controller.add([...g, ...p]);
      }
    }

    void onError(Object error, StackTrace stackTrace) {
      if (controller.isClosed) return;
      controller.addError(error, stackTrace);
      cancelAll();
      controller.close();
    }

    controller = StreamController<List<OshiSummary>>(
      onListen: () {
        subs.add(
          _col(OshiKind.group).snapshots().listen((snap) {
            groups = _parse(OshiKind.group, snap);
            emit();
          }, onError: onError),
        );
        subs.add(
          _col(OshiKind.person).snapshots().listen((snap) {
            persons = _parse(OshiKind.person, snap);
            emit();
          }, onError: onError),
        );
      },
      onPause: () {
        for (final s in subs) {
          s.pause();
        }
      },
      onResume: () {
        for (final s in subs) {
          s.resume();
        }
      },
      onCancel: cancelAll,
    );
    return controller.stream;
  }

  @override
  Future<String> request(OshiRequest request, {required String uid}) async {
    final errors = request.validate();
    if (errors.isNotEmpty) {
      throw OshiRequestException(errors.values.toList());
    }

    final sameKind = _parse(request.kind, await _col(request.kind).get());
    final duplicates = findExactDuplicates(
      sameKind,
      kind: request.kind,
      name: request.trimmedName,
      aliases: request.cleanedAliases,
    );
    if (duplicates.isNotEmpty) throw OshiDuplicateException(duplicates);

    final groupIds = request.cleanedGroupIds;
    if (request.kind == OshiKind.person && groupIds.isNotEmpty) {
      final approvedGroupIds = {
        for (final g in _parse(
          OshiKind.group,
          await _col(OshiKind.group).get(),
        ))
          if (g.isApproved) g.id,
      };
      if (!groupIds.every(approvedGroupIds.contains)) {
        throw const OshiRequestException(['所属グループが見つかりません。選び直してください']);
      }
    }

    final ref = _col(request.kind).doc();
    await ref.set(request.toFirestore(uid));
    return ref.id;
  }

  @override
  Future<String> requestGroupWithMembers(
    OshiRequest group,
    List<String> memberNames, {
    required String uid,
  }) async {
    if (group.kind != OshiKind.group) {
      throw const OshiRequestException(['グループの申請ではありません']);
    }
    final errors = group.validate();
    if (errors.isNotEmpty) {
      throw OshiRequestException(errors.values.toList());
    }
    final names = cleanMemberNames(memberNames);
    final memberError = validateMemberNames(names);
    if (memberError != null) throw OshiRequestException([memberError]);

    final groups = _parse(OshiKind.group, await _col(OshiKind.group).get());
    final duplicates = findExactDuplicates(
      groups,
      kind: OshiKind.group,
      name: group.trimmedName,
      aliases: group.cleanedAliases,
    );
    if (duplicates.isNotEmpty) throw OshiDuplicateException(duplicates);

    // グループとメンバーを1回で書く（途中で失敗しても、メンバーのいないグループが残らない）
    final batch = _db.batch();
    final groupRef = _col(OshiKind.group).doc();
    batch.set(groupRef, group.toFirestore(uid));
    for (final name in names) {
      final member = OshiRequest(
        kind: OshiKind.person,
        name: name,
        genre: group.genre,
        groupIds: [groupRef.id],
      );
      batch.set(_col(OshiKind.person).doc(), member.toFirestore(uid));
    }
    await batch.commit();
    return groupRef.id;
  }
}
