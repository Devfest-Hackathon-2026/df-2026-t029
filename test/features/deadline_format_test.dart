import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/live/deadline_format.dart';
import 'package:oshiashi/models/application.dart';
import 'package:oshiashi/models/reception.dart';
import 'package:oshiashi/utils/deadline.dart';

// 「今」は固定する。formatDateTime はそのままの時刻で書くので、ローカル時刻で作る
final now = DateTime(2026, 11, 5, 12); // 木曜

void main() {
  group('remainingLabel', () {
    RemainingLabel at(Duration d) => remainingLabel(now.add(d), now);

    test('ちょうど now・過去は「期限切れ」で、目立たせない', () {
      for (final d in [Duration.zero, const Duration(seconds: -1)]) {
        final r = at(d);
        expect(r.text, '期限切れ');
        expect(r.text, expiredLabel);
        expect(r.isUrgent, isFalse);
        expect(r.isPast, isTrue);
      }
    });

    test('24時間ちょうどは「あと1日」で、目立たせない', () {
      final r = at(const Duration(hours: 24));
      expect(r.text, 'あと1日');
      expect(r.isUrgent, isFalse);
      expect(r.isPast, isFalse);
    });

    test('日数は切り捨て（47時間59分は「あと1日」、48時間は「あと2日」）', () {
      expect(at(const Duration(hours: 47, minutes: 59)).text, 'あと1日');
      expect(at(const Duration(hours: 48)).text, 'あと2日');
      expect(at(const Duration(days: 30)).text, 'あと30日');
    });

    test('24時間の1マイクロ秒前は「あと23時間」で、目立たせる', () {
      final r = at(const Duration(hours: 24) - const Duration(microseconds: 1));
      expect(r.text, 'あと23時間');
      expect(r.isUrgent, isTrue);
    });

    test('1時間ちょうどは「あと1時間」', () {
      final r = at(const Duration(hours: 1));
      expect(r.text, 'あと1時間');
      expect(r.isUrgent, isTrue);
    });

    test('1時間未満は「あと○分」（切り捨て）', () {
      expect(at(const Duration(minutes: 59, seconds: 59)).text, 'あと59分');
      expect(at(const Duration(minutes: 1)).text, 'あと1分');
      expect(at(const Duration(minutes: 1)).isUrgent, isTrue);
    });

    test('1分未満（0 < 残り < 1分）は「あと1分未満」で、目立たせる', () {
      for (final d in [
        const Duration(microseconds: 1),
        const Duration(seconds: 30),
        const Duration(minutes: 1) - const Duration(microseconds: 1),
      ]) {
        final r = at(d);
        expect(r.text, 'あと1分未満', reason: '$d');
        expect(r.isUrgent, isTrue, reason: '$d');
        expect(r.isPast, isFalse, reason: '$d');
      }
    });

    test('入金期限まで30秒なら「入金期限まであと1分未満」', () {
      final t = describeNextDeadline(
        NextDeadline(
          kind: DeadlineKind.payment,
          at: now.add(const Duration(seconds: 30)),
          reception: Reception(
            id: 'r1',
            type: ReceptionType.fc,
            name: 'FC',
            applyEndAt: now,
          ),
        ),
        now,
      );
      expect(t.text, '入金期限まであと1分未満');
      expect(t.isUrgent, isTrue);
    });

    test('UTC で渡しても同じ瞬間として比べる', () {
      final r = remainingLabel(now.add(const Duration(hours: 2)).toUtc(), now);
      expect(r.text, 'あと2時間');
    });
  });

  group('describeNextDeadline', () {
    Reception reception({DateTime? applyStartAt}) => Reception(
      id: 'r1',
      liveId: 'l1',
      type: ReceptionType.fc,
      name: 'FC先行',
      applyStartAt: applyStartAt,
      applyEndAt: now.add(const Duration(days: 2)),
    );

    NextDeadline deadline(
      DeadlineKind kind,
      DateTime at, {
      DateTime? opensAt,
    }) => NextDeadline(
      kind: kind,
      at: at,
      reception: reception(),
      opensAt: opensAt,
      isExpired: !now.isBefore(at),
    );

    test('申込期限: 「申込期限まであと2日」', () {
      final t = describeNextDeadline(
        deadline(DeadlineKind.apply, now.add(const Duration(days: 2))),
        now,
      );
      expect(t.text, '申込期限まであと2日');
      expect(t.isUrgent, isFalse);
      expect(t.isExpired, isFalse);
      expect(t.opensText, isNull);
    });

    test('入金期限が24時間以内なら目立たせる: 「入金期限まであと5時間」', () {
      final t = describeNextDeadline(
        deadline(DeadlineKind.payment, now.add(const Duration(hours: 5))),
        now,
      );
      expect(t.text, '入金期限まであと5時間');
      expect(t.isUrgent, isTrue);
    });

    test('申込期限が24時間以内なら目立たせる', () {
      final t = describeNextDeadline(
        deadline(DeadlineKind.apply, now.add(const Duration(minutes: 30))),
        now,
      );
      expect(t.text, '申込期限まであと30分');
      expect(t.isUrgent, isTrue);
    });

    test('当落発表は日時で出し、24時間以内でも目立たせない', () {
      final t = describeNextDeadline(
        deadline(DeadlineKind.result, DateTime(2026, 11, 5, 18)),
        now,
      );
      expect(t.text, '当落発表 2026/11/5(木) 18:00');
      expect(t.isUrgent, isFalse);
      expect(t.isExpired, isFalse);
    });

    test('期限切れ: 申込期限・入金期限は「○○を過ぎました」', () {
      for (final (kind, text) in [
        (DeadlineKind.apply, '申込期限を過ぎました'),
        (DeadlineKind.payment, '入金期限を過ぎました'),
      ]) {
        final t = describeNextDeadline(deadline(kind, now), now);
        expect(t.text, text);
        expect(t.isExpired, isTrue);
        expect(t.isUrgent, isFalse);
      }
    });

    test('期限切れ: 当落発表は「（発表済み）」', () {
      final t = describeNextDeadline(
        deadline(DeadlineKind.result, DateTime(2026, 11, 4, 18)),
        now,
      );
      expect(t.text, '当落発表 2026/11/4(水) 18:00（発表済み）');
      expect(t.isExpired, isTrue);
      expect(t.isUrgent, isFalse);
    });

    test('受付開始前なら「受付開始 …〜」を添える', () {
      final t = describeNextDeadline(
        deadline(
          DeadlineKind.apply,
          now.add(const Duration(days: 5)),
          opensAt: DateTime(2026, 11, 10, 10),
        ),
        now,
      );
      expect(t.opensText, '受付開始 2026/11/10(火) 10:00〜');
      expect(t.text, '申込期限まであと5日');
    });

    test('nextDeadlineOf の結果をそのまま渡せる（申込状況で文が変わる）', () {
      final r = Reception(
        id: 'r1',
        liveId: 'l1',
        type: ReceptionType.fc,
        name: 'FC先行',
        applyEndAt: now.add(const Duration(days: 2)),
        resultAt: DateTime(2026, 11, 20, 18),
        paymentDeadline: now.add(const Duration(hours: 5)),
      );
      expect(
        describeNextDeadline(nextDeadlineOf(r, null, now)!, now).text,
        '申込期限まであと2日',
      );
      expect(
        describeNextDeadline(
          nextDeadlineOf(r, ApplicationStatus.applied, now)!,
          now,
        ).text,
        '当落発表 2026/11/20(金) 18:00',
      );
    });
  });
}
