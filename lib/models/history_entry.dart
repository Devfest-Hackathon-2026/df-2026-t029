import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// 変更履歴を持つ共通データのコレクション（DB 設計案 3.6）
enum HistoryCollection { lives, performances, receptions }

/// 変更履歴の対象（どのコレクションのどのドキュメントか）
@immutable
class HistoryTarget {
  const HistoryTarget(this.collection, this.docId);

  final HistoryCollection collection;
  final String docId;

  /// Firestore のドキュメントのパス（例: `performances/abc`）
  String get path => '${collection.name}/$docId';

  @override
  bool operator ==(Object other) =>
      other is HistoryTarget &&
      other.collection == collection &&
      other.docId == docId;

  @override
  int get hashCode => Object.hash(collection, docId);

  @override
  String toString() => 'HistoryTarget($path)';
}

/// 変更履歴1件（`{collection}/{docId}/history/{id}`）。
///
/// [before]・[after] は Firestore に保存した形のまま（Timestamp・List・Map など）。
/// 値が無かった（項目が無かった）ことと null を区別するため、[hasBefore]・
/// [hasAfter] を持つ。元に戻すとき、[hasBefore] が false なら項目を消す。
@immutable
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.target,
    required this.field,
    this.before,
    this.after,
    this.hasBefore = false,
    this.hasAfter = false,
    required this.changedBy,
    this.changedAt,
  });

  final String id;
  final HistoryTarget target;
  final String field;
  final Object? before;
  final Object? after;
  final bool hasBefore;
  final bool hasAfter;
  final String changedBy;

  /// 書き込み直後（サーバー時刻が未確定）は null
  final DateTime? changedAt;

  /// Firestore から読む。項目が欠けていても落ちない（field は空文字、
  /// changedBy は空文字、changedAt は null になる）
  factory HistoryEntry.fromFirestore(
    HistoryTarget target,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final field = data['field'];
    final changedBy = data['changedBy'];
    final changedAt = data['changedAt'];
    return HistoryEntry(
      id: doc.id,
      target: target,
      field: field is String ? field : '',
      before: data['before'],
      after: data['after'],
      hasBefore: data.containsKey('before'),
      hasAfter: data.containsKey('after'),
      changedBy: changedBy is String ? changedBy : '',
      changedAt: changedAt is Timestamp ? changedAt.toDate() : null,
    );
  }

  @override
  String toString() =>
      'HistoryEntry(${target.path}/$id $field: $before → $after)';
}

/// ドキュメント1件の作成日時・更新日時（ライブ詳細の「追加」の判定用）
@immutable
class DocStamp {
  const DocStamp({required this.target, this.createdAt, this.updatedAt});

  final HistoryTarget target;

  /// 書き込み直後（サーバー時刻が未確定）や、値が欠けているときは null
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// ライブ詳細に出す変更1件（項目の変更か、既存のライブへの公演・受付の追加）
sealed class LiveChange {
  const LiveChange();

  HistoryTarget get target;

  /// 変更・追加の日時。未確定なら null
  DateTime? get at;
}

/// 項目の変更（履歴1件）
final class FieldEdited extends LiveChange {
  const FieldEdited(this.entry);

  final HistoryEntry entry;

  @override
  HistoryTarget get target => entry.target;

  @override
  DateTime? get at => entry.changedAt;
}

/// 既存のライブに後から追加された公演・受付（項目ごとの履歴は無い）。
/// ライブと同じバッチで作られたもの（createdAt がライブと同じ）は含めない
final class DocAdded extends LiveChange {
  const DocAdded({required this.target, required this.at});

  @override
  final HistoryTarget target;

  @override
  final DateTime? at;
}
