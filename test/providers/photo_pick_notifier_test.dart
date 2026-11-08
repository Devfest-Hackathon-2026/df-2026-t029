// PhotoPickNotifier（Google フォトで選ぶ → Gemini で選ぶ流れの状態機械）のテスト。
// 偽の GooglePhotosApi・偽の PhotoPickAi を使い、時刻は photoPickClockProvider で固定する。
// 本物の Google・Gemini・ネットワークは呼ばない。トークン・URL は架空の値。
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/providers/photo_pick_providers.dart';
import 'package:oshiashi/services/google_photos_service.dart';
import 'package:oshiashi/services/photo_pick_ai.dart';
import 'package:oshiashi/utils/photo_picker.dart';

import '../features/google_photos_test_helpers.dart';

final _t0 = DateTime.utc(2026, 12, 19, 12);

final _info = PhotoPickRequestInfo(
  title: 'ツアー2026',
  startAt: DateTime.utc(2026, 12, 19, 9),
  venue: '東京ドーム',
  artist: 'ひかり',
);

const _thumbFailed = '写真を取り込めませんでした。もう一度お試しください。';
const _aiNote = 'AIが写真を選べなかったので、自分で選んでください。';

void main() {
  late DateTime now;
  late FakeGooglePhotosApi api;
  late FakePhotoPickAi ai;
  late ProviderContainer container;

  PhotoPickNotifier notifier() => container.read(photoPickProvider.notifier);
  PhotoPickState state() => container.read(photoPickProvider);

  setUp(() {
    now = _t0;
    api = FakeGooglePhotosApi(
      clock: () => now,
      items: [fakeItem('a'), fakeItem('b'), fakeItem('c')],
    );
    ai = FakePhotoPickAi();
    container = ProviderContainer(
      overrides: [
        googlePhotosApiProvider.overrideWithValue(api),
        photoPickAiProvider.overrideWithValue(ai),
        photoPickClockProvider.overrideWithValue(() => now),
      ],
    );
    container.listen(photoPickProvider, (_, _) {});
    addTearDown(container.dispose);
  });

  Future<void> begin({int slots = 8}) =>
      notifier().begin(info: _info, remainingSlots: slots);

  /// 候補が選べる状態（done）まで進める
  Future<void> toDone({int slots = 8}) async {
    await begin(slots: slots);
    await notifier().waitForSelection();
  }

  group('begin', () {
    test('認可 → セッション作成 → waitingPicker。busy', () async {
      await begin();
      expect(api.calls, ['authorize', 'createSession']);
      expect(state().stage, PhotoPickStage.waitingPicker);
      expect(state().session, isNotNull);
      expect(state().busy, isTrue, reason: 'つなぐの二重押しを防ぐ');
      expect(state().error, isNull);
    });

    test('authorize が最初の呼び出し（ポップアップを止められないため）', () async {
      await begin();
      expect(api.calls.first, 'authorize');
    });

    test('処理中の二重の begin は始めない', () async {
      api.authorizeGate = Completer<void>();
      final first = begin();
      await Future<void>.delayed(Duration.zero);
      expect(state().stage, PhotoPickStage.authorizing);
      await begin();
      expect(api.calls.where((c) => c == 'authorize'), hasLength(1));
      api.authorizeGate!.complete();
      await first;
      // waitingPicker でも busy なので、さらに押しても始めない
      await begin();
      expect(api.calls.where((c) => c == 'authorize'), hasLength(1));
      expect(api.calls.where((c) => c == 'createSession'), hasLength(1));
    });

    final failures = {
      GooglePhotosFailure.cancelled: 'Googleフォトにつなぎませんでした。',
      GooglePhotosFailure.popupBlocked:
          'ポップアップが止められました。ブラウザの設定で許可してから、もう一度お試しください。',
      GooglePhotosFailure.noToken: 'Googleフォトの権限を取得できませんでした。',
      GooglePhotosFailure.accountInUse:
          'この Google アカウントは、別のおしあしのアカウントで使われています。別の Google アカウントを選んでください',
    };
    for (final e in failures.entries) {
      test('認可の失敗（${e.key.name}）→ failed と日本語の文言。cancel で idle に戻せる', () async {
        api.authorizeError = GooglePhotosException(e.key);
        await begin();
        expect(state().stage, PhotoPickStage.failed);
        expect(state().error, e.value);
        expect(state().busy, isFalse);
        expect(api.calls, ['authorize']);
        notifier().cancel();
        expect(state().stage, PhotoPickStage.idle);
        expect(state().error, isNull);
      });
    }

    test('failed のあと、もう一度 begin できる', () async {
      api.authorizeError = const GooglePhotosException(
        GooglePhotosFailure.cancelled,
      );
      await begin();
      api.authorizeError = null;
      await begin();
      expect(state().stage, PhotoPickStage.waitingPicker);
      expect(state().error, isNull);
    });

    test('createSession の失敗（403）→ failed。例外の中身を出さない', () async {
      api.createError = const GooglePhotosException(
        GooglePhotosFailure.apiUnavailable,
      );
      await begin();
      expect(state().stage, PhotoPickStage.failed);
      expect(state().error, 'Googleフォトを使えませんでした。しばらくしてからもう一度お試しください。');
    });

    test('知らない例外でも、例外の中身は出ない', () async {
      api.authorizeError = Exception('secret-detail https://x.example.com');
      await begin();
      expect(state().stage, PhotoPickStage.failed);
      expect(state().error, isNot(contains('secret')));
      expect(state().error, isNot(contains('http')));
    });
  });

  group('waitForSelection: 正常', () {
    test('done。pick が rank の順に選択される。Gemini には縮小版と情報だけ渡す', () async {
      ai.judgements = [
        const PhotoJudgement(0, PhotoDecision.pick, rank: 2, label: 'ステージ'),
        const PhotoJudgement(1, PhotoDecision.pick, rank: 1),
        const PhotoJudgement(2, PhotoDecision.skip, skipKind: SkipKind.blurry),
      ];
      await toDone();
      final s = state();
      expect(s.stage, PhotoPickStage.done);
      expect(s.busy, isFalse);
      expect(s.selected, [1, 0]);
      expect(s.aiFailed, isFalse);
      expect(s.candidates, hasLength(3));
      expect(s.candidates[0].judgement?.label, 'ステージ');
      expect(s.session, isNull);

      final req = ai.requests.single;
      expect(req.title, 'ツアー2026');
      expect(req.venue, '東京ドーム');
      expect(req.artist, 'ひかり');
      expect(req.startAt, _info.startAt);
      expect(req.candidates, hasLength(3));
      expect(req.candidates.first.mimeType, 'image/jpeg');
    });

    test('段階: fetching → analyzing → done の順に進む', () async {
      final stages = <PhotoPickStage>[];
      container.listen(photoPickProvider, (_, n) {
        if (stages.isEmpty || stages.last != n.stage) stages.add(n.stage);
      });
      await toDone();
      expect(stages, [
        PhotoPickStage.authorizing,
        PhotoPickStage.waitingPicker,
        PhotoPickStage.fetching,
        PhotoPickStage.analyzing,
        PhotoPickStage.done,
      ]);
    });

    test('ポーリング: mediaItemsSet になるまで getSession を繰り返す', () async {
      api.pollsBeforeSet = 3;
      // createSession の時点では未選択（pollsBeforeSet が 0 ではない）
      await toDone();
      expect(api.calls.where((c) => c == 'getSession'), hasLength(3));
      expect(state().stage, PhotoPickStage.done);
    });

    test('createSession の時点で選び終わっていれば、待たない', () async {
      api.pollsBeforeSet = 0;
      await toDone();
      expect(api.calls.contains('getSession'), isFalse);
      expect(state().stage, PhotoPickStage.done);
    });

    test('既定の選択は、空き枠（remainingSlots）までに切る', () async {
      ai.judgements = [
        for (var i = 0; i < 3; i++)
          PhotoJudgement(i, PhotoDecision.pick, rank: i + 1),
      ];
      await toDone(slots: 2);
      expect(state().selected, [0, 1]);
    });

    test('縮小版は 768、同時に取る数の範囲で全部取る', () async {
      await toDone();
      expect(api.fetched.every((f) => f.side == 768), isTrue);
      expect(api.fetched.map((f) => f.id).toSet(), {'a', 'b', 'c'});
    });

    test('縮小版を取り終えても、セッションは消さない（決定での取り直しに baseUrl が要る）', () async {
      await toDone();
      expect(api.deletedSessions, isEmpty);
    });

    test('waitingPicker でなければ waitForSelection は何もしない', () async {
      await notifier().waitForSelection();
      expect(api.calls, isEmpty);
      expect(state().stage, PhotoPickStage.idle);
    });
  });

  group('waitForSelection: 失敗・中断', () {
    test('タイムアウト → failed。セッションを消す', () async {
      api.pollsBeforeSet = null; // 永遠に選び終わらない
      await begin();
      now = _t0.add(const Duration(hours: 1));
      await notifier().waitForSelection();
      expect(state().stage, PhotoPickStage.failed);
      expect(state().error, '選ぶ時間が過ぎました。もう一度やり直してください。');
      expect(api.deletedSessions, ['s1']);
    });

    test('待っている途中で時刻が期限を過ぎても、タイムアウトで止まる', () async {
      api.pollsBeforeSet = null;
      api.timeoutIn = const Duration(minutes: 1);
      await begin();
      final f = notifier().waitForSelection();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      now = _t0.add(const Duration(minutes: 2));
      await f;
      expect(state().error, '選ぶ時間が過ぎました。もう一度やり直してください。');
    });

    test('何も選ばれなかった → failed', () async {
      api.items = [];
      await toDone();
      expect(state().stage, PhotoPickStage.failed);
      expect(state().error, '写真が選ばれませんでした。');
      expect(api.deletedSessions, ['s1']);
      expect(ai.requests, isEmpty);
    });

    test('一覧の取得の失敗 → failed（通信）', () async {
      api.listError = const GooglePhotosException(GooglePhotosFailure.network);
      await toDone();
      expect(state().stage, PhotoPickStage.failed);
      expect(state().error, '通信できませんでした。もう一度お試しください。');
    });

    test('縮小版が1枚も取れない → 専用の文言。セッションを消す。Gemini は呼ばない', () async {
      api.failThumbIds.addAll({'a', 'b', 'c'});
      await toDone();
      expect(state().stage, PhotoPickStage.failed);
      expect(state().error, _thumbFailed);
      expect(api.deletedSessions, ['s1']);
      expect(ai.requests, isEmpty);
    });

    test('一部だけ取れない → 飛ばす。Gemini には取れた分だけ渡る', () async {
      api.failThumbIds.add('b');
      ai.judgements = [
        const PhotoJudgement(0, PhotoDecision.pick, rank: 1),
        const PhotoJudgement(1, PhotoDecision.pick, rank: 2),
      ];
      await toDone();
      expect(state().stage, PhotoPickStage.done);
      expect(state().candidates.map((c) => c.item.id), ['a', 'c']);
      expect(ai.requests.single.candidates, hasLength(2));
      expect(state().selected, [0, 1]);
    });

    test('Gemini が失敗 → aiFailed・全部ほかの候補・選択は空。写真は失わない', () async {
      ai.error = Exception('boom');
      await toDone();
      final s = state();
      expect(s.stage, PhotoPickStage.done);
      expect(s.aiFailed, isTrue);
      expect(s.selected, isEmpty);
      expect(s.candidates, hasLength(3));
      expect(s.candidates.every((c) => c.judgement == null), isTrue);
      expect(s.error, isNull);
      expect(_aiNote, isNotEmpty);
    });

    test('cancel: ポーリングが止まり、セッションが消え、idle に戻る', () async {
      api.pollsBeforeSet = null;
      await begin();
      final f = notifier().waitForSelection();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      notifier().cancel();
      await f;
      expect(state().stage, PhotoPickStage.idle);
      expect(api.deletedSessions, ['s1']);
      final polls = api.calls.where((c) => c == 'getSession').length;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        api.calls.where((c) => c == 'getSession').length,
        polls,
        reason: 'やめたあとはポーリングしない',
      );
    });

    test('cancel のあと、遅れて返ってきた一覧で state を書き換えない', () async {
      api.listGate = Completer<void>();
      await begin();
      final f = notifier().waitForSelection();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(state().stage, PhotoPickStage.fetching);
      notifier().cancel();
      api.listGate!.complete();
      await f;
      expect(state().stage, PhotoPickStage.idle);
      expect(ai.requests, isEmpty);
    });

    test('Gemini の待ち中に cancel しても、あとから結果で書き換えない', () async {
      ai.gate = Completer<void>();
      await begin();
      final f = notifier().waitForSelection();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(state().stage, PhotoPickStage.analyzing);
      notifier().cancel();
      ai.gate!.complete();
      await f;
      expect(state().stage, PhotoPickStage.idle);
      expect(state().candidates, isEmpty);
    });

    test(
      'waitForSelection を2回呼んでも、ポーリングは1本（getSession は選び終わるまでの回数だけ）',
      () async {
        api.pollsBeforeSet = 3;
        await begin();
        final f1 = notifier().waitForSelection();
        final f2 = notifier().waitForSelection();
        await Future.wait([f1, f2]);
        expect(state().stage, PhotoPickStage.done);
        expect(api.calls.where((c) => c == 'getSession'), hasLength(3));
        expect(api.calls.where((c) => c == 'listPickedItems'), hasLength(1));
        expect(ai.requests, hasLength(1));
      },
    );

    test('cancel のあと begin し直すと、再びポーリングできる', () async {
      api.pollsBeforeSet = null;
      await begin();
      final f = notifier().waitForSelection();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      notifier().cancel();
      await f;
      api.pollsBeforeSet = 1; // 次の getSession で選び終わる
      await begin();
      await notifier().waitForSelection();
      expect(state().stage, PhotoPickStage.done);
    });

    test('認可の待ち中に cancel すると、createSession は呼ばない', () async {
      api.authorizeGate = Completer<void>();
      final f = begin();
      await Future<void>.delayed(Duration.zero);
      notifier().cancel();
      api.authorizeGate!.complete();
      await f;
      expect(state().stage, PhotoPickStage.idle);
      expect(api.calls.contains('createSession'), isFalse);
    });

    test('cancel のあと、新しく begin した流れが古い処理に邪魔されない', () async {
      final oldGate = Completer<void>();
      api.listGate = oldGate;
      await begin();
      final old = notifier().waitForSelection();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      notifier().cancel();
      await begin();
      expect(state().stage, PhotoPickStage.waitingPicker);
      // 古い処理を再開させても、新しい流れの state は変わらない
      oldGate.complete();
      await old;
      expect(state().stage, PhotoPickStage.waitingPicker);
      expect(ai.requests, isEmpty);
    });
  });

  group('toggle', () {
    test('選ぶ・外す', () async {
      ai.judgements = [const PhotoJudgement(0, PhotoDecision.pick, rank: 1)];
      await toDone();
      expect(state().selected, [0]);
      notifier().toggle(1);
      expect(state().selected, [0, 1]);
      notifier().toggle(0);
      expect(state().selected, [1]);
    });

    test('上限（空き枠）を超える選択は無視する', () async {
      ai.judgements = [
        const PhotoJudgement(0, PhotoDecision.pick, rank: 1),
        const PhotoJudgement(1, PhotoDecision.pick, rank: 2),
      ];
      await toDone(slots: 2);
      expect(state().selected, [0, 1]);
      notifier().toggle(2);
      expect(state().selected, [0, 1]);
      notifier().toggle(1);
      notifier().toggle(2);
      expect(state().selected, [0, 2]);
    });

    test('空き枠が 0 なら、何も選べない', () async {
      await toDone(slots: 0);
      notifier().toggle(0);
      expect(state().selected, isEmpty);
    });

    test('範囲外の番号・done 以外では無視する', () async {
      notifier().toggle(0);
      expect(state().selected, isEmpty);
      await toDone();
      notifier().toggle(-1);
      notifier().toggle(99);
      expect(state().selected, isEmpty);
    });
  });

  group('materializeSelected（決定）', () {
    test('選んだ写真の大きい写真（1600）を取り、NewPhoto にする。そのあとセッションを消す', () async {
      ai.judgements = [
        const PhotoJudgement(0, PhotoDecision.pick, rank: 1),
        const PhotoJudgement(1, PhotoDecision.pick, rank: 2),
      ];
      await toDone();
      final photos = await notifier().materializeSelected();
      expect(photos, hasLength(2));
      expect(photos.first.photo.contentType, 'image/jpeg');
      expect(photos.first.photo.extension, 'jpg');
      final large = api.fetched.where((f) => f.side == 1600).toList();
      expect(large.map((f) => f.id), unorderedEquals(['a', 'b']));
      expect(api.deletedSessions, ['s1']);
    });

    test('形式は先頭のバイト列で判定する（PNG）。判定できなければ item の mimeType', () async {
      ai.judgements = [
        const PhotoJudgement(0, PhotoDecision.pick, rank: 1),
        const PhotoJudgement(1, PhotoDecision.pick, rank: 2),
      ];
      api.largeBytes = (item) => item.id == 'a'
          ? Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2])
          : Uint8List.fromList([9, 9, 9, 9, 9]); // 判定できない → image/jpeg
      await toDone();
      final photos = await notifier().materializeSelected();
      expect(photos[0].photo.contentType, 'image/png');
      expect(photos[0].photo.extension, 'png');
      expect(photos[1].photo.contentType, 'image/jpeg');
      expect(photos[1].photo.extension, 'jpg');
    });

    test('選択が空なら空の一覧', () async {
      await toDone();
      expect(await notifier().materializeSelected(), isEmpty);
    });

    test('1枚でも取れなければ例外。縮小版しか無いものは保存しない', () async {
      ai.judgements = [
        const PhotoJudgement(0, PhotoDecision.pick, rank: 1),
        const PhotoJudgement(1, PhotoDecision.pick, rank: 2),
      ];
      api.failLargeIds.add('b');
      await toDone();
      await expectLater(notifier().materializeSelected(), throwsA(anything));
    });

    test('5MB 以上は再圧縮せず例外', () async {
      ai.judgements = [const PhotoJudgement(0, PhotoDecision.pick, rank: 1)];
      api.largeBytes = (_) => fakeJpeg(maxPhotoBytes);
      await toDone();
      await expectLater(notifier().materializeSelected(), throwsA(anything));
    });
  });

  group('秘密情報を出さない', () {
    test('ログ・エラーの文言・state に、トークン・baseUrl が出ない', () async {
      final logs = <String>[];
      final old = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
      addTearDown(() => debugPrint = old);

      api.failThumbIds.add('b');
      ai.error = Exception('https://img.example.com/a');
      await toDone();
      await notifier().materializeSelected();

      for (final text in [
        ...logs,
        state().error ?? '',
        state().session?.pickerUri.toString() ?? '',
      ]) {
        expect(text, isNot(contains('img.example.com')));
        expect(text, isNot(contains('Bearer')));
      }
      expect(state().error, isNull);
    });
  });
}
