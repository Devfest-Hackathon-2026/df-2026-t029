import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/repositories/oshi_repository.dart';

Map<String, dynamic> _doc(
  String name, {
  String status = 'approved',
  List<String>? aliases,
}) => {
  'name': name,
  'genre': 'idol',
  'status': status,
  'createdBy': 'someone',
  'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  'aliases': ?aliases,
};

OshiRequest _req({
  OshiKind kind = OshiKind.person,
  String name = '新しい推し',
  List<String> aliases = const [],
  List<String> groupIds = const [],
  String officialX = '',
}) => OshiRequest(
  kind: kind,
  name: name,
  genre: OshiGenre.idol,
  aliases: aliases,
  groupIds: groupIds,
  officialX: officialX,
);

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreOshiRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreOshiRepository(db);
  });

  group('watchAll', () {
    test('groups と oshis をまとめて返す（申請中を含む）', () async {
      await db.collection('groups').doc('g1').set(_doc('グループ'));
      await db.collection('oshis').doc('p1').set(_doc('個人', status: 'pending'));

      final list = await repo.watchAll().first;
      expect(list.map((o) => o.key).toSet(), {'group/g1', 'person/p1'});
      final p1 = list.firstWhere((o) => o.id == 'p1');
      expect(p1.kind, OshiKind.person);
      expect(p1.isPending, isTrue);
    });

    test('両方とも空なら空のリストを1回流す', () async {
      expect(await repo.watchAll().first, isEmpty);
    });

    test('読めないドキュメント（名前が空・status 不明）は除く', () async {
      await db.collection('groups').doc('ok').set(_doc('OK'));
      await db.collection('groups').doc('noname').set(_doc('  '));
      await db
          .collection('groups')
          .doc('bad')
          .set(_doc('X', status: 'rejected'));
      await db.collection('oshis').doc('empty').set({});

      final list = await repo.watchAll().first;
      expect(list.map((o) => o.id), ['ok']);
    });

    test('承認されると、status が変わった値が流れる', () async {
      await db.collection('groups').doc('g1').set(_doc('A', status: 'pending'));

      final stream = repo.watchAll();
      final statuses = <OshiStatus>[];
      final sub = stream.listen((list) {
        if (list.isNotEmpty) statuses.add(list.single.status);
      });
      await pumpEventQueue();
      await db.collection('groups').doc('g1').update({'status': 'approved'});
      await pumpEventQueue();
      await sub.cancel();

      expect(statuses.first, OshiStatus.pending);
      expect(statuses.last, OshiStatus.approved);
    });
  });

  group('request', () {
    test('status: pending で作成し、ID を返す', () async {
      final id = await repo.request(
        _req(name: ' さくら ', officialX: '@sakura'),
        uid: 'u1',
      );
      final snap = await db.collection('oshis').doc(id).get();
      final data = snap.data()!;
      expect(data['name'], 'さくら');
      expect(data['status'], 'pending');
      expect(data['createdBy'], 'u1');
      expect(data['officialX'], 'sakura');
      expect(data['createdAt'], isA<Timestamp>());
    });

    test('グループは groups に作る', () async {
      final id = await repo.request(
        _req(kind: OshiKind.group, name: 'ユニット'),
        uid: 'u1',
      );
      expect((await db.collection('groups').doc(id).get()).exists, isTrue);
      expect((await db.collection('oshis').get()).docs, isEmpty);
    });

    test('入力が不正なら OshiRequestException で、何も作らない', () async {
      await expectLater(
        repo.request(_req(name: '・・・'), uid: 'u1'),
        throwsA(isA<OshiRequestException>()),
      );
      expect((await db.collection('oshis').get()).docs, isEmpty);
    });

    test('同じ種別に完全一致（申請中を含む）があれば OshiDuplicateException', () async {
      await db
          .collection('oshis')
          .doc('p1')
          .set(_doc('サクラ', status: 'pending'));
      await expectLater(
        repo.request(_req(name: 'ｻｸﾗ'), uid: 'u1'),
        throwsA(
          isA<OshiDuplicateException>().having(
            (e) => e.duplicates.map((d) => d.id),
            'duplicates',
            ['p1'],
          ),
        ),
      );
      expect((await db.collection('oshis').get()).docs, hasLength(1));
    });

    test('別名どうしの一致も重複にする', () async {
      await db.collection('oshis').doc('p1').set(_doc('A', aliases: ['えー']));
      await expectLater(
        repo.request(
          _req(name: 'B', aliases: ['エー']),
          uid: 'u1',
        ),
        throwsA(isA<OshiDuplicateException>()),
      );
    });

    test('種別が違えば同じ名前でも申請できる', () async {
      await db.collection('groups').doc('g1').set(_doc('さくら'));
      final id = await repo.request(_req(name: 'さくら'), uid: 'u1');
      expect((await db.collection('oshis').doc(id).get()).exists, isTrue);
    });

    test('部分一致は申請を止めない', () async {
      await db.collection('oshis').doc('p1').set(_doc('さくらみこ'));
      await repo.request(_req(name: 'さくら'), uid: 'u1');
      expect((await db.collection('oshis').get()).docs, hasLength(2));
    });

    test('承認済みの所属グループなら申請できる', () async {
      await db.collection('groups').doc('g1').set(_doc('G'));
      final id = await repo.request(_req(groupIds: ['g1']), uid: 'u1');
      final data = (await db.collection('oshis').doc(id).get()).data()!;
      expect(data['groupIds'], ['g1']);
    });

    test('所属グループが存在しない・申請中なら OshiRequestException', () async {
      await db
          .collection('groups')
          .doc('pend')
          .set(_doc('P', status: 'pending'));
      for (final gid in ['missing', 'pend']) {
        await expectLater(
          repo.request(_req(groupIds: [gid]), uid: 'u1'),
          throwsA(isA<OshiRequestException>()),
          reason: gid,
        );
      }
      expect((await db.collection('oshis').get()).docs, isEmpty);
    });

    test('同じ名前で2回申請すると、2回目は重複として止まる', () async {
      await repo.request(_req(name: 'さくら'), uid: 'u1');
      await expectLater(
        repo.request(_req(name: 'サクラ'), uid: 'u2'),
        throwsA(isA<OshiDuplicateException>()),
      );
      expect((await db.collection('oshis').get()).docs, hasLength(1));
    });
  });
}
