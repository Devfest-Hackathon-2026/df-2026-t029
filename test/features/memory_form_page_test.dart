// 記録する画面（作成: /lives/:liveId/memory/:performanceId、編集: /memories/:performanceId/edit）のテスト（B3）。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/memory/memory_form_page.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/live_memory.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/memory_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/repositories/memory_repository.dart';

import 'live_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

class FakeMemoryRepository implements MemoryRepository {
  FakeMemoryRepository([Iterable<LiveMemory> init = const []]) {
    for (final m in init) {
      store[m.performanceId] = m;
    }
  }
  final Map<String, LiveMemory> store = {};
  final List<String> calls = [];
  Object? error;
  Completer<void>? gate;

  @override
  Stream<Map<String, LiveMemory>> watchAll(String uid) =>
      Stream.value(Map.of(store));

  Future<void> _write(String name, LiveMemory m) async {
    calls.add(name);
    await gate?.future;
    if (error != null) throw error!;
    store[m.performanceId] = m;
  }

  @override
  Future<void> create(String uid, LiveMemory memory) =>
      _write('create', memory);

  @override
  Future<void> update(String uid, LiveMemory memory) =>
      _write('update', memory);

  @override
  Future<void> delete(String uid, String performanceId) async {
    calls.add('delete');
    await gate?.future;
    if (error != null) throw error!;
    store.remove(performanceId);
  }
}

final _start = DateTime(2026, 12, 9, 18);
final _existing = LiveMemory(
  performanceId: 'p1',
  liveId: 'l1',
  liveTitle: 'ツアー',
  startAt: _start,
  venue: '会場p1',
  seat: 'A1',
  setlist: const ['曲1', '曲2'],
  impression: 'よかった',
);

