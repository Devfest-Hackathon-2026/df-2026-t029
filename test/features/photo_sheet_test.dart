// 「写真を直す」シートと同意のダイアログのテスト（Q3）。
// 偽の GooglePhotosApi・偽の PhotoPickAi を使い、本物の Google・Gemini・ネットワークは呼ばない。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/photos/photos_sheet.dart';
import 'package:oshiashi/features/memory/ticket/ticket_widgets.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/live_memory.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/memory_providers.dart';
import 'package:oshiashi/providers/memory_ticket_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/providers/photo_pick_providers.dart';
import 'package:oshiashi/providers/photo_providers.dart';
import 'package:oshiashi/services/google_photos_service.dart';
import 'package:oshiashi/services/photo_pick_ai.dart';

import 'google_photos_test_helpers.dart';
import 'live_test_helpers.dart';
import 'memory_form_page_test.dart' show FakeMemoryRepository;
import 'oshi_test_helpers.dart';
import 'photo_test_helpers.dart';
import 'public_memory_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

final _now = DateTime.utc(2026, 12, 20, 12);

LiveMemory _mem({List<String> images = const []}) => LiveMemory(
  performanceId: 'p1',
  liveId: 'l1',
  liveTitle: 'ツアー',
  startAt: DateTime.utc(2026, 12, 19, 9),
  venue: '東京ドーム',
  seat: 'SEAT-SECRET-A12',
  setlist: const ['曲1'],
  images: images,
);

class _Env {
  final api = FakeGooglePhotosApi(
    clock: () => DateTime.utc(2026, 12, 20, 12),
    items: [fakeItem('a'), fakeItem('b'), fakeItem('c'), fakeItem('d')],
  )..imageBytes = validPng;
  final ai = FakePhotoPickAi();
  final photos = FakePhotoRepository();
  final publics = FakePublicMemoryRepository();
  late FakeMemoryRepository repo;
  final launched = <String>[];
}

