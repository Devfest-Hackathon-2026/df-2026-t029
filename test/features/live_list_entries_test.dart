import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/live/live_list_entries.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/oshi.dart';

import 'oshi_test_helpers.dart';

// ライブ一覧の並べ替えと「終了」の判定は data の buildLiveList
// （test/utils/deadline_test.dart）で確かめる。ここでは出演者名だけを見る。

Live live({
  List<String> groupIds = const [],
  List<String> oshiIds = const [],
}) => Live(id: 'l1', title: 'A', groupIds: groupIds, oshiIds: oshiIds);

void main() {
  final oshis = [
    oshi('g1', 'グループ1'),
    oshi('g2', 'グループ2'),
    oshi('p1', '個人1', kind: OshiKind.person),
  ];

  // 2つの公開 API が同じ結果を返すことも、各テストで確かめる
  List<String> names(Live l, [List<OshiSummary>? list]) {
    final byFunction = performerNamesOf(l, list ?? oshis);
    final byClass = PerformerNames(list ?? oshis).of(l);
    expect(byClass, byFunction);
    return byFunction;
  }

  group('出演者名', () {
    test('グループ（groupIds の順）→ 個人（oshiIds の順）', () {
      expect(names(live(groupIds: ['g2', 'g1'], oshiIds: ['p1'])), [
        'グループ2',
        'グループ1',
        '個人1',
      ]);
    });

    test('出演者が0件なら空', () {
      expect(names(live()), isEmpty);
    });

    test('推しの一覧が空なら、出演者がいても「（不明な出演者）」だけ', () {
      expect(names(live(groupIds: ['g1']), const []), [unknownPerformerLabel]);
    });

    test('見つからない ID があれば、最後に「（不明な出演者）」を1つだけ', () {
      expect(
        names(live(groupIds: ['missing1', 'g1'], oshiIds: ['missing2', 'p1'])),
        ['グループ1', '個人1', unknownPerformerLabel],
      );
      expect(unknownPerformerLabel, '（不明な出演者）');
    });

    test('すべて見つからなければ「（不明な出演者）」だけ', () {
      expect(names(live(oshiIds: ['x'])), [unknownPerformerLabel]);
    });

    test('種類は区別する: 個人の ID を groupIds に入れても見つからない', () {
      expect(names(live(groupIds: ['p1'])), [unknownPerformerLabel]);
      expect(names(live(oshiIds: ['g1'])), [unknownPerformerLabel]);
    });

    test('同じ ID が重複していても名前は1回だけ', () {
      expect(names(live(groupIds: ['g1', 'g1'], oshiIds: ['p1', 'p1'])), [
        'グループ1',
        '個人1',
      ]);
    });

    test('グループとソロ名義が同じ名前でも、両方出す（種別/ID で重複を除く）', () {
      final list = [
        oshi('g', '同じ名前'),
        oshi('p', '同じ名前', kind: OshiKind.person),
      ];
      expect(names(live(groupIds: ['g'], oshiIds: ['p']), list), [
        '同じ名前',
        '同じ名前',
      ]);
    });

    test('別 ID の2グループが同じ名前でも、両方出す', () {
      final list = [oshi('a', '同名'), oshi('b', '同名')];
      expect(names(live(groupIds: ['a', 'b']), list), ['同名', '同名']);
    });

    test('グループと個人で同じ ID 文字列でも、それぞれの名前を引く', () {
      final list = [
        oshi('x', 'グループX'),
        oshi('x', '個人X', kind: OshiKind.person),
      ];
      expect(names(live(groupIds: ['x'], oshiIds: ['x']), list), [
        'グループX',
        '個人X',
      ]);
    });

    test('申請中の推しの名前も引ける（表示の可否は画面が決める）', () {
      final list = [oshi('g', '申請中', status: OshiStatus.pending)];
      expect(names(live(groupIds: ['g']), list), ['申請中']);
    });
  });
}
