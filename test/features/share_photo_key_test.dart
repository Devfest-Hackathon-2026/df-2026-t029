// sharePhotoBytesKey（投稿用の写真の取得キー）のテスト。ホームのカードも同じキーで先頭4枚を使う。
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/memory/share/share_providers_ui.dart';
import 'package:oshiashi/utils/share_ticket.dart';

void main() {
  test('先頭 kShareMaxPhotos(4) 枚だけをキーにする', () {
    expect(kShareMaxPhotos, 4);
    expect(sharePhotoBytesKey(['a', 'b', 'c', 'd', 'e', 'f']), 'a|b|c|d');
  });

  test('4枚未満はそのまま、0枚は空', () {
    expect(sharePhotoBytesKey(['a', 'b', 'c']), 'a|b|c');
    expect(sharePhotoBytesKey(const []), '');
  });
}
