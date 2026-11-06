import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/home/home_page.dart';
import 'package:oshiashi/models/oshi.dart';

import 'oshi_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

void main() {
  testWidgets('読み込み中', (tester) async {
    await pumpPage(
      tester,
      const HomePage(),
      oshiRepo: FakeOshiRepository(),
      followRepo: FakeFollowRepository(),
      settle: false,
    );
    expect(_key('home_following_loading'), findsOneWidget);
    expect(_key('home_search_button'), findsOneWidget);
  });

  testWidgets('ライブを追加するボタンは右下の1つだけ', (tester) async {
    await pumpPage(
      tester,
      const HomePage(),
      oshiRepo: FakeOshiRepository(),
      followRepo: FakeFollowRepository(),
      settle: false,
    );
    expect(_key('home_add_live_fab'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('ライブを追加する'), findsOneWidget);
    expect(find.text('スクショから登録'), findsNothing);
    expect(_key('home_live_list_button'), findsOneWidget);
  });

  testWidgets('0件: フォローしていない', (tester) async {
    await pumpPage(
      tester,
      const HomePage(),
      oshiRepo: FakeOshiRepository([oshi('g1', 'A')]),
      followRepo: FakeFollowRepository(),
    );
    expect(_key('home_following_empty'), findsOneWidget);
  });

  testWidgets('エラー → もう一度読み込む', (tester) async {
    final repo = FakeOshiRepository([oshi('g1', 'A')])..fail = true;
    await pumpPage(
      tester,
      const HomePage(),
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
    await pumpPage(
      tester,
      const HomePage(),
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
    await pumpPage(
      tester,
      const HomePage(),
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
    await pumpPage(
      tester,
      const HomePage(),
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
    await pumpPage(
      tester,
      const HomePage(),
      oshiRepo: FakeOshiRepository(list),
      followRepo: FakeFollowRepository(
        FollowState(groupIds: {for (final o in list) o.id}),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(_key('home_following_list'), findsOneWidget);
  });
}
