import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateAppCheck();
  // 再読み込み時に、ログイン状態の復元を待ってから起動する
  await FirebaseAuth.instance.authStateChanges().first;
  runApp(const ProviderScope(child: App()));
}

/// App Check の reCAPTCHA Enterprise のサイトキー。リポジトリには書かず、
/// `--dart-define=APP_CHECK_SITE_KEY=...` で渡す
const _appCheckSiteKey = String.fromEnvironment('APP_CHECK_SITE_KEY');

/// App Check を有効にする（Firebase の初期化の後、ほかの呼び出しの前）。
/// サイトキーがあれば reCAPTCHA Enterprise。無ければ、開発中（デバッグビルド）だけ
/// デバッグ用プロバイダを使い、本番ビルドでは何もしない。失敗しても起動は続ける
Future<void> _activateAppCheck() async {
  final WebProvider? provider = _appCheckSiteKey.isNotEmpty
      ? ReCaptchaEnterpriseProvider(_appCheckSiteKey)
      : (kDebugMode ? WebDebugProvider() : null);
  if (provider == null) return;
  try {
    await FirebaseAppCheck.instance.activate(providerWeb: provider);
  } catch (e) {
    debugPrint('App Check の初期化に失敗しました: $e');
  }
}
