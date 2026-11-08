// parsePhotoPick・skipReasonText・プロンプトの組み立てのテスト。
// GeminiPhotoPickAi.choose は呼ばない（本物の Gemini を使わない）。
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/services/photo_pick_ai.dart';

Map<String, Object?> _item(
  int index,
  String decision, {
  Object? rank,
  Object? label,
  Object? skipKind,
}) => {
  'index': index,
  'decision': decision,
  'rank': ?rank,
  'label': ?label,
  'skipKind': ?skipKind,
};

Map<String, Object?> _wrap(List<Object?> items) => {'items': items};

void main() {
  group('parsePhotoPick', () {
    test('正常: 判定・順位・ラベル・理由が読める', () {
      final r = parsePhotoPick(
        _wrap([
          _item(0, 'pick', rank: 1, label: 'ステージ'),
          _item(1, 'candidate'),
          _item(2, 'skip', skipKind: 'blurry'),
        ]),
        3,
      );
      expect(r, hasLength(3));
      expect(r[0].decision, PhotoDecision.pick);
      expect(r[0].rank, 1);
      expect(r[0].label, 'ステージ');
      expect(r[1].decision, PhotoDecision.candidate);
      expect(r[2].decision, PhotoDecision.skip);
      expect(r[2].skipKind, SkipKind.blurry);
    });

    test('範囲外・負の番号は捨てる', () {
      final r = parsePhotoPick(
        _wrap([_item(-1, 'pick', rank: 1), _item(5, 'pick', rank: 2)]),
        2,
      );
      expect(r.map((e) => e.index), [0, 1]);
      expect(r.every((e) => e.decision == PhotoDecision.candidate), isTrue);
    });

    test('重複した番号は最初のものだけ', () {
      final r = parsePhotoPick(
        _wrap([_item(0, 'pick', rank: 1), _item(0, 'skip')]),
        1,
      );
      expect(r.single.decision, PhotoDecision.pick);
    });

    test('返ってこなかった番号は candidate', () {
      final r = parsePhotoPick(_wrap([_item(1, 'pick', rank: 1)]), 3);
      expect(r.map((e) => e.index), [0, 1, 2]);
      expect(r[0].decision, PhotoDecision.candidate);
      expect(r[2].decision, PhotoDecision.candidate);
    });

    test('pick が5枚以上なら rank の小さい順に4枚だけ。残りは candidate', () {
      final r = parsePhotoPick(
        _wrap([for (var i = 0; i < 6; i++) _item(i, 'pick', rank: 6 - i)]),
        6,
      );
      final picks = r.where((e) => e.decision == PhotoDecision.pick).toList();
      expect(picks, hasLength(4));
      // rank 1〜4 は index 5,4,3,2
      expect(picks.map((e) => e.index).toSet(), {2, 3, 4, 5});
      expect(r[0].decision, PhotoDecision.candidate);
      expect(r[1].decision, PhotoDecision.candidate);
    });

    test('rank が無い pick は番号順に4枚', () {
      final r = parsePhotoPick(
        _wrap([for (var i = 0; i < 6; i++) _item(i, 'pick')]),
        6,
      );
      final picks = r.where((e) => e.decision == PhotoDecision.pick);
      expect(picks.map((e) => e.index), [0, 1, 2, 3]);
    });

    test('maxPicks を指定できる', () {
      final r = parsePhotoPick(
        _wrap([for (var i = 0; i < 3; i++) _item(i, 'pick', rank: i + 1)]),
        3,
        maxPicks: 1,
      );
      expect(r.where((e) => e.decision == PhotoDecision.pick), hasLength(1));
    });

    test('skipKind が無い・知らない値は other', () {
      final r = parsePhotoPick(
        _wrap([_item(0, 'skip'), _item(1, 'skip', skipKind: 'weird')]),
        2,
      );
      expect(r[0].skipKind, SkipKind.other);
      expect(r[1].skipKind, SkipKind.other);
    });

    test('pick・candidate には skipKind を付けない', () {
      final r = parsePhotoPick(
        _wrap([_item(0, 'pick', rank: 1, skipKind: 'blurry')]),
        1,
      );
      expect(r.single.skipKind, isNull);
    });

    test('label は10文字までに切り、空・空白だけは null', () {
      final r = parsePhotoPick(
        _wrap([
          _item(0, 'pick', rank: 1, label: 'あ' * 11),
          _item(1, 'candidate', label: '   '),
          _item(2, 'candidate', label: 'あ' * 10),
        ]),
        3,
      );
      expect(r[0].label, 'あ' * 10);
      expect(r[1].label, isNull);
      expect(r[2].label, 'あ' * 10);
    });

    test('知らない decision は candidate', () {
      final r = parsePhotoPick(_wrap([_item(0, 'excellent')]), 1);
      expect(r.single.decision, PhotoDecision.candidate);
    });

    test('index・rank が文字列や小数でも読める', () {
      final r = parsePhotoPick(
        _wrap([
          {'index': '1', 'decision': 'pick', 'rank': '2'},
          {'index': 0.0, 'decision': 'skip'},
        ]),
        2,
      );
      expect(r[1].decision, PhotoDecision.pick);
      expect(r[1].rank, 2);
      expect(r[0].decision, PhotoDecision.skip);
    });

    test('配列がそのまま来ても読める', () {
      final r = parsePhotoPick([_item(0, 'pick', rank: 1)], 1);
      expect(r.single.decision, PhotoDecision.pick);
    });

    test('壊れた入力でも例外を投げず、全部 candidate（枚数ぶん）', () {
      for (final bad in <Object?>[
        null,
        'text',
        42,
        <Object?>[],
        <String, Object?>{},
        {'items': 'no'},
        {
          'items': [1, 'x', null, <Object?>[]],
        },
        {
          'items': [
            {'index': null, 'decision': 5},
            {'index': {}, 'decision': []},
          ],
        },
      ]) {
        final r = parsePhotoPick(bad, 3);
        expect(r, hasLength(3), reason: '$bad');
        expect(r.map((e) => e.index), [0, 1, 2]);
        expect(
          r.every((e) => e.decision == PhotoDecision.candidate),
          isTrue,
          reason: '$bad',
        );
      }
    });

    test('count が 0 以下なら空', () {
      expect(parsePhotoPick(_wrap([_item(0, 'pick')]), 0), isEmpty);
      expect(parsePhotoPick(null, -1), isEmpty);
    });
  });

  group('skipReasonText（固定の文）', () {
    test('種類ごと', () {
      expect(skipReasonText(SkipKind.duplicate), '似ているため');
      expect(skipReasonText(SkipKind.blurry), 'ピントがずれているため');
      expect(skipReasonText(SkipKind.screenshot), 'スクリーンショットのため');
      expect(skipReasonText(SkipKind.unrelated), 'ライブと関係なさそうなため');
      expect(skipReasonText(SkipKind.other), '今回は選ばなかったため');
      expect(skipReasonText(null), '今回は選ばなかったため');
    });
  });

  group('buildPhotoPickPrompt', () {
    final request = PhotoPickRequest(
      title: 'ツアー2026',
      startAt: DateTime.utc(2026, 12, 19, 9, 30),
      venue: '東京ドーム',
      artist: 'ひかり',
      candidates: [
        PhotoPickCandidate(Uint8List.fromList([1]), 'image/jpeg'),
      ],
    );

    test('ライブ名・日時（日本時間）・会場・アーティスト名が入る', () {
      final p = buildPhotoPickPrompt(request);
      expect(p, contains('ツアー2026'));
      expect(p, contains('2026/12/19 18:30'));
      expect(p, contains('東京ドーム'));
      expect(p, contains('ひかり'));
    });

    test('アーティスト名が無ければ、その行は無い', () {
      final p = buildPhotoPickPrompt(
        PhotoPickRequest(
          title: 'T',
          startAt: DateTime.utc(2026, 12, 19),
          venue: 'V',
          candidates: const [],
        ),
      );
      expect(p, isNot(contains('アーティスト：')));
    });

    test('人物を特定しない旨が入る', () {
      final p = buildPhotoPickPrompt(request);
      expect(p, contains('人物を特定しません'));
    });

    test('座席・メール・利用者名・トークンに関する語が入らない', () {
      final p = buildPhotoPickPrompt(request);
      expect(p, isNot(contains('座席')));
      expect(p, isNot(contains('@')));
      expect(p, isNot(contains('メール')));
      expect(p, isNot(contains('http')));
    });
  });

  group('GeminiPhotoPickAi.buildContents（Gemini は呼ばない）', () {
    test('番号つきの順序で、画像の前に「写真 i」の文が並ぶ', () {
      final ai = GeminiPhotoPickAi();
      final contents = ai.buildContents(
        PhotoPickRequest(
          title: 'T',
          startAt: DateTime.utc(2026, 12, 19),
          venue: 'V',
          candidates: [
            PhotoPickCandidate(Uint8List.fromList([1]), 'image/jpeg'),
            PhotoPickCandidate(
              Uint8List.fromList([2]),
              'image/png',
              createTime: DateTime.utc(2026, 12, 19, 9),
            ),
          ],
        ),
      );
      expect(contents, hasLength(1));
      final parts = contents.single.parts;
      // 指示 + (文 + 画像) × 2
      expect(parts, hasLength(5));
      expect(parts[1].toJson().toString(), contains('写真 0'));
      expect(parts[3].toJson().toString(), contains('写真 1'));
      expect(parts[3].toJson().toString(), contains('撮影 2026/12/19 18:00'));
    });
  });
}
