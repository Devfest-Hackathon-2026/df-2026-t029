import 'package:cloud_firestore/cloud_firestore.dart';

import 'converters.dart';

/// 受付種別（database.md 4章）
enum ReceptionType { fc, general, upgrade, other }

/// 席種と料金
class Price {
  const Price({required this.seat, required this.amount});

  final String seat;
  final int amount; // 円

  factory Price.fromMap(Map<String, dynamic> map) => Price(
        seat: map['seat'] as String,
        amount: (map['amount'] as num).toInt(),
      );

  Map<String, dynamic> toMap() => {'seat': seat, 'amount': amount};
}

class Reception {
  const Reception({
    this.id,
    this.liveId,
    this.groupIds = const [],
    this.oshiIds = const [],
    required this.type,
    required this.name,
    this.applyStartAt,
    required this.applyEndAt,
    this.resultAt,
    this.paymentDeadline,
    this.prices = const [],
    this.winnersOnly = false,
  });

  final String? id; // 保存前は null
  final String? liveId; // 保存時に repository が付ける
  final List<String> groupIds; // 同上（ライブからの複製）
  final List<String> oshiIds; // 同上（ライブからの複製）
  final ReceptionType type;
  final String name;
  final DateTime? applyStartAt;
  final DateTime applyEndAt;
  final DateTime? resultAt;
  final DateTime? paymentDeadline;
  final List<Price> prices;
  final bool winnersOnly;

  factory Reception.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Reception(
      id: doc.id,
      liveId: data['liveId'] as String?,
      groupIds: toStringList(data['groupIds']),
      oshiIds: toStringList(data['oshiIds']),
      type: ReceptionType.values.asNameMap()[data['type']] ??
          ReceptionType.other,
      name: data['name'] as String,
      applyStartAt: toDateTime(data['applyStartAt']),
      applyEndAt: toDateTime(data['applyEndAt'])!,
      resultAt: toDateTime(data['resultAt']),
      paymentDeadline: toDateTime(data['paymentDeadline']),
      prices: [
        for (final p in data['prices'] as List? ?? const [])
          Price.fromMap(Map<String, dynamic>.from(p as Map)),
      ],
      winnersOnly: data['winnersOnly'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type.name,
        'name': name,
        if (applyStartAt != null)
          'applyStartAt': Timestamp.fromDate(applyStartAt!),
        'applyEndAt': Timestamp.fromDate(applyEndAt),
        if (resultAt != null) 'resultAt': Timestamp.fromDate(resultAt!),
        if (paymentDeadline != null)
          'paymentDeadline': Timestamp.fromDate(paymentDeadline!),
        'prices': [for (final p in prices) p.toMap()],
        'winnersOnly': winnersOnly,
      };
}