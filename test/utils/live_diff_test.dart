// diffLive・pairManually・withoutUnselected と、変更履歴の表示用の関数
// （計画書 3.2・3.3・3.6）のテスト
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/history_entry.dart';
import 'package:oshiashi/models/reception.dart';
import 'package:oshiashi/utils/live_diff.dart';

import 'live_merge_fixtures.dart';

const _p = HistoryCollection.performances;
const _r = HistoryCollection.receptions;

void main() {
  group('日付の基本', () {
    test('jstDayOf: UTC 14:59 は同じ日、15:00 で翌日（日本時間の0時）', () {
      final a = DateTime.utc(2026, 12, 20, 14, 59);
      final b = DateTime.utc(2026, 12, 20, 15, 0);
      expect(jstDayOf(a), DateTime.utc(2026, 12, 20));
      expect(jstDayOf(b), DateTime.utc(2026, 12, 21));
      expect(isSameJstDay(a, b), isFalse);
      expect(
        isSameJstDay(jst(2026, 12, 20, 0), jst(2026, 12, 20, 23, 59)),
        isTrue,
      );
    });

    test('normalizeUrl: 前後の空白・末尾の / ・大文字小文字を無視', () {
      expect(normalizeUrl(' HTTPS://E.com/A// '), 'https://e.com/a');
      expect(normalizeUrl(''), '');
    });
  });

  group('回帰: 同じ日・同じ会場の昼公演と夜公演（レビュー記録 D3 重大）', () {
    final base = existingLive(
      performances: [
        existingPerf('day', startAt: jst(2026, 12, 20, 13), venue: 'A'),
        existingPerf('night', startAt: jst(2026, 12, 20, 18), venue: 'A'),
      ],
    );

    test('夜の公演だけを入力しても、昼公演を変更しない（夜と対応して変化なし）', () {
      final plan = diffLive(
        base,
        input(
          performances: [inputPerf(startAt: jst(2026, 12, 20, 18), venue: 'A')],
        ),
      );
      expect(plan.changedPerformances, isEmpty);
      expect(plan.unchangedPerformances.map((p) => p.id), ['night']);
      expect(plan.existingOnlyPerformances.map((p) => p.id), ['day']);
      expect(plan.isEmpty, isTrue);
    });

    test('夜→昼の順に入力しても、入れ替えの変更を出さない', () {
      final plan = diffLive(
        base,
        input(
          performances: [
            inputPerf(startAt: jst(2026, 12, 20, 18), venue: 'A'),
            inputPerf(startAt: jst(2026, 12, 20, 13), venue: 'A'),
          ],
        ),
      );
      expect(plan.changedPerformances, isEmpty);
      expect(plan.unchangedPerformances.map((p) => p.id), ['day', 'night']);
      expect(plan.isEmpty, isTrue);
    });

    test('昼・夜があるときに時刻の違う公演を1件入力しても、どちらかに勝手に対応しない', () {
      final plan = diffLive(
        base,
        input(
          performances: [inputPerf(startAt: jst(2026, 12, 20, 17), venue: 'A')],
        ),
      );
      expect(plan.changedPerformances, isEmpty);
      expect(plan.addedPerformances, hasLength(1));
      expect(plan.existingOnlyPerformances, hasLength(2));
    });
  });

  group('編集で外そうとした出演者（ignoredPerformerRemovals）', () {
    test('編集で外した出演者は計画に残り、mergedLive からは外れない', () {
      final base = existingLive(groupIds: ['g1', 'g2'], oshiIds: ['o1']);
      final plan = diffLive(
        base,
        input(groupIds: ['g1'], oshiIds: const []),
        editing: true,
      );
      expect(plan.ignoredPerformerRemovals.groupIds, ['g2']);
      expect(plan.ignoredPerformerRemovals.oshiIds, ['o1']);
      expect(plan.mergedLive.groupIds, ['g1', 'g2']);
      expect(plan.liveChanges, isEmpty);
    });

    test('照合（editing=false）では入力に無い出演者を「外した」扱いにしない', () {
      final base = existingLive(groupIds: ['g1', 'g2']);
      final plan = diffLive(base, input(groupIds: ['g1']));
      expect(plan.ignoredPerformerRemovals.groupIds, isEmpty);
      expect(plan.ignoredPerformerRemovals.oshiIds, isEmpty);
    });
  });

  group('公演の対応付け（3.2）', () {
    test('同じ日・同じ会場（正規化）なら対応が付き、時刻の違いは変更になる', () {
      final base = existingLive(
        performances: [existingPerf('p1', startAt: jst(2026, 12, 20, 18))],
      );
      final plan = diffLive(
        base,
        input(
          performances: [
            inputPerf(startAt: jst(2026, 12, 20, 17), venue: '東京 ドーム'),
          ],
        ),
      );
      expect(plan.addedPerformances, isEmpty);
      final d = plan.changedPerformances.single;
      expect(d.existing.id, 'p1');
      expect(d.changes.map((c) => c.key), ['performances/p1/startAt']);
      expect(d.merged.startAt.isAtSameMomentAs(jst(2026, 12, 20, 17)), isTrue);
      expect(d.merged.id, 'p1');
      // 会場の表記の揺れだけなら変更にしない
      expect(d.changes.where((c) => c.field == 'venue'), isEmpty);
    });

    test('日本時間の日の境界: 既存 23:59 と入力 翌0:00 は別の公演（追加）', () {
      final base = existingLive(
        performances: [existingPerf('p1', startAt: jst(2026, 12, 20, 23, 59))],
      );
      final plan = diffLive(
        base,
        input(performances: [inputPerf(startAt: jst(2026, 12, 21, 0, 0))]),
      );
      expect(plan.addedPerformances.single.key, 'performances/+0');
      expect(plan.existingOnlyPerformances.single.id, 'p1');
      expect(plan.changedPerformances, isEmpty);
    });

    test('会場が違えば、同じ日でも対応しない（追加＋今回の入力に無い）', () {
      final base = existingLive(performances: [existingPerf('p1', venue: 'A')]);
      final plan = diffLive(base, input(performances: [inputPerf(venue: 'B')]));
      expect(plan.addedPerformances, hasLength(1));
      expect(plan.existingOnlyPerformances.single.id, 'p1');
    });

    test('会場が片方だけ空なら、その日が1対1のときだけ対応する', () {
      final base = existingLive(performances: [existingPerf('p1', venue: 'A')]);
      final one = diffLive(
        base,
        input(
          performances: [inputPerf(startAt: jst(2026, 12, 20, 17), venue: '')],
        ),
      );
      expect(one.addedPerformances, isEmpty);
      // 会場は空の値なので上書きしない。時刻だけ変わる
      expect(one.changedPerformances.single.changes.map((c) => c.field), [
        'startAt',
      ]);

      // 既存の同じ日の公演が2件（昼・夜）なら決まらないので追加
      final two = existingLive(
        performances: [
          existingPerf('p1', startAt: jst(2026, 12, 20, 13), venue: 'A'),
          existingPerf('p2', startAt: jst(2026, 12, 20, 18), venue: 'B'),
        ],
      );
      final plan2 = diffLive(
        two,
        input(
          performances: [inputPerf(startAt: jst(2026, 12, 20, 17), venue: '')],
        ),
      );
      expect(plan2.addedPerformances, hasLength(1));
      expect(plan2.existingOnlyPerformances, hasLength(2));

      // 入力の同じ日の公演が2件でも決まらない
      final plan3 = diffLive(
        base,
        input(
          performances: [
            inputPerf(startAt: jst(2026, 12, 20, 13), venue: ''),
            inputPerf(startAt: jst(2026, 12, 20, 18), venue: ''),
          ],
        ),
      );
      expect(plan3.addedPerformances, hasLength(2));
    });

    test('編集: ID の指定が優先され、日付が変わっても同じ公演の変更になる', () {
      final base = existingLive(
        performances: [
          existingPerf('p1', startAt: jst(2026, 12, 20, 18)),
          existingPerf('p2', startAt: jst(2026, 12, 21, 18)),
        ],
      );
      final plan = diffLive(
        base,
        input(
          performances: [
            inputPerf(startAt: jst(2026, 12, 27, 18)), // p1 の日程変更
            inputPerf(startAt: jst(2026, 12, 21, 18)), // p2 そのまま
            inputPerf(startAt: jst(2026, 12, 28, 18)), // 新しく足した行
          ],
        ),
        performanceIds: ['p1', 'p2', null],
        editing: true,
      );
      expect(plan.changedPerformances.single.existing.id, 'p1');
      expect(plan.unchangedPerformances.single.id, 'p2');
      expect(plan.addedPerformances.single.key, 'performances/+2');
      expect(plan.existingOnlyPerformances, isEmpty);
    });
  });

  group('受付の対応付け（3.2）', () {
    test('種別と正規化した名前が同じなら対応する', () {
      final base = existingLive(
        receptions: [existingRec('r1', name: 'FC1次先行')],
      );
      final plan = diffLive(
        base,
        input(
          receptions: [
            inputRec(name: 'ＦＣ１次 先行', applyEndAt: jst(2026, 11, 18, 23, 59)),
          ],
        ),
      );
      final d = plan.changedReceptions.single;
      expect(d.existing.id, 'r1');
      expect(d.changes.map((c) => c.field), ['applyEndAt']);
    });

    test('名前が同じでも種別が違えば対応しない', () {
      final base = existingLive(receptions: [existingRec('r1')]);
      final plan = diffLive(
        base,
        input(
          receptions: [
            inputRec(type: ReceptionType.general, applyEndAt: jst(2026, 12, 1)),
          ],
        ),
      );
      expect(plan.addedReceptions, hasLength(1));
      expect(plan.existingOnlyReceptions.single.id, 'r1');
    });

    test('名前が違っても、種別と申込期限の日付が同じで1対1なら対応する', () {
      final base = existingLive(receptions: [existingRec('r1', name: 'FC先行')]);
      final plan = diffLive(
        base,
        input(
          receptions: [
            inputRec(name: 'ファンクラブ1次', applyEndAt: jst(2026, 11, 20, 18)),
          ],
        ),
      );
      final d = plan.changedReceptions.single;
      expect(d.existing.id, 'r1');
      expect(
        d.changes.map((c) => c.field),
        containsAll(['name', 'applyEndAt']),
      );
    });

    test('種別と申込期限の日付が同じ既存が2件なら決まらない（追加）', () {
      final base = existingLive(
        receptions: [
          existingRec('r1', name: 'FC1次'),
          existingRec('r2', name: 'FC2次'),
        ],
      );
      final plan = diffLive(base, input(receptions: [inputRec(name: 'FC最速')]));
      expect(plan.addedReceptions, hasLength(1));
      expect(plan.existingOnlyReceptions, hasLength(2));
    });

    test('申込期限の日付の境界（日本時間）: 23:59 と翌0:00 は別の日', () {
      final base = existingLive(
        receptions: [
          existingRec('r1', name: 'A', applyEndAt: jst(2026, 11, 20, 23, 59)),
        ],
      );
      final plan = diffLive(
        base,
        input(
          receptions: [
            inputRec(name: 'B', applyEndAt: jst(2026, 11, 21, 0, 0)),
          ],
        ),
      );
      expect(plan.addedReceptions, hasLength(1));
    });

    test('編集: ID の指定が優先される（種別を変えても同じ受付）', () {
      final base = existingLive(receptions: [existingRec('r1')]);
      final plan = diffLive(
        base,
        input(
          receptions: [inputRec(type: ReceptionType.general, name: '一般')],
        ),
        receptionIds: ['r1'],
        editing: true,
      );
      final d = plan.changedReceptions.single;
      expect(d.existing.id, 'r1');
      expect(d.changes.map((c) => c.field), containsAll(['type', 'name']));
      expect(d.changes.firstWhere((c) => c.field == 'type').after, 'general');
    });
  });

  group('反映の規則（3.3）', () {
    test('入力が空の任意項目では、既存の値を上書きしない（照合）', () {
      final base = existingLive(
        officialUrl: 'https://e.com/t',
        performances: [
          existingPerf('p1', openAt: jst(2026, 12, 20, 17), prefecture: '東京都'),
        ],
        receptions: [
          existingRec(
            'r1',
            applyStartAt: jst(2026, 11, 1, 10),
            resultAt: jst(2026, 11, 25, 15),
            paymentDeadline: jst(2026, 11, 28, 23, 59),
            prices: const [Price(seat: 'S席', amount: 9800)],
          ),
        ],
      );
      final plan = diffLive(base, input(receptions: [inputRec()]));
      expect(plan.isEmpty, isTrue);
      expect(plan.liveChanges, isEmpty);
      expect(plan.unchangedPerformances.single.id, 'p1');
      expect(plan.unchangedReceptions.single.id, 'r1');
    });

    test('既存が空の任意項目に値を入れると、hasBefore が false の変更', () {
      final base = existingLive(receptions: [existingRec('r1')]);
      final plan = diffLive(
        base,
        input(
          receptions: [inputRec(paymentDeadline: jst(2026, 11, 28, 23, 59))],
        ),
      );
      final c = plan.changedReceptions.single.changes.single;
      expect(c.key, 'receptions/r1/paymentDeadline');
      expect(c.hasBefore, isFalse);
      expect(c.before, isNull);
      expect(c.after, Timestamp.fromDate(jst(2026, 11, 28, 23, 59)));
    });

    test('出演者は和集合（既存を外さない。新しいものだけ後ろに足す）', () {
      final base = existingLive(groupIds: ['g1', 'g2'], oshiIds: ['o1']);
      final plan = diffLive(
        base,
        input(groupIds: ['g3', 'g1'], oshiIds: const []),
      );
      final g = plan.liveChanges.singleWhere((c) => c.field == 'groupIds');
      expect(g.before, ['g1', 'g2']);
      expect(g.after, ['g1', 'g2', 'g3']);
      expect(plan.liveChanges.where((c) => c.field == 'oshiIds'), isEmpty);
      expect(plan.mergedLive.groupIds, ['g1', 'g2', 'g3']);
      expect(plan.mergedLive.oshiIds, ['o1']);
    });

    test('入力の出演者が既存の一部だけなら、出演者の変更は無い', () {
      final base = existingLive(groupIds: ['g1', 'g2']);
      expect(diffLive(base, input(groupIds: ['g2'])).isEmpty, isTrue);
    });

    test('料金の順番の違いだけなら変化なし。金額が違えば変更', () {
      const s = Price(seat: 'S席', amount: 9800);
      const a = Price(seat: 'A席', amount: 7800);
      final base = existingLive(
        receptions: [
          existingRec('r1', prices: const [s, a]),
        ],
      );
      expect(
        diffLive(
          base,
          input(
            receptions: [
              inputRec(prices: const [a, s]),
            ],
          ),
        ).isEmpty,
        isTrue,
      );
      final plan = diffLive(
        base,
        input(
          receptions: [
            inputRec(
              prices: const [
                a,
                Price(seat: 'S席', amount: 9900),
              ],
            ),
          ],
        ),
      );
      expect(plan.changedReceptions.single.changes.single.field, 'prices');
    });

    test('照合では、入力の winnersOnly=false で既存の true を消さない。編集では消す', () {
      final base = existingLive(
        receptions: [existingRec('r1', winnersOnly: true)],
      );
      final inp = input(receptions: [inputRec(winnersOnly: false)]);
      expect(diffLive(base, inp).isEmpty, isTrue);
      final edit = diffLive(base, inp, receptionIds: ['r1'], editing: true);
      final c = edit.changedReceptions.single.changes.single;
      expect(c.field, 'winnersOnly');
      expect((c.before, c.after), (true, false));
      // false → true は照合でも変更
      final base2 = existingLive(receptions: [existingRec('r1')]);
      expect(
        diffLive(
          base2,
          input(receptions: [inputRec(winnersOnly: true)]),
        ).changedReceptions.single.changes.single.field,
        'winnersOnly',
      );
    });

    test('編集では表記の揺れも変更（文字どおり比べる）。照合では変化なし', () {
      final base = existingLive(title: 'ツアー2026');
      expect(diffLive(base, input(title: 'つあー２０２６')).isEmpty, isTrue);
      final edit = diffLive(base, input(title: 'つあー２０２６'), editing: true);
      expect(edit.liveChanges.single.key, 'live/title');
    });

    test('編集では、空にした任意項目は消す変更、料金は []、必須項目は消さない', () {
      final base = existingLive(
        officialUrl: 'https://e.com/t',
        performances: [
          existingPerf('p1', openAt: jst(2026, 12, 20, 17), prefecture: '東京都'),
        ],
        receptions: [
          existingRec(
            'r1',
            paymentDeadline: jst(2026, 11, 28),
            prices: const [Price(seat: 'S', amount: 1)],
          ),
        ],
      );
      final plan = diffLive(
        base,
        input(
          performances: [inputPerf(venue: '')], // 必須の会場を空にしても消さない
          receptions: [inputRec()],
        ),
        performanceIds: ['p1'],
        receptionIds: ['r1'],
        editing: true,
      );
      final url = plan.liveChanges.single;
      expect((url.field, url.hasAfter), ('officialUrl', false));
      expect(plan.mergedLive.officialUrl, isNull);

      final pc = plan.changedPerformances.single.changes;
      expect(pc.map((c) => c.field), unorderedEquals(['openAt', 'prefecture']));
      expect(pc.every((c) => !c.hasAfter), isTrue);
      expect(plan.changedPerformances.single.merged.venue, '東京ドーム');

      final rc = plan.changedReceptions.single.changes;
      final prices = rc.singleWhere((c) => c.field == 'prices');
      expect(prices.hasAfter, isTrue);
      expect(prices.after, isEmpty);
      expect(
        rc.singleWhere((c) => c.field == 'paymentDeadline').hasAfter,
        isFalse,
      );
    });

    test('変更も追加も無ければ isEmpty（selectableKeys が空）', () {
      final plan = diffLive(existingLive(), input());
      expect(plan.isEmpty, isTrue);
      expect(plan.selectableKeys, isEmpty);
      expect(plan.unchangedPerformances.single.id, 'L1p1');
    });

    test('既存にだけある公演・受付は消さず existingOnly に残る', () {
      final base = existingLive(
        performances: [
          existingPerf('p1'),
          existingPerf('p2', startAt: jst(2026, 12, 21, 18)),
        ],
        receptions: [existingRec('r1')],
      );
      final plan = diffLive(base, input());
      expect(plan.existingOnlyPerformances.map((p) => p.id), ['p2']);
      expect(plan.existingOnlyReceptions.map((r) => r.id), ['r1']);
      expect(plan.isEmpty, isTrue);
    });
  });

  group('pairManually（日程変更の手動の対応付け）', () {
    LiveMergePlan reschedule() => diffLive(
      existingLive(
        performances: [
          existingPerf('p1', startAt: jst(2026, 12, 20, 18)),
          existingPerf('p2', startAt: jst(2026, 12, 21, 18)),
        ],
        receptions: [existingRec('r1', name: 'FC1次')],
      ),
      input(
        performances: [
          inputPerf(startAt: jst(2026, 12, 21, 18)), // p2 と同じ
          inputPerf(startAt: jst(2026, 12, 27, 18)), // p1 の振替
        ],
        receptions: [inputRec(name: '一般', type: ReceptionType.general)],
      ),
    );

    test('追加を既存の変更にする。ほかの行のキーは変わらない', () {
      final plan = reschedule();
      expect(plan.addedPerformances.single.key, 'performances/+1');
      final keysBefore = plan.selectableKeys..remove('performances/+1');

      final paired = pairManually(
        plan,
        addedKey: 'performances/+1',
        existingId: 'p1',
      );
      expect(paired.addedPerformances, isEmpty);
      expect(paired.existingOnlyPerformances, isEmpty);
      final d = paired.changedPerformances.single;
      expect(d.existing.id, 'p1');
      expect(d.inputIndex, 1);
      expect(d.changes.single.key, 'performances/p1/startAt');
      expect(paired.selectableKeys, containsAll(keysBefore));
    });

    test('手で対応付けると変更になる。差が無ければ unchanged に入る', () {
      final base = existingLive(
        performances: [
          existingPerf('p1', startAt: jst(2026, 12, 20, 18), venue: 'A'),
        ],
      );
      // 会場が違うので自動では対応しないが、手で対応付けると会場の変更になる
      final plan = diffLive(base, input(performances: [inputPerf(venue: 'B')]));
      final paired = pairManually(
        plan,
        addedKey: 'performances/+0',
        existingId: 'p1',
      );
      expect(paired.changedPerformances.single.changes.single.field, 'venue');

      // 会場が空で、同じ日の既存が2件あるので自動では決まらない。
      // 手で p1 に対応付けると、開演も同じで会場は上書きしないので差が無い
      final base2 = existingLive(
        performances: [
          existingPerf('p1', startAt: jst(2026, 12, 20, 18), venue: 'A'),
          existingPerf('p2', startAt: jst(2026, 12, 20, 13), venue: 'B'),
        ],
      );
      final plan2 = diffLive(
        base2,
        input(
          performances: [inputPerf(startAt: jst(2026, 12, 20, 18), venue: '')],
        ),
      );
      expect(plan2.addedPerformances, hasLength(1));
      final paired2 = pairManually(
        plan2,
        addedKey: 'performances/+0',
        existingId: 'p1',
      );
      expect(paired2.changedPerformances, isEmpty);
      expect(paired2.unchangedPerformances.single.id, 'p1');
      expect(paired2.existingOnlyPerformances.single.id, 'p2');
      expect(paired2.isEmpty, isTrue);
    });

    test('existingOnly に無い ID・種類違い・知らないキーは ArgumentError', () {
      final plan = reschedule();
      // p2 は自動で対応済み（unchanged）なので選べない
      expect(
        () => pairManually(plan, addedKey: 'performances/+1', existingId: 'p2'),
        throwsArgumentError,
      );
      // 公演の追加に受付の ID
      expect(
        () => pairManually(plan, addedKey: 'performances/+1', existingId: 'r1'),
        throwsArgumentError,
      );
      // 受付の追加に公演の ID
      expect(
        () => pairManually(plan, addedKey: 'receptions/+0', existingId: 'p1'),
        throwsArgumentError,
      );
      expect(
        () => pairManually(plan, addedKey: 'performances/+9', existingId: 'p1'),
        throwsArgumentError,
      );
    });

    test('受付も同じように対応付けられる', () {
      final paired = pairManually(
        reschedule(),
        addedKey: 'receptions/+0',
        existingId: 'r1',
      );
      expect(paired.addedReceptions, isEmpty);
      expect(
        paired.changedReceptions.single.changes.map((c) => c.field),
        containsAll(['type', 'name']),
      );
    });
  });

  group('withoutUnselected', () {
    LiveMergePlan plan() => diffLive(
      existingLive(groupIds: ['g1'], receptions: [existingRec('r1')]),
      input(
        groupIds: ['g1', 'g2'],
        title: 'ツアー2026',
        performances: [
          inputPerf(),
          inputPerf(startAt: jst(2026, 12, 22, 18)),
        ],
        receptions: [
          inputRec(
            paymentDeadline: jst(2026, 11, 28),
            resultAt: jst(2026, 11, 25),
          ),
        ],
      ),
    );

    test('空の集合なら同じ計画。知らないキーは無視', () {
      final p = plan();
      expect(identical(withoutUnselected(p, const {}), p), isTrue);
      expect(withoutUnselected(p, {'xxx'}).selectableKeys, p.selectableKeys);
    });

    test('一部の項目だけ外すと、merged はその項目を除いて作り直す', () {
      final p = withoutUnselected(plan(), {'receptions/r1/resultAt'});
      final d = p.changedReceptions.single;
      expect(d.changes.map((c) => c.field), ['paymentDeadline']);
      expect(d.merged.resultAt, isNull);
      expect(
        d.merged.paymentDeadline!.isAtSameMomentAs(jst(2026, 11, 28)),
        isTrue,
      );
    });

    test('全部外すと unchanged に移る。追加を外すと消える', () {
      final p = withoutUnselected(plan(), {
        'receptions/r1/resultAt',
        'receptions/r1/paymentDeadline',
        'performances/+1',
      });
      expect(p.changedReceptions, isEmpty);
      expect(p.unchangedReceptions.single.id, 'r1');
      expect(p.addedPerformances, isEmpty);
    });

    test('出演者の追加を外すと、mergedLive の出演者は既存のまま', () {
      final p = withoutUnselected(plan(), {'live/groupIds'});
      expect(p.liveChanges, isEmpty);
      expect(p.mergedLive.groupIds, ['g1']);
    });

    test('すべて外すと isEmpty', () {
      final p = plan();
      expect(withoutUnselected(p, p.selectableKeys).isEmpty, isTrue);
    });
  });

  group('buildLiveChanges・recentChanges', () {
    const live = HistoryTarget(HistoryCollection.lives, 'L1');
    const p1 = HistoryTarget(_p, 'p1');
    const p2 = HistoryTarget(_p, 'p2');
    const r1 = HistoryTarget(_r, 'r1');
    final created = DateTime.utc(2026, 11, 1);

    HistoryEntry h(String id, HistoryTarget t, DateTime? at) => HistoryEntry(
      id: id,
      target: t,
      field: 'venue',
      before: 'A',
      after: 'B',
      hasBefore: true,
      hasAfter: true,
      changedBy: 'u',
      changedAt: at,
    );

    test('DocAdded は createdAt がライブより後の公演・受付だけ', () {
      final changes = buildLiveChanges(
        stamps: [
          DocStamp(target: live, createdAt: created),
          DocStamp(target: p1, createdAt: created), // 同じバッチ
          DocStamp(target: p2, createdAt: created.add(const Duration(days: 2))),
          const DocStamp(target: r1), // createdAt 欠け
        ],
        history: const [],
      );
      expect(changes.single, isA<DocAdded>());
      expect(changes.single.target, p2);
    });

    test('ライブ本体の stamp が無ければ DocAdded は作らない', () {
      final changes = buildLiveChanges(
        stamps: [
          DocStamp(target: p2, createdAt: created.add(const Duration(days: 2))),
        ],
        history: const [],
      );
      expect(changes, isEmpty);
    });

    test('新しい順。日時が未確定のものは先頭', () {
      final changes = buildLiveChanges(
        stamps: const [],
        history: [
          h('a', p1, DateTime.utc(2026, 11, 2)),
          h('b', p1, null),
          h('c', r1, DateTime.utc(2026, 11, 5)),
        ],
      );
      expect(changes.map((c) => (c as FieldEdited).entry.id), ['b', 'c', 'a']);
    });

    test('recentChanges: ちょうど7日前は含み、7日と1秒前は含まない。null は含む', () {
      final now = DateTime.utc(2026, 11, 10, 12);
      final changes = [
        FieldEdited(h('exact', p1, now.subtract(const Duration(days: 7)))),
        FieldEdited(
          h('old', p1, now.subtract(const Duration(days: 7, seconds: 1))),
        ),
        FieldEdited(h('pending', p1, null)),
      ];
      expect(
        recentChanges(changes, now).map((c) => (c as FieldEdited).entry.id),
        ['pending', 'exact'],
      );
    });

    test('latestRecentChangeByTarget: ドキュメントごとに直近の1件', () {
      final now = DateTime.utc(2026, 11, 10);
      final changes = [
        FieldEdited(h('old', p1, DateTime.utc(2026, 11, 8))),
        FieldEdited(h('new', p1, DateTime.utc(2026, 11, 9))),
        FieldEdited(h('r', r1, DateTime.utc(2026, 11, 1))), // 7日より前
      ];
      final m = latestRecentChangeByTarget(changes, now);
      expect(m.keys, [p1]);
      expect((m[p1]! as FieldEdited).entry.id, 'new');
    });
  });

  group('表示と canRevert', () {
    test('historyFieldLabel: 日本語。知らない項目はそのまま', () {
      expect(historyFieldLabel(_r, 'applyEndAt'), '申込期限');
      expect(historyFieldLabel(_r, 'paymentDeadline'), '入金期限');
      expect(historyFieldLabel(_p, 'venue'), '会場名');
      expect(historyFieldLabel(HistoryCollection.lives, 'title'), 'ライブ名');
      expect(historyFieldLabel(_p, 'unknown'), 'unknown');
    });

    test('formatHistoryValue: 料金・種別・真偽値・出演者・空', () {
      expect(
        formatHistoryValue('prices', [
          {'seat': 'S席', 'amount': 9800},
          {'seat': 'A席', 'amount': 12000},
        ]),
        'S席 9,800円、A席 12,000円',
      );
      expect(formatHistoryValue('type', 'upgrade'), 'アプグレ');
      expect(formatHistoryValue('winnersOnly', true), 'はい');
      expect(formatHistoryValue('winnersOnly', false), 'いいえ');
      expect(
        formatHistoryValue('groupIds', [
          'g1',
          'g2',
        ], nameOf: (id) => id == 'g1' ? 'A' : 'B'),
        'A、B',
      );
      expect(formatHistoryValue('groupIds', ['g9']), 'g9');
      for (final v in [null, '', <Object>[]]) {
        expect(formatHistoryValue('venue', v), '（なし）');
      }
      expect(formatHistoryValue('venue', 'X', present: false), '（なし）');
      expect(
        formatHistoryValue(
          'applyEndAt',
          Timestamp.fromDate(jst(2026, 11, 20, 23, 59)),
        ),
        matches(RegExp(r'^\d{4}/\d{1,2}/\d{1,2}\(.\) \d{2}:\d{2}$')),
      );
    });

    HistoryEntry e(
      HistoryCollection c,
      String field, {
      bool hasBefore = true,
    }) => HistoryEntry(
      id: 'h',
      target: HistoryTarget(c, 'x'),
      field: field,
      hasBefore: hasBefore,
      hasAfter: true,
      changedBy: 'u',
    );

    test('canRevert: 出演者・知らない項目・前が無かった必須項目は false', () {
      expect(canRevert(e(HistoryCollection.lives, 'groupIds')), isFalse);
      expect(canRevert(e(HistoryCollection.lives, 'oshiIds')), isFalse);
      expect(canRevert(e(_p, 'memo')), isFalse);
      expect(canRevert(e(_p, 'venue', hasBefore: false)), isFalse);
      expect(canRevert(e(_r, 'applyEndAt', hasBefore: false)), isFalse);
      // 戻せるもの
      expect(canRevert(e(HistoryCollection.lives, 'title')), isTrue);
      expect(canRevert(e(_r, 'paymentDeadline', hasBefore: false)), isTrue);
      expect(canRevert(e(_p, 'startAt')), isTrue);
    });
  });
}
