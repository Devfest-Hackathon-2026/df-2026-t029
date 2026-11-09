import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../repositories/profile_repository.dart';
import 'oshi_providers.dart';

/// プロフィールのリポジトリ
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => FirestoreProfileRepository(FirebaseFirestore.instance),
);

/// ログイン中のユーザーのプロフィール。未作成・未ログインなら null
final myProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watch(uid);
}, retry: firestoreRetry);
