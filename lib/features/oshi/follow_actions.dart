import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/oshi.dart';
import '../../repositories/auth_repository.dart';
import '../../providers/favorite_oshi_providers.dart';
import '../../providers/oshi_providers.dart';

/// フォロー・解除を行う。失敗したら画面に出す日本語の文を返し、成功したら null を返す。
///
/// 解除した推しが最推しなら、最推しも外す（Fc 3.2。失敗しても無視する）。
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
      // 解除の後は ref が使えなくなることがあるので、先に取っておく
      final isFavorite = ref.read(favoriteOshiKeyProvider).value == oshi.key;
      final favoriteRepo = ref.read(favoriteOshiRepositoryProvider);
      await repo.unfollow(uid, oshi);
      if (isFavorite) {
        try {
          await favoriteRepo.clear(uid);
        } catch (_) {
          // 外せなくても、フォロー中でない最推しは表示しないので困らない
        }
      }
    }
    return null;
  } on StateError catch (e) {
    // リポジトリの StateError は日本語の文（契約 v1）
    return e.message;
  } catch (_) {
    return follow ? 'フォローできませんでした。もう一度お試しください' : 'フォローを解除できませんでした。もう一度お試しください';
  }
}

/// 最推しにする（[favorite] が true）・外す（false）。
/// 失敗したら画面に出す日本語の文を返し、成功したら null を返す（Fc 3.2）。
Future<String?> runFavoriteAction(
  WidgetRef ref,
  OshiSummary oshi, {
  required bool favorite,
}) async {
  final uid = ref.read(currentUidProvider);
  if (uid == null) return 'ログインし直してください';
  final repo = ref.read(favoriteOshiRepositoryProvider);
  try {
    if (favorite) {
      await repo.set(uid, oshi);
    } else {
      await repo.clear(uid);
    }
    return null;
  } catch (_) {
    return favorite ? '最推しにできませんでした。もう一度お試しください' : '最推しを外せませんでした。もう一度お試しください';
  }
}
