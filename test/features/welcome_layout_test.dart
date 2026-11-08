import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/welcome/welcome_layout.dart';
import 'package:oshiashi/theme/brand_colors.dart';

Future<void> pumpAt(WidgetTester tester, double width, Widget child) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('WelcomeBreakpoints', () {
    test('tileColumns は 520 以下 1・521〜760 で 2・761 以上 3', () {
      final expected = {
        320.0: 1,
        520.0: 1,
        521.0: 2,
        760.0: 2,
        761.0: 3,
        1440.0: 3,
      };
      expected.forEach((w, cols) {
        expect(WelcomeBreakpoints.tileColumns(w), cols, reason: '幅 $w');
      });
    });

    test('isStacked は 760 以下、isPhone は 520 以下', () {
      expect(WelcomeBreakpoints.isStacked(760), isTrue);
      expect(WelcomeBreakpoints.isStacked(761), isFalse);
      expect(WelcomeBreakpoints.isPhone(520), isTrue);
      expect(WelcomeBreakpoints.isPhone(521), isFalse);
    });
  });

  group('welcomeClamp', () {
    test('8vw（40〜68）は幅 390・640・850 で 40・51.2・68', () {
      double h1(double w) => welcomeClamp(w, min: 40, vw: 8, max: 68);
      expect(h1(390), 40);
      expect(h1(640), closeTo(51.2, 0.001));
      expect(h1(850), 68);
      expect(h1(1440), 68);
    });
  });

  group('WelcomeWrap', () {
    const key = Key('inner');
    Widget inner() =>
        const SizedBox(key: key, width: double.infinity, height: 10);

    for (final c in [
      (w: 1440.0, inner: 912.0),
      (w: 390.0, inner: 354.0),
      (w: 600.0, inner: 552.0),
      (w: 520.0, inner: 484.0),
      (w: 521.0, inner: 473.0),
    ]) {
      testWidgets('幅 ${c.w} で中身の幅は ${c.inner}', (tester) async {
        await pumpAt(tester, c.w, WelcomeWrap(child: inner()));
        expect(tester.getSize(find.byKey(key)).width, closeTo(c.inner, 0.01));
        final left = tester.getTopLeft(find.byKey(key)).dx;
        expect(left, closeTo((c.w - c.inner) / 2, 0.01), reason: '中央');
      });
    }
  });

  group('WelcomeWrap の左端', () {
    for (final c in [
      (w: 1000.0, left: 44.0),
      (w: 1440.0, left: 264.0),
      (w: 390.0, left: 18.0),
      (w: 600.0, left: 24.0),
    ]) {
      testWidgets('幅 ${c.w}: 幅の狭い左寄せの子も、中身の左端（${c.left}）から始まる', (tester) async {
        await pumpAt(
          tester,
          c.w,
          const WelcomeWrap(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text('短い', key: Key('short'))],
            ),
          ),
        );
        expect(
          tester.getTopLeft(find.byKey(const Key('short'))).dx,
          closeTo(c.left, 0.5),
        );
      });
    }
  });

  group('WelcomeGrid', () {
    Widget cell(int i, double h) =>
        SizedBox(key: Key('c$i'), height: h, child: const SizedBox.expand());

    testWidgets('同じ行の高さがそろい、列の数・隙間のとおりに並ぶ', (tester) async {
      // 1 行目の高さは 30 と 80 → 80 にそろう
      final heights = [30.0, 80.0, 20.0, 10.0, 50.0];
      await pumpAt(
        tester,
        400,
        WelcomeGrid(
          columns: 2,
          gap: 16,
          itemCount: 5,
          itemBuilder: (_, i) => ColoredBox(
            key: Key('c$i'),
            color: Colors.red,
            child: SizedBox(height: heights[i]),
          ),
        ),
      );
      final r = [
        for (var i = 0; i < 5; i++) tester.getRect(find.byKey(Key('c$i'))),
      ];
      const cellW = (400 - 16) / 2;
      expect(r[0].width, closeTo(cellW, 0.01));
      expect(r[1].left, closeTo(cellW + 16, 0.01));
      expect(r[0].height, 80);
      expect(r[1].height, 80);
      expect(r[2].top, closeTo(r[0].bottom + 16, 0.01), reason: '行の間も gap');
      expect(r[2].height, 20);
      expect(r[3].height, 20);
      expect(r[4].top, closeTo(r[2].bottom + 16, 0.01));
      expect(r[4].left, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('隙間 0・3 列なら幅を 3 等分する', (tester) async {
      await pumpAt(
        tester,
        900,
        WelcomeGrid(
          columns: 3,
          itemCount: 6,
          itemBuilder: (_, i) => cell(i, 10),
        ),
      );
      for (var i = 0; i < 6; i++) {
        final r = tester.getRect(find.byKey(Key('c$i')));
        expect(r.width, closeTo(300, 0.01));
        expect(r.left, closeTo((i % 3) * 300, 0.01));
        expect(r.top, closeTo((i ~/ 3) * 10, 0.01));
      }
    });
  });

  group('WelcomeMark', () {
    testWidgets('帯は文字の大きさの 20%（高さ 1.2 の行では下から 10%）', (tester) async {
      const size = 40.0;
      final style = welcomeJp(size: size, weight: FontWeight.w700, height: 1.2);
      await pumpAt(
        tester,
        400,
        Align(
          alignment: Alignment.topLeft,
          child: WelcomeMark(
            key: const Key('mark'),
            text: 'もう逃さない。',
            style: style,
            color: BrandColors.hall3,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final band = find.descendant(
        of: find.byKey(const Key('mark')),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == BrandColors.hall3,
        ),
      );
      expect(band, findsOneWidget);
      final markRect = tester.getRect(find.byKey(const Key('mark')));
      final bandRect = tester.getRect(band);
      expect(bandRect.height, closeTo(size * 0.2, 0.01));
      expect(markRect.bottom - bandRect.bottom, closeTo(size * 0.1, 0.01));
      // 右に size×0.15 の余白があり、帯は左〜右いっぱい
      expect(bandRect.left, markRect.left);
      expect(bandRect.right, markRect.right);
      final text = tester.getRect(find.text('もう逃さない。'));
      expect(markRect.right - text.right, closeTo(size * 0.15, 0.01));
    });

    testWidgets('行の高さ 1.4（SOLUTION）では帯が下から 20%', (tester) async {
      const size = 30.0;
      final style = welcomeJp(size: size, height: 1.4);
      await pumpAt(
        tester,
        400,
        Align(
          alignment: Alignment.topLeft,
          child: WelcomeMark(
            key: const Key('mark'),
            text: 'おしあし',
            style: style,
            color: BrandColors.hall1,
          ),
        ),
      );
      final band = find.descendant(
        of: find.byKey(const Key('mark')),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == BrandColors.hall1,
        ),
      );
      final markRect = tester.getRect(find.byKey(const Key('mark')));
      expect(
        markRect.bottom - tester.getRect(band).bottom,
        closeTo(size * 0.2, 0.01),
      );
    });
  });
}
