import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/application.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/performance.dart';
import 'package:oshiashi/models/reception.dart';
import 'package:oshiashi/utils/deadline.dart';

// 「今」は固定する。buildLiveList は端末の日付で切るので、ローカル時刻で作る
// （どのタイムゾーンで実行しても同じ結果になる）。
final now = DateTime(2026, 11, 5, 12);

DateTime h(int hours) => now.add(Duration(hours: hours));

Reception reception({
  String? id = 'r1',
  String? liveId = 'l1',
  DateTime? applyStartAt,
  DateTime? applyEndAt,
  DateTime? resultAt,
  DateTime? paymentDeadline,
  bool winnersOnly = false,
}) => Reception(
  id: id,
  liveId: liveId,
  type: ReceptionType.fc,
  name: 'FC先行',
  applyStartAt: applyStartAt,
  applyEndAt: applyEndAt ?? h(48),
  resultAt: resultAt,
  paymentDeadline: paymentDeadline,
  winnersOnly: winnersOnly,
);

Application app(String receptionId, ApplicationStatus status) =>
    Application(receptionId: receptionId, liveId: 'l1', status: status);

void main() {
  group('nextDeadlineOf（計画書 3.3 の表）', () {
    final r = reception(
      applyEndAt: h(48),
      resultAt: h(96),
      paymentDeadline: h(144),
    );

    test('未申込 → 申込期限', () {
      final d = nextDeadlineOf(r, null, now)!;
      expect(d.kind, DeadlineKind.apply);
      expect(d.at, h(48));
      expect(d.reception, same(r));
      expect(d.isExpired, isFalse);
      expect(d.opensAt, isNull);
    });

    test('申込済 → 当落発表', () {
      final d = nextDeadlineOf(r, ApplicationStatus.applied, now)!;
      expect(d.kind, DeadlineKind.result);
      expect(d.at, h(96));
      expect(d.opensAt, isNull);
    });

    test('当選 → 入金期限', () {
      final d = nextDeadlineOf(r, ApplicationStatus.won, now)!;
      expect(d.kind, DeadlineKind.payment);
      expect(d.at, h(144));
    });

    test('落選・入金済 → なし', () {
      expect(nextDeadlineOf(r, ApplicationStatus.lost, now), isNull);
      expect(nextDeadlineOf(r, ApplicationStatus.paid, now), isNull);
    });

    test('申込済で当落発表が無い → なし', () {
      expect(
        nextDeadlineOf(reception(), ApplicationStatus.applied, now),
        isNull,
      );
    });

    test('当選で入金期限が未発表 → なし', () {
      expect(nextDeadlineOf(reception(), ApplicationStatus.won, now), isNull);
    });

    test('ラベルは日本語', () {
      expect(DeadlineKind.apply.label, '申込期限');
      expect(DeadlineKind.result.label, '当落発表');
      expect(DeadlineKind.payment.label, '入金期限');
    });

    group('期限切れの境界', () {
      test('期限の1マイクロ秒前は期限切れでない', () {
        final at = now.add(const Duration(microseconds: 1));
        expect(
          nextDeadlineOf(reception(applyEndAt: at), null, now)!.isExpired,
          isFalse,
        );
      });

      test('期限ちょうど（now == at）は期限切れ', () {
        expect(
          nextDeadlineOf(reception(applyEndAt: now), null, now)!.isExpired,
          isTrue,
        );
      });

      test('期限を過ぎても null にせず isExpired=true で返す（詳細の「期限切れ」用）', () {
        final d = nextDeadlineOf(reception(applyEndAt: h(-1)), null, now)!;
        expect(d.kind, DeadlineKind.apply);
        expect(d.at, h(-1));
        expect(d.isExpired, isTrue);
      });

      test('当選で入金期限を過ぎていれば isExpired', () {
        final d = nextDeadlineOf(
          reception(paymentDeadline: h(-1)),
          ApplicationStatus.won,
          now,
        )!;
        expect(d.kind, DeadlineKind.payment);
        expect(d.isExpired, isTrue);
      });

      test('UTC で渡しても同じ瞬間として比べる', () {
        final d = nextDeadlineOf(
          reception(applyEndAt: now.toUtc()),
          null,
          now,
        )!;
        expect(d.isExpired, isTrue);
      });
    });

    group('受付開始前（opensAt）', () {
      test('未申込で applyStartAt が先なら opensAt に入る', () {
        final d = nextDeadlineOf(
          reception(applyStartAt: h(24), applyEndAt: h(72)),
          null,
          now,
        )!;
        expect(d.kind, DeadlineKind.apply);
        expect(d.opensAt, h(24));
      });

      test('applyStartAt がちょうど now なら null（もう申し込める）', () {
        final d = nextDeadlineOf(reception(applyStartAt: now), null, now)!;
        expect(d.opensAt, isNull);
      });

      test('applyStartAt が過去なら null', () {
        final d = nextDeadlineOf(reception(applyStartAt: h(-1)), null, now)!;
        expect(d.opensAt, isNull);
      });

      test('applyStartAt が無ければ null', () {
        expect(nextDeadlineOf(reception(), null, now)!.opensAt, isNull);
      });

      test('申込済・当選では applyStartAt が先でも opensAt は入らない', () {
        final r2 = reception(
          applyStartAt: h(24),
          resultAt: h(96),
          paymentDeadline: h(144),
        );
        expect(
          nextDeadlineOf(r2, ApplicationStatus.applied, now)!.opensAt,
          isNull,
        );
        expect(nextDeadlineOf(r2, ApplicationStatus.won, now)!.opensAt, isNull);
      });
    });

    test('winnersOnly の受付も対象（Step7 までは全員に出す）', () {
      final d = nextDeadlineOf(reception(winnersOnly: true), null, now)!;
      expect(d.kind, DeadlineKind.apply);
      expect(d.reception.winnersOnly, isTrue);
    });
  });

  group('upcomingDeadlines', () {
    test('受付が0件なら空', () {
      expect(upcomingDeadlines(const [], const {}, now), isEmpty);
    });

    test('期限切れを除き、近い順に並べる', () {
      final rs = [
        reception(id: 'far', applyEndAt: h(72)),
        reception(id: 'expired', applyEndAt: h(-1)),
        reception(id: 'just', applyEndAt: now),
        reception(id: 'near', applyEndAt: h(1)),
      ];
      final ds = upcomingDeadlines(rs, const {}, now);
      expect([for (final d in ds) d.reception.id], ['near', 'far']);
    });

    test('期限が同じなら受付 ID の順', () {
      final rs = [
        reception(id: 'b', applyEndAt: h(5)),
        reception(id: 'c', applyEndAt: h(5)),
        reception(id: 'a', applyEndAt: h(5)),
      ];
      expect(
        [for (final d in upcomingDeadlines(rs, const {}, now)) d.reception.id],
        ['a', 'b', 'c'],
      );
    });

    test('申込状況で次の締切が切り替わる（当落を押すと次の締切へ）', () {
      final rs = [
        reception(
          id: 'r1',
          applyEndAt: h(1),
          resultAt: h(50),
          paymentDeadline: h(100),
        ),
        reception(id: 'r2', applyEndAt: h(10)),
      ];
      List<(String?, DeadlineKind, DateTime)> run(
        Map<String, Application> apps,
      ) => [
        for (final d in upcomingDeadlines(rs, apps, now))
          (d.reception.id, d.kind, d.at),
      ];

      // 未申込: 申込期限が近い順
      expect(run(const {}), [
        ('r1', DeadlineKind.apply, h(1)),
        ('r2', DeadlineKind.apply, h(10)),
      ]);
      // 申込済: 当落発表に切り替わり、順番も変わる
      expect(run({'r1': app('r1', ApplicationStatus.applied)}), [
        ('r2', DeadlineKind.apply, h(10)),
        ('r1', DeadlineKind.result, h(50)),
      ]);
      // 当選: 入金期限
      expect(run({'r1': app('r1', ApplicationStatus.won)}), [
        ('r2', DeadlineKind.apply, h(10)),
        ('r1', DeadlineKind.payment, h(100)),
      ]);
      // 入金済・落選: 出ない
      for (final s in [ApplicationStatus.paid, ApplicationStatus.lost]) {
        expect(run({'r1': app('r1', s)}), [
          ('r2', DeadlineKind.apply, h(10)),
        ], reason: s.code);
      }
    });

    test('申込期限は過ぎたが、申込済で当落発表がまだ先なら出る', () {
      final rs = [reception(id: 'r1', applyEndAt: h(-24), resultAt: h(24))];
      expect(upcomingDeadlines(rs, const {}, now), isEmpty);
      final ds = upcomingDeadlines(rs, {
        'r1': app('r1', ApplicationStatus.applied),
      }, now);
      expect(ds.single.kind, DeadlineKind.result);
    });

    test('ID が null の受付は未申込として扱い、落ちない', () {
      final ds = upcomingDeadlines(
        [reception(id: null, applyEndAt: h(1))],
        {'r1': app('r1', ApplicationStatus.paid)},
        now,
      );
      expect(ds.single.kind, DeadlineKind.apply);
    });

    test('ほかの受付の申込状況は影響しない', () {
      final ds = upcomingDeadlines(
        [reception(id: 'r1', applyEndAt: h(1))],
        {'other': app('other', ApplicationStatus.paid)},
        now,
      );
      expect(ds.single.reception.id, 'r1');
    });

    test('受付開始前の受付も、opensAt 付きで含まれる', () {
      final ds = upcomingDeadlines(
        [reception(applyStartAt: h(24), applyEndAt: h(48))],
        const {},
        now,
      );
      expect(ds.single.opensAt, h(24));
    });
  });

  group('buildLiveList', () {
    Live live(String? id, String title) => Live(id: id, title: title);
    Performance perf(String? liveId, DateTime startAt, {String? id}) =>
        Performance(id: id, liveId: liveId, startAt: startAt, venue: '会場');
    List<String?> ids(List<LiveListEntry> es) => [
      for (final e in es) e.live.id,
    ];

    test('ライブが0件なら空', () {
      expect(buildLiveList(const [], const [], now), isEmpty);
    });

    test('今日の公演は、開演後も終了にしない（日単位）', () {
      final todayMorning = DateTime(2026, 11, 5, 0, 0);
      final e = buildLiveList(
        [live('l1', 'A')],
        [perf('l1', todayMorning)],
        now,
      ).single;
      expect(e.isEnded, isFalse);
      expect(e.nextStartAt, todayMorning);
    });

    test('昨日の 23:59 の公演だけのライブは終了', () {
      final e = buildLiveList(
        [live('l1', 'A')],
        [perf('l1', DateTime(2026, 11, 4, 23, 59, 59, 999))],
        now,
      ).single;
      expect(e.isEnded, isTrue);
      expect(e.nextStartAt, isNull);
    });

    test('今日が終わる直前（23:59）の時点でも、今日の公演は終了にしない', () {
      final late = DateTime(2026, 11, 5, 23, 59, 59);
      final e = buildLiveList(
        [live('l1', 'A')],
        [perf('l1', DateTime(2026, 11, 5, 10))],
        late,
      ).single;
      expect(e.isEnded, isFalse);
    });

    test('日付が変わったら（翌日 0:00）、前日の公演は終了', () {
      final e = buildLiveList(
        [live('l1', 'A')],
        [perf('l1', DateTime(2026, 11, 5, 23))],
        DateTime(2026, 11, 6),
      ).single;
      expect(e.isEnded, isTrue);
    });

    test('過去と未来の公演が混ざれば終了でない。次は今日以降で最も早い公演', () {
      final e = buildLiveList(
        [live('l1', 'A')],
        [
          perf('l1', DateTime(2026, 11, 20), id: 'p3'),
          perf('l1', DateTime(2026, 11, 1), id: 'p1'),
          perf('l1', DateTime(2026, 11, 8), id: 'p2'),
        ],
        now,
      ).single;
      expect(e.isEnded, isFalse);
      expect(e.nextStartAt, DateTime(2026, 11, 8));
      // performances は開演順
      expect([for (final p in e.performances) p.id], ['p1', 'p2', 'p3']);
    });

    test('performances は変更できない', () {
      final e = buildLiveList(
        [live('l1', 'A')],
        [perf('l1', h(1))],
        now,
      ).single;
      expect(
        () => e.performances.add(perf('l1', h(2))),
        throwsUnsupportedError,
      );
    });

    test('公演0件のライブは終了ではなく、nextStartAt は null', () {
      final e = buildLiveList([live('l1', 'A')], const [], now).single;
      expect(e.isEnded, isFalse);
      expect(e.nextStartAt, isNull);
      expect(e.performances, isEmpty);
    });

    test('並び順: これから（近い順）→ 公演0件 → 終了（最後の公演が新しい順）', () {
      final entries = buildLiveList(
        [
          live('endedOld', 'E1'),
          live('none', 'N'),
          live('far', 'F'),
          live('endedNew', 'E2'),
          live('near', 'R'),
        ],
        [
          perf('endedOld', DateTime(2026, 10, 1)),
          // 最初の公演は古いが、最後の公演で比べる
          perf('endedNew', DateTime(2026, 9, 1)),
          perf('endedNew', DateTime(2026, 11, 3)),
          perf('far', DateTime(2026, 12, 1)),
          perf('near', DateTime(2026, 11, 5, 18)),
        ],
        now,
      );
      expect(ids(entries), ['near', 'far', 'none', 'endedNew', 'endedOld']);
    });

    test('同じ順位ならタイトル → ID の順（どのグループでも）', () {
      final t = DateTime(2026, 11, 10);
      final past = DateTime(2026, 11, 1);
      final entries = buildLiveList(
        [
          live('u2', 'B'),
          live('u1', 'A'),
          live('u0', 'A'),
          live('n2', 'Y'),
          live('n1', 'X'),
          live('e2', 'Q'),
          live('e1', 'P'),
        ],
        [
          perf('u2', t),
          perf('u1', t),
          perf('u0', t),
          perf('e2', past),
          perf('e1', past),
        ],
        now,
      );
      expect(ids(entries), ['u0', 'u1', 'u2', 'n1', 'n2', 'e1', 'e2']);
    });

    test('同じ ID のライブが2回来たら、最初の1件を1行だけ', () {
      final entries = buildLiveList(
        [live('l1', '最初'), live('l1', '2件目')],
        [perf('l1', h(1))],
        now,
      );
      expect(entries.single.live.title, '最初');
      expect(entries.single.performances, hasLength(1));
    });

    test('liveId が null・ほかのライブの公演は振り分けない', () {
      final entries = buildLiveList(
        [live('l1', 'A'), live('l2', 'B')],
        [
          perf(null, h(1)),
          perf('unknown', h(1)),
          perf('l2', DateTime(2026, 11, 1)),
        ],
        now,
      );
      final byId = {for (final e in entries) e.live.id: e};
      expect(byId['l1']!.performances, isEmpty);
      expect(byId['l2']!.performances, hasLength(1));
      expect(byId['l2']!.isEnded, isTrue);
    });

    test('ID が null のライブがあっても落ちない（公演は付かない）', () {
      final entries = buildLiveList(
        [live(null, 'A'), live('l1', 'B')],
        [perf(null, h(1)), perf('l1', h(1))],
        now,
      );
      expect(entries, hasLength(2));
      final noId = entries.firstWhere((e) => e.live.id == null);
      expect(noId.performances, isEmpty);
    });

    test('UTC の開演日時でも、端末の日付で判定する', () {
      // 端末の今日の 0:00 を UTC で表したもの（今日の公演）
      final todayStartUtc = DateTime(2026, 11, 5).toUtc();
      final e = buildLiveList(
        [live('l1', 'A')],
        [perf('l1', todayStartUtc)],
        now,
      ).single;
      expect(e.isEnded, isFalse);
    });
  });

  group('performanceDayOf（公演ごとの日単位の表示）', () {
    test('当日の開演前・開演後は today', () {
      expect(
        performanceDayOf(DateTime(2026, 11, 5, 18), now),
        PerformanceDay.today,
      );
      expect(
        performanceDayOf(DateTime(2026, 11, 5, 10), now),
        PerformanceDay.today,
      );
      // 今日の 0:00 と 23:59:59.999
      expect(
        performanceDayOf(DateTime(2026, 11, 5), now),
        PerformanceDay.today,
      );
      expect(
        performanceDayOf(DateTime(2026, 11, 5, 23, 59, 59, 999), now),
        PerformanceDay.today,
      );
    });

    test('前日の 23:59 の公演は past', () {
      expect(
        performanceDayOf(DateTime(2026, 11, 4, 23, 59, 59, 999), now),
        PerformanceDay.past,
      );
    });

    test('翌日 0:00 の公演は future', () {
      expect(
        performanceDayOf(DateTime(2026, 11, 6), now),
        PerformanceDay.future,
      );
    });

    test('「今」が 23:59 でも、今日の公演は today、翌日 0:00 は future', () {
      final late = DateTime(2026, 11, 5, 23, 59, 59);
      expect(
        performanceDayOf(DateTime(2026, 11, 5, 9), late),
        PerformanceDay.today,
      );
      expect(
        performanceDayOf(DateTime(2026, 11, 6), late),
        PerformanceDay.future,
      );
    });

    test('年・月の変わり目', () {
      expect(
        performanceDayOf(
          DateTime(2026, 12, 31, 23),
          DateTime(2027, 1, 1, 0, 1),
        ),
        PerformanceDay.past,
      );
      expect(
        performanceDayOf(DateTime(2026, 12, 1), DateTime(2026, 11, 30, 23, 59)),
        PerformanceDay.future,
      );
    });

    test('UTC で渡しても、端末の日付で判定する', () {
      expect(
        performanceDayOf(DateTime(2026, 11, 5, 0, 30).toUtc(), now.toUtc()),
        PerformanceDay.today,
      );
    });

    test('buildLiveList の「終了」と同じ判定', () {
      for (final start in [
        DateTime(2026, 11, 4, 23, 59),
        DateTime(2026, 11, 5),
        DateTime(2026, 11, 5, 23),
        DateTime(2026, 11, 6),
      ]) {
        final ended = buildLiveList(
          [const Live(id: 'l1', title: 'A')],
          [Performance(liveId: 'l1', startAt: start, venue: 'v')],
          now,
        ).single.isEnded;
        expect(
          ended,
          performanceDayOf(start, now) == PerformanceDay.past,
          reason: '$start',
        );
      }
    });
  });

  group('upcomingDeadlines の winnerLiveIds', () {
    final upg = Reception(
      id: 'up',
      liveId: 'l1',
      type: ReceptionType.upgrade,
      name: 'アプグレ',
      applyEndAt: h(24),
      winnersOnly: true,
    );
    final fc = reception(id: 'fc', applyEndAt: h(48));

    test('null なら絞らない（従来どおり）', () {
      final r = upcomingDeadlines([upg, fc], {}, now);
      expect([for (final d in r) d.reception.id], ['up', 'fc']);
    });

    test('当選者でなければ winnersOnly を除く', () {
      final r = upcomingDeadlines([upg, fc], {}, now, winnerLiveIds: {});
      expect([for (final d in r) d.reception.id], ['fc']);
      final other = upcomingDeadlines(
        [upg, fc],
        {},
        now,
        winnerLiveIds: {'l2'},
      );
      expect([for (final d in other) d.reception.id], ['fc']);
    });

    test('当選しているライブなら含める', () {
      final r = upcomingDeadlines([upg, fc], {}, now, winnerLiveIds: {'l1'});
      expect([for (final d in r) d.reception.id], ['up', 'fc']);
    });
  });
}
