import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trade_post.dart';
import '../repositories/trade_post_repository.dart';
import 'oshi_providers.dart';

/// 交換・売買の投稿のリポジトリ。テストでは `overrideWithValue` で差し替える
final tradePostRepositoryProvider = Provider<TradePostRepository>(
  (ref) => FirestoreTradePostRepository(FirebaseFirestore.instance),
);

/// ログイン中のユーザーの投稿（更新日時の新しい順。募集終了・非表示も含む）。
/// 未ログインなら空
final myTradePostsProvider = StreamProvider<List<TradePost>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(tradePostRepositoryProvider).watchMine(uid);
}, retry: firestoreRetry);

/// ID で取得した投稿（詳細・編集画面で使う）。見つからなければ null。
/// 保存したら `ref.invalidate` で読み直す
final tradePostByIdProvider = FutureProvider.family<TradePost?, String>(
  (ref, id) => ref.watch(tradePostRepositoryProvider).fetch(id),
  retry: firestoreRetry,
);
