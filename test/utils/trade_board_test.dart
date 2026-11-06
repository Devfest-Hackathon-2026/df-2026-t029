// lib/utils/trade_board.dart（G-3-2）のテスト
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/trade_post.dart';
import 'package:oshiashi/utils/trade_board.dart';

TradePost at(String id, int? day) => TradePost(
  id: id,
  tags: const [TradeTag.trade],
  handover: const [HandoverMethod.mail],
  updatedAt: day == null ? null : DateTime(2026, 11, day),
);

List<String?> ids(TradeBoard b) => [for (final p in b.posts) p.id];

void main() {
  test('まとめて新しい順に並べ、同じ投稿は1つにする', () {
    final b = mergeBoardPosts([
      [at('a', 3), at('c', 1)],
      [at('b', 2), at('c', 1)],
    ], 50);
    expect(ids(b), ['a', 'b', 'c']);
    expect(b.hasMore, isFalse);
  });

  test('保存中で日時がない投稿は先頭に置く', () {
    final b = mergeBoardPosts([
      [at('a', 3), at('pending', null)],
    ], 50);
    expect(ids(b), ['pending', 'a']);
  });

  test('まとめた結果が limit を超えたら切り、続きありとする', () {
    final b = mergeBoardPosts([
      [at('a', 3), at('c', 1)],
      [at('b', 2)],
    ], 2);
    expect(ids(b), ['a', 'b']);
    expect(b.hasMore, isTrue);
  });

  test('どれかの検索が limit 件ちょうどなら、続きありとする', () {
    final b = mergeBoardPosts([
      [at('a', 3), at('b', 2)],
      [],
    ], 2);
    expect(ids(b), ['a', 'b']);
    expect(b.hasMore, isTrue);
  });

  test('空なら空で、続きなし', () {
    final b = mergeBoardPosts([[], []], 50);
    expect(b.posts, isEmpty);
    expect(b.hasMore, isFalse);
  });
}
