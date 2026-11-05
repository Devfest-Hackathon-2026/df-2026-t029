import 'package:cloud_firestore/cloud_firestore.dart';

/// 申込状況（DB 設計案 3.8・4章）。
///
/// 未申込は値なし（`null`＝ドキュメントなし）で表す。
enum ApplicationStatus {
  applied('applied', '申込済'),
  won('won', '当選'),
  lost('lost', '落選'),
  paid('paid', '入金済');

  const ApplicationStatus(this.code, this.label);

  /// Firestore に保存する値
  final String code;

  /// 画面に出す名前
  final String label;

  /// 未申込（`null`）を画面に出すときの名前
  static const String notAppliedLabel = '未申込';

  /// 不明な値・欠けている値なら null
  static ApplicationStatus? fromCode(Object? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// `users/{uid}/applications/{receptionId}` の1件
class Application {
  const Application({
    required this.receptionId,
    required this.liveId,
    required this.status,
    this.updatedAt,
  });

  /// 受付の ID（ドキュメント ID と同じ）
  final String receptionId;

  /// ライブの ID（絞り込み用）
  final String liveId;

  final ApplicationStatus status;

  /// サーバー時刻。書き込み直後（サーバーの確定前）は null のことがある
  final DateTime? updatedAt;

  /// 欠けている・型が違う値があっても例外を投げない。
  /// `status` が不明、または `liveId` が文字列でないときは null を返す（未申込として扱う）。
  static Application? fromFirestore(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    final status = ApplicationStatus.fromCode(data['status']);
    final liveId = data['liveId'];
    if (status == null || liveId is! String) return null;
    final updatedAt = data['updatedAt'];
    return Application(
      receptionId: id,
      liveId: liveId,
      status: status,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Application &&
      other.receptionId == receptionId &&
      other.liveId == liveId &&
      other.status == status &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(receptionId, liveId, status, updatedAt);

  @override
  String toString() =>
      'Application($receptionId, live: $liveId, ${status.code})';
}
