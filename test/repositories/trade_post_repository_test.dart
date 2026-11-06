// lib/repositories/trade_post_repository.dart の掲示板用の取得（G-3-1）のテスト
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
    required int day,
  }) => db.collection('tradePosts').doc(id).set({
    'uid': 'u1',
    'displayName': '匿名',
    'groupIds': groupIds,
    'oshiIds': oshiIds,
    'tags': ['trade'],
    'gives': [],
    'wants': [],
    'giveKeys': [],
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
}
