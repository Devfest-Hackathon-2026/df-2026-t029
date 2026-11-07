import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// テーマの色の作り方。
/// fidelity は選んだ色に近く、tonalSpot（Flutter の標準）は選んだ色をやわらげる
const _schemeVariant = DynamicSchemeVariant.fidelity;

/// アプリ全体のテーマを作る（Da-1）。
/// 色はすべて [seedColor] から作った ColorScheme から取り、テーマカラーを変えると全部いっしょに変わる
ThemeData buildAppTheme(Color seedColor) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    dynamicSchemeVariant: _schemeVariant,
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: GoogleFonts.outfit().fontFamily,
  );
  // 背景は白に近い色にし、テーマの色はボタン・強調・選択中のタブだけに使う
  final background = scheme.surfaceContainerLowest;

  return base.copyWith(
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      // スクロールしても色を変えない
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    // カードは影をなくし、薄い枠で背景と区別する
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    navigationRailTheme: NavigationRailThemeData(backgroundColor: background),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: background),
  );
}