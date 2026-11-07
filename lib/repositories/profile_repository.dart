import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

/// アプリ内のプロフィール（`users/{uid}`。G-8）
abstract class ProfileRepository {
  /// プロフィールを購読する。未作成なら null
  Stream<UserProfile?> watch(String uid);

  /// プロフィールを保存する。
  ///
  /// - [displayName] は前後の空白を除く。空なら `ArgumentError`
  /// - [xAccount] が null・空なら、既存の値を消す
  /// - フォローの配列（followingGroupIds・followingOshiIds）は変えない
  /// - `users/{uid}` が無ければ、createdAt もあわせて作成する
  Future<void> save(
    String uid, {
    required String displayName,
    String? xAccount,
  });

  /// テーマカラーだけを保存する（D-6）。[color] が null なら項目を消して初期の色に戻す。
  /// プロフィールの保存日時（profileUpdatedAt）は変えない
  Future<void> saveThemeColor(String uid, int? color);
}

/// Firestore 版の [ProfileRepository]
class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Stream<UserProfile?> watch(String uid) => _user(uid)
      .snapshots()
      .map((snap) => UserProfile.fromFirestore(snap.data()));

  @override
  Future<void> save(
    String uid, {
    required String displayName,
    String? xAccount,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      throw ArgumentError('ハンドルネームを入力してください');
    }
    final x = xAccount?.trim() ?? '';
    final userRef = _user(uid);

    await _db.runTransaction<void>((tx) async {
      final userSnap = await tx.get(userRef);
      // 既存のドキュメントは update で、プロフィールの項目だけを書く。
      // （FollowRepository と同じく、fake_cloud_firestore の Transaction.set が
      // merge を無視するため、テストできる形にしている）
      if (userSnap.exists) {
        tx.update(userRef, {
          'displayName': name,
          'xAccount': x.isEmpty ? FieldValue.delete() : x,
          'profileUpdatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(userRef, {
          'displayName': name,
          if (x.isNotEmpty) 'xAccount': x,
          'profileUpdatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  @override
  Future<void> saveThemeColor(String uid, int? color) => _user(uid).update({
        'themeColor': color ?? FieldValue.delete(),
      });
}