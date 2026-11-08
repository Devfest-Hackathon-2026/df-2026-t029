// 「まとめて編集して投稿」の画面（/memories/:performanceId/share）のテスト（Q3）。
// URL・保存・クリップボード・画像の作成は、すべて偽物に差し替える（本物の通信はしない）。
// 座席が、画像・文章・X の URL・クリップボードのどこにも出ないことを、目印の文字列で確かめる。
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/memory/share/memory_share_screen.dart';
import 'package:oshiashi/features/memory/share/share_providers_ui.dart';
import 'package:oshiashi/features/memory/share/share_ticket_view.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/live_memory.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/memory_providers.dart';
import 'package:oshiashi/providers/memory_ticket_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/providers/photo_pick_providers.dart';
import 'package:oshiashi/providers/photo_providers.dart';
import 'package:oshiashi/providers/share_providers.dart';
import 'package:oshiashi/services/google_photos_service.dart';
import 'package:oshiashi/services/photo_pick_ai.dart';
import 'package:oshiashi/utils/share_ticket.dart';

import 'google_photos_test_helpers.dart';
import 'live_test_helpers.dart';
import 'memory_form_page_test.dart' show FakeMemoryRepository;
import 'oshi_test_helpers.dart';
import 'photo_test_helpers.dart';
import 'public_memory_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

const _secretSeat = 'SEAT-SECRET-A12ブロック';

final _now = DateTime.utc(2026, 12, 20, 12);

class _ReactiveRepo extends FakeMemoryRepository {
  _ReactiveRepo(super.init);

  final _changes = StreamController<Map<String, LiveMemory>>.broadcast();

  @override
  Stream<Map<String, LiveMemory>> watchAll(String uid) async* {
    yield Map.of(store);
    yield* _changes.stream;
  }

  @override
  Future<void> update(String uid, LiveMemory memory) async {
    await super.update(uid, memory);
    _changes.add(Map.of(store));
  }

  /// 本物と同じく、postedAt が付いた記録が流れる（投稿した印を二度書かないことの確認用）
  @override
  Future<void> markPosted(String uid, String performanceId) async {
    await super.markPosted(uid, performanceId);
    final m = store[performanceId]!;
    store[performanceId] = LiveMemory(
      performanceId: m.performanceId,
      liveId: m.liveId,
      liveTitle: m.liveTitle,
      startAt: m.startAt,
      venue: m.venue,
      seat: m.seat,
      setlist: m.setlist,
      impression: m.impression,
      images: m.images,
      isPublic: m.isPublic,
      publicSeat: m.publicSeat,
      postedAt: DateTime.utc(2026, 12, 20, 12),
    );
    _changes.add(Map.of(store));
  }
}

class _PendingRepo extends FakeMemoryRepository {
  @override
  Stream<Map<String, LiveMemory>> watchAll(String uid) =>
      StreamController<Map<String, LiveMemory>>().stream;
}

LiveMemory _mem({
  List<String> setlist = const ['曲A', '曲B'],
  String? impression = '最高でした',
  String? seat = _secretSeat,
  DateTime? postedAt,
}) => LiveMemory(
  performanceId: 'a',
  liveId: 'la',
  liveTitle: 'ツアー2026',
  startAt: DateTime.utc(2026, 12, 19, 9),
  venue: '東京ドーム',
  seat: seat,
  setlist: setlist,
  impression: impression,
  postedAt: postedAt,
);

class _Env {
  late _ReactiveRepo repo;
  final opened = <Uri>[];
  bool openResult = true;
  final saved = <({Uint8List bytes, String name})>[];
  Object? saveError;
  final copied = <String>[];
  Object? copyError;
  int captures = 0;
  double? lastRatio;
  final photos = FakePhotoRepository();
  final publics = FakePublicMemoryRepository();
  late GoRouter router;
}

