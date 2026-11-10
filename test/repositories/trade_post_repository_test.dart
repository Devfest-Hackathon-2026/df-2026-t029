// lib/repositories/trade_post_repository.dart の掲示板用の取得（G-3-1）と
// マッチの検索（G-4-1）のテスト
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/repositories/trade_post_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreTradePostRepository repo;

  /// 投稿を直接書き込む（[day] 日の更新日時）
  Future<void> put(
    String id, {
    List<String> groupIds = const [],
    List<String> oshiIds = const [],
    String status = 'open',
    List<String> giveKeys = const [],
    required int day,
  }) => db.collection('tradePosts').doc(id).set({
    'uid': 'u1',
    'displayName': '匿名',
    'groupIds': groupIds,
    'oshiIds': oshiIds,
    'tags': ['trade'],
    'gives': [],
    'wants': [],
    'giveKeys': giveKeys,
    'wantKeys': [],
    'handover': ['mail'],
    'performanceIds': [],
    'images': [],
    'status': status,
    'createdAt': Timestamp.fromDate(DateTime(2026, 11, day)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 11, day)),
  });

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreTradePostRepository(db);
  });

  group('watchOpenFor', () {
    setUp(() async {
      await put('old', groupIds: ['g1'], day: 1);
      await put('new', groupIds: ['g1', 'g2'], day: 3);
      await put('closed', groupIds: ['g1'], status: 'closed', day: 4);
      await put('hidden', groupIds: ['g1'], status: 'hidden', day: 5);
      await put('other', groupIds: ['g2'], day: 2);
      await put('person', oshiIds: ['p1'], day: 6);
      await put('personInGroup', groupIds: ['g1'], oshiIds: ['p1'], day: 7);
    });

    test('グループは groupIds で探し、募集中だけを更新日時の新しい順に返す', () async {
      final posts = await repo
          .watchOpenFor(OshiKind.group, 'g1', limit: 50)
          .first;
      expect(posts.map((p) => p.id), ['personInGroup', 'new', 'old']);
    });

    test('個人は oshiIds で探す', () async {
      final posts = await repo
          .watchOpenFor(OshiKind.person, 'p1', limit: 50)
          .first;
      expect(posts.map((p) => p.id), ['personInGroup', 'person']);
    });

    test('limit 件までを新しい順に返す', () async {
      final posts = await repo
          .watchOpenFor(OshiKind.group, 'g1', limit: 2)
          .first;
      expect(posts.map((p) => p.id), ['personInGroup', 'new']);
    });

    test('募集終了にした投稿は、一覧から消える', () async {
      final stream = repo.watchOpenFor(OshiKind.group, 'g2', limit: 50);
      final results = <List<String?>>[];
      final sub = stream.listen((l) => results.add([for (final p in l) p.id]));
      await pumpEventQueue();

      await db.collection('tradePosts').doc('new').update({'status': 'closed'});
      await pumpEventQueue();
      await sub.cancel();

      expect(results.first, ['new', 'other']);
      expect(results.last, ['other']);
    });
  });

  group('壊れた投稿', () {
    test('中身の壊れた投稿は飛ばし、ほかの投稿は返す', () async {
      await put('ok', groupIds: ['g1'], day: 1);
      await db.collection('tradePosts').doc('broken').set({
        'groupIds': ['g1'],
        'status': 'open',
        'gives': ['セットではない値'],
        'updatedAt': Timestamp.fromDate(DateTime(2026, 11, 2)),
      });
      final posts = await repo
          .watchOpenFor(OshiKind.group, 'g1', limit: 50)
          .first;
      expect(posts.map((p) => p.id), ['ok']);
      expect(await repo.fetch('broken'), isNull);
    });
  });

  group('fetchOpenGiving', () {
    test('giveKeys にどれかを含む、募集中の投稿だけを返す', () async {
      await put('a', giveKeys: ['item:x#v1', 'goods:x'], day: 1);
      await put('b', giveKeys: ['member:m1'], day: 2);
      await put('closed', giveKeys: ['goods:x'], status: 'closed', day: 3);
      await put('hidden', giveKeys: ['goods:x'], status: 'hidden', day: 4);
      await put('none', giveKeys: ['goods:y'], day: 5);

      final posts = await repo.fetchOpenGiving(['goods:x', 'member:m1']);
      expect(posts.map((p) => p.id).toSet(), {'a', 'b'});
    });

    test('30個を超えるキーは分けて検索し、重複を除く', () async {
      final keys = [for (var i = 0; i < 65; i++) 'goods:g$i'];
      await put('first', giveKeys: ['goods:g0'], day: 1);
      await put('last', giveKeys: ['goods:g64'], day: 2);
      // 2回の検索の両方に当たる投稿
      await put('both', giveKeys: ['goods:g1', 'goods:g40'], day: 3);

      final posts = await repo.fetchOpenGiving(keys);
      expect(posts.map((p) => p.id).toList()..sort(), [
        'both',
        'first',
        'last',
      ]);
    });

    test('キーが空なら検索せずに空', () async {
      await put('a', giveKeys: ['goods:x'], day: 1);
      expect(await repo.fetchOpenGiving(const []), isEmpty);
    });
  });
}
