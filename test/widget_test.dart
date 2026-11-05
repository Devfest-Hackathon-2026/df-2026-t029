import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oshiashi/features/auth/login_page.dart';

void main() {
  testWidgets('ログイン画面に Google ログインのボタンが表示される', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );

    expect(find.text('Google でログイン'), findsOneWidget);
  });
}
