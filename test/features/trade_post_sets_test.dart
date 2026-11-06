// lib/features/trade/trade_post_draft.dart の譲セット・求セット（G-2-5）のテスト
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/trade/trade_post_draft.dart';
import 'package:oshiashi/models/goods.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/models/trade_post.dart';
import 'package:oshiashi/providers/goods_providers.dart';

import 'oshi_test_helpers.dart';

const vA = GoodsVariant(id: 'v1', name: 'メンバーA', oshiId: 'pA');
const vB = GoodsVariant(id: 'v2', name: 'メンバーB');
const acsta = Goods(
  id: 'acsta',
  name: 'ランダムアクスタ',
  category: GoodsCategory.acrylic,
  groupIds: ['g1'],
  variants: [vA, vB],
);
const towel = Goods(
  id: 'towel',
  name: 'タオル',
  category: GoodsCategory.other,
  groupIds: ['g1'],
  variants: [GoodsVariant(id: 'v1', name: '通常')],
);
final goodsById = {'acsta': acsta, 'towel': towel};

OshiSummary person(
  String id,
  String name, {
  List<String> groupIds = const [],
  OshiStatus status = OshiStatus.approved,
}) => OshiSummary(
  id: id,
  kind: OshiKind.person,
  name: name,
  genre: OshiGenre.idol,
  status: status,
  groupIds: groupIds,
);

/// 必須項目がそろった入力
TradePostDraft validDraft() => TradePostDraft(
  groupIds: ['g1'],
  tags: {TradeTag.trade},
  handover: {HandoverMethod.mail},
);

GiveItem item(String goodsId, String variantId) => GiveItem(
  goodsId: goodsId,
  variantId: variantId,
  label: '$goodsId$variantId',
);

