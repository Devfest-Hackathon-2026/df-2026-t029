import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}/myLives/{liveId}` の1件（自分のライブ一覧に入っているライブ）
class MyLive {
  const MyLive({required this.liveId, this.addedAt});

  /// ライブの ID（ドキュメント ID と同じ）
  final String liveId;

  /// 追加した日時（サーバー時刻）。書き込み直後は null のことがある
  final DateTime? addedAt;

  /// 欠けている・型が違う値があっても例外を投げない
  factory MyLive.fromFirestore(String id, Map<String, dynamic>? data) {
    final addedAt = data?['addedAt'];
    return MyLive(
      liveId: id,
      addedAt: addedAt is Timestamp ? addedAt.toDate() : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MyLive && other.liveId == liveId && other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(liveId, addedAt);

  @override
  String toString() => 'MyLive($liveId)';
}
