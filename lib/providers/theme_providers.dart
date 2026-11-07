import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 初期のテーマカラー（基準の色）。紹介ページの色が決まったら、ここだけを直す
const kDefaultSeedColor = Color(0xFF795548);

/// アプリ全体のテーマの基準の色。D-6 で、ユーザーが設定した色を返すようにする
final themeSeedColorProvider = Provider<Color>((ref) => kDefaultSeedColor);