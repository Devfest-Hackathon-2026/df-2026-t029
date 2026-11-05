import 'dart:convert';

import '../models/live.dart';
import '../models/performance.dart';
import '../models/reception.dart';

/// カレンダーに追加する予定の種類
enum CalendarEventKind {
  performance('公演'),
  applyEnd('申込締切'),
  payment('入金締切'),
  applyStart('申込開始'),
  result('当落発表');

  const CalendarEventKind(this.label);

  final String label;
}

/// 予定の種類をまとめて選ぶプリセット
enum CalendarPreset {
  compact('コンパクト', {
    CalendarEventKind.performance,
    CalendarEventKind.applyEnd,
  }),
  standard('標準', {
    CalendarEventKind.performance,
    CalendarEventKind.applyEnd,
    CalendarEventKind.payment,
  }),
  all('すべて', {
    CalendarEventKind.performance,
    CalendarEventKind.applyEnd,
    CalendarEventKind.payment,
    CalendarEventKind.applyStart,
    CalendarEventKind.result,
  });

  const CalendarPreset(this.label, this.kinds);

  final String label;
  final Set<CalendarEventKind> kinds;
}

/// Google カレンダーに追加する予定1件分
class CalendarEvent {
  const CalendarEvent({
    required this.sourceId,
    required this.kind,
    required this.title,
    required this.start,
    required this.end,
    this.location,
    this.description = '',
    this.reminderMinutes = const [],
    this.winnersOnly = false,
  });

  /// 元になった公演・受付の ID
  final String sourceId;
  final CalendarEventKind kind;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? location;
  final String description;

  /// 何分前に通知するか
  final List<int> reminderMinutes;

  /// 当選者のみが対象の受付の予定か（5-3 のチェックリストで初期値を外す）
  final bool winnersOnly;

  /// Google カレンダーの予定 ID。同じ公演・受付・種類なら常に同じ値になる。
  /// Calendar API の ID に使える文字（0-9 と a-v）にするため、16進数で表す
  String get eventId => utf8
      .encode('oshiashi:$sourceId:${kind.name}')
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  /// Calendar API に送る形
  Map<String, dynamic> toJson() => {
        'id': eventId,
        'status': 'confirmed',
        'summary': title,
        if (location != null) 'location': location,
        'description': description,
        'start': {
          'dateTime': start.toUtc().toIso8601String(),
          'timeZone': 'Asia/Tokyo',
        },
        'end': {
          'dateTime': end.toUtc().toIso8601String(),
          'timeZone': 'Asia/Tokyo',
        },
        'reminders': {
          'useDefault': false,
          'overrides': [
            for (final m in reminderMinutes) {'method': 'popup', 'minutes': m},
          ],
        },
      };
}

/// 保存済みのライブ・公演・受付から、追加できる予定をすべて作る。
/// 公演・受付は保存済み（id が入っている）であること
List<CalendarEvent> buildCalendarEvents({
  required Live live,
  required List<Performance> performances,
  required List<Reception> receptions,
}) {
  final url = live.officialUrl;
  final footer = [if (url != null) '公式：$url', 'おしあしから追加'].join('\n');

  CalendarEvent receptionEvent(
    Reception r,
    CalendarEventKind kind,
    DateTime at, {
    required bool isDeadline,
  }) {
    // 期限は「30分前〜期限」、それ以外は「その時刻〜30分後」
    final start = isDeadline ? at.subtract(const Duration(minutes: 30)) : at;
    return CalendarEvent(
      sourceId: r.id!,
      kind: kind,
      title: '【${kind.label}】${live.title}／${r.name}',
      start: start,
      end: start.add(const Duration(minutes: 30)),
      description: [
        if (r.prices.isNotEmpty)
          '料金：${r.prices.map((p) => '${p.seat} ${_yen(p.amount)}').join('、')}',
        footer,
      ].join('\n'),
      reminderMinutes: isDeadline ? const [1440, 180] : const [10],
      winnersOnly: r.winnersOnly,
    );
  }

  return [
    for (final p in performances)
      CalendarEvent(
        sourceId: p.id!,
        kind: CalendarEventKind.performance,
        title: '【公演】${live.title}',
        start: p.startAt,
        end: p.startAt.add(const Duration(hours: 3)),
        location: p.venue,
        description: [
          if (p.openAt case final openAt?) '開場：${_time(openAt)}',
          '開演：${_time(p.startAt)}',
          footer,
        ].join('\n'),
        reminderMinutes: const [1440, 180],
      ),
    for (final r in receptions) ...[
      receptionEvent(r, CalendarEventKind.applyEnd, r.applyEndAt,
          isDeadline: true),
      if (r.paymentDeadline case final at?)
        receptionEvent(r, CalendarEventKind.payment, at, isDeadline: true),
      if (r.applyStartAt case final at?)
        receptionEvent(r, CalendarEventKind.applyStart, at, isDeadline: false),
      if (r.resultAt case final at?)
        receptionEvent(r, CalendarEventKind.result, at, isDeadline: false),
    ],
  ];
}

String _time(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// 例：9800 → 9,800円
String _yen(int amount) =>
    '${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}円';