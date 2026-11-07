// /live-form の保存（U5）。手入力とスクショ読み取り（Step3）の両方が同じ保存処理を使う。
// 横山さんのフォームのうち、Step2 で変えたのは _save と保存中の表示だけ。
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/live_form/live_draft.dart';
import 'package:oshiashi/features/live_form/live_draft_to_models.dart';
import 'package:oshiashi/features/live_form/live_form_page.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/models/reception.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';

import 'live_test_helpers.dart';
import 'oshi_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));
final _saveButton = _key('live_form_save_button');

/// Gemini の抽出結果（Step3 の LiveDraft.fromGemini に渡す形）
Map<String, dynamic> gemini({int prices = 1, int performances = 1}) => {
  'liveTitle': '読み取ったライブ',
  'officialUrl': 'https://example.com/live',
  'performers': ['テストグループ'],
  'performances': [
    for (var i = 0; i < performances; i++)
      {
        'startAt': '2026-12-0${i + 1}T18:00:00+09:00',
        'venue': '武道館',
        'prefecture': '東京都',
      },
  ],
  'receptions': [
    {
      'type': 'fc',
      'name': 'FC先行',
      'applyEndAt': '2026-11-20T23:59:00+09:00',
      'prices': [
        for (var i = 0; i < prices; i++) {'seat': 'S席$i', 'amount': 9800},
      ],
    },
  ],
};

const _group = OshiSummary(
  id: 'g1',
  kind: OshiKind.group,
  name: 'テストグループ',
  genre: OshiGenre.idol,
  status: OshiStatus.approved,
);

