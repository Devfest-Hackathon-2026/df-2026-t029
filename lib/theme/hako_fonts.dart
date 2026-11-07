import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'brand_colors.dart';

/// ログイン前の画面（案6）の書体。画面からは `GoogleFonts.` や `fontFamily:` を
/// 直接書かず、すべてここを通す。
abstract final class HakoFonts {
  /// 英字の書体（同梱。pubspec.yaml の fonts）
  static const enFamily = 'ArchivoHako';

  /// 日本語・本文・見出し・ボタン（BIZ UDPGothic。太さは 400 か 700 だけ）
  static TextStyle jp({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = BrandColors.ink,
    double height = 1.75,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.bizUDPGothic(
      fontSize: size,
      fontWeight: weight.value >= 600 ? FontWeight.w700 : FontWeight.w400,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    ).copyWith(leadingDistribution: TextLeadingDistribution.even);
  }

  /// 英字ラベル・数字（ArchivoHako。太さは 700 / 800 / 900）。
  /// 出せない文字（日本語・「→」など）は日本語の書体に落とす。
  static TextStyle en({
    required double size,
    FontWeight weight = FontWeight.w800,
    Color color = BrandColors.ink,
    double height = 1.75,
    double letterSpacing = 0,
  }) {
    final fallback = jp(
      size: size,
      weight: FontWeight.w700,
      color: color,
      height: height,
    );
    return TextStyle(
      fontFamily: enFamily,
      fontFamilyFallback: [fallback.fontFamily!],
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  /// Google ボタンの文字（Roboto 500・14）。日本語は jp の書体に落とす。
  static TextStyle googleButton() {
    final fallback = jp(size: 14, weight: FontWeight.w400, height: 1.2);
    return GoogleFonts.roboto(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: BrandColors.googleText,
      height: 1.2,
    ).copyWith(
      leadingDistribution: TextLeadingDistribution.even,
      fontFamilyFallback: [fallback.fontFamily!],
    );
  }
}
