import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/goods.dart';
import '../models/oshi.dart';
import '../repositories/goods_repository.dart';
import 'oshi_providers.dart';

/// グッズのリポジトリ。テストでは `overrideWithValue` で差し替える
final goodsRepositoryProvider = Provider<GoodsRepository>(
  (ref) => FirestoreGoodsRepository(FirebaseFirestore.instance),
);

/// グッズの検索で選んでいる推し。未選択なら null
class GoodsTargetNotifier extends Notifier<OshiSummary?> {
  @override
  OshiSummary? build() => null;

  void select(OshiSummary? oshi) => state = oshi;
}

final goodsTargetProvider =
    NotifierProvider<GoodsTargetNotifier, OshiSummary?>(
  GoodsTargetNotifier.new,
);

/// 選んでいる推しのグッズ（名前順。未選択なら空）。
///
/// グループならそのグループのグッズ、個人なら本人名義のグッズと
/// 所属グループのグッズ。登録・更新したら `ref.invalidate` で読み直す。
final goodsForTargetProvider = FutureProvider<List<Goods>>((ref) async {
  final oshi = ref.watch(goodsTargetProvider);
  if (oshi == null) return [];
  final repository = ref.watch(goodsRepositoryProvider);
  return switch (oshi.kind) {
    OshiKind.group => repository.fetchFor(groupIds: [oshi.id]),
    OshiKind.person =>
      repository.fetchFor(groupIds: oshi.groupIds, oshiIds: [oshi.id]),
  };
}, retry: firestoreRetry);

/// ID で取得したグッズ（編集画面で使う）
final goodsByIdProvider = FutureProvider.family<Goods?, String>(
  (ref, id) => ref.watch(goodsRepositoryProvider).fetch(id),
  retry: firestoreRetry,
);