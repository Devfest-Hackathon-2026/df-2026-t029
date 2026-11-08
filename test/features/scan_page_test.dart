// ライブを登録する画面（/register）のウィジェットテスト。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/scan/scan_page.dart';

Future<void> pumpScan(WidgetTester tester, {double width = 390}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(path: '/lives/add', builder: (_, _) => const Text('route:add')),
      GoRoute(path: '/register', builder: (_, _) => const ScanPage()),
      GoRoute(
        path: '/live-form',
        builder: (_, _) => const Text('route:/live-form'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('2枚のカードの文言が今のまま', (tester) async {
    await pumpScan(tester);
    expect(find.text('スクショから読み取る'), findsOneWidget);
    expect(find.text('手入力する'), findsOneWidget);
    expect(
      find.text('告知画像やチケットサイトのスクリーンショットから、日程や期限を自動で読み取ります'),
      findsOneWidget,
    );
    expect(find.text('ライブ名・公演・受付を自分で入力します'), findsOneWidget);
    expect(find.text('ライブを登録'), findsOneWidget);
  });

  testWidgets('「手入力する」で /live-form へ', (tester) async {
    await pumpScan(tester);
    await tester.tap(find.text('手入力する'));
    await tester.pumpAndSettle();
    expect(find.text('route:/live-form'), findsOneWidget);
  });

  testWidgets('戻れないときの戻るは /lives/add へ', (tester) async {
    await pumpScan(tester);
    await tester.tap(find.byKey(const Key('hako_back')));
    await tester.pumpAndSettle();
    expect(find.text('route:add'), findsOneWidget);
  });

  for (final w in [320.0, 360.0, 390.0, 430.0, 720.0, 1000.0]) {
    testWidgets('幅 ${w.toInt()} ではみ出さない', (tester) async {
      await pumpScan(tester, width: w);
      expect(tester.takeException(), isNull);
    });
  }
}
