import '../../models/goods.dart';
import '../../models/oshi.dart';
import '../../models/performance.dart';
import '../../models/trade_post.dart';
import '../../providers/goods_providers.dart';
import '../../utils/oshi_search.dart';
import '../../utils/trade_keys.dart';
import '../goods/goods_draft.dart';
import '../common/photo_items.dart';

/// 入力中の譲セット
class GiveSetDraft {
  GiveSetDraft({
    List<GiveItem>? items,
    this.pickCount = '',
    this.note = '',
    List<PhotoItem>? photos,
  }) : items = items ?? [],
       photos = photos ?? [];

  factory GiveSetDraft.fromSet(GiveSet s) => GiveSetDraft(
    items: [...s.items],
    pickCount: s.pickCount?.toString() ?? '',
    note: s.note ?? '',
    photos: savedPhotoItems(s.images),
  );

  final List<GiveItem> items;

  /// 品目を選ぶシートに渡す、選択済みのキー
  List<String> get selectedKeys => [
    for (final i in items) itemKey(i.goodsId, i.variantId),
  ];

  /// シートで選び直した品目に置き換える。
  /// [loadedGoodsIds] にないグッズの品目（シートに出なかったもの）は残す
  void replaceItems(List<GiveItem> picked, Set<String> loadedGoodsIds) {
    // clear の前にリストにする（where は遅延評価のため）
    final kept = items
        .where((i) => !loadedGoodsIds.contains(i.goodsId))
        .toList();
    items
      ..clear()
      ..addAll([...kept, ...picked]);
  }

  /// 選べる数（入力のまま。空なら指定なし）
  String pickCount;
  String note;

  /// セットの写真（G-7）
  final List<PhotoItem> photos;

  /// 保存用のセットにする。写真は [uploaded]（新しい写真 → パス）で
  /// パスにする。[uploaded] が null なら写真は空（入力の検査用）
  GiveSet toSet({Map<NewPhoto, String>? uploaded}) => GiveSet(
    items: [...items],
    pickCount: _parsePickCount(pickCount),
    images: uploaded == null ? const [] : photoPathsOf(photos, uploaded),
    note: _trimOrNull(note),
  );
}

/// 入力中の求セット
class WantSetDraft {
  WantSetDraft({List<WantTarget>? targets, this.pickCount = '', this.note = ''})
    : targets = targets ?? [];

  factory WantSetDraft.fromSet(WantSet s) => WantSetDraft(
    targets: [...s.targets],
    pickCount: s.pickCount?.toString() ?? '',
    note: s.note ?? '',
  );

  final List<WantTarget> targets;
  String pickCount;
  String note;

  /// 品目を選ぶシートに渡す、選択済みのキー（メンバー指定は含めない）
  List<String> get selectedKeys => [
    for (final t in targets)
      if (t.type == WantType.item && t.goodsId != null && t.variantId != null)
        itemKey(t.goodsId!, t.variantId!)
      else if (t.type == WantType.goods && t.goodsId != null)
        wholeGoodsKey(t.goodsId!),
  ];

  /// メンバー指定の対象の推しの ID
  List<String> get memberIds => [
    for (final t in targets)
      if (t.type == WantType.member && t.oshiId != null) t.oshiId!,
  ];

  /// 品目・グッズの全種類の対象を、シートで選び直したものに置き換える。
  /// メンバー指定と、[loadedGoodsIds] にないグッズの対象は残す
  void replaceGoodsTargets(
    List<WantTarget> picked,
    Set<String> loadedGoodsIds,
  ) {
    final kept = targets.where(
      (t) => t.type != WantType.member && !loadedGoodsIds.contains(t.goodsId),
    );
    final members = targets.where((t) => t.type == WantType.member);
    targets.replaceRange(0, targets.length, [...kept, ...picked, ...members]);
  }

  /// メンバー指定の対象を、シートで選び直したものに置き換える。
  /// 品目・全種類と、[candidateIds] にないメンバー（候補に出なかったもの）は残す
  void replaceMembers(List<OshiSummary> picked, Set<String> candidateIds) {
    final others = targets.where(
      (t) => t.type != WantType.member || !candidateIds.contains(t.oshiId),
    );
    targets.replaceRange(0, targets.length, [
      ...others,
      for (final m in picked) memberTarget(m),
    ]);
  }

  WantSet toSet() => WantSet(
    targets: [...targets],
    pickCount: _parsePickCount(pickCount),
    note: _trimOrNull(note),
  );
}

int? _parsePickCount(String s) => int.tryParse(s.trim());

String? _trimOrNull(String s) {
  final t = s.trim();
  return t.isEmpty ? null : t;
}