Future<_Env> pumpSheet(
  WidgetTester tester, {
  LiveMemory? memory,
  bool consented = false,
  double width = 390,
  double textScale = 1,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final m = memory ?? _mem();
  final env = _Env()..repo = FakeMemoryRepository([m]);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/url_launcher'),
    (call) async {
      if (call.method == 'launch') {
        env.launched.add((call.arguments as Map)['url'] as String);
      }
      return true;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      null,
    ),
  );
  final lives = FakeLiveRepository(
    lives: const [
      Live(id: 'l1', title: 'ツアー', groupIds: ['g1']),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        googlePhotosApiProvider.overrideWithValue(env.api),
        photoPickAiProvider.overrideWithValue(env.ai),
        photoPickClockProvider.overrideWithValue(() => _now),
        photoRepositoryProvider.overrideWithValue(env.photos),
        memoryRepositoryProvider.overrideWithValue(env.repo),
        liveRepositoryProvider.overrideWithValue(lives),
        oshiRepositoryProvider.overrideWithValue(
          FakeOshiRepository([oshi('g1', 'ひかり')]),
        ),
        memoryEditorProvider.overrideWithValue(
          MemoryEditor(
            uid: 'u1',
            memories: env.repo,
            photos: env.photos,
            publics: env.publics,
            lives: lives,
            displayName: () async => 'ハンドル',
          ),
        ),
        if (consented)
          googlePhotosConsentedProvider.overrideWith(() => _Consented()),
      ],
      retry: (_, _) => null,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                key: const Key('open_sheet'),
                onPressed: () => showPhotosSheet(context, memory: m),
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(_key('open_sheet'));
  await tester.pumpAndSettle();
  return env;
}

class _Consented extends ConsentNotifier {
  @override
  bool build() => true;
}

Future<void> tapKey(WidgetTester tester, String k) async {
  await tester.ensureVisible(_key(k));
  await tester.pumpAndSettle();
  await tester.tap(_key(k));
  await tester.pumpAndSettle();
}

/// 同意 → 認可 → 「Googleフォトを開く」まで進める
Future<void> connectAndOpen(WidgetTester tester) async {
  await tapKey(tester, 'photo_connect_button');
  await tapKey(tester, 'google_photos_consent_yes');
}

/// 「Googleフォトを開く」を押して、選び終わるまで進める
Future<void> openPickerAndWait(WidgetTester tester) async {
  await tapKey(tester, 'photo_open_picker');
  // 選択を待つ → 縮小版 → Gemini の非同期を進める
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
}

void main() {
  group('状態①: つないでいない・写真0枚', () {
    testWidgets('つなぐ・端末から追加の2つが出る。「写真を直す」「決定」', (tester) async {
      await pumpSheet(tester);
      expect(_key('photo_sheet'), findsOneWidget);
      expect(find.text('写真を直す'), findsOneWidget);
      expect(find.text('Googleフォトとつなぐと、おしあしが写真を選びます'), findsOneWidget);
      expect(
        find.text('Googleフォトの画面で、公演の日に撮った写真をまとめて選ぶと、その中から、おしあしがいい写真を選びます。'),
        findsOneWidget,
      );
      expect(_key('photo_connect_button'), findsOneWidget);
      expect(_key('photo_manual_add'), findsOneWidget);
      expect(find.text('つながずに、写真を自分で追加する'), findsOneWidget);
      expect(_key('photo_sheet_done'), findsOneWidget);
    });

    testWidgets('説明の1行（記録に残る写真・投稿の写真は別）が出る', (tester) async {
      await pumpSheet(tester);
      expect(_key('photo_sheet_note'), findsOneWidget);
      expect(
        tester.widget<Text>(_key('photo_sheet_note')).data,
        'ここで選んだ写真が、記録に残ります。SNSに投稿する写真は、投稿の編集画面で別に選べます。',
      );
    });

    testWidgets('「とじる」で、変更せずに閉じる', (tester) async {
      final env = await pumpSheet(tester);
      await tapKey(tester, 'photo_sheet_close');
      expect(_key('photo_sheet'), findsNothing);
      expect(env.repo.calls, isEmpty);
      expect(env.api.calls, isEmpty);
    });

    testWidgets('Esc で閉じる', (tester) async {
      await pumpSheet(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_key('photo_sheet'), findsNothing);
    });

    testWidgets('写真が無いまま「決定」すると、空のまま保存して閉じる', (tester) async {
      final env = await pumpSheet(tester);
      await tapKey(tester, 'photo_sheet_done');
      expect(_key('photo_sheet'), findsNothing);
      expect(env.repo.store['p1']!.images, isEmpty);
    });
  });

  group('同意のダイアログ', () {
    testWidgets('最初に押すと出る。本文の5項目・ボタン', (tester) async {
      await pumpSheet(tester);
      await tapKey(tester, 'photo_connect_button');
      expect(_key('google_photos_consent'), findsOneWidget);
      expect(find.text('Googleフォトとつなぎますか？'), findsOneWidget);
      for (final t in [
        '写真を読み取るだけです。変更や削除はしません。',
        'Googleフォトの画面で、あなたが選んだ写真だけを使います。ライブラリ全体は見ません。',
        '選んだ写真は、AI（Gemini）に送って、よく写っている写真を選びます。',
        '記録に入れた写真だけを、おしあしに保存します。',
        'やめたいときは、Googleアカウントの設定（Googleのサービスにアクセスできるアプリ）から解除できます。',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('今はしない'), findsOneWidget);
      expect(find.text('つなぐ'), findsOneWidget);
    });

    /// 同意のダイアログの透明度（出すアニメーションの途中なら 1 未満）
    double dialogOpacity(WidgetTester tester) => tester
        .widgetList<FadeTransition>(
          find.ancestor(
            of: _key('google_photos_consent'),
            matching: find.byType(FadeTransition),
          ),
        )
        .map((f) => f.opacity.value)
        .reduce((a, b) => a < b ? a : b);

    testWidgets('動きを減らす設定では、ダイアログは動かずに出る', (tester) async {
      await pumpSheet(tester, disableAnimations: true);
      await tester.tap(_key('photo_connect_button'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(dialogOpacity(tester), 1.0);
    });

    testWidgets('設定が無ければ、ダイアログは出る途中の透明度がある（比較）', (tester) async {
      await pumpSheet(tester);
      await tester.tap(_key('photo_connect_button'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(dialogOpacity(tester), lessThan(1.0));
    });

    testWidgets('「今はしない」: 閉じるだけで、認可は始めない。状態①のまま', (tester) async {
      final env = await pumpSheet(tester);
      await tapKey(tester, 'photo_connect_button');
      await tapKey(tester, 'google_photos_consent_no');
      expect(_key('google_photos_consent'), findsNothing);
      expect(env.api.calls, isEmpty);
      expect(_key('photo_connect_button'), findsOneWidget);
      // 同意の印も付かない（もう一度押すと、またダイアログが出る）
      await tapKey(tester, 'photo_connect_button');
      expect(_key('google_photos_consent'), findsOneWidget);
    });

    testWidgets('「つなぐ」: 認可から始まり、「Googleフォトを開く」の待ちになる', (tester) async {
      final env = await pumpSheet(tester);
      await connectAndOpen(tester);
      expect(env.api.calls.first, 'authorize');
      expect(_key('photo_open_picker'), findsOneWidget);
      expect(
        find.text('Googleフォトを開いて、公演の日に撮った写真を選び（最大30枚）、「完了」を押してください。'),
        findsOneWidget,
      );
      expect(_key('photo_cancel'), findsOneWidget);
    });

    testWidgets('同じタブで2回目以降は、ダイアログなしで認可へ進む', (tester) async {
      final env = await pumpSheet(tester);
      await connectAndOpen(tester);
      await tapKey(tester, 'photo_cancel');
      expect(_key('photo_reselect'), findsOneWidget);
      env.api.calls.clear();
      await tapKey(tester, 'photo_reselect');
      expect(_key('google_photos_consent'), findsNothing);
      expect(env.api.calls.first, 'authorize');
      expect(_key('photo_open_picker'), findsOneWidget);
    });

    testWidgets('つなぎ済み（このタブで同意済み）なら、最初からダイアログなし', (tester) async {
      final env = await pumpSheet(tester, consented: true);
      await tapKey(tester, 'photo_reselect');
      expect(_key('google_photos_consent'), findsNothing);
      expect(env.api.calls.first, 'authorize');
    });
  });

  group('つなぐ流れ', () {
    testWidgets('認可を閉じた → エラーの文言。例外の中身は出ない', (tester) async {
      final env = await pumpSheet(tester);
      env.api.authorizeError = const GooglePhotosException(
        GooglePhotosFailure.cancelled,
      );
      await connectAndOpen(tester);
      expect(
        tester.widget<Text>(_key('photo_error')).data,
        'Googleフォトにつなぎませんでした。',
      );
    });

    testWidgets('知らない例外でも、中身を出さずに既定の文言', (tester) async {
      final env = await pumpSheet(tester);
      env.api.authorizeError = Exception('secret https://example.com/x');
      await connectAndOpen(tester);
      final text = tester.widget<Text>(_key('photo_error')).data!;
      expect(text, 'Googleフォトを使えませんでした。しばらくしてからもう一度お試しください。');
    });

    testWidgets('認可中は段階の文とスピナー・「やめる」。写真の決定は押せない', (tester) async {
      final env = await pumpSheet(tester);
      env.api.authorizeGate = Completer<void>();
      await tapKey(tester, 'photo_connect_button');
      await tester.tap(_key('google_photos_consent_yes'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Googleフォトとつないでいます…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(
        tester.widget<TicketButton>(_key('photo_sheet_done')).onPressed,
        isNull,
      );
      env.api.authorizeGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('「やめる」で認可の流れを止め、セッションを消す', (tester) async {
      final env = await pumpSheet(tester);
      await connectAndOpen(tester);
      await tapKey(tester, 'photo_cancel');
      expect(env.api.deletedSessions, ['s1']);
      expect(_key('photo_open_picker'), findsNothing);
    });

    testWidgets('「Googleフォトを開く」: autoclose を付けた URL を開き、選び終わると候補が出る', (
      tester,
    ) async {
      final env = await pumpSheet(tester);
      env.ai.judgements = [
        const PhotoJudgement(0, PhotoDecision.pick, rank: 1, label: 'ステージ'),
        const PhotoJudgement(1, PhotoDecision.pick, rank: 2),
        const PhotoJudgement(2, PhotoDecision.candidate),
        const PhotoJudgement(3, PhotoDecision.skip, skipKind: SkipKind.blurry),
      ];
      await connectAndOpen(tester);
      await openPickerAndWait(tester);
      expect(
        env.launched.single,
        'https://photos.example.com/picker/s1/autoclose',
      );
      expect(_key('photo_ai_note'), findsOneWidget);
      expect(
        find.textContaining('あなたが選んだ4枚の中から、よく写っている写真を2枚えらんでいます。'),
        findsOneWidget,
      );
      expect(_key('photo_selected_0'), findsOneWidget);
      expect(_key('photo_selected_1'), findsOneWidget);
      expect(_key('photo_selected_2'), findsNothing);
      expect(find.text('ステージ'), findsOneWidget);
      expect(find.textContaining('ほかの候補'), findsOneWidget);
      expect(_key('photo_candidate_2'), findsOneWidget);
      expect(_key('photo_skipped_toggle'), findsOneWidget);
      expect(find.text('選ばなかった写真（1枚）と理由を見る'), findsOneWidget);
      expect(_key('photo_reselect'), findsOneWidget);
      expect(_key('photo_manual_add'), findsOneWidget);
    });

    testWidgets('何も選ばれなかった → 文言', (tester) async {
      final env = await pumpSheet(tester);
      env.api.items = [];
      await connectAndOpen(tester);
      await openPickerAndWait(tester);
      expect(tester.widget<Text>(_key('photo_error')).data, '写真が選ばれませんでした。');
    });

    testWidgets('Gemini が失敗 → 「AIが写真を選べなかったので…」。紫の説明は出ず、候補は全部ほかの候補', (
      tester,
    ) async {
      final env = await pumpSheet(tester);
      env.ai.error = Exception('boom');
      await connectAndOpen(tester);
      await openPickerAndWait(tester);
      expect(
        tester.widget<Text>(_key('photo_ai_failed')).data,
        'AIが写真を選べなかったので、自分で選んでください。',
      );
      expect(_key('photo_ai_note'), findsNothing);
      expect(_key('photo_selected_0'), findsNothing);
      expect(_key('photo_candidate_0'), findsOneWidget);
    });

    testWidgets('選ばなかった写真を開くと、固定の理由と「戻す」が出る', (tester) async {
      final env = await pumpSheet(tester);
      env.ai.judgements = [
        const PhotoJudgement(0, PhotoDecision.pick, rank: 1),
        const PhotoJudgement(3, PhotoDecision.skip, skipKind: SkipKind.blurry),
      ];
      await connectAndOpen(tester);
      await openPickerAndWait(tester);
      await tapKey(tester, 'photo_skipped_toggle');
      expect(find.text('ピントがずれているため'), findsOneWidget);
      expect(find.text('選ばなかった写真をとじる'), findsOneWidget);
      await tapKey(tester, 'photo_skipped_restore_3');
      expect(_key('photo_selected_1'), findsOneWidget);
    });

    testWidgets('ほかの候補を押すと選ばれ、外すと戻る', (tester) async {
      final env = await pumpSheet(tester);
      env.ai.judgements = [
        const PhotoJudgement(0, PhotoDecision.pick, rank: 1),
      ];
      await connectAndOpen(tester);
      await openPickerAndWait(tester);
      expect(_key('photo_selected_1'), findsNothing);
      await tapKey(tester, 'photo_candidate_1');
      expect(_key('photo_selected_1'), findsOneWidget);
      expect(_key('photo_candidate_1'), findsNothing);
      await tapKey(tester, 'photo_remove_1');
      expect(_key('photo_selected_1'), findsNothing);
      expect(_key('photo_candidate_1'), findsOneWidget);
    });
  });

  group('決定', () {
    testWidgets('選んだ写真の大きい写真（1600）を取り直して保存し、閉じる。そのあとセッションを消す', (tester) async {
      final env = await pumpSheet(tester);
      env.ai.judgements = [
        const PhotoJudgement(0, PhotoDecision.pick, rank: 1),
        const PhotoJudgement(1, PhotoDecision.pick, rank: 2),
      ];
      await connectAndOpen(tester);
      await openPickerAndWait(tester);
      expect(env.api.deletedSessions, isEmpty, reason: '決定の前はセッションを残す');
      await tapKey(tester, 'photo_sheet_done');
      expect(_key('photo_sheet'), findsNothing);
      expect(env.api.fetched.where((f) => f.side == 1600), hasLength(2));
      expect(env.photos.uploaded, hasLength(2));
      expect(env.repo.store['p1']!.images, hasLength(2));
      expect(env.api.deletedSessions, ['s1']);
      // 座席は消えない
      expect(env.repo.store['p1']!.seat, 'SEAT-SECRET-A12');
    });

    testWidgets('大きい写真を取れなかった → 文言を出し、保存せず、シートは開いたまま', (tester) async {
      final env = await pumpSheet(tester);
      env.ai.judgements = [
        const PhotoJudgement(0, PhotoDecision.pick, rank: 1),
      ];
      env.api.failLargeIds.add('a');
      await connectAndOpen(tester);
      await openPickerAndWait(tester);
      await tapKey(tester, 'photo_sheet_done');
      expect(
        tester.widget<Text>(_key('photo_error')).data,
        '写真を取り込めませんでした。もう一度選び直してください',
      );
      expect(_key('photo_sheet'), findsOneWidget);
      expect(env.repo.calls, isEmpty);
      expect(env.photos.uploaded, isEmpty);
    });

    testWidgets('保存に失敗 → 文言を出し、開いたまま。上げた写真は消す', (tester) async {
      final env = await pumpSheet(tester);
      env.ai.judgements = [
        const PhotoJudgement(0, PhotoDecision.pick, rank: 1),
      ];
      await connectAndOpen(tester);
      await openPickerAndWait(tester);
      env.repo.error = Exception('x');
      await tapKey(tester, 'photo_sheet_done');
      expect(
        tester.widget<Text>(_key('photo_error')).data,
        '写真を保存できませんでした。もう一度お試しください',
      );
      expect(_key('photo_sheet'), findsOneWidget);
      expect(env.photos.deleted, env.photos.uploaded);
    });

    testWidgets('「とじる」は変更を捨てる（選んだ写真は保存されない）', (tester) async {
      final env = await pumpSheet(tester);
      env.ai.judgements = [
        const PhotoJudgement(0, PhotoDecision.pick, rank: 1),
      ];
      await connectAndOpen(tester);
      await openPickerAndWait(tester);
      await tapKey(tester, 'photo_sheet_close');
      expect(_key('photo_sheet'), findsNothing);
      expect(env.repo.calls, isEmpty);
      expect(env.photos.uploaded, isEmpty);
      expect(env.api.deletedSessions, ['s1']);
    });

    testWidgets('保存中は閉じられない', (tester) async {
      final env = await pumpSheet(tester);
      env.ai.judgements = [
        const PhotoJudgement(0, PhotoDecision.pick, rank: 1),
      ];
      await connectAndOpen(tester);
      await openPickerAndWait(tester);
      env.repo.gate = Completer<void>();
      await tester.ensureVisible(_key('photo_sheet_done'));
      await tester.tap(_key('photo_sheet_done'));
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<IconButton>(_key('photo_sheet_close')).onPressed,
        isNull,
      );
      env.repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(_key('photo_sheet'), findsNothing);
    });
  });

  group('保存済みの写真', () {
    testWidgets('写真がある記録: 格子に出て、「×」で外して決定すると消える', (tester) async {
      final env = await pumpSheet(
        tester,
        memory: _mem(images: const ['users/u1/a.jpg', 'users/u1/b.jpg']),
      );
      expect(_key('photo_selected_0'), findsOneWidget);
      expect(_key('photo_selected_1'), findsOneWidget);
      expect(_key('photo_connect_button'), findsNothing);
      expect(_key('photo_reselect'), findsOneWidget);
      await tapKey(tester, 'photo_remove_0');
      expect(_key('photo_selected_1'), findsNothing);
      await tapKey(tester, 'photo_sheet_done');
      expect(env.repo.store['p1']!.images, ['users/u1/b.jpg']);
      expect(env.photos.deleted, ['users/u1/a.jpg']);
    });

    testWidgets('8枚あれば、候補を足せない・端末から追加も押せない', (tester) async {
      final env = await pumpSheet(
        tester,
        memory: _mem(images: [for (var i = 0; i < 8; i++) 'users/u1/$i.jpg']),
      );
      expect(
        tester.widget<TicketButton>(_key('photo_manual_add')).onPressed,
        isNull,
      );
      expect(env.api.calls, isEmpty);
    });

    testWidgets('空き枠が少ないと、既定の選択は空き枠までで、候補は足せない', (tester) async {
      final env = await pumpSheet(
        tester,
        memory: _mem(images: [for (var i = 0; i < 7; i++) 'users/u1/$i.jpg']),
        consented: true,
      );
      env.ai.judgements = [
        for (var i = 0; i < 4; i++)
          PhotoJudgement(i, PhotoDecision.pick, rank: i + 1),
      ];
      await tapKey(tester, 'photo_reselect');
      await openPickerAndWait(tester);
      // 保存済み 7 + 選んだ 1 = 8 枚
      expect(_key('photo_selected_7'), findsOneWidget);
      expect(_key('photo_selected_8'), findsNothing);
      await tester.ensureVisible(_key('photo_candidate_item_1'));
      await tester.tap(_key('photo_candidate_1'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_key('photo_selected_8'), findsNothing);
    });
  });

  group('はみ出し', () {
    for (final w in [320.0, 360.0, 390.0, 430.0, 720.0, 1000.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('幅 $w・文字 $scale 倍: 状態①と候補の一覧ではみ出さない', (tester) async {
          final env = await pumpSheet(tester, width: w, textScale: scale);
          expect(tester.takeException(), isNull);
          env.ai.judgements = [
            const PhotoJudgement(
              0,
              PhotoDecision.pick,
              rank: 1,
              label: 'ステージ客席',
            ),
            const PhotoJudgement(
              1,
              PhotoDecision.skip,
              skipKind: SkipKind.unrelated,
            ),
          ];
          await connectAndOpen(tester);
          expect(tester.takeException(), isNull);
          await openPickerAndWait(tester);
          expect(tester.takeException(), isNull);
          expect(_key('photo_selected_0'), findsOneWidget);
        });
      }
    }

    testWidgets('PC の幅では、シートの最大幅が 640', (tester) async {
      await pumpSheet(tester, width: 1000);
      expect(tester.getSize(_key('photo_sheet')).width, lessThanOrEqualTo(640));
    });
  });
}
