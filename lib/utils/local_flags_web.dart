import 'package:web/web.dart' as web;

/// localStorage から読む。使えない（プライベートモードなど）ときは null
String? readLocalFlag(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

/// localStorage に書く。使えないときは何もしない
void writeLocalFlag(String key, String value) {
  try {
    web.window.localStorage.setItem(key, value);
  } catch (_) {
    // 保存できなくても、画面の操作は止めない
  }
}
