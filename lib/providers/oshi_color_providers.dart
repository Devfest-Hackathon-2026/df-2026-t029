import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/oshi.dart';
import '../models/trade_post.dart';
import '../repositories/oshi_color_repository.dart';
import 'oshi_providers.dart';

/// 推しの色のリポジトリ。テストでは `overrideWithValue` で差し替える
final oshiColorRepositoryProvider = Provider<OshiColorRepository>(
  (ref) => FirestoreOshiColorRepository(FirebaseFirestore.instance),
);

/// 推しの色（キー → ARGB）。未ログイン・読み込み中は空として使う（Fc 5.3）
final oshiColorsProvider = StreamProvider<Map<String, int>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const {});
  return ref.watch(oshiColorRepositoryProvider).watch(uid);
}, retry: firestoreRetry);

/// 推しの色のキー（`group:xxx`・`person:xxx`）
String oshiColorKey(OshiKind kind, String id) => '${kind.name}:$id';

/// 推しの色（Fc 5.3）。自分の色が無い個人は、所属グループのうち
/// 色があるものの最初の色を使う。どちらも無ければ null
Color? resolveOshiColor(OshiSummary oshi, Map<String, int> colors) {
  final own = colors[oshiColorKey(oshi.kind, oshi.id)];
  if (own != null) return Color(own);
  if (oshi.kind == OshiKind.person) {
    for (final g in oshi.groupIds) {
      final c = colors[oshiColorKey(OshiKind.group, g)];
      if (c != null) return Color(c);
    }
  }
  return null;
}

/// 投稿の色（掲示板の行の左端。Fc 5.3）。
/// 対象の推し（個人 → グループの順）のうち、最初に色があるもの
Color? resolvePostColor(
  TradePost post,
  Map<String, int> colors,
  List<OshiSummary> all,
) {
  if (colors.isEmpty) return null;
  final persons = {
    for (final o in all)
      if (o.kind == OshiKind.person) o.id: o,
  };
  for (final id in post.oshiIds) {
    final person = persons[id];
    final c = person == null
        ? colors[oshiColorKey(OshiKind.person, id)]
        : resolveOshiColor(person, colors)?.toARGB32();
    if (c != null) return Color(c);
  }
  for (final id in post.groupIds) {
    final c = colors[oshiColorKey(OshiKind.group, id)];
    if (c != null) return Color(c);
  }
  return null;
}
