// FirestoreLiveRepository の watchLives など（複数のクエリをまとめる処理）の
// 回帰テスト。fake_cloud_firestore ではクエリをエラーにしたり、クエリごとに
// 値を流す時機を変えたりできないので、クエリごとに StreamController を持つ
// 小さな偽物の FirebaseFirestore を使う。
//
// cloud_firestore の Query などは @sealed（外部での実装を想定しない）だが、
// テスト用の偽物に限って実装する（fake_cloud_firestore も同じことをしている）。
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/repositories/live_repository.dart';

void main() {
  late _Db db;
  late FirestoreLiveRepository repo;

  setUp(() {
    db = _Db();
    repo = FirestoreLiveRepository(db);
  });

  /// lives に対して作られたクエリ（作られた順）
  List<_Query> queries() => db.col('lives').queries;
  _Query groupQuery([int i = 0]) =>
      queries().where((q) => q.field == 'groupIds').elementAt(i);
  _Query oshiQuery([int i = 0]) =>
      queries().where((q) => q.field == 'oshiIds').elementAt(i);

  const targets = FollowTargets(groupIds: {'g1'}, oshiIds: {'p1'});

  /// 購読して、流れたものを記録する
  ({List<List<String?>> values, List<Object> errors, Completer<void> done})
  listen(Stream<List<Live>> stream) {
    final values = <List<String?>>[];
    final errors = <Object>[];
    final done = Completer<void>();
    final sub = stream.listen(
      (ls) => values.add([for (final l in ls) l.id]..sort()),
      onError: errors.add,
      onDone: done.complete,
    );
    addTearDown(sub.cancel);
    return (values: values, errors: errors, done: done);
  }

  group('値の流れ方', () {
    test('対象のグループ・推しごとにクエリを作る（array-contains-any、30件ずつ）', () async {
      final ids = {
        for (var i = 0; i < 65; i++) 'g${i.toString().padLeft(2, '0')}',
      };
      listen(repo.watchLives(FollowTargets(groupIds: ids, oshiIds: {'p1'})));
      await pumpEventQueue();
      expect(queries(), hasLength(4));
      expect(
        [
          for (final q in queries().where((q) => q.field == 'groupIds'))
            (q.values as List).length,
        ],
        [30, 30, 5],
      );
      expect(oshiQuery().values, ['p1']);
      expect(queries().every((q) => q.listening), isTrue);
    });

    test('すべてのクエリが1回ずつ値を流すまでは、何も流さない', () async {
      final r = listen(repo.watchLives(targets));
      await pumpEventQueue();
      groupQuery().emit([
        _doc('a', groupIds: ['g1']),
      ]);
      await pumpEventQueue();
      expect(r.values, isEmpty);

      oshiQuery().emit([
        _doc('b', oshiIds: ['p1']),
      ]);
      await pumpEventQueue();
      expect(r.values, [
        ['a', 'b'],
      ]);
    });

    test('両方のクエリに当たるドキュメントは1件にまとめ、更新を反映する', () async {
      final r = listen(repo.watchLives(targets));
      await pumpEventQueue();
      final both = _doc('both', groupIds: ['g1'], oshiIds: ['p1']);
      groupQuery().emit([both]);
      oshiQuery().emit([both]);
      await pumpEventQueue();
      expect(r.values.last, ['both']);

      // グループ側から外れても、推し側に残っていれば出る
      groupQuery().emit([]);
      await pumpEventQueue();
      expect(r.values.last, ['both']);
      oshiQuery().emit([]);
      await pumpEventQueue();
      expect(r.values.last, isEmpty);
    });

    test('読めないドキュメントは飛ばす', () async {
      final r = listen(repo.watchLives(targets));
      await pumpEventQueue();
      groupQuery().emit([
        _doc('ok', groupIds: ['g1']),
        _RawDoc('broken', {
          'groupIds': ['g1'],
        }),
      ]);
      oshiQuery().emit([]);
      await pumpEventQueue();
      expect(r.values.last, ['ok']);
    });
  });

  group('エラーの後（回帰テスト）', () {
    test('片方がエラーになった後、もう片方が更新されても値が流れない。エラーは1回、ストリームは閉じる', () async {
      final r = listen(repo.watchLives(targets));
      await pumpEventQueue();
      groupQuery().emit([
        _doc('a', groupIds: ['g1']),
      ]);
      oshiQuery().emit([
        _doc('b', oshiIds: ['p1']),
      ]);
      await pumpEventQueue();
      expect(r.values, [
        ['a', 'b'],
      ]);

      oshiQuery().fail();
      await pumpEventQueue();
      // 残ったグループ側が更新されても、古い推し側の結果と組み合わせて流さない
      groupQuery().emit([
        _doc('a', groupIds: ['g1']),
        _doc('c', groupIds: ['g1']),
      ]);
      await pumpEventQueue();

      expect(r.values, [
        ['a', 'b'],
      ]);
      expect(r.errors, hasLength(1));
      expect(
        r.errors.single,
        isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        ),
      );
      expect(r.done.isCompleted, isTrue);
    });

    test('エラーの後、すべてのクエリの購読を解除する', () async {
      listen(repo.watchLives(targets));
      await pumpEventQueue();
      expect(queries().every((q) => q.listening), isTrue);
      groupQuery().fail();
      await pumpEventQueue();
      expect(queries().map((q) => q.cancelled), everyElement(isTrue));
    });

    test('最初の値の前にエラーになっても、エラーを1回流して閉じる', () async {
      final r = listen(repo.watchLives(targets));
      await pumpEventQueue();
      groupQuery().fail();
      await pumpEventQueue();
      oshiQuery().emit([
        _doc('b', oshiIds: ['p1']),
      ]);
      await pumpEventQueue();
      expect(r.values, isEmpty);
      expect(r.errors, hasLength(1));
      expect(r.done.isCompleted, isTrue);
    });

    test('両方のクエリがエラーになっても、エラーは1回だけ', () async {
      final r = listen(repo.watchLives(targets));
      await pumpEventQueue();
      groupQuery().fail();
      oshiQuery().fail();
      await pumpEventQueue();
      expect(r.errors, hasLength(1));
      expect(r.done.isCompleted, isTrue);
    });

    test('分割された3つ目のクエリのエラーでも同じ（すべて解除して閉じる）', () async {
      final ids = {
        for (var i = 0; i < 65; i++) 'g${i.toString().padLeft(2, '0')}',
      };
      final r = listen(repo.watchLives(FollowTargets(groupIds: ids)));
      await pumpEventQueue();
      groupQuery(0).emit([]);
      groupQuery(1).emit([]);
      groupQuery(2).fail();
      await pumpEventQueue();
      groupQuery(0).emit([
        _doc('late', groupIds: ['g00']),
      ]);
      await pumpEventQueue();
      expect(r.values, isEmpty);
      expect(r.errors, hasLength(1));
      expect(queries().map((q) => q.cancelled), everyElement(isTrue));
    });

    test('公演・受付の購読も同じ処理を使う', () async {
      final perf = listen(
        repo.watchPerformances(targets).map((_) => const <Live>[]),
      );
      final rec = listen(
        repo.watchReceptions(targets).map((_) => const <Live>[]),
      );
      await pumpEventQueue();
      for (final name in ['performances', 'receptions']) {
        db.col(name).queries.first.fail();
      }
      await pumpEventQueue();
      for (final name in ['performances', 'receptions']) {
        expect(
          db.col(name).queries.map((q) => q.cancelled),
          everyElement(isTrue),
        );
      }
      expect(perf.errors, hasLength(1));
      expect(rec.errors, hasLength(1));
    });
  });

  group('購読の解除', () {
    test('購読をやめると、すべてのクエリの購読を解除する', () async {
      final sub = repo.watchLives(targets).listen((_) {});
      await pumpEventQueue();
      expect(queries(), hasLength(2));
      await sub.cancel();
      expect(queries().map((q) => q.cancelled), everyElement(isTrue));
    });
  });
}

