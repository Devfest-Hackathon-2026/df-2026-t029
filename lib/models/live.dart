import 'package:cloud_firestore/cloud_firestore.dart';

import 'converters.dart';

class Live {
  const Live({
    this.id,
    required this.title,
    this.groupIds = const [],
    this.oshiIds = const [],
    this.officialUrl,
  });

  final String? id; // 保存前は null
  final String title;
  final List<String> groupIds;
  final List<String> oshiIds;
  final String? officialUrl;

  factory Live.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Live(
      id: doc.id,
      title: data['title'] as String,
      groupIds: toStringList(data['groupIds']),
      oshiIds: toStringList(data['oshiIds']),
      officialUrl: data['officialUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'groupIds': groupIds,
        'oshiIds': oshiIds,
        if (officialUrl != null) 'officialUrl': officialUrl,
      };
}