/// 譲の品目・求の「品目を指定」の表示名。
/// 種類が「通常」1つだけのグッズはグッズ名のみ、それ以外は「グッズ名（種類名）」
String itemLabel(Goods g, GoodsVariant v) =>
    g.variants.length == 1 && v.name == GoodsDraft.defaultVariantName
    ? g.name
    : '${g.name}（${v.name}）';

GiveItem giveItemOf(Goods g, GoodsVariant v) =>
    GiveItem(goodsId: g.id!, variantId: v.id, label: itemLabel(g, v));

/// 求の「品目を指定」
WantTarget itemTarget(Goods g, GoodsVariant v) => WantTarget(
  type: WantType.item,
  goodsId: g.id,
  variantId: v.id,
  label: itemLabel(g, v),
);

/// 求の「グッズの全種類」
WantTarget goodsTarget(Goods g) =>
    WantTarget(type: WantType.goods, goodsId: g.id, label: '${g.name}（全種類）');

/// 品目を選ぶシートでの、品目のキー（検索用キーと同じ形）
String itemKey(String goodsId, String variantId) => 'item:$goodsId#$variantId';

/// 品目を選ぶシートでの、グッズの全種類のキー（検索用キーと同じ形）
String wholeGoodsKey(String goodsId) => 'goods:$goodsId';

/// シートで選んだキーから、品目かグッズの全種類を作る。
/// [goodsById] にないグッズ・種類のキーは読み飛ばす
List<T> _fromKeys<T>(
  List<String> keys,
  Map<String, Goods> goodsById, {
  required T Function(Goods, GoodsVariant) item,
  T Function(Goods)? whole,
}) {
  final result = <T>[];
  for (final k in keys) {
    if (k.startsWith('item:')) {
      final [goodsId, variantId] = k.substring(5).split('#');
      final g = goodsById[goodsId];
      final v = g?.variants.where((v) => v.id == variantId).firstOrNull;
      if (g != null && v != null) result.add(item(g, v));
    } else if (k.startsWith('goods:') && whole != null) {
      final g = goodsById[k.substring(6)];
      if (g != null) result.add(whole(g));
    }
  }
  return result;
}

/// 譲の品目を、シートで選んだキーから作る
List<GiveItem> giveItemsFromKeys(
  List<String> keys,
  Map<String, Goods> goodsById,
) => _fromKeys(keys, goodsById, item: giveItemOf);

/// 求の対象（品目・グッズの全種類）を、シートで選んだキーから作る
List<WantTarget> wantTargetsFromKeys(
  List<String> keys,
  Map<String, Goods> goodsById,
) => _fromKeys(keys, goodsById, item: itemTarget, whole: goodsTarget);

/// 求の「メンバー指定」
WantTarget memberTarget(OshiSummary m) =>
    WantTarget(type: WantType.member, oshiId: m.id, label: m.name);

/// 作成・編集画面で入力中の投稿
class TradePostDraft {
  TradePostDraft({
    List<String>? groupIds,
    List<String>? oshiIds,
    Set<TradeTag>? tags,
    this.priceType,
    Set<HandoverMethod>? handover,
    List<String>? performanceIds,
    this.xAccount = '',
    this.note = '',
    List<GiveSetDraft>? gives,
    List<WantSetDraft>? wants,
    List<PhotoItem>? photos,
  }) : gives = gives ?? [],
       wants = wants ?? [],
       groupIds = groupIds ?? [],
       oshiIds = oshiIds ?? [],
       tags = tags ?? {},
       handover = handover ?? {},
       performanceIds = performanceIds ?? [],
       photos = photos ?? [];

  /// 保存済みの投稿から、編集用に作る
  factory TradePostDraft.fromPost(TradePost p) => TradePostDraft(
    groupIds: [...p.groupIds],
    oshiIds: [...p.oshiIds],
    tags: {...p.tags},
    priceType: p.priceType,
    handover: {...p.handover},
    performanceIds: [...p.performanceIds],
    xAccount: p.xAccount ?? '',
    note: p.note ?? '',
    gives: [for (final s in p.gives) GiveSetDraft.fromSet(s)],
    wants: [for (final s in p.wants) WantSetDraft.fromSet(s)],
    photos: savedPhotoItems(p.images),
  );

  // 上限はセキュリティルールと同じ
  static const int maxTargets = 20; // groupIds・oshiIds のそれぞれ
  static const int maxPerformances = 20;
  static const int maxNoteLength = 1000;
  static const int maxSets = 10; // 譲セット・求セットのそれぞれ
  static const int maxGiveKeys = 300;
  static const int maxWantKeys = 100;

