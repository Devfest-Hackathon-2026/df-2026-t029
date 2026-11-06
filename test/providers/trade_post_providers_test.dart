// lib/providers/trade_post_providers.dart（G-2-3）のテスト。
// リポジトリは偽物に差し替える。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/models/trade_post.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/providers/trade_post_providers.dart';

import '../features/trade_test_helpers.dart';

TradePost _post(String id, {TradePostStatus status = TradePostStatus.open}) =>
    postOf(id, status: status);

class _Env {
  _Env({String? uid = 'u1'}) {
    container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue(uid),
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
    test('推しの種類と ID で購読し、届いた一覧をそのまま返す', () async {
      final env = _Env();
      final p = openTradePostsProvider((OshiKind.person, 'p1'));
      expect(env.read(p).isLoading, isTrue);
      expect(env.repo.watchedOpen, [(OshiKind.person, 'p1')]);

      env.repo.open.add([_post('a'), _post('b')]);
      await pumpEventQueue();
      expect(env.read(p).requireValue.map((p) => p.id), ['a', 'b']);
    });

    test('同じ推しなら同じプロバイダとして扱う', () {
      expect(
        openTradePostsProvider((OshiKind.group, 'g1')),
        openTradePostsProvider((OshiKind.group, 'g1')),
      );
    });

    test('未ログインなら空で、リポジトリを呼ばない', () async {
      final env = _Env(uid: null);
      final p = openTradePostsProvider((OshiKind.group, 'g1'));
      env.read(p);
      await pumpEventQueue();
      expect(env.read(p).requireValue, isEmpty);
      expect(env.repo.watchedOpen, isEmpty);
    });
  });

  test('myDisplayNameProvider：G-8 まで表示名は「匿名」', () {
    final env = _Env();
    expect(env.container.read(myDisplayNameProvider), '匿名');
  });
}
