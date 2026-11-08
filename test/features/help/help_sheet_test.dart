// ヘルプシート（計画書 4.3）のウィジェットテスト。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/help/help_topic.dart';
import 'package:oshiashi/theme/brand_colors.dart';

import 'help_test_helpers.dart';

Future<void> openSheet(WidgetTester tester, HelpTopic topic) async {
  await pumpHelpButton(tester, topic: topic);
  await tester.tap(key('help_button'));
  await tester.pumpAndSettle();
}

void main() {
  group('中身', () {
    for (final topic in HelpTopic.values) {
      testWidgets('${topic.label}: 見出し・小見出し・手順が順に出る', (tester) async {
        useSize(tester, const Size(390, 1200));
        await openSheet(tester, topic);
        expect(key('help_sheet'), findsOneWidget);
        expect(find.text('${topic.label}の使い方'), findsOneWidget);
        expect(find.text('この画面でできること'), findsOneWidget);
        expect(find.text('とじる'), findsOneWidget);

        final items = topic.items;
        double? previousY;
        for (var i = 0; i < items.length; i++) {
          final card = key('help_sheet_item_$i');
          expect(card, findsOneWidget);
          expect(
            find.descendant(of: card, matching: find.text(items[i].title)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: card, matching: find.text(items[i].body)),
            findsOneWidget,
          );
          // 番号の丸（1 から）
          expect(
            find.descendant(of: card, matching: find.text('${i + 1}')),
            findsOneWidget,
          );
          final y = tester.getTopLeft(card).dy;
          if (previousY != null) expect(y, greaterThan(previousY));
          previousY = y;
        }
        expect(key('help_sheet_item_${items.length}'), findsNothing);
      });
    }

    testWidgets('番号の丸と見出しの札は、その画面の色', (tester) async {
      useSize(tester, const Size(390, 1200));
      // 凡例の無い画面で数える（札 1 つ + 手順の数だけの丸）
      for (final topic in [HelpTopic.oshi, HelpTopic.live, HelpTopic.memory]) {
        await openSheet(tester, topic);
        final colored = tester
            .widgetList<Container>(find.byType(Container))
            .where((c) {
              final d = c.decoration;
              return d is BoxDecoration && d.color == topic.hue;
            });
        expect(colored, hasLength(topic.items.length + 1), reason: topic.label);
        await tester.tap(key('help_sheet_close'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('凡例: ホームは3つの札', (tester) async {
      useSize(tester, const Size(390, 1200));
      await openSheet(tester, HelpTopic.home);
      expect(key('help_sheet_legend'), findsOneWidget);
      for (final t in ['申込期限', '入金期限', '当落発表']) {
        expect(
          find.descendant(of: key('help_sheet_legend'), matching: find.text(t)),
          findsOneWidget,
        );
      }
    });

    testWidgets('凡例: グッズ交換は「譲」「求」と説明', (tester) async {
      useSize(tester, const Size(390, 1200));
      await openSheet(tester, HelpTopic.trade);
      expect(key('help_sheet_legend'), findsOneWidget);
      for (final t in ['譲', '手放せるグッズ', '求', 'ほしいグッズ']) {
        expect(
          find.descendant(of: key('help_sheet_legend'), matching: find.text(t)),
          findsOneWidget,
        );
      }
    });

    for (final topic in [HelpTopic.oshi, HelpTopic.live, HelpTopic.memory]) {
      testWidgets('${topic.label}: 凡例は出ない', (tester) async {
        useSize(tester, const Size(390, 1200));
        await openSheet(tester, topic);
        expect(key('help_sheet_legend'), findsNothing);
      });
    }
  });

  group('閉じ方', () {
    testWidgets('「とじる」で閉じる', (tester) async {
      useSize(tester, const Size(390, 1200));
      await openSheet(tester, HelpTopic.home);
      await tester.ensureVisible(key('help_sheet_close'));
      await tester.tap(key('help_sheet_close'));
      await tester.pumpAndSettle();
      expect(key('help_sheet'), findsNothing);
    });

    testWidgets('暗幕のタップで閉じる', (tester) async {
      useSize(tester, const Size(390, 800));
      await openSheet(tester, HelpTopic.home);
      await tester.tapAt(const Offset(195, 10));
      await tester.pumpAndSettle();
      expect(key('help_sheet'), findsNothing);
    });

    testWidgets('Esc キーで閉じる', (tester) async {
      useSize(tester, const Size(390, 800));
      await openSheet(tester, HelpTopic.home);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(key('help_sheet'), findsNothing);
    });

    testWidgets('閉じたあと、もう一度開ける', (tester) async {
      useSize(tester, const Size(390, 800));
      await openSheet(tester, HelpTopic.live);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(key('help_button'));
      await tester.pumpAndSettle();
      expect(key('help_sheet'), findsOneWidget);
    });
  });

  group('動き', () {
    testWidgets('disableAnimations のときは、1フレームで最終の位置に出る', (tester) async {
      useSize(tester, const Size(390, 800));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpHelpButton(tester);
      await tester.tap(key('help_button'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(key('help_sheet'), findsOneWidget);
      expect(tester.getRect(key('help_sheet')).bottom, closeTo(800, 0.5));
    });

    testWidgets('通常は、下から動いてくる（1フレーム目はまだ画面の下）', (tester) async {
      useSize(tester, const Size(390, 800));
      await pumpHelpButton(tester);
      await tester.tap(key('help_button'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.getRect(key('help_sheet')).bottom, greaterThan(800));
      await tester.pumpAndSettle();
      expect(tester.getRect(key('help_sheet')).bottom, closeTo(800, 0.5));
    });
  });

  group('大きさ', () {
    testWidgets('PC（幅 720 以上）は幅 640 以内で、下の中央', (tester) async {
      for (final w in [720.0, 1000.0]) {
        useSize(tester, Size(w, 900));
        await openSheet(tester, HelpTopic.home);
        final rect = tester.getRect(key('help_sheet'));
        expect(rect.width, lessThanOrEqualTo(640), reason: 'w=$w');
        expect(rect.center.dx, closeTo(w / 2, 1), reason: 'w=$w');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('幅 719 はスマホ（全幅）', (tester) async {
      useSize(tester, const Size(719, 900));
      await openSheet(tester, HelpTopic.home);
      expect(tester.getRect(key('help_sheet')).width, 719);
    });

    testWidgets('高さは画面の 82% まで。足りないときはスクロールできる', (tester) async {
      useSize(tester, const Size(390, 400));
      await openSheet(tester, HelpTopic.memory);
      expect(
        tester.getRect(key('help_sheet')).height,
        lessThanOrEqualTo(400 * 0.82 + 0.5),
      );
      expect(tester.takeException(), isNull);
      // 「とじる」は最初は画面の外。スクロールすれば見える
      expect(
        tester.getTopLeft(key('help_sheet_close')).dy,
        greaterThan(400 * 0.82),
      );
      await tester.ensureVisible(key('help_sheet_close'));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(key('help_sheet_close')).dy,
        lessThanOrEqualTo(400),
      );
      await tester.tap(key('help_sheet_close'));
      await tester.pumpAndSettle();
      expect(key('help_sheet'), findsNothing);
    });

    for (final scale in [1.0, 1.3]) {
      for (final w in [320.0, 360.0, 390.0, 430.0, 720.0, 1000.0]) {
        testWidgets('幅 ${w.toInt()}・文字 $scale 倍: はみ出さない（全画面）', (tester) async {
          useSize(tester, Size(w, 700), textScale: scale);
          for (final topic in HelpTopic.values) {
            await openSheet(tester, topic);
            expect(tester.takeException(), isNull, reason: topic.label);
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
          }
        });
      }
    }
  });

  group('読み上げ', () {
    testWidgets('シートは「{画面名}の使い方」を名前にして、見出しは header', (tester) async {
      useSize(tester, const Size(390, 1200));
      final handle = tester.ensureSemantics();
      await openSheet(tester, HelpTopic.live);
      expect(find.bySemanticsLabel('ライブ一覧の使い方'), findsWidgets);
      expect(
        find.bySemanticsLabel('1. ライブの予定を見る。登録したライブが、開催日の近い順に並びます。'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('見た目', () {
    testWidgets('背景は紙の色、上の角丸 22、「とじる」は墨の背景', (tester) async {
      useSize(tester, const Size(390, 1200));
      await openSheet(tester, HelpTopic.home);
      final box = tester.widget<DecoratedBox>(key('help_sheet'));
      final d = box.decoration as BoxDecoration;
      expect(d.color, BrandColors.paper);
      expect(
        d.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(22)),
      );
      final close = tester.widget<FilledButton>(key('help_sheet_close'));
      final bg = close.style?.backgroundColor?.resolve({});
      expect(bg, BrandColors.ink);
      expect(
        tester.getSize(key('help_sheet_close')).height,
        greaterThanOrEqualTo(48),
      );
    });
  });
}
