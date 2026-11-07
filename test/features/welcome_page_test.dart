import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oshiashi/features/welcome/welcome_page.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> pumpWelcome(
  WidgetTester tester, {
  Size size = const Size(900, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/welcome',
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
      GoRoute(
        path: '/login',
        builder: (_, state) =>
            Text('route:login:${state.uri.queryParameters['mode'] ?? ''}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  // 紹介ページは英字・番号に google_fonts を使う。テストでは取りに行かない
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('表示できる。フォントの例外も出ない', (tester) async {
    await pumpWelcome(tester);
    expect(_key('welcome_start_button'), findsOneWidget);
    expect(_key('welcome_login_button'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('「始める」で、ログイン画面の「新規登録」へ移す', (tester) async {
    await pumpWelcome(tester);
    await tester.ensureVisible(_key('welcome_start_button'));
    await tester.pumpAndSettle();
    await tester.tap(_key('welcome_start_button'));
    await tester.pumpAndSettle();
    expect(find.text('route:login:signup'), findsOneWidget);
  });

  testWidgets('右上の「ログイン」で、ログイン画面の「ログイン」へ移す', (tester) async {
    await pumpWelcome(tester);
    await tester.tap(_key('welcome_login_button'));
    await tester.pumpAndSettle();
    expect(find.text('route:login:'), findsOneWidget);
  });

  testWidgets('「始める」の下の説明が変わり、reCAPTCHA の文言はログイン画面へ移った', (tester) async {
    await pumpWelcome(tester);
    await tester.ensureVisible(_key('welcome_start_button'));
    await tester.pumpAndSettle();
    expect(find.text('メールアドレスか Google アカウントで始められます。'), findsOneWidget);
    expect(find.textContaining('押すと Google のログインの画面が開きます'), findsNothing);
    expect(_key('welcome_recaptcha_notice'), findsNothing);
    expect(
      find.textContaining('reCAPTCHA で保護されており', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('スマホの幅（360px）でもはみ出さない', (tester) async {
    await pumpWelcome(tester, size: const Size(360, 640));
    await tester.ensureVisible(_key('welcome_start_button'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
