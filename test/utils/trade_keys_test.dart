// lib/utils/trade_keys.dart（G-2-2。G-4-2 で品目・対象ごとの関数に分けた）のテスト
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/goods.dart';
import 'package:oshiashi/models/trade_post.dart';
import 'package:oshiashi/utils/trade_keys.dart';

const acsta = Goods(
  id: 'acsta',
  name: 'アクスタ',
  category: GoodsCategory.acrylic,
  variants: [
    GoodsVariant(id: 'v1', name: 'A', oshiId: 'mA'),
    GoodsVariant(id: 'v2', name: 'B'),
  ],
);

GiveItem item(String goodsId, String variantId) =>
    GiveItem(goodsId: goodsId, variantId: variantId, label: '');

void main() {
  group('giveItemKeys', () {
    test('品目・グッズ・メンバー（種類にメンバーがいるとき）の3つ', () {
      expect(giveItemKeys(item('acsta', 'v1'), {'acsta': acsta}), [
        'item:acsta#v1',
        'goods:acsta',
        'member:mA',
      ]);
    });

    test('種類にメンバーがいない・グッズが読めないときはメンバーなし', () {
      expect(giveItemKeys(item('acsta', 'v2'), {'acsta': acsta}), [
        'item:acsta#v2',
        'goods:acsta',
      ]);
      expect(giveItemKeys(item('acsta', 'v1'), const {}), [
        'item:acsta#v1',
        'goods:acsta',
      ]);
    });
  });

  test('buildGiveKeys：セットをまたいで重複を除く', () {
    final keys = buildGiveKeys(
      [
        GiveSet(items: [item('acsta', 'v1'), item('acsta', 'v2')]),
        GiveSet(items: [item('acsta', 'v1')]),
      ],
      {'acsta': acsta},
    );
    expect(keys, [
      'item:acsta#v1',
      'goods:acsta',
      'member:mA',
      'item:acsta#v2',
    ]);
  });

  group('wantTargetKey / buildWantKeys', () {
    test('出し方に応じたキーを1つ作る', () {
      expect(
        wantTargetKey(
          const WantTarget(
            type: WantType.item,
            goodsId: 'g',
            variantId: 'v1',
            label: '',
          ),
        ),
        'item:g#v1',
      );
      expect(
        wantTargetKey(
          const WantTarget(type: WantType.goods, goodsId: 'g', label: ''),
        ),
        'goods:g',
      );
      expect(
        wantTargetKey(
          const WantTarget(type: WantType.member, oshiId: 'm', label: ''),
        ),
        'member:m',
      );
    });

    test('必要な ID が欠けていれば null で、buildWantKeys では読み飛ばす', () {
      const broken = WantTarget(type: WantType.item, goodsId: 'g', label: '');
      expect(wantTargetKey(broken), isNull);
      expect(
        buildWantKeys([
          const WantSet(
            targets: [
              broken,
              WantTarget(type: WantType.goods, goodsId: 'g', label: ''),
              WantTarget(type: WantType.goods, goodsId: 'g', label: ''),
            ],
          ),
        ]),
        ['goods:g'],
      );
    });
  });
}
