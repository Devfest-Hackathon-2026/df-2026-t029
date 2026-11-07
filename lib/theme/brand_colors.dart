import 'package:flutter/material.dart';

/// ブランドの色（案6「ハコ色」）。
/// 紹介ページ・ログイン画面・確認画面で共通に使う。
abstract final class BrandColors {
  // 紙と墨
  static const paper = Color(0xFFFBF6EA); // 紙の色（ページの地）
  static const ink = Color(0xFF121212); // 墨（文字・枠・黒い区画）
  static const backdrop = Color(0xFFD9D3C4); // 幅 430 の外側（PC で見たとき）
  // 6つのハコの色（上から順。色の帯も同じ順）
  static const hall1 = Color(0xFFE8452C); // 赤
  static const hall2 = Color(0xFFFF9F1C); // 橙
  static const hall3 = Color(0xFFF2D21B); // 黄
  static const hall4 = Color(0xFF2DBE7E); // 緑
  static const hall5 = Color(0xFF4A9BEF); // 青
  static const hall6 = Color(0xFFF07BAE); // 桃
  static const halls = [hall1, hall2, hall3, hall4, hall5, hall6];
  // 黒い区画の中
  static const onInkSub = Color(0xFFDDDDDD); // 補足の文字
  static const boardRule = Color(0xFF555555); // 掲示板の見出しの下線
  static const boardRow = Color(0xFF333333); // 掲示板の行の区切り
  // エラーの文字（紙の上で 6:1）
  static const errorText = Color(0xFFB3261E);
  // Google ボタン（Google のブランドのガイドライン）
  static const googleBorder = Color(0xFF747775);
  static const googleText = Color(0xFF1F1F1F);
}
