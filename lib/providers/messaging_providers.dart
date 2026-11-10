import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';
import '../repositories/messaging_repository.dart';
import 'oshi_providers.dart';

/// リマインド通知のリポジトリ
final messagingRepositoryProvider = Provider<MessagingRepository>(
  (ref) => MessagingRepository(
    FirebaseMessaging.instance,
    FirebaseFirestore.instance,
  ),
);

/// このブラウザでリマインド通知がオンか（Step6 仕様書 3.5）。
/// オン・オフを変えたら `ref.invalidate(notificationEnabledProvider)` で読み直す
final notificationEnabledProvider = FutureProvider<bool>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return false;
  return ref.read(messagingRepositoryProvider).isEnabled(uid);
});

/// アプリを開いているときに届いた通知（Step6 仕様書 3.6）
final foregroundMessageProvider = StreamProvider<RemoteMessage>(
  (ref) => ref.watch(messagingRepositoryProvider).onForegroundMessage,
);

/// ログアウトする。先にこのブラウザの通知のトークンを消す
/// （Step6 仕様書 9章の未決定事項。同じブラウザで別のアカウントに切り替えたときに、
/// 前のアカウントの通知が届かないよう「ログアウトで消す」に決めた）。
/// トークンの削除が失敗・3秒を超えても、ログアウトは続ける
Future<void> signOutAndStopNotifications(WidgetRef ref) async {
  final uid = ref.read(currentUidProvider);
  final auth = ref.read(authRepositoryProvider);
  if (uid != null) {
    try {
      // リポジトリの用意（FirebaseMessaging）で失敗しても、ログアウトは続ける
      await ref
          .read(messagingRepositoryProvider)
          .stopOnSignOut(uid)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // 消せなくてもログアウトはする
    }
  }
  await auth.signOut();
}