void main() {
  group('表示名', () {
    test('品目は「グッズ名（種類名）」、「通常」だけのグッズはグッズ名のみ', () {
      expect(itemLabel(acsta, vA), 'ランダムアクスタ（メンバーA）');
      expect(itemLabel(towel, towel.variants.single), 'タオル');
    });

    test('全種類は「グッズ名（全種類）」、メンバーは名前', () {
      expect(goodsTarget(acsta).label, 'ランダムアクスタ（全種類）');
      expect(memberTarget(person('pA', 'A子')).label, 'A子');
    });
  });

  group('キーからの変換', () {
    test('譲は品目だけを作り、全種類や知らないキーは読み飛ばす', () {
      final items = giveItemsFromKeys([
        itemKey('acsta', 'v2'),
        wholeGoodsKey('acsta'),
        itemKey('acsta', 'v9'),
        itemKey('none', 'v1'),
        itemKey('towel', 'v1'),
      ], goodsById);
      expect(
        [for (final i in items) i.toMap()],
        [
          {'goodsId': 'acsta', 'variantId': 'v2', 'label': 'ランダムアクスタ（メンバーB）'},
          {'goodsId': 'towel', 'variantId': 'v1', 'label': 'タオル'},
        ],
      );
    });

    test('求は品目と全種類を選んだ順に作る', () {
      final targets = wantTargetsFromKeys([
        wholeGoodsKey('towel'),
        itemKey('acsta', 'v1'),
      ], goodsById);
      expect(
        [for (final t in targets) t.toMap()],
        [
          {'type': 'goods', 'goodsId': 'towel', 'label': 'タオル（全種類）'},
          {
            'type': 'item',
            'goodsId': 'acsta',
            'variantId': 'v1',
            'label': 'ランダムアクスタ（メンバーA）',
          },
        ],
      );
    });

    test('選択済みのキーは、シートで選び直す形で返す', () {
      final give = GiveSetDraft(items: [item('acsta', 'v1')]);
      expect(give.selectedKeys, ['item:acsta#v1']);

      final want = WantSetDraft(
        targets: [
          itemTarget(acsta, vB),
          goodsTarget(towel),
          memberTarget(person('pA', 'A子')),
        ],
      );
      expect(want.selectedKeys, ['item:acsta#v2', 'goods:towel']);
      expect(want.memberIds, ['pA']);
    });
  });

  group('選び直し', () {
    test('譲：シートに出たグッズの品目だけを置き換え、出なかったものは残す', () {
      final set = GiveSetDraft(
        items: [item('acsta', 'v1'), item('other', 'v1')],
      );
      set.replaceItems([item('acsta', 'v2')], {'acsta', 'towel'});
      expect(set.selectedKeys, ['item:other#v1', 'item:acsta#v2']);
    });

    test('求：品目・全種類を置き換えても、メンバー指定は残す', () {
      final a = person('pA', 'A子');
      final set = WantSetDraft(
        targets: [itemTarget(acsta, vA), memberTarget(a)],
      );
      set.replaceGoodsTargets([goodsTarget(towel)], {'acsta', 'towel'});
      expect(set.targets.map((t) => t.label), ['タオル（全種類）', 'A子']);
    });

    test('求：メンバーを置き換えても、品目と候補外のメンバーは残す', () {
      final a = person('pA', 'A子');
      final b = person('pB', 'B子');
      final set = WantSetDraft(
        targets: [
          memberTarget(a),
          itemTarget(acsta, vA),
          const WantTarget(type: WantType.member, oshiId: 'pX', label: 'X'),
        ],
      );
      set.replaceMembers([b], {'pA', 'pB'});
      expect(set.targets.map((t) => t.label), ['ランダムアクスタ（メンバーA）', 'X', 'B子']);
    });
  });

  group('validate（セット）', () {
    test('品目を選んだセットはエラーなし', () {
      final d = validDraft()
        ..gives.add(GiveSetDraft(items: [item('acsta', 'v1')]))
        ..wants.add(WantSetDraft(targets: [goodsTarget(towel)]));
      expect(d.validate(goodsById: goodsById), isEmpty);
    });

    test('空のセットはエラー（何番目かを示す）', () {
      final d = validDraft()
        ..gives.add(GiveSetDraft(items: [item('acsta', 'v1')]))
        ..gives.add(GiveSetDraft())
        ..wants.add(WantSetDraft());
      expect(d.validate(), [
        '譲セット2の品目を1つ以上選ぶか、セットを削除してください',
        '求セット1の品目を1つ以上選ぶか、セットを削除してください',
      ]);
    });

    test('セットは10個まで', () {
      final d = validDraft();
      for (var i = 0; i < 11; i++) {
        d.gives.add(GiveSetDraft(items: [item('acsta', 'v1')]));
      }
      expect(d.validate(), contains('譲セットは10個までです'));
    });

    test('1セットの品目は30個まで', () {
      final d = validDraft()
        ..gives.add(
          GiveSetDraft(items: [for (var i = 0; i < 31; i++) item('g$i', 'v1')]),
        );
      expect(d.validate(), contains('譲セット1の品目は30個までです'));
    });

    test('選べる数は空欄か、1〜品目数の数字', () {
      final set = GiveSetDraft(items: [item('a', 'v1'), item('b', 'v1')]);
      final d = validDraft()..gives.add(set);
      for (final ok in ['', ' ', '1', '2']) {
        set.pickCount = ok;
        expect(d.validate(), isEmpty, reason: ok);
      }
      for (final ng in ['0', '3', 'a', '1.5']) {
        set.pickCount = ng;
        expect(d.validate(), ['譲セット1の選べる数は1〜2の数字で入力してください'], reason: ng);
      }
    });

    test('求の検索用キーが100個を超えるとエラー', () {
      final d = validDraft();
      for (var s = 0; s < 4; s++) {
        d.wants.add(
          WantSetDraft(
            targets: [
              for (var i = 0; i < 26; i++)
                WantTarget(
                  type: WantType.goods,
                  goodsId: 'g${s}_$i',
                  label: 'x',
                ),
            ],
          ),
        );
      }
      expect(d.validate(), ['求の対象が多すぎます（100個まで）。対象を減らしてください']);
    });

    test('譲の検索用キーは、種類のメンバーも数えて300個まで', () {
      // 1品目で item・goods・member の3つ。10セット×30品目×3 = 900
      final many = Goods(
        id: 'many',
        name: '多い',
        category: GoodsCategory.card,
        variants: [
          for (var i = 0; i < 300; i++)
            GoodsVariant(id: 'v$i', name: '$i', oshiId: 'm$i'),
        ],
      );
      final d = validDraft();
      for (var s = 0; s < 4; s++) {
        d.gives.add(
          GiveSetDraft(
            items: [
              for (var i = 0; i < 25; i++) item('many', 'v${s * 25 + i}'),
            ],
          ),
        );
      }
      // 100品目：item 100 + goods 1 + member 100 = 201 → OK
      expect(d.validate(goodsById: {'many': many}), isEmpty);
      for (var s = 4; s < 6; s++) {
        d.gives.add(
          GiveSetDraft(
            items: [
              for (var i = 0; i < 25; i++) item('many', 'v${s * 25 + i}'),
            ],
          ),
        );
      }
      // 150品目：150 + 1 + 150 = 301 → NG
      expect(d.validate(goodsById: {'many': many}), ['譲の品目が多すぎます。品目を減らしてください']);
    });

    test('toPost は選べる数を数値に、空の備考を null にする', () {
      final d = validDraft()
        ..gives.add(
          GiveSetDraft(items: [item('a', 'v1')], pickCount: ' 1 ', note: ' '),
        )
        ..wants.add(WantSetDraft(targets: [goodsTarget(towel)], note: ' 急ぎ '));
      final p = d.toPost();
      expect(p.gives.single.pickCount, 1);
      expect(p.gives.single.note, isNull);
      expect(p.wants.single.pickCount, isNull);
      expect(p.wants.single.note, '急ぎ');
    });
  });

  group('候補と範囲', () {
    final all = [
      oshi('g1', 'グループ1'),
      person('pB', 'B子', groupIds: ['g1']),
      person('pA', 'A子', groupIds: ['g1', 'g2']),
      person('pC', 'C子', groupIds: ['g2']),
      person('pS', 'ソロ'),
      person('pP', '申請中', groupIds: ['g1'], status: OshiStatus.pending),
    ];

    test('メンバー候補は、対象グループのメンバーと対象の個人（承認済み・名前順）', () {
      final r = memberCandidates(groupIds: ['g1'], oshiIds: ['pS'], all: all);
      expect(r.map((o) => o.id), ['pA', 'pB', 'pS']);
    });

    test('グッズの範囲には、対象の個人の所属グループを含める', () {
      final scope = goodsScopeFor(
        groupIds: const [],
        oshiIds: ['pA'],
        all: all,
      );
      expect(scope.groupIds, ['g1', 'g2']);
      expect(scope.oshiIds, ['pA']);
    });

    test('GoodsScope は順序が違っても中身が同じなら等しい', () {
      final a = GoodsScope(groupIds: {'g2', 'g1'}, oshiIds: {'p1'});
      final b = GoodsScope(groupIds: {'g1', 'g2'}, oshiIds: {'p1'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == GoodsScope(groupIds: {'g1'}, oshiIds: {'p1'}), isFalse);
      expect(GoodsScope(groupIds: {}, oshiIds: {}).isEmpty, isTrue);
    });
  });
}
