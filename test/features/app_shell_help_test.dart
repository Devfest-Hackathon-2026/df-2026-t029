// 外枠（AppShell）の「?」ボタン・初回の吹き出し・未読の数字のテスト
// （ログイン後のヘルプシート。計画書 4.2・4.4・4.7・5.5）。
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/shell/app_shell.dart';
import 'package:oshiashi/providers/help_providers.dart';
import 'package:oshiashi/providers/trade_post_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';
import 'package:oshiashi/theme/hako_app_widgets.dart';

import 'auth_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

const _tops = ['/', '/oshi', '/lives', '/trade', '/memories'];
const _others = [
  '/lives/abc',
  '/memories/p1',
  '/chats/c1',
  '/goods/new',
  '/expenses',
];

const _phoneText = 'はじめての方へ。画面右上の「?」から、使い方を見られます。';
const _wideText = 'はじめての方へ。左下の「?」から、使い方を見られます。';

Future<GoRouter> pumpShell(
  WidgetTester tester, {
  required double width,
  double height = 800,
  String initial = '/',
  int unread = 0,
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
          for (final p in [..._tops, ..._others])
            GoRoute(
              path: p,
              builder: (_, _) =>
                  HakoPageScaffold(title: 'ページ$p', body: Text('本文$p')),
            ),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Text('route:/profile'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        unreadChatCountProvider.overrideWithValue(unread),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

bool _coachVisible(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppShell)))
        .read(helpCoachVisibleProvider);

void main() {
  group('「?」ボタンの出る場所', () {
    for (final w in [390.0, 1000.0]) {
      testWidgets('幅 ${w.toInt()}: トップの5画面で1つだけ出る', (tester) async {
        for (final p in _tops) {
          await pumpShell(tester, width: w, initial: p);
          expect(_key('help_button'), findsOneWidget, reason: p);
        }
      });

      testWidgets('幅 ${w.toInt()}: 詳細・チャット・追加などでは出ない', (tester) async {
        for (final p in _others) {
          await pumpShell(tester, width: w, initial: p);
          expect(_key('help_button'), findsNothing, reason: p);
        }
      });
    }

    testWidgets('スマホは上のバーの中で、アカウントのボタンの左', (tester) async {
      await pumpShell(tester, width: 390, initial: '/oshi');
      expect(
        find.descendant(
          of: _key('hako_app_bar'),
          matching: _key('help_button'),
        ),
        findsOneWidget,
      );
      expect(_key('shell_rail'), findsNothing);
      expect(
        tester.getCenter(_key('help_button')).dx,
        lessThan(tester.getCenter(find.byType(AccountMenuButton)).dx),
      );
    });

    testWidgets('PC は左のタブ（shell_rail）の中で、アカウントのボタンの上', (tester) async {
      await pumpShell(tester, width: 1000, initial: '/oshi');
      expect(
        find.descendant(of: _key('shell_rail'), matching: _key('help_button')),
        findsOneWidget,
      );
      expect(_key('hako_app_bar'), findsNothing);
      expect(
        tester.getCenter(_key('help_button')).dy,
        lessThan(tester.getCenter(_key('shell_account_button')).dy),
      );
    });

    testWidgets('幅 719 は上のバー、720 は左のタブ（境界）', (tester) async {
      await pumpShell(tester, width: 719, initial: '/oshi');
      expect(
        find.descendant(
          of: _key('hako_app_bar'),
          matching: _key('help_button'),
        ),
        findsOneWidget,
      );
      await pumpShell(tester, width: 720, initial: '/oshi');
      expect(
        find.descendant(of: _key('shell_rail'), matching: _key('help_button')),
        findsOneWidget,
      );
    });

    testWidgets('「?」を押すと、その画面の使い方が開く（5画面）', (tester) async {
      const labels = ['ホーム', '推し', 'ライブ一覧', 'グッズ交換', 'メモリー'];
      for (var i = 0; i < 5; i++) {
        await pumpShell(tester, width: 390, initial: _tops[i]);
        await tester.tap(_key('help_button'));
        await tester.pumpAndSettle();
        expect(find.text('${labels[i]}の使い方'), findsOneWidget);
        await tester.tap(_key('help_sheet_close'));
        await tester.pumpAndSettle();
      }
    });
  });

  group('初回の吹き出し', () {
    testWidgets('ホームで出る（スマホの文言）', (tester) async {
      await pumpShell(tester, width: 390);
      expect(_key('help_coach'), findsOneWidget);
      expect(find.text(_phoneText), findsOneWidget);
      expect(find.text('わかった'), findsOneWidget);
    });

    testWidgets('ホームで出る（PC の文言は「左下」）', (tester) async {
      await pumpShell(tester, width: 1000);
      expect(_key('help_coach'), findsOneWidget);
      expect(find.text(_wideText), findsOneWidget);
      expect(find.text(_phoneText), findsNothing);
    });

    testWidgets('スマホでは「?」の下、PC では「?」の右に出る', (tester) async {
      await pumpShell(tester, width: 390);
      final phoneHelp = tester.getRect(_key('help_button'));
      final phoneCoach = tester.getRect(_key('help_coach'));
      expect(phoneCoach.top, greaterThanOrEqualTo(phoneHelp.bottom - 0.5));

      await pumpShell(tester, width: 1000);
      final wideHelp = tester.getRect(_key('help_button'));
      final wideCoach = tester.getRect(_key('help_coach'));
      expect(wideCoach.left, greaterThanOrEqualTo(wideHelp.right - 0.5));
    });

    testWidgets('「わかった」の押せる範囲は 44 以上', (tester) async {
      await pumpShell(tester, width: 390);
      final size = tester.getSize(_key('help_coach_ok'));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    for (final p in ['/oshi', '/lives', '/trade', '/memories', ..._others]) {
      testWidgets('$p では出ない', (tester) async {
        await pumpShell(tester, width: 390, initial: p);
        expect(_key('help_coach'), findsNothing);
        expect(find.text('わかった'), findsNothing);
      });
    }

    testWidgets('「わかった」で消える', (tester) async {
      await pumpShell(tester, width: 390);
      await tester.tap(_key('help_coach_ok'));
      await tester.pumpAndSettle();
      expect(_key('help_coach'), findsNothing);
      expect(_coachVisible(tester), isFalse);
    });

    testWidgets('「?」を押すと消える（シートは開く）', (tester) async {
      await pumpShell(tester, width: 390);
      await tester.tap(_key('help_button'));
      await tester.pumpAndSettle();
      expect(_key('help_coach'), findsNothing);
      expect(_key('help_sheet'), findsOneWidget);
    });

    testWidgets('PC でも「?」を押すと消える', (tester) async {
      await pumpShell(tester, width: 1000);
      await tester.tap(_key('help_button'));
      await tester.pumpAndSettle();
      expect(_key('help_coach'), findsNothing);
    });

    testWidgets('アカウントのメニューを開くと消える', (tester) async {
      await pumpShell(tester, width: 390);
      await tester.tap(find.byType(AccountMenuButton));
      await tester.pumpAndSettle();
      expect(_key('help_coach'), findsNothing);
    });

    testWidgets('消す前は、ほかの画面へ移って戻ると、また出る', (tester) async {
      final router = await pumpShell(tester, width: 390);
      router.go('/oshi');
      await tester.pumpAndSettle();
      expect(_key('help_coach'), findsNothing);
      router.go('/');
      await tester.pumpAndSettle();
      expect(_key('help_coach'), findsOneWidget);
    });

    testWidgets('消したあとは、ほかの画面へ移って戻っても出ない', (tester) async {
      final router = await pumpShell(tester, width: 390);
      await tester.tap(_key('help_coach_ok'));
      await tester.pumpAndSettle();
      router.go('/oshi');
      await tester.pumpAndSettle();
      router.go('/');
      await tester.pumpAndSettle();
      expect(_key('help_coach'), findsNothing);
    });

    testWidgets('シートが開いている間は出ない', (tester) async {
      await pumpShell(tester, width: 390);
      await tester.tap(_key('help_button'));
      await tester.pumpAndSettle();
      expect(_key('help_coach'), findsNothing);
    });

    testWidgets('幅 320・1000 でもはみ出さない', (tester) async {
      for (final w in [320.0, 1000.0]) {
        await pumpShell(tester, width: w);
        expect(tester.takeException(), isNull, reason: 'w=$w');
      }
    });
  });

  group('未読の数字（グッズ交換のタブ）', () {
    for (final w in [390.0, 1000.0]) {
      testWidgets('幅 ${w.toInt()}: 未読が無ければ出ない', (tester) async {
        await pumpShell(tester, width: w);
        expect(_key('shell_unread_dot'), findsNothing);
      });

      testWidgets('幅 ${w.toInt()}: 未読があるときだけ、グッズ交換のタブに数字が出る', (tester) async {
        await pumpShell(tester, width: w, unread: 3);
        expect(_key('shell_unread_dot'), findsOneWidget);
        expect(
          find.descendant(
            of: _key('shell_tab_3'),
            matching: _key('shell_unread_dot'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('shell_unread_dot'),
            matching: find.text('3'),
          ),
          findsOneWidget,
        );
        for (final i in [0, 1, 2, 4]) {
          expect(
            find.descendant(
              of: _key('shell_tab_$i'),
              matching: _key('shell_unread_dot'),
            ),
            findsNothing,
          );
        }
      });
    }

    testWidgets('99 件を超えたら 99+', (tester) async {
      await pumpShell(tester, width: 390, unread: 120);
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('読み上げは「未読N件」', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpShell(tester, width: 390, unread: 2);
      expect(find.bySemanticsLabel(RegExp('未読2件')), findsOneWidget);
      handle.dispose();
    });
  });
}
