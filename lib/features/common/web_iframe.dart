// iframe の埋め込み（add_P 5.5。add_M の地図でも使う）。
// Web では <iframe>、それ以外は灰色の箱。どちらも次の形:
//   WebIframe({required String src, double aspectRatio = 16 / 9, String title = ''})
export 'web_iframe_stub.dart'
    if (dart.library.js_interop) 'web_iframe_web.dart';