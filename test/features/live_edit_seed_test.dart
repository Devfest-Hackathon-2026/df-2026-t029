// liveDraftFromExisting・LiveEditSeed（計画書 3.7 の編集）のテスト。
// 既存 → 下書き → toModels → diffLive の往復を確かめる。
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/live_form/live_draft.dart';
import 'package:oshiashi/features/live_form/live_draft_to_models.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/models/reception.dart';
import 'package:oshiashi/repositories/live_repository.dart';
import 'package:oshiashi/utils/live_diff.dart';

import '../utils/live_merge_fixtures.dart';
import 'oshi_test_helpers.dart';

final g1 = oshi('g1', 'グループ1');
final o1 = oshi('o1', '個人1', kind: OshiKind.person);

final base = existingLive(
  groupIds: ['g1'],
  oshiIds: ['o1'],
  officialUrl: 'https://e.com/t',
  performances: [
    existingPerf('p1', startAt: jst(2026, 12, 20, 18), prefecture: '東京都'),
    existingPerf('p2', startAt: jst(2026, 12, 21, 18), venue: '大阪城ホール'),
  ],
  receptions: [
    existingRec(
      'r1',
      paymentDeadline: jst(2026, 11, 28, 23, 59),
      prices: const [Price(seat: 'S席', amount: 9800)],
      winnersOnly: true,
    ),
    existingRec(
      'r2',
      type: ReceptionType.general,
      name: '一般',
      applyEndAt: jst(2026, 12, 5),
    ),
  ],
);

LiveMergePlan diffOf(LiveEditSeed seed) {
  final ids = seed.idsInOrder();
  return diffLive(
    base,
    seed.draft.toModels(),
    performanceIds: ids.performanceIds,
    receptionIds: ids.receptionIds,
    editing: true,
  );
}

void main() {
  test('既存の内容がそのまま下書きに入り、往復しても差分が出ない', () {
    final seed = liveDraftFromExisting(base, [g1, o1]);
    expect(seed.liveId, 'L1');
    final d = seed.draft;
    expect(d.title, 'ツアー2026');
    expect(d.officialUrl, 'https://e.com/t');
    expect(d.selectedPerformers.map((o) => o.id), ['g1', 'o1']);
    expect(d.performances.map((p) => p.venue), ['東京ドーム', '大阪城ホール']);
    expect(d.performances.first.prefecture, '東京都');
    expect(d.performances.last.prefecture, ''); // 無い任意項目は空文字
    expect(d.receptions.first.prices.single.amount, 9800);
    expect(d.receptions.first.winnersOnly, isTrue);
    expect(seed.idsInOrder().performanceIds, ['p1', 'p2']);
    expect(seed.idsInOrder().receptionIds, ['r1', 'r2']);

    expect(diffOf(seed).isEmpty, isTrue);
  });

  test('開演日を変え、都道府県を空にすると、ID で対応して2項目の変更', () {
    final seed = liveDraftFromExisting(base, [g1, o1]);
    seed.draft.performances.first
      ..startAt = jst(2026, 12, 27, 18)
      ..prefecture = '';
    final plan = diffOf(seed);
    final d = plan.changedPerformances.single;
    expect(d.existing.id, 'p1');
    expect(
      d.changes.map((c) => c.field),
      unorderedEquals(['startAt', 'prefecture']),
    );
    expect(
      d.changes.firstWhere((c) => c.field == 'prefecture').hasAfter,
      isFalse,
    );
    expect(plan.addedPerformances, isEmpty);
    expect(plan.existingOnlyPerformances, isEmpty);
  });

  test('行の並べ替え・削除・追加の後も、既存の ID を保つ', () {
    final seed = liveDraftFromExisting(base, [g1, o1]);
    final d = seed.draft;
    final first = d.performances.removeAt(0);
    d.performances.add(first); // p2, p1 の順
    d.performances.insert(
      0,
      PerformanceDraft(startAt: jst(2027, 1, 5, 18), venue: '新'),
    );
    d.receptions.removeAt(0); // r1 を消す
    expect(seed.idsInOrder().performanceIds, [null, 'p2', 'p1']);
    expect(seed.idsInOrder().receptionIds, ['r2']);

    final plan = diffOf(seed);
    expect(plan.addedPerformances.single.key, 'performances/+0');
    expect(plan.unchangedPerformances.map((p) => p.id), ['p1', 'p2']);
    // 消した行の既存の受付は消さず「今回の入力に無い」
    expect(plan.existingOnlyReceptions.single.id, 'r1');
  });

  test('中身が同じ行を2つ足しても、別の行として扱う（同一性で対応）', () {
    final seed = liveDraftFromExisting(base, [g1, o1]);
    seed.draft.performances.addAll([
      PerformanceDraft(startAt: jst(2027, 1, 5, 18), venue: '同じ'),
      PerformanceDraft(startAt: jst(2027, 1, 5, 18), venue: '同じ'),
    ]);
    expect(seed.idsInOrder().performanceIds, ['p1', 'p2', null, null]);
  });

  test('allOshis に無い出演者は下書きに入らないが、差分で外れない', () {
    final seed = liveDraftFromExisting(base, [g1]); // o1 が一覧に無い
    expect(seed.draft.selectedPerformers.map((o) => o.id), ['g1']);
    final plan = diffOf(seed);
    expect(plan.liveChanges, isEmpty);
    expect(plan.mergedLive.oshiIds, ['o1']);
  });

  test('当選者のみ（winnersOnly）を外す編集は変更になる', () {
    final seed = liveDraftFromExisting(base, [g1, o1]);
    seed.draft.receptions.first.winnersOnly = false;
    final c = diffOf(seed).changedReceptions.single.changes.single;
    expect((c.field, c.before, c.after), ('winnersOnly', true, false));
  });

  test('ID の無いライブは ArgumentError', () {
    final noId = ExistingLive(
      live: const Live(title: 'x', groupIds: ['g1']),
      performances: base.performances,
      receptions: const [],
    );
    expect(() => liveDraftFromExisting(noId, [g1]), throwsArgumentError);
  });
}
