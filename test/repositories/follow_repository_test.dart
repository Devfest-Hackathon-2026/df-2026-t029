import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/repositories/follow_repository.dart';

OshiSummary _target(
  String id, {
  OshiKind kind = OshiKind.group,
  OshiStatus status = OshiStatus.approved,
}) => OshiSummary(
  id: id,
  kind: kind,
  name: '推し$id',
  genre: OshiGenre.idol,
  status: status,
);

Future<void> _seedOshi(
  FakeFirebaseFirestore db,
  String id, {
  OshiKind kind = OshiKind.group,
  String status = 'approved',
}) => db.collection(kind.collection).doc(id).set({
  'name': '推し$id',
  'genre': 'idol',
  'status': status,
  'createdBy': 'someone',
  'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
});

// 注: fake の runTransaction は再試行も競合検出もしないので、
// 「同時に2回押す」場合の重複防止はここでは確かめられない。

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreFollowRepository repo;

  Future<Map<String, dynamic>?> userData(String uid) async =>
      (await db.collection('users').doc(uid).get()).data();

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreFollowRepository(db);
  });

  group('follow', () {
    test('users/{uid} が無い状態で最初のフォローが成功し、必須項目を作る', () async {
      await _seedOshi(db, 'g1');
      await repo.follow('u1', _target('g1'), displayName: ' アリス ');

      final data = (await userData('u1'))!;
      expect(data['followingGroupIds'], ['g1']);
      expect(data['followingOshiIds'], <String>[]);
      expect(data['displayName'], 'アリス');
      expect(data['createdAt'], isA<Timestamp>());
    });

    test('displayName が null・空白なら「名無し」', () async {
      await _seedOshi(db, 'g1');
      await repo.follow('u1', _target('g1'));
      await repo.follow('u2', _target('g1'), displayName: '  ');
      expect((await userData('u1'))!['displayName'], '名無し');
      expect((await userData('u2'))!['displayName'], '名無し');
    });

    test('2回フォローしても重複しない', () async {
      await _seedOshi(db, 'g1');
      await repo.follow('u1', _target('g1'));
      await repo.follow('u1', _target('g1'));
      expect((await userData('u1'))!['followingGroupIds'], ['g1']);
    });

    test('個人は followingOshiIds に入る', () async {
      await _seedOshi(db, 'p1', kind: OshiKind.person);
      await repo.follow('u1', _target('p1', kind: OshiKind.person));
      final data = (await userData('u1'))!;
      expect(data['followingOshiIds'], ['p1']);
      expect(data['followingGroupIds'], <String>[]);
    });

    test('既存のユーザーの displayName・createdAt・ほかの配列を上書きしない', () async {
      final created = Timestamp.fromDate(DateTime(2025, 1, 1));
      await db.collection('users').doc('u1').set({
        'displayName': '元の名前',
        'createdAt': created,
        'followingGroupIds': ['g0'],
        'followingOshiIds': ['p0'],
      });
      await _seedOshi(db, 'g1');
      await repo.follow('u1', _target('g1'), displayName: '新しい名前');

      final data = (await userData('u1'))!;
      expect(data['displayName'], '元の名前');
      expect(data['createdAt'], created);
      expect(data['followingGroupIds'], ['g0', 'g1']);
      expect(data['followingOshiIds'], ['p0']);
    });

    test('既存のユーザーに欠けている項目だけを補う', () async {
      await db.collection('users').doc('u1').set({'displayName': '元の名前'});
      await _seedOshi(db, 'g1');
      await repo.follow('u1', _target('g1'));

      final data = (await userData('u1'))!;
      expect(data['displayName'], '元の名前');
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['followingOshiIds'], <String>[]);
      expect(data['followingGroupIds'], ['g1']);
    });

    test('申請中の推しは、渡された値で拒否する（書き込まない）', () async {
      await _seedOshi(db, 'g1', status: 'pending');
      await expectLater(
        repo.follow('u1', _target('g1', status: OshiStatus.pending)),
        throwsA(isA<StateError>()),
      );
      expect(await userData('u1'), isNull);
    });

    test('渡された値が承認済みでも、Firestore 上で申請中なら拒否する', () async {
      await _seedOshi(db, 'g1', status: 'pending');
      await expectLater(
        repo.follow('u1', _target('g1')),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('申請中'),
          ),
        ),
      );
      expect(await userData('u1'), isNull);
    });

    test('推しが存在しないなら拒否する', () async {
      await expectLater(
        repo.follow('u1', _target('nothing')),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('見つかりません'),
          ),
        ),
      );
      expect(await userData('u1'), isNull);
    });

    test('種別が違うコレクションの同じ ID は別の推しとして扱う', () async {
      await _seedOshi(db, 'x', kind: OshiKind.person);
      await expectLater(
        repo.follow('u1', _target('x', kind: OshiKind.group)),
        throwsA(isA<StateError>()),
      );
    });

    test('同じ種別が200件に達していたら拒否し、別の種別は追加できる', () async {
      final ids = [for (var i = 0; i < 200; i++) 'g$i'];
      await db.collection('users').doc('u1').set({
        'displayName': 'A',
        'createdAt': Timestamp.now(),
        'followingGroupIds': ids,
        'followingOshiIds': <String>[],
      });
      await _seedOshi(db, 'g200');
      await _seedOshi(db, 'p1', kind: OshiKind.person);

      await expectLater(
        repo.follow('u1', _target('g200')),
        throwsA(isA<StateError>()),
      );
      expect((await userData('u1'))!['followingGroupIds'], hasLength(200));

      await repo.follow('u1', _target('p1', kind: OshiKind.person));
      expect((await userData('u1'))!['followingOshiIds'], ['p1']);
    });

    test('199件なら200件目を追加できる', () async {
      final ids = [for (var i = 0; i < 199; i++) 'g$i'];
      await db.collection('users').doc('u1').set({
        'displayName': 'A',
        'createdAt': Timestamp.now(),
        'followingGroupIds': ids,
        'followingOshiIds': <String>[],
      });
      await _seedOshi(db, 'g199');
      await repo.follow('u1', _target('g199'));
      expect((await userData('u1'))!['followingGroupIds'], hasLength(200));
    });

    test('200件に達していても、フォロー済みの推しなら何もしない（エラーにしない）', () async {
      final ids = [for (var i = 0; i < 200; i++) 'g$i'];
      await db.collection('users').doc('u1').set({
        'displayName': 'A',
        'createdAt': Timestamp.now(),
        'followingGroupIds': ids,
        'followingOshiIds': <String>[],
      });
      await _seedOshi(db, 'g0');
      await repo.follow('u1', _target('g0'));
      expect((await userData('u1'))!['followingGroupIds'], hasLength(200));
    });
  });

  group('unfollow', () {
    test('フォローを解除する', () async {
      await _seedOshi(db, 'g1');
      await _seedOshi(db, 'g2');
      await repo.follow('u1', _target('g1'));
      await repo.follow('u1', _target('g2'));
      await repo.unfollow('u1', _target('g1'));
      expect((await userData('u1'))!['followingGroupIds'], ['g2']);
    });

    test('users/{uid} が無くてもエラーにならず、ドキュメントを作らない', () async {
      await repo.unfollow('u1', _target('g1'));
      expect(await userData('u1'), isNull);
    });

    test('フォローしていない推しの解除は何もしない', () async {
      await _seedOshi(db, 'g1');
      await repo.follow('u1', _target('g1'));
      await repo.unfollow('u1', _target('other'));
      await repo.unfollow('u1', _target('g1', kind: OshiKind.person));
      expect((await userData('u1'))!['followingGroupIds'], ['g1']);
    });

    test('推しが削除済みでも解除できる', () async {
      await _seedOshi(db, 'g1');
      await repo.follow('u1', _target('g1'));
      await db.collection('groups').doc('g1').delete();
      await repo.unfollow('u1', _target('g1'));
      expect((await userData('u1'))!['followingGroupIds'], isEmpty);
    });
  });

  group('watch', () {
    test('users/{uid} が無ければ空', () async {
      expect((await repo.watch('u1').first).isEmpty, isTrue);
    });

    test('フォロー・解除がリアルタイムに流れる', () async {
      await _seedOshi(db, 'g1');
      final states = <FollowState>[];
      final sub = repo.watch('u1').listen(states.add);
      await pumpEventQueue();
      await repo.follow('u1', _target('g1'));
      await pumpEventQueue();
      await repo.unfollow('u1', _target('g1'));
      await pumpEventQueue();
      await sub.cancel();

      expect(states.first.isEmpty, isTrue);
      expect(states.any((s) => s.groupIds.contains('g1')), isTrue);
      expect(states.last.groupIds, isEmpty);
    });
  });
}
