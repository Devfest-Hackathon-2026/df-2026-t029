// 外枠（AppShell）とアカウントのメニューのテスト（Q1）。
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/shell/app_shell.dart';
import 'package:oshiashi/repositories/auth_repository.dart';
import 'package:oshiashi/theme/brand_colors.dart';
import 'package:oshiashi/theme/hako_app_widgets.dart';

import 'auth_test_helpers.dart';

const _tabLabels = ['ホーム', '推し', 'ライブ一覧', 'グッズ交換', 'メモリー'];
const _tabPaths = ['/', '/oshi', '/lives', '/trade', '/memories'];

/// 外枠の中の画面（スマホの幅ではアカウントのボタンを上のバーに持つ）
Widget _page(String path) =>
    HakoPageScaffold(title: 'ページ$path', body: Text('本文$path'));

Future<GoRouter> pumpShell(
  WidgetTester tester, {
  required double width,
  double height = 800,
  String initial = '/',
  FakeAuthRepository? auth,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (_, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          for (final p in [
            ..._tabPaths,
            '/lives/abc',
            '/lives/abc/memory/p1',
            '/memories/p1',
            '/chats/c1',
            '/goods/new',
            '/expenses',
          ])
            GoRoute(path: p, builder: (_, _) => _page(p)),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('route:/profile')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// タブ [label] のピルの色（選択中はページの色、そうでなければ透明）
Color? _pill(WidgetTester tester, String label) {
  final item = find.ancestor(
    of: find.text(label),
    matching: find.byType(InkWell),
  );
  final box = tester.widget<Container>(
    find.descendant(of: item.first, matching: find.byType(Container)).first,
  );
  return (box.decoration! as BoxDecoration).color;
}

/// 選択中のタブの番号（ピルが塗られているもの）。なければ -1
int _selected(WidgetTester tester) {
  final on = [
    for (var i = 0; i < _tabLabels.length; i++)
      if (_pill(tester, _tabLabels[i]) != Colors.transparent) i,
  ];
  expect(on.length, lessThanOrEqualTo(1));
  return on.isEmpty ? -1 : on.single;
}

void main() {
  group('tabIndexFor', () {
    const cases = <String, int>{
      '/': 0,
      '/expenses': 0,
      '/unknown': 0,
      '/oshi': 1,
      '/oshi/search': 1,
      '/lives': 2,
      '/lives/add': 2,
      '/lives/abc/memory/p1': 2,
      '/register': 2,
      '/live-form': 2,
      '/trade': 3,
      '/trade/post/new': 3,
      '/chats/c1': 3,
      '/goods/new': 3,
      '/memories': 4,
      '/memories/p1': 4,
    };
    cases.forEach((path, i) {
      test('「$path」→ $i', () => expect(tabIndexFor(path), i));
    });
  });

  group('幅 390（下のタブ）', () {
    testWidgets('5つのタブが順に並び、左のタブは無い', (tester) async {
      await pumpShell(tester, width: 390);
      expect(find.byKey(const Key('shell_bottom_bar')), findsOneWidget);
      expect(find.byKey(const Key('shell_rail')), findsNothing);
      for (final l in _tabLabels) {
        expect(
          find.descendant(
            of: find.byKey(const Key('shell_bottom_bar')),
            matching: find.text(l),
          ),
          findsOneWidget,
          reason: l,
        );
      }
      expect(
        tester.getSize(find.byKey(const Key('shell_bottom_bar'))).height,
        72,
      );
    });

    testWidgets('選択中のタブはパスで決まる', (tester) async {
      const expected = {
        '/': 0,
        '/oshi': 1,
        '/lives/abc': 2,
        '/lives/abc/memory/p1': 2,
        '/chats/c1': 3,
        '/memories/p1': 4,
        '/expenses': 0,
      };
      for (final e in expected.entries) {
        await pumpShell(tester, width: 390, initial: e.key);
        expect(_selected(tester), e.value, reason: e.key);
      }
    });

    testWidgets('タブを押すと移動する', (tester) async {
      await pumpShell(tester, width: 390);
      for (var i = 1; i < 5; i++) {
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('shell_bottom_bar')),
            matching: find.text(_tabLabels[i]),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('本文${_tabPaths[i]}'), findsOneWidget);
        expect(_selected(tester), i);
      }
    });

    testWidgets('選択中のピルの色はページの色（ホーム=黄・推し=赤・ライブ=青）', (tester) async {
      const hues = {
        '/': BrandColors.hall3,
        '/oshi': BrandColors.hall1,
        '/lives': BrandColors.hall5,
        '/trade': BrandColors.hall6,
        '/memories': BrandColors.hall4,
      };
      for (final e in hues.entries) {
        await pumpShell(tester, width: 390, initial: e.key);
        expect(
          _pill(tester, _tabLabels[_tabPaths.indexOf(e.key)]),
          e.value,
          reason: e.key,
        );
      }
    });

    testWidgets('アカウントのメニュー（上のバー）: プロフィールへ移る', (tester) async {
      await pumpShell(tester, width: 390);
      await tester.tap(find.byType(AccountMenuButton));
      await tester.pumpAndSettle();
      expect(find.text('プロフィール'), findsOneWidget);
      expect(find.text('ログアウト'), findsOneWidget);
      await tester.tap(find.text('プロフィール'));
      await tester.pumpAndSettle();
      expect(find.text('route:/profile'), findsOneWidget);
    });

    testWidgets('アカウントのメニュー: ログアウトで signOut を呼ぶ', (tester) async {
      final auth = FakeAuthRepository();
      await pumpShell(tester, width: 390, auth: auth);
      await tester.tap(find.byType(AccountMenuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ログアウト'));
      await tester.pumpAndSettle();
      expect(auth.signOuts, 1);
    });
  });

  group('幅 1000（左のタブ）', () {
    testWidgets('左のタブ・「おしあし」の札・アカウントのボタンがあり、下のタブは無い', (tester) async {
      await pumpShell(tester, width: 1000);
      expect(find.byKey(const Key('shell_rail')), findsOneWidget);
      expect(find.byKey(const Key('shell_bottom_bar')), findsNothing);
      expect(find.byKey(const Key('shell_app_name')), findsOneWidget);
      expect(find.text('おしあし'), findsOneWidget);
      expect(find.byKey(const Key('shell_account_button')), findsOneWidget);
      for (final l in _tabLabels) {
        expect(find.text(l), findsOneWidget, reason: l);
      }
    });

    testWidgets('選択中のタブはパスで決まり、押すと移動する', (tester) async {
      await pumpShell(tester, width: 1000, initial: '/lives/abc');
      expect(_selected(tester), 2);
      await tester.tap(find.text('メモリー'));
      await tester.pumpAndSettle();
      expect(find.text('本文/memories'), findsOneWidget);
      expect(_selected(tester), 4);
    });

    testWidgets('PC では上のバーが出ず、タイトルが本文の上に出る', (tester) async {
      await pumpShell(tester, width: 1000, initial: '/oshi');
      expect(find.byKey(const Key('hako_app_bar')), findsNothing);
      expect(find.byKey(const Key('hako_page_title')), findsOneWidget);
    });

    testWidgets('アカウントのメニュー（左下）: プロフィール・ログアウト', (tester) async {
      final auth = FakeAuthRepository();
      await pumpShell(tester, width: 1000, auth: auth);
      await tester.tap(find.byKey(const Key('shell_account_button')));
      await tester.pumpAndSettle();
      expect(find.text('プロフィール'), findsOneWidget);
      await tester.tap(find.text('ログアウト'));
      await tester.pumpAndSettle();
      expect(auth.signOuts, 1);
    });

    testWidgets('メニューからプロフィールへ移る', (tester) async {
      await pumpShell(tester, width: 1000);
      await tester.tap(find.byKey(const Key('shell_account_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('プロフィール'));
      await tester.pumpAndSettle();
      expect(find.text('route:/profile'), findsOneWidget);
    });
  });

  testWidgets('幅 320・360・430・720・1000 ではみ出さない', (tester) async {
    for (final w in [320.0, 360.0, 430.0, 720.0, 1000.0]) {
      await pumpShell(tester, width: w);
      expect(tester.takeException(), isNull, reason: 'w=$w');
    }
  });

  testWidgets('左のタブは、高さ 400 でも例外が出ない（項目がスクロールする）', (tester) async {
    await pumpShell(tester, width: 1000, height: 400);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('shell_app_name')), findsOneWidget);
    expect(find.byKey(const Key('shell_account_button')), findsOneWidget);
  });
}
