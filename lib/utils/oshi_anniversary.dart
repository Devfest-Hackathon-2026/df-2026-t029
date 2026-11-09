import '../models/oshi.dart';
import '../models/oshi_days.dart';
import '../providers/oshi_days_providers.dart';

/// 記念日の種類（add_O 3.3）
enum OshiEventKind {
  /// 誕生日（個人）
  birthday,

  /// 結成日（グループ）
  formation,

  /// 推し始めて◯年
  years,

  /// 推して◯日（100日ごと）
  days,
}

/// 推しの記念日1件
class OshiEvent {
  const OshiEvent({
    required this.oshi,
    required this.kind,
    required this.date,
    required this.daysAway,
    this.count,
  });

  final OshiSummary oshi;
  final OshiEventKind kind;

  /// 記念日の日付（その日の0時）
  final DateTime date;

  /// 今日から何日後か（今日なら 0）
  final int daysAway;

  /// 年数（years）・日数（days）
  final int? count;
}

bool _isLeap(int year) => (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

/// [date] がその月日か。2月29日は、うるう年でなければ2月28日に祝う
bool _isMonthDay(int month, int day, DateTime date) {
  if (month == 2 && day == 29 && !_isLeap(date.year)) {
    return date.month == 2 && date.day == 28;
  }
  return date.month == month && date.day == day;
}

/// 今日から [withinDays] 日後までの記念日（日付の近い順。add_O 3.3）。
/// [oshis] はフォロー中の推し
List<OshiEvent> oshiEventsWithin(
  List<OshiSummary> oshis,
  OshiDays days,
  DateTime now, {
  int withinDays = 7,
}) {
  final events = <OshiEvent>[];
  for (var i = 0; i <= withinDays; i++) {
    final date = DateTime(now.year, now.month, now.day + i);
    for (final oshi in oshis) {
      final birthday = oshiBirthdayOf(oshi, days);
      if (birthday != null && _isMonthDay(birthday.month, birthday.day, date)) {
        events.add(
          OshiEvent(
            oshi: oshi,
            kind: oshi.kind == OshiKind.group
                ? OshiEventKind.formation
                : OshiEventKind.birthday,
            date: date,
            daysAway: i,
          ),
        );
      }
      final start = oshiStartDateOf(oshi, days);
      if (start == null) continue;
      final years = date.year - start.year;
      if (years >= 1 && _isMonthDay(start.month, start.day, date)) {
        events.add(
          OshiEvent(
            oshi: oshi,
            kind: OshiEventKind.years,
            date: date,
            daysAway: i,
            count: years,
          ),
        );
      }
      final count = oshiDayCount(start, date);
      if (count != null && count % 100 == 0) {
        events.add(
          OshiEvent(
            oshi: oshi,
            kind: OshiEventKind.days,
            date: date,
            daysAway: i,
            count: count,
          ),
        );
      }
    }
  }
  return events;
}
