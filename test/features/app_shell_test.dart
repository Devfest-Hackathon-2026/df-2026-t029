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

/// 丸いアイコンの色（選択中は濃い色、そうでなければ淡い色）
const _hues = [
  BrandColors.hall3,
  BrandColors.hall1,
  BrandColors.hall5,
  BrandColors.hall6,
  BrandColors.hall4,
];
const _softs = [
  BrandColors.hall3Soft,
  BrandColors.hall1Soft,
  BrandColors.hall5Soft,
  BrandColors.hall6Soft,
  BrandColors.hall4Soft,
];

Finder _tab(int i) => find.byKey(Key('shell_tab_$i'));

/// タブ [i] の丸（直径 44 の円）
Finder _circle(int i) => find.descendant(
  of: _tab(i),
  matching: find.byWidgetPredicate(
    (w) =>
        w is AnimatedContainer &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).shape == BoxShape.circle,
  ),
);

Color? _circleColor(WidgetTester tester, int i) {
  final box = tester.widget<AnimatedContainer>(_circle(i));
  return (box.decoration! as BoxDecoration).color;
}

/// 選択中のタブの番号（丸が濃い色のもの）。なければ -1
int _selected(WidgetTester tester) {
  final on = [
    for (var i = 0; i < _tabLabels.length; i++)
      if (_circleColor(tester, i) == _hues[i]) i,
  ];
  expect(on.length, lessThanOrEqualTo(1));
  return on.isEmpty ? -1 : on.single;
}

Finder _key(String k) => find.byKey(Key(k));

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
        80,
      );
      expect(kShellBottomBarHeight, 80);
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

    testWidgets('選択中の丸は濃い色（ページの色）、ほかは淡い色', (tester) async {
      for (var i = 0; i < 5; i++) {
        await pumpShell(tester, width: 390, initial: _tabPaths[i]);
        for (var j = 0; j < 5; j++) {
          expect(
            _circleColor(tester, j),
            j == i ? _hues[j] : _softs[j],
            reason: 'path=${_tabPaths[i]} tab=$j',
          );
        }
      }
    });

    testWidgets('選択中の丸だけ、上に 6 浮く', (tester) async {
      await pumpShell(tester, width: 390, initial: '/oshi');
      final selectedTop = tester.getTopLeft(_circle(1)).dy;
      for (final j in [0, 2, 3, 4]) {
        expect(tester.getTopLeft(_circle(j)).dy - selectedTop, 6, reason: '$j');
      }
      expect(tester.getSize(_circle(1)), const Size(44, 44));
    });

    testWidgets('選択中の丸には墨の硬い影（下に 3・ぼかし 0）、ほかには無い', (tester) async {
      await pumpShell(tester, width: 390, initial: '/lives');
      List<BoxShadow>? shadow(int i) =>
          (tester.widget<AnimatedContainer>(_circle(i)).decoration!
                  as BoxDecoration)
              .boxShadow;
      expect(shadow(2), [
        const BoxShadow(color: BrandColors.ink, offset: Offset(0, 3)),
      ]);
      expect(shadow(0), isEmpty);
    });

    testWidgets('タブのキー shell_tab_0〜4 はタップを受ける部品で、5つが順に左から並ぶ', (tester) async {
      await pumpShell(tester, width: 390);
      var left = -1.0;
      for (var i = 0; i < 5; i++) {
        expect(_tab(i), findsOneWidget);
        expect(tester.widget(_tab(i)), isA<InkWell>());
        final x = tester.getTopLeft(_tab(i)).dx;
        expect(x, greaterThan(left));
        left = x;
      }
    });

    testWidgets('読み上げ: タブはボタンで、選択中は selected', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpShell(tester, width: 390, initial: '/oshi');
      expect(
        tester.getSemantics(_tab(1)),
        matchesSemantics(
          label: '推し',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      handle.dispose();
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