/// /scan（仮）→ /live-form（読み取り結果）を開く。保存後の行き先も確かめられるルーター
Future<GoRouter> pumpFromScan(
  WidgetTester tester,
  FakeLiveRepository repo, {
  Map<String, dynamic>? json,
  String? uid = 'u1',
}) async {
  final router = GoRouter(
    initialLocation: '/scan',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Text('route:/'),
        routes: [
          GoRoute(
            path: 'lives',
            builder: (_, _) => const Text('route:/lives'),
            routes: [
              GoRoute(
                path: ':liveId',
                builder: (_, s) =>
                    Text('route:/lives/${s.pathParameters['liveId']}'),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/scan',
        builder: (c, _) => Scaffold(
          body: TextButton(
            onPressed: () => c.push(
              '/live-form',
              extra: LiveDraft.fromGemini(json ?? gemini()),
            ),
            child: const Text('読み取り結果を開く'),
          ),
        ),
      ),
      GoRoute(
        path: '/live-form',
        builder: (_, s) => LiveFormPage(initial: s.extra as LiveDraft?),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue(uid),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        // uid が無いときも推しの一覧があるように、一覧そのものを差し替える
        allOshisProvider.overrideWith((ref) => Stream.value(const [_group])),
        liveRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(DateTime(2026, 11, 5, 12)),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('読み取り結果を開く'));
  await tester.pumpAndSettle();
  return router;
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.ensureVisible(_saveButton);
  await tester.tap(_saveButton);
}

/// 保存が成功した後に開く、Google カレンダーへの追加シートを「追加しない」で
/// 閉じ、移動が終わるまで待つ。シートが開いている間は保存ボタンの進捗表示が
/// 回り続けるため、シートを閉じるまでは pumpAndSettle を使わない。
Future<void> skipCalendarSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  expect(find.text('Google カレンダーにも追加しますか？'), findsOneWidget);
  await tester.tap(find.text('追加しない'));
  await tester.pumpAndSettle();
}

String dialogText(WidgetTester tester) =>
    (tester.widget<AlertDialog>(find.byType(AlertDialog)).content! as Text)
        .data!;

void main() {
  testWidgets('スクショ経由: 保存すると1つのバッチで作り、ライブ詳細へ移る', (tester) async {
    final repo = FakeLiveRepository()..createGate = Completer<void>();
    final router = await pumpFromScan(tester, repo);

    await tapSave(tester);
    await tester.pump();

    final c = repo.created.single;
    expect(c.uid, 'u1');
    expect(c.live.title, '読み取ったライブ');
    expect(c.live.officialUrl, 'https://example.com/live');
    // 読み取った出演者名が承認済みの推しに自動で対応付けられている
    expect(c.live.groupIds, ['g1']);
    expect(c.live.oshiIds, isEmpty);
    expect(c.performances.single.venue, '武道館');
    expect(c.performances.single.prefecture, '東京都');
    expect(c.receptions.single.type, ReceptionType.fc);
    expect(c.receptions.single.prices.single.amount, 9800);

    repo.createGate!.complete();
    await skipCalendarSheet(tester);
    expect(find.text('route:/lives/new-live-1'), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/lives/new-live-1',
    );
    // go で移るので、戻るとフォームではなく一覧（→ ホーム）に戻る
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('route:/lives'), findsOneWidget);
  });

  testWidgets('保存中はボタンを押せず、進捗を出す。連打しても作成は1回', (tester) async {
    final repo = FakeLiveRepository()..createGate = Completer<void>();
    await pumpFromScan(tester, repo);

    await tester.ensureVisible(_saveButton);
    await tester.tap(_saveButton);
    // setState が反映される前の2回目
    await tester.tap(_saveButton, warnIfMissed: false);
    await tester.pump();
    await tester.tap(_saveButton, warnIfMissed: false);
    await tester.pump();

    expect(repo.created, hasLength(1));
    expect(tester.widget<FilledButton>(_saveButton).onPressed, isNull);
    expect(
      find.descendant(
        of: _saveButton,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    repo.createGate!.complete();
    await skipCalendarSheet(tester);
    expect(repo.created, hasLength(1));
  });

  testWidgets('失敗したら日本語の SnackBar を出し、入力を残して、もう一度押せる', (tester) async {
    final repo = FakeLiveRepository()
      ..createGate = Completer<void>()
      ..createError = permissionDenied();
    await pumpFromScan(tester, repo);

    await tapSave(tester);
    await tester.pump();
    repo.createGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('保存できませんでした。通信状況を確かめて、もう一度お試しください'), findsOneWidget);
    expect(find.text('読み取ったライブ'), findsOneWidget);
    expect(find.text('route:/lives/new-live-1'), findsNothing);
    expect(tester.widget<FilledButton>(_saveButton).onPressed, isNotNull);
    expect(find.text('保存'), findsOneWidget);

    // 直してもう一度
    repo
      ..createError = null
      ..createGate = null;
    await tapSave(tester);
    await skipCalendarSheet(tester);
    expect(repo.created, hasLength(2));
    expect(find.text('route:/lives/new-live-2'), findsOneWidget);
  });

  testWidgets('未ログイン（uid が無い）なら保存せず、日本語で知らせる', (tester) async {
    final repo = FakeLiveRepository();
    await pumpFromScan(tester, repo, uid: null);
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(find.text('ログインし直してから、もう一度保存してください'), findsOneWidget);
    expect(repo.created, isEmpty);
  });

  testWidgets('公演が0件なら、日本語のダイアログを出して保存しない', (tester) async {
    final repo = FakeLiveRepository();
    await pumpFromScan(tester, repo, json: gemini(performances: 0));
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(dialogText(tester), contains('公演を1件以上入力してください'));
    expect(repo.created, isEmpty);
  });

  testWidgets('料金が上限ちょうどなら保存でき、1個多いとダイアログで止める', (tester) async {
    const max = LiveLimits.maxPricesPerReception;
    final over = FakeLiveRepository();
    await pumpFromScan(tester, over, json: gemini(prices: max + 1));
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(dialogText(tester), contains('席種は$max個までです'));
    expect(over.created, isEmpty);

    final ok = FakeLiveRepository();
    await pumpFromScan(tester, ok, json: gemini(prices: max));
    await tapSave(tester);
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    await skipCalendarSheet(tester);
    expect(ok.created.single.receptions.single.prices, hasLength(max));
  });

  testWidgets('必須項目が欠けていれば（validate）、保存しない', (tester) async {
    final repo = FakeLiveRepository();
    final json = gemini()..['liveTitle'] = '';
    await pumpFromScan(tester, repo, json: json);
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(dialogText(tester), contains('ライブ名を入力してください'));
    expect(repo.created, isEmpty);
  });

  for (final w in [320.0, 360.0, 390.0, 720.0, 1000.0]) {
    testWidgets('ライブ情報の入力: 幅 ${w.toInt()} ではみ出さない', (tester) async {
      tester.view.physicalSize = Size(w, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpFromScan(tester, FakeLiveRepository());
      expect(find.byKey(const Key('hako_save_bar')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
