// lib/utils/trade_match.dart（G-4-2）のテスト
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/goods.dart';
import 'package:oshiashi/models/trade_post.dart';
import 'package:oshiashi/utils/trade_keys.dart';
import 'package:oshiashi/utils/trade_match.dart';

const acsta = Goods(
  id: 'acsta',
  name: 'アクスタ',
  category: GoodsCategory.acrylic,
  variants: [
    GoodsVariant(id: 'vA', name: 'A', oshiId: 'mA'),
    GoodsVariant(id: 'vB', name: 'B', oshiId: 'mB'),
    GoodsVariant(id: 'vC', name: 'C', oshiId: 'mC'),
  ],
);
final goodsById = {'acsta': acsta};

GiveItem item(String v) =>
    GiveItem(goodsId: 'acsta', variantId: v, label: 'アクスタ（$v）');

WantTarget wantItem(String v) => WantTarget(
  type: WantType.item,
  goodsId: 'acsta',
  variantId: v,
  label: 'アクスタ（$v）',
);
const wantAll = WantTarget(
  type: WantType.goods,
  goodsId: 'acsta',
  label: 'アクスタ（全種類）',
);
WantTarget wantMember(String m) =>
    WantTarget(type: WantType.member, oshiId: m, label: m);

/// 譲・求から、保存時と同じ規則で検索用キーを作った投稿
TradePost post(
  String id, {
  required String uid,
  List<GiveItem> gives = const [],
  List<WantTarget> wants = const [],
  TradePostStatus status = TradePostStatus.open,
  int day = 1,
}) {
  final giveSets = gives.isEmpty ? <GiveSet>[] : [GiveSet(items: gives)];
  final wantSets = wants.isEmpty ? <WantSet>[] : [WantSet(targets: wants)];
  return TradePost(
    id: id,
    uid: uid,
    tags: const [TradeTag.trade],
    handover: const [HandoverMethod.mail],
    gives: giveSets,
    wants: wantSets,
    giveKeys: buildGiveKeys(giveSets, goodsById),
    wantKeys: buildWantKeys(wantSets),
    status: status,
    updatedAt: DateTime(2026, 11, day),
  );
}

List<String?> ids(List<TradeMatch> ms) => [for (final m in ms) m.theirs.id];

