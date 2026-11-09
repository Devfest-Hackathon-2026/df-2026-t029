import 'package:cloud_firestore/cloud_firestore.dart';

import 'converters.dart';

/// グッズの種別（database.md 4章）
enum GoodsCategory { card, acrylic, badge, photo, other }

extension GoodsCategoryLabel on GoodsCategory {
  String get label => switch (this) {
    GoodsCategory.card => 'トレカ',
    GoodsCategory.acrylic => 'アクスタ・アクキー',
    GoodsCategory.badge => '缶バッジ',
    GoodsCategory.photo => '生写真・ブロマイド',
    GoodsCategory.other => 'その他',
  };
}

/// グッズの種類（例：メンバーA、絵柄1）
class GoodsVariant {
  const GoodsVariant({required this.id, required this.name, this.oshiId});

  final String id; // グッズ内で一意（v1, v2…）
  final String name;
  final String? oshiId; // 紐づくメンバー（任意）

  factory GoodsVariant.fromMap(Map<String, dynamic> map) => GoodsVariant(
    id: map['id'] as String,
    name: map['name'] as String,
    oshiId: map['oshiId'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    if (oshiId != null) 'oshiId': oshiId,
  };
}

class Goods {
  const Goods({
    this.id,
    required this.name,
    this.aliases = const [],
    required this.category,
    this.groupIds = const [],
    this.oshiIds = const [],
    this.liveId,
    this.price,
    this.officialUrl,
    this.variants = const [],
  });

  final String? id; // 保存前は null
  final String name;
  final List<String> aliases;
  final GoodsCategory category;
  final List<String> groupIds;
  final List<String> oshiIds;
  final String? liveId; // ツアーグッズの場合
  final int? price; // 定価（円）
  final String? officialUrl;
  final List<GoodsVariant> variants;

  /// 次に追加する種類の ID（既存の最大の番号＋1）
  String get nextVariantId {
    var max = 0;
    for (final v in variants) {
      final n = int.tryParse(v.id.replaceFirst('v', '')) ?? 0;
      if (n > max) max = n;
    }
    return 'v${max + 1}';
  }

  factory Goods.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Goods(
      id: doc.id,
      name: data['name'] as String,
      aliases: toStringList(data['aliases']),
      category:
          GoodsCategory.values.asNameMap()[data['category']] ??
          GoodsCategory.other,
      groupIds: toStringList(data['groupIds']),
      oshiIds: toStringList(data['oshiIds']),
      liveId: data['liveId'] as String?,
      price: (data['price'] as num?)?.toInt(),
      officialUrl: data['officialUrl'] as String?,
      variants: [
        for (final v in data['variants'] as List? ?? const [])
          GoodsVariant.fromMap(Map<String, dynamic>.from(v as Map)),
      ],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    if (aliases.isNotEmpty) 'aliases': aliases,
    'category': category.name,
    'groupIds': groupIds,
    'oshiIds': oshiIds,
    if (liveId != null) 'liveId': liveId,
    if (price != null) 'price': price,
    if (officialUrl != null) 'officialUrl': officialUrl,
    'variants': [for (final v in variants) v.toMap()],
  };
}
