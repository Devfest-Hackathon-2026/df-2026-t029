import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/welcome/welcome_features.dart';
import 'package:oshiashi/features/welcome/welcome_story.dart';
import 'package:oshiashi/theme/brand_colors.dart';

Finder _key(String k) => find.byKey(Key(k));

/// 紹介ページの区画を縦に並べて出す（ページ全体と同じく、縦にスクロールできる）
Future<void> pumpSections(
  WidgetTester tester,
  double width, {
  required List<Widget> children,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: BrandColors.paper,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color _shadowOf(WidgetTester tester, String key) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: _key(key), matching: find.byType(DecoratedBox)).first,
  );
  final decoration = box.decoration as BoxDecoration;
  expect(decoration.boxShadow, hasLength(1), reason: key);
  final shadow = decoration.boxShadow!.single;
  expect(shadow.offset, const Offset(5, 5), reason: '$key 影の位置');
  expect(shadow.blurRadius, 0, reason: '$key 硬い影');
  return shadow.color;
}

void main() {
  group('困りごと（PROBLEM 01・02）', () {
    for (final c in [
      (prefix: 'welcome_problem1', shadow: BrandColors.ink),
      (prefix: 'welcome_problem2', shadow: BrandColors.hall6),
    ]) {
      testWidgets('${c.prefix}: 幅 1000 で横 3 列・影の色', (tester) async {
        await pumpSections(
          tester,
          1000,
          children: [
            if (c.prefix.endsWith('1'))
              const WelcomeProblemSection()
            else
              const WelcomeGoodsProblemSection(),
          ],
        );
        expect(tester.takeException(), isNull);
        final r = [
          for (var i = 1; i <= 3; i++) tester.getRect(_key('${c.prefix}_$i')),
        ];
        expect(r[1].top, r[0].top);
        expect(r[2].top, r[0].top);
        expect(r[1].left, closeTo(r[0].right + 16, 0.5));
        expect(r[2].left, closeTo(r[1].right + 16, 0.5));
        expect(r[0].height, closeTo(r[1].height, 0.01), reason: '高さがそろう');
        expect(r[0].height, closeTo(r[2].height, 0.01));
        for (var i = 1; i <= 3; i++) {
          expect(_shadowOf(tester, '${c.prefix}_$i'), c.shadow);
        }
      });

      testWidgets('${c.prefix}: 幅 390 で縦 1 列（間 16）', (tester) async {
        await pumpSections(
          tester,
          390,
          children: [
            if (c.prefix.endsWith('1'))
              const WelcomeProblemSection()
            else
              const WelcomeGoodsProblemSection(),
          ],
        );
        expect(tester.takeException(), isNull);
        final r = [
          for (var i = 1; i <= 3; i++) tester.getRect(_key('${c.prefix}_$i')),
        ];
        for (var i = 0; i < 3; i++) {
          expect(r[i].left, 18);
          expect(r[i].width, closeTo(354, 0.01));
        }
        expect(r[1].top, closeTo(r[0].bottom + 16, 0.5));
        expect(r[2].top, closeTo(r[1].bottom + 16, 0.5));
      });
    }

    testWidgets('見出し・説明・3 枚の文言が出る', (tester) async {
      await pumpSections(
        tester,
        390,
        children: const [WelcomeProblemSection(), WelcomeGoodsProblemSection()],
      );
      for (final t in [
        'PROBLEM 01',
        'こんな「うっかり」、ありませんか？',
        '推し活は楽しい分、気をつけることがたくさん。おしあしは、その「うっかり」を減らすためのアプリです。',
        '「申込期限、いつだっけ？」',
        '「当選したのに、入金を忘れた」',
        '「ライブが増えて、整理できない」',
        'PROBLEM 02',
        'ライブ本番の前に、こんなことありませんか？',
        'チケットが取れても、推し活の悩みはまだあります。ライブの日が近づくほど気になるのが、グッズのこと。',
        '「推しのグッズ、手に入らなかった」',
        '「誰かとグッズを交換したい」',
        '「持っている人が、見つからない」',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
    });
  });

  group('期限の流れ（FLOW）', () {
    testWidgets('幅 1000: 横 3 列・区画の高さがそろう・矢印 2 つが線の中央', (tester) async {
      await pumpSections(tester, 1000, children: const [WelcomeFlowSection()]);
      expect(tester.takeException(), isNull);
      final r = [
        for (var i = 1; i <= 3; i++) tester.getRect(_key('welcome_term_$i')),
      ];
      expect(r[1].top, r[0].top);
      expect(r[2].top, r[0].top);
      expect(r[1].left, closeTo(r[0].right, 0.5));
      expect(r[0].height, closeTo(r[1].height, 0.01));
      expect(r[0].height, closeTo(r[2].height, 0.01));
      final flow = find.descendant(
        of: _key('welcome_flow'),
        matching: find.text('→'),
      );
      expect(flow, findsNWidgets(2));
      expect(find.text('↓'), findsNothing);
      // 区画の左端の 1px 外（線の中央）に円の中心がある
      final centers = [
        for (var i = 0; i < 2; i++) tester.getCenter(flow.at(i)),
      ];
      expect(centers[0].dx, closeTo(r[1].left - 1, 1));
      expect(centers[1].dx, closeTo(r[2].left - 1, 1));
      expect(centers[0].dy, closeTo(r[0].center.dy, 1));
    });

    testWidgets('幅 390: 縦に積む・矢印は ↓ で線の中央', (tester) async {
      await pumpSections(tester, 390, children: const [WelcomeFlowSection()]);
      expect(tester.takeException(), isNull);
      final r = [
        for (var i = 1; i <= 3; i++) tester.getRect(_key('welcome_term_$i')),
      ];
      expect(r[1].top, closeTo(r[0].bottom, 0.5));
      expect(r[2].top, closeTo(r[1].bottom, 0.5));
      expect(r[0].width, closeTo(r[1].width, 0.01));
      final arrows = find.text('↓');
      expect(arrows, findsNWidgets(2));
      expect(find.text('→'), findsNothing);
      expect(tester.getCenter(arrows.at(0)).dy, closeTo(r[1].top - 1, 1));
      expect(tester.getCenter(arrows.at(1)).dy, closeTo(r[2].top - 1, 1));
    });

    testWidgets('文言が出る', (tester) async {
      await pumpSections(tester, 390, children: const [WelcomeFlowSection()]);
      for (final t in [
        'FLOW',
        'チケットの期限は、この順番で管理していきます',
        'はじめての方も安心。申込・当落・入金、それぞれの意味から説明します。',
        '申込',
        '申し込む',
        'チケットの抽選などに申し込める期間。この期限を過ぎると、そもそも参加できません。',
        '当落',
        '結果を待つ',
        '当選か落選かが発表される日。発表の時間も、ライブごとに違います。',
        '入金',
        '支払う',
        '当選したあと、チケット代を支払う期限。ここを過ぎると、当選が取り消されることがあります。',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
    });

    testWidgets('札の色は 申込=赤・当落=黄・入金=緑、文字は墨', (tester) async {
      await pumpSections(tester, 1000, children: const [WelcomeFlowSection()]);
      const expected = [
        ('申込', BrandColors.hall1),
        ('当落', BrandColors.hall3),
        ('入金', BrandColors.hall4),
      ];
      for (final e in expected) {
        final container = tester.widget<Container>(
          find
              .ancestor(of: find.text(e.$1), matching: find.byType(Container))
              .first,
        );
        expect(container.color, e.$2, reason: e.$1);
        expect(
          tester.widget<Text>(find.text(e.$1)).style?.color,
          BrandColors.ink,
        );
      }
    });
  });

  group('SOLUTION', () {
    testWidgets('見出し・説明が出て、地は墨', (tester) async {
      await pumpSections(tester, 390, children: const [WelcomeSolutionBand()]);
      expect(tester.takeException(), isNull);
      expect(find.text('SOLUTION'), findsOneWidget);
      expect(
        find.textContaining('そんなお悩みを、', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('おしあし'), findsOneWidget);
      expect(find.text('おしあしでできる、6つのこと。'), findsOneWidget);
      final band = tester.getRect(_key('welcome_solution'));
      expect(band.width, 390);
      final box = tester.widget<ColoredBox>(
        find
            .descendant(
              of: _key('welcome_solution'),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(box.color, BrandColors.ink);
    });

    for (final scale in [1.0, 1.3]) {
      for (final w in [320.0, 1000.0]) {
        testWidgets('幅 $w・文字 $scale 倍: 左寄せで、蛍光ペンは「おしあし」の下', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await pumpSections(
            tester,
            w,
            children: const [WelcomeSolutionBand()],
          );
          expect(tester.takeException(), isNull);
          // 左寄せ: 中身の左端（最大 960 の中央寄せの枠 ＋ 左右の余白）にそろう
          final gutter = w <= 520 ? 18.0 : 24.0;
          final left = (w - (w < 960 ? w : 960)) / 2 + gutter;
          expect(
            tester.getTopLeft(find.text('SOLUTION')).dx,
            closeTo(left, 0.5),
            reason: '英字',
          );
          expect(
            tester.getTopLeft(find.text('おしあしでできる、6つのこと。')).dx,
            closeTo(left, 0.5),
            reason: '説明',
          );
          final head = tester.getRect(
            find.textContaining('そんなお悩みを、', findRichText: true),
          );
          expect(head.left, closeTo(left, 0.5), reason: '見出し');
          // 蛍光ペンの帯（赤）は、「おしあし」の文字の横幅の中・文字の下寄りにある
          final pen = tester.getRect(
            find.byWidgetPredicate(
              (x) => x is ColoredBox && x.color == BrandColors.hall1,
            ),
          );
          final word = tester.getRect(find.text('おしあし'));
          expect(pen.left, greaterThanOrEqualTo(word.left - 0.5));
          expect(pen.right, greaterThanOrEqualTo(word.right - 0.5));
          expect(pen.center.dy, greaterThan(word.center.dy));
          expect(pen.bottom, lessThanOrEqualTo(word.bottom + 0.5));
        });
      }
    }

    testWidgets('蛍光ペンは赤', (tester) async {
      await pumpSections(tester, 1000, children: const [WelcomeSolutionBand()]);
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == BrandColors.hall1,
        ),
        findsOneWidget,
      );
    });
  });

  group('6つのハコ', () {
    const colors = [
      BrandColors.hall1,
      BrandColors.hall2,
      BrandColors.hall3,
      BrandColors.hall4,
      BrandColors.hall5,
      BrandColors.hall6,
    ];

    for (final c in [
      (w: 1440.0, cols: 3, tile: 480.0),
      (w: 1000.0, cols: 3, tile: 1000 / 3),
      (w: 761.0, cols: 3, tile: 761 / 3),
      (w: 760.0, cols: 2, tile: 380.0),
      (w: 640.0, cols: 2, tile: 320.0),
      (w: 521.0, cols: 2, tile: 260.5),
      (w: 520.0, cols: 1, tile: 520.0),
      (w: 390.0, cols: 1, tile: 390.0),
    ]) {
      testWidgets('幅 ${c.w}: ${c.cols} 列・各ハコの幅 ${c.tile}・隙間なし・行の高さがそろう', (
        tester,
      ) async {
        await pumpSections(tester, c.w, children: const [WelcomeTileGrid()]);
        expect(tester.takeException(), isNull);
        final r = [
          for (var i = 1; i <= 6; i++) tester.getRect(_key('welcome_hall_$i')),
        ];
        for (var i = 0; i < 6; i++) {
          expect(r[i].width, closeTo(c.tile, 0.01), reason: 'ハコ${i + 1} 幅');
          final row = i ~/ c.cols;
          final first = r[row * c.cols];
          expect(r[i].top, closeTo(first.top, 0.01));
          expect(r[i].height, closeTo(first.height, 0.01));
          expect(r[i].left, closeTo((i % c.cols) * c.tile, 0.01));
          if (row > 0) {
            expect(
              r[i].top,
              closeTo(r[(row - 1) * c.cols].bottom, 0.01),
              reason: '行の間も隙間なし',
            );
          }
        }
      });
    }

    testWidgets('幅 1000: 最小の高さ 260。幅 390 では 260 に固定されない', (tester) async {
      await pumpSections(tester, 1000, children: const [WelcomeTileGrid()]);
      for (var i = 1; i <= 6; i++) {
        expect(
          tester.getSize(_key('welcome_hall_$i')).height,
          greaterThanOrEqualTo(260),
        );
      }
      await pumpSections(tester, 390, children: const [WelcomeTileGrid()]);
      for (var i = 1; i <= 6; i++) {
        expect(
          tester.getSize(_key('welcome_hall_$i')).height,
          lessThan(260),
          reason: 'ハコ$i（参考: 203.7）',
        );
      }
    });

    testWidgets('色の順・番号・文言・文字は墨', (tester) async {
      await pumpSections(tester, 1000, children: const [WelcomeTileGrid()]);
      const texts = [
        ('FOLLOW', '推しをフォロー', '推しを探してフォロー。見つからなければ、追加を申請できます。'),
        (
          'SCAN',
          'スクショで読み取り',
          '告知画像やチケットサイトのスクリーンショットから、日程・申込期限・入金期限をAIが読み取ります。',
        ),
        ('DUE', '次の締切が、ひと目で', '申込・当落・入金の期限を並べて表示。次にやることが分かります。'),
        ('SHARE', 'みんなで共有', '同じ推しのファンが登録したライブを、自分の一覧に追加できます。'),
        ('CALENDAR', 'Google カレンダーに追加', '登録した予定を、Google カレンダーにも追加できます。'),
        ('TRADE', 'グッズ交換', '手放したいグッズは「譲」、探しているグッズは「求」として登録。交換できる相手が見つかります。'),
      ];
      for (var i = 0; i < 6; i++) {
        final hall = _key('welcome_hall_${i + 1}');
        Finder inHall(Finder f) => find.descendant(of: hall, matching: f);
        final box = tester.widget<ColoredBox>(
          inHall(find.byType(ColoredBox)).first,
        );
        expect(box.color, colors[i], reason: 'ハコ${i + 1} の色');
        final n = '0${i + 1}';
        expect(inHall(find.text('HALL $n')), findsOneWidget);
        expect(inHall(find.text(n)), findsOneWidget, reason: '大きな番号 $n');
        expect(inHall(find.text(texts[i].$1)), findsOneWidget);
        expect(inHall(find.text(texts[i].$2)), findsOneWidget);
        expect(inHall(find.text(texts[i].$3)), findsOneWidget);
        // 文字は墨だけ（番号は黒の 12%）
        for (final t in [texts[i].$1, texts[i].$2, texts[i].$3, 'HALL $n']) {
          expect(
            tester.widget<Text>(inHall(find.text(t))).style?.color,
            BrandColors.ink,
            reason: '$t の色',
          );
        }
      }
    });

    testWidgets('大きな番号は題・説明より後ろ（先に描く）で、ハコの外は切る', (tester) async {
      await pumpSections(tester, 1000, children: const [WelcomeTileGrid()]);
      final hall = _key('welcome_hall_1');
      final stack = tester.widget<Stack>(
        find.descendant(of: hall, matching: find.byType(Stack)).first,
      );
      expect(stack.clipBehavior, Clip.hardEdge);
      expect(stack.children.first, isA<Positioned>(), reason: '番号が最初');
      final number = tester.getRect(
        find.descendant(of: hall, matching: find.text('01')),
      );
      final tile = tester.getRect(hall);
      expect(number.right, lessThanOrEqualTo(tile.right));
    });
  });

  group('FAQ', () {
    const answers = [
      '公演名・日程・申込期間・入金期限などが写っている、告知画像やチケットサイトの画面です。登録する前に、読み取り結果を必ず確認してください。',
      '追加の申請を送れます。',
      'グッズ交換で使う、ファンの間の言葉です。手放したいグッズは「譲」、探しているグッズは「求」として登録します。',
      '同じ推しをフォローしているファンが登録したライブを、自分の一覧に追加できます。自分で入力する手間が省けます。',
    ];
    const questions = [
      'スクショは、どんな画像を選べばいいですか？',
      'フォローしたい推しが見つからないときは？',
      '「譲」「求」って何ですか？',
      'ほかのファンが登録したライブは、どう使えますか？',
    ];

    Future<void> tapFaq(WidgetTester tester, int n) async {
      await tester.ensureVisible(_key('welcome_faq_$n'));
      await tester.pump();
      await tester.tap(_key('welcome_faq_$n'));
      await tester.pump();
    }

    testWidgets('最初は答えが出ず、見出し・質問・「＋」が出る', (tester) async {
      await pumpSections(tester, 390, children: const [WelcomeFaqSection()]);
      expect(tester.takeException(), isNull);
      expect(_key('welcome_faq'), findsOneWidget);
      expect(find.text('FAQ'), findsOneWidget);
      expect(find.text('よくある質問'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(find.text(questions[i]), findsOneWidget);
        expect(find.text(answers[i]), findsNothing);
      }
      expect(find.text('＋'), findsNWidgets(4));
      expect(find.text('−'), findsNothing);
    });

    testWidgets('押すと答えが出て「−」になり、もう一度押すと消える（U+2212）', (tester) async {
      await pumpSections(tester, 390, children: const [WelcomeFaqSection()]);
      await tapFaq(tester, 1);
      expect(find.text(answers[0]), findsOneWidget);
      expect(find.text('−'), findsOneWidget);
      expect(find.text('＋'), findsNWidgets(3));
      await tapFaq(tester, 1);
      expect(find.text(answers[0]), findsNothing);
      expect(find.text('＋'), findsNWidgets(4));
    });

    testWidgets('項目ごとに独立。1つ開けても、ほかは閉じない', (tester) async {
      await pumpSections(tester, 390, children: const [WelcomeFaqSection()]);
      await tapFaq(tester, 1);
      await tapFaq(tester, 3);
      expect(find.text(answers[0]), findsOneWidget);
      expect(find.text(answers[2]), findsOneWidget);
      expect(find.text(answers[1]), findsNothing);
      await tapFaq(tester, 1);
      expect(find.text(answers[0]), findsNothing);
      expect(find.text(answers[2]), findsOneWidget, reason: '3 つ目は開いたまま');
    });

    testWidgets('押せる範囲は高さ 44 以上（閉じた 1 行で 58）', (tester) async {
      await pumpSections(tester, 1000, children: const [WelcomeFaqSection()]);
      for (var i = 1; i <= 4; i++) {
        expect(
          tester.getSize(_key('welcome_faq_$i')).height,
          greaterThanOrEqualTo(44),
        );
      }
    });

    testWidgets('読み上げ: button で、expanded が開閉に合わせて変わる', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSections(tester, 390, children: const [WelcomeFaqSection()]);
      final first = _key('welcome_faq_1');
      expect(
        tester.getSemantics(first),
        matchesSemantics(
          label: questions[0],
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          hasExpandedState: true,
          isExpanded: false,
        ),
      );
      await tapFaq(tester, 1);
      expect(
        tester.getSemantics(first),
        matchesSemantics(
          label: questions[0],
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          hasExpandedState: true,
          isExpanded: true,
        ),
      );
      handle.dispose();
    });
  });

  testWidgets('動きが無い（全区画）', (tester) async {
    await pumpSections(
      tester,
      390,
      children: const [
        WelcomeProblemSection(),
        WelcomeFlowSection(),
        WelcomeGoodsProblemSection(),
        WelcomeSolutionBand(),
        WelcomeTileGrid(),
        WelcomeFaqSection(),
      ],
    );
    expect(tester.hasRunningAnimations, isFalse);
  });
}
