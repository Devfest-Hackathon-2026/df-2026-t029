# 既存のデモ用データ（tools/seed）を Google にまつわる架空の推しに作り替える（1回だけ使う）。
# python3 retheme.py <tools/seed のパス>
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
FILES = ['demo_data.mjs', 'demo_trade.mjs', 'demo_personal.mjs', 'demo_data.test.mjs', 'README.md']

NEW_GROUPS = r"""export const GROUPS = [
  {
    key: 'workspace',
    name: 'Work☆Space',
    genre: 'idol',
    aliases: ['ワクスペ', 'Work Space'],
    members: [
      ['gmail', 'メルル', 'Gmail'],
      ['calendar', 'カレン', 'Calendar'],
      ['drive', 'ミドリ', 'Drive'],
      ['docs', 'フミ', 'Docs'],
    ],
  },
  {
    key: 'maps',
    name: 'マップ☆ガイド',
    genre: 'idol',
    aliases: ['マプガイ', 'Maps'],
    members: [
      ['pin', 'ピン', 'Pin'],
      ['route', 'ルート', 'Route'],
      ['navi', 'ナビ', 'Navi'],
    ],
  },
  {
    key: 'pixel',
    name: 'TEAM PIXEL',
    genre: 'idol',
    aliases: ['チーピク'],
    members: [
      ['tensor', 'テンソル', 'Tensor'],
      ['camera', 'カメラ', 'Camera'],
      ['eraser', 'イレイサー', 'Magic Eraser'],
    ],
  },
  {
    key: 'okvoices',
    name: 'OK! Voices',
    genre: 'voice_actor',
    aliases: ['オケボ'],
    members: [
      ['assistant', 'アシスタ', 'Assistant'],
      ['nest', 'ネスト', 'Nest'],
      ['home', 'ホーム', 'Home'],
    ],
  },
  {
    key: 'playlists',
    name: 'The Playlists',
    genre: 'artist',
    aliases: ['プレリス'],
    members: [
      ['play', 'プレイ', 'Play'],
      ['shorts', 'ショーツ', 'Shorts'],
      ['music', 'ミュージック', 'Music'],
      ['premium', 'プレミアム', 'Premium'],
    ],
  },
  {
    key: 'kotoba',
    name: 'ことばレンズ',
    genre: 'vtuber',
    aliases: ['ことレン'],
    members: [
      ['lens', 'レンズ', 'Lens'],
      ['translate', 'ホンヤク', 'Translate'],
    ],
  },
  {
    // 申請中のグループ（「申請中」の表示の確認用）。メンバーも申請中
    key: 'earthdrop',
    name: 'アース☆ドロップ',
    genre: 'idol',
    aliases: ['アスドロ'],
    pending: true,
    members: [
      ['earth', 'アース', 'Earth'],
      ['moon', 'ムーン', 'Moon'],
    ],
  },
];

/** ソロは [ID のキー, 名前, 別名, ジャンル] */
export const SOLOS = [
  ['keep', 'キープちゃん', 'Keep', 'idol'],
  ['photos', 'フォトさん', 'Photos', 'voice_actor'],
  ['meet', 'ミート', 'Meet', 'artist'],
];
"""

