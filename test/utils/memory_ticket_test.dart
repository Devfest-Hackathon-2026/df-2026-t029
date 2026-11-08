// memoryProgress・recentUnpostedMemory のテスト（Q1）。時刻はすべて固定の値。
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/live_memory.dart';
import 'package:oshiashi/utils/memory_ticket.dart';

final _now = DateTime(2026, 11, 8, 12);

LiveMemory _mem(
  String id, {
  required DateTime startAt,
  String? seat,
  List<String> setlist = const [],
  String? impression,
  List<String> images = const [],
  DateTime? postedAt,
}) => LiveMemory(
  performanceId: id,
  liveId: 'l$id',
  liveTitle: 'ライブ$id',
  startAt: startAt,
  venue: '会場$id',
  seat: seat,
  setlist: setlist,
  impression: impression,
  images: images,
  postedAt: postedAt,
);

void main() {
  group('memoryProgress', () {
    final at = DateTime(2026, 10, 1, 18);

    test('何も入っていなければ 0', () {
      expect(memoryProgress(_mem('a', startAt: at)), 0);
    });

    test('4つとも入っていれば 4', () {
      final m = _mem(
        'a',
        startAt: at,
        seat: 'A1',
        setlist: const ['曲1'],
        impression: '良かった',
        images: const ['p/1.jpg'],
      );
      expect(memoryProgress(m), 4);
    });

    test('写真だけ・座席だけ・セトリだけ・感想だけは、それぞれ 1', () {
      expect(
        memoryProgress(_mem('a', startAt: at, images: const ['p/1.jpg'])),
        1,
      );
      expect(memoryProgress(_mem('a', startAt: at, seat: 'A1')), 1);
      expect(memoryProgress(_mem('a', startAt: at, setlist: ['曲1'])), 1);
      expect(memoryProgress(_mem('a', startAt: at, impression: '感想')), 1);
    });

    test('座席が空白だけ（半角・全角・改行）なら入っていない', () {
      expect(memoryProgress(_mem('a', startAt: at, seat: '   ')), 0);
      expect(memoryProgress(_mem('a', startAt: at, seat: '　\n ')), 0);
      expect(memoryProgress(_mem('a', startAt: at, seat: '')), 0);
    });

    test('感想が空白だけなら入っていない', () {
      expect(memoryProgress(_mem('a', startAt: at, impression: ' \n\t ')), 0);
      expect(memoryProgress(_mem('a', startAt: at, impression: '')), 0);
    });

    test('写真は1枚でも 1、枚数は数えない', () {
      final many = List.generate(8, (i) => 'p/$i.jpg');
      expect(memoryProgress(_mem('a', startAt: at, images: many)), 1);
    });

    test('写真0枚でも、ほかの3つが入っていれば 3', () {
      final m = _mem(
        'a',
        startAt: at,
        seat: 'A1',
        setlist: const ['曲1', '曲2'],
        impression: '感想',
      );
      expect(memoryProgress(m), 3);
    });
  });

  group('recentUnpostedMemory', () {
    test('空の入力は null', () {
      expect(recentUnpostedMemory(const [], _now), isNull);
    });

    test('1日前の参戦済みは出る', () {
      final m = _mem('a', startAt: _now.subtract(const Duration(days: 1)));
      expect(recentUnpostedMemory([m], _now), same(m));
    });

    test('ちょうど開演の時刻（startAt == now）は参戦済みとして出る', () {
      final m = _mem('a', startAt: _now);
      expect(recentUnpostedMemory([m], _now), same(m));
    });

    test('ちょうど7日前は出る（境界を含む）', () {
      final m = _mem('a', startAt: _now.subtract(const Duration(days: 7)));
      expect(recentUnpostedMemory([m], _now), same(m));
    });

    test('7日と1分前は出ない', () {
      final m = _mem(
        'a',
        startAt: _now.subtract(const Duration(days: 7, minutes: 1)),
      );
      expect(recentUnpostedMemory([m], _now), isNull);
    });

    test('8日前は出ない', () {
      final m = _mem('a', startAt: _now.subtract(const Duration(days: 8)));
      expect(recentUnpostedMemory([m], _now), isNull);
    });

    test('参戦予定（開演が now より後）は出ない', () {
      final m = _mem('a', startAt: _now.add(const Duration(minutes: 1)));
      expect(recentUnpostedMemory([m], _now), isNull);
    });

    test('postedAt があれば出ない', () {
      final m = _mem(
        'a',
        startAt: _now.subtract(const Duration(days: 1)),
        postedAt: _now.subtract(const Duration(hours: 1)),
      );
      expect(recentUnpostedMemory([m], _now), isNull);
    });

    test('複数あれば、開演がいちばん新しい1件', () {
      final older = _mem('o', startAt: _now.subtract(const Duration(days: 5)));
      final newest = _mem('n', startAt: _now.subtract(const Duration(days: 1)));
      final mid = _mem('m', startAt: _now.subtract(const Duration(days: 3)));
      expect(recentUnpostedMemory([older, newest, mid], _now), same(newest));
      expect(recentUnpostedMemory([newest, mid, older], _now), same(newest));
    });

    test('いちばん新しいものが投稿済みなら、その次に新しい未投稿が出る', () {
      final posted = _mem(
        'p',
        startAt: _now.subtract(const Duration(days: 1)),
        postedAt: _now,
      );
      final other = _mem('o', startAt: _now.subtract(const Duration(days: 4)));
      expect(recentUnpostedMemory([posted, other], _now), same(other));
    });

    test('予定・古い・投稿済みだけが混じっていれば null', () {
      final list = [
        _mem('f', startAt: _now.add(const Duration(days: 3))),
        _mem('o', startAt: _now.subtract(const Duration(days: 30))),
        _mem(
          'p',
          startAt: _now.subtract(const Duration(days: 2)),
          postedAt: _now,
        ),
      ];
      expect(recentUnpostedMemory(list, _now), isNull);
    });

    test('recentMemoryDays は 7', () {
      expect(recentMemoryDays, 7);
    });
  });
}
