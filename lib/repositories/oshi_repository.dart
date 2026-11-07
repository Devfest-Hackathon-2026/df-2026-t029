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
}
