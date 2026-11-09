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

/// 公演1件の遠征メモ（`users/{uid}/trips/{performanceId}`。E-2・add_E 3章）
class Trip {
  const Trip({
    required this.performanceId,
    required this.liveId,
    required this.liveTitle,
    required this.startAt,
    required this.venue,
    this.transport,
    this.departAt,
    this.returnAt,
    this.transportCost,
    this.hotelName,
    this.checkInAt,
    this.hotelCost,
    this.localNote,
    this.note,
    this.createdAt,
  });

  /// 金額の上限（円）
  static const int maxCost = 1000000;
  static const int maxHotelNameLength = 100;
  static const int maxNoteLength = 500;
  static const int maxLocalNoteLength = 500;

  final String performanceId;
  final String liveId;

  /// ライブ名・開演日時・会場は複製（一覧と費用の集計に使う）
  final String liveTitle;
  final DateTime startAt;
  final String venue;

  final TravelTransport? transport;

  /// 行きの出発（add_E 3章）
  final DateTime? departAt;

  /// 帰りの出発（終電など。add_E 3章）
  final DateTime? returnAt;

  /// 交通費（円、往復の合計）
  final int? transportCost;
  final String? hotelName;

  /// 宿のチェックイン（add_E 3章）
  final DateTime? checkInAt;

  /// 宿代（円）
  final int? hotelCost;

  /// 現地メモ（コインロッカー・食事・グッズ列など。add_E 3章）
  final String? localNote;
  final String? note;

  /// 作成日時（保存前は null）
  final DateTime? createdAt;

  /// 交通費と宿代の合計（どちらも無ければ 0）
  int get totalCost => (transportCost ?? 0) + (hotelCost ?? 0);

  /// 交通費か宿代のどちらかが入っているか（費用管理に出すか）
  bool get hasCost => transportCost != null || hotelCost != null;

  /// 宿の記録があるか
  bool get hasHotel =>
      (hotelName != null && hotelName!.isNotEmpty) ||
      hotelCost != null ||
      checkInAt != null;

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
      departAt: toDateTime(data['departAt']),
      returnAt: toDateTime(data['returnAt']),
      transportCost: toInt(data['transportCost']),
      hotelName: data['hotelName'] as String?,
      checkInAt: toDateTime(data['checkInAt']),
      hotelCost: toInt(data['hotelCost']),
      localNote: data['localNote'] as String?,
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
    if (departAt != null) 'departAt': Timestamp.fromDate(departAt!),
    if (returnAt != null) 'returnAt': Timestamp.fromDate(returnAt!),
    if (transportCost != null) 'transportCost': transportCost,
    if (hotelName != null && hotelName!.isNotEmpty) 'hotelName': hotelName,
    if (checkInAt != null) 'checkInAt': Timestamp.fromDate(checkInAt!),
    if (hotelCost != null) 'hotelCost': hotelCost,
    if (localNote != null && localNote!.isNotEmpty) 'localNote': localNote,
    if (note != null && note!.isNotEmpty) 'note': note,
  };
}
