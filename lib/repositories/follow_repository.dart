import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/oshi.dart';

/// 推しのフォロー（`users/{uid}` の `followingGroupIds`・`followingOshiIds`）
abstract class FollowRepository {
  /// フォロー状態を購読する。`users/{uid}` が無いときは [FollowState.empty]。
  Stream<FollowState> watch(String uid);

  /// フォローする。
  ///
  /// - 推しのドキュメントを読み直して確かめる。存在しなければ
  ///   `StateError('推しが見つかりません')`、承認済みでなければ
  ///   `StateError('申請中の推しはフォローできません')`
  /// - すでにフォロー中なら何もしない
  /// - 同じ種別の配列が [FollowState.maxFollows] 件に達していたら `StateError`
  ///   （上限は followingGroupIds・followingOshiIds のそれぞれに 200 件）
  /// - `users/{uid}` がすでにあるときは、displayName・createdAt を上書きせず、
  ///   欠けている項目だけを補う
  /// - `users/{uid}` が無ければ、[displayName]（空・null なら「名無し」）、
  ///   `createdAt`、空の配列で作成してから追加する（計画書 3.6）
  Future<void> follow(String uid, OshiSummary target, {String? displayName});

  /// フォローを解除する。フォローしていない・`users/{uid}` が無いときは何もしない。
  /// 推しが削除済みでも解除できる。
  Future<void> unfollow(String uid, OshiSummary target);
}

/// Firestore 版の [FollowRepository]
class FirestoreFollowRepository implements FollowRepository {
  FirestoreFollowRepository(this._db);

  final FirebaseFirestore _db;

  /// displayName が空・null のときに使う名前（計画書 3.6）
  static const String defaultDisplayName = '名無し';

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Stream<FollowState> watch(String uid) =>
      _user(uid)
          .snapshots()
          .map((snap) => FollowState.fromFirestore(snap.data()));

  @override
  Future<void> follow(
    String uid,
    OshiSummary target, {
    String? displayName,
  }) async {
    if (!target.isApproved) {
      throw StateError('申請中の推しはフォローできません');
    }
    final targetRef = _db.collection(target.kind.collection).doc(target.id);
    final userRef = _user(uid);
    final field = FollowState.fieldOf(target.kind);

    await _db.runTransaction<void>((tx) async {
      // トランザクションでは、書き込みの前にすべて読む
      final targetSnap = await tx.get(targetRef);
      final userSnap = await tx.get(userRef);

      final current = OshiSummary.fromFirestore(
        target.kind,
        target.id,
        targetSnap.data(),
      );
      if (!targetSnap.exists || current == null) {
        throw StateError('推しが見つかりません');
      }
      if (!current.isApproved) {
        throw StateError('申請中の推しはフォローできません');
      }

      final userData = userSnap.data() ?? const <String, dynamic>{};
      final following = FollowState.fromFirestore(userData).idsOf(target.kind);
      if (following.contains(target.id)) return;
      if (following.length >= FollowState.maxFollows) {
        throw StateError('フォローできるのは${FollowState.maxFollows}件までです');
      }

      final name = displayName?.trim() ?? '';
      final data = <String, dynamic>{
        field: FieldValue.arrayUnion([target.id]),
        if (userData['displayName'] is! String)
          'displayName': name.isEmpty ? defaultDisplayName : name,
        if (userData['createdAt'] is! Timestamp)
          'createdAt': FieldValue.serverTimestamp(),
        for (final kind in OshiKind.values)
          if (kind != target.kind &&
              userData[FollowState.fieldOf(kind)] is! List)
            FollowState.fieldOf(kind): <String>[],
      };
      // 既存のドキュメントは update で、欠けた項目だけを足す。
      // （set の merge でも同じ結果だが、fake_cloud_firestore の
      // Transaction.set が merge を無視するため、テストできる形にしている）
      if (userSnap.exists) {
        tx.update(userRef, data);
      } else {
        tx.set(userRef, data);
      }
    });
  }

  @override
  Future<void> unfollow(String uid, OshiSummary target) async {
    final userRef = _user(uid);
    final field = FollowState.fieldOf(target.kind);
    await _db.runTransaction<void>((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) return;
      final following = FollowState.fromFirestore(userSnap.data())
          .idsOf(target.kind);
      if (!following.contains(target.id)) return;
      tx.update(userRef, {
        field: FieldValue.arrayRemove([target.id]),
      });
    });
  }
}


/// まとめてフォロー（Ff 2.2）。
/// テストで差し替える [FollowRepository] の実装を増やさないよう、別のクラスにする
class FollowBatchRepository {
  FollowBatchRepository(this._db);

  final FirebaseFirestore _db;

  /// [targets] のうち、承認済みでまだフォローしていない推しを、
  /// 1回のトランザクションでフォローする。
  /// 申請中・削除済み・上限（種別ごとに [FollowState.maxFollows]）を超える分は足さない。
  /// `users/{uid}` の作り方・欠けた項目の補い方は [FirestoreFollowRepository.follow] と同じ
  Future<({int added, int skipped})> followMany(
    String uid,
    List<OshiSummary> targets, {
    String? displayName,
  }) async {
    if (targets.isEmpty) return (added: 0, skipped: 0);
    final userRef = _db.collection('users').doc(uid);
    final refs = [
      for (final t in targets) _db.collection(t.kind.collection).doc(t.id),
    ];

    return _db.runTransaction((tx) async {
      // トランザクションでは、書き込みの前にすべて読む
      final snaps = [for (final r in refs) await tx.get(r)];
      final userSnap = await tx.get(userRef);
      final userData = userSnap.data() ?? const <String, dynamic>{};
      final state = FollowState.fromFirestore(userData);

      final adds = <OshiKind, List<String>>{};
      var skipped = 0;
      for (var i = 0; i < targets.length; i++) {
        final t = targets[i];
        final current = OshiSummary.fromFirestore(
          t.kind,
          t.id,
          snaps[i].data(),
        );
        if (current == null || !current.isApproved) {
          skipped++;
          continue;
        }
        final have = state.idsOf(t.kind);
        final list = adds.putIfAbsent(t.kind, () => []);
        if (have.contains(t.id) || list.contains(t.id)) continue;
        if (have.length + list.length >= FollowState.maxFollows) {
          skipped++;
          continue;
        }
        list.add(t.id);
      }

      final added = adds.values.fold<int>(0, (n, l) => n + l.length);
      if (added == 0) return (added: 0, skipped: skipped);

      final name = displayName?.trim() ?? '';
      final data = <String, dynamic>{
        for (final e in adds.entries)
          if (e.value.isNotEmpty)
            FollowState.fieldOf(e.key): FieldValue.arrayUnion(e.value),
        if (userData['displayName'] is! String)
          'displayName': name.isEmpty
              ? FirestoreFollowRepository.defaultDisplayName
              : name,
        if (userData['createdAt'] is! Timestamp)
          'createdAt': FieldValue.serverTimestamp(),
        for (final kind in OshiKind.values)
          if ((adds[kind]?.isEmpty ?? true) &&
              userData[FollowState.fieldOf(kind)] is! List)
            FollowState.fieldOf(kind): <String>[],
      };
      if (userSnap.exists) {
        tx.update(userRef, data);
      } else {
        tx.set(userRef, data);
      }
      return (added: added, skipped: skipped);
    });
  }
}