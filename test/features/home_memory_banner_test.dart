// ホームの「ライブお疲れさまでした！」カードと、メモリー一覧の「新しい記録」のカードのテスト（Q3）。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/home/home_memory_banner.dart';
import 'package:oshiashi/features/memory/memory_list_page.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/live_memory.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/memory_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';

import 'live_test_helpers.dart';
import 'memory_form_page_test.dart' show FakeMemoryRepository;
import 'oshi_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

final _now = DateTime(2026, 11, 8, 12);

LiveMemory _mem(
  String id,
  DateTime at, {
  DateTime? postedAt,
  List<String> images = const [],
  String? title,
}) => LiveMemory(
  performanceId: id,
  liveId: 'l$id',
  liveTitle: title ?? 'ライブ$id',
  startAt: at,
  venue: '会場$id',
  seat: 'SEAT-SECRET-A12',
  images: images,
  postedAt: postedAt,
);

/// 読み込み中のままの記録のリポジトリ
class _PendingRepo extends FakeMemoryRepository {
  @override
  Stream<Map<String, LiveMemory>> watchAll(String uid) =>
      StreamController<Map<String, LiveMemory>>().stream;
}

/// 読み込みに失敗する記録のリポジトリ
class _ErrorRepo extends FakeMemoryRepository {
  @override
  Stream<Map<String, LiveMemory>> watchAll(String uid) =>
      Stream.error(permissionDenied());
}

