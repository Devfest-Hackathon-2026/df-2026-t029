// lib/utils/trade_board.dart（G-3-2・G-3-3）のテスト
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

  group('BoardFilter', () {
    TradePost p(
      String id, {
      List<GiveSet> gives = const [],
      List<WantSet> wants = const [],
      List<TradeTag> tags = const [TradeTag.trade],
      List<HandoverMethod> handover = const [HandoverMethod.mail],
      List<String> performanceIds = const [],
    }) => TradePost(
      id: id,
      tags: tags,
      gives: gives,
      wants: wants,
      handover: handover,
      performanceIds: performanceIds,
    );

    GiveSet giveOf(String goodsId) => GiveSet(
      items: [GiveItem(goodsId: goodsId, variantId: 'v1', label: goodsId)],
    );
    WantSet wantOf(WantTarget t) => WantSet(targets: [t]);

    final giveA = p('giveA', gives: [giveOf('a')]);
    final wantA = p(
      'wantA',
      wants: [
        wantOf(
          const WantTarget(type: WantType.goods, goodsId: 'a', label: 'A'),
        ),
      ],
    );
    final wantMember = p(
      'wantMember',
      wants: [
        wantOf(
          const WantTarget(type: WantType.member, oshiId: 'm', label: 'M'),
        ),
      ],
    );
    final giveB = p('giveB', gives: [giveOf('b')]);
    final textOnly = p('text');
    final all = [giveA, wantA, wantMember, giveB, textOnly];

    List<String?> filter(BoardFilter f) => [
      for (final x in all)
        if (f.matches(x)) x.id,
    ];

    test('条件なしなら全部', () {
      expect(BoardFilter.none.isEmpty, isTrue);
      expect(filter(BoardFilter.none), hasLength(5));
    });

    test('グッズだけなら、譲か求に含む投稿', () {
      expect(filter(const BoardFilter(goodsId: 'a')), ['giveA', 'wantA']);
    });

    test('グッズ＋譲／求で、どちらに含むかを絞る', () {
      expect(filter(const BoardFilter(goodsId: 'a', side: BoardSide.give)), [
        'giveA',
      ]);
      expect(filter(const BoardFilter(goodsId: 'a', side: BoardSide.want)), [
        'wantA',
      ]);
    });

    test('グッズなしの譲／求は、譲・求がある投稿', () {
      expect(filter(const BoardFilter(side: BoardSide.give)), [
        'giveA',
        'giveB',
      ]);
      expect(filter(const BoardFilter(side: BoardSide.want)), [
        'wantA',
        'wantMember',
      ]);
    });

    test('メンバー指定の求は、グッズの絞り込みでは引っかけない', () {
      final f = const BoardFilter(goodsId: 'm', side: BoardSide.want);
      expect(f.matches(wantMember), isFalse);
    });

    test('タグは、どれかを含む投稿', () {
      final sell = p('sell', tags: const [TradeTag.sell]);
      final buy = p('buy', tags: const [TradeTag.trade, TradeTag.buy]);
      final trade = p('trade');
      const f = BoardFilter(tags: {TradeTag.sell, TradeTag.buy});
      expect([sell, buy, trade].where(f.matches).map((x) => x.id), [
        'sell',
        'buy',
      ]);
    });

    test('公演は、手渡しでその公演を選んでいる投稿', () {
      final hand = p(
        'hand',
        handover: const [HandoverMethod.hand],
        performanceIds: const ['f1'],
      );
      final other = p(
        'other',
        handover: const [HandoverMethod.hand],
        performanceIds: const ['f2'],
      );
      const f = BoardFilter(performanceId: 'f1');
      expect([hand, other].where(f.matches).map((x) => x.id), ['hand']);
    });

    test('条件の数と、条件ごとの取り外し', () {
      const f = BoardFilter(
        goodsId: 'a',
        goodsName: 'A',
        side: BoardSide.give,
        tags: {TradeTag.trade},
        performanceId: 'f1',
        performanceLabel: '公演',
      );
      expect(f.count, 3);
      expect(f.withoutGoods().goodsId, isNull);
      expect(f.withoutGoods().side, BoardSide.any);
      expect(f.withoutGoods().count, 2);
      expect(f.withoutTags().tags, isEmpty);
      expect(f.withoutTags().goodsId, 'a');
      expect(f.withoutPerformance().performanceId, isNull);
      expect(f.withoutPerformance().tags, {TradeTag.trade});
    });
  });
}