# キー（ID の一部）：'旧' → '新'（引用符で囲まれたものだけ）
KEYS = {
    'stellanote': 'workspace', 'luminous': 'maps', 'blueorbit': 'pixel', 'prismvoice': 'okvoices',
    'midnight': 'playlists', 'neonlink': 'kotoba', 'cosmodrop': 'earthdrop',
    'luna': 'gmail', 'sora': 'calendar', 'hikari': 'drive', 'mio': 'docs',
    'momo': 'pin', 'rin': 'route', 'tsubasa': 'navi',
    'haruto': 'tensor', 'ren': 'camera', 'yu': 'eraser',
    'yui': 'assistant', 'shizuku': 'nest', 'nana': 'home',
    'kai': 'play', 'jin': 'shorts', 'yuki': 'music', 'takumi': 'premium',
    'milk': 'lens', 'ao': 'translate', 'kirara': 'earth', 'riri': 'moon',
    'reina': 'keep', 'minato': 'photos', 'kanata': 'meet',
}
# ライブ・グッズのキーの頭
PREFIXES = {
    'stella-': 'workspace-', 'luminous-': 'maps-', 'blueorbit-': 'pixel-', 'prism-': 'okvoices-',
    'midnight-': 'playlists-', 'neon-': 'kotoba-', 'reina-': 'keep-', 'minato-': 'photos-',
    'kanata-': 'meet-', 'hoshizora-fest': 'cloud-fest',
}
# 表示の文字（長いものから置き換える）
TEXT = {
    'ステラノート 全国ツアー 2026「ひかりの旋律」': 'Work☆Space 全国ツアー 2026「Shared with You」',
    'ステラノート 1st ライブ「はじまりの夜」': 'Work☆Space 1st ライブ「はじまりの受信箱」',
    'ステラノート 生写真セット「はじまりの夜」': 'Work☆Space 生写真セット「はじまりの受信箱」',
    'ステラノート TOUR 2026': 'Work☆Space TOUR 2026',
    'ルミナス☆ガーデン 秋のワンマン「花ひらく」': 'マップ☆ガイド 秋のワンマン「目的地はここ」',
    'BLUE ORBIT ARENA TOUR「ORBIT LINE」': 'TEAM PIXEL ARENA TOUR「SNAPSHOT」',
    'BLUE ORBIT 缶バッジ「ORBIT LINE」': 'TEAM PIXEL 缶バッジ「SNAPSHOT」',
    'Prism Voice 1st LIVE「Colorful Harmony」': 'OK! Voices 1st LIVE「Hey, Harmony」',
    '柊ミナト ファンミーティング 2026': 'フォトさん ファンミーティング 2026「思い出」',
    'ミッドナイト・トレイン LIVE HOUSE TOUR「終電のあとで」': 'The Playlists LIVE HOUSE TOUR「おすすめの次に」',
    'ミッドナイト・トレイン ワンマン「夜明け前」': 'The Playlists ワンマン「自動再生」',
    'ネオンリンク 3Dライブ「Link Start!」': 'ことばレンズ 3Dライブ「Look & Talk」',
    '白鳥レイナ コンサート 2026「Swan Song」': 'キープちゃん コンサート 2026「メモのうた」',
    '空野カナタ アコースティックライブ「ことのは」': 'ミート アコースティックライブ「ミュートを外して」',
    'ほしぞらフェス': 'クラウドフェス',
    # セットリスト・感想（メモリー）
    "'はじまりの夜'": "'はじまりの受信箱'",
    "'ステラ・ノート（アンコール）'": "'Shared with You（アンコール）'",
    "'ステラ・ノート'": "'Shared with You'",
    "'星降るメロディ'": "'既読のメロディ'",
    "'きみと見た流星'": "'スター付きのきみ'",
    "'ミッドナイト・テレスコープ'": "'ミッドナイト・リマインダー'",
    "'またね、ステラ'": "'またね、Work☆Space'",
    '開演の瞬間に会場が星空みたいになって': '開演の瞬間に会場がペンライトの4色に染まって',
    '「ステラ・ノート」を歌って': '「Shared with You」を歌って',
    "'終電のあとで'": "'おすすめの次に'",
    "'夜明け前'": "'自動再生'",
    "'ネオンの海'": "'再生リストの海'",
    "'ことのは'": "'ミュートを外して'",
    'ユウキのベースソロ': 'ミュージックのベースソロ',
    '金沢ことのはイン': '金沢あかりイン',
    # グループ名
    'ステラノート': 'Work☆Space',
    'ルミナス☆ガーデン': 'マップ☆ガイド',
    'BLUE ORBIT': 'TEAM PIXEL',
    'Prism Voice': 'OK! Voices',
    'ミッドナイト・トレイン': 'The Playlists',
    'ネオンリンク': 'ことばレンズ',
    # メンバー（フルネーム → 短い名前の順）
    '星宮ルナ': 'メルル', '月城ソラ': 'カレン', '陽野ヒカリ': 'ミドリ', '雪村ミオ': 'フミ',
    '白鳥レイナ': 'キープちゃん', '柊ミナト': 'フォトさん', '空野カナタ': 'ミート',
    'ルナ': 'メルル', 'ソラ': 'カレン', 'ヒカリ': 'ミドリ', 'ミオ': 'フミ',
    # 架空のファンの名前
    'るなまる': 'めるまる', 'そらいろ': 'かれんだ', 'ひかりんご': 'みどりんご', 'みおみお': 'ふみふみ',
    'モモ担': 'ピン担', 'つばさ推し': 'ナビ推し', 'はると担': 'テンソル担', 'しずく推し': 'ネスト推し',
    'ねおん': 'ことれん',
    'lunamaru_demo': 'merumaru_demo', 'sorairo_demo': 'karenda_demo', 'miomio_demo': 'fumifumi_demo',
    'tsubasa_demo': 'navi_demo', 'shizuku_demo': 'nest_demo', 'neon_demo': 'kotoren_demo',
}

for name in FILES:
    p = root / name
    s = p.read_text(encoding='utf-8')
    if name == 'demo_data.mjs':
        s, n = re.subn(r"export const GROUPS = \[.*?\n\];\n\n/\*\* ソロは.*?\n\];\n", NEW_GROUPS, s, flags=re.S)
        assert n == 1, 'GROUPS が見つかりません'
        s = s.replace('// 推し（グループ7・個人22。ジャンルの半分をアイドルにする）',
                      '// 推し（グループ7・個人22。Google にまつわるものがモチーフ。ジャンルの半分をアイドルにする）')
    for old, new in PREFIXES.items():
        s = s.replace(old, new)
    for old, new in KEYS.items():
        s = re.sub(rf"'{re.escape(old)}'", f"'{new}'", s)
    for old in sorted(TEXT, key=len, reverse=True):
        s = s.replace(old, TEXT[old])
    p.write_text(s, encoding='utf-8')
    print('更新', name)
