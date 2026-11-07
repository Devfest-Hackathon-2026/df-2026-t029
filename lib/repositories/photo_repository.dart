import 'dart:math';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../utils/photo_picker.dart';

/// 写真の保存先（Cloud Storage。M-5 仕様書 5.2）
abstract class PhotoRepository {
  /// [dir] の下に写真をアップロードし、Storage のパスを返す
  Future<String> upload(String dir, PickedPhoto photo);

  /// 写真を消す。見つからないときは何もしない
  Future<void> delete(String path);

  /// まとめて消す。失敗しても止めない
  Future<void> deleteAll(Iterable<String> paths);

  /// 表示用のダウンロード URL
  Future<String> downloadUrl(String path);
}

/// Firebase Storage 版の [PhotoRepository]
class FirebasePhotoRepository implements PhotoRepository {
  FirebasePhotoRepository(this._storage);

  final FirebaseStorage _storage;

  static final _random = Random.secure();
  static const _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  /// `<日時のミリ秒>_<ランダム6文字>.<拡張子>`（M-5 仕様書 3.2）
  String _fileName(String extension) {
    final rand = List.generate(
      6,
      (_) => _chars[_random.nextInt(_chars.length)],
    ).join();
    return '${DateTime.now().millisecondsSinceEpoch}_$rand.$extension';
  }

  @override
  Future<String> upload(String dir, PickedPhoto photo) async {
    final path = '$dir/${_fileName(photo.extension)}';
    await _storage.ref(path).putData(
      photo.bytes,
      SettableMetadata(contentType: photo.contentType),
    );
    return path;
  }

  @override
  Future<void> delete(String path) async {
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  @override
  Future<void> deleteAll(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        await delete(path);
      } catch (e) {
        debugPrint('写真の削除に失敗: $path $e');
      }
    }
  }

  @override
  Future<String> downloadUrl(String path) =>
      _storage.ref(path).getDownloadURL();
}