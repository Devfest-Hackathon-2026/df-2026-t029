import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/application.dart';
import 'package:oshiashi/models/reception.dart';
import 'package:oshiashi/repositories/application_repository.dart';

Reception reception({String? id = 'r1', String? liveId = 'l1'}) => Reception(
  id: id,
  liveId: liveId,
  type: ReceptionType.fc,
  name: 'FC先行',
  applyEndAt: DateTime(2026, 11, 20),
);

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreApplicationRepository repo;

  CollectionReference<Map<String, dynamic>> apps(String uid) =>
      db.collection('users').doc(uid).collection('applications');

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreApplicationRepository(db);
  });

  group('setStatus', () {
    test('作成: ドキュメント ID は受付 ID、項目は liveId・status・updatedAt の3つだけ', () async {
      await repo.setStatus('alice', reception(), ApplicationStatus.applied);
      final doc = await apps('alice').doc('r1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!.keys.toSet(), {'liveId', 'status', 'updatedAt'});
      expect(doc.data()!['liveId'], 'l1');
      expect(doc.data()!['status'], 'applied');
      expect(doc.data()!['updatedAt'], isA<Timestamp>());
    });

    test('どの状態からどの状態へも変えられる（順番を強制しない）', () async {
      final r = reception();
      for (final s in [
        ApplicationStatus.paid,
        ApplicationStatus.applied,
        ApplicationStatus.lost,
        ApplicationStatus.won,
        ApplicationStatus.applied,
      ]) {
        await repo.setStatus('alice', r, s);
        final data = (await apps('alice').doc('r1').get()).data()!;
        expect(data['status'], s.code);
      }
      expect((await apps('alice').get()).docs, hasLength(1));
    });

    test('上書きなので、知らない項目は消える', () async {
      await apps('alice')
          .doc('r1')
          .set({'liveId': 'old', 'status': 'applied', 'extra': 1});
      await repo.setStatus('alice', reception(), ApplicationStatus.won);
      final data = (await apps('alice').doc('r1').get()).data()!;
      expect(data.keys.toSet(), {'liveId', 'status', 'updatedAt'});
      expect(data['liveId'], 'l1');
    });

    test('null（未申込）に戻すとドキュメントを削除する', () async {
      await repo.setStatus('alice', reception(), ApplicationStatus.won);
      await repo.setStatus('alice', reception(), null);
      expect((await apps('alice').doc('r1').get()).exists, isFalse);
    });

    test('ドキュメントが無いときに null にしても例外にならない', () async {
      await repo.setStatus('alice', reception(), null);
      expect((await apps('alice').get()).docs, isEmpty);
    });

    test('ほかの受付・ほかのユーザーのドキュメントには触れない', () async {
      await repo.setStatus('alice', reception(id: 'r1'), ApplicationStatus.won);
      await repo.setStatus(
        'alice',
        reception(id: 'r2'),
        ApplicationStatus.paid,
      );
      await repo.setStatus('bob', reception(id: 'r1'), ApplicationStatus.lost);
      await repo.setStatus('alice', reception(id: 'r1'), null);
      expect([for (final d in (await apps('alice').get()).docs) d.id], ['r2']);
      expect((await apps('bob').doc('r1').get()).data()!['status'], 'lost');
    });

    test('受付の id か liveId が null なら ArgumentError（何も書かない）', () async {
      for (final r in [reception(id: null), reception(liveId: null)]) {
        for (final s in [ApplicationStatus.applied, null]) {
          await expectLater(repo.setStatus('alice', r, s), throwsArgumentError);
        }
      }
      expect((await apps('alice').get()).docs, isEmpty);
    });
  });

  group('watchAll', () {
    test('ドキュメントが無ければ空の Map', () async {
      expect(await repo.watchAll('alice').first, isEmpty);
    });

    test('receptionId → Application', () async {
      await repo.setStatus('alice', reception(id: 'r1'), ApplicationStatus.won);
      await repo.setStatus(
        'alice',
        reception(id: 'r2', liveId: 'l2'),
        ApplicationStatus.applied,
      );
      final all = await repo.watchAll('alice').first;
      expect(all.keys.toSet(), {'r1', 'r2'});
      expect(all['r1']!.status, ApplicationStatus.won);
      expect(all['r1']!.liveId, 'l1');
      expect(all['r1']!.receptionId, 'r1');
      expect(all['r2']!.status, ApplicationStatus.applied);
      expect(all['r2']!.liveId, 'l2');
    });

    test('status が不明・liveId が文字列でないドキュメントは含まない（例外にしない）', () async {
      await apps('alice').doc('ok').set({'liveId': 'l1', 'status': 'paid'});
      await apps('alice')
          .doc('unknown')
          .set({'liveId': 'l1', 'status': 'pending'});
      await apps('alice').doc('noStatus').set({'liveId': 'l1'});
      await apps('alice').doc('badLive').set({'liveId': 1, 'status': 'won'});
      await apps('alice').doc('empty').set({});
      final all = await repo.watchAll('alice').first;
      expect(all.keys, ['ok']);
    });

    test('ほかのユーザーの申込状況は含まない', () async {
      await repo.setStatus('bob', reception(), ApplicationStatus.won);
      expect(await repo.watchAll('alice').first, isEmpty);
    });

    test('変更・削除が流れる', () async {
      final values = <Map<String, ApplicationStatus>>[];
      final sub = repo
          .watchAll('alice')
          .listen(
            (m) =>
                values.add({for (final e in m.entries) e.key: e.value.status}),
          );
      addTearDown(sub.cancel);
      await pumpEventQueue();
      await repo.setStatus('alice', reception(), ApplicationStatus.applied);
      await pumpEventQueue();
      await repo.setStatus('alice', reception(), ApplicationStatus.won);
      await pumpEventQueue();
      await repo.setStatus('alice', reception(), null);
      await pumpEventQueue();
      // 未申込 → 申込済 → 当選 → 未申込 の順に流れる（途中の重複は問わない）
      expect(
        [for (final m in values) m['r1']],
        containsAllInOrder(<ApplicationStatus?>[
          null,
          ApplicationStatus.applied,
          ApplicationStatus.won,
          null,
        ]),
      );
      expect(values.last, isEmpty);
    });
  });
}
