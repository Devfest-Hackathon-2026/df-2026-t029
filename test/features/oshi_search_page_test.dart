import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/oshi/oshi_search_page.dart';
import 'package:oshiashi/models/oshi.dart';

import 'oshi_test_helpers.dart';

final _g1 = oshi('g1', 'サンプルグループ');
final _p1 = oshi('p1', 'さんぷる太郎', kind: OshiKind.person, aliases: ['たろう']);
final _g2 = oshi('g2', '申請中ユニット', status: OshiStatus.pending);

Finder _key(String k) => find.byKey(Key(k));

void main() {
  group('4つの状態', () {
    testWidgets('読み込み中', (tester) async {
      await pumpPage(
        tester,
        const OshiSearchPage(),
        oshiRepo: FakeOshiRepository(),
        followRepo: FakeFollowRepository(),
        settle: false,
      );
      expect(_key('oshi_search_loading'), findsOneWidget);
    });

    testWidgets('エラー → もう一度読み込むで購読し直す', (tester) async {
      final repo = FakeOshiRepository([_g1])..fail = true;
      await pumpPage(
        tester,
        const OshiSearchPage(),
        oshiRepo: repo,
        followRepo: FakeFollowRepository(),
      );
      expect(_key('oshi_search_error'), findsOneWidget);
      expect(find.text('推しの一覧を読み込めませんでした'), findsOneWidget);

      final before = repo.watchCount;
      repo.fail = false;
      await tester.tap(_key('oshi_search_retry_button'));
      await tester.pumpAndSettle();
      expect(repo.watchCount, greaterThan(before));
      expect(_key('oshi_search_results'), findsOneWidget);
      expect(_key('oshi_tile_group_g1'), findsOneWidget);
    });

    testWidgets('0件: 検索語に合う推しが無いと、申請ボタンを出す', (tester) async {
      await pumpPage(
        tester,
        const OshiSearchPage(initialQuery: 'みつからない'),
        oshiRepo: FakeOshiRepository([_g1]),
        followRepo: FakeFollowRepository(),
      );
      expect(_key('oshi_search_empty'), findsOneWidget);
      expect(find.text('「みつからない」に合う推しは見つかりませんでした'), findsOneWidget);
      expect(_key('oshi_search_request_button'), findsOneWidget);
    });

    testWidgets('0件: 検索欄が空で、承認済みが1件も無い（申請中だけ）', (tester) async {
      await pumpPage(
        tester,
        const OshiSearchPage(),
        oshiRepo: FakeOshiRepository([_g2]),
        followRepo: FakeFollowRepository(),
      );
      expect(_key('oshi_search_empty'), findsOneWidget);
      expect(find.text('まだ公開されている推しがいません'), findsOneWidget);
    });

    testWidgets('結果あり: 検索欄が空なら承認済みだけ、末尾に申請の導線', (tester) async {
      await pumpPage(
        tester,
        const OshiSearchPage(),
        oshiRepo: FakeOshiRepository([_g1, _p1, _g2]),
        followRepo: FakeFollowRepository(),
      );
      expect(_key('oshi_search_results'), findsOneWidget);
      expect(_key('oshi_tile_group_g1'), findsOneWidget);
      expect(_key('oshi_tile_person_p1'), findsOneWidget);
      expect(_key('oshi_tile_group_g2'), findsNothing);
      expect(_key('oshi_search_footer_request_button'), findsOneWidget);
      expect(find.text('グループ'), findsOneWidget);
      expect(find.text('個人'), findsOneWidget);
    });
  });

  group('検索', () {
    testWidgets('入力に合わせて絞り込み、別名・ひらがなでも見つかる', (tester) async {
      final repo = FakeOshiRepository([_g1, _p1, _g2]);
      await pumpPage(
        tester,
        const OshiSearchPage(),
        oshiRepo: repo,
        followRepo: FakeFollowRepository(),
      );
      final watchCount = repo.watchCount;

      await tester.enterText(_key('oshi_search_field'), 'タロウ');
      await tester.pumpAndSettle();
      expect(_key('oshi_tile_person_p1'), findsOneWidget);
      expect(_key('oshi_tile_group_g1'), findsNothing);

      await tester.enterText(_key('oshi_search_field'), 'しんせい');
      await tester.pumpAndSettle();
      expect(_key('oshi_search_empty'), findsOneWidget);

      await tester.enterText(_key('oshi_search_field'), '申請中');
      await tester.pumpAndSettle();
      expect(_key('oshi_tile_group_g2'), findsOneWidget);

      // 検索のたびに Firestore を読み直さない
      expect(repo.watchCount, watchCount);
    });
  });

  group('申請中の推し', () {
    testWidgets('申請中バッジが出て、フォローボタンを押せない', (tester) async {
      await pumpPage(
        tester,
        const OshiSearchPage(initialQuery: '申請中'),
        oshiRepo: FakeOshiRepository([_g2]),
        followRepo: FakeFollowRepository(),
      );
      expect(_key('oshi_pending_badge_group_g2'), findsOneWidget);
      final button = _key('oshi_follow_button_group_g2');
      expect(onPressedOf(tester, button), isNull);
    });

    testWidgets('フォロー中の推しが申請中に戻されても、解除はできる', (tester) async {
      await pumpPage(
        tester,
        const OshiSearchPage(initialQuery: '申請中'),
        oshiRepo: FakeOshiRepository([_g2]),
        followRepo: FakeFollowRepository(const FollowState(groupIds: {'g2'})),
      );
      expect(
        onPressedOf(tester, _key('oshi_unfollow_button_group_g2')),
        isNotNull,
      );
    });
  });

  group('フォロー・解除', () {
    testWidgets('フォローすると「フォロー中」になり、解除すると戻る', (tester) async {
      final follow = FakeFollowRepository();
      await pumpPage(
        tester,
        const OshiSearchPage(),
        oshiRepo: FakeOshiRepository([_g1]),
        followRepo: follow,
      );
      await tester.tap(_key('oshi_follow_button_group_g1'));
      await tester.pumpAndSettle();
      expect(follow.followCalls, ['group/g1']);
      expect(_key('oshi_unfollow_button_group_g1'), findsOneWidget);

      await tester.tap(_key('oshi_unfollow_button_group_g1'));
      await tester.pumpAndSettle();
      expect(follow.unfollowCalls, ['group/g1']);
      expect(_key('oshi_follow_button_group_g1'), findsOneWidget);
    });

    testWidgets('処理中はボタンを押せず、連打しても1回しか呼ばない', (tester) async {
      final follow = FakeFollowRepository()..gate = Completer();
      await pumpPage(
        tester,
        const OshiSearchPage(),
        oshiRepo: FakeOshiRepository([_g1]),
        followRepo: follow,
      );
      final button = _key('oshi_follow_button_group_g1');
      await tester.tap(button);
      await tester.pump();
      expect(onPressedOf(tester, button), isNull);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();

      follow.gate!.complete();
      await tester.pumpAndSettle();
      expect(follow.followCalls, ['group/g1']);
    });

    testWidgets('回帰: 処理中に推しのデータが更新されても、ボタンは押せないまま', (tester) async {
      final repo = FakeOshiRepository([_g1]);
      final follow = FakeFollowRepository()..gate = Completer();
      await pumpPage(
        tester,
        const OshiSearchPage(),
        oshiRepo: repo,
        followRepo: follow,
      );
      final button = _key('oshi_follow_button_group_g1');
      await tester.tap(button);
      await tester.pump();

      // 同じ推しの中身（== は全項目比較）が変わった値が届く
      repo.emit([
        oshi('g1', 'サンプルグループ', aliases: ['さんぷる']),
      ]);
      await tester.pump();
      expect(onPressedOf(tester, button), isNull);
      await tester.tap(button, warnIfMissed: false);

      follow.gate!.complete();
      await tester.pumpAndSettle();
      expect(follow.followCalls, ['group/g1']);
    });

    testWidgets('フォロー状態を読み込むまではボタンを押せない', (tester) async {
      final follow = FakeFollowRepository()..emitInitial = false;
      await pumpPage(
        tester,
        const OshiSearchPage(),
        oshiRepo: FakeOshiRepository([_g1]),
        followRepo: follow,
      );
      expect(onPressedOf(tester, _key('oshi_follow_button_group_g1')), isNull);
    });

    testWidgets('失敗したら日本語の SnackBar を出し、ボタンを押せる状態に戻す', (tester) async {
      final follow = FakeFollowRepository()
        ..error = StateError('申請中の推しはフォローできません');
      await pumpPage(
        tester,
        const OshiSearchPage(),
        oshiRepo: FakeOshiRepository([_g1]),
        followRepo: follow,
      );
      await tester.tap(_key('oshi_follow_button_group_g1'));
      await tester.pumpAndSettle();
      expect(find.text('申請中の推しはフォローできません'), findsOneWidget);
      expect(
        onPressedOf(tester, _key('oshi_follow_button_group_g1')),
        isNotNull,
      );
    });

    testWidgets('想定外のエラーでも決まった日本語の文を出す', (tester) async {
      final follow = FakeFollowRepository()..error = Exception('network');
      await pumpPage(
        tester,
        const OshiSearchPage(),
        oshiRepo: FakeOshiRepository([_g1]),
        followRepo: follow,
      );
      await tester.tap(_key('oshi_follow_button_group_g1'));
      await tester.pumpAndSettle();
      expect(find.text('フォローできませんでした。もう一度お試しください'), findsOneWidget);
    });

    testWidgets('処理中に画面を閉じても例外にならない', (tester) async {
      final follow = FakeFollowRepository()..gate = Completer();
      await pumpPage(
        tester,
        const OshiSearchPage(),
        oshiRepo: FakeOshiRepository([_g1]),
        followRepo: follow,
      );
      await tester.tap(_key('oshi_follow_button_group_g1'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      follow.gate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('スマホの幅（360px）', () {
    testWidgets('長い名前・申請中バッジ・フォロー中でもはみ出さない', (tester) async {
      usePhoneSize(tester);
      final longName = '長い名前' * 12;
      await pumpPage(
        tester,
        const OshiSearchPage(initialQuery: '長い'),
        oshiRepo: FakeOshiRepository([
          oshi('a', longName),
          oshi('b', '${longName}B', status: OshiStatus.pending),
          oshi('c', '${longName}C', kind: OshiKind.person),
        ]),
        followRepo: FakeFollowRepository(const FollowState(oshiIds: {'c'})),
      );
      expect(tester.takeException(), isNull);
      expect(_key('oshi_search_results'), findsOneWidget);
    });

    testWidgets('0件の表示もはみ出さない', (tester) async {
      usePhoneSize(tester);
      await pumpPage(
        tester,
        OshiSearchPage(initialQuery: 'みつからない' * 10),
        oshiRepo: FakeOshiRepository([_g1]),
        followRepo: FakeFollowRepository(),
      );
      expect(tester.takeException(), isNull);
      expect(_key('oshi_search_empty'), findsOneWidget);
    });
  });
}
