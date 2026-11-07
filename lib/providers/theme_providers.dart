import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_providers.dart';

/// 初期のテーマカラー（基準の色）。紹介ページの色が決まったら、ここだけを直す
const kDefaultSeedColor = Color(0xFF795548);

/// アプリ全体のテーマの基準の色。ユーザーが設定していればその色、
/// 未設定・未ログイン・読み込み中なら初期の色
final themeSeedColorProvider = Provider<Color>((ref) {
  final color = ref.watch(myProfileProvider).value?.themeColor;
  return color == null ? kDefaultSeedColor : Color(color);
});