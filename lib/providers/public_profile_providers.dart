import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/public_profile.dart';
import '../repositories/public_profile_repository.dart';
import 'oshi_providers.dart';

/// 公開プロフィールのリポジトリ。テストでは `overrideWithValue` で差し替える
final publicProfileRepositoryProvider = Provider<PublicProfileRepository>(
  (ref) => FirestorePublicProfileRepository(FirebaseFirestore.instance),
);

/// uid ごとの公開プロフィール（add_I 3.3）。未ログインなら null。
/// 読めないとき（ルールのデプロイ前など）は取り直さず、アイコン無しとして扱う
final publicProfileProvider = StreamProvider.autoDispose
    .family<PublicProfile?, String>((ref, uid) {
      if (ref.watch(currentUidProvider) == null) return Stream.value(null);
      return ref.watch(publicProfileRepositoryProvider).watch(uid);
    }, retry: (_, _) => null);

/// プロフィールのアイコンを置く Storage のフォルダ
String userIconDir(String uid) => 'userIcons/$uid';
