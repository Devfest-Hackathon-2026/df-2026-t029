import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/oshi/oshi_request_page.dart';
import 'package:oshiashi/models/oshi.dart';

import 'oshi_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

final _existing = [
  oshi('g1', 'サンプルグループ'),
  oshi('g2', '申請中ユニット', status: OshiStatus.pending),
  oshi('p1', 'さんぷる太郎', kind: OshiKind.person, aliases: ['たろう']),
];

/// 申請画面を GoRouter の中で開く（成功時の context.go を確かめるため）
Future<void> _pumpRequest(
  WidgetTester tester, {
  required FakeOshiRepository repo,
  String name = '',
}) async {
  final router = GoRouter(
    initialLocation: Uri(
      path: '/oshi/request',
      queryParameters: name.isEmpty ? null : {'name': name},
    ).toString(),
    routes: [
      GoRoute(
        path: '/oshi/request',
        builder: (context, state) => OshiRequestPage(
          initialName: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      GoRoute(
        path: '/oshi/search',
        builder: (context, state) => Scaffold(
          body: Text(
            'search:${state.uri.queryParameters['q']}',
            key: const Key('fake_search_page'),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overridesFor(repo, FakeFollowRepository()),
      retry: (_, _) => null,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(_key(key), 200, scrollable: listScrollable());
  await tester.pumpAndSettle();
}

Future<void> _selectGenre(WidgetTester tester, String label) async {
  await _scrollTo(tester, 'oshi_request_genre_field');
  await tester.tap(_key('oshi_request_genre_field'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// 種別を切り替える（初期値は個人）
Future<void> _selectKind(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    _key('oshi_request_kind'),
    -200,
    scrollable: listScrollable(),
  );
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await _scrollTo(tester, 'oshi_request_submit_button');
  await tester.tap(_key('oshi_request_submit_button'));
}

void main() {
  testWidgets('検索欄の文字列を名前の初期値にする', (tester) async {
    await _pumpRequest(
      tester,
      repo: FakeOshiRepository(_existing),
      name: 'あたらしい',
    );
    final field = tester.widget<TextField>(_key('oshi_request_name_field'));
    expect(field.controller!.text, 'あたらしい');
  });

  group('重複の確認', () {
    testWidgets('同じ種別に完全一致（表記ゆれ）なら申請ボタンを押せず、種別を変えると押せる', (tester) async {
      await _pumpRequest(
        tester,
        repo: FakeOshiRepository(_existing),
        name: 'ｻﾝﾌﾟﾙ ぐるーぷ',
      );
      await _selectKind(tester, 'グループ');
      expect(_key('oshi_request_exact_card'), findsOneWidget);
      expect(_key('oshi_request_candidate_group_g1'), findsOneWidget);
      await _scrollTo(tester, 'oshi_request_submit_button');
      expect(onPressedOf(tester, _key('oshi_request_submit_button')), isNull);

      await tester.scrollUntilVisible(
        _key('oshi_request_kind'),
        -200,
        scrollable: listScrollable(),
      );
      await tester.tap(find.text('個人'));
      await tester.pumpAndSettle();
      expect(_key('oshi_request_exact_card'), findsNothing);
      await _scrollTo(tester, 'oshi_request_submit_button');
      expect(
        onPressedOf(tester, _key('oshi_request_submit_button')),
        isNotNull,
      );
    });

    testWidgets('申請中の推しとの完全一致でも止める', (tester) async {
      await _pumpRequest(
        tester,
        repo: FakeOshiRepository(_existing),
        name: 'しんせいちゅうゆにっと',
      );
      await _selectKind(tester, 'グループ');
      // 漢字はかなに変換しないので一致しない。カタカナ表記で確かめる
      expect(_key('oshi_request_exact_card'), findsNothing);

      await tester.enterText(_key('oshi_request_name_field'), '申請中ユニット');
      await tester.pumpAndSettle();
      expect(_key('oshi_request_exact_card'), findsOneWidget);
      expect(_key('oshi_request_candidate_group_g2'), findsOneWidget);
    });

    testWidgets('新しい別名が既存の名前と一致しても止める', (tester) async {
      await _pumpRequest(
        tester,
        repo: FakeOshiRepository(_existing),
        name: '別人',
      );
      await tester.tap(find.text('個人'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'oshi_request_add_alias_button');
      await tester.tap(_key('oshi_request_add_alias_button'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('oshi_request_alias_field_0'), 'タロウ');
      await tester.pumpAndSettle();
      expect(_key('oshi_request_exact_card'), findsOneWidget);
    });

    testWidgets('部分一致は「もしかして」に出すが、申請は止めない', (tester) async {
      await _pumpRequest(
        tester,
        repo: FakeOshiRepository(_existing),
        name: 'サンプル',
      );
      expect(_key('oshi_request_similar_card'), findsOneWidget);
      expect(_key('oshi_request_exact_card'), findsNothing);
      await _scrollTo(tester, 'oshi_request_submit_button');
      expect(
        onPressedOf(tester, _key('oshi_request_submit_button')),
        isNotNull,
      );
    });

    testWidgets('既存の推しを読み込むまでは申請ボタンを押せない', (tester) async {
      await _pumpRequest(tester, repo: FakeOshiRepository(), name: 'あたらしい');
      await _scrollTo(tester, 'oshi_request_submit_button');
      expect(onPressedOf(tester, _key('oshi_request_submit_button')), isNull);
    });

    testWidgets('既存の推しを読めなかったら、エラーを出して申請ボタンを押せない', (tester) async {
      final repo = FakeOshiRepository(_existing)..fail = true;
      await _pumpRequest(tester, repo: repo, name: 'あたらしい');
      expect(_key('oshi_request_load_error'), findsOneWidget);
      await _scrollTo(tester, 'oshi_request_submit_button');
      expect(onPressedOf(tester, _key('oshi_request_submit_button')), isNull);
    });
  });

  group('入力の検査', () {
    testWidgets('ジャンル未選択・記号だけの名前ではエラーを出し、申請しない', (tester) async {
      final repo = FakeOshiRepository(_existing);
      await _pumpRequest(tester, repo: repo, name: '・・・');
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(repo.requests, isEmpty);
      expect(find.text('入力内容を確かめてください'), findsOneWidget);
      expect(find.text('ジャンルを選んでください'), findsOneWidget);
      await tester.scrollUntilVisible(
        _key('oshi_request_name_field'),
        -200,
        scrollable: listScrollable(),
      );
      expect(find.text('名前に文字（記号や空白以外）を含めてください'), findsOneWidget);
    });

    testWidgets('X に @ だけ・URL に http を入れるとエラー', (tester) async {
      final repo = FakeOshiRepository(_existing);
      await _pumpRequest(tester, repo: repo, name: 'あたらしい');
      await _selectGenre(tester, 'アイドル');
      await _scrollTo(tester, 'oshi_request_url_field');
      await tester.enterText(
        _key('oshi_request_url_field'),
        'http://example.com',
      );
      await _scrollTo(tester, 'oshi_request_x_field');
      await tester.enterText(_key('oshi_request_x_field'), '@');
      await _tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(repo.requests, isEmpty);
      await tester.scrollUntilVisible(
        find.text('公式サイトは https:// で始まる URL を入力してください'),
        -200,
        scrollable: listScrollable(),
      );
      expect(find.text('X のアカウント名は英数字と _ の1〜15文字で入力してください'), findsOneWidget);
    });
  });

  group('申請', () {
    testWidgets('成功すると1回だけ申請し、SnackBar を出して検索画面へ移る', (tester) async {
      final repo = FakeOshiRepository(_existing)..requestGate = Completer();
      await _pumpRequest(tester, repo: repo, name: ' あたらしい推し ');
      await _selectGenre(tester, '声優');
      await _scrollTo(tester, 'oshi_request_x_field');
      await tester.enterText(_key('oshi_request_x_field'), '@new_oshi');

      await _tapSubmit(tester);
      await tester.pump();
      // 処理中は押せない（連打しても1回）
      expect(onPressedOf(tester, _key('oshi_request_submit_button')), isNull);
      await tester.tap(_key('oshi_request_submit_button'), warnIfMissed: false);
      await tester.pump();

      repo.requestGate!.complete();
      await tester.pumpAndSettle();

      expect(repo.requests, hasLength(1));
      final r = repo.requests.single;
      expect(r.kind, OshiKind.person); // 初期値は個人（Fb-1）
      expect(r.trimmedName, 'あたらしい推し');
      expect(r.genre, OshiGenre.voiceActor);
      expect(r.xHandle, 'new_oshi');
      expect(find.text('申請しました。運営の承認後に公開されます'), findsOneWidget);
      expect(find.text('search:あたらしい推し'), findsOneWidget);
    });

    testWidgets('リポジトリが重複と判定したら、SnackBar を出して画面に残る', (tester) async {
      final repo = FakeOshiRepository(_existing)
        ..requestError = OshiDuplicateException([oshi('gx', '先に申請された推し')]);
      await _pumpRequest(tester, repo: repo, name: 'あたらしい');
      await _selectGenre(tester, 'アイドル');
      await _tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.text('同じ名前の推しが既にあります（先に申請された推し）'), findsOneWidget);
      expect(_key('fake_search_page'), findsNothing);
      // もう一度押せる
      expect(
        onPressedOf(tester, _key('oshi_request_submit_button')),
        isNotNull,
      );
    });

    testWidgets('通信エラーなどでは決まった日本語の文を出す', (tester) async {
      final repo = FakeOshiRepository(_existing)..requestError = Exception('x');
      await _pumpRequest(tester, repo: repo, name: 'あたらしい');
      await _selectGenre(tester, 'アイドル');
      await _tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.text('申請できませんでした。通信状況を確かめて、もう一度お試しください'), findsOneWidget);
    });
  });

  group('別名の欄', () {
    testWidgets('10個まで追加でき、途中を消してもフォーカスと文字が隣へ移らない', (tester) async {
      await _pumpRequest(
        tester,
        repo: FakeOshiRepository(_existing),
        name: 'あたらしい',
      );
      for (var i = 0; i < 10; i++) {
        await _scrollTo(tester, 'oshi_request_add_alias_button');
        await tester.tap(_key('oshi_request_add_alias_button'));
        await tester.pumpAndSettle();
      }
      expect(
        onPressedOf(tester, _key('oshi_request_add_alias_button')),
        isNull,
      );

      await tester.scrollUntilVisible(
        _key('oshi_request_name_field'),
        -300,
        scrollable: listScrollable(),
      );
      for (var i = 0; i < 3; i++) {
        await _scrollTo(tester, 'oshi_request_alias_field_$i');
        await tester.enterText(_key('oshi_request_alias_field_$i'), 'べつ$i');
      }
      await tester.pumpAndSettle();
      await tester.tap(_key('oshi_request_alias_field_1'));
      await tester.pumpAndSettle();
      Finder editable(int id) => find.descendant(
        of: _key('oshi_request_alias_field_$id'),
        matching: find.byType(EditableText),
      );
      final before = tester.state<EditableTextState>(editable(1));

      await _scrollTo(tester, 'oshi_request_remove_alias_button_0');
      await tester.tap(_key('oshi_request_remove_alias_button_0'));
      await tester.pumpAndSettle();

      expect(_key('oshi_request_alias_field_0'), findsNothing);
      expect(tester.widget<EditableText>(editable(1)).controller.text, 'べつ1');
      expect(
        tester.widget<EditableText>(editable(1)).focusNode.hasFocus,
        isTrue,
      );
      expect(
        identical(tester.state<EditableTextState>(editable(1)), before),
        isTrue,
      );
      expect(tester.widget<EditableText>(editable(2)).controller.text, 'べつ2');
      // 消したので、また追加できる
      await _scrollTo(tester, 'oshi_request_add_alias_button');
      expect(
        onPressedOf(tester, _key('oshi_request_add_alias_button')),
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('スマホの幅（360px）', () {
    testWidgets('全項目に長い値を入れて、エラーと候補が出てもはみ出さない', (tester) async {
      usePhoneSize(tester);
      await _pumpRequest(
        tester,
        repo: FakeOshiRepository([
          ..._existing,
          oshi('long', '${'ながいなまえ' * 8}A'),
        ]),
        name: 'ながいなまえ' * 8,
      );
      expect(_key('oshi_request_similar_card'), findsOneWidget);
      await tester.tap(find.text('個人'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'oshi_request_add_alias_button');
      await tester.tap(_key('oshi_request_add_alias_button'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('oshi_request_alias_field_0'), 'べつめい' * 20);
      await _scrollTo(tester, 'oshi_request_agency_field');
      await tester.enterText(_key('oshi_request_agency_field'), 'じむしょ' * 20);
      await _tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
