import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/profile/theme_color_picker.dart';
import 'package:oshiashi/providers/theme_providers.dart';
import 'package:oshiashi/theme/app_theme.dart';
import 'package:oshiashi/theme/brand_colors.dart';

const _ink = BrandColors.ink;

/// 計画書 4.1 の12色と、期待する文字の色
const _expected = <(String, int, bool)>[
  ('レッド', 0xFFE8452C, false),
  ('ピンク', 0xFFF07BAE, false),
  ('オレンジ', 0xFFFF9F1C, false),
  ('イエロー', 0xFFF2D21B, false),
  ('オリーブ', 0xFF8DB33A, false),
  ('グリーン', 0xFF2DBE7E, false),
  ('スカイブルー', 0xFF3FB6F0, false),
  ('ブルー', 0xFF4A9BEF, false),
  ('ネイビー', 0xFF283593, true),
  ('パープル', 0xFF8E24AA, true),
  ('ホワイト', 0xFFFFFFFF, false),
  ('ブラック', 0xFF121212, true),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('onThemeColor', () {
    for (final (name, argb, white) in _expected) {
      test('$name は ${white ? '白' : '墨'}', () {
        expect(onThemeColor(Color(argb)), white ? Colors.white : _ink);
      });
    }
  });

  group('テーマカラー', () {
    test('初期色は 0xFFFF9F1C', () {
      expect(kDefaultSeedColor, const Color(0xFFFF9F1C));
    });

    test('色見本は計画書の12色（名前・値・順）', () {
      expect(kThemeColorPresets.length, 12);
      for (var i = 0; i < 12; i++) {
        expect(kThemeColorPresets[i].$1, _expected[i].$1);
        expect(kThemeColorPresets[i].$2, Color(_expected[i].$2));
      }
    });
  });

  group('buildAppTheme', () {
    for (final (name, argb, white) in _expected) {
      test('$name で例外なく作れ、FilledButton の背景と文字がテーマカラー', () {
        final t = buildAppTheme(Color(argb));
        final style = t.filledButtonTheme.style!;
        expect(style.backgroundColor!.resolve({}), Color(argb));
        expect(style.foregroundColor!.resolve({}), white ? Colors.white : _ink);
        expect(t.scaffoldBackgroundColor, BrandColors.paper);
        expect(t.colorScheme.primaryContainer, Color(argb));
      });
    }

    test('枠は墨・カードは白', () {
      final t = buildAppTheme(kDefaultSeedColor);
      expect(t.cardTheme.color, Colors.white);
      expect(t.useMaterial3, isTrue);
    });
  });
}
