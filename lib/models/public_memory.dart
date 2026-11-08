import 'package:cloud_firestore/cloud_firestore.dart';

import 'converters.dart';
import 'live_memory.dart';

/// 公開メモリー（`publicMemories/{uid}_{performanceId}`。add_K 3.2）。
/// 自分の記録を公開したときに置く写し
class PublicMemory {
  const PublicMemory({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.performanceId,
    required this.liveId,
    required this.liveTitle,
    required this.startAt,
    required this.venue,
    this.groupIds = const [],
    this.oshiIds = const [],
    this.seat,
    this.setlist = const [],
    this.impression,
    this.images = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// ドキュメント ID（uid と performanceId を「_」でつなぐ）
  static String idOf(String uid, String performanceId) =>
      '${uid}_$performanceId';

  /// 自分の記録から、書き込む項目を作る（日時は repository が付ける）。
  /// 座席は [LiveMemory.publicSeat] が true のときだけ入れる
  static Map<String, dynamic> dataOf(
    LiveMemory memory, {
    required String uid,
    required String displayName,
    required List<String> groupIds,
    required List<String> oshiIds,
  }) {
    final seat = memory.publicSeat ? memory.seat : null;
    return {
      'uid': uid,
      'displayName': displayName,
      'performanceId': memory.performanceId,
      'liveId': memory.liveId,
      'liveTitle': memory.liveTitle,
      'startAt': Timestamp.fromDate(memory.startAt),
      'venue': memory.venue,
      'groupIds': groupIds,
      'oshiIds': oshiIds,
      'seat': ?seat,
      'setlist': memory.setlist,
      'impression': ?memory.impression,
      'images': memory.images,
    };
  }

  factory PublicMemory.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return PublicMemory(
      id: doc.id,
      uid: data['uid'] as String,
      displayName: data['displayName'] as String? ?? '',
      performanceId: data['performanceId'] as String,
      liveId: data['liveId'] as String,
      liveTitle: data['liveTitle'] as String,
      startAt: toDateTime(data['startAt'])!,
      venue: data['venue'] as String? ?? '',
      groupIds: toStringList(data['groupIds']),
      oshiIds: toStringList(data['oshiIds']),
      seat: data['seat'] as String?,
      setlist: toStringList(data['setlist']),
      impression: data['impression'] as String?,
      images: toStringList(data['images']),
      createdAt: toDateTime(data['createdAt']),
      updatedAt: toDateTime(data['updatedAt']),
    );
  }

  final String id; // ドキュメント ID（uid_performanceId）
  final String uid;
  final String displayName; // 書いた人の表示名の写し
  final String performanceId;
  final String liveId;
  final String liveTitle;
  final DateTime startAt;
  final String venue;
  final List<String> groupIds; // ライブの出演グループ（推しで探すのに使う）
  final List<String> oshiIds; // ライブの出演者（個人）
  final String? seat; // 座席も公開したときだけ
  final List<String> setlist;
  final String? impression;
  final List<String> images; // Storage のパス（1枚目が表紙）
  final DateTime? createdAt;
  final DateTime? updatedAt; // 保存直後（サーバー時刻の確定前）は null
}