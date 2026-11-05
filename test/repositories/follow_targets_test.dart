import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/repositories/live_repository.dart';

OshiSummary groupOshi(String id) => OshiSummary(
  id: id,
  kind: OshiKind.group,
  name: id,
  genre: OshiGenre.idol,
  status: OshiStatus.approved,
);

OshiSummary person(String id, {List<String> groupIds = const []}) =>
    OshiSummary(
      id: id,
      kind: OshiKind.person,
      name: id,
      genre: OshiGenre.idol,
      status: OshiStatus.approved,
      groupIds: groupIds,
    );

void main() {
  group('FollowTargets.fromFollowing', () {
    test('フォロー0件なら空（問い合わせない）', () {
      final t = FollowTargets.fromFollowing(const []);
      expect(t.isEmpty, isTrue);
      expect(t, FollowTargets.empty);
    });

    test('グループは groupIds へ', () {
      final t = FollowTargets.fromFollowing([groupOshi('g1'), groupOshi('g2')]);
      expect(t.groupIds, {'g1', 'g2'});
      expect(t.oshiIds, isEmpty);
      expect(t.isEmpty, isFalse);
    });

    test('個人は oshiIds へ、所属グループは groupIds へ足す', () {
      final t = FollowTargets.fromFollowing([
        person('p1', groupIds: ['g1', 'g2']),
      ]);
      expect(t.oshiIds, {'p1'});
      expect(t.groupIds, {'g1', 'g2'});
    });

    test('ソロ（所属なし）の個人だけでも空ではない', () {
      final t = FollowTargets.fromFollowing([person('p1')]);
      expect(t.groupIds, isEmpty);
      expect(t.oshiIds, {'p1'});
      expect(t.isEmpty, isFalse);
    });

    test('フォロー中のグループと所属グループが重なっても1つにまとまる', () {
      final t = FollowTargets.fromFollowing([
        groupOshi('g1'),
        person('p1', groupIds: ['g1']),
        person('p2', groupIds: ['g1', 'g3']),
      ]);
      expect(t.groupIds, {'g1', 'g3'});
      expect(t.oshiIds, {'p1', 'p2'});
    });

    test('グループと個人で同じ ID 文字列でも、別の集合に入る', () {
      final t = FollowTargets.fromFollowing([groupOshi('x'), person('x')]);
      expect(t.groupIds, {'x'});
      expect(t.oshiIds, {'x'});
    });

    test('結果の集合は変更できない', () {
      final t = FollowTargets.fromFollowing([groupOshi('g1'), person('p1')]);
      expect(() => t.groupIds.add('g2'), throwsUnsupportedError);
      expect(() => t.oshiIds.add('p2'), throwsUnsupportedError);
    });
  });

  group('FollowTargets の等価性', () {
    test('中身が同じなら、順序が違っても等しく hashCode も同じ', () {
      const a = FollowTargets(groupIds: {'g1', 'g2'}, oshiIds: {'p1', 'p2'});
      final b = FollowTargets.fromFollowing([
        person('p2'),
        groupOshi('g2'),
        person('p1'),
        groupOshi('g1'),
      ]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('ID が同じでも、グループと個人の区別が違えば等しくない', () {
      const a = FollowTargets(groupIds: {'x'});
      const b = FollowTargets(oshiIds: {'x'});
      expect(a == b, isFalse);
    });

    test('1件でも違えば等しくない', () {
      const a = FollowTargets(groupIds: {'g1'}, oshiIds: {'p1'});
      expect(
        a == const FollowTargets(groupIds: {'g1', 'g2'}, oshiIds: {'p1'}),
        isFalse,
      );
      expect(a == const FollowTargets(groupIds: {'g1'}), isFalse);
    });

    test('empty は空', () {
      expect(FollowTargets.empty.isEmpty, isTrue);
      expect(FollowTargets.empty, const FollowTargets());
    });
  });
}
