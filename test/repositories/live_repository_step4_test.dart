// FirestoreLiveRepository の Step4（照合・更新・変更履歴）のテスト。
// fake_cloud_firestore で Firestore 版の実装を動かす。
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/history_entry.dart';
import 'package:oshiashi/models/reception.dart';
import 'package:oshiashi/repositories/live_repository.dart';
import 'package:oshiashi/utils/live_diff.dart';

import '../utils/live_merge_fixtures.dart';

final _created = Timestamp.fromDate(DateTime.utc(2026, 1, 1));

Map<String, dynamic> _audit([Timestamp? at]) => {
  'createdBy': 'bob',
  'createdAt': _created,
  'updatedBy': 'bob',
  'updatedAt': at ?? _created,
};

late FakeFirebaseFirestore db;
late FirestoreLiveRepository repo;

/// ライブ L1（g1）と、公演 p1・p2、受付 r1 を直接置く
Future<void> seed({
  List<String> groupIds = const ['g1'],
  List<String> oshiIds = const [],
}) async {
  await db.doc('lives/L1').set({
    'title': 'ツアー2026',
    'groupIds': groupIds,
    'oshiIds': oshiIds,
    'officialUrl': 'https://e.com/t',
    ..._audit(),
  });
  final child = {'liveId': 'L1', 'groupIds': groupIds, 'oshiIds': oshiIds};
  await db.doc('performances/p1').set({
    ...child,
    'startAt': Timestamp.fromDate(jst(2026, 12, 20, 18)),
    'venue': '東京ドーム',
    'prefecture': '東京都',
    ..._audit(),
  });
  await db.doc('performances/p2').set({
    ...child,
    'startAt': Timestamp.fromDate(jst(2026, 12, 21, 18)),
    'venue': '東京ドーム',
    ..._audit(),
  });
  await db.doc('receptions/r1').set({
    ...child,
    'type': 'fc',
    'name': 'FC1次先行',
    'applyEndAt': Timestamp.fromDate(jst(2026, 11, 20, 23, 59)),
    'paymentDeadline': Timestamp.fromDate(jst(2026, 11, 28, 23, 59)),
    'prices': [
      {'seat': 'S席', 'amount': 9800},
    ],
    'winnersOnly': false,
    ..._audit(),
  });
}

Future<List<Map<String, dynamic>>> history(String path) async {
  final snap = await db.doc(path).collection('history').get();
  return [for (final d in snap.docs) d.data()];
}

Future<Map<String, dynamic>> data(String path) async =>
    (await db.doc(path).get()).data()!;

Future<int> count(String collection) async =>
    (await db.collection(collection).get()).docs.length;

