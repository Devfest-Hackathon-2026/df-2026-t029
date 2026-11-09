import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/oshi.dart';
import '../repositories/oshi_emoji_repository.dart';
import 'oshi_color_providers.dart';
import 'oshi_providers.dart';

/// 推しの絵文字のリポジトリ。テストでは `overrideWithValue` で差し替える
final oshiEmojiRepositoryProvider = Provider<OshiEmojiRepository>(
  (ref) => FirestoreOshiEmojiRepository(FirebaseFirestore.instance),
);

/// 推しの絵文字（キー → 絵文字）。未ログイン・読み込み中は空として使う（add_I 3.1）
final oshiEmojisProvider = StreamProvider<Map<String, String>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const {});
  return ref.watch(oshiEmojiRepositoryProvider).watch(uid);
}, retry: firestoreRetry);

/// 推しの絵文字（add_I 3.1）。色と違い、グループの絵文字は引き継がない
String? resolveOshiEmoji(OshiSummary oshi, Map<String, String> emojis) =>
    emojis[oshiColorKey(oshi.kind, oshi.id)];

/// 絵文字1文字の UTF-8 での上限（肌の色・国旗・ZWJ でつないだ絵文字も入る長さ）
const _maxEmojiBytes = 32;

/// 入力を絵文字1文字（書記素1つ）にする。空・長すぎるときは null
String? normalizeOshiEmoji(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final first = text.characters.first;
  return utf8.encode(first).length <= _maxEmojiBytes ? first : null;
}
