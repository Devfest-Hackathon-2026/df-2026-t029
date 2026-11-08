import 'package:cloud_firestore/cloud_firestore.dart';

import 'converters.dart';

class Performance {
  const Performance({
    this.id,
    this.liveId,
    this.groupIds = const [],
    this.oshiIds = const [],
    required this.startAt,
    this.openAt,
    required this.venue,
    this.prefecture,
    this.source,
  });

  final String? id; // 保存前は null
  final String? liveId; // 保存時に repository が付ける
  final List<String> groupIds; // 同上（ライブからの複製）
  final List<String> oshiIds; // 同上（ライブからの複製）
  final DateTime startAt;
  final DateTime? openAt;
  final String venue;
  final String? prefecture;

  /// 'ai' なら AI が登録した（add_L 3.1）。読むだけで、アプリからは書かない
  final String? source;

  /// AI が登録した公演か（add_L 5.3）
  bool get isAi => source == 'ai';

  factory Performance.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Performance(
      id: doc.id,
      liveId: data['liveId'] as String?,
      groupIds: toStringList(data['groupIds']),
      oshiIds: toStringList(data['oshiIds']),
      startAt: toDateTime(data['startAt'])!,
      openAt: toDateTime(data['openAt']),
      venue: data['venue'] as String,
      prefecture: data['prefecture'] as String?,
      source: data['source'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'startAt': Timestamp.fromDate(startAt),
        if (openAt != null) 'openAt': Timestamp.fromDate(openAt!),
        'venue': venue,
        if (prefecture != null) 'prefecture': prefecture,
      };
  
  /// 保存時に、ID とライブから複製する項目を付けた複製
  Performance copyWithIds({
    required String id,
    required String liveId,
    required List<String> groupIds,
    required List<String> oshiIds,
  }) =>
      Performance(
        id: id,
        liveId: liveId,
        groupIds: groupIds,
        oshiIds: oshiIds,
        startAt: startAt,
        openAt: openAt,
        venue: venue,
        prefecture: prefecture,
      );
}