final _routes = <String>[];

Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  required FakeMemoryRepository repo,
  double width = 390,
  double textScale = 1,
  List<String> liveIds = const [],
  Map<String, String>? store,
  String? uid = 'u1',
}) async {
  _routes.clear();
  final saved = store ?? <String, String>{};
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => page),
      GoRoute(
        path: '/memories',
        builder: (_, _) => page,
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, s) {
              _routes.add(s.uri.toString());
              return Text('route:${s.uri}');
            },
            routes: [
              GoRoute(
                path: 'share',
                builder: (_, s) {
                  _routes.add(s.uri.toString());
                  return Text('route:${s.uri}');
                },
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
        currentUidProvider.overrideWithValue(uid),
        homeBannerStorageProvider.overrideWithValue(
          HomeBannerStorage(
            read: (k) => saved[k],
            write: (k, v) => saved[k] = v,
          ),
        ),
        memoryRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(_now),
        liveRepositoryProvider.overrideWithValue(
          FakeLiveRepository(
            lives: [
              for (final id in liveIds)
                Live(id: 'l$id', title: 'ライブ', groupIds: const ['g1']),
            ],
          ),
        ),
        oshiRepositoryProvider.overrideWithValue(
          FakeOshiRepository([oshi('g1', 'ひかり')]),
        ),
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

Widget _home() => Scaffold(
  body: ListView(
    padding: const EdgeInsets.all(16),
    children: const [HomeMemoryBanner()],
  ),
);

void main() {
  final recent = _mem('a', _now.subtract(const Duration(days: 2)));

  group('ホームのカード', () {
    testWidgets('新しい記録があれば出る。見出し・本文・2つのボタン・リンク', (tester) async {
      await pumpPage(
        tester,
        _home(),
        repo: FakeMemoryRepository([recent]),
        liveIds: ['a'],
      );
      expect(_key('home_memory_banner'), findsOneWidget);
      expect(find.text('ライブお疲れさまでした！'), findsOneWidget);
      expect(
        find.textContaining('の記録と、投稿用のチケットができています。そのままでも、まとめて直してからでも投稿できます。'),
        findsOneWidget,
      );
      expect(find.textContaining('ライブa', findRichText: true), findsWidgets);
      expect(find.text('Xに投稿'), findsOneWidget);
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('記録を見る・セトリと感想を書く'), findsOneWidget);
    });

    testWidgets('写真が0枚でも出る', (tester) async {
      await pumpPage(
        tester,
        _home(),
        repo: FakeMemoryRepository([recent]),
        liveIds: ['a'],
      );
      expect(_key('home_memory_banner'), findsOneWidget);
    });

    testWidgets('ちょうど7日前は出て、8日前は出ない', (tester) async {
      await pumpPage(
        tester,
        _home(),
        repo: FakeMemoryRepository([
          _mem('a', _now.subtract(const Duration(days: 7))),
        ]),
        liveIds: ['a'],
      );
      expect(_key('home_memory_banner'), findsOneWidget);
      await pumpPage(
        tester,
        _home(),
        repo: FakeMemoryRepository([
          _mem('a', _now.subtract(const Duration(days: 8))),
        ]),
        liveIds: ['a'],
      );
      expect(_key('home_memory_banner'), findsNothing);
    });

    testWidgets('投稿済み（postedAt あり）なら出ない', (tester) async {
      await pumpPage(
        tester,
        _home(),
        repo: FakeMemoryRepository([
          _mem('a', _now.subtract(const Duration(days: 1)), postedAt: _now),
        ]),
        liveIds: ['a'],
      );
      expect(_key('home_memory_banner'), findsNothing);
    });

    testWidgets('参戦予定だけなら出ない', (tester) async {
      await pumpPage(
        tester,
        _home(),
        repo: FakeMemoryRepository([
          _mem('a', _now.add(const Duration(days: 3))),
        ]),
        liveIds: ['a'],
      );
      expect(_key('home_memory_banner'), findsNothing);
    });

    testWidgets('複数あれば、開演がいちばん新しい1件のカード', (tester) async {
      await pumpPage(
        tester,
        _home(),
        repo: FakeMemoryRepository([
          _mem('old', _now.subtract(const Duration(days: 5)), title: '古いほう'),
          _mem('new', _now.subtract(const Duration(days: 1)), title: '新しいほう'),
        ]),
        liveIds: ['old', 'new'],
      );
      expect(_key('home_memory_banner'), findsOneWidget);
      expect(find.textContaining('新しいほう', findRichText: true), findsWidgets);
      expect(find.textContaining('古いほう', findRichText: true), findsNothing);
    });

    testWidgets('閉じるボタン（×）で、そのカードが消える。ほかの記録のカードは出ない', (tester) async {
      final store = <String, String>{};
      await pumpPage(
        tester,
        _home(),
        repo: FakeMemoryRepository([recent]),
        liveIds: ['a'],
        store: store,
      );
      expect(_key('home_memory_banner'), findsOneWidget);
      await tester.ensureVisible(_key('home_memory_banner_close'));
      await tester.tap(_key('home_memory_banner_close'));
      await tester.pumpAndSettle();
      expect(_key('home_memory_banner'), findsNothing);
      // このブラウザに、ユーザーごとの印が残る（記録の中身は変えない）
      expect(store.keys.single, contains('u1'));
      expect(store.values.single, contains('"a"'));
    });

    testWidgets('閉じたカードは、次に開いても出ない（保存した印から戻る）', (tester) async {
      final store = <String, String>{
        'oshiashi.dismissedHomeBanners.u1': '["a"]',
      };
      await pumpPage(
        tester,
        _home(),
        repo: FakeMemoryRepository([recent]),
        liveIds: ['a'],
        store: store,
      );
      expect(_key('home_memory_banner'), findsNothing);
    });

    testWidgets('別のユーザーが閉じた印は、効かない', (tester) async {
      final store = <String, String>{
        'oshiashi.dismissedHomeBanners.other': '["a"]',
      };
      await pumpPage(
        tester,
        _home(),
        repo: FakeMemoryRepository([recent]),
        liveIds: ['a'],
        store: store,
      );
      expect(_key('home_memory_banner'), findsOneWidget);
    });

    testWidgets('保存した印が壊れていても、カードは出る（例外なし）', (tester) async {
      final store = <String, String>{
        'oshiashi.dismissedHomeBanners.u1': 'これはJSONではない',
      };
      await pumpPage(
        tester,
        _home(),
        repo: FakeMemoryRepository([recent]),
        liveIds: ['a'],
        store: store,
      );
      expect(_key('home_memory_banner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('いちばん新しい記録を閉じると、次に新しい（7日以内・未投稿）記録のカードに替わる', (tester) async {
      await pumpPage(
        tester,
        _home(),
        repo: FakeMemoryRepository([
          _mem('old', _now.subtract(const Duration(days: 5)), title: '古いほう'),
          _mem('new', _now.subtract(const Duration(days: 1)), title: '新しいほう'),
        ]),
        liveIds: ['old', 'new'],
      );
      await tester.ensureVisible(_key('home_memory_banner_close'));
      await tester.tap(_key('home_memory_banner_close'));
      await tester.pumpAndSettle();
      expect(find.textContaining('古いほう', findRichText: true), findsWidgets);
      expect(find.textContaining('新しいほう', findRichText: true), findsNothing);
    });

    testWidgets('ボタンで投稿の画面へ（投稿先つき）・リンクで記録へ', (tester) async {
      await pumpPage(
        tester,
        _home(),
        repo: FakeMemoryRepository([recent]),
        liveIds: ['a'],
      );
      await tester.ensureVisible(_key('home_memory_banner_x'));
      await tester.tap(_key('home_memory_banner_x'));
      await tester.pumpAndSettle();
      expect(_routes.last, '/memories/a/share?target=x');
    });

    testWidgets('Instagram のボタンは target=ig', (tester) async {
      await pumpPage(
        tester,
        _home(),
        repo: FakeMemoryRepository([recent]),
        liveIds: ['a'],
      );
      await tester.ensureVisible(_key('home_memory_banner_ig'));
      await tester.tap(_key('home_memory_banner_ig'));
      await tester.pumpAndSettle();
      expect(_routes.last, '/memories/a/share?target=ig');
    });

    testWidgets('リンクは記録の画面へ', (tester) async {
      await pumpPage(
        tester,
        _home(),
        repo: FakeMemoryRepository([recent]),
        liveIds: ['a'],
      );
      await tester.ensureVisible(_key('home_memory_banner_open'));
      await tester.tap(_key('home_memory_banner_open'));
      await tester.pumpAndSettle();
      expect(_routes.last, '/memories/a');
    });

    testWidgets('読み込み中・記録なし・エラーは何も出ない（例外も出ない）', (tester) async {
      await pumpPage(tester, _home(), repo: _PendingRepo());
      expect(_key('home_memory_banner'), findsNothing);
      await pumpPage(tester, _home(), repo: FakeMemoryRepository());
      expect(_key('home_memory_banner'), findsNothing);
      await pumpPage(tester, _home(), repo: _ErrorRepo());
      expect(_key('home_memory_banner'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('座席の文字列が、カードのどこにも出ない', (tester) async {
      await pumpPage(
        tester,
        _home(),
        repo: FakeMemoryRepository([recent]),
        liveIds: ['a'],
      );
      expect(
        find.textContaining('SEAT-SECRET', findRichText: true),
        findsNothing,
      );
      expect(find.textContaining('A12', findRichText: true), findsNothing);
    });

    for (final w in [320.0, 360.0, 390.0, 430.0, 720.0, 1000.0]) {
      testWidgets('幅 $w・文字 1.3 倍・長いタイトルではみ出さない', (tester) async {
        await pumpPage(
          tester,
          _home(),
          repo: FakeMemoryRepository([
            _mem(
              'a',
              _now.subtract(const Duration(days: 1)),
              title: 'とても長いライブ名' * 8,
            ),
          ]),
          liveIds: ['a'],
          width: w,
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        expect(_key('home_memory_banner'), findsOneWidget);
      });
    }
  });

  group('メモリー一覧の「新しい記録」のカード', () {
    testWidgets('ホームのカードを閉じた記録でも、一覧の「新しい記録」のカードは残る', (tester) async {
      await pumpPage(
        tester,
        const MemoryListPage(),
        repo: FakeMemoryRepository([recent]),
        store: {'oshiashi.dismissedHomeBanners.u1': '["a"]'},
      );
      expect(_key('memory_list_recent_card'), findsOneWidget);
    });

    testWidgets('新しい記録は大きいカードで先頭に出て、同じ記録のグリッドのカードは出ない', (tester) async {
      await pumpPage(
        tester,
        const MemoryListPage(),
        repo: FakeMemoryRepository([
          recent,
          _mem('old', DateTime(2026, 10, 1, 18)),
        ]),
      );
      expect(_key('memory_list_recent_card'), findsOneWidget);
      expect(find.text('チケットを開いて、セトリと感想を書く'), findsOneWidget);
      expect(_key('memory_list_attended_a'), findsNothing);
      expect(_key('memory_list_attended_old'), findsOneWidget);
    });

    testWidgets('押すと記録の画面へ', (tester) async {
      await pumpPage(
        tester,
        const MemoryListPage(),
        repo: FakeMemoryRepository([recent]),
      );
      await tester.ensureVisible(_key('memory_list_recent_card'));
      await tester.tap(_key('memory_list_recent_card'));
      await tester.pumpAndSettle();
      expect(_routes.last, '/memories/a');
    });

    testWidgets('投稿済み・8日前・参戦予定だけなら、大きいカードは出ない', (tester) async {
      await pumpPage(
        tester,
        const MemoryListPage(),
        repo: FakeMemoryRepository([
          _mem('p', _now.subtract(const Duration(days: 1)), postedAt: _now),
          _mem('o', _now.subtract(const Duration(days: 8))),
          _mem('f', _now.add(const Duration(days: 2))),
        ]),
      );
      expect(_key('memory_list_recent_card'), findsNothing);
      expect(_key('memory_list_attended_p'), findsOneWidget);
      expect(_key('memory_list_attended_o'), findsOneWidget);
    });

    testWidgets('参戦済みが0件のときだけ、「記録する」の説明文。1件以上なら既存の説明', (tester) async {
      await pumpPage(
        tester,
        const MemoryListPage(),
        repo: FakeMemoryRepository([
          _mem('f', _now.add(const Duration(days: 2))),
        ]),
      );
      expect(
        find.text('参戦が終わったライブは、「記録する」を押すと、チケット風の記録が作られます。'),
        findsOneWidget,
      );
      expect(find.text('行ったライブの思い出です。'), findsNothing);
      await pumpPage(
        tester,
        const MemoryListPage(),
        repo: FakeMemoryRepository([recent]),
      );
      expect(find.text('行ったライブの思い出です。'), findsOneWidget);
      expect(find.text('参戦が終わったライブは、「記録する」を押すと、チケット風の記録が作られます。'), findsNothing);
    });

    for (final w in [320.0, 390.0, 720.0, 1000.0]) {
      testWidgets('幅 $w・文字 1.3 倍・長いタイトルではみ出さない', (tester) async {
        await pumpPage(
          tester,
          const MemoryListPage(),
          repo: FakeMemoryRepository([
            _mem(
              'a',
              _now.subtract(const Duration(days: 1)),
              title: 'とても長いライブ名' * 8,
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