Future<void> pumpForm(
  WidgetTester tester, {
  required String location,
  required FakeMemoryRepository memories,
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
      GoRoute(path: '/lives', builder: (_, _) => const Text('route:/lives')),
      GoRoute(
        path: '/lives/:liveId',
        builder: (_, s) => Text('route:/lives/${s.pathParameters['liveId']}'),
        routes: [
          GoRoute(
            path: 'memory/:performanceId',
            builder: (_, s) => MemoryFormPage(
              performanceId: s.pathParameters['performanceId']!,
              liveId: s.pathParameters['liveId'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/memories',
        builder: (_, _) => const Text('route:/memories'),
        routes: [
          GoRoute(
            path: ':performanceId',
            builder: (_, s) =>
                Text('route:/memories/${s.pathParameters['performanceId']}'),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, s) => MemoryFormPage(
                  performanceId: s.pathParameters['performanceId']!,
                ),
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
        liveRepositoryProvider.overrideWithValue(
          FakeLiveRepository(
            lives: const [
              Live(id: 'l1', title: 'ツアー', groupIds: ['g1']),
            ],
            performances: [perfOf('p1', 'l1', _start)],
          ),
        ),
        memoryRepositoryProvider.overrideWithValue(memories),
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
}

void main() {
  group('作成', () {
    const loc = '/lives/l1/memory/p1';

    testWidgets('ライブ名・日時・会場と、3つの欄・保存が出る。削除は無い', (tester) async {
      await pumpForm(tester, location: loc, memories: FakeMemoryRepository());
      expect(find.text('記録する'), findsOneWidget);
      expect(find.text('ツアー'), findsOneWidget);
      expect(find.text('2026/12/9(水) 18:00 開演'), findsOneWidget);
      expect(find.text('会場p1'), findsOneWidget);
      expect(_key('memory_form_seat'), findsOneWidget);
      expect(_key('memory_form_setlist'), findsOneWidget);
      expect(_key('memory_form_impression'), findsOneWidget);
      expect(_key('memory_form_save_button'), findsOneWidget);
      expect(_key('memory_form_delete_button'), findsNothing);
    });

    testWidgets('保存すると create が呼ばれ、セトリは空行・空白を除く。ライブ詳細へ移る', (tester) async {
      final repo = FakeMemoryRepository();
      await pumpForm(tester, location: loc, memories: repo);
      await tester.enterText(_key('memory_form_seat'), '  B2  ');
      await tester.enterText(_key('memory_form_setlist'), ' 曲A \n\n曲B\n   ');
      await tester.enterText(_key('memory_form_impression'), '最高');
      await tester.tap(_key('memory_form_save_button'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['create']);
      final m = repo.store['p1']!;
      expect(m.seat, 'B2');
      expect(m.setlist, ['曲A', '曲B']);
      expect(m.impression, '最高');
      expect(find.text('route:/lives/l1'), findsOneWidget);
    });

    testWidgets('空のまま保存すると、座席・感想は null・セトリは空', (tester) async {
      final repo = FakeMemoryRepository();
      await pumpForm(tester, location: loc, memories: repo);
      await tester.tap(_key('memory_form_save_button'));
      await tester.pumpAndSettle();
      final m = repo.store['p1']!;
      expect(m.seat, isNull);
      expect(m.impression, isNull);
      expect(m.setlist, isEmpty);
    });

    testWidgets('セトリは100曲まで（境界）。101曲は保存しない', (tester) async {
      final repo = FakeMemoryRepository();
      await pumpForm(tester, location: loc, memories: repo);
      await tester.enterText(
        _key('memory_form_setlist'),
        List.generate(101, (i) => '曲$i').join('\n'),
      );
      await tester.scrollUntilVisible(
        _key('memory_form_save_button'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(_key('memory_form_save_button'));
      await tester.pumpAndSettle();
      expect(find.text('セトリは100曲までです'), findsOneWidget);
      expect(repo.calls, isEmpty);

      await tester.enterText(
        _key('memory_form_setlist'),
        List.generate(100, (i) => '曲$i').join('\n'),
      );
      await tester.scrollUntilVisible(
        _key('memory_form_save_button'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(_key('memory_form_save_button'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['create']);
    });

    testWidgets('曲名は100文字まで（境界）', (tester) async {
      final repo = FakeMemoryRepository();
      await pumpForm(tester, location: loc, memories: repo);
      await tester.enterText(_key('memory_form_setlist'), 'あ' * 101);
      await tester.tap(_key('memory_form_save_button'));
      await tester.pumpAndSettle();
      expect(find.text('曲名は1曲100文字までです'), findsOneWidget);
      expect(repo.calls, isEmpty);
      await tester.enterText(_key('memory_form_setlist'), 'あ' * 100);
      await tester.tap(_key('memory_form_save_button'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['create']);
    });

    testWidgets('保存に失敗したら日本語の SnackBar。画面に残り、また押せる', (tester) async {
      final repo = FakeMemoryRepository()..error = Exception('x');
      await pumpForm(tester, location: loc, memories: repo);
      await tester.tap(_key('memory_form_save_button'));
      await tester.pumpAndSettle();
      expect(find.text('記録を保存できませんでした。もう一度お試しください'), findsOneWidget);
      expect(_key('memory_form_save_button'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_key('memory_form_save_button')).onPressed,
        isNotNull,
      );
    });

    testWidgets('連打しても書き込みは1回。処理中はボタンが無効', (tester) async {
      final repo = FakeMemoryRepository()..gate = Completer<void>();
      await pumpForm(tester, location: loc, memories: repo);
      await tester.tap(_key('memory_form_save_button'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(_key('memory_form_save_button')).onPressed,
        isNull,
      );
      await tester.tap(_key('memory_form_save_button'), warnIfMissed: false);
      await tester.pump();
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(repo.calls, ['create']);
    });

    testWidgets('存在しない公演は「見つかりませんでした」', (tester) async {
      await pumpForm(
        tester,
        location: '/lives/l1/memory/nope',
        memories: FakeMemoryRepository(),
      );
      expect(_key('memory_form_not_found'), findsOneWidget);
      expect(find.text('この公演は見つかりませんでした'), findsOneWidget);
    });

    testWidgets('戻るで /lives へ（戻れないとき）', (tester) async {
      await pumpForm(tester, location: loc, memories: FakeMemoryRepository());
      await tester.tap(_key('hako_back'));
      await tester.pumpAndSettle();
      // ルートの親（ライブ詳細）があるので、そこへ戻る
      expect(find.text('route:/lives/l1'), findsOneWidget);
    });
  });

  group('編集', () {
    const loc = '/memories/p1/edit';

    testWidgets('今の内容が入っていて、削除ボタンがある', (tester) async {
      await pumpForm(
        tester,
        location: loc,
        memories: FakeMemoryRepository([_existing]),
      );
      expect(find.text('記録を編集'), findsOneWidget);
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('曲1\n曲2'), findsOneWidget);
      expect(find.text('よかった'), findsOneWidget);
      expect(_key('memory_form_delete_button'), findsOneWidget);
    });

    testWidgets('保存すると update が呼ばれ、記録の詳細へ移る', (tester) async {
      final repo = FakeMemoryRepository([_existing]);
      await pumpForm(tester, location: loc, memories: repo);
      await tester.enterText(_key('memory_form_seat'), 'C3');
      await tester.tap(_key('memory_form_save_button'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['update']);
      expect(repo.store['p1']!.seat, 'C3');
      expect(find.text('route:/memories/p1'), findsOneWidget);
    });

    testWidgets('削除: 確認ダイアログでキャンセルすれば消さない', (tester) async {
      final repo = FakeMemoryRepository([_existing]);
      await pumpForm(tester, location: loc, memories: repo);
      await tester.tap(_key('memory_form_delete_button'));
      await tester.pumpAndSettle();
      expect(find.text('記録を削除しますか？'), findsOneWidget);
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
    });

    testWidgets('削除: 確認すると delete が呼ばれ、メモリー一覧へ移る', (tester) async {
      final repo = FakeMemoryRepository([_existing]);
      await pumpForm(tester, location: loc, memories: repo);
      await tester.tap(_key('memory_form_delete_button'));
      await tester.pumpAndSettle();
      await tester.tap(_key('memory_form_delete_confirm'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['delete']);
      expect(repo.store, isEmpty);
      expect(find.text('route:/memories'), findsOneWidget);
    });

    testWidgets('削除に失敗したら日本語の SnackBar', (tester) async {
      final repo = FakeMemoryRepository([_existing])..error = Exception('x');
      await pumpForm(tester, location: loc, memories: repo);
      await tester.tap(_key('memory_form_delete_button'));
      await tester.pumpAndSettle();
      await tester.tap(_key('memory_form_delete_confirm'));
      await tester.pumpAndSettle();
      expect(find.text('記録を削除できませんでした。もう一度お試しください'), findsOneWidget);
    });
  });

  group('はみ出し', () {
    for (final w in [320.0, 360.0, 390.0, 720.0, 1000.0]) {
      testWidgets('幅 ${w.toInt()}・文字 1.3 倍・長いタイトルでもはみ出さない', (tester) async {
        await pumpForm(
          tester,
          location: '/memories/p1/edit',
          memories: FakeMemoryRepository([
            LiveMemory(
              performanceId: 'p1',
              liveId: 'l1',
              liveTitle: 'とても長いライブ名' * 10,
              startAt: _start,
              venue: '長い会場名' * 10,
              setlist: List.generate(30, (i) => '曲$i'),
            ),
          ]),
          width: w,
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