// ---------------------------------------------------------------------------
// 偽物の Firestore（このテストで使う部分だけ）

class _Db implements FirebaseFirestore {
  final _cols = <String, _Col>{};

  _Col col(String path) => _cols.putIfAbsent(path, () => _Col(path));

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      col(path);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_Db: ${invocation.memberName}');
}

class _Col implements CollectionReference<Map<String, dynamic>> {
  _Col(this.path);

  @override
  final String path;

  final queries = <_Query>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) {
      final field = invocation.positionalArguments.first as String;
      final named = invocation.namedArguments;
      final values = named[#arrayContainsAny] ?? named[#isEqualTo];
      final q = _Query(field, values);
      queries.add(q);
      return q;
    }
    throw UnimplementedError('_Col: ${invocation.memberName}');
  }
}

class _Query implements Query<Map<String, dynamic>> {
  _Query(this.field, this.values);

  final String field;
  final Object? values;
  final _state = _QueryState();
  bool get listening => _state.listening;
  bool get cancelled => _state.cancelled;

  late final _controller =
      StreamController<QuerySnapshot<Map<String, dynamic>>>(
        onListen: () => _state.listening = true,
        onCancel: () => _state.cancelled = true,
      );

  void emit(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (!cancelled) _controller.add(_Snap(docs));
  }

  void fail() {
    if (!cancelled) {
      _controller.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
    }
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => _controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_Query: ${invocation.memberName}');
}

/// _Query は @immutable なので、変わる状態は別のオブジェクトに持つ
class _QueryState {
  bool listening = false;
  bool cancelled = false;
}

class _Snap implements QuerySnapshot<Map<String, dynamic>> {
  _Snap(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_Snap: ${invocation.memberName}');
}

QueryDocumentSnapshot<Map<String, dynamic>> _doc(
  String id, {
  List<String> groupIds = const [],
  List<String> oshiIds = const [],
}) =>
    _RawDoc(id, {'title': 'ライブ$id', 'groupIds': groupIds, 'oshiIds': oshiIds});

class _RawDoc implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _RawDoc(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic> data() => _data;

  @override
  bool get exists => true;

  @override
  DocumentReference<Map<String, dynamic>> get reference => _Ref('lives/$id');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_RawDoc: ${invocation.memberName}');
}

class _Ref implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.path);

  @override
  final String path;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_Ref: ${invocation.memberName}');
}
