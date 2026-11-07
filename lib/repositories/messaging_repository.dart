// firebase_messaging 17 で getToken・deleteToken は非推奨になった
// （FID 宛ての register／onRegistered が後継）。送信側（Cloud Functions の
// Admin SDK）が FCM トークン宛ての送信のため、トークン方式のまま使う
// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Web プッシュの VAPID キー。リポジトリには書かず、
/// `--dart-define=FCM_VAPID_KEY=...` で渡す
const fcmVapidKey = String.fromEnvironment('FCM_VAPID_KEY');

/// 通知をオンにした結果
enum NotificationEnableResult {
  /// 許可され、トークンを保存した
  enabled,

  /// ブラウザで通知が許可されなかった
  denied,

  /// VAPID キーが渡されていない
  notConfigured,
}

/// リマインド通知の FCM トークン（仕様書 4.1・5.3）。
///
/// トークンは `users/{uid}/fcmTokens/{token}` に保存する（ドキュメント ID がトークン）。
class MessagingRepository {
  MessagingRepository(this._messaging, this._db);

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _tokens(String uid) =>
      _db.collection('users').doc(uid).collection('fcmTokens');

  /// このブラウザの通知が許可されていて、このブラウザのトークンが保存されているか
  Future<bool> isEnabled(String uid) async {
    if (fcmVapidKey.isEmpty) return false;
    final settings = await _messaging.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      return false;
    }
    final token = await _messaging.getToken(vapidKey: fcmVapidKey);
    if (token == null) return false;
    final doc = await _tokens(uid).doc(token).get();
    return doc.exists;
  }

  /// 通知の許可を求め、許可されたらトークンを保存する
  Future<NotificationEnableResult> enable(String uid) async {
    if (fcmVapidKey.isEmpty) return NotificationEnableResult.notConfigured;
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      return NotificationEnableResult.denied;
    }
    final token = await _messaging.getToken(vapidKey: fcmVapidKey);
    if (token == null) return NotificationEnableResult.denied;
    final ref = _tokens(uid).doc(token);
    final snap = await ref.get();
    await ref.set({
      // 作成日時は初回だけ。保存し直すたびに更新日時を変える
      if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return NotificationEnableResult.enabled;
  }

  /// このブラウザのトークンを消し、通知を止める
  Future<void> disable(String uid) async {
    if (fcmVapidKey.isNotEmpty) {
      try {
        final token = await _messaging.getToken(vapidKey: fcmVapidKey);
        if (token != null) await _tokens(uid).doc(token).delete();
      } catch (_) {
        // 許可が取り消されているとトークンを取れない。そのまま deleteToken へ進む
      }
    }
    await _messaging.deleteToken();
  }

  /// アプリを開いている（前面の）ときに届いた通知
  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;
}