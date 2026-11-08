import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/oshi/oshi_page.dart';
import 'package:oshiashi/models/oshi.dart';

import 'oshi_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

/// 推しの画面（タブの「推し」。ホームから移したフォロー中の一覧）のテスト。
/// 縦に長い一覧まで描画される高さにする（ListView は画面外の項目を作らないため）
void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('読み込み中', (tester) async {
    _useTallScreen(tester);
    await pumpPage(
      tester,
      const OshiPage(),
      oshiRepo: FakeOshiRepository(),
      followRepo: FakeFollowRepository(),
      settle: false,
    );
    expect(_key('home_following_loading'), findsOneWidget);
    expect(_key('oshi_search_button'), findsOneWidget);
  });

  testWidgets('0件: フォローしていない', (tester) async {
    _useTallScreen(tester);
    await pumpPage(
      tester,
      const OshiPage(),
      oshiRepo: FakeOshiRepository([oshi('g1', 'A')]),
      followRepo: FakeFollowRepository(),
    );
    expect(_key('home_following_empty'), findsOneWidget);
  });

  testWidgets('エラー → もう一度読み込む', (tester) async {
    final repo = FakeOshiRepository([oshi('g1', 'A')])..fail = true;
    _useTallScreen(tester);
    await pumpPage(
      tester,
      const OshiPage(),
      oshiRepo: repo,
      followRepo: FakeFollowRepository(const FollowState(groupIds: {'g1'})),
    );
    expect(_key('home_following_error'), findsOneWidget);

    repo.fail = false;
    await tester.tap(_key('home_following_retry_button'));
    await tester.pumpAndSettle();
    expect(_key('home_following_list'), findsOneWidget);
    expect(_key('oshi_tile_group_g1'), findsOneWidget);
  });

  testWidgets('フォロー中の承認済みだけを出し、解除すると0件になる', (tester) async {
    final follow = FakeFollowRepository(
      const FollowState(groupIds: {'g1', 'g2', 'gone'}),
    );
    _useTallScreen(tester);
    await pumpPage(
      tester,
      const OshiPage(),
      oshiRepo: FakeOshiRepository([
        oshi('g1', 'A'),
        oshi('g2', '申請中', status: OshiStatus.pending),
        oshi('g3', 'フォローしていない'),
      ]),
      followRepo: follow,
    );
    expect(_key('home_following_list'), findsOneWidget);
    expect(_key('oshi_tile_group_g1'), findsOneWidget);
    expect(_key('oshi_tile_group_g2'), findsNothing);
    expect(_key('oshi_tile_group_g3'), findsNothing);

    await tester.tap(_key('oshi_unfollow_button_group_g1'));
    await tester.pumpAndSettle();
    expect(follow.unfollowCalls, ['group/g1']);
    expect(_key('home_following_empty'), findsOneWidget);
  });

  testWidgets('解除の処理中はボタンを押せず、連打しても1回だけ', (tester) async {
    final follow = FakeFollowRepository(const FollowState(groupIds: {'g1'}))
      ..gate = Completer();
    _useTallScreen(tester);
    await pumpPage(
      tester,
      const OshiPage(),
      oshiRepo: FakeOshiRepository([oshi('g1', 'A')]),
      followRepo: follow,
    );
    final button = _key('oshi_unfollow_button_group_g1');
    await tester.tap(button);
    await tester.pump();
    expect(onPressedOf(tester, button), isNull);
    await tester.tap(button, warnIfMissed: false);
    follow.gate!.complete();
    await tester.pumpAndSettle();
    expect(follow.unfollowCalls, ['group/g1']);
  });

  testWidgets('解除に失敗したら SnackBar を出す', (tester) async {
    final follow = FakeFollowRepository(const FollowState(groupIds: {'g1'}))
      ..error = Exception('network');
    _useTallScreen(tester);
    await pumpPage(
      tester,
      const OshiPage(),
      oshiRepo: FakeOshiRepository([oshi('g1', 'A')]),
      followRepo: follow,
    );
    await tester.tap(_key('oshi_unfollow_button_group_g1'));
    await tester.pumpAndSettle();
    expect(find.text('フォローを解除できませんでした。もう一度お試しください'), findsOneWidget);
    expect(_key('oshi_tile_group_g1'), findsOneWidget);
  });

  testWidgets('360px 幅で、長い名前が多数あってもはみ出さない', (tester) async {
    usePhoneSize(tester);
    final list = [
      for (var i = 0; i < 20; i++) oshi('g$i', '${'とても長いグループの名前' * 4}$i'),
    ];
    _useTallScreen(tester);
    await pumpPage(
      tester,
      const OshiPage(),
      oshiRepo: FakeOshiRepository(list),
      followRepo: FakeFollowRepository(
        FollowState(groupIds: {for (final o in list) o.id}),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(_key('home_following_list'), findsOneWidget);
  });

  for (final w in layoutWidths) {
    testWidgets('幅 ${w.toInt()}・長い名前でもはみ出さない', (tester) async {
      tester.view.physicalSize = Size(w, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpPage(
        tester,
        const OshiPage(),
        oshiRepo: FakeOshiRepository([
          oshi('g1', 'とても長いグループの名前' * 5),
          oshi('g2', 'B'),
        ]),
        followRepo: FakeFollowRepository(
          const FollowState(groupIds: {'g1', 'g2'}),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  group('補足（電球の行）', () {
    testWidgets('「フォロー中の推し」の補足は、いつも出る。最推しがいなければ最推しの補足は出ない', (tester) async {
      _useTallScreen(tester);
      await pumpPage(
        tester,
        const OshiPage(),
        oshiRepo: FakeOshiRepository([oshi('g1', 'A')]),
        followRepo: FakeFollowRepository(const FollowState(groupIds: {'g1'})),
      );
      expect(_key('hint_oshi_following'), findsOneWidget);
      expect(find.text('フォローすると、予定がホームとライブ一覧に届きます。'), findsOneWidget);
      expect(_key('hint_oshi_favorite'), findsNothing);
    });

    testWidgets('フォロー中が0件でも「フォロー中の推し」の補足は出る', (tester) async {
      _useTallScreen(tester);
      await pumpPage(
        tester,
        const OshiPage(),
        oshiRepo: FakeOshiRepository([oshi('g1', 'A')]),
        followRepo: FakeFollowRepository(),
      );
      expect(_key('hint_oshi_following'), findsOneWidget);
      expect(_key('hint_oshi_favorite'), findsNothing);
    });

    testWidgets('最推しがいるときだけ、最推しの補足が出る', (tester) async {
      _useTallScreen(tester);
      await pumpPage(
        tester,
        const OshiPage(),
        oshiRepo: FakeOshiRepository([oshi('g1', 'A')]),
        followRepo: FakeFollowRepository(const FollowState(groupIds: {'g1'})),
        favoriteKey: 'group/g1',
      );
      expect(_key('hint_oshi_favorite'), findsOneWidget);
      expect(find.text('いちばん応援している推しです。'), findsOneWidget);
      expect(_key('hint_oshi_following'), findsOneWidget);
    });

    testWidgets('最推しの補足は「最推し」の見出しの下、フォロー中の補足は「フォロー中の推し」の見出しの下', (tester) async {
      _useTallScreen(tester);
      await pumpPage(
        tester,
        const OshiPage(),
        oshiRepo: FakeOshiRepository([oshi('g1', 'A')]),
        followRepo: FakeFollowRepository(const FollowState(groupIds: {'g1'})),
        favoriteKey: 'group/g1',
      );
      double y(Finder f) => tester.getTopLeft(f).dy;
      expect(y(find.text('最推し')), lessThan(y(_key('hint_oshi_favorite'))));
      expect(
        y(find.text('フォロー中の推し')),
        lessThan(y(_key('hint_oshi_following'))),
      );
      expect(y(_key('hint_oshi_favorite')), lessThan(y(find.text('フォロー中の推し'))));
    });
  });
}