  /// 1セットの品目・対象の上限（ルールにはなく、アプリ側で決めた値）
  static const int maxItemsPerSet = 30;

  final List<String> groupIds;
  final List<String> oshiIds;
  final Set<TradeTag> tags;
  PriceType? priceType;
  final Set<HandoverMethod> handover;

  /// 手渡しの公演の ID（選んだ順）
  final List<String> performanceIds;

  /// 入力のまま（先頭の @ や前後の空白は [cleanedXAccount] で除く）
  String xAccount;
  String note;
  final List<GiveSetDraft> gives;
  final List<WantSetDraft> wants;

  /// 投稿全体の写真（G-7）
  final List<PhotoItem> photos;

  /// 写真の枚数（投稿全体とセットの合計。上限は [TradePost.maxImages]）
  int get photoCount =>
      photos.length + gives.fold<int>(0, (n, s) => n + s.photos.length);

  /// 投稿全体とすべてのセットの写真（アップロード用）
  List<PhotoItem> get allPhotos => [
    ...photos,
    for (final s in gives) ...s.photos,
  ];

  bool get hasPrice =>
      tags.contains(TradeTag.sell) || tags.contains(TradeTag.buy);
  bool get isHand => handover.contains(HandoverMethod.hand);

  /// 推しを選んでいるか
  bool isTarget(OshiSummary o) => switch (o.kind) {
    OshiKind.group => groupIds.contains(o.id),
    OshiKind.person => oshiIds.contains(o.id),
  };

  /// 推しの選択を切り替える。上限を超えるときは何もせず false を返す
  bool toggleTarget(OshiSummary o) {
    final list = o.kind == OshiKind.group ? groupIds : oshiIds;
    if (list.remove(o.id)) return true;
    if (list.length >= maxTargets) return false;
    list.add(o.id);
    return true;
  }

  /// 公演の選択を切り替える。上限を超えるときは何もせず false を返す
  bool togglePerformance(String id) {
    if (performanceIds.remove(id)) return true;
    if (performanceIds.length >= maxPerformances) return false;
    performanceIds.add(id);
    return true;
  }

  String? get cleanedXAccount {
    final x = xAccount.trim().replaceFirst(RegExp('^[@＠]'), '');
    return x.isEmpty ? null : x;
  }

  String? get cleanedNote {
    final n = note.trim();
    return n.isEmpty ? null : n;
  }

  /// 入力を検査し、エラー文の一覧を返す（空なら保存できる）。
  ///
  /// [goodsById] は譲の品目のグッズ（検索用キーの数を数えるため。
  /// 種類に紐づくメンバーのキーを数えるのに使う）
  List<String> validate({Map<String, Goods> goodsById = const {}}) {
    final errors = <String>[];
    if (groupIds.isEmpty && oshiIds.isEmpty) {
      errors.add('対象の推しを1つ以上選んでください');
    }
    if (tags.isEmpty) {
      errors.add('取引のタグを1つ以上選んでください');
    }
    if (hasPrice && priceType == null) {
      errors.add('譲渡・買取希望の価格（定価／定価以下）を選んでください');
    }
    if (handover.isEmpty) {
      errors.add('受け渡し方法を1つ以上選んでください');
    }
    final x = cleanedXAccount;
    if (x != null && !RegExp(r'^[A-Za-z0-9_]{1,15}$').hasMatch(x)) {
      errors.add('X アカウントは英数字と _ の15文字以内で入力してください（@ は不要）');
    }
    if ((cleanedNote?.length ?? 0) > maxNoteLength) {
      errors.add('備考は$maxNoteLength文字以内で入力してください');
    }
    if (photoCount > TradePost.maxImages) {
      errors.add('写真は投稿全体とセットの合計で${TradePost.maxImages}枚までです');
    }
    _validateSets(
      errors,
      name: '譲セット',
      counts: [for (final s in gives) s.items.length],
      pickCounts: [for (final s in gives) s.pickCount],
      notes: [for (final s in gives) s.note],
    );
    _validateSets(
      errors,
      name: '求セット',
      counts: [for (final s in wants) s.targets.length],
      pickCounts: [for (final s in wants) s.pickCount],
      notes: [for (final s in wants) s.note],
    );
    final post = toPost();
    if (buildGiveKeys(post.gives, goodsById).length > maxGiveKeys) {
      errors.add('譲の品目が多すぎます。品目を減らしてください');
    }
    if (buildWantKeys(post.wants).length > maxWantKeys) {
      errors.add('求の対象が多すぎます（$maxWantKeys個まで）。対象を減らしてください');
    }
    return errors;
  }

