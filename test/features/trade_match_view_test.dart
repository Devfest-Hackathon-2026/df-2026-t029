// マッチ（交換トップの「マッチ」タブ。G-4-3）のウィジェットテスト。
// 本物のプロバイダを使い、リポジトリだけを偽物に差し替える。
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/trade/trade_match_view.dart';
import 'package:oshiashi/models/goods.dart';
import 'package:oshiashi/models/trade_post.dart';
import 'package:oshiashi/providers/goods_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/providers/trade_post_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';
import 'package:oshiashi/utils/trade_keys.dart';

import 'oshi_test_helpers.dart';
import 'trade_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

const acsta = Goods(
  id: 'acsta',
  name: 'アクスタ',
  category: GoodsCategory.acrylic,
  variants: [
    GoodsVariant(id: 'vA', name: 'A'),
    GoodsVariant(id: 'vB', name: 'B'),
    GoodsVariant(id: 'vC', name: 'C'),
  ],
);

GiveItem item(String v) =>
    GiveItem(goodsId: 'acsta', variantId: v, label: 'アクスタ（$v）');
WantTarget want(String v) => WantTarget(
  type: WantType.item,
  goodsId: 'acsta',
  variantId: v,
  label: 'アクスタ（$v）',
);

TradePost post(
  String id, {
  required String uid,
  List<GiveItem> gives = const [],
  List<WantTarget> wants = const [],
  int day = 1,
}) {
  final g = gives.isEmpty ? <GiveSet>[] : [GiveSet(items: gives)];
  final w = wants.isEmpty ? <WantSet>[] : [WantSet(targets: wants)];
  return TradePost(
    id: id,
    uid: uid,
    displayName: '匿名',
    tags: const [TradeTag.trade],
    handover: const [HandoverMethod.mail],
    gives: g,
    wants: w,
    giveKeys: buildGiveKeys(g, {'acsta': acsta}),
    wantKeys: buildWantKeys(w),
    updatedAt: DateTime(2026, 11, day),
  );
}

Future<void> pumpMatch(
  WidgetTester tester,
  FakeTradePostRepository repo,
) async {
  usePhoneSize(tester);
  addTearDown(repo.mine.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('me'),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        tradePostRepositoryProvider.overrideWithValue(repo),
        goodsRepositoryProvider.overrideWithValue(
          FakeGoodsRepository(const [acsta]),
        ),
      ],
      retry: (_, _) => null,
      child: const MaterialApp(home: Scaffold(body: TradeMatchView())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // 自分：A を出して C が欲しい
  final mine = post(
    'mine',
    uid: 'me',
    gives: [item('vA')],
    wants: [want('vC')],
  );

  testWidgets('求のある募集中の投稿がなければ、案内を出す', (tester) async {
    final repo = FakeTradePostRepository()
      ..mineInitial = [
        post('mine', uid: 'me', gives: [item('vA')]),
      ];
    await pumpMatch(tester, repo);
    expect(_key('trade_match_no_wants'), findsOneWidget);
    expect(repo.givingQueries, isEmpty);
  });

  testWidgets('相互マッチ → 片方マッチの順に、一致した品目を出す', (tester) async {
    final repo = FakeTradePostRepository()
      ..mineInitial = [mine]
      ..allPosts = [
        post('oneSided', uid: 'x', gives: [item('vC')], day: 5),
        post(
          'mutual',
          uid: 'y',
          gives: [item('vC'), item('vB')],
          wants: [want('vA')],
          day: 1,
        ),
      ];
    await pumpMatch(tester, repo);

    expect(find.text('相互マッチ（1件）'), findsOneWidget);
    expect(find.text('片方マッチ（1件）'), findsOneWidget);
    final cards = [
      for (final c in tester.widgetList<Card>(find.byType(Card)))
        (c.key as ValueKey<String>).value,
    ];
    expect(cards, ['trade_match_mutual', 'trade_match_oneSided']);

    // 相互マッチ：もらえるもの（C だけ。B は求めていない）と出せるもの
    final mutual = find.descendant(
      of: _key('trade_match_mutual'),
      matching: find.byType(Text),
    );
    final texts = [for (final t in tester.widgetList<Text>(mutual)) t.data];
    expect(texts, contains('もらえるもの：アクスタ（vC）'));
    expect(texts, contains('出せるもの：アクスタ（vA）'));
    expect(texts, contains('相互'));

    // 片方マッチには「出せるもの」を出さない
    final one = find.descendant(
      of: _key('trade_match_oneSided'),
      matching: find.textContaining('出せるもの'),
    );
    expect(one, findsNothing);
  });

  testWidgets('マッチがなければその旨を出す', (tester) async {
    final repo = FakeTradePostRepository()
      ..mineInitial = [mine]
      ..allPosts = [
        post('other', uid: 'x', gives: [item('vB')]),
      ];
    await pumpMatch(tester, repo);
    expect(_key('trade_match_empty'), findsOneWidget);
  });

  testWidgets('自分の投稿が複数合うときは、件数を添える', (tester) async {
    final repo = FakeTradePostRepository()
      ..mineInitial = [
        mine,
        post('mine2', uid: 'me', wants: [want('vC')]),
      ]
      ..allPosts = [
        post('theirs', uid: 'x', gives: [item('vC')]),
      ];
    await pumpMatch(tester, repo);
    expect(find.text('合うあなたの投稿：2件'), findsOneWidget);
  });

  testWidgets('「更新」で検索し直し、新しい投稿を拾う', (tester) async {
    final repo = FakeTradePostRepository()
      ..mineInitial = [mine]
      ..allPosts = [];
    await pumpMatch(tester, repo);
    expect(_key('trade_match_empty'), findsOneWidget);
    expect(repo.givingQueries, hasLength(1));

    repo.allPosts = [
      post('new', uid: 'x', gives: [item('vC')]),
    ];
    await tester.tap(_key('trade_match_refresh'));
    await tester.pumpAndSettle();
    expect(repo.givingQueries, hasLength(2));
    expect(_key('trade_match_new'), findsOneWidget);
  });

  testWidgets('下に引っ張っても検索し直す', (tester) async {
    final repo = FakeTradePostRepository()
      ..mineInitial = [mine]
      ..allPosts = [];
    await pumpMatch(tester, repo);
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(repo.givingQueries, hasLength(2));
  });
}
