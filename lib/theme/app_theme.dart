import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 強調色の作り方。fidelity は選んだ色に近く、tonalSpot（Flutter の標準）は選んだ色をやわらげる
const _schemeVariant = DynamicSchemeVariant.fidelity;

/// これより明るい色（白など）は、塗りに使うと背景にまぎれるので、強調色で代わりに塗る
const _maxFillLuminance = 0.8;

/// アプリ全体のテーマを作る（Da-1・Fa-1）。
/// 背景・カード・線は白と灰色だけにし、選んだ色はボタン・選択中の印・強調だけに使う。
/// 色はすべて [seedColor] から作り、テーマカラーを変えると全部いっしょに変わる
ThemeData buildAppTheme(Color seedColor) {
  // 文字・アイコンの強調色（primary）を取る表。白い背景の上で読める濃さになる
  final accent = ColorScheme.fromSeed(
    seedColor: seedColor,
    dynamicSchemeVariant: _schemeVariant,
  );
  // 背景・カード・線を取る表（色みのない灰色）
  final neutral = ColorScheme.fromSeed(
    seedColor: seedColor,
    dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
  );
  // ボタンなどの塗りは、選んだ色そのもの。上の文字は、塗りの明るさで白か黒にする
  final fill = seedColor.computeLuminance() > _maxFillLuminance
      ? accent.primary
      : seedColor;
  final onFill = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
      ? Colors.white
      : Colors.black;

  final scheme = accent.copyWith(
    surface: neutral.surface,
    onSurface: neutral.onSurface,
    onSurfaceVariant: neutral.onSurfaceVariant,
    surfaceContainerLowest: neutral.surfaceContainerLowest,
    surfaceContainerLow: neutral.surfaceContainerLow,
    surfaceContainer: neutral.surfaceContainer,
    surfaceContainerHigh: neutral.surfaceContainerHigh,
    surfaceContainerHighest: neutral.surfaceContainerHighest,
    outline: neutral.outline,
    outlineVariant: neutral.outlineVariant,
    surfaceTint: neutral.surfaceTint,
    // 右下のボタン・選択中のタブの印・選択中のチップは、選んだ色で塗る
    primaryContainer: fill,
    onPrimaryContainer: onFill,
    secondaryContainer: fill,
    onSecondaryContainer: onFill,
  );

  // 英字は紹介ページと同じ Outfit。日本語は Outfit に無いので、標準の日本語フォントになる
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: GoogleFonts.outfit().fontFamily,
  );
  // 背景は白に近い色
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
    // ボタンは、選んだ色そのもので塗る（押せないときの色は標準のまま）
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: fill,
        foregroundColor: onFill,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: fill,
      foregroundColor: onFill,
    ),
  );
}