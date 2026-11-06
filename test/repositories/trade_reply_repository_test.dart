// lib/repositories/trade_reply_repository.dart（G-5-2）のテスト
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/repositories/trade_reply_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreTradeReplyRepository repo;

  CollectionReference<Map<String, dynamic>> replies(String postId) =>
      db.collection('tradePosts').doc(postId).collection('replies');

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreTradeReplyRepository(db);
  });

  test('create：承認前・サーバー時刻で作り、添付がなければ linkedPostId を書かない', () async {
    final id = await repo.create(
      'p1',
      uid: 'u1',
      displayName: '匿名',
      text: 'こんにちは',
    );
    final data = (await replies('p1').doc(id).get()).data()!;
    expect(data.keys.toSet(), {
      'uid',
      'displayName',
      'text',
      'approved',
      'createdAt',
    });
    expect(data['approved'], isFalse);
    expect(data['createdAt'], isA<Timestamp>());
  });

  test('create：添付があれば linkedPostId を書く', () async {
    final id = await repo.create(
      'p1',
      uid: 'u1',
      displayName: '匿名',
      text: '交換しませんか',
      linkedPostId: 'mine',
    );
    final data = (await replies('p1').doc(id).get()).data()!;
    expect(data['linkedPostId'], 'mine');
  });

  test('watchReplies：書いた順に返す', () async {
    await replies('p1').doc('late').set({
      'uid': 'a',
      'displayName': '匿名',
      'text': '後',
      'approved': true,
      'createdAt': Timestamp.fromDate(DateTime(2026, 11, 6, 12)),
    });
    await replies('p1').doc('early').set({
      'uid': 'b',
      'displayName': '匿名',
      'text': '先',
      'approved': false,
      'createdAt': Timestamp.fromDate(DateTime(2026, 11, 6, 10)),
    });
    final list = await repo.watchReplies('p1').first;
    expect(list.map((r) => r.id), ['early', 'late']);
    expect(list.last.approved, isTrue);
    expect(list.first.linkedPostId, isNull);
  });

  test('delete：返信を消す', () async {
    final id = await repo.create(
      'p1',
      uid: 'u1',
      displayName: '匿名',
      text: '消す',
    );
    await repo.delete('p1', id);
    expect((await replies('p1').doc(id).get()).exists, isFalse);
  });
}
