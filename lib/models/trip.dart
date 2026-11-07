import 'package:cloud_firestore/cloud_firestore.dart';

import 'converters.dart';

/// 遠征の交通手段。Firestore には [code] を保存する
enum TravelTransport {
  shinkansen('shinkansen', '新幹線'),
  plane('plane', '飛行機'),
  bus('bus', '高速バス'),
  train('train', '電車'),
  car('car', '車'),
  other('other', 'その他');

  const TravelTransport(this.code, this.label);

  final String code;
  final String label;

  /// 不明な値・欠けている値なら null
  static TravelTransport? fromCode(Object? code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return null;
  }
}

/// 公演1件の遠征メモ（`users/{uid}/trips/{performanceId}`。E-2）
class Trip {
  const Trip({
    required this.performanceId,
    required this.liveId,
    required this.liveTitle,
    required this.startAt,
    required this.venue,
    this.transport,
    this.transportCost,
    this.hotelName,
    this.hotelCost,
    this.note,
    this.createdAt,
  });

  /// 金額の上限（円）
  static const int maxCost = 1000000;
  static const int maxHotelNameLength = 100;
  static const int maxNoteLength = 500;

  final String performanceId;
  final String liveId;

  /// ライブ名・開演日時・会場は複製（一覧と費用の集計に使う）
  final String liveTitle;
  final DateTime startAt;
  final String venue;

  final TravelTransport? transport;

  /// 交通費（円、往復の合計）
  final int? transportCost;
  final String? hotelName;

  /// 宿代（円）
  final int? hotelCost;
  final String? note;

  /// 作成日時（保存前は null）
  final DateTime? createdAt;

  /// 交通費と宿代の合計（どちらも無ければ 0）
  int get totalCost => (transportCost ?? 0) + (hotelCost ?? 0);

  /// 交通費か宿代のどちらかが入っているか（費用管理に出すか）
  bool get hasCost => transportCost != null || hotelCost != null;

  /// 宿の記録があるか
  bool get hasHotel =>
      (hotelName != null && hotelName!.isNotEmpty) || hotelCost != null;

  factory Trip.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    int? toInt(Object? v) => (v as num?)?.toInt();
    return Trip(
      performanceId: doc.id,
      liveId: data['liveId'] as String? ?? '',
      liveTitle: data['liveTitle'] as String? ?? '',
      startAt: toDateTime(data['startAt']) ?? DateTime(1970),
      venue: data['venue'] as String? ?? '',
      transport: TravelTransport.fromCode(data['transport']),
      transportCost: toInt(data['transportCost']),
      hotelName: data['hotelName'] as String?,
      hotelCost: toInt(data['hotelCost']),
      note: data['note'] as String?,
      createdAt: toDateTime(data['createdAt']),
    );
  }

  /// 保存用の Map。作成日時・更新日時はリポジトリが付ける
  Map<String, dynamic> toFirestore() => {
    'liveId': liveId,
    'liveTitle': liveTitle,
    'startAt': Timestamp.fromDate(startAt),
    'venue': venue,
    if (transport != null) 'transport': transport!.code,
    if (transportCost != null) 'transportCost': transportCost,
    if (hotelName != null && hotelName!.isNotEmpty) 'hotelName': hotelName,
    if (hotelCost != null) 'hotelCost': hotelCost,
    if (note != null && note!.isNotEmpty) 'note': note,
  };
}