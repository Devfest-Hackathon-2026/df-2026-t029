// findLiveCandidates（計画書 3.1）のテスト
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/utils/live_match.dart';

import 'live_merge_fixtures.dart';

void main() {
  group('ほぼ確実', () {
    test('公式 URL が同じ（末尾の / と大文字小文字・前後の空白は無視）', () {
      final e = existingLive(
        title: '全く別の名前',
        officialUrl: 'https://Example.com/Tour2026/',
        performances: [existingPerf('p', startAt: jst(2027, 3, 1, 18))],
      );
      final c = findLiveCandidates(
        input(officialUrl: ' https://example.com/tour2026 '),
        [e],
      );
      expect(c, hasLength(1));
      expect(c.single.strength, MatchStrength.sure);
      expect(c.single.reasons, contains('公式 URL が同じ'));
    });

    test('URL が途中で違えば一致しない', () {
      final e = existingLive(
        title: '別',
        officialUrl: 'https://example.com/tour2025',
        performances: [existingPerf('p', startAt: jst(2027, 3, 1, 18))],
      );
      expect(
        findLiveCandidates(input(officialUrl: 'https://example.com/tour2026'), [
          e,
        ]),
        isEmpty,
      );
    });

    test('入力の URL が空なら、既存の URL が空でも「URL が同じ」にしない', () {
      final e = existingLive(
        title: '別',
        performances: [existingPerf('p', startAt: jst(2027, 3, 1, 18))],
      );
      expect(findLiveCandidates(input(title: 'ツアー'), [e]), isEmpty);
    });

    test('正規化したライブ名が同じ（カタカナ／ひらがな・全角／半角・空白）', () {
      final e = existingLive(
        title: 'ＬＩＶＥ ツアー２０２６',
        performances: [existingPerf('p', startAt: jst(2027, 3, 1, 18))],
      );
      final c = findLiveCandidates(input(title: 'LIVE  つあー2026'), [e]);
      expect(c, hasLength(1));
      expect(c.single.strength, MatchStrength.sure);
      expect(c.single.reasons, contains('ライブ名が同じ'));
    });

    test('URL と名前の両方が同じなら理由は2つ', () {
      final e = existingLive(officialUrl: 'https://e.com/t');
      final c = findLiveCandidates(input(officialUrl: 'https://e.com/t/'), [e]);
      expect(c.single.reasons, containsAll(['公式 URL が同じ', 'ライブ名が同じ']));
    });
  });

  group('可能性あり', () {
    test('名前の一方が他方を含み、同じ日（日本時間）の公演がある', () {
      final e = existingLive(
        title: 'ツアー2026',
        performances: [
          existingPerf('p', startAt: jst(2026, 12, 20, 18), venue: '大阪城ホール'),
        ],
      );
      final c = findLiveCandidates(
        input(
          title: 'ツアー2026 追加公演',
          performances: [
            inputPerf(startAt: jst(2026, 12, 20, 13), venue: '別の会場'),
          ],
        ),
        [e],
      );
      expect(c, hasLength(1));
      expect(c.single.strength, MatchStrength.possible);
      expect(c.single.reasons.single, contains('12/20(日)'));
    });

    test('名前が含まれても、同じ日の公演が無ければ候補にしない', () {
      final e = existingLive(
        title: 'ツアー2026',
        performances: [existingPerf('p', startAt: jst(2026, 12, 20, 18))],
      );
      expect(
        findLiveCandidates(
          input(
            title: 'ツアー2026 追加公演',
            performances: [inputPerf(startAt: jst(2026, 12, 21, 18))],
          ),
          [e],
        ),
        isEmpty,
      );
    });

    test('日本時間の日で比べる（UTC では同じ日でも、日本時間で別の日なら別）', () {
      // 既存: 12/20 23:30 JST（UTC 12/20 14:30）。入力: 12/21 00:30 JST（UTC 12/20 15:30）
      final e = existingLive(
        title: 'ツアー2026',
        performances: [
          existingPerf('p', startAt: jst(2026, 12, 20, 23, 30), venue: 'A'),
        ],
      );
      final inp = input(
        title: 'ツアー2026 追加',
        performances: [
          inputPerf(startAt: jst(2026, 12, 21, 0, 30), venue: 'A'),
        ],
      );
      expect(findLiveCandidates(inp, [e]), isEmpty);
    });

    test('ライブ名は違うが、同じ日・同じ会場（正規化）の公演がある', () {
      final e = existingLive(
        title: 'ウィンターフェス',
        performances: [
          existingPerf(
            'p',
            startAt: jst(2026, 12, 20, 18),
            venue: 'さいたまスーパーアリーナ',
          ),
        ],
      );
      final c = findLiveCandidates(
        input(
          title: '冬の対バン',
          performances: [
            inputPerf(startAt: jst(2026, 12, 20, 12), venue: 'さいたま スーパーアリーナ'),
          ],
        ),
        [e],
      );
      expect(c.single.strength, MatchStrength.possible);
      expect(c.single.reasons.single, contains('同じ会場'));
    });

    test('同じ日でも会場が違い、名前も違えば候補にしない（出演者が同じ別のライブ）', () {
      final e = existingLive(
        title: 'ファンミーティング',
        performances: [existingPerf('p', venue: 'Zepp Haneda')],
      );
      expect(
        findLiveCandidates(
          input(
            title: 'ツアー2026',
            performances: [inputPerf(venue: '東京ドーム')],
          ),
          [e],
        ),
        isEmpty,
      );
    });
  });

  group('並び順と件数', () {
    test('ほぼ確実が可能性ありより先。別のツアー（似た名前）は上位に来ない', () {
      final sameName = existingLive(
        id: 'z-same',
        title: 'ツアー2026',
        performances: [existingPerf('a', startAt: jst(2027, 5, 1, 18))],
      );
      final similar = existingLive(
        id: 'a-similar',
        title: 'ツアー2026 ファイナル',
        performances: [
          existingPerf('b'),
          existingPerf('c', venue: '東京ドーム'),
        ],
      );
      final c = findLiveCandidates(input(), [similar, sameName]);
      expect(c.map((x) => x.existing.live.id), ['z-same', 'a-similar']);
    });

    test('同じ強さなら理由が多い順 → 最初の公演が近い順 → ID の順', () {
      // 3件とも「ライブ名が同じ」。more は会場も同じで理由が2つ
      final more = existingLive(
        id: 'm',
        performances: [existingPerf('m1', startAt: jst(2026, 12, 20, 18))],
      );
      final near = existingLive(
        id: 'n',
        performances: [
          existingPerf('n1', startAt: jst(2026, 12, 25, 18), venue: '他'),
        ],
      );
      final far = existingLive(
        id: 'f',
        performances: [
          existingPerf('f1', startAt: jst(2027, 6, 1, 18), venue: '他'),
        ],
      );
      final c = findLiveCandidates(input(), [far, near, more]);
      expect(c.map((x) => x.existing.live.id), ['m', 'n', 'f']);

      // 距離も同じなら ID の順
      final b = existingLive(
        id: 'b',
        performances: [
          existingPerf('b1', startAt: jst(2026, 12, 25, 18), venue: '他'),
        ],
      );
      final a = existingLive(
        id: 'a',
        performances: [
          existingPerf('a1', startAt: jst(2026, 12, 25, 18), venue: '他'),
        ],
      );
      expect(
        findLiveCandidates(input(), [b, a]).map((x) => x.existing.live.id),
        ['a', 'b'],
      );
    });

    test('最大3件（limit で変えられる）。同じ ID は1件にする', () {
      final lives = [
        for (var i = 0; i < 5; i++)
          existingLive(
            id: 'L$i',
            performances: [
              existingPerf(
                'p$i',
                startAt: jst(2026, 12, 21 + i, 18),
                venue: '他',
              ),
            ],
          ),
      ];
      expect(findLiveCandidates(input(), lives), hasLength(3));
      expect(findLiveCandidates(input(), lives, limit: 5), hasLength(5));
      expect(findLiveCandidates(input(), [lives[0], lives[0]]), hasLength(1));
    });

    test('既存が空・当てはまるものが無ければ空', () {
      expect(findLiveCandidates(input(), const []), isEmpty);
      expect(
        findLiveCandidates(input(title: 'A'), [
          existingLive(
            title: 'B',
            performances: [existingPerf('p', venue: 'X')],
          ),
        ]),
        isEmpty,
      );
    });
  });
}
