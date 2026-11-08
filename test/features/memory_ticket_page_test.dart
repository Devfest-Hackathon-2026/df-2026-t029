// 記録の画面（チケット風。/memories/:performanceId）のテスト（Q3）。
// 座席・セトリ・感想のその場の編集、進み具合、固定のバー、公開スイッチ、4状態、はみ出し。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/memory/memory_detail_page.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/live_memory.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/memory_providers.dart';
import 'package:oshiashi/providers/memory_ticket_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/providers/photo_pick_providers.dart';

import 'live_test_helpers.dart';
import 'memory_form_page_test.dart' show FakeMemoryRepository;
import 'photo_test_helpers.dart';
import 'public_memory_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

final _now = DateTime(2026, 11, 5, 12);

/// 書き込みのたびに新しい値を流す偽物（画面が新しい値に変わるのを確かめる）
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
}

LiveMemory _mem({
  String id = 'a',
  DateTime? at,
  String? seat = 'A1',
  List<String> setlist = const ['曲1', '曲2'],
  String? impression = '感想',
  List<String> images = const [],
  bool isPublic = false,
  bool publicSeat = false,
  String? title,
}) => LiveMemory(
  performanceId: id,
  liveId: 'l$id',
  liveTitle: title ?? 'ライブ$id',
  startAt: at ?? DateTime(2026, 10, 1, 18),
  venue: '会場$id',
  seat: seat,
  setlist: setlist,
  impression: impression,
  images: images,
  isPublic: isPublic,
  publicSeat: publicSeat,
);

class _Env {
  _Env(this.repo);
  final _ReactiveRepo repo;
  final photos = FakePhotoRepository();
  final publics = FakePublicMemoryRepository();
  GoRouter? router;
}

