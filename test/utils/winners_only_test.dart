import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/application.dart';
import 'package:oshiashi/models/reception.dart';
import 'package:oshiashi/utils/winners_only.dart';

Application app(String id, String liveId, ApplicationStatus s) =>
    Application(receptionId: id, liveId: liveId, status: s);

Reception rec(String id, String? liveId, {bool winnersOnly = false}) =>
    Reception(
      id: id,
      liveId: liveId,
      type: ReceptionType.upgrade,
      name: '受付$id',
      applyEndAt: DateTime(2026, 11, 10),
      winnersOnly: winnersOnly,
    );

void main() {
  group('winnerLiveIds', () {
    test('空なら空', () => expect(winnerLiveIds({}), isEmpty));

    test('won・paid のライブだけ含める。applied・lost は含めない', () {
      final ids = winnerLiveIds({
        'a': app('a', 'l1', ApplicationStatus.won),
        'b': app('b', 'l2', ApplicationStatus.paid),
        'c': app('c', 'l3', ApplicationStatus.applied),
        'd': app('d', 'l4', ApplicationStatus.lost),
      });
      expect(ids, {'l1', 'l2'});
    });

    test('同じライブに複数あっても1件。落選と当選が混ざれば当選を優先', () {
      final ids = winnerLiveIds({
        'a': app('a', 'l1', ApplicationStatus.lost),
        'b': app('b', 'l1', ApplicationStatus.won),
        'c': app('c', 'l1', ApplicationStatus.paid),
      });
      expect(ids, {'l1'});
    });
  });

  group('isReceptionVisible', () {
    test('winnersOnly でなければ、当選者でなくても true', () {
      expect(isReceptionVisible(rec('r', 'l1'), {}), isTrue);
    });

    test('winnersOnly は、そのライブで当選しているときだけ true', () {
      final r = rec('r', 'l1', winnersOnly: true);
      expect(isReceptionVisible(r, {}), isFalse);
      expect(isReceptionVisible(r, {'l2'}), isFalse);
      expect(isReceptionVisible(r, {'l1'}), isTrue);
    });

    test('winnersOnly で liveId が null なら false', () {
      expect(
        isReceptionVisible(rec('r', null, winnersOnly: true), {'l1'}),
        isFalse,
      );
    });
  });

  group('splitVisibleReceptions', () {
    test('0件', () {
      final s = splitVisibleReceptions([], {});
      expect(s.visible, isEmpty);
      expect(s.hiddenCount, 0);
    });

    test('順序を保ち、隠した件数を数える', () {
      final list = [
        rec('a', 'l1'),
        rec('b', 'l1', winnersOnly: true),
        rec('c', 'l1'),
        rec('d', 'l1', winnersOnly: true),
      ];
      final s = splitVisibleReceptions(list, {});
      expect([for (final r in s.visible) r.id], ['a', 'c']);
      expect(s.hiddenCount, 2);
      final w = splitVisibleReceptions(list, {'l1'});
      expect([for (final r in w.visible) r.id], ['a', 'b', 'c', 'd']);
      expect(w.hiddenCount, 0);
    });

    test('すべて隠れる場合', () {
      final s = splitVisibleReceptions([rec('a', 'l1', winnersOnly: true)], {});
      expect(s.visible, isEmpty);
      expect(s.hiddenCount, 1);
    });
  });
}
