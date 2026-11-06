// 交換の掲示板（/trade/board。G-3-2）のウィジェットテスト。
// 本物のプロバイダを使い、リポジトリだけを偽物に差し替える。
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/trade/trade_board_page.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/models/trade_post.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/providers/trade_post_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';

import 'live_test_helpers.dart';
import 'oshi_test_helpers.dart';
import 'trade_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

final oshis = [
  oshi('g1', 'グループ1'),
  const OshiSummary(
    id: 'p1',
    kind: OshiKind.person,
    name: '個人1',
    genre: OshiGenre.idol,
    status: OshiStatus.approved,
    groupIds: ['g1'],
  ),
];

FakeFollowRepository following() =>
    FakeFollowRepository(const FollowState(groupIds: {'g1'}, oshiIds: {'p1'}));

TradePost post(
  String id,
  int day, {
  String uid = 'other',
  List<String> groupIds = const ['g1'],
  List<String> oshiIds = const [],
  List<TradeTag> tags = const [TradeTag.trade],
  PriceType? priceType,
  List<GiveSet> gives = const [],
}) => TradePost(
  id: id,
  uid: uid,
  displayName: '匿名',
  groupIds: groupIds,
  oshiIds: oshiIds,
  tags: tags,
  priceType: priceType,
  gives: gives,
  handover: const [HandoverMethod.mail, HandoverMethod.hand],
  updatedAt: DateTime(2026, 11, day),
);

Future<void> pumpBoard(
  WidgetTester tester,
  FakeTradePostRepository repo,
) async {
  usePhoneSize(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        oshiRepositoryProvider.overrideWithValue(FakeOshiRepository(oshis)),
        followRepositoryProvider.overrideWithValue(following()),
        liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
        nowProvider.overrideWithValue(DateTime(2026, 11, 5, 12)),
        tradePostRepositoryProvider.overrideWithValue(repo),
      ],
      retry: (_, _) => null,
      child: const MaterialApp(home: TradeBoardPage()),
    ),
  );
  await tester.pumpAndSettle();
}

/// 推しを選ぶ。読み込み中のまま止まる場合は [settle] を false にする
/// （読み込み中の表示は動き続けるため、pumpAndSettle が終わらない）
Future<void> selectOshi(
  WidgetTester tester,
  String label, {
  bool settle = true,
}) async {
  await tester.tap(_key('trade_board_oshi'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('推しを選ぶまでは案内を出す', (tester) async {
    await pumpBoard(tester, FakeTradePostRepository());
    expect(find.text('推しを選んでください'), findsOneWidget);
  });

  testWidgets('推しを選ぶと、募集中の投稿を新しい順に出す', (tester) async {
    final repo = FakeTradePostRepository()
      ..openByTarget = {
        (OshiKind.group, 'g1'): [
          post(
            'new',
            3,
            tags: const [TradeTag.trade, TradeTag.sell],
            priceType: PriceType.face,
            gives: const [
              GiveSet(
                items: [GiveItem(goodsId: 'a', variantId: 'v1', label: 'アクスタ')],
              ),
            ],
          ),
          post('mine', 2, uid: 'u1'),
        ],
      };
    await pumpBoard(tester, repo);
    await selectOshi(tester, 'グループ1（グループ）');

    final cards = tester
        .widgetList<Card>(find.byType(Card))
        .map((c) => (c.key as ValueKey<String>).value)
        .toList();
    expect(cards, ['trade_board_post_new', 'trade_board_post_mine']);
    expect(find.text('交換希望・譲渡（売ります）／価格：定価'), findsOneWidget);
    expect(find.text('譲：アクスタ'), findsOneWidget);
    expect(find.text('受け渡し：郵送・手渡し'), findsNWidgets(2));
    // 自分の投稿には印を付ける
    expect(find.text('自分'), findsOneWidget);
  });

  testWidgets('個人を選ぶと、所属グループの投稿もまとめて出す', (tester) async {
    final repo = FakeTradePostRepository()
      ..openByTarget = {
        (OshiKind.person, 'p1'): [
          post('solo', 1, groupIds: const [], oshiIds: const ['p1']),
        ],
        (OshiKind.group, 'g1'): [post('group', 2)],
      };
    await pumpBoard(tester, repo);
    await selectOshi(tester, '個人1（個人）');

    expect(_key('trade_board_post_group'), findsOneWidget);
    expect(_key('trade_board_post_solo'), findsOneWidget);
  });

  testWidgets('投稿がなければその旨を出す', (tester) async {
    final repo = FakeTradePostRepository()..openByTarget = {};
    await pumpBoard(tester, repo);
    await selectOshi(tester, 'グループ1（グループ）');
    expect(find.text('募集中の投稿はまだありません'), findsOneWidget);
  });

  testWidgets('50件を超えると「もっと見る」で続きを読む', (tester) async {
    final repo = FakeTradePostRepository()
      ..openByTarget = {
        (OshiKind.group, 'g1'): [
          for (var i = 0; i < 60; i++)
            post(
              'p$i',
              1,
            ).copyForTest(updatedAt: DateTime(2026, 11, 1, 0, 60 - i)),
        ],
      };
    await pumpBoard(tester, repo);
    await selectOshi(tester, 'グループ1（グループ）');
    expect(repo.watchedOpen.last, (OshiKind.group, 'g1', 50));

    await tester.scrollUntilVisible(
      _key('trade_board_more'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(_key('trade_board_more'));
    await tester.pumpAndSettle();
    expect(repo.watchedOpen.last, (OshiKind.group, 'g1', 100));

    await tester.scrollUntilVisible(
      _key('trade_board_post_p59'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    expect(_key('trade_board_more'), findsNothing);
  });

  testWidgets('読み込めなかったらエラーを出す', (tester) async {
    final repo = FakeTradePostRepository();
    await pumpBoard(tester, repo);
    await selectOshi(tester, 'グループ1（グループ）', settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repo.open.addError(permissionDenied());
    await tester.pumpAndSettle();
    expect(find.textContaining('投稿を読み込めませんでした'), findsOneWidget);
  });
}

extension on TradePost {
  TradePost copyForTest({required DateTime updatedAt}) => TradePost(
    id: id,
    uid: uid,
    displayName: displayName,
    groupIds: groupIds,
    tags: tags,
    handover: handover,
    updatedAt: updatedAt,
  );
}
