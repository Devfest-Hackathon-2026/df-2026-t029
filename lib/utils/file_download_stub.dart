import 'dart:typed_data';

/// Web 以外では保存できない（テストでは、呼び出し側の差し替え口で置き換える）
Future<void> downloadBytes(
  Uint8List bytes,
  String fileName, {
  String mimeType = 'image/png',
}) {
  throw UnsupportedError('この環境では、ファイルを保存できません');
}
