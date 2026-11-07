/// 推しの名前・別名を、検索と重複判定のために正規化する（計画書 3.2）。
///
/// 1. 空白（全角スペースを含む）をすべて取り除く
/// 2. 全角英数字・記号（U+FF01〜U+FF5E）を半角にする
/// 3. 英字を小文字にする
/// 4. ひらがな（U+3041〜U+3096）をカタカナにする
/// 5. 半角カタカナを全角カタカナにする（濁点・半濁点の結合を含む）
/// 6. 中黒（・･）、ピリオド、ハイフン類、アンダースコアを取り除く
///
/// 長音符「ー」は名前の一部なので取り除かない。
String normalizeName(String input) {
  // 1
  var s = input.replaceAll(_whitespace, '');
  // 2
  s = String.fromCharCodes(
    s.runes.map((r) => (r >= 0xFF01 && r <= 0xFF5E) ? r - 0xFEE0 : r),
  );
  // 3
  s = s.toLowerCase();
  // 4
  s = String.fromCharCodes(
    s.runes.map((r) => (r >= 0x3041 && r <= 0x3096) ? r + 0x60 : r),
  );
  // 5・6
  final out = <int>[];
  for (final r in s.runes) {
    if (_removed.contains(r) || (r >= 0x2010 && r <= 0x2015)) continue;

    if (_dakuten.contains(r) && out.isNotEmpty) {
      final voiced = _voiced[out.last];
      if (voiced != null) {
        out[out.length - 1] = voiced;
        continue;
      }
    }
    if (_handakuten.contains(r) && out.isNotEmpty) {
      final semi = _semiVoiced[out.last];
      if (semi != null) {
        out[out.length - 1] = semi;
        continue;
      }
    }
    out.add(_halfToFull[r] ?? r);
  }
  return String.fromCharCodes(out);
}

final RegExp _whitespace = RegExp(r'\s');

/// 6 で取り除く文字（U+2010〜U+2015 のハイフン・ダッシュ類は別に判定）
const Set<int> _removed = {
  0x30FB, // ・ 中黒
  0xFF65, // ･ 半角中黒
  0x00B7, // · 中点
  0x002E, // . ピリオド（全角は 2 で半角になる）
  0x002D, // - ハイフンマイナス（全角は 2 で半角になる）
  0x2212, // − マイナス記号
  0x2043, // ⁃ ハイフンの箇条書き記号
  0xFE63, // ﹣ 小さいハイフンマイナス
  0x005F, // _ アンダースコア（全角は 2 で半角になる）
};

/// 濁点（半角 ﾞ、結合用、単独の ゛）
const Set<int> _dakuten = {0xFF9E, 0x3099, 0x309B};

/// 半濁点（半角 ﾟ、結合用、単独の ゜）
const Set<int> _handakuten = {0xFF9F, 0x309A, 0x309C};

/// 半角カタカナ・記号 → 全角
final Map<int, int> _halfToFull = () {
  const half = 'ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ';
  const full = 'ヲァィゥェォャュョッーアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン';
  final map = <int, int>{};
  final h = half.runes.toList();
  final f = full.runes.toList();
  for (var i = 0; i < h.length; i++) {
    map[h[i]] = f[i];
  }
  map[0xFF61] = 0x3002; // ｡ → 。
  map[0xFF62] = 0x300C; // ｢ → 「
  map[0xFF63] = 0x300D; // ｣ → 」
  map[0xFF64] = 0x3001; // ､ → 、
  map[0xFF9E] = 0x309B; // 結合できなかった ﾞ → ゛
  map[0xFF9F] = 0x309C; // 結合できなかった ﾟ → ゜
  map[0x3099] = 0x309B; // 結合できなかった結合用濁点 → ゛
  map[0x309A] = 0x309C; // 結合できなかった結合用半濁点 → ゜
  return map;
}();

/// 清音 → 濁音
final Map<int, int> _voiced = () {
  final map = <int, int>{};
  for (final r in 'カキクケコサシスセソタチツテトハヒフヘホ'.runes) {
    map[r] = r + 1;
  }
  map[0x30A6] = 0x30F4; // ウ → ヴ
  map[0x30EF] = 0x30F7; // ワ → ヷ
  map[0x30F2] = 0x30FA; // ヲ → ヺ
  return map;
}();

/// 清音 → 半濁音
final Map<int, int> _semiVoiced = {for (final r in 'ハヒフヘホ'.runes) r: r + 2};
