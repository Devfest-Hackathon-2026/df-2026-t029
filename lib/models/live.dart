import 'package:cloud_firestore/cloud_firestore.dart';

import 'converters.dart';

class Live {
  const Live({
    this.id,
    required this.title,
    this.groupIds = const [],
    this.oshiIds = const [],
    this.officialUrl,
    this.source,
    this.sourceUrls = const [],
    this.searchQueries = const [],
  });

  final String? id; // 保存前は null
  final String title;
  final List<String> groupIds;
  final List<String> oshiIds;
  final String? officialUrl;

  /// 'ai' なら AI が公式サイトから登録した（add_L 3.1）。読むだけで、アプリからは書かない
  final String? source;

  /// 出典の URL（add_L 3.1）。読むだけ
  final List<String> sourceUrls;

  /// 取得のときに使った Google 検索の語（add_L 3.1）。読むだけ
  final List<String> searchQueries;

  /// AI が登録したライブか（add_L 5.3）
  bool get isAi => source == 'ai';

  factory Live.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Live(
      id: doc.id,
      title: data['title'] as String,
      groupIds: toStringList(data['groupIds']),
      oshiIds: toStringList(data['oshiIds']),
      officialUrl: data['officialUrl'] as String?,
      source: data['source'] as String?,
      sourceUrls: toStringList(data['sourceUrls']),
      searchQueries: toStringList(data['searchQueries']),
    );
  }

  /// source・sourceUrls・searchQueries は書かない（Functions だけが書く。add_L 3.1）
  Map<String, dynamic> toFirestore() => {
        'title': title,
        'groupIds': groupIds,
        'oshiIds': oshiIds,
        if (officialUrl != null) 'officialUrl': officialUrl,
      };

  /// 保存後に ID を付けた複製
  Live copyWithId(String id) => Live(
        id: id,
        title: title,
        groupIds: groupIds,
        oshiIds: oshiIds,
        officialUrl: officialUrl,
        source: source,
        sourceUrls: sourceUrls,
        searchQueries: searchQueries,
      );
}