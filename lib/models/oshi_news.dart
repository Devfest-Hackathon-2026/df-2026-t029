import 'package:cloud_firestore/cloud_firestore.dart';

/// お知らせの種類（add_P 3.2）
enum OshiNewsType {
  youtube('新しい動画'),
  live('ライブ情報');

  const OshiNewsType(this.label);

  /// 画面の札に出す名前
  final String label;

  static OshiNewsType? fromCode(Object? code) => switch (code) {
    'youtube' => youtube,
    'live' => live,
    _ => null,
  };
}

/// 推しのお知らせ（`oshiNews/{id}`。add_P 3.2）。書くのは Functions だけ
class OshiNews {
  const OshiNews({
    required this.id,
    required this.oshiKey,
    required this.oshiName,
    required this.type,
    required this.title,
    required this.publishedAt,
    this.videoId,
    this.liveId,
  });

  final String id;

  /// 推しのキー（`group:xxx`・`person:xxx`。oshiColorKey と同じ形）
  final String oshiKey;
  final String oshiName;
  final OshiNewsType type;
  final String title;
  final DateTime publishedAt;

  /// [OshiNewsType.youtube] のとき
  final String? videoId;

  /// [OshiNewsType.live] のとき
  final String? liveId;

  /// 読めないもの（種類・タイトル・日時が無い、動画やライブの ID が無い）は null
  static OshiNews? fromFirestore(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    final type = OshiNewsType.fromCode(data['type']);
    final oshiKey = data['oshiKey'];
    final title = data['title'];
    final publishedAt = data['publishedAt'];
    if (type == null ||
        oshiKey is! String ||
        title is! String ||
        title.trim().isEmpty ||
        publishedAt is! Timestamp) {
      return null;
    }
    final videoId = data['videoId'] is String ? data['videoId'] as String : null;
    final liveId = data['liveId'] is String ? data['liveId'] as String : null;
    if (type == OshiNewsType.youtube && videoId == null) return null;
    if (type == OshiNewsType.live && liveId == null) return null;
    return OshiNews(
      id: id,
      oshiKey: oshiKey,
      oshiName: data['oshiName'] is String ? data['oshiName'] as String : '',
      type: type,
      title: title.trim(),
      publishedAt: publishedAt.toDate(),
      videoId: videoId,
      liveId: liveId,
    );
  }

  /// 動画のページ
  String? get videoUrl =>
      videoId == null ? null : 'https://www.youtube.com/watch?v=$videoId';

  /// サムネイル（保存せず、表示のときに読む）
  String? get thumbnailUrl =>
      videoId == null ? null : 'https://i.ytimg.com/vi/$videoId/mqdefault.jpg';

  /// 埋め込みのプレーヤー（add_P 5.5）
  String? get embedUrl => videoId == null
      ? null
      : 'https://www.youtube-nocookie.com/embed/$videoId';
}