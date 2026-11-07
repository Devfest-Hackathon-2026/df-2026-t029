import 'package:flutter/material.dart';

/// ブランドの色（夜のライブ会場とペンライトのイメージ）。
/// 紹介ページ・ログイン画面・確認画面で共通に使う。
abstract final class BrandColors {
  // 暗い区画（最初の画面・締め）
  static const night = Color(0xFF0E0A1F);
  static const violet = Color(0xFF2E1A5C);
  static const text = Colors.white;
  static const subText = Color(0xBFFFFFFF); // 白の 75%
  // 明るい区画（機能）
  static const paper = Color(0xFFFAF8FD); // ほんのり紫がかった白
  static const ink = Color(0xFF1A1033); // 濃い紫紺の文字
  static const inkSub = Color(0xFF5E5A72);
  static const line = Color(0xFFE6E0F0);
  // 差し色（ペンライト）
  static const pink = Color(0xFFFF4FA3);
  static const purple = Color(0xFF8B5CF6);
}
