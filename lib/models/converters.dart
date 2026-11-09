import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore の timestamp を DateTime に変換する（空なら null）
DateTime? toDateTime(Object? value) => (value as Timestamp?)?.toDate();

/// Firestore の配列を `List<String>` に変換する（空なら空のリスト）
List<String> toStringList(Object? value) =>
    List<String>.from(value as List? ?? const []);
