import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/performance.dart';
import 'package:oshiashi/utils/deadline.dart';
import 'package:oshiashi/utils/live_search.dart';

final now = DateTime(2026, 11, 6, 12);

Live live(String id, String title) =>
    Live(id: id, title: title, groupIds: const ['g1']);

Performance perf(String liveId, DateTime startAt) =>
    Performance(liveId: liveId, startAt: startAt, venue: '会場');

List<String?> ids(List<LiveListEntry> es) => [for (final e in es) e.live.id];

void main() {
  final lives = [
    live('a', 'ＬＩＶＥ ツアー'),
    live('b', 'ぷりんセスの旅'),
    live('c', 'プリンセス・フェス'),
  ];
  final perfs = [
    perf('a', DateTime(2026, 12, 1)),
    perf('b', DateTime(2026, 11, 20)),
    perf('c', DateTime(2026, 10, 1)),
  ];

  test('空の検索語・空白のみなら全件を、一覧と同じ順（近い順、終了は最後）で返す', () {
    expect(ids(searchLives(lives, perfs, '', now)), ['b', 'a', 'c']);
    expect(ids(searchLives(lives, perfs, ' 　 ', now)), ['b', 'a', 'c']);
  });

  test('全角・半角・大小文字・ひらがな・カタカナ・空白・中黒の揺れを吸収する', () {
    expect(ids(searchLives(lives, perfs, 'live', now)), ['a']);
    expect(ids(searchLives(lives, perfs, 'ライブ', now)), isEmpty);
    expect(ids(searchLives(lives, perfs, 'プリンセス', now)), ['b', 'c']);
    expect(ids(searchLives(lives, perfs, 'ぷりんせす', now)), ['b', 'c']);
    expect(ids(searchLives(lives, perfs, 'ﾌﾟﾘﾝｾｽ', now)), ['b', 'c']);
    expect(ids(searchLives(lives, perfs, 'ＬＩＶＥ　ツアー', now)), ['a']);
  });

  test('部分一致で、一致しなければ空', () {
    expect(ids(searchLives(lives, perfs, 'フェス', now)), ['c']);
    expect(searchLives(lives, perfs, 'ないよ', now), isEmpty);
  });

  test('空の入力は空', () {
    expect(searchLives(const [], const [], 'a', now), isEmpty);
  });

  test('公演が無いライブも返す（公演を絞り込みに使わない）', () {
    expect(ids(searchLives(lives, const [], 'ツアー', now)), ['a']);
  });
}
