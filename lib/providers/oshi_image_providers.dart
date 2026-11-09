import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/oshi.dart';
import '../repositories/oshi_image_repository.dart';
import 'oshi_color_providers.dart';
import 'oshi_providers.dart';

/// 推しの画像のリポジトリ。テストでは `overrideWithValue` で差し替える
final oshiImageRepositoryProvider = Provider<OshiImageRepository>(
  (ref) => FirestoreOshiImageRepository(FirebaseFirestore.instance),
);

/// 推しの画像（キー → Storage のパス）。未ログイン・読み込み中は空として使う（add_I 3.1b）
final oshiImagesProvider = StreamProvider<Map<String, String>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const {});
  return ref.watch(oshiImageRepositoryProvider).watch(uid);
}, retry: firestoreRetry);

/// 推しの画像の Storage のパス（add_I 3.1b）。グループの画像は引き継がない
String? resolveOshiImage(OshiSummary oshi, Map<String, String> images) =>
    images[oshiColorKey(oshi.kind, oshi.id)];

/// 推しの画像を置く Storage のフォルダ
String oshiImageDir(String uid) => 'users/$uid/oshiIcons';