  void _validateSets(
    List<String> errors, {
    required String name,
    required List<int> counts,
    required List<String> pickCounts,
    required List<String> notes,
  }) {
    if (counts.length > maxSets) {
      errors.add('$nameは$maxSets個までです');
    }
    for (var i = 0; i < counts.length; i++) {
      final label = '$name${i + 1}';
      final n = counts[i];
      if (n == 0) {
        errors.add('$labelの品目を1つ以上選ぶか、セットを削除してください');
      } else if (n > maxItemsPerSet) {
        errors.add('$labelの品目は$maxItemsPerSet個までです');
      }
      final pick = pickCounts[i].trim();
      if (pick.isNotEmpty && n > 0) {
        final v = int.tryParse(pick);
        if (v == null || v < 1 || v > n) {
          errors.add('$labelの選べる数は1〜$nの数字で入力してください');
        }
      }
      if (notes[i].trim().length > maxNoteLength) {
        errors.add('$labelの備考は$maxNoteLength文字以内で入力してください');
      }
    }
  }

  /// 保存用のモデルに変換する（[validate] の結果が空のときだけ呼ぶ）。
  ///
  /// 編集のときは [base] を渡す（ID を引き継ぐ）。写真は [uploaded]
  /// （新しい写真 → パス）でパスにする。[uploaded] が null なら写真は空
  /// （[validate] の中で使う）。
  /// 価格の区分は譲渡・買取希望のときだけ、公演は手渡しのときだけ残す
  TradePost toPost({TradePost? base, Map<NewPhoto, String>? uploaded}) =>
      TradePost(
        id: base?.id,
        groupIds: [...groupIds],
        oshiIds: [...oshiIds],
        // 表示の順をそろえる
        tags: [
          for (final t in TradeTag.values)
            if (tags.contains(t)) t,
        ],
        priceType: hasPrice ? priceType : null,
        gives: [for (final s in gives) s.toSet(uploaded: uploaded)],
        wants: [for (final s in wants) s.toSet()],
        handover: [
          for (final h in HandoverMethod.values)
            if (handover.contains(h)) h,
        ],
        performanceIds: isHand ? [...performanceIds] : const [],
        xAccount: cleanedXAccount,
        note: cleanedNote,
        images: uploaded == null ? const [] : photoPathsOf(photos, uploaded),
      );
}

/// 手渡しの公演の候補（開演の早い順）。
///
/// 対象の推しの、開演が [now] 以降の公演。個人なら本人名義の公演と、
/// 所属グループの公演を含む。[selectedIds] にある公演は、過去でも残す
/// （編集時に、選んでいた公演が黙って消えないようにする）。
List<Performance> handoverPerformanceCandidates({
  required List<Performance> performances,
  required List<String> groupIds,
  required List<String> oshiIds,
  required List<OshiSummary> all,
  required DateTime now,
  List<String> selectedIds = const [],
}) {
  final groups = {
    ...groupIds,
    for (final o in all)
      if (o.kind == OshiKind.person && oshiIds.contains(o.id)) ...o.groupIds,
  };
  final result = [
    for (final p in performances)
      if (p.id != null &&
          (selectedIds.contains(p.id) ||
              (!p.startAt.isBefore(now) &&
                  (p.groupIds.any(groups.contains) ||
                      p.oshiIds.any(oshiIds.contains)))))
        p,
  ]..sort((a, b) => a.startAt.compareTo(b.startAt));
  return result;
}

/// 求の「メンバー指定」の候補（承認済みの個人を名前順）。
///
/// 対象のグループのメンバーと、対象の個人本人
List<OshiSummary> memberCandidates({
  required List<String> groupIds,
  required List<String> oshiIds,
  required List<OshiSummary> all,
}) {
  final persons = all.where(
    (o) =>
        o.kind == OshiKind.person &&
        (oshiIds.contains(o.id) || o.groupIds.any(groupIds.contains)),
  );
  return searchOshis(persons.toList(), ''); // 承認済みだけを名前順に
}

/// 品目を選ぶシートで読むグッズの範囲。
///
/// 対象のグループと、対象の個人の所属グループのグッズ、
/// 対象の個人の名義のグッズ（グッズの検索画面と同じ考え方）
GoodsScope goodsScopeFor({
  required List<String> groupIds,
  required List<String> oshiIds,
  required List<OshiSummary> all,
}) => GoodsScope(
  groupIds: {
    ...groupIds,
    for (final o in all)
      if (o.kind == OshiKind.person && oshiIds.contains(o.id)) ...o.groupIds,
  },
  oshiIds: {...oshiIds},
);