Future<_Env> pumpShare(
  WidgetTester tester, {
  LiveMemory? memory,
  bool missing = false,
  bool pending = false,
  String location = '/memories/a/share',
  double width = 390,
  double textScale = 1,
  bool disableAnimations = false,
  FakeMemoryRepository? repoOverride,
}) async {
  tester.view.physicalSize = Size(width, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final env = _Env()..repo = _ReactiveRepo([if (!missing) memory ?? _mem()]);
  final FakeMemoryRepository repo = pending ? _PendingRepo() : env.repo;
  final lives = FakeLiveRepository(
    lives: const [
      Live(id: 'la', title: 'ツアー2026', groupIds: ['g1']),
    ],
  );
  final api = FakeGooglePhotosApi(clock: () => _now);
  env.router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/memories/:id/share',
        builder: (_, s) => MemoryShareScreen(
          performanceId: s.pathParameters['id']!,
          initialTarget: shareTargetFromQuery(s.uri.queryParameters['target']),
        ),
      ),
      GoRoute(
        path: '/memories/:id',
        builder: (_, _) => const Text('route:detail'),
      ),
      GoRoute(path: '/memories', builder: (_, _) => const Text('route:list')),
    ],
  );
  addTearDown(env.router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        memoryRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(DateTime.utc(2026, 12, 20, 12)),
        liveRepositoryProvider.overrideWithValue(lives),
        oshiRepositoryProvider.overrideWithValue(
          FakeOshiRepository([oshi('g1', 'ひかり')]),
        ),
        photoRepositoryProvider.overrideWithValue(env.photos),
        googlePhotosApiProvider.overrideWithValue(api),
        photoPickAiProvider.overrideWithValue(FakePhotoPickAi()),
        memoryEditorProvider.overrideWithValue(
          MemoryEditor(
            uid: 'u1',
            memories: repo,
            photos: env.photos,
            publics: env.publics,
            lives: lives,
            displayName: () async => 'ハンドル',
          ),
        ),
        shareUrlOpenerProvider.overrideWithValue((url) async {
          env.opened.add(url);
          return env.openResult;
        }),
        shareImageSaverProvider.overrideWithValue((bytes, name) async {
          if (env.saveError != null) throw env.saveError!;
          env.saved.add((bytes: bytes, name: name));
        }),
        shareClipboardProvider.overrideWithValue((text) async {
          if (env.copyError != null) throw env.copyError!;
          env.copied.add(text);
        }),
        shareCaptureProvider.overrideWithValue((key, ratio) async {
          env.captures++;
          env.lastRatio = ratio;
          return validPng;
        }),
        sharePhotoFetcherProvider.overrideWithValue((url) async => validPng),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(
        routerConfig: env.router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
      ),
    ),
  );
  if (pending) {
    // 読み込み中はスピナーが回り続けるので、pumpAndSettle は使わない
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  } else {
    await tester.pumpAndSettle();
  }
  return env;
}

/// Instagram のタブを押した状態で開く（?target=ig の経路は、別のテストで確かめる）
Future<_Env> pumpShareIg(
  WidgetTester tester, {
  LiveMemory? memory,
  double width = 390,
  double textScale = 1,
}) async {
  final env = await pumpShare(
    tester,
    memory: memory,
    width: width,
    textScale: textScale,
  );
  await tapKey(tester, 'share_tab_ig');
  return env;
}

Future<void> tapKey(WidgetTester tester, String k) async {
  await tester.ensureVisible(_key(k));
  await tester.pumpAndSettle();
  await tester.tap(_key(k));
  await tester.pumpAndSettle();
}

String _caption(WidgetTester tester) =>
    tester.widget<TextField>(_key('share_caption')).controller!.text;

