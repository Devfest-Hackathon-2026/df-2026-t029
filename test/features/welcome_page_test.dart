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

  // 「始める」の nudge は止まらない動きなので、テストでは動きを切る
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('表示できる。フォントの例外も出ない', (tester) async {
    await pumpWelcome(tester);
    expect(_key('welcome_page'), findsOneWidget);
    expect(_key('welcome_start_button'), findsOneWidget);
    expect(_key('welcome_login_button'), findsOneWidget);
    expect(_key('hako_column'), findsOneWidget);
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

  testWidgets('6つのハコの見出し・説明・番号・英字が出る', (tester) async {
    await pumpWelcome(tester);
    const halls = [
      ('推しをフォロー', '推しを探してフォロー。見つからなければ追加を申請できます。', 'FOLLOW'),
      ('スクショから読み取り', '告知画像やチケットサイトのスクショから、日程・申込期限・入金期限を AI が読み取ります。', 'SCAN'),
      ('次の締切が、ひと目で', '申込 → 当落 → 入金。次にやることの期限が分かります。', 'DUE'),
      ('みんなで共有', '同じ推しのファンが登録したライブを、自分の一覧に追加できます。', 'SHARE'),
      ('Google カレンダーに追加', null, 'CALENDAR'),
      ('グッズ交換', '「譲」「求」を登録すると、交換できる相手が見つかります。', 'TRADE'),
    ];
    for (var i = 0; i < halls.length; i++) {
      final hall = _key('welcome_hall_${i + 1}');
      expect(hall, findsOneWidget);
      await tester.ensureVisible(hall);
      await tester.pump();
      Finder inHall(Finder f) => find.descendant(of: hall, matching: f);
      expect(inHall(find.text(halls[i].$1)), findsOneWidget, reason: '$i 見出し');
      if (halls[i].$2 != null) {
        expect(
          inHall(find.text(halls[i].$2!)),
          findsOneWidget,
          reason: '$i 説明',
        );
      }
      expect(inHall(find.text('HALL 0${i + 1}')), findsOneWidget);
      expect(inHall(find.text(halls[i].$3)), findsOneWidget);
    }
  });

  testWidgets('「くわしく →」は作らない（5.1 案C）', (tester) async {
    await pumpWelcome(tester);
    expect(find.textContaining('くわしく'), findsNothing);
    expect(_key('welcome_more_1'), findsNothing);
    expect(_key('welcome_more_3'), findsNothing);
  });

  testWidgets('掲示板に締切の3行が出る（架空の名前）', (tester) async {
    await pumpWelcome(tester);
    final board = _key('welcome_board');
    expect(board, findsOneWidget);
    Finder inBoard(Finder f) => find.descendant(of: board, matching: f);
    for (final t in ['11.20', '11.24', '11.30', '入金', '申込', '当落']) {
      expect(inBoard(find.text(t)), findsOneWidget, reason: t);
    }
    expect(inBoard(find.textContaining('ひかりの夜')), findsNWidgets(2));
    expect(inBoard(find.textContaining('ミナト・ツアー')), findsOneWidget);
  });

  testWidgets('最初の画面の見出しとリード文が出る', (tester) async {
    await pumpWelcome(tester);
    expect(find.textContaining('推し活の予定を、', findRichText: true), findsOneWidget);
    expect(find.textContaining('もう逃さない。', findRichText: true), findsOneWidget);
    expect(find.text('申込、当落、入金。ばらばらの締切を、ひとつの掲示板にまとめます。'), findsOneWidget);
  });

  testWidgets('写真・SCROLL の案内・旧い説明・reCAPTCHA の文言は無い', (tester) async {
    await pumpWelcome(tester);
    expect(_key('welcome_scroll_hint'), findsNothing);
    expect(find.text('SCROLL'), findsNothing);
    expect(find.byType(Image), findsNothing);
    await tester.ensureVisible(_key('welcome_start_button'));
    await tester.pumpAndSettle();
    expect(find.text('メールアドレスか Google アカウントで始められます。'), findsNothing);
    expect(_key('welcome_recaptcha_notice'), findsNothing);
    expect(
      find.textContaining('reCAPTCHA で保護されており', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('「始める」の上に一行の案内が出る', (tester) async {
    await pumpWelcome(tester);
    await tester.ensureVisible(_key('welcome_start_button'));
    await tester.pumpAndSettle();
    expect(find.text('6つのハコ、まとめて入場。'), findsOneWidget);
    expect(_key('welcome_cta_note'), findsOneWidget);
  });

  testWidgets('動きを切ると pumpAndSettle が終わる', (tester) async {
    await pumpWelcome(tester);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  // 左右の余白は 20（〜599）・40（〜899）・64（900〜）、中身は最大 1100 で中央
  double gutterOf(double w) => w >= 900 ? 64 : (w >= 600 ? 40 : 20);
  double contentWidthOf(double w) {
    final c = w - 2 * gutterOf(w);
    return c < 1100 ? c : 1100;
  }

  for (final w in [320.0, 360.0, 430.0, 599.0, 600.0, 900.0, 1280.0, 1920.0]) {
    testWidgets('幅 $w: ヘッダー・掲示板・「始める」は余白を取り、最大 1100 で中央', (tester) async {
      await pumpWelcome(tester, size: Size(w, 800));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(_key('hako_column')).width, w);
      final cw = contentWidthOf(w);
      final left = (w - cw) / 2;
      // ヘッダーは両端そろえ（左右の余白だけ空け、最大幅では絞らない）
      final g = gutterOf(w);
      final name = tester.getRect(find.text('おしあし').first);
      final login = tester.getRect(_key('welcome_login_button'));
      expect(name.left, closeTo(g, 1), reason: 'おしあし');
      expect(login.right, closeTo(w - g, 1), reason: 'ログイン');
      expect(login.height, greaterThanOrEqualTo(44));
      // 掲示板は中身の幅の中
      final board = tester.getRect(_key('welcome_board'));
      expect(board.left, greaterThanOrEqualTo(left - 0.5));
      expect(board.right, lessThanOrEqualTo(left + cw + 0.5));
      await tester.ensureVisible(_key('welcome_start_button'));
      await tester.pumpAndSettle();
      final r = tester.getRect(_key('welcome_start_button'));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(w));
      expect(r.width, lessThanOrEqualTo(cw + 0.5));
      expect(r.center.dx, closeTo(w / 2, 0.5));
      expect(tester.takeException(), isNull);
    });
  }

  // 6つのハコの列組み: 幅 600 以上は3列（2行）、600 未満は1列
  for (final c in [
    (w: 320.0, cols: 1),
    (w: 390.0, cols: 1),
    (w: 599.0, cols: 1),
    (w: 600.0, cols: 3),
    (w: 700.0, cols: 3),
    (w: 899.0, cols: 3),
    (w: 900.0, cols: 3),
    (w: 1280.0, cols: 3),
  ]) {
    testWidgets('幅 ${c.w}: ハコは ${c.cols} 列で、同じ行の高さがそろう', (tester) async {
      await pumpWelcome(tester, size: Size(c.w, 900));
      expect(tester.takeException(), isNull);
      final rects = [
        for (var i = 1; i <= 6; i++) tester.getRect(_key('welcome_hall_$i')),
      ];
      for (var i = 0; i < 6; i++) {
        final row = i ~/ c.cols;
        final first = rects[row * c.cols];
        expect(rects[i].top, closeTo(first.top, 0.5), reason: 'ハコ${i + 1} top');
        expect(
          rects[i].height,
          closeTo(first.height, 0.5),
          reason: 'ハコ${i + 1} 高さ',
        );
        if (row > 0) {
          expect(rects[i].top, greaterThan(rects[(row - 1) * c.cols].top));
        }
        expect(rects[i].width, closeTo(c.w / c.cols, 1), reason: 'ハコ${i + 1}');
      }
      expect(rects.first.left, 0);
      expect(rects[c.cols - 1].right, closeTo(c.w, 0.5));
    });
  }

  testWidgets('幅 1280 では、ハコ 1〜3 が上の行、4〜6 が次の行', (tester) async {
    await pumpWelcome(tester, size: const Size(1280, 900));
    final tops = [
      for (var i = 1; i <= 6; i++) tester.getRect(_key('welcome_hall_$i')).top,
    ];
    expect(tops[1], tops[0]);
    expect(tops[2], tops[0]);
    expect(tops[3], tops[4]);
    expect(tops[3], tops[5]);
    expect(tops[3], greaterThan(tops[0]));
  });

  testWidgets('どの幅でも例外が出ない（文字 1.0 倍）', (tester) async {
    for (final w in [
      320.0,
      360.0,
      599.0,
      600.0,
      700.0,
      899.0,
      900.0,
      1000.0,
      1280.0,
      1920.0,
    ]) {
      await pumpWelcome(tester, size: Size(w, 800));
      expect(tester.takeException(), isNull, reason: '幅 $w');
    }
  });

  testWidgets('文字を 1.3 倍にしても例外が出ない', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final w in [
      320.0,
      360.0,
      599.0,
      600.0,
      700.0,
      899.0,
      900.0,
      1000.0,
      1280.0,
      1920.0,
    ]) {
      await pumpWelcome(tester, size: Size(w, 800));
      expect(tester.takeException(), isNull, reason: '幅 $w');
    }
  });
}
