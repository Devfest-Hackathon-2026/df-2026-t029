// 「?」ボタン（計画書 4.2）のウィジェットテスト。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/help/help_topic.dart';
import 'package:oshiashi/providers/help_providers.dart';
import 'package:oshiashi/theme/brand_colors.dart';

import 'help_test_helpers.dart';

void main() {
  testWidgets('話題が null なら何も出ない', (tester) async {
    useSize(tester, const Size(390, 800));
    await pumpHelpButton(tester, topic: null);
    expect(key('help_button'), findsNothing);
  });

  testWidgets('スコープが無いときも何も出ない', (tester) async {
    useSize(tester, const Size(390, 800));
    await pumpHelpButton(tester, withScope: false);
    expect(key('help_button'), findsNothing);
  });

  testWidgets('押すとシートが開く', (tester) async {
    useSize(tester, const Size(390, 800));
    await pumpHelpButton(tester, topic: HelpTopic.oshi);
    expect(key('help_button'), findsOneWidget);
    expect(key('help_sheet'), findsNothing);
    await tester.tap(key('help_button'));
    await tester.pumpAndSettle();
    expect(find.text('推しの使い方'), findsOneWidget);
  });

  testWidgets('押せる範囲は 44×44 以上、見た目の円は直径 36', (tester) async {
    useSize(tester, const Size(390, 800));
    await pumpHelpButton(tester);
    final size = tester.getSize(key('help_button'));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
    final circle = find.descendant(
      of: key('help_button'),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    expect(tester.getSize(circle), const Size(36, 36));
  });

  testWidgets('円の端に近い所（円の外・押せる範囲の中）を押しても開く', (tester) async {
    useSize(tester, const Size(390, 800));
    await pumpHelpButton(tester);
    final rect = tester.getRect(key('help_button'));
    await tester.tapAt(rect.topLeft + const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(key('help_sheet'), findsOneWidget);
  });

  testWidgets('押すと、初回の吹き出しを消す', (tester) async {
    useSize(tester, const Size(390, 800));
    await pumpHelpButton(tester);
    final container = ProviderScope.containerOf(
      tester.element(key('help_button')),
    );
    expect(container.read(helpCoachVisibleProvider), isTrue);
    await tester.tap(key('help_button'));
    await tester.pumpAndSettle();
    expect(container.read(helpCoachVisibleProvider), isFalse);
  });

  testWidgets('開いている間は見た目が反転し（背景が墨）、閉じると戻る', (tester) async {
    useSize(tester, const Size(390, 800));
    await pumpHelpButton(tester);
    Color? bg() {
      final c = tester.widget<Container>(
        find.descendant(
          of: key('help_button'),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).shape == BoxShape.circle,
          ),
        ),
      );
      return (c.decoration as BoxDecoration).color;
    }

    expect(bg(), BrandColors.surface);
    await tester.tap(key('help_button'));
    await tester.pumpAndSettle();
    expect(bg(), BrandColors.ink);
    await tester.tapAt(const Offset(195, 10)); // 暗幕
    await tester.pumpAndSettle();
    expect(bg(), BrandColors.surface);
  });

  testWidgets('読み上げ: ラベルとボタン。開いている間は toggled', (tester) async {
    useSize(tester, const Size(390, 800));
    final handle = tester.ensureSemantics();
    await pumpHelpButton(tester);
    expect(
      tester.getSemantics(key('help_button')),
      matchesSemantics(
        label: 'この画面でできることを見る',
        isButton: true,
        hasToggledState: true,
        isToggled: false,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    // 開いている間は、背後の「?」はシートが読み上げの範囲（scopesRoute）になるので
    // 読み上げの木から外れる。toggled は見た目の反転（別のテスト）で確かめる
    await tester.tap(key('help_button'));
    await tester.pumpAndSettle();
    expect(key('help_sheet'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('ツールチップは「この画面でできることを見る」', (tester) async {
    useSize(tester, const Size(390, 800));
    await pumpHelpButton(tester);
    expect(find.byTooltip('この画面でできることを見る'), findsOneWidget);
  });

  testWidgets('閉じたあと、フォーカスが「?」に戻る（Esc・とじる）', (tester) async {
    useSize(tester, const Size(390, 800));
    await pumpHelpButton(tester);
    for (final close in ['esc', 'button']) {
      await tester.tap(key('help_button'));
      await tester.pumpAndSettle();
      if (close == 'esc') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else {
        await tester.ensureVisible(key('help_sheet_close'));
        await tester.tap(key('help_sheet_close'));
      }
      await tester.pumpAndSettle();
      expect(key('help_sheet'), findsNothing, reason: close);
      expect(
        Focus.of(
          tester.element(
            find
                .descendant(
                  of: key('help_button'),
                  matching: find.byType(SizedBox),
                )
                .first,
          ),
        ).hasPrimaryFocus,
        isTrue,
        reason: close,
      );
    }
  });
}
