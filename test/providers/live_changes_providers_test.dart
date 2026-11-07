// Step4 のプロバイダ（fetchLiveCandidates・liveChangesProvider・
// recentChangesProvider・existingLiveProvider）のテスト
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/history_entry.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/utils/live_match.dart';

import '../features/live_test_helpers.dart';
import '../utils/live_merge_fixtures.dart';

const _live = HistoryTarget(HistoryCollection.lives, 'L1');
const _p1 = HistoryTarget(HistoryCollection.performances, 'p1');
const _r1 = HistoryTarget(HistoryCollection.receptions, 'r1');
final _now = DateTime.utc(2026, 11, 10, 12);
final _created = DateTime.utc(2026, 10, 1);

HistoryEntry _h(String id, HistoryTarget t, DateTime? at) => HistoryEntry(
  id: id,
  target: t,
  field: 'venue',
  before: 'A',
  after: 'B',
  hasBefore: true,
  hasAfter: true,
  changedBy: 'u',
  changedAt: at,
);

void main() {
  late FakeLiveRepository repo;
  late ProviderContainer c;

  setUp(() {
    repo = FakeLiveRepository();
    c = ProviderContainer(
      overrides: [
        liveRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(_now),
      ],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
  });

  /// [p] の値を購読し、イベントループを回して最新の値を返す
  Future<T> read<T>(ProviderListenable<T> p) async {
    final sub = c.listen(p, (_, _) {});
    addTearDown(sub.close);
    await pumpEventQueue();
    return sub.read();
  }

  test('fetchLiveCandidates: 入力の出演者で読み、findLiveCandidates で判定する', () async {
    repo.candidates = [
      existingLive(),
      existingLive(
        id: 'L2',
        title: '別',
        performances: [existingPerf('x', venue: 'X')],
      ),
    ];
    final result = await fetchLiveCandidates(
      repo,
      input(groupIds: ['g1'], oshiIds: ['o1']),
    );
    expect(repo.candidateCalls.single.groupIds, ['g1']);
    expect(repo.candidateCalls.single.oshiIds, ['o1']);
    expect(result.map((x) => x.existing.live.id), ['L1']);
    expect(result.single.strength, MatchStrength.sure);
  });

  test('existingLiveProvider: 無いライブは null', () async {
    repo.existing = {'L1': existingLive()};
    expect((await read(existingLiveProvider('L1'))).value?.live.id, 'L1');
    expect((await read(existingLiveProvider('none'))).value, isNull);
  });

  test('liveChangesProvider: ドキュメントごとの履歴と、後から追加した公演をまとめ、新しい順', () async {
    repo.docStamps = {
      'L1': [
        DocStamp(target: _live, createdAt: _created),
        DocStamp(target: _p1, createdAt: _created),
        DocStamp(target: _r1, createdAt: _created.add(const Duration(days: 3))),
      ],
    };
    repo.history = {
      _live: [_h('l', _live, DateTime.utc(2026, 11, 1))],
      _p1: [_h('p', _p1, DateTime.utc(2026, 11, 9))],
    };
    final v = await read(liveChangesProvider('L1'));
    final changes = v.requireValue;
    expect(changes, hasLength(3));
    expect((changes[0] as FieldEdited).entry.id, 'p');
    expect((changes[1] as FieldEdited).entry.id, 'l');
    expect(changes[2], isA<DocAdded>());
    expect(changes[2].target, _r1);
  });

  test('liveChangesProvider: 履歴の1つが読み込み中なら読み込み中、エラーならエラー', () async {
    repo.docStamps = {
      'L1': [DocStamp(target: _live, createdAt: _created)],
    };
    repo.emitInitial = false;
    expect((await read(liveChangesProvider('L1'))).isLoading, isTrue);

    final repo2 = FakeLiveRepository()..fail = true;
    final c2 = ProviderContainer(
      overrides: [liveRepositoryProvider.overrideWithValue(repo2)],
      retry: (_, _) => null,
    );
    addTearDown(c2.dispose);
    final sub = c2.listen(liveChangesProvider('L1'), (_, _) {});
    addTearDown(sub.close);
    await pumpEventQueue();
    expect(sub.read().hasError, isTrue);
  });

  test('liveChangesProvider: 新しい履歴が流れると更新される', () async {
    repo.docStamps = {
      'L1': [DocStamp(target: _live, createdAt: _created)],
    };
    final sub = c.listen(liveChangesProvider('L1'), (_, _) {});
    addTearDown(sub.close);
    await pumpEventQueue();
    expect(sub.read().requireValue, isEmpty);
    repo.setHistory(_live, [_h('new', _live, DateTime.utc(2026, 11, 9))]);
    await pumpEventQueue();
    expect(sub.read().requireValue, hasLength(1));
  });

  test('recentChangesProvider: nowProvider から7日以内のものだけ、ドキュメントごとに直近', () async {
    repo.docStamps = {
      'L1': [
        DocStamp(target: _live, createdAt: _created),
        DocStamp(target: _p1, createdAt: _created),
        DocStamp(target: _r1, createdAt: _created),
      ],
    };
    repo.history = {
      _p1: [
        _h('old', _p1, _now.subtract(const Duration(days: 2))),
        _h('new', _p1, _now.subtract(const Duration(hours: 1))),
      ],
      _r1: [_h('r', _r1, _now.subtract(const Duration(days: 8)))],
    };
    final m = (await read(recentChangesProvider('L1'))).requireValue;
    expect(m.keys, [_p1]);
    expect((m[_p1]! as FieldEdited).entry.id, 'new');
  });
}
