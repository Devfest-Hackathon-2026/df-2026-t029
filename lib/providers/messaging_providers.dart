import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/messaging_repository.dart';
import 'oshi_providers.dart';

/// リマインド通知のリポジトリ
final messagingRepositoryProvider = Provider<MessagingRepository>(
  (ref) => MessagingRepository(
    FirebaseMessaging.instance,
    FirebaseFirestore.instance,
  ),
);

/// このブラウザでリマインド通知がオンか（仕様書 3.5）。
/// オン・オフを変えたら `ref.invalidate(notificationEnabledProvider)` で読み直す
final notificationEnabledProvider = FutureProvider<bool>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return false;
  return ref.read(messagingRepositoryProvider).isEnabled(uid);
});

/// アプリを開いているときに届いた通知（仕様書 3.6）
final foregroundMessageProvider = StreamProvider<RemoteMessage>(
  (ref) => ref.watch(messagingRepositoryProvider).onForegroundMessage,
);