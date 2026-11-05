import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/oshi.dart';
import '../../repositories/auth_repository.dart';
import '../../providers/oshi_providers.dart';

/// フォロー・解除を行う。失敗したら画面に出す日本語の文を返し、成功したら null を返す。
Future<String?> runFollowAction(
  WidgetRef ref,
  OshiSummary oshi, {
  required bool follow,
}) async {
  final uid = ref.read(currentUidProvider);
  if (uid == null) return 'ログインし直してください';
  final repo = ref.read(followRepositoryProvider);
  try {
    if (follow) {
      // 表示名は、users/{uid} を初めて作るときだけ使われる（契約 v1.1）
      final displayName = ref.read(authStateProvider).value?.displayName;
      await repo.follow(uid, oshi, displayName: displayName);
    } else {
      await repo.unfollow(uid, oshi);
    }
    return null;
  } on StateError catch (e) {
    // リポジトリの StateError は日本語の文（契約 v1）
    return e.message;
  } catch (_) {
    return follow ? 'フォローできませんでした。もう一度お試しください' : 'フォローを解除できませんでした。もう一度お試しください';
  }
}
