// lib/providers/trade_post_providers.dart（G-2-3）のテスト。
// リポジトリは偽物に差し替える。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/models/trade_post.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/providers/trade_post_providers.dart';

import '../features/oshi_test_helpers.dart' show permissionDenied;
import '../features/trade_test_helpers.dart';

const p1 = OshiSummary(
  id: 'p1',
  kind: OshiKind.person,
  name: '個人1',
  genre: OshiGenre.idol,
  status: OshiStatus.approved,
  groupIds: ['g1', 'g2'],
);

TradePost _post(String id, {TradePostStatus status = TradePostStatus.open}) =>
    postOf(id, status: status);

class _Env {
  _Env({String? uid = 'u1', List<OshiSummary> oshis = const []}) {
    container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue(uid),
        allOshisProvider.overrideWith((ref) => Stream.value(oshis)),
        tradePostRepositoryProvider.overrideWithValue(repo),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    addTearDown(repo.mine.close);
    addTearDown(repo.open.close);
  }

  final repo = FakeTradePostRepository();
  late final ProviderContainer container;

  /// 購読者がいないプロバイダは止まるので、先に listen してから読む
  T read<T>(ProviderListenable<T> p) {
    container.listen(p, (_, _) {});
    return container.read(p);
  }
}

void main() {
  group('myTradePostsProvider', () {
    test('ログイン中のユーザーの uid で購読し、届いた一覧をそのまま返す', () async {
      final env = _Env();
      expect(env.read(myTradePostsProvider).isLoading, isTrue);
      expect(env.repo.watchedUids, ['u1']);

      final closed = _post('p2', status: TradePostStatus.closed);
      env.repo.mine.add([_post('p1'), closed]);
      await pumpEventQueue();

      final posts = env.read(myTradePostsProvider).requireValue;
      expect(posts.map((p) => p.id), ['p1', 'p2']);
      expect(posts[1].status, TradePostStatus.closed);
    });

    test('未ログインなら空で、リポジトリを呼ばない', () async {
      final env = _Env(uid: null);
      env.read(myTradePostsProvider);
      await pumpEventQueue();

      expect(env.read(myTradePostsProvider).requireValue, isEmpty);
      expect(env.repo.watchedUids, isEmpty);
    });

    test('購読でエラーが起きたらエラーを返す', () async {
      final env = _Env();
      env.read(myTradePostsProvider);
      env.repo.mine.addError(Exception('失敗'));
      await pumpEventQueue();

      expect(env.read(myTradePostsProvider).hasError, isTrue);
    });
  });

  group('tradePostByIdProvider', () {
    test('ID で取得した投稿を返す', () async {
      final env = _Env();
      env.repo.posts['p1'] = _post('p1');

      final post = await env.container.read(tradePostByIdProvider('p1').future);
      expect(post?.id, 'p1');
    });

    test('見つからなければ null', () async {
      final env = _Env();
      final post = await env.container.read(
        tradePostByIdProvider('none').future,
      );
      expect(post, isNull);
    });

    test('invalidate すると読み直す', () async {
      final env = _Env();
      env.repo.posts['p1'] = _post('p1');
      env.read(tradePostByIdProvider('p1'));
      await env.container.read(tradePostByIdProvider('p1').future);

      env.repo.posts['p1'] = _post('p1', status: TradePostStatus.closed);
      env.container.invalidate(tradePostByIdProvider('p1'));
      final post = await env.container.read(tradePostByIdProvider('p1').future);

      expect(post?.status, TradePostStatus.closed);
      expect(env.repo.fetchCount, 2);
    });
  });

  group('openTradePostsProvider', () {
    test('推しの種類・ID・件数で購読し、届いた一覧をそのまま返す', () async {
      final env = _Env();
      final p = openTradePostsProvider((
        kind: OshiKind.person,
        id: 'p1',
        limit: 50,
      ));
      expect(env.read(p).isLoading, isTrue);
      expect(env.repo.watchedOpen, [(OshiKind.person, 'p1', 50)]);

      env.repo.open.add([_post('a'), _post('b')]);
      await pumpEventQueue();
      expect(env.read(p).requireValue.map((p) => p.id), ['a', 'b']);
    });

    test('未ログインなら空で、リポジトリを呼ばない', () async {
      final env = _Env(uid: null);
      final p = openTradePostsProvider((
        kind: OshiKind.group,
        id: 'g1',
        limit: 50,
      ));
      env.read(p);
      await pumpEventQueue();
      expect(env.read(p).requireValue, isEmpty);
      expect(env.repo.watchedOpen, isEmpty);
    });
  });

  group('tradeBoardProvider', () {
    TradePost at(String id, int day) => TradePost(
      id: id,
      groupIds: const ['g1'],
      tags: const [TradeTag.trade],
      handover: const [HandoverMethod.mail],
      updatedAt: DateTime(2026, 11, day),
    );

    test('グループなら、そのグループの投稿だけ', () async {
      final env = _Env(oshis: [p1]);
      env.repo.openByTarget = {
        (OshiKind.group, 'g1'): [at('a', 2), at('b', 1)],
      };
      final p = tradeBoardProvider((kind: OshiKind.group, id: 'g1', limit: 50));
      env.read(p);
      await pumpEventQueue();
      final board = env.read(p).requireValue;
      expect(board.posts.map((p) => p.id), ['a', 'b']);
      expect(board.hasMore, isFalse);
      expect(env.repo.watchedOpen, [(OshiKind.group, 'g1', 50)]);
    });

    test('個人なら、所属グループの投稿もまとめて新しい順に出す', () async {
      final env = _Env(oshis: [p1]);
      env.repo.openByTarget = {
        (OshiKind.person, 'p1'): [at('solo', 3), at('both', 1)],
        (OshiKind.group, 'g1'): [at('group', 2), at('both', 1)],
        (OshiKind.group, 'g2'): [at('g2', 4)],
      };
      final p = tradeBoardProvider((
        kind: OshiKind.person,
        id: 'p1',
        limit: 50,
      ));
      env.read(p);
      await pumpEventQueue();
      expect(env.read(p).requireValue.posts.map((p) => p.id), [
        'g2',
        'solo',
        'group',
        'both',
      ]);
    });

    test('limit 件で切り、続きがあれば hasMore', () async {
      final env = _Env(oshis: [p1]);
      env.repo.openByTarget = {
        (OshiKind.group, 'g1'): [at('a', 3), at('b', 2), at('c', 1)],
      };
      final p = tradeBoardProvider((kind: OshiKind.group, id: 'g1', limit: 2));
      env.read(p);
      await pumpEventQueue();
      final board = env.read(p).requireValue;
      expect(board.posts.map((p) => p.id), ['a', 'b']);
      expect(board.hasMore, isTrue);
    });

    test('どれかの検索がエラーなら、エラー', () async {
      final env = _Env(oshis: [p1]);
      final p = tradeBoardProvider((
        kind: OshiKind.person,
        id: 'p1',
        limit: 50,
      ));
      env.read(p);
      await pumpEventQueue();
      expect(env.read(p).isLoading, isTrue);
      env.repo.open.addError(permissionDenied());
      await pumpEventQueue();
      expect(env.read(p).hasError, isTrue);
    });
  });

  test('boardTargetProvider：選んだ推しを覚える', () {
    final env = _Env();
    expect(env.container.read(boardTargetProvider), isNull);
    env.container.read(boardTargetProvider.notifier).select(p1);
    expect(env.container.read(boardTargetProvider), p1);
  });

  group('matchCandidatesProvider', () {
    TradePost mine(
      String id, {
      List<String> wantKeys = const [],
      TradePostStatus status = TradePostStatus.open,
    }) => TradePost(
      id: id,
      uid: 'u1',
      tags: const [TradeTag.trade],
      handover: const [HandoverMethod.mail],
      wantKeys: wantKeys,
      status: status,
    );
    TradePost theirs(
      String id, {
      String uid = 'u2',
      List<String> giveKeys = const [],
    }) => TradePost(
      id: id,
      uid: uid,
      tags: const [TradeTag.trade],
      handover: const [HandoverMethod.mail],
      giveKeys: giveKeys,
    );

    // 購読者がいないプロバイダは止まるため、どのテストも先に env.read で購読する
    test('自分の募集中の投稿の求のキーで探し、自分の投稿は除く', () async {
      final env = _Env();
      env.repo.mineInitial = [
        mine('m1', wantKeys: ['goods:x', 'member:a']),
        mine('m2', wantKeys: ['goods:x', 'item:y#v1']),
        mine('closed', wantKeys: ['goods:z'], status: TradePostStatus.closed),
      ];
      env.repo.allPosts = [
        theirs('t1', giveKeys: ['goods:x']),
        theirs('t2', giveKeys: ['goods:z']),
        theirs('own', uid: 'u1', giveKeys: ['goods:x']),
      ];
      env.read(matchCandidatesProvider);
      final posts = await env.container.read(matchCandidatesProvider.future);
      expect(posts.map((p) => p.id), ['t1']);
      expect(env.repo.givingQueries.single, [
        'goods:x',
        'item:y#v1',
        'member:a',
      ]);
    });

    test('自分の求がなければ、検索しないで空', () async {
      final env = _Env();
      env.repo.mineInitial = [mine('m1')];
      env.read(matchCandidatesProvider);
      expect(await env.container.read(matchCandidatesProvider.future), isEmpty);
      expect(env.repo.givingQueries, isEmpty);
    });

    test('求のキーが変わったときだけ検索し直す', () async {
      final env = _Env();
      env.repo.mineInitial = [
        mine('m1', wantKeys: ['goods:x']),
      ];
      env.read(matchCandidatesProvider);
      await env.container.read(matchCandidatesProvider.future);
      expect(env.repo.givingQueries, hasLength(1));

      // キーが同じ更新（備考を変えたなど）では検索しない
      env.repo.mine.add([
        mine('m1', wantKeys: ['goods:x']),
      ]);
      await pumpEventQueue();
      await env.container.read(matchCandidatesProvider.future);
      expect(env.repo.givingQueries, hasLength(1));

      env.repo.mine.add([
        mine('m1', wantKeys: ['goods:x', 'goods:w']),
      ]);
      await pumpEventQueue();
      await env.container.read(matchCandidatesProvider.future);
      expect(env.repo.givingQueries, hasLength(2));
      expect(env.repo.givingQueries.last, ['goods:w', 'goods:x']);
    });

    test('未ログインなら空', () async {
      final env = _Env(uid: null);
      env.read(matchCandidatesProvider);
      expect(await env.container.read(matchCandidatesProvider.future), isEmpty);
    });
  });

  test('myDisplayNameProvider：G-8 まで表示名は「匿名」', () {
    final env = _Env();
    expect(env.container.read(myDisplayNameProvider), '匿名');
  });
}
