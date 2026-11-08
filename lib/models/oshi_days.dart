/// 月と日（誕生日・結成日。年は持たない）
typedef MonthDay = ({int month, int day});

/// 推しの記念日の設定（`users/{uid}/settings/oshiDays`。add_O 3.1）
class OshiDays {
  const OshiDays({this.startDates = const {}, this.birthdays = const {}});

  static const empty = OshiDays();

  /// 推しの色のキー（`group:xxx`・`person:xxx`）→ 推し始めた日（その日の0時）
  final Map<String, DateTime> startDates;

  /// 推しの色のキー → 誕生日（グループは結成日）
  final Map<String, MonthDay> birthdays;

  factory OshiDays.fromMap(Map<String, dynamic>? data) {
    final starts = data?['startDates'];
    final births = data?['birthdays'];
    return OshiDays(
      startDates: {
        if (starts is Map)
          for (final e in starts.entries)
            if (e.key is String && e.value is String)
              e.key as String: ?parseYmd(e.value as String),
      },
      birthdays: {
        if (births is Map)
          for (final e in births.entries)
            if (e.key is String && e.value is String)
              e.key as String: ?parseMd(e.value as String),
      },
    );
  }
}

/// その月の最終日（2月は29日まで選べるようにする）
int maxDayOfMonth(int month) => switch (month) {
  2 => 29,
  4 || 6 || 9 || 11 => 30,
  _ => 31,
};

String _two(int n) => n.toString().padLeft(2, '0');

/// `YYYY-MM-DD` → その日の0時。形が違えば null
DateTime? parseYmd(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) return null;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

/// その日 → `YYYY-MM-DD`
String formatYmd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// `MM-DD` → 月と日。形が違う・ありえない日なら null
MonthDay? parseMd(String s) {
  final m = RegExp(r'^(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) return null;
  final month = int.parse(m[1]!);
  final day = int.parse(m[2]!);
  if (month < 1 || month > 12 || day < 1 || day > maxDayOfMonth(month)) {
    return null;
  }
  return (month: month, day: day);
}

/// 月と日 → `MM-DD`
String formatMd(MonthDay md) => '${_two(md.month)}-${_two(md.day)}';