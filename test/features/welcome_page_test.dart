import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/welcome/welcome_page.dart';
import 'package:oshiashi/theme/brand_colors.dart';

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
  // 書体は test/flutter_test_config.dart が、取りに行かない設定にしている
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
}

const _allWidths = [
  320.0,
  360.0,
  390.0,
  430.0,
  520.0,
  521.0,
  760.0,
  761.0,
  1000.0,
  1440.0,
];

void main() {
  testWidgets('表示できる。主なキーが揃い、旧い hako_column は無い', (tester) async {
    await pumpWelcome(tester);
    for (final k in [
      'welcome_page',
      'welcome_login_button',
      'welcome_start_button',
      'welcome_h1',
      'welcome_lead',
      'welcome_board',
      'welcome_flow',
      'welcome_solution',
      'welcome_faq',
      'welcome_cta',
      'welcome_cta_note',
      for (var i = 1; i <= 3; i++) 'welcome_problem1_$i',
      for (var i = 1; i <= 3; i++) 'welcome_problem2_$i',
      for (var i = 1; i <= 3; i++) 'welcome_term_$i',
      for (var i = 1; i <= 6; i++) 'welcome_hall_$i',
      for (var i = 1; i <= 4; i++) 'welcome_faq_$i',
    ]) {
      expect(_key(k), findsOneWidget, reason: k);
    }
    expect(_key('hako_column'), findsNothing);
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

  testWidgets('読み上げ: 「おしあしを始める」は、押せるボタンとして伝わる', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpWelcome(tester);
    await tester.ensureVisible(_key('welcome_start_button'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(_key('welcome_start_button')),
      matchesSemantics(
        label: 'おしあしを始める',
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('4.10 の文言が出る（FAQ の答えは開いてから）', (tester) async {
    await pumpWelcome(tester);
    for (final t in [
      'おしあし',
      'ログイン',
      '推し活の締切をひとつの掲示板にまとめて、次にやることを、ひと目で確認できるアプリです。',
      'NEXT 締切',
      '直近の締切（表示例）',
      '11.20',
      '11.24',
      '11.30',
      '「ひかりの夜」東京公演',
      '「ミナト・ツアー」大阪',
      '「ひかりの夜」追加公演',
      'PROBLEM 01',
      'こんな「うっかり」、ありませんか？',
      '「申込期限、いつだっけ？」',
      'FLOW',
      'チケットの期限は、この順番で管理していきます',
      '申し込む',
      '結果を待つ',
      '支払う',
      'PROBLEM 02',
      'ライブ本番の前に、こんなことありませんか？',
      '「推しのグッズ、手に入らなかった」',
      'SOLUTION',
      'おしあしでできる、6つのこと。',
      'HALL 01',
      'HALL 06',
      '推しをフォロー',
      'スクショで読み取り',
      '次の締切が、ひと目で',
      'みんなで共有',
      'Google カレンダーに追加',
      'グッズ交換',
      'FAQ',
      'よくある質問',
      'スクショは、どんな画像を選べばいいですか？',
      'フォローしたい推しが見つからないときは？',
      '「譲」「求」って何ですか？',
      'ほかのファンが登録したライブは、どう使えますか？',
      'まずは、推しをひとり。',
      '新規登録して、推しをフォローするところから始めましょう。',
      'おしあしを始める',
      '→',
      '新規登録・ログインの画面に進みます。',
    ]) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    expect(find.textContaining('推し活の予定を、', findRichText: true), findsOneWidget);
    expect(find.textContaining('もう逃さない。', findRichText: true), findsOneWidget);
    expect(find.text('追加の申請を送れます。'), findsNothing, reason: '答えは閉じている');
    await tester.ensureVisible(_key('welcome_faq_2'));
    await tester.pump();
    await tester.tap(_key('welcome_faq_2'));
    await tester.pump();
    expect(find.text('追加の申請を送れます。'), findsOneWidget);
  });

  testWidgets('出さないもの（バッジ・文言案・旧い文言・画像・旧キー）', (tester) async {
    await pumpWelcome(tester);
    for (final t in [
      '案C 改',
      'おしあし — ログイン前画面 文言案',
      "TODAY'S 締切",
      '6つのハコ、まとめて入場。',
      '申込、当落、入金。ばらばらの締切を、ひとつの掲示板にまとめます。',
    ]) {
      expect(
        find.textContaining(t, findRichText: true),
        findsNothing,
        reason: t,
      );
    }
    expect(find.textContaining('文言案'), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(_key('hako_column'), findsNothing);
    // 半角の ? ( ) を使わない（全角にする）
    expect(find.textContaining('?'), findsNothing);
    expect(find.textContaining('('), findsNothing);
    expect(find.textContaining('（表示例）'), findsOneWidget);
  });

  testWidgets('動きが無い', (tester) async {
    await pumpWelcome(tester);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.hasRunningAnimations, isFalse);
  });

  group('大きさ（幅 390・計画書 4.4・4.8・4.11）', () {
    testWidgets('見出し 40px・96 の高さ・ヘッダー 79・掲示板 196.7・ボタン 94.4', (tester) async {
      await pumpWelcome(tester, size: const Size(390, 900));
      expect(tester.takeException(), isNull);
      // ヘッダー（上 28 ＋ ロゴの行 51）。SafeArea の上は 0
      final login = tester.getRect(_key('welcome_login_button'));
      expect(login.height, greaterThanOrEqualTo(44));
      final logo = tester.getRect(find.text('おしあし').first);
      expect(logo.top, closeTo(28 + (51 - logo.height) / 2, 8));
      final h1 = tester.getRect(_key('welcome_h1'));
      expect(h1.top, closeTo(79 + 56, 8), reason: '見出しの上端 135');
      expect(h1.height, closeTo(96, 8));
      final h1Text = tester.widget<Text>(find.text('推し活の予定を、'));
      expect(h1Text.style?.fontSize, 40);
      expect(h1Text.style?.height, 1.2);
      expect(tester.getRect(_key('welcome_board')).height, closeTo(196.7, 8));
      await tester.ensureVisible(_key('welcome_start_button'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(_key('welcome_start_button')).height,
        closeTo(94.4, 1),
      );
    });

    testWidgets('幅 1000: 見出し 68px・高さ 163.2、掲示板の幅は 912', (tester) async {
      await pumpWelcome(tester, size: const Size(1000, 900));
      final h1Text = tester.widget<Text>(find.text('推し活の予定を、'));
      expect(h1Text.style?.fontSize, 68);
      expect(tester.getRect(_key('welcome_h1')).height, closeTo(163.2, 8));
      expect(tester.getRect(_key('welcome_board')).width, closeTo(912, 0.01));
    });

    testWidgets('幅 1440: 掲示板の幅は 912（最大 960 − 余白）で中央・ハコは全幅', (tester) async {
      await pumpWelcome(tester, size: const Size(1440, 900));
      final board = tester.getRect(_key('welcome_board'));
      expect(board.width, closeTo(912, 0.01));
      expect(board.center.dx, closeTo(720, 0.01));
      final hall1 = tester.getRect(_key('welcome_hall_1'));
      final hall3 = tester.getRect(_key('welcome_hall_3'));
      expect(hall1.left, 0);
      expect(hall3.right, 1440);
    });

    testWidgets('幅 390: 余白は 18、幅 521: 余白は 24', (tester) async {
      await pumpWelcome(tester, size: const Size(390, 900));
      expect(tester.getRect(_key('welcome_board')).left, 18);
      expect(
        tester.getRect(_key('welcome_login_button')).right,
        closeTo(390 - 18, 0.01),
      );
      await pumpWelcome(tester, size: const Size(521, 900));
      expect(tester.getRect(_key('welcome_board')).left, 24);
    });

    testWidgets('ボタンの文字は 幅 520 以下で 21・521 以上で 26', (tester) async {
      await pumpWelcome(tester, size: const Size(520, 900));
      expect(tester.widget<Text>(find.text('おしあしを始める')).style?.fontSize, 21);
      await pumpWelcome(tester, size: const Size(521, 900));
      expect(tester.widget<Text>(find.text('おしあしを始める')).style?.fontSize, 26);
    });
  });

  for (final c in [
    (w: 390.0, g: 18.0),
    (w: 520.0, g: 18.0),
    (w: 521.0, g: 24.0),
    (w: 1000.0, g: 24.0),
    (w: 1440.0, g: 24.0),
  ]) {
    testWidgets('幅 ${c.w}: ヘッダーは画面の左右の端から ${c.g} の余白で、上 28', (tester) async {
      await pumpWelcome(tester, size: Size(c.w, 900));
      expect(tester.takeException(), isNull);
      final logo = tester.getRect(find.text('おしあし').first);
      final login = tester.getRect(_key('welcome_login_button'));
      expect(logo.left, closeTo(c.g, 0.5), reason: 'おしあし');
      expect(login.right, closeTo(c.w - c.g, 0.5), reason: 'ログイン');
      expect(login.height, greaterThanOrEqualTo(44));
      expect(login.top, greaterThanOrEqualTo(28));
    });
  }

  testWidgets('黒い帯（SOLUTION・CTA）は全幅、紙は全幅', (tester) async {
    await pumpWelcome(tester, size: const Size(1440, 900));
    expect(tester.getSize(_key('welcome_solution')).width, 1440);
    final cta = find.ancestor(
      of: _key('welcome_cta'),
      matching: find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == BrandColors.ink,
      ),
    );
    expect(cta, findsOneWidget);
    expect(tester.getSize(cta).width, 1440);
    final scaffold = tester.widget<Scaffold>(_key('welcome_page'));
    expect(scaffold.backgroundColor, BrandColors.paper);
  });

  testWidgets('「始める」ボタンは黄の地・赤の硬い影 6px', (tester) async {
    await pumpWelcome(tester);
    await tester.ensureVisible(_key('welcome_start_button'));
    await tester.pumpAndSettle();
    final shadowBox = tester
        .widgetList<DecoratedBox>(
          find.ancestor(
            of: _key('welcome_start_button'),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.boxShadow != null)
        .single;
    expect(shadowBox.boxShadow!.single.color, BrandColors.hall1);
    expect(shadowBox.boxShadow!.single.offset, const Offset(6, 6));
    expect(shadowBox.boxShadow!.single.blurRadius, 0);
    final material = tester.widget<Material>(
      find
          .ancestor(
            of: _key('welcome_start_button'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, BrandColors.hall3);
  });

  group('はみ出さない・横スクロールが出ない', () {
    for (final scale in [1.0, 1.3]) {
      testWidgets('文字 $scale 倍で、どの幅でも例外が出ない', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (final w in _allWidths) {
          await pumpWelcome(tester, size: Size(w, 800));
          expect(tester.takeException(), isNull, reason: '幅 $w');
          // 横にスクロールする入れ物は、縦の 1 つだけ
          final scrollables = tester.widgetList<Scrollable>(
            find.byType(Scrollable),
          );
          for (final s in scrollables) {
            expect(s.axis, Axis.vertical, reason: '幅 $w');
          }
          // 主な部品が画面の幅の外に出ない
          for (final k in ['welcome_board', 'welcome_login_button']) {
            final r = tester.getRect(_key(k));
            expect(r.left, greaterThanOrEqualTo(0), reason: '幅 $w $k');
            expect(r.right, lessThanOrEqualTo(w + 0.01), reason: '幅 $w $k');
          }
        }
      });
    }

    testWidgets('幅ごとに、全区画の部品が画面の幅の中に収まる', (tester) async {
      for (final w in _allWidths) {
        await pumpWelcome(tester, size: Size(w, 800));
        for (final k in [
          for (var i = 1; i <= 3; i++) 'welcome_problem1_$i',
          for (var i = 1; i <= 3; i++) 'welcome_problem2_$i',
          'welcome_flow',
          'welcome_solution',
          for (var i = 1; i <= 6; i++) 'welcome_hall_$i',
          'welcome_faq_1',
          'welcome_start_button',
        ]) {
          final r = tester.getRect(_key(k));
          expect(r.left, greaterThanOrEqualTo(-0.01), reason: '幅 $w $k');
          expect(r.right, lessThanOrEqualTo(w + 0.01), reason: '幅 $w $k');
        }
      }
    });
  });
}
