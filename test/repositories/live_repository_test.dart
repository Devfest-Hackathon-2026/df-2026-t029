import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/performance.dart';
import 'package:oshiashi/models/reception.dart';
import 'package:oshiashi/repositories/live_repository.dart';

final start = DateTime(2026, 12, 1, 18);

Performance perf({
  DateTime? startAt,
  String venue = '東京ドーム',
  String? prefecture,
  DateTime? openAt,
}) => Performance(
  startAt: startAt ?? start,
  venue: venue,
  prefecture: prefecture,
  openAt: openAt,
);

Reception rec({String name = 'FC先行', DateTime? applyEndAt}) => Reception(
  type: ReceptionType.fc,
  name: name,
  applyEndAt: applyEndAt ?? DateTime(2026, 11, 20),
  prices: const [Price(seat: 'S席', amount: 9800)],
);

/// 一覧の購読用に、直接書き込むドキュメント
Map<String, dynamic> liveDoc(
  String title, {
  List<String> groupIds = const [],
  List<String> oshiIds = const [],
}) => {'title': title, 'groupIds': groupIds, 'oshiIds': oshiIds};

Map<String, dynamic> perfDoc(
  String liveId,
  DateTime startAt, {
  List<String> groupIds = const [],
  List<String> oshiIds = const [],
}) => {
  'liveId': liveId,
  'groupIds': groupIds,
  'oshiIds': oshiIds,
  'startAt': Timestamp.fromDate(startAt),
  'venue': '会場',
};