void main() {
  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreLiveRepository(db);
  });

  group('fetchExisting', () {
    test('ライブ一式と、各ドキュメントの updatedAt（versions）を読む', () async {
      await seed();
      final e = (await repo.fetchExisting('L1'))!;
      expect(e.live.id, 'L1');
      expect(e.performances.map((p) => p.id), ['p1', 'p2']); // 開演順
      expect(e.receptions.single.id, 'r1');
      expect(e.versions.keys, {
        'lives/L1',
        'performances/p1',
        'performances/p2',
        'receptions/r1',
      });
      expect(e.versions['lives/L1'], _created);
      expect(e.firstPerformance!.id, 'p1');
    });

    test('無いライブは null。読めない公演は飛ばす', () async {
      expect(await repo.fetchExisting('none'), isNull);
      await seed();
      await db.doc('performances/broken').set({'liveId': 'L1', 'venue': 1});
      final e = (await repo.fetchExisting('L1'))!;
      expect(e.performances.map((p) => p.id), ['p1', 'p2']);
    });

    test('読めないライブ本体は null', () async {
      await db.doc('lives/bad').set({'groupIds': 'g1'});
      expect(await repo.fetchExisting('bad'), isNull);
    });
  });

  group('fetchCandidates', () {
    test('出演者が1つでも重なるライブ一式。重複は1件。両方空なら空', () async {
      await seed(groupIds: ['g1'], oshiIds: ['o1']);
      await db.doc('lives/L2').set({
        'title': '別',
        'groupIds': ['g9'],
        'oshiIds': <String>[],
        ..._audit(),
      });
      final c = await repo.fetchCandidates(groupIds: ['g1'], oshiIds: ['o1']);
      expect(c.map((e) => e.live.id), ['L1']);
      expect(c.single.performances, hasLength(2));
      expect(c.single.receptions, hasLength(1));
      expect(await repo.fetchCandidates(groupIds: [], oshiIds: []), isEmpty);
    });

    test('31件を超える出演者でも分割して探す（31件目の出演者のライブも見つかる）', () async {
      final ids = [
        for (var i = 0; i < 31; i++) 'g${i.toString().padLeft(2, '0')}',
      ];
      await db.doc('lives/Last').set({
        'title': '最後',
        'groupIds': [ids.last],
        'oshiIds': <String>[],
        ..._audit(),
      });
      await db.doc('lives/First').set({
        'title': '最初',
        'groupIds': [ids.first],
        'oshiIds': <String>[],
        ..._audit(),
      });
      final c = await repo.fetchCandidates(groupIds: ids, oshiIds: const []);
      expect(c.map((e) => e.live.id).toSet(), {'Last', 'First'});
    });

    test('31件を超えるライブの公演・受付も読む（whereIn の分割）', () async {
      for (var i = 0; i < 31; i++) {
        await db.doc('lives/L$i').set({
          'title': 'T$i',
          'groupIds': ['g1'],
          'oshiIds': <String>[],
          ..._audit(),
        });
        await db.doc('performances/P$i').set({
          'liveId': 'L$i',
          'groupIds': ['g1'],
          'oshiIds': <String>[],
          'startAt': Timestamp.fromDate(jst(2026, 12, 1)),
          'venue': 'V',
          ..._audit(),
        });
      }
      final c = await repo.fetchCandidates(groupIds: ['g1'], oshiIds: const []);
      expect(c, hasLength(31));
      expect(c.every((e) => e.performances.length == 1), isTrue);
    });
  });

  group('applyMerge', () {
    test('変わった項目ごとに履歴1件、ID は変わらない、空の値で上書きしない', () async {
      await seed();
      final base = (await repo.fetchExisting('L1'))!;
      final plan = diffLive(
        base,
        input(
          title: 'ツアー2026 改',
          performances: [inputPerf(startAt: jst(2026, 12, 20, 17))], // p1 の時刻
          receptions: [
            inputRec(
              applyEndAt: jst(2026, 11, 18, 23, 59),
              resultAt: jst(2026, 11, 25, 15),
            ),
          ],
        ),
      );
      final saved = await repo.applyMerge(plan, uid: 'alice');

      expect(await count('lives'), 1);
      expect(await count('performances'), 2);
      expect(await count('receptions'), 1);
      expect(saved.live.id, 'L1');
      expect(saved.performances.single.id, 'p1');
      expect(saved.receptions.single.id, 'r1');

      final live = await data('lives/L1');
      expect(live['title'], 'ツアー2026 改');
      expect(live['officialUrl'], 'https://e.com/t'); // 空の値で消さない
      expect(live['updatedBy'], 'alice');
      expect(live['createdBy'], 'bob');
      expect(live['createdAt'], _created);

      final lh = await history('lives/L1');
      expect(lh, hasLength(1));
      expect(lh.single['field'], 'title');
      expect(lh.single['before'], 'ツアー2026');
      expect(lh.single['after'], 'ツアー2026 改');
      expect(lh.single['changedBy'], 'alice');
      expect(lh.single['changedAt'], isA<Timestamp>());

      final p1 = await data('performances/p1');
      expect(p1['startAt'], Timestamp.fromDate(jst(2026, 12, 20, 17)));
      expect(p1['prefecture'], '東京都');
      expect((await history('performances/p1')).single['field'], 'startAt');
      expect(await history('performances/p2'), isEmpty);
      // p2 は変わらないので updatedAt も書かない（出演者の変更が無い）
      expect((await data('performances/p2'))['updatedAt'], _created);

      final rh = await history('receptions/r1');
      expect(
        rh.map((h) => h['field']),
        unorderedEquals(['applyEndAt', 'resultAt']),
      );
      final result = rh.firstWhere((h) => h['field'] == 'resultAt');
      expect(result.containsKey('before'), isFalse); // 前は無かった
      final r1 = await data('receptions/r1');
      expect(
        r1['paymentDeadline'],
        Timestamp.fromDate(jst(2026, 11, 28, 23, 59)),
      );
      expect(r1['prices'], [
        {'seat': 'S席', 'amount': 9800},
      ]);
    });

    test('追加だけ: 既存の公演は残り、追加分に liveId・出演者・作成者が付き、履歴は作らない', () async {
      await seed();
      final base = (await repo.fetchExisting('L1'))!;
      final plan = diffLive(
        base,
        input(
          performances: [
            inputPerf(startAt: jst(2026, 12, 27, 18), venue: '大阪城ホール'),
          ],
          receptions: [
            inputRec(
              type: ReceptionType.general,
              name: '一般',
              applyEndAt: jst(2026, 12, 5),
            ),
          ],
        ),
      );
      final saved = await repo.applyMerge(plan, uid: 'alice');
      expect(await count('performances'), 3);
      expect(await count('receptions'), 2);
      final newP = saved.performances.single;
      expect(newP.id, isNot(anyOf('p1', 'p2')));
      final d = await data('performances/${newP.id}');
      expect(d['liveId'], 'L1');
      expect(d['groupIds'], ['g1']);
      expect(d['createdBy'], 'alice');
      expect(d['venue'], '大阪城ホール');
      expect(await history('performances/${newP.id}'), isEmpty);
      expect(saved.receptions.single.liveId, 'L1');
      // ライブ本体は項目が変わらなくても updatedBy・updatedAt を書く（履歴なし）
      final live = await data('lives/L1');
      expect(live['updatedBy'], 'alice');
      expect(live['updatedAt'], isNot(_created));
      expect(await history('lives/L1'), isEmpty);
    });

    test('出演者が増えたら、すべての公演・受付の groupIds・oshiIds をそろえる（履歴はライブだけ）', () async {
      await seed();
      final base = (await repo.fetchExisting('L1'))!;
      final plan = diffLive(
        base,
        input(
          groupIds: ['g2'],
          oshiIds: ['o1'],
          performances: [inputPerf(startAt: jst(2026, 12, 28, 18))], // 追加
        ),
      );
      final saved = await repo.applyMerge(plan, uid: 'alice');
      final live = await data('lives/L1');
      expect(live['groupIds'], ['g1', 'g2']);
      expect(live['oshiIds'], ['o1']);
      for (final path in [
        'performances/p1',
        'performances/p2',
        'receptions/r1',
        'performances/${saved.performances.single.id}',
      ]) {
        final d = await data(path);
        expect(d['groupIds'], ['g1', 'g2'], reason: path);
        expect(d['oshiIds'], ['o1'], reason: path);
      }
      expect(
        (await history('lives/L1')).map((h) => h['field']),
        unorderedEquals(['groupIds', 'oshiIds']),
      );
      expect(await history('performances/p1'), isEmpty);
      expect(await history('receptions/r1'), isEmpty);
      expect(saved.live.groupIds, ['g1', 'g2']);
    });

    test('回帰: 出演者が古いままの公演を変えると、出演者もライブにそろう（レビュー記録 D4 中）', () async {
      await seed(groupIds: ['g1', 'g2']);
      // 差分を作った後に他人が足した公演のように、出演者がライブより古い
      await db.doc('performances/p1').update({
        'groupIds': ['g1'],
      });
      final base = (await repo.fetchExisting('L1'))!;
      final plan = diffLive(
        base,
        input(
          groupIds: ['g1', 'g2'],
          performances: [inputPerf(startAt: jst(2026, 12, 20, 17))],
        ),
      );
      expect(plan.liveChanges, isEmpty); // 出演者の変更は無い
      await repo.applyMerge(plan, uid: 'alice');
      expect((await data('performances/p1'))['groupIds'], ['g1', 'g2']);
    });

    test('選択から外した出演者の追加は反映しない（子もそのまま）', () async {
      await seed();
      final base = (await repo.fetchExisting('L1'))!;
      final plan = withoutUnselected(
        diffLive(base, input(title: '新しい名前', groupIds: ['g2'])),
        {'live/groupIds'},
      );
      await repo.applyMerge(plan, uid: 'alice');
      expect((await data('lives/L1'))['groupIds'], ['g1']);
      expect((await data('performances/p1'))['groupIds'], ['g1']);
      expect((await data('lives/L1'))['title'], '新しい名前');
    });

    test('isEmpty の計画は ArgumentError で、何も書かない', () async {
      await seed();
      final base = (await repo.fetchExisting('L1'))!;
      final plan = diffLive(base, input());
      expect(plan.isEmpty, isTrue);
      await expectLater(
        repo.applyMerge(plan, uid: 'alice'),
        throwsArgumentError,
      );
      expect((await data('lives/L1'))['updatedAt'], _created);
    });

    test('同時更新: ライブ本体だけが先に更新されていたら、何も書かずに LiveConflictException', () async {
      await seed();
      final base = (await repo.fetchExisting('L1'))!;
      final plan = diffLive(
        base,
        input(receptions: [inputRec(applyEndAt: jst(2026, 11, 18))]),
      );
      final later = Timestamp.fromDate(DateTime.utc(2026, 2, 1));
      await db.doc('lives/L1').update({
        'updatedAt': later,
        'updatedBy': 'carol',
      });

      await expectLater(
        repo.applyMerge(plan, uid: 'alice'),
        throwsA(
          isA<LiveConflictException>().having((e) => e.paths, 'paths', [
            'lives/L1',
          ]),
        ),
      );
      expect(
        (await data('receptions/r1'))['applyEndAt'],
        Timestamp.fromDate(jst(2026, 11, 20, 23, 59)),
      );
      expect(await history('receptions/r1'), isEmpty);
      expect((await data('lives/L1'))['updatedBy'], 'carol');
    });

    test('同時更新: 変更する受付だけが先に更新されていたら止まる。関係ない公演の更新では止まらない', () async {
      await seed();
      final base = (await repo.fetchExisting('L1'))!;
      final plan = diffLive(
        base,
        input(receptions: [inputRec(applyEndAt: jst(2026, 11, 18))]),
      );
      final later = Timestamp.fromDate(DateTime.utc(2026, 2, 1));
      await db.doc('receptions/r1').update({'updatedAt': later});
      await expectLater(
        repo.applyMerge(plan, uid: 'alice'),
        throwsA(
          isA<LiveConflictException>().having((e) => e.paths, 'paths', [
            'receptions/r1',
          ]),
        ),
      );
      expect(await history('receptions/r1'), isEmpty);
      expect(await count('performances'), 2);

      // 変更しない公演（p2）の更新だけなら反映できる
      await seed();
      final base2 = (await repo.fetchExisting('L1'))!;
      final plan2 = diffLive(
        base2,
        input(receptions: [inputRec(applyEndAt: jst(2026, 11, 18))]),
      );
      await db.doc('performances/p2').update({'updatedAt': later});
      await repo.applyMerge(plan2, uid: 'alice');
      expect((await history('receptions/r1')), hasLength(1));
    });

    test('同時更新: 変更する公演が消えていても止まる', () async {
      await seed();
      final base = (await repo.fetchExisting('L1'))!;
      final plan = diffLive(
        base,
        input(performances: [inputPerf(startAt: jst(2026, 12, 20, 17))]),
      );
      await db.doc('performances/p1').delete();
      await expectLater(
        repo.applyMerge(plan, uid: 'alice'),
        throwsA(isA<LiveConflictException>()),
      );
      expect(await count('performances'), 1);
    });

    test('同じ計画を2回反映すると、2回目は競合になる（二重送信で重複しない）', () async {
      await seed();
      final base = (await repo.fetchExisting('L1'))!;
      final plan = diffLive(
        base,
        input(performances: [inputPerf(startAt: jst(2026, 12, 27, 18))]),
      );
      await repo.applyMerge(plan, uid: 'alice');
      await expectLater(
        repo.applyMerge(plan, uid: 'alice'),
        throwsA(isA<LiveConflictException>()),
      );
      expect(await count('performances'), 3);
    });

    test('編集で空にした任意項目は消え、履歴に after が無い', () async {
      await seed();
      final base = (await repo.fetchExisting('L1'))!;
      final plan = diffLive(
        base,
        input(receptions: [inputRec()]),
        receptionIds: ['r1'],
        editing: true,
      );
      await repo.applyMerge(plan, uid: 'alice');
      final r1 = await data('receptions/r1');
      expect(r1.containsKey('paymentDeadline'), isFalse);
      expect(r1['prices'], isEmpty);
      final h = (await history('receptions/r1'))
          .firstWhere((h) => h['field'] == 'paymentDeadline');
      expect(h.containsKey('after'), isFalse);
      expect(h['before'], Timestamp.fromDate(jst(2026, 11, 28, 23, 59)));
      // 公式 URL も消える
      expect((await data('lives/L1')).containsKey('officialUrl'), isFalse);
    });
  });

  group('watchHistory・revert', () {
    Future<List<HistoryEntry>> entries(HistoryTarget t) =>
        repo.watchHistory(t).first;
    const r1 = HistoryTarget(HistoryCollection.receptions, 'r1');

    Future<void> changeDeadline() async {
      final base = (await repo.fetchExisting('L1'))!;
      await repo.applyMerge(
        diffLive(
          base,
          input(receptions: [inputRec(applyEndAt: jst(2026, 11, 18, 23, 59))]),
        ),
        uid: 'alice',
      );
    }

    test('watchHistory は新しい順で、Firestore の形のまま', () async {
      await seed();
      await db.doc('receptions/r1/history/old').set({
        'field': 'name',
        'before': 'a',
        'after': 'b',
        'changedBy': 'bob',
        'changedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
      });
      await db.doc('receptions/r1/history/new').set({
        'field': 'name',
        'before': 'b',
        'after': 'c',
        'changedBy': 'bob',
        'changedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 3)),
      });
      await db.doc('receptions/r1/history/broken').set({'x': 1});
      final list = await entries(r1);
      expect(list.map((e) => e.id), ['broken', 'new', 'old']); // 日時の無いものは先頭
      expect(list[1].hasBefore && list[1].hasAfter, isTrue);
      expect(list.first.field, '');
    });

    test('元に戻す: 値が戻り、戻した操作も履歴に残る', () async {
      await seed();
      await changeDeadline();
      final entry = (await entries(r1)).single;
      await repo.revert(entry, uid: 'carol');
      final r = await data('receptions/r1');
      expect(r['applyEndAt'], Timestamp.fromDate(jst(2026, 11, 20, 23, 59)));
      expect(r['updatedBy'], 'carol');
      final list = await entries(r1);
      expect(list, hasLength(2));
      final undo = list.firstWhere((e) => e.id != entry.id);
      expect(undo.changedBy, 'carol');
      expect(undo.before, entry.after);
      expect(undo.after, entry.before);
    });

    test('その後に別の変更があれば止まる（もう一度戻すのも止まる）', () async {
      await seed();
      await changeDeadline();
      final entry = (await entries(r1)).single;
      await repo.revert(entry, uid: 'carol');
      await expectLater(
        repo.revert(entry, uid: 'carol'),
        throwsA(isA<LiveConflictException>()),
      );
      expect(await entries(r1), hasLength(2));
    });

    test('before が無かった項目を戻すと、項目が消える', () async {
      await seed();
      final base = (await repo.fetchExisting('L1'))!;
      await repo.applyMerge(
        diffLive(
          base,
          input(receptions: [inputRec(resultAt: jst(2026, 11, 25))]),
        ),
        uid: 'alice',
      );
      final entry = (await entries(r1)).single;
      expect(entry.hasBefore, isFalse);
      await repo.revert(entry, uid: 'alice');
      expect((await data('receptions/r1')).containsKey('resultAt'), isFalse);
      final undo = (await entries(r1)).firstWhere((e) => e.id != entry.id);
      expect(undo.hasAfter, isFalse);
      expect(undo.hasBefore, isTrue);
    });

    test('after が無い（消した）変更を戻すと、値が戻る', () async {
      await seed();
      final base = (await repo.fetchExisting('L1'))!;
      await repo.applyMerge(
        diffLive(
          base,
          input(receptions: [inputRec()]),
          receptionIds: ['r1'],
          editing: true,
        ),
        uid: 'alice',
      );
      final entry = (await entries(r1))
          .firstWhere((e) => e.field == 'paymentDeadline');
      await repo.revert(entry, uid: 'alice');
      expect(
        (await data('receptions/r1'))['paymentDeadline'],
        Timestamp.fromDate(jst(2026, 11, 28, 23, 59)),
      );
    });

    test('出演者の履歴（canRevert=false）は ArgumentError。ドキュメントが無ければ競合', () async {
      await seed();
      final base = (await repo.fetchExisting('L1'))!;
      await repo.applyMerge(
        diffLive(base, input(groupIds: ['g2'])),
        uid: 'alice',
      );
      const live = HistoryTarget(HistoryCollection.lives, 'L1');
      final entry = (await entries(live)).single;
      expect(entry.field, 'groupIds');
      await expectLater(repo.revert(entry, uid: 'alice'), throwsArgumentError);
      expect((await data('lives/L1'))['groupIds'], ['g1', 'g2']);

      const gone = HistoryTarget(HistoryCollection.performances, 'nothing');
      await expectLater(
        repo.revert(
          const HistoryEntry(
            id: 'h',
            target: gone,
            field: 'venue',
            before: 'A',
            after: 'B',
            hasBefore: true,
            hasAfter: true,
            changedBy: 'u',
          ),
          uid: 'alice',
        ),
        throwsA(isA<LiveConflictException>()),
      );
    });
  });

  group('watchDocStamps', () {
    test('ライブ本体と公演・受付の作成・更新日時を流し、後から足したものは DocAdded になる', () async {
      await seed();
      await db.doc('performances/late').set({
        'liveId': 'L1',
        'groupIds': ['g1'],
        'oshiIds': <String>[],
        'startAt': Timestamp.fromDate(jst(2026, 12, 30)),
        'venue': 'V',
        ..._audit(),
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 5)),
      });
      final stamps = await repo.watchDocStamps('L1').first;
      expect(stamps.map((s) => s.target.path).toSet(), {
        'lives/L1',
        'performances/p1',
        'performances/p2',
        'performances/late',
        'receptions/r1',
      });
      final changes = buildLiveChanges(stamps: stamps, history: const []);
      expect(changes.single.target.path, 'performances/late');
    });
  });
}
