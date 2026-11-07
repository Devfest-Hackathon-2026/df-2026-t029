import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// 写真1枚の大きさの上限（Storage のルールと同じ。M-5 仕様書 3.1）
const maxPhotoBytes = 5 * 1024 * 1024;

/// 縮小後の長辺（px）
const photoMaxSide = 1600.0;

/// 1つの記録（G-7 では1つの投稿）に付けられる写真の枚数
const maxPhotosPerItem = 8;

/// 対応している形式 → 拡張子
const _extensionOf = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
};

/// 拡張子 → 形式（mimeType が取れないとき用）
const _contentTypeOfExtension = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
};

/// 選んだ写真（まだアップロードしていない）
class PickedPhoto {
  const PickedPhoto({
    required this.bytes,
    required this.contentType,
    required this.extension,
  });

  final Uint8List bytes;

  /// `image/jpeg` など
  final String contentType;

  /// `jpg` など（ファイル名に使う）
  final String extension;
}

/// 写真を選んだ結果
class PhotoPickResult {
  const PhotoPickResult({
    required this.photos,
    required this.rejected,
    required this.overLimit,
  });

  /// 追加できる写真（先頭から、空いている枚数まで）
  final List<PickedPhoto> photos;

  /// 大きすぎる・対応していない形式で外した枚数
  final int rejected;

  /// 枚数の上限で入れなかった枚数
  final int overLimit;
}

/// 形式を決める。対応していなければ null
String? _contentTypeOf(XFile file) {
  final mime = file.mimeType;
  if (mime != null && _extensionOf.containsKey(mime)) return mime;
  final name = file.name.toLowerCase();
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;
  return _contentTypeOfExtension[name.substring(dot + 1)];
}

/// 写真を選ぶ（複数可）。長辺 1600px に縮小し、形式と大きさで振り分け、
/// 先頭から [remaining] 枚までを返す（M-5 仕様書 3.1・5.1）。
/// 何も選ばなかったときは、すべて空・0 の結果になる。
Future<PhotoPickResult> pickPhotos({required int remaining}) async {
  final files = await ImagePicker().pickMultiImage(
    maxWidth: photoMaxSide,
    maxHeight: photoMaxSide,
    imageQuality: 85,
  );
  final photos = <PickedPhoto>[];
  var rejected = 0;
  for (final file in files) {
    final type = _contentTypeOf(file);
    if (type == null) {
      rejected++;
      continue;
    }
    final bytes = await file.readAsBytes();
    if (bytes.length >= maxPhotoBytes) {
      rejected++;
      continue;
    }
    photos.add(
      PickedPhoto(bytes: bytes, contentType: type, extension: _extensionOf[type]!),
    );
  }
  final room = remaining < 0 ? 0 : remaining;
  return PhotoPickResult(
    photos: photos.take(room).toList(),
    rejected: rejected,
    overLimit: photos.length > room ? photos.length - room : 0,
  );
}

/// 選んだ結果の知らせ（外したもの・上限で入れなかったものがあるときだけ）
String? photoPickMessage(PhotoPickResult result) {
  final parts = [
    if (result.rejected > 0)
      '${result.rejected}枚は大きすぎるか、対応していない形式のため追加できませんでした',
    if (result.overLimit > 0) '写真は$maxPhotosPerItem枚までです',
  ];
  return parts.isEmpty ? null : parts.join('。');
}