Map<String, dynamic> recDoc(
  String liveId,
  DateTime applyEndAt, {
  List<String> groupIds = const [],
  List<String> oshiIds = const [],
}) => {
  'liveId': liveId,
  'groupIds': groupIds,
  'oshiIds': oshiIds,
  'type': 'fc',
  'name': 'FC',
  'applyEndAt': Timestamp.fromDate(applyEndAt),
};

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreLiveRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreLiveRepository(db);
  });

  group('create', () {
    Future<String> create({
      Live live = const Live(
        title: 'ツアー',
        groupIds: ['g1', 'g2'],
        oshiIds: ['p1'],
      ),
      List<Performance>? performances,
      List<Reception>? receptions,
    }) => repo.create(
      live: live,
      performances: performances ?? [perf()],
      receptions: receptions ?? [rec()],
      uid: 'alice',
    );

    test('ライブ・公演・受付を作り、ライブの ID を返す', () async {
      final id = await create(
        performances: [
          perf(),
          perf(venue: '大阪城ホール'),
        ],
        receptions: [
          rec(),
          rec(name: '一般'),
          rec(name: 'アプグレ'),
        ],
      );
      final live = await db.collection('lives').doc(id).get();
      expect(live.exists, isTrue);
      expect(live.data()!['title'], 'ツアー');
      expect((await db.collection('performances').get()).docs, hasLength(2));
      expect((await db.collection('receptions').get()).docs, hasLength(3));
    });

    test('ライブには groupIds・oshiIds と作成者の項目が入る（それ以外のキーは無い）', () async {
      final id = await create();
      final data = (await db.collection('lives').doc(id).get()).data()!;
      expect(data.keys.toSet(), {
        'title',
        'groupIds',
        'oshiIds',
        'createdBy',
        'createdAt',
        'updatedBy',
        'updatedAt',
      });
      expect(data['groupIds'], ['g1', 'g2']);
      expect(data['oshiIds'], ['p1']);
      expect(data['createdBy'], 'alice');
      expect(data['updatedBy'], 'alice');
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['updatedAt'], isA<Timestamp>());
    });

    test('ライブの groupIds・oshiIds が空でもキーは入る（空の配列）', () async {
      final id = await create(
        live: const Live(title: 'ソロ', oshiIds: ['p1']),
      );
      final data = (await db.collection('lives').doc(id).get()).data()!;
      expect(data['groupIds'], isEmpty);
      expect(data['groupIds'], isA<List<dynamic>>());
      expect(data['oshiIds'], ['p1']);
      final perfData = (await db.collection('performances').get()).docs.single
          .data();
      expect(perfData['groupIds'], isEmpty);
      expect(perfData['oshiIds'], ['p1']);
    });

    test('officialUrl があればライブに入る', () async {
      final id = await create(
        live: const Live(
          title: 'A',
          groupIds: ['g1'],
          officialUrl: 'https://example.com',
        ),
      );
      final data = (await db.collection('lives').doc(id).get()).data()!;
      expect(data['officialUrl'], 'https://example.com');
    });

    test('公演: toFirestore の項目に liveId・groupIds・oshiIds・作成者の項目だけを足す', () async {
      final id = await create(
        performances: [
          perf(
            prefecture: '東京都',
            openAt: start.subtract(const Duration(hours: 1)),
          ),
        ],
      );
      final data = (await db.collection('performances').get()).docs.single
          .data();
      expect(data.keys.toSet(), {
        'startAt',
        'openAt',
        'venue',
        'prefecture',
        'liveId',
        'groupIds',
        'oshiIds',
        'createdBy',
        'createdAt',
        'updatedBy',
        'updatedAt',
      });
      expect(data['liveId'], id);
      expect(data['groupIds'], ['g1', 'g2']);
      expect(data['oshiIds'], ['p1']);
      expect(data['createdBy'], 'alice');
      expect(data['updatedBy'], 'alice');
      expect((data['startAt'] as Timestamp).toDate(), start);
    });

    test('受付: toFirestore の項目に liveId・groupIds・oshiIds・作成者の項目だけを足す', () async {
      final id = await create();
      final data = (await db.collection('receptions').get()).docs.single.data();
      expect(data.keys.toSet(), {
        'type',
        'name',
        'applyEndAt',
        'prices',
        'winnersOnly',
        'liveId',
        'groupIds',
        'oshiIds',
        'createdBy',
        'createdAt',
        'updatedBy',
        'updatedAt',
      });
      expect(data['liveId'], id);
      expect(data['groupIds'], ['g1', 'g2']);
      expect(data['oshiIds'], ['p1']);
      expect(data['prices'], [
        {'seat': 'S席', 'amount': 9800},
      ]);
    });

    test('引数の子の id・liveId・groupIds・oshiIds は無視する', () async {
      final id = await create(
        performances: [
          Performance(
            id: 'p-fake',
            liveId: 'other-live',
            groupIds: const ['x'],
            oshiIds: const ['y'],
            startAt: start,
            venue: '会場',
          ),
        ],
        receptions: [
          Reception(
            id: 'r-fake',
            liveId: 'other-live',
            groupIds: const ['x'],
            oshiIds: const ['y'],
            type: ReceptionType.general,
            name: '一般',
            applyEndAt: DateTime(2026, 11, 20),
          ),
        ],
      );
      for (final col in ['performances', 'receptions']) {
        final docs = (await db.collection(col).get()).docs;
        expect(docs.single.id, isNot(anyOf('p-fake', 'r-fake')), reason: col);
        expect(docs.single.data()['liveId'], id, reason: col);
        expect(docs.single.data()['groupIds'], ['g1', 'g2'], reason: col);
        expect(docs.single.data()['oshiIds'], ['p1'], reason: col);
      }
    });

    test('受付0件でも作れる', () async {
      final id = await create(receptions: []);
      expect((await db.collection('lives').doc(id).get()).exists, isTrue);
      expect((await db.collection('receptions').get()).docs, isEmpty);
    });

    test('上限の件数（公演50・受付30）を1回で作れる', () async {
      await create(
        performances: [for (var i = 0; i < 50; i++) perf()],
        receptions: [for (var i = 0; i < 30; i++) rec()],
      );
      expect((await db.collection('performances').get()).docs, hasLength(50));
      expect((await db.collection('receptions').get()).docs, hasLength(30));
    });

    test('2回呼べば別のライブになる（ID は自動）', () async {
      final a = await create();
      final b = await create();
      expect(a, isNot(b));
      expect((await db.collection('lives').get()).docs, hasLength(2));
    });

    test(
      '作ったものは watchLive・watchPerformancesOf・watchReceptionsOf で読める',
      () async {
        final id = await create(
          performances: [perf(venue: 'A')],
          receptions: [rec(name: 'X')],
        );
        final live = await repo.watchLive(id).first;
        expect(live!.id, id);
        expect(live.groupIds, ['g1', 'g2']);
        final ps = await repo.watchPerformancesOf(id).first;
        expect(ps.single.liveId, id);
        expect(ps.single.venue, 'A');
        final rs = await repo.watchReceptionsOf(id).first;
        expect(rs.single.name, 'X');
        expect(rs.single.oshiIds, ['p1']);
      },
    );
  });

  group('chunks', () {
    test('空なら空', () {
      expect(chunks(const {}, 30), isEmpty);
    });

    test('ID の順に並べ替えてから size 件ずつに分ける（65件 → 30・30・5）', () {
      final ids = {
        for (var i = 64; i >= 0; i--) 'id${i.toString().padLeft(2, '0')}',
      };
      final cs = chunks(ids, 30);
      expect([for (final c in cs) c.length], [30, 30, 5]);
      expect(cs.first.first, 'id00');
      expect(cs.last.last, 'id64');
      expect(cs.expand((c) => c).toSet(), ids);
    });

    test('ちょうど30件なら1つ、31件なら2つ', () {
      Set<String> n(int count) => {for (var i = 0; i < count; i++) 'x$i'};
      expect(chunks(n(30), 30), hasLength(1));
      expect([for (final c in chunks(n(31), 30)) c.length], [30, 1]);
    });

    test('分割の大きさは queryChunkSize（array-contains-any の上限）', () {
      expect(FirestoreLiveRepository.queryChunkSize, 30);
    });
  });

  group('watchLives / watchPerformances / watchReceptions', () {
    test('対象が空なら問い合わせず、空のリストを1回流して終わる', () async {
      await db.collection('lives').add(liveDoc('A', groupIds: ['g1']));
      for (final s in [
        repo.watchLives(FollowTargets.empty),
        repo.watchPerformances(FollowTargets.empty),
        repo.watchReceptions(FollowTargets.empty),
      ]) {
        expect(await s.toList(), [isEmpty]);
      }
    });

    test('groupIds と oshiIds のどちらかに当たるライブを返す', () async {
      await db
          .collection('lives')
          .doc('byGroup')
          .set(liveDoc('G', groupIds: ['g1']));
      await db
          .collection('lives')
          .doc('byOshi')
          .set(liveDoc('O', oshiIds: ['p1']));
      await db
          .collection('lives')
          .doc('other')
          .set(liveDoc('X', groupIds: ['g9']));
      final lives = await repo
          .watchLives(const FollowTargets(groupIds: {'g1'}, oshiIds: {'p1'}))
          .first;
      expect({for (final l in lives) l.id}, {'byGroup', 'byOshi'});
    });

    test('グループと個人の両方に当たるライブは1件にまとめる', () async {
      await db
          .collection('lives')
          .doc('both')
          .set(liveDoc('B', groupIds: ['g1', 'g2'], oshiIds: ['p1']));
      final lives = await repo
          .watchLives(
            const FollowTargets(groupIds: {'g1', 'g2'}, oshiIds: {'p1'}),
          )
          .first;
      expect([for (final l in lives) l.id], ['both']);
    });

    test('groupIds と oshiIds を取り違えない（個人 ID はグループの検索に当たらない）', () async {
      await db.collection('lives').doc('l').set(liveDoc('A', oshiIds: ['x']));
      final lives = await repo
          .watchLives(const FollowTargets(groupIds: {'x'}))
          .first;
      expect(lives, isEmpty);
    });

    test('30件を超える対象は分割して問い合わせ、すべての分割の結果をまとめる', () async {
      // 65件のグループ（30・30・5に分かれる）。各分割から1件ずつ当たる
      final groupIds = {
        for (var i = 0; i < 65; i++) 'g${i.toString().padLeft(2, '0')}',
      };
      await db
          .collection('lives')
          .doc('first')
          .set(liveDoc('1', groupIds: ['g00']));
      await db
          .collection('lives')
          .doc('middle')
          .set(liveDoc('2', groupIds: ['g45']));
      await db
          .collection('lives')
          .doc('last')
          .set(liveDoc('3', groupIds: ['g64']));
      // 2つの分割にまたがるライブも1件
      await db
          .collection('lives')
          .doc('across')
          .set(liveDoc('4', groupIds: ['g01', 'g50', 'g62']));
      // 31件の推し（30・1）
      final oshiIds = {for (var i = 0; i < 31; i++) 'p$i'};
      await db
          .collection('lives')
          .doc('solo')
          .set(liveDoc('5', oshiIds: ['p30']));

      final lives = await repo
          .watchLives(FollowTargets(groupIds: groupIds, oshiIds: oshiIds))
          .first;
      expect([for (final l in lives) l.id]..sort(), [
        'across',
        'first',
        'last',
        'middle',
        'solo',
      ]);
    });

    test('最初の値は、すべての分割の結果がそろってから流す（途中の結果を流さない）', () async {
      final groupIds = {for (var i = 0; i < 61; i++) 'g$i'};
      for (final g in groupIds) {
        await db
            .collection('lives')
            .doc('live-$g')
            .set(liveDoc(g, groupIds: [g]));
      }
      final first = await repo
          .watchLives(FollowTargets(groupIds: groupIds))
          .first;
      expect(first, hasLength(61));
    });

    test('後から追加・削除されたドキュメントも流れる', () async {
      const targets = FollowTargets(groupIds: {'g1'});
      final values = <List<String?>>[];
      final sub = repo
          .watchLives(targets)
          .listen((ls) => values.add([for (final l in ls) l.id]..sort()));
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(values.last, isEmpty);

      await db.collection('lives').doc('a').set(liveDoc('A', groupIds: ['g1']));
      await pumpEventQueue();
      expect(values.last, ['a']);

      await db.collection('lives').doc('b').set(liveDoc('B', groupIds: ['g1']));
      await pumpEventQueue();
      expect(values.last, ['a', 'b']);

      await db.collection('lives').doc('a').delete();
      await pumpEventQueue();
      expect(values.last, ['b']);
    });

    test('対象から外れる更新をすれば消える', () async {
      await db.collection('lives').doc('a').set(liveDoc('A', groupIds: ['g1']));
      final values = <int>[];
      final sub = repo
          .watchLives(const FollowTargets(groupIds: {'g1'}))
          .listen((ls) => values.add(ls.length));
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(values.last, 1);
      await db.collection('lives').doc('a').update({
        'groupIds': ['g2'],
      });
      await pumpEventQueue();
      expect(values.last, 0);
    });

    test('読めないドキュメントは飛ばし、ほかは返す（計画書 3.7）', () async {
      final col = db.collection('lives');
      await col.doc('ok').set(liveDoc('OK', groupIds: ['g1']));
      await col.doc('noTitle').set({
        'groupIds': ['g1'],
      });
      await col.doc('badTitle').set({
        'title': 123,
        'groupIds': ['g1'],
      });
      await col.doc('badOshiIds').set({
        'title': 'X',
        'groupIds': ['g1'],
        'oshiIds': 'p1',
      });
      await col.doc('badElement').set({
        'title': 'X',
        'groupIds': ['g1', 2],
      });
      final lives = await repo
          .watchLives(const FollowTargets(groupIds: {'g1'}))
          .first;
      expect([for (final l in lives) l.id], ['ok']);
    });

    test('公演: 読めないもの（startAt・venue が無い・型違い）は飛ばす', () async {
      final col = db.collection('performances');
      await col.doc('ok').set(perfDoc('l1', start, groupIds: ['g1']));
      await col.doc('noStart').set({
        'liveId': 'l1',
        'groupIds': ['g1'],
        'venue': '会場',
      });
      await col.doc('badStart').set({
        'liveId': 'l1',
        'groupIds': ['g1'],
        'venue': '会場',
        'startAt': '2026-12-01',
      });
      await col.doc('noVenue').set({
        'liveId': 'l1',
        'groupIds': ['g1'],
        'startAt': Timestamp.fromDate(start),
      });
      final ps = await repo
          .watchPerformances(const FollowTargets(groupIds: {'g1'}))
          .first;
      expect([for (final p in ps) p.id], ['ok']);
    });

    test('受付: 読めないもの（name・applyEndAt が無い、prices が壊れている）は飛ばす', () async {
      final col = db.collection('receptions');
      final end = DateTime(2026, 11, 20);
      await col.doc('ok').set(recDoc('l1', end, oshiIds: ['p1']));
      await col
          .doc('noName')
          .set(
            {
              ...recDoc('l1', end, oshiIds: ['p1']),
            }..remove('name'),
          );
      await col
          .doc('noEnd')
          .set(
            {
              ...recDoc('l1', end, oshiIds: ['p1']),
            }..remove('applyEndAt'),
          );
      await col.doc('badPrices').set({
        ...recDoc('l1', end, oshiIds: ['p1']),
        'prices': [
          {'seat': 'S', 'amount': 'free'},
        ],
      });
      await col.doc('badPricesList').set({
        ...recDoc('l1', end, oshiIds: ['p1']),
        'prices': 'S席 9800円',
      });
      final rs = await repo
          .watchReceptions(const FollowTargets(oshiIds: {'p1'}))
          .first;
      expect([for (final r in rs) r.id], ['ok']);
    });

    test('公演・受付も、グループと個人の両方に当たるものは1件にまとめる', () async {
      await db
          .collection('performances')
          .doc('p')
          .set(perfDoc('l1', start, groupIds: ['g1'], oshiIds: ['p1']));
      await db
          .collection('receptions')
          .doc('r')
          .set(recDoc('l1', start, groupIds: ['g1'], oshiIds: ['p1']));
      const targets = FollowTargets(groupIds: {'g1'}, oshiIds: {'p1'});
      expect(await repo.watchPerformances(targets).first, hasLength(1));
      expect(await repo.watchReceptions(targets).first, hasLength(1));
    });

    test('購読をやめても例外にならない', () async {
      final sub = repo
          .watchLives(const FollowTargets(groupIds: {'g1'}, oshiIds: {'p1'}))
          .listen((_) {});
      await pumpEventQueue();
      await sub.cancel();
      await db.collection('lives').add(liveDoc('A', groupIds: ['g1']));
      await pumpEventQueue();
    });
  });

  group('watchLive / watchPerformancesOf / watchReceptionsOf', () {
    test('watchLive: 無いライブは null', () async {
      expect(await repo.watchLive('none').first, isNull);
    });

    test('watchLive: 読めないライブは null（例外にしない）', () async {
      await db.collection('lives').doc('broken').set({
        'groupIds': ['g1'],
      });
      expect(await repo.watchLive('broken').first, isNull);
    });

    test('watchLive: 後から作られたら流れる', () async {
      final values = <String?>[];
      final sub = repo.watchLive('l1').listen((l) => values.add(l?.title));
      addTearDown(sub.cancel);
      await pumpEventQueue();
      await db
          .collection('lives')
          .doc('l1')
          .set(liveDoc('A', groupIds: ['g1']));
      await pumpEventQueue();
      expect(values, [null, 'A']);
    });

    test('watchPerformancesOf: そのライブの公演だけを開演順に。読めないものは飛ばす', () async {
      final col = db.collection('performances');
      await col.doc('late').set(perfDoc('l1', DateTime(2026, 12, 3)));
      await col.doc('early').set(perfDoc('l1', DateTime(2026, 12, 1)));
      await col.doc('mid').set(perfDoc('l1', DateTime(2026, 12, 2)));
      await col.doc('other').set(perfDoc('l2', DateTime(2026, 11, 1)));
      await col.doc('broken').set({'liveId': 'l1'});
      final ps = await repo.watchPerformancesOf('l1').first;
      expect([for (final p in ps) p.id], ['early', 'mid', 'late']);
    });

    test('watchReceptionsOf: そのライブの受付だけを申込期限の順に。読めないものは飛ばす', () async {
      final col = db.collection('receptions');
      await col.doc('b').set(recDoc('l1', DateTime(2026, 11, 20)));
      await col.doc('a').set(recDoc('l1', DateTime(2026, 11, 10)));
      await col.doc('other').set(recDoc('l2', DateTime(2026, 11, 1)));
      await col.doc('broken').set({'liveId': 'l1', 'name': 'X'});
      final rs = await repo.watchReceptionsOf('l1').first;
      expect([for (final r in rs) r.id], ['a', 'b']);
    });

    test('ライブに公演・受付が無ければ空', () async {
      expect(await repo.watchPerformancesOf('none').first, isEmpty);
      expect(await repo.watchReceptionsOf('none').first, isEmpty);
    });
  });
}
