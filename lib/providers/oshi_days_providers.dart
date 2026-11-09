import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/oshi.dart';
import '../models/oshi_days.dart';
import '../repositories/oshi_days_repository.dart';
import 'oshi_color_providers.dart';
import 'oshi_providers.dart';

/// 推しの記念日のリポジトリ。テストでは `overrideWithValue` で差し替える
final oshiDaysRepositoryProvider = Provider<OshiDaysRepository>(
  (ref) => FirestoreOshiDaysRepository(FirebaseFirestore.instance),
);

/// 推しの記念日の設定。未ログインなら空（add_O 3.1）
final oshiDaysProvider = StreamProvider<OshiDays>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(OshiDays.empty);
  return ref.watch(oshiDaysRepositoryProvider).watch(uid);
}, retry: firestoreRetry);

/// その推しの推し始めた日
DateTime? oshiStartDateOf(OshiSummary oshi, OshiDays days) =>
    days.startDates[oshiColorKey(oshi.kind, oshi.id)];

/// その推しの誕生日（グループは結成日）
MonthDay? oshiBirthdayOf(OshiSummary oshi, OshiDays days) =>
    days.birthdays[oshiColorKey(oshi.kind, oshi.id)];

/// 推して何日目か（推し始めた日を1日目とする。add_O 3.2）。
/// 推し始めた日が今日より後なら null
int? oshiDayCount(DateTime start, DateTime now) {
  final s = DateTime.utc(start.year, start.month, start.day);
  final t = DateTime.utc(now.year, now.month, now.day);
  final diff = t.difference(s).inDays;
  return diff < 0 ? null : diff + 1;
}
