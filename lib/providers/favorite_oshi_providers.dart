import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/oshi.dart';
import '../repositories/favorite_oshi_repository.dart';
import 'oshi_providers.dart';

/// 最推しのリポジトリ。テストでは `overrideWithValue` で差し替える
final favoriteOshiRepositoryProvider = Provider<FavoriteOshiRepository>(
  (ref) => FirestoreFavoriteOshiRepository(FirebaseFirestore.instance),
);

/// 最推しのキー（[OshiSummary.key]）。無い・未ログインなら null（Fc 3.2）
final favoriteOshiKeyProvider = StreamProvider<String?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(favoriteOshiRepositoryProvider).watch(uid);
}, retry: firestoreRetry);

/// 最推し。フォロー中の推しの中にあるときだけ返す
/// （フォローを外した・削除された・読み込み中・エラーのときは null）
final favoriteOshiProvider = Provider<OshiSummary?>((ref) {
  final key = ref.watch(favoriteOshiKeyProvider).value;
  if (key == null) return null;
  final following = ref.watch(followingOshisProvider).value ?? const [];
  return following.where((o) => o.key == key).firstOrNull;
});
