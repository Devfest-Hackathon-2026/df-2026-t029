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
  // ログイン後の画面（統合案 v4）
  static const surface = Colors.white; // カード・入力の箱・チップ
  static const sub = Color(0xFF55524B); // 補足の文字
  static const tonal = Color(0xFFEDE6D3); // 軽いチップ・スイッチの切
  static const tonal2 = Color(0xFFE4DBC3); // リンクのチップ
  static const rowLine = Color(0x40121212); // 一覧の行の下線（ink の 25%）
  // 淡い色（ヘルプ・下部バー。濃い色の対）
  static const hall1Soft = Color(0xFFFBD6CE); // 推し
  static const hall3Soft = Color(0xFFFBF0B4); // ホーム
  static const hall4Soft = Color(0xFFCDEFDF); // メモリー
  static const hall5Soft = Color(0xFFD3E5FA); // ライブ一覧
  static const hall6Soft = Color(0xFFFADCE9); // グッズ交換・「譲」
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

/// 濃い色（hall1・3・4・5・6）に対応する淡い色。ほかの色はそのまま返す
Color softOf(Color hall) {
  if (hall == BrandColors.hall1) return BrandColors.hall1Soft;
  if (hall == BrandColors.hall3) return BrandColors.hall3Soft;
  if (hall == BrandColors.hall4) return BrandColors.hall4Soft;
  if (hall == BrandColors.hall5) return BrandColors.hall5Soft;
  if (hall == BrandColors.hall6) return BrandColors.hall6Soft;
  return hall;
}

/// テーマカラーの上に置く文字・アイコンの色（墨か白の、コントラストが高いほう）
Color onThemeColor(Color bg) {
  final l = bg.computeLuminance();
  final inkL = BrandColors.ink.computeLuminance();
  final withInk = (l + 0.05) / (inkL + 0.05);
  final withWhite = 1.05 / (l + 0.05);
  return withInk >= withWhite ? BrandColors.ink : Colors.white;
}
