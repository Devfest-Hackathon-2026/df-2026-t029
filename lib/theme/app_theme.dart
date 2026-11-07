import 'package:flutter/material.dart';

import 'brand_colors.dart';
import 'hako_fonts.dart';

const _ink = BrandColors.ink;

BorderSide _side(double w) => BorderSide(color: _ink, width: w);

/// アプリ全体のテーマを作る（統合案 v4「ハコ色」）。
/// [seedColor] はテーマカラーそのもの。ボタン・選んだチップ・スイッチのオンに使う。
/// 背景は紙、文字・枠は墨。
ThemeData buildAppTheme(Color seedColor) {
  final onTheme = onThemeColor(seedColor);
  final scheme = const ColorScheme.light().copyWith(
    primary: _ink,
    onPrimary: Colors.white,
    secondary: _ink,
    onSecondary: Colors.white,
    surface: BrandColors.surface,
    onSurface: _ink,
    onSurfaceVariant: BrandColors.sub,
    outline: _ink,
    outlineVariant: BrandColors.rowLine,
    error: BrandColors.errorText,
    onError: Colors.white,
    primaryContainer: seedColor,
    onPrimaryContainer: onTheme,
    secondaryContainer: BrandColors.tonal,
    onSecondaryContainer: _ink,
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: BrandColors.paper,
    surfaceContainerLow: BrandColors.paper,
    surfaceContainer: BrandColors.paper,
    surfaceContainerHigh: BrandColors.paper,
    surfaceContainerHighest: BrandColors.tonal,
  );

  TextStyle jp(double size, {FontWeight w = FontWeight.w400, double h = 1.6}) =>
      HakoFonts.jp(size: size, weight: w, height: h);

  final textTheme = TextTheme(
    displayLarge: jp(32, w: FontWeight.w700),
    displayMedium: jp(28, w: FontWeight.w700),
    displaySmall: jp(24, w: FontWeight.w700, h: 1.35),
    headlineLarge: jp(24, w: FontWeight.w700, h: 1.35),
    headlineMedium: jp(22, w: FontWeight.w700),
    headlineSmall: jp(20, w: FontWeight.w700, h: 1.4),
    titleLarge: jp(20, w: FontWeight.w700, h: 1.4),
    titleMedium: jp(16, w: FontWeight.w700),
    titleSmall: jp(15, w: FontWeight.w700),
    bodyLarge: jp(16),
    bodyMedium: jp(15),
    bodySmall: jp(12, h: 1.5).copyWith(color: BrandColors.sub),
    labelLarge: jp(14, w: FontWeight.w700),
    labelMedium: jp(12, w: FontWeight.w700, h: 1.5),
    labelSmall: jp(11, w: FontWeight.w700, h: 1.2),
  );

  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    focusColor: _ink.withValues(alpha: 0.12),
    splashColor: _ink.withValues(alpha: 0.10),
  );

  const stadium = StadiumBorder();
  final inputLine = UnderlineInputBorder(borderSide: _side(2));
  final inputFocus = UnderlineInputBorder(borderSide: _side(3));
  final inputError = UnderlineInputBorder(
    borderSide: const BorderSide(color: BrandColors.errorText, width: 2),
  );
  final inputErrorFocus = UnderlineInputBorder(
    borderSide: const BorderSide(color: BrandColors.errorText, width: 3),
  );

  return base.copyWith(
    scaffoldBackgroundColor: BrandColors.paper,
    appBarTheme: AppBarTheme(
      backgroundColor: BrandColors.paper,
      foregroundColor: _ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: jp(20, h: 1.3),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _side(1.5),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: BrandColors.rowLine,
      thickness: 1.5,
      space: 1.5,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? seedColor.withValues(alpha: 0.5)
              : seedColor,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? onTheme.withValues(alpha: 0.5)
              : onTheme,
        ),
        side: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? BorderSide(color: _ink.withValues(alpha: 0.5), width: 2)
              : _side(s.contains(WidgetState.focused) ? 3 : 2),
        ),
        shape: const WidgetStatePropertyAll(stadium),
        elevation: const WidgetStatePropertyAll(0),
        minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20),
        ),
        textStyle: WidgetStatePropertyAll(jp(14, w: FontWeight.w700, h: 1.3)),
        overlayColor: WidgetStatePropertyAll(_ink.withValues(alpha: 0.10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? _ink.withValues(alpha: 0.4)
              : _ink,
        ),
        side: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? BorderSide(color: _ink.withValues(alpha: 0.4), width: 1.5)
              : _side(s.contains(WidgetState.focused) ? 3 : 1.5),
        ),
        shape: const WidgetStatePropertyAll(stadium),
        minimumSize: const WidgetStatePropertyAll(Size(64, 40)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        textStyle: WidgetStatePropertyAll(jp(13, w: FontWeight.w700, h: 1.3)),
        overlayColor: WidgetStatePropertyAll(_ink.withValues(alpha: 0.10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? _ink.withValues(alpha: 0.4)
              : _ink,
        ),
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10),
        ),
        textStyle: WidgetStatePropertyAll(jp(14, w: FontWeight.w700, h: 1.3)),
        overlayColor: WidgetStatePropertyAll(_ink.withValues(alpha: 0.10)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? _ink.withValues(alpha: 0.4)
              : _ink,
        ),
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: seedColor,
      foregroundColor: onTheme,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: StadiumBorder(side: _side(2)),
      extendedTextStyle: jp(14, w: FontWeight.w700, h: 1.3),
      extendedSizeConstraints: const BoxConstraints.tightFor(height: 44),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      contentPadding: const EdgeInsets.only(top: 6, bottom: 2),
      labelStyle: jp(12, h: 1.4).copyWith(color: BrandColors.sub),
      floatingLabelStyle: jp(12, h: 1.4).copyWith(color: BrandColors.sub),
      hintStyle: jp(15).copyWith(color: BrandColors.sub),
      helperStyle: jp(12, h: 1.4).copyWith(color: BrandColors.sub),
      counterStyle: jp(12, h: 1.4).copyWith(color: BrandColors.sub),
      errorStyle: jp(
        12,
        w: FontWeight.w700,
        h: 1.4,
      ).copyWith(color: BrandColors.errorText),
      border: inputLine,
      enabledBorder: inputLine,
      focusedBorder: inputFocus,
      errorBorder: inputError,
      focusedErrorBorder: inputErrorFocus,
      disabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: _ink.withValues(alpha: 0.4), width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: BrandColors.paper,
      selectedColor: seedColor,
      disabledColor: BrandColors.tonal,
      checkmarkColor: onTheme,
      labelStyle: jp(14, h: 1.3),
      secondaryLabelStyle: jp(
        14,
        w: FontWeight.w700,
        h: 1.3,
      ).copyWith(color: onTheme),
      iconTheme: const IconThemeData(color: _ink, size: 18),
      side: _side(1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? seedColor : BrandColors.tonal,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(_ink),
      trackOutlineWidth: const WidgetStatePropertyAll(2),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? onTheme : _ink,
      ),
      overlayColor: WidgetStatePropertyAll(_ink.withValues(alpha: 0.12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: BrandColors.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _side(2),
      ),
      titleTextStyle: jp(18, w: FontWeight.w700, h: 1.4),
      contentTextStyle: jp(15),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: BrandColors.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      modalBackgroundColor: BrandColors.paper,
      modalBarrierColor: _ink.withValues(alpha: 0.5),
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        side: BorderSide(color: _ink, width: 2),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: BrandColors.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _side(2),
      ),
      menuPadding: EdgeInsets.zero,
      textStyle: jp(15),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _ink,
      contentTextStyle: jp(13, h: 1.5).copyWith(color: Colors.white),
      actionTextColor: BrandColors.hall3,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    listTileTheme: ListTileThemeData(
      textColor: _ink,
      iconColor: _ink,
      titleTextStyle: jp(15, h: 1.5),
      subtitleTextStyle: jp(12, h: 1.5).copyWith(color: BrandColors.sub),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: _ink),
    tabBarTheme: TabBarThemeData(
      labelColor: _ink,
      unselectedLabelColor: _ink,
      labelStyle: jp(14, w: FontWeight.w700, h: 1.3),
      unselectedLabelStyle: jp(14, h: 1.3),
      indicatorColor: _ink,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: BrandColors.rowLine,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: _ink, width: 3),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: BrandColors.paper,
      elevation: 0,
      selectedLabelTextStyle: jp(11, w: FontWeight.w700, h: 1.2),
      unselectedLabelTextStyle: jp(11, w: FontWeight.w700, h: 1.2),
      selectedIconTheme: const IconThemeData(color: _ink, size: 24),
      unselectedIconTheme: const IconThemeData(color: _ink, size: 24),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: BrandColors.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      iconTheme: const WidgetStatePropertyAll(
        IconThemeData(color: _ink, size: 24),
      ),
      labelTextStyle: WidgetStatePropertyAll(
        jp(11, w: FontWeight.w700, h: 1.2),
      ),
    ),
  );
}
