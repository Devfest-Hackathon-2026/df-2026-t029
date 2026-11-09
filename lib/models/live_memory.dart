import 'package:cloud_firestore/cloud_firestore.dart';

import 'converters.dart';
import 'live.dart';
import 'performance.dart';

/// ライブの記録（`users/{uid}/memories/{performanceId}`）
class LiveMemory {
  const LiveMemory({
    required this.performanceId,
    required this.liveId,
    required this.liveTitle,
    required this.startAt,
    required this.venue,
    this.seat,
    this.setlist = const [],
    this.impression,
    this.images = const [],
    this.isPublic = false,
    this.publicSeat = false,
    this.createdAt,
    this.updatedAt,
    this.postedAt,
  });

  /// 公演から、中身が空の記録を作る（ライブ名・開演日時・会場を複製する）。
  /// 公演の id か liveId が null なら `ArgumentError`
  factory LiveMemory.fromPerformance(Live live, Performance performance) {
    final performanceId = performance.id;
    final liveId = performance.liveId;
    if (performanceId == null || liveId == null) {
      throw ArgumentError('保存前の公演は記録できません');
    }
    return LiveMemory(
      performanceId: performanceId,
      liveId: liveId,
      liveTitle: live.title,
      startAt: performance.startAt,
      venue: performance.venue,
    );
  }

  factory LiveMemory.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return LiveMemory(
      performanceId: doc.id,
      liveId: data['liveId'] as String,
      liveTitle: data['liveTitle'] as String,
      startAt: toDateTime(data['startAt'])!,
      venue: data['venue'] as String,
      seat: data['seat'] as String?,
      setlist: toStringList(data['setlist']),
      impression: data['impression'] as String?,
      images: toStringList(data['images']),
      isPublic: data['isPublic'] as bool? ?? false,
      publicSeat: data['publicSeat'] as bool? ?? false,
      createdAt: toDateTime(data['createdAt']),
      updatedAt: toDateTime(data['updatedAt']),
      postedAt: toDateTime(data['postedAt']),
    );
  }

  final String performanceId; // ドキュメント ID
  final String liveId;
  final String liveTitle; // 複製
  final DateTime startAt; // 複製
  final String venue; // 複製
  final String? seat;
  final List<String> setlist;
  final String? impression;
  final List<String> images; // Storage のパス（1枚目が表紙）

  /// 同じ推しのファンに公開するか（add_K 3.1）
  final bool isPublic;

  /// 座席も公開するか。[isPublic] が false のときは使わない（add_K 3.1）
  final bool publicSeat;

  final DateTime? createdAt; // 保存直後（サーバー時刻の確定前）は null
  final DateTime? updatedAt; // 同上

  /// SNS に投稿する操作をした日時（無ければ未投稿）。ホームの「新しい記録」の判定に使う。
  /// [toFirestore] には入れない（`markPosted` だけが書く）
  final DateTime? postedAt;

  /// 参戦済みか（公演日時が [now] 以前）。false なら参戦予定
  bool isAttended(DateTime now) => !startAt.isAfter(now);

  /// 作成時に書き込む項目（日時は repository が付ける）
  Map<String, dynamic> toFirestore() => {
    'liveId': liveId,
    'liveTitle': liveTitle,
    'startAt': Timestamp.fromDate(startAt),
    'venue': venue,
    if (seat != null) 'seat': seat,
    'setlist': setlist,
    if (impression != null) 'impression': impression,
    'images': images,
    'isPublic': isPublic,
    'publicSeat': publicSeat,
  };

  /// 座席・セトリ・感想・写真（と公開の設定）を差し替えた複製。
  /// null を渡すとその項目を空にする。[isPublic]・[publicSeat] は省略すると今の値
  LiveMemory copyWithContent({
    required String? seat,
    required List<String> setlist,
    required String? impression,
    required List<String> images,
    bool? isPublic,
    bool? publicSeat,
  }) => LiveMemory(
    performanceId: performanceId,
    liveId: liveId,
    liveTitle: liveTitle,
    startAt: startAt,
    venue: venue,
    seat: seat,
    setlist: setlist,
    impression: impression,
    images: images,
    isPublic: isPublic ?? this.isPublic,
    publicSeat: publicSeat ?? this.publicSeat,
    createdAt: createdAt,
    updatedAt: updatedAt,
    postedAt: postedAt,
  );
}
