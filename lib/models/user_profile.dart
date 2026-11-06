import 'package:cloud_firestore/cloud_firestore.dart';

/// アプリ内のプロフィール（`users/{uid}` の displayName・xAccount・profileUpdatedAt）
class UserProfile {
  const UserProfile({
    required this.displayName,
    this.xAccount,
    this.updatedAt,
  });

  /// ハンドルネーム。投稿・返信・チャットの表示名に使う
  final String displayName;

  /// X のユーザー名（@ なし）。投稿の X アカウントの初期値に使う
  final String? xAccount;

  /// 最後に保存した日時。保存直後（サーバー時刻の確定前）は null のことがある
  final DateTime? updatedAt;

  /// `users/{uid}` のデータから作る。プロフィール未作成なら null。
  ///
  /// - フォローで作られただけのドキュメント（Google の名前や「名無し」が
  ///   displayName に入っている）は、profileUpdatedAt が無いので未作成とする
  /// - 保存直後のローカルの値では、サーバー時刻の項目が null になるため、
  ///   値ではなくキーの有無で判定する（作成画面へ戻されないように）
  static UserProfile? fromFirestore(Map<String, dynamic>? data) {
    if (data == null || !data.containsKey('profileUpdatedAt')) return null;
    final name = data['displayName'];
    if (name is! String || name.trim().isEmpty) return null;
    final x = data['xAccount'];
    final updatedAt = data['profileUpdatedAt'];
    return UserProfile(
      displayName: name,
      xAccount: x is String && x.isNotEmpty ? x : null,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }
}