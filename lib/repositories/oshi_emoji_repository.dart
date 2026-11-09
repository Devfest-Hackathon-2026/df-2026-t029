import 'package:cloud_firestore/cloud_firestore.dart';

/// 推しの絵文字（個人の設定。`users/{uid}/settings/oshiEmojis`。add_I 3.1）。
///
/// `emojis` に「推しの色のキー（`group:xxx`・`person:xxx`）→ 絵文字1文字」を持つ
abstract class OshiEmojiRepository {
  /// 推しの色のキー → 絵文字。無ければ空
  Stream<Map<String, String>> watch(String uid);

  /// 絵文字を決める。[emoji] が null なら外す
  Future<void> setEmoji(String uid, String key, String? emoji);
}

/// Firestore 版の [OshiEmojiRepository]
class FirestoreOshiEmojiRepository implements OshiEmojiRepository {
  FirestoreOshiEmojiRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid).collection('settings').doc('oshiEmojis');

  @override
  Stream<Map<String, String>> watch(String uid) =>
      _doc(uid).snapshots().map((snap) {
        final emojis = snap.data()?['emojis'];
        if (emojis is! Map) return const {};
        return {
          for (final e in emojis.entries)
            if (e.key is String &&
                e.value is String &&
                (e.value as String).isNotEmpty)
              e.key as String: e.value as String,
        };
      });

  @override
  Future<void> setEmoji(String uid, String key, String? emoji) =>
      _doc(uid).set({
        'emojis': {key: emoji ?? FieldValue.delete()},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}