Future<_Env> pumpTicket(
  WidgetTester tester,
  LiveMemory? memory, {
  String id = 'a',
  double width = 390,
  double textScale = 1,
  bool consented = false,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final env = _Env(_ReactiveRepo([?memory]));
  final lives = FakeLiveRepository(
    lives: [
      Live(id: 'l$id', title: 'ライブ', groupIds: const ['g1']),
    ],
  );
  final router = GoRouter(
    initialLocation: '/memories/$id',
    routes: [
      GoRoute(
        path: '/memories/:id',
        builder: (_, s) =>
            MemoryDetailPage(performanceId: s.pathParameters['id']!),
        routes: [
          GoRoute(path: 'edit', builder: (_, _) => const Text('route:edit')),
          GoRoute(path: 'share', builder: (_, _) => const Text('route:share')),
        ],
      ),
      GoRoute(path: '/memories', builder: (_, _) => const Text('route:list')),
    ],
  );
  env.router = router;
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        memoryRepositoryProvider.overrideWithValue(env.repo),
        nowProvider.overrideWithValue(_now),
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
  return env;
}

class _Consented extends ConsentNotifier {
  @override
  bool build() => true;
}

Future<void> tapKey(WidgetTester tester, String k) async {
  if (_key(k).evaluate().isEmpty) {
    // 長いリストは、画面の外の要素がまだ作られていない
    await tester.scrollUntilVisible(
      _key(k),
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(_key(k));
  await tester.pumpAndSettle();
  await tester.tap(_key(k));
  await tester.pumpAndSettle();
}

void main() {
  group('チケットの内容', () {
    testWidgets('ライブ名・日時・会場・座席・札・セトリ・感想が出る', (tester) async {
      await pumpTicket(tester, _mem());
      expect(_key('memory_ticket'), findsOneWidget);
      expect(find.text('ライブa'), findsOneWidget);
      expect(find.text('会場a'), findsOneWidget);
      expect(find.textContaining('開演'), findsOneWidget);
      expect(tester.widget<Text>(_key('memory_detail_seat')).data, 'A1');
      expect(find.text('参戦済み'), findsOneWidget);
      expect(find.text('1. 曲1'), findsOneWidget);
      expect(find.text('2. 曲2'), findsOneWidget);
      expect(tester.widget<Text>(_key('memory_detail_impression')).data, '感想');
      expect(find.text('座席は、この記録だけに表示されます。SNSの画像と文章には出ません。'), findsOneWidget);
    });

    testWidgets('座席が無ければ「未入力」。座席の説明の文は出ない', (tester) async {
      await pumpTicket(tester, _mem(seat: null));
      expect(tester.widget<Text>(_key('memory_detail_seat')).data, '未入力');
    });

    testWidgets('座席があれば、「参戦予定に登録した座席です…」の補足が出る', (tester) async {
      await pumpTicket(tester, _mem());
      expect(_key('memory_ticket_seat_note'), findsOneWidget);
      expect(find.text('参戦予定に登録した座席です。違っていれば書き換えられます。'), findsOneWidget);
    });

    testWidgets('参戦予定の札', (tester) async {
      await pumpTicket(tester, _mem(at: DateTime(2026, 12, 9, 18)));
      expect(find.text('参戦予定'), findsOneWidget);
    });

    testWidgets('写真0枚: 「写真はまだありません」＋「Googleフォトとつなぐ」', (tester) async {
      await pumpTicket(tester, _mem());
      expect(find.text('写真はまだありません'), findsOneWidget);
      expect(find.text('Googleフォトとつなぐ'), findsOneWidget);
      expect(_key('memory_ticket_photos'), findsOneWidget);
    });

    testWidgets('写真0枚でつないでいれば「写真を追加」', (tester) async {
      await pumpTicket(tester, _mem(), consented: true);
      expect(find.text('写真を追加'), findsOneWidget);
      expect(find.text('Googleフォトとつなぐ'), findsNothing);
    });

    testWidgets('公開中の札', (tester) async {
      await pumpTicket(tester, _mem(isPublic: true, publicSeat: true));
      expect(find.text('公開中（座席も）'), findsOneWidget);
    });

    testWidgets('編集ボタンで編集へ（残したキー）', (tester) async {
      await pumpTicket(tester, _mem());
      await tapKey(tester, 'memory_detail_edit_button');
      expect(find.text('route:edit'), findsOneWidget);
    });
  });

  group('進み具合', () {
    testWidgets('4つ入っていれば 4/4', (tester) async {
      await pumpTicket(tester, _mem(images: const ['a.jpg']));
      expect(find.text('4/4 入力済み'), findsOneWidget);
      expect(_key('memory_progress'), findsOneWidget);
    });

    testWidgets('写真が無ければ 3/4、何も無ければ 0/4', (tester) async {
      await pumpTicket(tester, _mem());
      expect(find.text('3/4 入力済み'), findsOneWidget);
      await pumpTicket(
        tester,
        _mem(seat: null, setlist: const [], impression: null),
      );
      expect(find.text('0/4 入力済み'), findsOneWidget);
    });

    testWidgets('保存すると進み具合が変わる', (tester) async {
      await pumpTicket(tester, _mem(seat: null));
      expect(find.text('2/4 入力済み'), findsOneWidget);
      await tapKey(tester, 'memory_ticket_seat_edit');
      await tester.enterText(_key('memory_inline_input'), 'B2');
      await tapKey(tester, 'memory_inline_save');
      expect(find.text('3/4 入力済み'), findsOneWidget);
    });
  });

  group('その場の編集', () {
    testWidgets('座席: 「直す」で編集カードが開き、決定で保存・閉じる・チケットが新しい値に', (tester) async {
      final env = await pumpTicket(tester, _mem());
      expect(_key('memory_inline_editor'), findsNothing);
      await tapKey(tester, 'memory_ticket_seat_edit');
      expect(_key('memory_inline_editor'), findsOneWidget);
      expect(
        tester.widget<TextField>(_key('memory_inline_input')).controller!.text,
        'A1',
      );
      await tester.enterText(_key('memory_inline_input'), '  アリーナ C3  ');
      await tapKey(tester, 'memory_inline_save');
      expect(_key('memory_inline_editor'), findsNothing);
      expect(env.repo.store['a']!.seat, 'アリーナ C3');
      expect(tester.widget<Text>(_key('memory_detail_seat')).data, 'アリーナ C3');
      // セトリ・感想は変わらない
      expect(env.repo.store['a']!.setlist, ['曲1', '曲2']);
      expect(env.repo.store['a']!.impression, '感想');
    });

    testWidgets('座席を空にして決定すると、項目が消えて「未入力」', (tester) async {
      final env = await pumpTicket(tester, _mem());
      await tapKey(tester, 'memory_ticket_seat_edit');
      await tester.enterText(_key('memory_inline_input'), '   ');
      await tapKey(tester, 'memory_inline_save');
      expect(env.repo.store['a']!.seat, isNull);
      expect(tester.widget<Text>(_key('memory_detail_seat')).data, '未入力');
    });

    testWidgets('セトリ: 1行1曲・空行は捨てる。座席・感想は変わらない', (tester) async {
      final env = await pumpTicket(tester, _mem());
      await tapKey(tester, 'memory_ticket_setlist');
      expect(_key('memory_inline_editor'), findsOneWidget);
      await tester.enterText(_key('memory_inline_input'), '新曲A\n\n  新曲B  \n');
      await tapKey(tester, 'memory_inline_save');
      expect(env.repo.store['a']!.setlist, ['新曲A', '新曲B']);
      expect(env.repo.store['a']!.seat, 'A1');
      expect(env.repo.store['a']!.impression, '感想');
      expect(find.text('1. 新曲A'), findsOneWidget);
    });

    testWidgets('感想: 保存して、座席・セトリは変わらない', (tester) async {
      final env = await pumpTicket(tester, _mem());
      await tapKey(tester, 'memory_ticket_impression');
      await tester.enterText(_key('memory_inline_input'), '  最高でした  ');
      await tapKey(tester, 'memory_inline_save');
      expect(env.repo.store['a']!.impression, '最高でした');
      expect(env.repo.store['a']!.seat, 'A1');
      expect(env.repo.store['a']!.setlist, ['曲1', '曲2']);
    });

    testWidgets('空の枠: ヒントが出て、タップで開く', (tester) async {
      await pumpTicket(tester, _mem(setlist: const [], impression: null));
      expect(find.text('セトリを書く'), findsOneWidget);
      expect(find.text('感想を書く'), findsOneWidget);
      expect(find.text('公演のあとに、覚えている曲から書けます'), findsOneWidget);
      expect(find.text('心に残ったことを、自由に書いてください'), findsOneWidget);
      await tapKey(tester, 'memory_ticket_impression');
      expect(_key('memory_inline_editor'), findsOneWidget);
    });

    testWidgets('同時に開く編集カードは1つ（別の枠を押すと閉じる・同じ枠で閉じる）', (tester) async {
      await pumpTicket(tester, _mem());
      await tapKey(tester, 'memory_ticket_setlist');
      expect(_key('memory_inline_editor'), findsOneWidget);
      await tapKey(tester, 'memory_ticket_impression');
      expect(_key('memory_inline_editor'), findsOneWidget);
      expect(
        tester.widget<TextField>(_key('memory_inline_input')).controller!.text,
        '感想',
        reason: '感想のカードに切り替わる',
      );
      await tapKey(tester, 'memory_ticket_seat_edit');
      expect(_key('memory_inline_editor'), findsOneWidget);
      await tapKey(tester, 'memory_ticket_seat_edit');
      expect(_key('memory_inline_editor'), findsNothing);
    });

    testWidgets('入力中の文字は、別の枠を押して閉じるときに捨てる', (tester) async {
      await pumpTicket(tester, _mem());
      await tapKey(tester, 'memory_ticket_impression');
      await tester.enterText(_key('memory_inline_input'), '書きかけ');
      await tapKey(tester, 'memory_ticket_setlist');
      await tapKey(tester, 'memory_ticket_impression');
      expect(
        tester.widget<TextField>(_key('memory_inline_input')).controller!.text,
        '感想',
      );
    });

    testWidgets('保存に失敗: SnackBar を出し、カードは開いたまま、入力も残る', (tester) async {
      final env = await pumpTicket(tester, _mem());
      await tapKey(tester, 'memory_ticket_impression');
      await tester.enterText(_key('memory_inline_input'), '直した感想');
      env.repo.error = Exception('x');
      await tapKey(tester, 'memory_inline_save');
      expect(find.text('保存できませんでした。もう一度お試しください'), findsOneWidget);
      expect(_key('memory_inline_editor'), findsOneWidget);
      expect(
        tester.widget<TextField>(_key('memory_inline_input')).controller!.text,
        '直した感想',
      );
      expect(env.repo.store['a']!.impression, '感想');
      // もう一度押せば保存できる
      env.repo.error = null;
      await tapKey(tester, 'memory_inline_save');
      expect(env.repo.store['a']!.impression, '直した感想');
      expect(_key('memory_inline_editor'), findsNothing);
    });

    testWidgets('保存中は「決定」を押せない（二重に押しても1回だけ）', (tester) async {
      final env = await pumpTicket(tester, _mem());
      await tapKey(tester, 'memory_ticket_impression');
      await tester.enterText(_key('memory_inline_input'), '直した');
      env.repo.gate = Completer<void>();
      await tester.tap(_key('memory_inline_save'));
      await tester.pump();
      await tester.tap(_key('memory_inline_save'), warnIfMissed: false);
      await tester.pump();
      expect(env.repo.calls.where((c) => c == 'update'), hasLength(1));
      env.repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(env.repo.calls.where((c) => c == 'update'), hasLength(1));
    });

    testWidgets('上限を超えると、赤い文が出て、決定を押せない', (tester) async {
      final env = await pumpTicket(tester, _mem());
      await tapKey(tester, 'memory_ticket_seat_edit');
      await tester.enterText(_key('memory_inline_input'), 'あ' * 101);
      await tester.pump();
      expect(_key('memory_inline_error'), findsOneWidget);
      await tester.tap(_key('memory_inline_save'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(env.repo.calls, isNot(contains('update')));
      await tester.enterText(_key('memory_inline_input'), 'あ' * 100);
      await tester.pump();
      expect(_key('memory_inline_error'), findsNothing);
    });

    testWidgets('公開中の記録を保存すると、公開の写しも書き直す', (tester) async {
      final env = await pumpTicket(tester, _mem(isPublic: true));
      await tapKey(tester, 'memory_ticket_impression');
      await tester.enterText(_key('memory_inline_input'), '公開の感想');
      await tapKey(tester, 'memory_inline_save');
      expect(env.publics.published.single.impression, '公開の感想');
    });
  });

  group('固定のバー（まとめて編集して投稿）', () {
    testWidgets('参戦済みの記録に出て、押すと投稿の画面へ', (tester) async {
      await pumpTicket(tester, _mem());
      expect(_key('memory_share_button'), findsOneWidget);
      expect(find.text('まとめて編集して投稿'), findsOneWidget);
      await tester.tap(_key('memory_share_button'));
      await tester.pumpAndSettle();
      expect(find.text('route:share'), findsOneWidget);
    });

    testWidgets('参戦予定の記録には出ない', (tester) async {
      await pumpTicket(tester, _mem(at: DateTime(2026, 12, 9, 18)));
      expect(_key('memory_share_button'), findsNothing);
    });
  });

  group('公開スイッチ（U4）', () {
    testWidgets('スイッチで公開にでき、公開の写しが書かれる', (tester) async {
      final env = await pumpTicket(tester, _mem());
      expect(
        tester
            .widget<SwitchListTile>(_key('memory_publish_seat_switch'))
            .onChanged,
        isNull,
        reason: '公開がオフのとき、座席のスイッチは押せない',
      );
      await tapKey(tester, 'memory_publish_switch');
      expect(env.repo.store['a']!.isPublic, isTrue);
      expect(env.publics.published, hasLength(1));
      expect(
        tester
            .widget<SwitchListTile>(_key('memory_publish_seat_switch'))
            .onChanged,
        isNotNull,
      );
    });

    testWidgets('座席も公開できる。公開をやめると写しが消える', (tester) async {
      final env = await pumpTicket(tester, _mem(isPublic: true));
      await tapKey(tester, 'memory_publish_seat_switch');
      expect(env.repo.store['a']!.publicSeat, isTrue);
      await tapKey(tester, 'memory_publish_switch');
      expect(env.repo.store['a']!.isPublic, isFalse);
      expect(env.publics.unpublished, isNotEmpty);
    });

    testWidgets('保存に失敗したら SnackBar', (tester) async {
      final env = await pumpTicket(tester, _mem());
      env.repo.error = Exception('x');
      await tapKey(tester, 'memory_publish_switch');
      expect(find.text('保存できませんでした。もう一度お試しください'), findsOneWidget);
    });
  });

  group('4状態', () {
    testWidgets('記録が無い', (tester) async {
      await pumpTicket(tester, null, id: 'zzz');
      expect(_key('memory_detail_not_found'), findsOneWidget);
      expect(find.text('この記録は見つかりませんでした'), findsOneWidget);
      expect(_key('memory_share_button'), findsNothing);
    });
  });

  for (final w in [320.0, 360.0, 390.0, 430.0, 720.0, 1000.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('幅 $w・文字 $scale 倍・長い内容・編集カードを開いてもはみ出さない', (tester) async {
        await pumpTicket(
          tester,
          _mem(
            title: 'とても長いライブ名' * 8,
            seat: '長い座席' * 10,
            setlist: List.generate(40, (i) => '長い曲名' * 4 + '$i'),
            impression: '長い感想' * 50,
            images: const ['a.jpg', 'b.jpg', 'c.jpg'],
          ),
          width: w,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        await tapKey(tester, 'memory_ticket_impression');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
