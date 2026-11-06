// 投稿の詳細画面（/trade/:id。G-5-1）のウィジェットテスト
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/live/official_url_link.dart';
import 'package:oshiashi/features/trade/trade_post_detail_page.dart';
import 'package:oshiashi/models/live.dart';
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

/// fetch で例外を投げる偽物（非表示の投稿を他人が読んだときなど）
class _ThrowingRepo extends FakeTradePostRepository {
  _ThrowingRepo(this.e);
  final Object e;
  @override
  Future<TradePost?> fetch(String id) async => throw e;
}

TradePost fullPost({
  String uid = 'other',
  String? xAccount = 'oshi_fan',
  TradePostStatus status = TradePostStatus.open,
}) => TradePost(
  id: 'p1',
  uid: uid,
  displayName: '匿名',
  groupIds: const ['g1'],
  tags: const [TradeTag.trade, TradeTag.sell],
  priceType: PriceType.below,
  gives: const [
    GiveSet(
      items: [
        GiveItem(goodsId: 'a', variantId: 'v1', label: 'アクスタ（A）'),
        GiveItem(goodsId: 'a', variantId: 'v2', label: 'アクスタ（B）'),
      ],
      pickCount: 1,
      note: 'どれか1つ',
    ),
  ],
  wants: const [
    WantSet(
      targets: [
        WantTarget(type: WantType.goods, goodsId: 'b', label: 'タオル（全種類）'),
        WantTarget(type: WantType.member, oshiId: 'm1', label: 'メンバー1'),
      ],
    ),
  ],
  handover: const [HandoverMethod.mail, HandoverMethod.hand],
  performanceIds: const ['f1', 'unknown'],
  xAccount: xAccount,
  note: '送料はご負担ください',
  status: status,
  updatedAt: DateTime(2026, 11, 5, 12),
);

Future<List<Uri>> pumpDetail(
  WidgetTester tester,
  FakeTradePostRepository repo, {
  bool launchOk = true,
}) async {
  usePhoneSize(tester);
  final opened = <Uri>[];
  final router = GoRouter(
    initialLocation: '/trade/p1',
    routes: [
      GoRoute(
        path: '/trade/:id',
        builder: (_, s) => TradePostDetailPage(postId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trade/:id/edit',
        builder: (_, s) => Text('route:edit:${s.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        oshiRepositoryProvider.overrideWithValue(
          FakeOshiRepository([oshi('g1', 'グループ1')]),
        ),
        followRepositoryProvider.overrideWithValue(
          FakeFollowRepository(const FollowState(groupIds: {'g1'})),
        ),
        liveRepositoryProvider.overrideWithValue(
          FakeLiveRepository(
            lives: const [
              Live(id: 'l1', title: 'ツアー', groupIds: ['g1']),
            ],
            performances: [
              perfOf('f1', 'l1', DateTime(2026, 11, 20, 18)).copyWithIds(
                id: 'f1',
                liveId: 'l1',
                groupIds: ['g1'],
                oshiIds: [],
              ),
            ],
          ),
        ),
        nowProvider.overrideWithValue(DateTime(2026, 11, 5, 12)),
        tradePostRepositoryProvider.overrideWithValue(repo),
        urlLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return launchOk;
        }),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

Future<void> scrollTo(WidgetTester tester, Finder f) => tester
    .scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);

void main() {
  test('xProfileUri：正しいユーザー名だけを x.com のリンクにする', () {
    expect(xProfileUri('oshi_fan').toString(), 'https://x.com/oshi_fan');
    expect(xProfileUri(null), isNull);
    expect(xProfileUri('bad name'), isNull);
    expect(xProfileUri('a/../evil'), isNull);
  });

  testWidgets('投稿の内容をすべて出す', (tester) async {
    final repo = FakeTradePostRepository()..posts['p1'] = fullPost();
    await pumpDetail(tester, repo);

    expect(find.text('対象：グループ1'), findsOneWidget);
    expect(find.text('交換希望・譲渡（売ります）／価格：定価以下'), findsOneWidget);
    expect(find.text('譲セット1（この中から1個）'), findsOneWidget);
    expect(find.text('・アクスタ（A）'), findsOneWidget);
    expect(find.text('・アクスタ（B）'), findsOneWidget);
    expect(find.text('備考：どれか1つ'), findsOneWidget);
    expect(find.text('・タオル（全種類）'), findsOneWidget);
    expect(find.text('・メンバー1（メンバー指定）'), findsOneWidget);

    await scrollTo(tester, _key('trade_detail_note'));
    expect(find.text('郵送・手渡し'), findsOneWidget);
    expect(find.text('・ツアー 2026/11/20(金) 18:00 会場f1'), findsOneWidget);
    expect(find.text('・（公演の情報を表示できません）'), findsOneWidget);
    expect(find.text('送料はご負担ください'), findsOneWidget);
    // 他人の投稿なので編集ボタンはない
    expect(_key('trade_detail_edit'), findsNothing);
  });

  testWidgets('X のリンクを押すと x.com を開く。開けなければ伝える', (tester) async {
    final repo = FakeTradePostRepository()..posts['p1'] = fullPost();
    final opened = await pumpDetail(tester, repo, launchOk: false);
    await scrollTo(tester, _key('trade_detail_x'));
    expect(find.text('X：@oshi_fan'), findsOneWidget);
    await tester.tap(_key('trade_detail_x'));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse('https://x.com/oshi_fan')]);
    expect(find.text('X を開けませんでした'), findsOneWidget);
  });

  testWidgets('X がなければ、返信で連絡できると案内する', (tester) async {
    final repo = FakeTradePostRepository()
      ..posts['p1'] = fullPost(xAccount: null);
    await pumpDetail(tester, repo);
    await scrollTo(tester, _key('trade_detail_no_x'));
    expect(_key('trade_detail_no_x'), findsOneWidget);
  });

  testWidgets('自分の投稿なら編集ボタンを出し、編集画面へ行ける', (tester) async {
    final repo = FakeTradePostRepository()..posts['p1'] = fullPost(uid: 'u1');
    await pumpDetail(tester, repo);
    expect(find.text('自分'), findsOneWidget);
    await tester.tap(_key('trade_detail_edit'));
    await tester.pumpAndSettle();
    expect(find.text('route:edit:p1'), findsOneWidget);
  });

  testWidgets('募集終了なら目立たせる', (tester) async {
    final repo = FakeTradePostRepository()
      ..posts['p1'] = fullPost(status: TradePostStatus.closed);
    await pumpDetail(tester, repo);
    expect(find.text('この投稿は募集終了です'), findsOneWidget);
  });

  testWidgets('見つからない・読めない投稿はその旨を出す', (tester) async {
    await pumpDetail(tester, FakeTradePostRepository());
    expect(find.text('投稿が見つかりません'), findsOneWidget);
  });

  testWidgets('権限がない（非表示）ときは、表示できないと出す', (tester) async {
    await pumpDetail(
      tester,
      _ThrowingRepo(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
    );
    expect(find.textContaining('この投稿は表示できません'), findsOneWidget);
  });
}