void main() {
  // 自分：A を出して C が欲しい
  final mine = post(
    'mine',
    uid: 'me',
    gives: [item('vA')],
    wants: [wantItem('vC')],
  );

  test('相手の譲が自分の求に合えば片方マッチ、相手の求も合えば相互マッチ', () {
    final oneSided = post('oneSided', uid: 'x', gives: [item('vC')], day: 3);
    final mutual = post(
      'mutual',
      uid: 'y',
      gives: [item('vC')],
      wants: [wantItem('vA')],
      day: 2,
    );
    final none = post('none', uid: 'z', gives: [item('vB')]);
    final r = matchTradePosts(
      mine: [mine],
      candidates: [oneSided, mutual, none],
      goodsById: goodsById,
    );
    // 相互マッチ → 片方マッチの順
    expect(ids(r), ['mutual', 'oneSided']);
    expect(r[0].isMutual, isTrue);
    expect(r[0].best.iGive.map((i) => i.variantId), ['vA']);
    expect(r[1].isMutual, isFalse);
    expect(r[1].best.iGive, isEmpty);
    expect(r[1].best.theyGive.map((i) => i.variantId), ['vC']);
  });

  test('幅のある求（全種類・メンバー指定）も一致し、一致した品目を出す', () {
    final wantsAll = post('wantsAll', uid: 'me', wants: [wantAll]);
    final wantsMember = post(
      'wantsMember',
      uid: 'me',
      wants: [wantMember('mB')],
    );
    final theirs = post('theirs', uid: 'x', gives: [item('vA'), item('vB')]);

    final r1 = matchTradePosts(
      mine: [wantsAll],
      candidates: [theirs],
      goodsById: goodsById,
    );
    expect(r1.single.best.theyGive.map((i) => i.variantId), ['vA', 'vB']);

    final r2 = matchTradePosts(
      mine: [wantsMember],
      candidates: [theirs],
      goodsById: goodsById,
    );
    // メンバー B の品目だけ
    expect(r2.single.best.theyGive.map((i) => i.variantId), ['vB']);
  });

  test('グッズが読めなくても、キーで判定してマッチにはする（品目の表示が減る）', () {
    final wantsMember = post(
      'wantsMember',
      uid: 'me',
      wants: [wantMember('mB')],
    );
    final theirs = post('theirs', uid: 'x', gives: [item('vB')]);
    final r = matchTradePosts(
      mine: [wantsMember],
      candidates: [theirs],
      goodsById: const {},
    );
    expect(ids(r), ['theirs']);
    expect(r.single.best.theyGive, isEmpty);
  });

  test('自分の投稿が複数合うときは1件にまとめ、相互マッチの組を先にする', () {
    final mine1 = post('mine1', uid: 'me', wants: [wantItem('vC')]);
    final mine2 = post(
      'mine2',
      uid: 'me',
      gives: [item('vA')],
      wants: [wantAll],
    );
    final theirs = post(
      'theirs',
      uid: 'x',
      gives: [item('vC')],
      wants: [wantItem('vA')],
    );
    final r = matchTradePosts(
      mine: [mine1, mine2],
      candidates: [theirs],
      goodsById: goodsById,
    );
    expect(r.single.pairs.map((p) => p.mine.id), ['mine2', 'mine1']);
    expect(r.single.isMutual, isTrue);
  });

  test('自分の募集終了の投稿・相手の募集中でない投稿・自分の投稿は除く', () {
    final closedMine = post(
      'closedMine',
      uid: 'me',
      wants: [wantItem('vB')],
      status: TradePostStatus.closed,
    );
    final theirsB = post('theirsB', uid: 'x', gives: [item('vB')]);
    final closedTheirs = post(
      'closedTheirs',
      uid: 'x',
      gives: [item('vC')],
      status: TradePostStatus.closed,
    );
    final own = post('own', uid: 'me', gives: [item('vC')]);
    final r = matchTradePosts(
      mine: [mine, closedMine],
      candidates: [theirsB, closedTheirs, own],
      goodsById: goodsById,
    );
    expect(r, isEmpty);
  });

  test('同じ種類のマッチの中では、相手の投稿の更新日時の新しい順', () {
    final r = matchTradePosts(
      mine: [mine],
      candidates: [
        post('old', uid: 'x', gives: [item('vC')], day: 1),
        post('new', uid: 'y', gives: [item('vC')], day: 5),
      ],
      goodsById: goodsById,
    );
    expect(ids(r), ['new', 'old']);
  });

  test('一致した品目は、同じ品目が複数のセットにあっても1つ', () {
    final theirs = TradePost(
      id: 'dup',
      uid: 'x',
      tags: const [TradeTag.trade],
      handover: const [HandoverMethod.mail],
      gives: [
        GiveSet(items: [item('vC')]),
        GiveSet(items: [item('vC')]),
      ],
      giveKeys: const ['item:acsta#vC', 'goods:acsta', 'member:mC'],
    );
    final r = matchTradePosts(
      mine: [mine],
      candidates: [theirs],
      goodsById: goodsById,
    );
    expect(r.single.best.theyGive, hasLength(1));
  });

  test('goodsIdsForMatching：両方の譲の品目のグッズ', () {
    final other = TradePost(
      uid: 'x',
      tags: const [TradeTag.trade],
      handover: const [HandoverMethod.mail],
      gives: const [
        GiveSet(
          items: [GiveItem(goodsId: 'towel', variantId: 'v1', label: '')],
        ),
      ],
    );
    expect(goodsIdsForMatching([mine], [other]), {'acsta', 'towel'});
  });
}
