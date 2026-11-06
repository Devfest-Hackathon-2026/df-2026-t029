// Step4（照合・差分）のテスト用の組み立て関数。
import 'package:oshiashi/features/live_form/live_draft_to_models.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/performance.dart';
import 'package:oshiashi/models/reception.dart';
import 'package:oshiashi/repositories/live_repository.dart';

/// 日本時間の日時（UTC の DateTime で返す。DateTime.now() に依存しない）
DateTime jst(int y, int m, int d, [int h = 0, int min = 0]) =>
    DateTime.utc(y, m, d, h, min).subtract(const Duration(hours: 9));

/// 既存の公演（ID 付き）
Performance existingPerf(
  String id, {
  String liveId = 'L1',
  DateTime? startAt,
  DateTime? openAt,
  String venue = '東京ドーム',
  String? prefecture,
  List<String> groupIds = const ['g1'],
  List<String> oshiIds = const [],
}) => Performance(
  id: id,
  liveId: liveId,
  groupIds: groupIds,
  oshiIds: oshiIds,
  startAt: startAt ?? jst(2026, 12, 20, 18),
  openAt: openAt,
  venue: venue,
  prefecture: prefecture,
);

/// 入力の公演（ID なし）
Performance inputPerf({
  DateTime? startAt,
  DateTime? openAt,
  String venue = '東京ドーム',
  String? prefecture,
}) => Performance(
  startAt: startAt ?? jst(2026, 12, 20, 18),
  openAt: openAt,
  venue: venue,
  prefecture: prefecture,
);

/// 既存の受付（ID 付き）
Reception existingRec(
  String id, {
  String liveId = 'L1',
  ReceptionType type = ReceptionType.fc,
  String name = 'FC1次先行',
  DateTime? applyStartAt,
  DateTime? applyEndAt,
  DateTime? resultAt,
  DateTime? paymentDeadline,
  List<Price> prices = const [],
  bool winnersOnly = false,
  List<String> groupIds = const ['g1'],
  List<String> oshiIds = const [],
}) => Reception(
  id: id,
  liveId: liveId,
  groupIds: groupIds,
  oshiIds: oshiIds,
  type: type,
  name: name,
  applyStartAt: applyStartAt,
  applyEndAt: applyEndAt ?? jst(2026, 11, 20, 23, 59),
  resultAt: resultAt,
  paymentDeadline: paymentDeadline,
  prices: prices,
  winnersOnly: winnersOnly,
);

/// 入力の受付（ID なし）
Reception inputRec({
  ReceptionType type = ReceptionType.fc,
  String name = 'FC1次先行',
  DateTime? applyStartAt,
  DateTime? applyEndAt,
  DateTime? resultAt,
  DateTime? paymentDeadline,
  List<Price> prices = const [],
  bool winnersOnly = false,
}) => Reception(
  type: type,
  name: name,
  applyStartAt: applyStartAt,
  applyEndAt: applyEndAt ?? jst(2026, 11, 20, 23, 59),
  resultAt: resultAt,
  paymentDeadline: paymentDeadline,
  prices: prices,
  winnersOnly: winnersOnly,
);

/// 既存のライブ一式
ExistingLive existingLive({
  String id = 'L1',
  String title = 'ツアー2026',
  List<String> groupIds = const ['g1'],
  List<String> oshiIds = const [],
  String? officialUrl,
  List<Performance>? performances,
  List<Reception> receptions = const [],
}) => ExistingLive(
  live: Live(
    id: id,
    title: title,
    groupIds: groupIds,
    oshiIds: oshiIds,
    officialUrl: officialUrl,
  ),
  performances: performances ?? [existingPerf('${id}p1', liveId: id)],
  receptions: receptions,
);

/// 入力（確認・修正画面の保存時の形）
LiveModels input({
  String title = 'ツアー2026',
  List<String> groupIds = const ['g1'],
  List<String> oshiIds = const [],
  String? officialUrl,
  List<Performance>? performances,
  List<Reception> receptions = const [],
}) => (
  live: Live(
    title: title,
    groupIds: groupIds,
    oshiIds: oshiIds,
    officialUrl: officialUrl,
  ),
  performances: performances ?? [inputPerf()],
  receptions: receptions,
);
