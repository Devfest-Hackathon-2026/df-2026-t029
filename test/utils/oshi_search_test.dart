import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/utils/oshi_search.dart';

OshiSummary _oshi(
  String id,
  String name, {
  OshiKind kind = OshiKind.group,
  OshiStatus status = OshiStatus.approved,
  List<String> aliases = const [],
}) {
  return OshiSummary(
    id: id,
    kind: kind,
    name: name,
    aliases: aliases,
    genre: OshiGenre.idol,
    status: status,
  );
}

List<String> _ids(List<OshiSummary> list) => [for (final o in list) o.id];

void main() {
  group('searchOshis: 空のクエリ', () {
    final all = [
      _oshi('c', 'ちぇりー'),
      _oshi('p', 'あんず', status: OshiStatus.pending),
      _oshi('a', 'いちご'),
      _oshi('b', 'アップル'),
    ];

    test('空文字なら承認済みだけを名前（正規化後）順に返す', () {
      expect(_ids(searchOshis(all, '')), ['b', 'a', 'c']);
    });

    test('空白だけ・記号だけのクエリも空として扱う', () {
      expect(_ids(searchOshis(all, '　 ')), ['b', 'a', 'c']);
      expect(_ids(searchOshis(all, '・-')), ['b', 'a', 'c']);
    });

    test('一覧が空なら空', () {
      expect(searchOshis(const [], ''), isEmpty);
      expect(searchOshis(const [], 'あ'), isEmpty);
    });

    test('入力のリストを並べ替えない', () {
      final copy = [...all];
      searchOshis(copy, '');
      expect(_ids(copy), _ids(all));
    });
  });

  group('searchOshis: 一致の判定', () {
    test('ひらがな・カタカナ・半角カナ・全角英字の揺れを吸収する', () {
      final all = [_oshi('1', 'サクラ'), _oshi('2', 'SnowMan')];
      expect(_ids(searchOshis(all, 'さくら')), ['1']);
      expect(_ids(searchOshis(all, 'ｻｸﾗ')), ['1']);
      expect(_ids(searchOshis(all, 'ｓｎｏｗ　ｍａｎ')), ['2']);
      expect(_ids(searchOshis(all, 'snow-man')), ['2']);
    });

    test('別名でも一致する', () {
      final all = [
        _oshi('1', 'Hey! Say! JUMP', aliases: ['へいせいじゃんぷ', 'JUMP']),
      ];
      expect(_ids(searchOshis(all, 'へいせい')), ['1']);
      expect(_ids(searchOshis(all, 'jump')), ['1']);
    });

    test('申請中も検索結果に含める', () {
      final all = [_oshi('1', 'さくら', status: OshiStatus.pending)];
      expect(_ids(searchOshis(all, 'さくら')), ['1']);
    });

    test('一致しなければ空', () {
      final all = [_oshi('1', 'さくら')];
      expect(searchOshis(all, 'もも'), isEmpty);
    });

    test('グループと個人を混ぜて返す', () {
      final all = [
        _oshi('g', 'さくら', kind: OshiKind.group),
        _oshi('p', 'さくら', kind: OshiKind.person),
      ];
      expect(searchOshis(all, 'さくら').map((o) => o.kind).toSet(), {
        OshiKind.group,
        OshiKind.person,
      });
    });
  });

  group('searchOshis: 並び順', () {
    test('完全一致 → 前方一致 → 部分一致', () {
      final all = [
        _oshi('partial', 'はなさくら'),
        _oshi('prefix', 'さくら学院'),
        _oshi('exact', 'さくら'),
      ];
      expect(_ids(searchOshis(all, 'サクラ')), ['exact', 'prefix', 'partial']);
    });

    test('別名で完全一致したものは、名前で前方一致したものより先', () {
      final all = [
        _oshi('prefix', 'さくらんぼ'),
        _oshi('alias', 'チェリー', aliases: ['さくら']),
      ];
      expect(_ids(searchOshis(all, 'さくら')), ['alias', 'prefix']);
    });

    test('同順位なら承認済みが申請中より先、次に名前順', () {
      final all = [
        _oshi('pending-a', 'さくらあ', status: OshiStatus.pending),
        _oshi('approved-i', 'さくらい'),
        _oshi('approved-u', 'さくらう'),
      ];
      expect(_ids(searchOshis(all, 'さくら')), [
        'approved-i',
        'approved-u',
        'pending-a',
      ]);
    });

    test('完全一致の申請中は、前方一致の承認済みより先', () {
      final all = [
        _oshi('approved-prefix', 'さくら学院'),
        _oshi('pending-exact', 'さくら', status: OshiStatus.pending),
      ];
      expect(_ids(searchOshis(all, 'さくら')), [
        'pending-exact',
        'approved-prefix',
      ]);
    });

    test('名前が同じなら種別・ID で順序が決まる（毎回同じ）', () {
      final all = [
        _oshi('b', 'さくら', kind: OshiKind.person),
        _oshi('a', 'さくら', kind: OshiKind.person),
        _oshi('z', 'さくら', kind: OshiKind.group),
      ];
      final first = _ids(searchOshis(all, 'さくら'));
      expect(first, ['z', 'a', 'b']);
      expect(_ids(searchOshis(all.reversed.toList(), 'さくら')), first);
    });
  });

  group('findExactDuplicates', () {
    final all = [
      _oshi('g1', 'さくら', kind: OshiKind.group),
      _oshi('p1', 'ミコ', kind: OshiKind.person, aliases: ['みこち']),
      _oshi('p2', 'ペコラ', kind: OshiKind.person, status: OshiStatus.pending),
      _oshi('p3', 'さくらみこ', kind: OshiKind.person),
    ];

    test('正規化後に名前が完全一致すると見つかる', () {
      expect(
        _ids(findExactDuplicates(all, kind: OshiKind.group, name: 'ｻｸﾗ')),
        ['g1'],
      );
    });

    test('種別が違えば重複にしない', () {
      expect(
        findExactDuplicates(all, kind: OshiKind.person, name: 'さくら'),
        isEmpty,
      );
    });

    test('部分一致は重複にしない', () {
      expect(
        findExactDuplicates(all, kind: OshiKind.person, name: 'さくら'),
        isEmpty,
      );
      expect(
        findExactDuplicates(all, kind: OshiKind.person, name: 'み'),
        isEmpty,
      );
    });

    test('申請中も重複の対象にする', () {
      expect(
        _ids(findExactDuplicates(all, kind: OshiKind.person, name: 'ぺこら')),
        ['p2'],
      );
    });

    test('新しい名前と既存の別名、新しい別名と既存の名前・別名も突き合わせる', () {
      expect(
        _ids(findExactDuplicates(all, kind: OshiKind.person, name: 'ミコチ')),
        ['p1'],
      );
      expect(
        _ids(
          findExactDuplicates(
            all,
            kind: OshiKind.person,
            name: '別の名前',
            aliases: ['みこ'],
          ),
        ),
        ['p1'],
      );
      expect(
        _ids(
          findExactDuplicates(
            all,
            kind: OshiKind.person,
            name: '別の名前',
            aliases: ['ﾐｺﾁ'],
          ),
        ),
        ['p1'],
      );
    });

    test('正規化して空になる名前・別名は比べない', () {
      final withSymbolAlias = [
        _oshi('x', 'エックス', kind: OshiKind.person, aliases: ['・']),
      ];
      expect(
        findExactDuplicates(
          withSymbolAlias,
          kind: OshiKind.person,
          name: '　',
          aliases: ['-', ''],
        ),
        isEmpty,
      );
    });

    test('複数見つかったら承認済み → 申請中 → 名前順', () {
      final list = [
        _oshi('pend', 'もも', kind: OshiKind.person, status: OshiStatus.pending),
        _oshi('b', 'ﾓﾓ', kind: OshiKind.person),
        _oshi('a', 'モモ', kind: OshiKind.person),
      ];
      expect(
        _ids(findExactDuplicates(list, kind: OshiKind.person, name: 'もも')),
        // 正規化後が同じ「モモ」なので、元の表記（U+30E2 < U+FF93）で並ぶ
        ['a', 'b', 'pend'],
      );
    });
  });
}
