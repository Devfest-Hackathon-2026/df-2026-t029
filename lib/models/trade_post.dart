import 'package:cloud_firestore/cloud_firestore.dart';

import 'converters.dart';

/// 取引のタグ（database.md 4章）。複数選べる
enum TradeTag {
  trade('交換希望'),
  sell('譲渡（売ります）'),
  buy('買取希望');

  const TradeTag(this.label);

  final String label;
}

/// 価格の区分（譲渡・買取希望のときだけ使う）
enum PriceType {
  face('定価'),
  below('定価以下');

  const PriceType(this.label);

  final String label;
}

/// 受け渡し方法
enum HandoverMethod {
  mail('郵送'),
  hand('手渡し');

  const HandoverMethod(this.label);

  final String label;
}

/// 投稿の状態
enum TradePostStatus {
  open('募集中'),
  closed('募集終了'),
  hidden('非表示');

  const TradePostStatus(this.label);

  final String label;
}

/// 求の出し方
enum WantType {
  item('品目を指定'),
  goods('グッズの全種類'),
  member('メンバー指定');

  const WantType(this.label);

  final String label;
}

/// 文字列の配列を enum の配列にする（知らない値は読み飛ばす）
List<T> _enumList<T extends Enum>(List<T> values, Object? raw) {
  final byName = values.asNameMap();
  return [for (final s in toStringList(raw)) ?byName[s]];
}

/// 譲の品目（グッズ＋種類）
class GiveItem {
  const GiveItem({
    required this.goodsId,
    required this.variantId,
    required this.label,
  });

  final String goodsId;
  final String variantId;

  /// 表示名（例：ランダムアクスタ（メンバーA））
  final String label;

  factory GiveItem.fromMap(Map<String, dynamic> map) => GiveItem(
    goodsId: map['goodsId'] as String,
    variantId: map['variantId'] as String,
    label: map['label'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'goodsId': goodsId,
    'variantId': variantId,
    'label': label,
  };
}

/// 譲セット（「この中から N 個」）
class GiveSet {
  const GiveSet({
    this.items = const [],
    this.pickCount,
    this.images = const [],
    this.note,
  });

  final List<GiveItem> items;

  /// 選べる数。null なら指定なし
  final int? pickCount;

  /// セットの写真（Storage のパス）。G-7 で対応するまでは空
  final List<String> images;
  final String? note;

  factory GiveSet.fromMap(Map<String, dynamic> map) => GiveSet(
    items: [
      for (final m in map['items'] as List? ?? const [])
        GiveItem.fromMap(Map<String, dynamic>.from(m as Map)),
    ],
    pickCount: (map['pickCount'] as num?)?.toInt(),
    images: toStringList(map['images']),
    note: map['note'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'items': [for (final i in items) i.toMap()],
    if (pickCount != null) 'pickCount': pickCount,
    'images': images,
    if (note != null) 'note': note,
  };
}

/// 求める対象（品目／グッズの全種類／メンバー）
class WantTarget {
  const WantTarget({
    required this.type,
    this.goodsId,
    this.variantId,
    this.oshiId,
    required this.label,
  });

  final WantType type;

  /// type が item・goods のとき
  final String? goodsId;

  /// type が item のとき
  final String? variantId;

  /// type が member のとき
  final String? oshiId;

  /// 表示名（例：メンバーC）
  final String label;

