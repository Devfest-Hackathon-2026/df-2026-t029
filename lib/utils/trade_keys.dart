import '../models/goods.dart';
import '../models/trade_post.dart';

/// 譲の検索用キー（DB 設計案 5章）。
///
/// 品目1つから、品目・グッズ・メンバー（種類にメンバーがいる場合のみ）の
/// 3種類を作る。[goodsById] は、品目のグッズを ID で引けるもの
/// （種類に紐づくメンバーを調べるため）。重複は除く。
List<String> buildGiveKeys(List<GiveSet> gives, Map<String, Goods> goodsById) {
  final keys = <String>{};
  for (final set in gives) {
    for (final item in set.items) {
      keys.addAll(giveItemKeys(item, goodsById));
    }
  }
  return keys.toList();
}

/// 譲の品目1つの検索用キー（品目・グッズ・メンバー）。
/// メンバーのキーは、[goodsById] で品目の種類にメンバーがいるときだけ作る
List<String> giveItemKeys(GiveItem item, Map<String, Goods> goodsById) {
  final oshiId = goodsById[item.goodsId]?.variants
      .where((v) => v.id == item.variantId)
      .firstOrNull
      ?.oshiId;
  return [
    'item:${item.goodsId}#${item.variantId}',
    'goods:${item.goodsId}',
    if (oshiId != null) 'member:$oshiId',
  ];
}

/// 求の検索用キー。求める対象1つから、出し方に応じたキーを1つ作る。重複は除く。
List<String> buildWantKeys(List<WantSet> wants) {
  final keys = <String>{};
  for (final set in wants) {
    for (final t in set.targets) {
      final key = wantTargetKey(t);
      if (key != null) keys.add(key);
    }
  }
  return keys.toList();
}

/// 求める対象1つの検索用キー。必要な ID が欠けていれば null
String? wantTargetKey(WantTarget t) => switch (t.type) {
  WantType.item when t.goodsId != null && t.variantId != null =>
    'item:${t.goodsId}#${t.variantId}',
  WantType.goods when t.goodsId != null => 'goods:${t.goodsId}',
  WantType.member when t.oshiId != null => 'member:${t.oshiId}',
  _ => null,
};