void main() {
  group('4状態', () {
    testWidgets('表示: 上のバーの題・タブ・プレビュー', (tester) async {
      await pumpShare(tester);
      expect(find.text('投稿をまとめて編集'), findsOneWidget);
      expect(_key('share_tab_x'), findsOneWidget);
      expect(_key('share_tab_ig'), findsOneWidget);
      expect(_key('share_preview'), findsOneWidget);
    });

    testWidgets('記録が無い', (tester) async {
      await pumpShare(tester, missing: true);
      expect(_key('share_not_found'), findsOneWidget);
      expect(find.text('この記録は見つかりませんでした'), findsOneWidget);
    });

    testWidgets('読み込み中', (tester) async {
      await tester.runAsync(() async {});
      tester.view.physicalSize = const Size(390, 900);
      await pumpShare(tester, pending: true);
      expect(_key('share_loading'), findsOneWidget);
    });
  });

  group('保存用の画像の部分', () {
    testWidgets('画面の外にあり、見える部品に重ならない（幅 390・X の横長）', (tester) async {
      await pumpShare(tester);
      final views = find.byType(ShareTicketView);
      expect(views, findsNWidgets(2), reason: '見える1つ（プレビュー）と、保存用の1つ');
      final preview = tester.getRect(views.first);
      final capture = tester.getRect(views.last);
      expect(capture.right, lessThanOrEqualTo(0), reason: '画面の左の外');
      expect(capture.width, 800, reason: 'X の横長は 1600 / 2');
      expect(preview.left, greaterThanOrEqualTo(0));
      expect(preview.overlaps(capture), isFalse);
      // 画面の中のタブ・文章の欄・ボタンは、保存用の部分に覆われない
      for (final k in ['share_tab_x', 'share_caption']) {
        expect(tester.getRect(_key(k)).left, greaterThanOrEqualTo(0));
      }
    });

    testWidgets('Instagram・正方形でも、画面の外', (tester) async {
      await pumpShareIg(tester);
      final capture = tester.getRect(find.byType(ShareTicketView).last);
      expect(capture.right, lessThanOrEqualTo(0));
    });
  });

  group('画像の形・デザイン・背景色（S3）', () {
    ShareState shareState(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(MemoryShareScreen)),
    ).read(shareProvider('a'));

    Future<void> openLook(WidgetTester tester) => tapKey(tester, 'share_look');

    testWidgets('折りたたみを開くと、形・デザイン・背景が出る。開いたまま操作できる', (tester) async {
      await pumpShare(tester);
      await openLook(tester);
      expect(find.text('画像の形・デザイン・背景色を変える'), findsOneWidget);
      for (final k in [
        'share_format_0',
        'share_format_1',
        'share_design_ticket',
        'share_design_photo',
        'share_bg_0',
        'share_bg_1',
        'share_bg_2',
        'share_bg_3',
        'share_bg_4',
        'share_bg_5',
        'share_bg_6',
      ]) {
        expect(_key(k), findsOneWidget, reason: k);
      }
      await tapKey(tester, 'share_design_photo');
      // 操作したあとも開いたまま
      expect(tester.getSize(_key('share_bg_0')).height, greaterThan(0));
    });

    testWidgets('形: 投稿先の形がすべて出る。選ぶとプレビューの比率が変わる', (tester) async {
      await pumpShare(tester);
      await openLook(tester);
      expect(find.text('横長 16:9'), findsOneWidget);
      expect(find.text('正方形 1:1'), findsOneWidget);
      var size = tester.getSize(find.byType(ShareTicketView).first);
      expect(size.width / size.height, closeTo(16 / 9, 0.01));
      await tapKey(tester, 'share_format_1');
      expect(shareState(tester).config.formatIndex, 1);
      size = tester.getSize(find.byType(ShareTicketView).first);
      expect(size.width / size.height, closeTo(1, 0.01));
    });

    testWidgets('Instagram の形（フィード・ストーリー）', (tester) async {
      await pumpShareIg(tester);
      await openLook(tester);
      expect(find.text('フィード 4:5'), findsOneWidget);
      expect(find.text('ストーリー 9:16'), findsOneWidget);
      expect(_key('share_format_2'), findsNothing);
      await tapKey(tester, 'share_format_1');
      final size = tester.getSize(find.byType(ShareTicketView).first);
      expect(size.width / size.height, closeTo(9 / 16, 0.01));
    });

    testWidgets('デザイン: 切り替えるとプレビューの絵が変わる（チケットだけ「LIVE TICKET」）', (tester) async {
      await pumpShare(tester);
      expect(find.textContaining('LIVE TICKET'), findsWidgets);
      await openLook(tester);
      await tapKey(tester, 'share_design_photo');
      expect(shareState(tester).config.design, ShareDesign.photoMain);
      expect(find.textContaining('LIVE TICKET'), findsNothing);
      await tapKey(tester, 'share_design_ticket');
      expect(find.textContaining('LIVE TICKET'), findsWidgets);
    });

    testWidgets('背景: 7色を選べる（黒・コラージュは無い）。押せる範囲は 44px 以上', (tester) async {
      await pumpShare(tester);
      await openLook(tester);
      expect(_key('share_design_collage'), findsNothing);
      expect(_key('share_bg_7'), findsNothing);
      for (var i = 0; i < 7; i++) {
        final size = tester.getSize(_key('share_bg_$i'));
        expect(size.width, greaterThanOrEqualTo(44), reason: 'bg $i');
        expect(size.height, greaterThanOrEqualTo(44), reason: 'bg $i');
        await tapKey(tester, 'share_bg_$i');
        expect(shareState(tester).config.backgroundIndex, i);
      }
    });

    testWidgets('幅 320・文字 1.3 倍: 背景 7 色が折り返し、すべて 44px 以上で、はみ出さない', (
      tester,
    ) async {
      await pumpShare(tester, width: 320, textScale: 1.3);
      await openLook(tester);
      for (var i = 0; i < 7; i++) {
        final r = tester.getRect(_key('share_bg_$i'));
        expect(r.width, greaterThanOrEqualTo(44), reason: 'bg $i');
        expect(r.height, greaterThanOrEqualTo(44), reason: 'bg $i');
        expect(r.right, lessThanOrEqualTo(320), reason: 'bg $i は画面の中');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('投稿先ごとに別々: X の設定は Instagram に持ち越さない', (tester) async {
      await pumpShare(tester);
      await openLook(tester);
      await tapKey(tester, 'share_design_photo');
      await tapKey(tester, 'share_bg_6');
      await tapKey(tester, 'share_format_1');
      await tapKey(tester, 'share_tab_ig');
      var c = shareState(tester).config;
      expect(c.design, ShareDesign.ticket);
      expect(c.backgroundIndex, 0);
      expect(c.formatIndex, 0);
      await tapKey(tester, 'share_design_photo');
      await tapKey(tester, 'share_tab_x');
      c = shareState(tester).config;
      expect(c.design, ShareDesign.photoMain);
      expect(c.backgroundIndex, 6);
      // 投稿先を切り替えると、その投稿先の形は1つめに戻る（開き直しと同じ約束）
      expect(c.formatIndex, 0);
    });

    testWidgets('文章は変わらない（デザイン・背景・形は画像だけの設定）', (tester) async {
      await pumpShare(tester);
      final before = _caption(tester);
      await openLook(tester);
      await tapKey(tester, 'share_design_photo');
      await tapKey(tester, 'share_bg_2');
      await tapKey(tester, 'share_format_1');
      expect(_caption(tester), before);
    });

    testWidgets('保存する画像は、選んだ形の幅÷2・pixelRatio 2。座席は出ない', (tester) async {
      final env = await pumpShare(tester);
      await openLook(tester);
      await tapKey(tester, 'share_format_1');
      await tapKey(tester, 'share_design_photo');
      await tapKey(tester, 'share_save_image');
      expect(env.lastRatio, 2);
      final capture = tester.getRect(find.byType(ShareTicketView).last);
      expect(capture.width, 540, reason: '正方形 1080 / 2');
      expect(capture.height, 540);
      expect(capture.right, lessThanOrEqualTo(0));
      expect(env.saved.single.name, 'oshiashi_a_x.png');
      expect(find.textContaining('SEAT', findRichText: true), findsNothing);
    });

    testWidgets('動きを減らす設定では、折りたたみが動かずに開く', (tester) async {
      await pumpShare(tester, disableAnimations: true);
      await tester.ensureVisible(_key('share_look'));
      await tester.pumpAndSettle();
      await tester.tap(_key('share_look'));
      await tester.pump();
      expect(tester.getSize(_key('share_bg_0')).height, greaterThan(0));
      expect(
        tester.getSize(_key('share_design_ticket')).height,
        greaterThan(0),
      );
    });

    for (final w in [320.0, 360.0, 390.0, 430.0, 720.0, 1000.0]) {
      testWidgets('幅 $w・文字 1.3 倍: 開いて操作してもはみ出さない', (tester) async {
        await pumpShare(tester, width: w, textScale: 1.3);
        await openLook(tester);
        for (final k in [
          'share_design_photo',
          'share_format_1',
          'share_bg_6',
        ]) {
          await tapKey(tester, k);
          final e = tester.takeException();
          expect(e, isNull, reason: '$k: $e');
        }
      });
    }
  });

  group('投稿先', () {
    testWidgets('既定は X: Xの動作のボタンがある', (tester) async {
      await pumpShare(tester);
      expect(_key('share_post_x'), findsOneWidget);
      expect(_key('share_copy_caption'), findsNothing);
      expect(
        find.textContaining('のせる内容は、XとInstagramで別々に決められます'),
        findsOneWidget,
      );
    });

    testWidgets('Instagram のタブで3ステップに変わる', (tester) async {
      await pumpShare(tester);
      await tapKey(tester, 'share_tab_ig');
      expect(_key('share_post_x'), findsNothing);
      expect(_key('share_save_image'), findsOneWidget);
      expect(_key('share_copy_caption'), findsOneWidget);
      expect(_key('share_open_ig'), findsOneWidget);
    });

    // 回帰: ?target=ig が効かず X で開いていた（状態が autoDispose で捨てられていた）
    testWidgets('?target=ig で、Instagram を選んだ状態で開く', (tester) async {
      await pumpShare(tester, location: '/memories/a/share?target=ig');
      expect(_key('share_open_ig'), findsOneWidget);
    });

    testWidgets('開き直すと、投稿先は X・形は1つめに戻る', (tester) async {
      final env = await pumpShare(tester);
      await tapKey(tester, 'share_tab_ig');
      env.router.go('/memories/a');
      await tester.pumpAndSettle();
      env.router.go('/memories/a/share');
      await tester.pumpAndSettle();
      expect(_key('share_post_x'), findsOneWidget);
      expect(_key('share_open_ig'), findsNothing);
    });

    testWidgets('投稿先ごとに文章が別（X の手直しは Instagram に持ち越さない）', (tester) async {
      await pumpShare(tester);
      await tester.enterText(_key('share_caption'), 'Xだけの文章');
      await tester.pumpAndSettle();
      await tapKey(tester, 'share_tab_ig');
      expect(_caption(tester), isNot('Xだけの文章'));
      await tapKey(tester, 'share_tab_x');
      expect(_caption(tester), 'Xだけの文章');
    });
  });

  group('文章', () {
    testWidgets('X の既定: 題・日付と会場・感想・タグ。セトリは入らない', (tester) async {
      await pumpShare(tester);
      expect(
        _caption(tester),
        '【参戦記録】ツアー2026\n'
        '2026/12/19(土) @ 東京ドーム\n'
        '\n'
        '最高でした\n'
        '\n'
        '#ひかり #おしあし',
      );
    });

    testWidgets('Instagram の既定: 感想は画像にのるので、文章には入らない', (tester) async {
      await pumpShareIg(tester);
      expect(_caption(tester), isNot(contains('最高でした')));
      expect(_caption(tester), contains('2026/12/19(土) @ 東京ドーム'));
    });

    testWidgets('文章のチップのオンオフで文章が変わる', (tester) async {
      await pumpShare(tester);
      await tapKey(tester, 'share_chip_cap_setlist');
      expect(_caption(tester), contains('セトリ：曲A / 曲B'));
      await tapKey(tester, 'share_chip_cap_setlist');
      expect(_caption(tester), isNot(contains('セトリ')));
      await tapKey(tester, 'share_chip_cap_memo');
      expect(_caption(tester), isNot(contains('最高でした')));
      await tapKey(tester, 'share_chip_cap_tags');
      expect(_caption(tester), isNot(contains('#おしあし')));
      await tapKey(tester, 'share_chip_cap_info');
      expect(_caption(tester), '【参戦記録】ツアー2026');
    });

    testWidgets('文章を直すと「自動で作った文章に戻す」が出て、押すと戻る', (tester) async {
      await pumpShare(tester);
      expect(_key('share_caption_reset'), findsNothing);
      await tester.enterText(_key('share_caption'), '手直しした文章');
      await tester.pumpAndSettle();
      expect(_key('share_caption_reset'), findsOneWidget);
      expect(_caption(tester), '手直しした文章');
      await tapKey(tester, 'share_caption_reset');
      expect(_caption(tester), startsWith('【参戦記録】ツアー2026'));
      expect(_key('share_caption_reset'), findsNothing);
    });

    testWidgets('X の文字数の表示（重み付き 280）', (tester) async {
      await pumpShare(tester);
      await tester.enterText(_key('share_caption'), 'あ' * 140);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(_key('share_caption_count')).data,
        '280 / 280',
      );
    });

    testWidgets('X で 141 字を超えると、赤く注意が出て「Xで投稿画面を開く」が押せない', (tester) async {
      final env = await pumpShare(tester);
      await tester.enterText(_key('share_caption'), 'あ' * 141);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(_key('share_caption_count')).data,
        '282 / 280（文字数が多すぎます）',
      );
      await tester.ensureVisible(_key('share_post_x'));
      await tester.tap(_key('share_post_x'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(env.opened, isEmpty);
    });

    testWidgets('Instagram は素の文字数 2200', (tester) async {
      await pumpShareIg(tester);
      await tester.enterText(_key('share_caption'), 'あ' * 2200);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(_key('share_caption_count')).data,
        '2200 / 2200',
      );
    });
  });

  group('X の動作', () {
    testWidgets('投稿画面を開く: URL に文章が入る。画像は付かない。投稿した印が付く', (tester) async {
      final env = await pumpShare(tester);
      await tapKey(tester, 'share_post_x');
      final url = env.opened.single;
      expect(url.scheme, 'https');
      expect(url.host, 'x.com');
      expect(url.path, '/intent/post');
      expect(url.queryParameters['text'], _caption(tester));
      expect(url.queryParameters.keys, ['text']);
      expect(env.repo.postedIds, ['a']);
    });

    testWidgets('画像を保存しなくても、押せる', (tester) async {
      final env = await pumpShare(tester);
      expect(env.saved, isEmpty);
      await tapKey(tester, 'share_post_x');
      expect(env.opened, hasLength(1));
    });

    testWidgets('開けなかったら文言を出し、投稿した印は付けない', (tester) async {
      final env = await pumpShare(tester);
      env.openResult = false;
      await tapKey(tester, 'share_post_x');
      expect(find.text('ページを開けませんでした。もう一度お試しください'), findsOneWidget);
      expect(env.repo.postedIds, isEmpty);
    });

    testWidgets('投稿した印の保存に失敗しても、操作は止まらない', (tester) async {
      final env = await pumpShare(tester);
      env.repo.error = Exception('x');
      await tapKey(tester, 'share_post_x');
      expect(env.opened, hasLength(1));
      expect(tester.takeException(), isNull);
      expect(find.text('ページを開けませんでした。もう一度お試しください'), findsNothing);
    });

    testWidgets('すでに投稿済みの記録では、投稿した印を書き直さない', (tester) async {
      final env = await pumpShare(tester, memory: _mem(postedAt: _now));
      await tapKey(tester, 'share_post_x');
      expect(env.opened, hasLength(1));
      expect(env.repo.postedIds, isEmpty);
    });

    testWidgets('画像を保存: ファイル名・PNG・トースト・投稿した印', (tester) async {
      final env = await pumpShare(tester);
      await tapKey(tester, 'share_save_image');
      expect(env.saved.single.name, 'oshiashi_a_x.png');
      expect(env.saved.single.bytes, validPng);
      expect(env.captures, 1);
      expect(find.text('画像を保存しました'), findsOneWidget);
      expect(env.repo.postedIds, ['a']);
    });

    testWidgets('画像の保存に失敗したら文言を出し、投稿した印は付けない', (tester) async {
      final env = await pumpShare(tester);
      env.saveError = Exception('x');
      await tapKey(tester, 'share_save_image');
      expect(find.text('保存できませんでした。もう一度お試しください'), findsOneWidget);
      expect(env.repo.postedIds, isEmpty);
    });
  });

  group('Instagram の3ステップ', () {
    Future<_Env> ig(WidgetTester tester) => pumpShareIg(tester);

    testWidgets('画像を保存 → 文章をコピー → Instagram を開く', (tester) async {
      final env = await ig(tester);
      await tapKey(tester, 'share_save_image');
      expect(env.saved.single.name, 'oshiashi_a_ig.png');
      await tapKey(tester, 'share_copy_caption');
      expect(env.copied.single, _caption(tester));
      expect(find.text('文章をコピーしました'), findsOneWidget);
      await tapKey(tester, 'share_open_ig');
      expect(env.opened.single.toString(), 'https://www.instagram.com/');
      expect(env.repo.postedIds, ['a']);
    });

    testWidgets('③は①②の前でも押せる', (tester) async {
      final env = await ig(tester);
      await tapKey(tester, 'share_open_ig');
      expect(env.opened, hasLength(1));
    });

    testWidgets('コピーに失敗したら文言', (tester) async {
      final env = await ig(tester);
      env.copyError = Exception('x');
      await tapKey(tester, 'share_copy_caption');
      expect(find.text('コピーできませんでした。文章を長押ししてコピーしてください'), findsOneWidget);
      expect(env.copied, isEmpty);
    });

    testWidgets('コピーだけでは、投稿した印は付かない', (tester) async {
      final env = await ig(tester);
      await tapKey(tester, 'share_copy_caption');
      expect(env.repo.postedIds, isEmpty);
    });
  });

  group('編集シート', () {
    testWidgets('セトリのペン: シートが開き、決定で記録に保存。座席は消えない', (tester) async {
      final env = await pumpShare(tester);
      await tapKey(tester, 'share_chip_edit_setlist');
      expect(_key('share_edit_sheet'), findsOneWidget);
      await tester.enterText(_key('share_edit_input'), '新曲A\n\n 新曲B ');
      await tester.pumpAndSettle();
      await tapKey(tester, 'share_edit_done');
      expect(_key('share_edit_sheet'), findsNothing);
      expect(env.repo.store['a']!.setlist, ['新曲A', '新曲B']);
      expect(env.repo.store['a']!.seat, _secretSeat, reason: '座席を消さない');
      expect(env.repo.store['a']!.impression, '最高でした');
    });

    testWidgets('感想のペン: 決定で保存。座席は消えない', (tester) async {
      final env = await pumpShare(tester);
      await tapKey(tester, 'share_chip_edit_memo');
      await tester.enterText(_key('share_edit_input'), '最高の夜だった');
      await tester.pumpAndSettle();
      await tapKey(tester, 'share_edit_done');
      expect(env.repo.store['a']!.impression, '最高の夜だった');
      expect(env.repo.store['a']!.seat, _secretSeat);
      expect(env.repo.store['a']!.setlist, ['曲A', '曲B']);
      // 文章も新しい内容になる
      expect(_caption(tester), contains('最高の夜だった'));
    });

    testWidgets('プレビューの部分（セトリ・感想）をタップしても開く', (tester) async {
      await pumpShare(tester);
      await tapKey(tester, 'share_part_setlist');
      expect(_key('share_edit_sheet'), findsOneWidget);
    });

    testWidgets('保存に失敗したら SnackBar。シートは開いたまま', (tester) async {
      final env = await pumpShare(tester);
      await tapKey(tester, 'share_chip_edit_memo');
      await tester.enterText(_key('share_edit_input'), '直した');
      await tester.pumpAndSettle();
      env.repo.error = Exception('x');
      await tapKey(tester, 'share_edit_done');
      expect(find.text('保存できませんでした。もう一度お試しください'), findsOneWidget);
      expect(_key('share_edit_sheet'), findsOneWidget);
      expect(env.repo.store['a']!.impression, '最高でした');
    });

    testWidgets('写真のペン: 「写真を直す」シートが開く', (tester) async {
      await pumpShare(tester);
      await tapKey(tester, 'share_chip_edit_photo');
      expect(_key('photo_sheet'), findsOneWidget);
    });
  });

  group('座席が SNS に出ない（目印の文字列）', () {
    Future<void> expectNoSeat(WidgetTester tester, _Env env) async {
      expect(
        find.textContaining('SEAT-SECRET', findRichText: true),
        findsNothing,
      );
      expect(find.textContaining('A12ブロック', findRichText: true), findsNothing);
      expect(_caption(tester), isNot(contains('SEAT')));
      for (final u in env.opened) {
        expect(Uri.decodeFull(u.toString()), isNot(contains('SEAT')));
        expect(u.toString(), isNot(contains('A12')));
      }
      for (final c in env.copied) {
        expect(c, isNot(contains('SEAT')));
      }
    }

    for (final target in ['x', 'ig']) {
      testWidgets('$target: 画面（プレビュー・保存する画像の部分）・文章・URL・コピーに出ない', (
        tester,
      ) async {
        final env = target == 'x'
            ? await pumpShare(tester)
            : await pumpShareIg(tester);
        await expectNoSeat(tester, env);
        // すべての文章のチップをオンにしても出ない
        for (final name in ['info', 'setlist', 'memo', 'tags']) {
          final k = 'share_chip_cap_$name';
          await tapKey(tester, k);
        }
        await expectNoSeat(tester, env);
        if (target == 'x') {
          await tapKey(tester, 'share_post_x');
        } else {
          await tapKey(tester, 'share_copy_caption');
          await tapKey(tester, 'share_open_ig');
        }
        await tapKey(tester, 'share_save_image');
        await expectNoSeat(tester, env);
        expect(env.opened.isNotEmpty || env.copied.isNotEmpty, isTrue);
      });
    }

    testWidgets('セトリ・感想を保存しても、座席は記録に残り、画面には出ない', (tester) async {
      final env = await pumpShare(tester);
      await tapKey(tester, 'share_chip_edit_setlist');
      await tester.enterText(_key('share_edit_input'), '曲Z');
      await tester.pumpAndSettle();
      await tapKey(tester, 'share_edit_done');
      expect(env.repo.store['a']!.seat, _secretSeat);
      await expectNoSeat(tester, env);
    });
  });

  group('はみ出し', () {
    for (final w in [320.0, 360.0, 390.0, 430.0, 720.0, 1000.0]) {
      for (final scale in [1.0, 1.3]) {
        // 回帰: タブ（X / Instagram）が狭い幅・文字 1.3 倍で右にはみ出していた
        testWidgets('幅 $w・文字 $scale 倍・長い内容（X と Instagram）', (tester) async {
          final memory = _mem(
            setlist: List.generate(20, (i) => '長い曲名' * 4 + '$i'),
            impression: '長い感想' * 50,
          );
          await pumpShare(tester, memory: memory, width: w, textScale: scale);
          var e = tester.takeException();
          expect(e, isNull, reason: '$e');
          await tapKey(tester, 'share_tab_ig');
          e = tester.takeException();
          expect(e, isNull, reason: '$e');
        });
      }
    }
  });
}
