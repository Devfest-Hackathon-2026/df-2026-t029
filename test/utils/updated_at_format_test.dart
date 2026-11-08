import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/utils/updated_at_format.dart';

void main() {
  // 「いま」は固定する（2026/11/8）
  final now = DateTime(2026, 11, 8, 12);

  test('今年は年を省略する（時刻つき）', () {
    expect(
      formatUpdatedAt(DateTime(2026, 11, 9, 9), now: now),
      '11/9(月) 09:00',
    );
  });

  test('今年は年を省略する（日付だけ）', () {
    expect(
      formatUpdatedAt(DateTime(2026, 11, 9, 9), now: now, withTime: false),
      '11/9(月)',
    );
  });

  test('去年は年を付ける', () {
    expect(
      formatUpdatedAt(DateTime(2025, 12, 31, 9), now: now),
      '2025/12/31(水) 09:00',
    );
    expect(
      formatUpdatedAt(DateTime(2025, 12, 31, 9), now: now, withTime: false),
      '2025/12/31(水)',
    );
  });

  test('来年も年を付ける', () {
    expect(
      formatUpdatedAt(DateTime(2027, 1, 1, 0, 5), now: now),
      '2027/1/1(金) 00:05',
    );
  });

  test('年末年始: 12/31 と 1/1 で、いまの年を基準に年が付く', () {
    final newYearsEve = DateTime(2026, 12, 31, 23, 59);
    expect(formatUpdatedAt(newYearsEve, now: newYearsEve), '12/31(木) 23:59');
    expect(
      formatUpdatedAt(newYearsEve, now: DateTime(2027, 1, 1, 0, 0)),
      '2026/12/31(木) 23:59',
    );
  });

  test('曜日は月〜日の7通りすべて', () {
    const expected = ['月', '火', '水', '木', '金', '土', '日'];
    for (var i = 0; i < 7; i++) {
      final d = DateTime(2026, 11, 9 + i, 9);
      expect(
        formatUpdatedAt(d, now: now, withTime: false),
        '11/${9 + i}(${expected[i]})',
      );
    }
  });

  test('時刻は 0 埋め（0時5分・9時0分）', () {
    expect(
      formatUpdatedAt(DateTime(2026, 1, 5, 0, 5), now: now),
      '1/5(月) 00:05',
    );
    expect(
      formatUpdatedAt(DateTime(2026, 1, 5, 9, 0), now: now),
      '1/5(月) 09:00',
    );
  });
}
