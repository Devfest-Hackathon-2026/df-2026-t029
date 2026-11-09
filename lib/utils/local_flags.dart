// このブラウザだけに覚えておく、小さな文字列の保存（Web では localStorage）。
// どちらも次の形:
//   String? readLocalFlag(String key);
//   void writeLocalFlag(String key, String value);
// 読み書きに失敗しても例外は投げない（読めなければ null・書けなければ何もしない）。
export 'local_flags_stub.dart'
    if (dart.library.js_interop) 'local_flags_web.dart';
