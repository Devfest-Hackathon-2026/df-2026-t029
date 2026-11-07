// メモリー一覧（/memories）と記録の詳細（/memories/:performanceId）のテスト（A5）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/memory/memory_detail_page.dart';
import 'package:oshiashi/features/memory/memory_list_page.dart';
import 'package:oshiashi/models/live_memory.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/memory_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';

import 'memory_form_page_test.dart' show FakeMemoryRepository;

Finder _key(String k) => find.byKey(Key(k));

final _now = DateTime(2026, 11, 5, 12);

LiveMemory mem(String id, DateTime at, {String? title}) => LiveMemory(
  performanceId: id,
  liveId: 'l$id',
  liveTitle: title ?? 'ライブ$id',
  startAt: at,
  venue: '会場$id',
  seat: 'A1',
  setlist: const ['曲1', '曲2'],
  impression: '感想',
);

Future<GoRouter> pumpMemory(
  WidgetTester tester,
  String location, {
  required List<LiveMemory> memories,
  double width = 390,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('route:/')),
      GoRoute(
        path: '/memories',
        builder: (_, _) => const MemoryListPage(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, s) =>
                MemoryDetailPage(performanceId: s.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, _) => const Text('route:edit'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        memoryRepositoryProvider.overrideWithValue(
          FakeMemoryRepository(memories),
        ),
        nowProvider.overrideWithValue(_now),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  final upcoming = mem('u', DateTime(2026, 12, 9, 18));
  final attended = mem('a', DateTime(2026, 10, 1, 18));

  group('メモリー一覧', () {
    testWidgets('記録が無ければ案内', (tester) async {
      await pumpMemory(tester, '/memories', memories: const []);
      expect(_key('memory_list_empty'), findsOneWidget);
    });

    testWidgets('参戦予定と参戦済みに分かれ、押すと詳細へ', (tester) async {
      await pumpMemory(tester, '/memories', memories: [upcoming, attended]);
      expect(find.text('参戦予定'), findsOneWidget);
      expect(find.text('参戦済み'), findsOneWidget);
      expect(_key('memory_list_upcoming_u'), findsOneWidget);
      expect(_key('memory_list_attended_a'), findsOneWidget);
      await tester.tap(_key('memory_list_attended_a'));
      await tester.pumpAndSettle();
      expect(_key('memory_detail'), findsOneWidget);
    });

    for (final w in [320.0, 360.0, 390.0, 720.0, 1000.0]) {
      testWidgets('幅 $w・文字 1.3 倍・長いタイトルではみ出さない', (tester) async {
        await pumpMemory(
          tester,
          '/memories',
          memories: [
            mem('u', DateTime(2026, 12, 9, 18), title: 'とても長いライブ名' * 8),
            mem('a', DateTime(2026, 10, 1, 18), title: 'とても長いライブ名' * 8),
            mem('b', DateTime(2026, 9, 1, 18)),
          ],
          width: w,
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('記録の詳細', () {
    testWidgets('座席・セトリ・感想が出て、編集ボタンで編集へ', (tester) async {
      await pumpMemory(tester, '/memories/a', memories: [attended]);
      expect(_key('memory_detail_seat'), findsOneWidget);
      expect(_key('memory_detail_setlist'), findsOneWidget);
      expect(_key('memory_detail_impression'), findsOneWidget);
      await tester.tap(_key('memory_detail_edit_button'));
      await tester.pumpAndSettle();
      expect(find.text('route:edit'), findsOneWidget);
    });

    testWidgets('記録が無ければ「見つかりませんでした」', (tester) async {
      await pumpMemory(tester, '/memories/zzz', memories: const []);
      expect(_key('memory_detail_not_found'), findsOneWidget);
    });

    for (final w in [320.0, 360.0, 390.0, 720.0, 1000.0]) {
      testWidgets('幅 $w・文字 1.3 倍ではみ出さない', (tester) async {
        await pumpMemory(
          tester,
          '/memories/a',
          memories: [
            LiveMemory(
              performanceId: 'a',
              liveId: 'la',
              liveTitle: 'とても長いライブ名' * 8,
              startAt: DateTime(2026, 10, 1, 18),
              venue: '長い会場名' * 8,
              seat: '長い座席' * 10,
              setlist: List.generate(40, (i) => '長い曲名' * 4 + '$i'),
              impression: '長い感想' * 50,
            ),
          ],
          width: w,
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
