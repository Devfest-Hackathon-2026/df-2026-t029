import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// ブラウザのダウンロードで [bytes] を [fileName] として保存する
Future<void> downloadBytes(
  Uint8List bytes,
  String fileName, {
  String mimeType = 'image/png',
}) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  try {
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  } catch (_) {
    web.URL.revokeObjectURL(url);
    rethrow;
  }
  // ブラウザによっては、すぐ無効にすると保存が失敗する。少し待ってから無効にする
  Timer(const Duration(seconds: 2), () => web.URL.revokeObjectURL(url));
}
