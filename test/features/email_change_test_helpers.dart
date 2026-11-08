// メールアドレス変更の画面テスト用の共通の部品（AccountSection とシートを開く台）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/profile/account_section.dart';
import 'package:oshiashi/providers/email_change_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';
import 'package:oshiashi/theme/app_theme.dart';
import 'package:oshiashi/providers/theme_providers.dart';

import 'auth_test_helpers.dart';

Finder k(String key) => find.byKey(Key(key));

const kShortTiming = EmailChangeTiming(
  pollInterval: Duration(seconds: 1),
  resendCooldown: 3,
);

/// AccountSection だけを置いた台を作る。providers は ['password'] か ['google.com'] など
Future<FakeAuthRepository> pumpAccount(
  WidgetTester tester, {
  List<String> providers = const ['password'],
  String? email = 'ken-oshi@example.com',
  double width = 390,
  double height = 1000,
  double textScale = 1,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  final repo = FakeAuthRepository()
    ..email = email
    ..providers = providers;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        emailChangeTimingProvider.overrideWithValue(kShortTiming),
      ],
      retry: (_, _) => null,
      child: MaterialApp(
        theme: buildAppTheme(kDefaultSeedColor),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(child: AccountSection()),
        ),
      ),
    ),
  );
  await tester.pump();
  return repo;
}

/// 行を押してシートを開く
Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(k('profile_email_row'));
  await tester.pumpAndSettle();
}
