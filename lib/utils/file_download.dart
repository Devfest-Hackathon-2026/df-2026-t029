// ファイルの保存（ダウンロード）。Web では <a download>、それ以外は何もできない。
// どちらも次の形:
//   Future<void> downloadBytes(Uint8List bytes, String fileName,
//       {String mimeType = 'image/png'});
export 'file_download_stub.dart'
    if (dart.library.js_interop) 'file_download_web.dart';
