import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/oshi.dart';
import '../models/oshi_news.dart';
import '../repositories/oshi_news_repository.dart';
import 'oshi_color_providers.dart';
import 'oshi_providers.dart';

/// お知らせのリポジトリ。テストでは `overrideWithValue` で差し替える
final oshiNewsRepositoryProvider = Provider<OshiNewsRepository>(
  (ref) => FirestoreOshiNewsRepository(FirebaseFirestore.instance),
);

/// 1回に読むお知らせの件数
const oshiNewsLimit = 20;

/// ホームのお知らせに出す日数と件数（add_P 2.2）
const homeNewsDays = 14;

/// お知らせを読む推しのキー（add_P 5.1）：その推しと、個人なら所属グループ
List<String> newsKeysOf(OshiSummary oshi) => [
  oshiColorKey(oshi.kind, oshi.id),
  if (oshi.kind == OshiKind.person)
    for (final g in oshi.groupIds) oshiColorKey(OshiKind.group, g),
];

/// [keys] の推しのお知らせ（新しい順）。
/// family の引数は、キーを「,」でつないだ文字列（リストは値で比べられないため）
final oshiNewsProvider = StreamProvider.autoDispose
    .family<List<OshiNews>, String>((ref, joinedKeys) {
      final keys = joinedKeys.isEmpty ? <String>[] : joinedKeys.split(',');
      return ref
          .watch(oshiNewsRepositoryProvider)
          .watchByOshiKeys(keys, limit: oshiNewsLimit);
    }, retry: firestoreRetry);

/// その推しのお知らせ（[newsKeysOf] のキー）
AsyncValue<List<OshiNews>> watchNewsOf(WidgetRef ref, OshiSummary oshi) =>
    ref.watch(oshiNewsProvider(newsKeysOf(oshi).join(',')));

/// [days] 日以内のものだけ
List<OshiNews> recentNews(List<OshiNews> news, DateTime now, {int days = homeNewsDays}) {
  final since = now.subtract(Duration(days: days));
  return news.where((n) => n.publishedAt.isAfter(since)).toList();
}