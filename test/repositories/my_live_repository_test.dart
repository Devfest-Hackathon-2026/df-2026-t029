// MyLiveRepository と、LiveRepository の myLives 自動追加・ID 指定の購読のテスト。
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/my_live.dart';
import 'package:oshiashi/repositories/live_repository.dart';
import 'package:oshiashi/repositories/my_live_repository.dart';
import 'package:oshiashi/utils/live_diff.dart';

import '../utils/live_merge_fixtures.dart';
import 'live_repository_test.dart' show liveDoc, perf, perfDoc, rec, recDoc;

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreMyLiveRepository mine;
  late FirestoreLiveRepository lives;

  setUp(() {
    db = FakeFirebaseFirestore();
    mine = FirestoreMyLiveRepository(db);
    lives = FirestoreLiveRepository(db);
  });

  Future<Set<String>> myIds(String uid) async => {
    for (final d in (await db.collection('users/$uid/myLives').get()).docs)
      d.id,
  };

  group('MyLiveRepository', () {
    test('add で入り、watchAll に出る。項目は addedAt のみ', () async {
      await mine.add('alice', 'L1');
      final doc = await db.doc('users/alice/myLives/L1').get();
      expect(doc.data()!.keys, ['addedAt']);
      final list = await mine.watchAll('alice').first;
      expect([for (final m in list) m.liveId], ['L1']);
    });

    test('2回 add しても addedAt が変わらない', () async {
      await db.doc('users/alice/myLives/L1').set({
        'addedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });
      await mine.add('alice', 'L1');
      final doc = await db.doc('users/alice/myLives/L1').get();
      expect(
        (doc.data()!['addedAt'] as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 1, 1),
      );
    });

    test('remove で消える。入っていなくてもエラーにならない。申込状況は残る', () async {
      await db.doc('users/alice/applications/r1').set({'status': 'won'});
      await mine.add('alice', 'L1');
      await mine.remove('alice', 'L1');
      await mine.remove('alice', 'L1');
      expect(await myIds('alice'), isEmpty);
      expect(
        (await db.doc('users/alice/applications/r1').get()).exists,
        isTrue,
      );
    });

    test('外して追加し直すと、申込状況はそのまま戻る', () async {
      await db.doc('users/alice/applications/r1').set({'status': 'won'});
      await mine.add('alice', 'L1');
      await mine.remove('alice', 'L1');
      await mine.add('alice', 'L1');
      final app = await db.doc('users/alice/applications/r1').get();
      expect(app.data()!['status'], 'won');
    });

    test('ユーザーごとに独立している', () async {
      await mine.add('alice', 'L1');
      expect(await myIds('bob'), isEmpty);
      expect(await mine.watchAll('bob').first, isEmpty);
    });

    test('MyLive.fromFirestore は欠けた・型違いの値でも落ちない', () {
      expect(MyLive.fromFirestore('x', null).addedAt, isNull);
      expect(MyLive.fromFirestore('x', {'addedAt': 'あ'}).addedAt, isNull);
    });
  });

  group('create の自動追加', () {
    test('作ったライブが作成者の myLives に入る（他人には入らない）', () async {
      final saved = await lives.create(
        live: const Live(title: 'ツアー', groupIds: ['g1']),
        performances: [perf()],
        receptions: [rec()],
        uid: 'alice',
      );
      expect(await myIds('alice'), {saved.live.id});
      expect(await myIds('bob'), isEmpty);
    });
  });

  group('applyMerge の自動追加', () {
    Future<void> seed() async {
      await db.doc('lives/L1').set({
        'title': 'ツアー2026',
        'groupIds': ['g1'],
        'oshiIds': <String>[],
        'createdBy': 'bob',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'updatedBy': 'bob',
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });
    }

    test('既存への反映で myLives に入り、2回目は addedAt を変えない', () async {
      await seed();
      final base = (await lives.fetchExisting('L1'))!;
      await lives.applyMerge(
        diffLive(base, input(title: 'ツアー2026 改')),
        uid: 'alice',
      );
      expect(await myIds('alice'), {'L1'});
      final first = (await db.doc('users/alice/myLives/L1').get())
          .data()!['addedAt'];

      final base2 = (await lives.fetchExisting('L1'))!;
      await lives.applyMerge(
        diffLive(base2, input(title: 'ツアー2026 再改')),
        uid: 'alice',
      );
      final second = (await db.doc('users/alice/myLives/L1').get())
          .data()!['addedAt'];
      expect(second, first);
    });

    test('変更が無い計画は ArgumentError で、myLives に入らない', () async {
      await seed();
      final base = (await lives.fetchExisting('L1'))!;
      final plan = diffLive(
        base,
        input(title: 'ツアー2026', performances: [], receptions: []),
      );
      expect(plan.isEmpty, isTrue);
      await expectLater(
        lives.applyMerge(plan, uid: 'alice'),
        throwsArgumentError,
      );
      expect(await myIds('alice'), isEmpty);
    });
  });

  group('ID 指定の購読', () {
    Future<void> seedMany(int n) async {
      for (var i = 0; i < n; i++) {
        await db.doc('lives/L$i').set(liveDoc('ライブ$i', groupIds: ['g1']));
        await db
            .doc('performances/p$i')
            .set(perfDoc('L$i', DateTime(2026, 12, 1)));
        await db
            .doc('receptions/r$i')
            .set(recDoc('L$i', DateTime(2026, 11, 20)));
      }
    }

    test('指定した ID のライブ・公演・受付だけが出る', () async {
      await seedMany(5);
      final ids = {'L1', 'L3'};
      final ls = await lives.watchLivesByIds(ids).first;
      expect({for (final l in ls) l.id}, ids);
      final ps = await lives.watchPerformancesOfLives(ids).first;
      expect({for (final p in ps) p.liveId}, ids);
      final rs = await lives.watchReceptionsOfLives(ids).first;
      expect({for (final r in rs) r.liveId}, ids);
    });

    test('空の ID は空を1回流して終わる', () async {
      await seedMany(2);
      expect(await lives.watchLivesByIds({}).toList(), [isEmpty]);
      expect(await lives.watchPerformancesOfLives({}).toList(), [isEmpty]);
      expect(await lives.watchReceptionsOfLives({}).toList(), [isEmpty]);
    });

    test('存在しない ID は無視する', () async {
      await seedMany(2);
      final ls = await lives.watchLivesByIds({'L0', 'nope'}).first;
      expect([for (final l in ls) l.id], ['L0']);
    });

    test('30件を超えても全件出る（分割）', () async {
      await seedMany(65);
      final ids = {for (var i = 0; i < 65; i++) 'L$i'};
      final ls = await lives.watchLivesByIds(ids).first;
      expect(ls, hasLength(65));
      final ps = await lives.watchPerformancesOfLives(ids).first;
      expect(ps, hasLength(65));
    });
  });
}
