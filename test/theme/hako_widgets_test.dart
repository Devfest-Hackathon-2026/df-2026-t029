import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oshiashi/theme/brand_colors.dart';
import 'package:oshiashi/theme/google_logo.dart';
import 'package:oshiashi/theme/hako_widgets.dart';

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  // 送信中のくるくるは止まらないので pumpAndSettle は使わない
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ColorStrip', () {
    testWidgets('高さ 10 で、hall1〜hall6 の 6色が順に並ぶ', (tester) async {
      await pump(tester, const Scaffold(body: ColorStrip()));
      expect(tester.getSize(find.byType(ColorStrip)).height, 10);
      final colors = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byType(ColorStrip),
              matching: find.byType(ColoredBox),
            ),
          )
          .map((b) => b.color)
          .toList();
      expect(colors, BrandColors.halls);
      expect(colors, [
        BrandColors.hall1,
        BrandColors.hall2,
        BrandColors.hall3,
        BrandColors.hall4,
        BrandColors.hall5,
        BrandColors.hall6,
      ]);
    });
  });

  group('HakoTab', () {
    testWidgets('選ばれている札は墨の背景・白い文字、選ばれていない札は白い背景', (tester) async {
      await pump(
        tester,
        Scaffold(
          // 実画面と同じく、縦に制約の無い場所（スクロールの中）に置く
          body: SingleChildScrollView(
            child: Row(
              children: [
                Expanded(
                  child: HakoTab(
                    key: const Key('t1'),
                    label: 'ログイン',
                    selected: true,
                    onPressed: () {},
                  ),
                ),
                Expanded(
                  child: HakoTab(
                    key: const Key('t2'),
                    label: '新規登録',
                    selected: false,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      Color bg(String k) => tester
          .widget<Material>(
            find.descendant(
              of: find.byKey(Key(k)),
              matching: find.byType(Material),
            ),
          )
          .color!;
      expect(bg('t1'), BrandColors.ink);
      expect(bg('t2'), Colors.white);
      expect(tester.getSize(find.byKey(const Key('t1'))).height, 48);
    });

    testWidgets('押すと onPressed が呼ばれ、null のときは何も起きない', (tester) async {
      var taps = 0;
      await pump(
        tester,
        Scaffold(
          body: Column(
            children: [
              HakoTab(
                key: const Key('on'),
                label: 'A',
                selected: false,
                onPressed: () => taps++,
              ),
              const HakoTab(
                key: Key('off'),
                label: 'B',
                selected: false,
                onPressed: null,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('on')));
      await tester.tap(find.byKey(const Key('off')), warnIfMissed: false);
      expect(taps, 1);
      expect(
        tester.widget<HakoTab>(find.byKey(const Key('off'))).onPressed,
        isNull,
      );
    });

    testWidgets('読み上げでは選択中のボタンとして伝える', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        Scaffold(
          body: HakoTab(
            key: const Key('t'),
            label: 'ログイン',
            selected: true,
            onPressed: () {},
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('t'))),
        matchesSemantics(
          label: 'ログイン',
          isButton: true,
          isSelected: true,
          isEnabled: true,
          hasEnabledState: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('HakoPrimaryButton', () {
    testWidgets('押すと呼ばれる。ラベルとくるくるは子孫にある', (tester) async {
      var taps = 0;
      await pump(
        tester,
        Scaffold(
          body: HakoPrimaryButton(
            key: const Key('b'),
            label: 'ログイン',
            onPressed: () => taps++,
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('b')),
          matching: find.text('ログイン'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('b')));
      expect(taps, 1);
      expect(tester.getSize(find.byType(FilledButton)).height, 54);
    });

    testWidgets('送信中は、くるくるを出し、ラベルを消し、押しても呼ばれない', (tester) async {
      var taps = 0;
      await pump(
        tester,
        Scaffold(
          body: HakoPrimaryButton(
            key: const Key('b'),
            label: 'ログイン',
            busy: true,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('b')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.text('ログイン'), findsNothing);
      await tester.tap(find.byKey(const Key('b')), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('onPressed が null のときは押せず、半透明', (tester) async {
      await pump(
        tester,
        const Scaffold(
          body: HakoPrimaryButton(
            key: Key('b'),
            label: 'ログイン',
            onPressed: null,
          ),
        ),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
        isFalse,
      );
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.5);
    });
  });

  group('HakoPill', () {
    testWidgets('押せる範囲の高さが 44 以上で、押すと呼ばれる', (tester) async {
      var taps = 0;
      await pump(
        tester,
        Scaffold(
          body: Center(
            child: HakoPill(
              key: const Key('p'),
              label: '戻る',
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('p'))).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.byKey(const Key('p')));
      expect(taps, 1);
    });
  });

  group('GoogleLogo', () {
    testWidgets('描いても例外が出ず、指定の大きさで、読み上げない', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const Scaffold(body: GoogleLogo(size: 20)));
      expect(tester.takeException(), isNull);
      final box = find.descendant(
        of: find.byType(GoogleLogo),
        matching: find.byType(CustomPaint),
      );
      expect(tester.getSize(box.first), const Size(20, 20));
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
      handle.dispose();
    });
  });

  group('HakoPage', () {
    testWidgets('幅 800 では紙（hako_column）と色の帯が全幅', (tester) async {
      await pump(
        tester,
        const HakoPage(child: Text('中身')),
        size: const Size(800, 900),
      );
      expect(tester.getSize(find.byKey(const Key('hako_column'))).width, 800);
      for (final strip in find.byType(ColorStrip).evaluate()) {
        expect(tester.getSize(find.byWidget(strip.widget)).width, 800);
      }
      expect(find.text('中身'), findsOneWidget);
      expect(find.byType(ColorStrip), findsNWidgets(2));
    });

    testWidgets('スマホの幅では画面いっぱい。中身が短くても紙が画面の高さまで伸びる', (tester) async {
      await pump(
        tester,
        const HakoPage(child: Text('中身')),
        size: const Size(360, 700),
      );
      final rect = tester.getRect(find.byKey(const Key('hako_column')));
      expect(rect.width, 360);
      expect(rect.height, 700);
      // 下の色の帯が画面の下に来る
      expect(tester.getRect(find.byType(ColorStrip).last).bottom, 700);
      expect(tester.takeException(), isNull);
    });

    testWidgets('背景は backdrop、列は paper', (tester) async {
      await pump(tester, const HakoPage(child: SizedBox()));
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        BrandColors.backdrop,
      );
      expect(
        tester.widget<ColoredBox>(find.byKey(const Key('hako_column'))).color,
        BrandColors.paper,
      );
    });
  });

  group('HakoContent', () {
    testWidgets('幅 800 では 430 に絞って中央に置く', (tester) async {
      await pump(
        tester,
        const HakoPage(
          child: HakoContent(
            child: SizedBox(key: Key('c'), width: double.infinity, height: 50),
          ),
        ),
        size: const Size(800, 900),
      );
      final rect = tester.getRect(find.byKey(const Key('c')));
      expect(rect.width, 430);
      expect(rect.center.dx, closeTo(400, 0.5));
    });

    testWidgets('スマホの幅（360）では画面いっぱい', (tester) async {
      await pump(
        tester,
        const HakoPage(
          child: HakoContent(
            child: SizedBox(key: Key('c'), width: double.infinity, height: 50),
          ),
        ),
        size: const Size(360, 700),
      );
      expect(tester.getRect(find.byKey(const Key('c'))).width, 360);
    });
  });
}
