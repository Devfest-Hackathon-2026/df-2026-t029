import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/oshi.dart';
import '../repositories/auth_repository.dart';
import '../repositories/follow_repository.dart';
import '../repositories/oshi_repository.dart';
import '../utils/oshi_search.dart';

/// Firestore を購読するプロバイダの再試行の方針（Riverpod の `retry`）。
///
/// ルールで拒否された（`permission-denied`）ときは、何度読み直しても結果が
/// 変わらないので再試行しない（null）。それ以外（一時的なネットワーク障害など）は
/// Riverpod の既定（[ProviderContainer.defaultRetry]）に任せる。
Duration? firestoreRetry(int retryCount, Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return null;
  }
  return ProviderContainer.defaultRetry(retryCount, error);
}

/// 推しのリポジトリ。テストでは `overrideWithValue` で差し替える
final oshiRepositoryProvider = Provider<OshiRepository>(
  (ref) => FirestoreOshiRepository(FirebaseFirestore.instance),
);

/// フォローのリポジトリ。テストでは `overrideWithValue` で差し替える
final followRepositoryProvider = Provider<FollowRepository>(
  (ref) => FirestoreFollowRepository(FirebaseFirestore.instance),
);

/// ログイン中のユーザーの uid（未ログインなら null）。
/// uid が変わったときだけ、下のプロバイダが購読し直す。
///
/// 認証のストリームが最初の値を流すまで（読み込み中）は、
/// `FirebaseAuth.currentUser` の uid を使う。main.dart がログイン状態の復元を
/// 待ってから起動するので、この時点の currentUser は正しい。
/// 読み込み中に null を返すと、一覧が一瞬「0件」になってしまうため。
final currentUidProvider = Provider<String?>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.hasValue) return auth.value?.uid;
  return ref.read(authRepositoryProvider).currentUser?.uid;
});

/// `groups` と `oshis`（承認済み＋申請中）。順序は不定なので、
/// 表示するときは [searchOshis] を通す。
///
/// 購読でエラーが起きるとストリームは閉じる。再試行は
/// `ref.invalidate(allOshisProvider)` で行う。
/// 未ログインでは読めない（ルールで拒否される）ので、空のリストを返す。
final allOshisProvider = StreamProvider<List<OshiSummary>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(oshiRepositoryProvider).watchAll();
}, retry: firestoreRetry);

/// ログイン中のユーザーのフォロー状態。未ログインなら [FollowState.empty]
final followStateProvider = StreamProvider<FollowState>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(FollowState.empty);
  return ref.watch(followRepositoryProvider).watch(uid);
}, retry: firestoreRetry);

/// フォロー中で承認済みの推し（個人が先、グループが後。それぞれ名前順）。
///
/// [allOshisProvider] と [followStateProvider] のどちらかがエラーならエラー、
/// どちらかが読み込み中なら読み込み中。フォロー中でも、削除された推しや
/// 申請中に戻された推しは含めない。
final followingOshisProvider = Provider<AsyncValue<List<OshiSummary>>>((ref) {
  final all = ref.watch(allOshisProvider);
  final follow = ref.watch(followStateProvider);
  if (all case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (follow case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  final allValue = all.value;
  final followValue = follow.value;
  if (allValue == null || followValue == null) return const AsyncLoading();
  final sorted = searchOshis(
    allValue.where(followValue.isFollowing).toList(),
    '',
  );
  // ファンはふつう個人（推しメン）を選ぶので、個人を先に並べる
  return AsyncData([
    for (final o in sorted)
      if (o.kind == OshiKind.person) o,
    for (final o in sorted)
      if (o.kind == OshiKind.group) o,
  ]);
});