  /// 知らない出し方なら null（読み飛ばす）
  static WantTarget? fromMap(Map<String, dynamic> map) {
    final type = WantType.values.asNameMap()[map['type']];
    if (type == null) return null;
    return WantTarget(
      type: type,
      goodsId: map['goodsId'] as String?,
      variantId: map['variantId'] as String?,
      oshiId: map['oshiId'] as String?,
      label: map['label'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type.name,
    if (goodsId != null) 'goodsId': goodsId,
    if (variantId != null) 'variantId': variantId,
    if (oshiId != null) 'oshiId': oshiId,
    'label': label,
  };
}

/// 求セット
class WantSet {
  const WantSet({this.targets = const [], this.pickCount, this.note});

  final List<WantTarget> targets;

  /// 選べる数。null なら指定なし
  final int? pickCount;
  final String? note;

  factory WantSet.fromMap(Map<String, dynamic> map) => WantSet(
    targets: [
      for (final m in map['targets'] as List? ?? const [])
        ?WantTarget.fromMap(Map<String, dynamic>.from(m as Map)),
    ],
    pickCount: (map['pickCount'] as num?)?.toInt(),
    note: map['note'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'targets': [for (final t in targets) t.toMap()],
    if (pickCount != null) 'pickCount': pickCount,
    if (note != null) 'note': note,
  };
}

/// 交換・売買の投稿
class TradePost {
  const TradePost({
    this.id,
    this.uid = '',
    this.displayName = '',
    this.groupIds = const [],
    this.oshiIds = const [],
    required this.tags,
    this.priceType,
    this.gives = const [],
    this.wants = const [],
    this.giveKeys = const [],
    this.wantKeys = const [],
    required this.handover,
    this.performanceIds = const [],
    this.xAccount,
    this.note,
    this.images = const [],
    this.status = TradePostStatus.open,
    this.createdAt,
    this.updatedAt,
  });

  /// 写真の上限（投稿全体とセットの合計）
  static const int maxImages = 8;

  final String? id; // 保存前は null
  final String uid; // 保存時に repository が付ける
  final String displayName; // 同上
  final List<String> groupIds;
  final List<String> oshiIds;
  final List<TradeTag> tags;

  /// 譲渡・買取希望のときだけ使う
  final PriceType? priceType;
  final List<GiveSet> gives;
  final List<WantSet> wants;
  final List<String> giveKeys; // 保存時に repository が作る
  final List<String> wantKeys; // 同上
  final List<HandoverMethod> handover;

  /// 手渡しの公演の ID
  final List<String> performanceIds;

  /// `@` なしの X アカウント名
  final String? xAccount;
  final String? note;

  /// 投稿全体の写真（Storage のパス）。G-7 で対応するまでは空
  final List<String> images;
  final TradePostStatus status; // 保存時に repository が付ける
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 価格の区分を使うか（譲渡・買取希望のタグがあるとき）
  bool get hasPrice =>
      tags.contains(TradeTag.sell) || tags.contains(TradeTag.buy);

  /// 文章だけの投稿か（自動のマッチングの対象外）
  bool get isTextOnly => gives.isEmpty && wants.isEmpty;

  /// 写真の枚数（投稿全体とセットの合計）
  int get imageCount =>
      images.length + gives.fold<int>(0, (n, s) => n + s.images.length);

  factory TradePost.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TradePost(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      groupIds: toStringList(data['groupIds']),
      oshiIds: toStringList(data['oshiIds']),
      tags: _enumList(TradeTag.values, data['tags']),
      priceType: PriceType.values.asNameMap()[data['priceType']],
      gives: [
        for (final m in data['gives'] as List? ?? const [])
          GiveSet.fromMap(Map<String, dynamic>.from(m as Map)),
      ],
      wants: [
        for (final m in data['wants'] as List? ?? const [])
          WantSet.fromMap(Map<String, dynamic>.from(m as Map)),
      ],
      giveKeys: toStringList(data['giveKeys']),
      wantKeys: toStringList(data['wantKeys']),
      handover: _enumList(HandoverMethod.values, data['handover']),
      performanceIds: toStringList(data['performanceIds']),
      xAccount: data['xAccount'] as String?,
      note: data['note'] as String?,
      images: toStringList(data['images']),
      // 知らない値は、募集中として扱わない
      status:
          TradePostStatus.values.asNameMap()[data['status']] ??
          TradePostStatus.closed,
      createdAt: toDateTime(data['createdAt']),
      updatedAt: toDateTime(data['updatedAt']),
    );
  }

  /// 保存用の Map。uid・表示名・検索用キー・状態・日時は repository が付ける
  Map<String, dynamic> toFirestore() => {
    'groupIds': groupIds,
    'oshiIds': oshiIds,
    'tags': [for (final t in tags) t.name],
    if (hasPrice && priceType != null) 'priceType': priceType!.name,
    'gives': [for (final s in gives) s.toMap()],
    'wants': [for (final s in wants) s.toMap()],
    'handover': [for (final h in handover) h.name],
    'performanceIds': performanceIds,
    if (xAccount != null) 'xAccount': xAccount,
    if (note != null) 'note': note,
    'images': images,
  };
}
