// 架空の公式サイト（デモ用）のデータ。Google にまつわるものをモチーフにした架空のグループ。
// 実在の人物・団体・会場とは関係がありません（会場名もすべて架空）。
//
// - このファイルは「公式サイトの生成（build.mjs）」と「推しのシード（tools/seed/seed_google.mjs）」の両方が読む。
//   推しの名前・ID を1か所で決めるため。
// - ライブはシードしない（アプリがこのサイトから取得する）。
// - 日時は基準日（日本時間）からの相対。[日, 時, 分] の形。
// - versions を付けたものは、その版だけに出す（版A＝最初、版B＝更新後。照合・変更履歴のデモ用）。

/** 推しの ID の頭（demo- にしない。functions/live_fetch は demo- の推しを取得の対象外にするため） */
export const GDEMO_PREFIX = 'gdemo-';

/**
 * グループ・ソロの定義。
 * kind: group | person。members はグループのみ。
 * slug は公式サイトのパス（/<slug>/）。live・schedule などクローラーの語や、news・profile など除外の語を含めない。
 */
export const ACTS = [
  {
    kind: 'group',
    slug: 'g-palette',
    id: 'gdemo-group-gpalette',
    name: 'G-Palette',
    kana: 'ジーパレット',
    aliases: ['ジーパレ', 'Gパレ'],
    genre: 'idol',
    genreLabel: 'アイドル',
    colors: ['#4285F4', '#EA4335', '#FBBC04', '#34A853'],
    catchCopy: '検索しても、見つからないくらい輝きたい。',
    about:
      'Google にまつわる4人が集まった、カラフルなアイドルグループ。' +
      'ブラウザの中から、スマホの中から、ステージの上へ。メンバーカラーは4色のパレット。',
    officialX: 'googlejapan',
    officialYoutube: '@GoogleJapan',
    members: [
      {
        key: 'chrome',
        id: 'gdemo-oshi-chrome',
        name: 'Chromeくん',
        aliases: ['クロームくん', 'Chrome'],
        color: '#4285F4',
        role: 'リーダー',
        profile: 'タブを開きすぎるのが悩み。どんな曲もすばやく読み込む。',
        birthday: '9月2日',
      },
      {
        key: 'android',
        id: 'gdemo-oshi-android',
        name: 'Androidくん',
        aliases: ['Android Bot', 'ドロイドくん'],
        color: '#34A853',
        role: 'パフォーマンス担当',
        profile: '緑のボディとアンテナがチャームポイント。ダンスはいつでもアップデート中。',
        birthday: '11月5日',
      },
      {
        key: 'moffy',
        id: 'gdemo-oshi-moffy',
        name: 'モッフィー',
        aliases: ['Moffy', 'もふもふ'],
        color: '#FBBC04',
        role: 'ムードメーカー',
        profile: 'Gemini が生み出した、もふもふの子。さわると幸せになれるらしい。',
        birthday: '12月6日',
      },
      {
        key: 'dino',
        id: 'gdemo-oshi-dino',
        name: 'Chrome Dino',
        aliases: ['ディノ', 'T-Rex'],
        color: '#EA4335',
        role: 'ボーカル',
        profile: 'オフラインになると現れる。サボテンを跳び越えるのが特技。',
        birthday: '12月1日',
      },
    ],
    lives: [
      {
        code: '260901',
        title: 'G-Palette お披露目ライブ「Hello, World!」',
        lead: '4人が初めてそろったステージ。たくさんのご来場、ありがとうございました。',
        perfs: [{ day: -40, open: [17, 30], start: [18, 30], venue: '下北沢ピクセルシアター', pref: '東京都' }],
        recs: [
          {
            name: '一般発売（先着）',
            start: [-70, 10, 0],
            end: [-41, 23, 59],
            prices: [['自由席', 3000]],
          },
        ],
      },
      {
        code: '261001',
        title: 'G-Palette 1st ワンマンライブ「Hello, Palette!」',
        lead: '初めてのワンマンライブが決定！ 4色そろったステージをお届けします。',
        perfs: [
          {
            day: 33,
            open: [17, 0],
            start: [18, 0],
            // 版B：開演時刻の変更（照合・変更履歴のデモ用）
            b: { open: [17, 30], start: [18, 30] },
            venue: 'ミナトみらいブルーホール',
            pref: '神奈川県',
          },
        ],
        recs: [
          {
            name: 'FC先行（抽選）',
            start: [-6, 12, 0],
            end: [1, 23, 59],
            result: [4, 18, 0],
            pay: [7, 23, 0],
            prices: [['指定席', 7700], ['立見', 5500]],
          },
          {
            name: '一般発売（先着）',
            start: [14, 10, 0],
            end: [30, 23, 59],
            prices: [['指定席', 7700], ['立見', 5500]],
          },
        ],
      },
      {
        code: '261003',
        title: 'Chrome Dino 生誕祭 2026 〜オフラインでも会いたい〜',
        lead: 'メンバー Chrome Dino の生誕祭。ほかのメンバーもお祝いにかけつけます。',
        perfs: [{ day: 12, open: [18, 0], start: [19, 0], venue: '渋谷オフラインホール', pref: '東京都' }],
        recs: [
          {
            name: '一般発売（先着）',
            start: [-10, 12, 0],
            end: [11, 23, 59],
            note: 'お支払いはお申し込みのときに行います。',
            prices: [['自由席', 4500]],
          },
        ],
      },
      {
        code: '261004',
        title: 'モッフィーのもふもふ配信ライブ',
        lead: 'おうちで見られる配信ライブ。アーカイブは1週間見られます。',
        perfs: [{ day: 20, start: [20, 0], venue: 'オンライン配信', pref: null }],
        recs: [
          {
            name: '配信チケット',
            start: [-3, 18, 0],
            end: [20, 22, 0],
            prices: [['視聴チケット', 2500]],
          },
        ],
      },
      {
        code: '261005',
        versions: ['b'],
        title: 'G-Palette クリスマスライブ「Merry Material」',
        lead: '追加決定！ 4人で過ごすクリスマスのライブです。',
        perfs: [{ day: 45, open: [17, 0], start: [18, 0], venue: 'お台場マテリアルホール', pref: '東京都' }],
        recs: [
          {
            name: 'FC先行（抽選）',
            start: [3, 12, 0],
            end: [9, 23, 59],
            result: [12, 18, 0],
            pay: [15, 23, 59],
            prices: [['指定席', 7700]],
          },
        ],
      },
      {
        code: '270101',
        title: 'G-Palette LIVE TOUR 2027「Colors of Search」',
        lead: '初めての全国ツアー。大阪・名古屋・東京の3か所をまわります。',
        perfs: [
          { day: 60, open: [16, 0], start: [17, 0], venue: 'なにわサーチホール', pref: '大阪府' },
          { day: 67, open: [16, 0], start: [17, 0], venue: '名古屋インデックスホール', pref: '愛知県' },
          { day: 74, open: [16, 0], start: [17, 0], venue: '東京クロールアリーナ', pref: '東京都' },
          // 版B：追加公演
          {
            day: 75,
            open: [15, 0],
            start: [16, 0],
            venue: '東京クロールアリーナ',
            pref: '東京都',
            versions: ['b'],
            label: '追加公演',
          },
        ],
        recs: [
          {
            name: 'FC1次先行（抽選）',
            start: [5, 12, 0],
            end: [12, 23, 59],
            result: [16, 18, 0],
            pay: [19, 23, 59],
            prices: [['S席', 9800], ['A席', 8800]],
          },
          {
            name: 'プレイガイド先行（抽選）',
            start: [20, 12, 0],
            end: [26, 23, 59],
            result: [29, 18, 0],
            pay: [32, 23, 59],
            prices: [['S席', 9800], ['A席', 8800]],
          },
          {
            name: '一般発売（先着）',
            start: [40, 10, 0],
            end: [58, 23, 59],
            prices: [['S席', 9800], ['A席', 8800]],
          },
        ],
      },
    ],
  },
  {
    kind: 'group',
    slug: 'hello-devs',
    id: 'gdemo-group-hellodevs',
    name: 'Hello Devs',
    kana: 'ハローデブズ',
    aliases: ['ハロデブ'],
    genre: 'artist',
    genreLabel: 'アーティスト',
    colors: ['#0175C2', '#00ADD8', '#FFCA28'],
    catchCopy: 'ホットリロードで、毎日が新曲。',
    about: '開発者の相棒たちが組んだスリーピースバンド。ライブハウスで少しずつ仲間を増やしている。',
    members: [
      {
        key: 'dash',
        id: 'gdemo-oshi-dash',
        name: 'Dash',
        aliases: ['ダッシュ'],
        color: '#0175C2',
        role: 'ボーカル',
        profile: '青い小鳥。羽ばたくように歌う。',
        birthday: '12月4日',
      },
      {
        key: 'gopher',
        id: 'gdemo-oshi-gopher',
        name: 'Gopher',
        aliases: ['ゴーファー'],
        color: '#00ADD8',
        role: 'ギター',
        profile: '並行していくつもフレーズを弾ける。',
        birthday: '11月10日',
      },
      {
        key: 'sparky',
        id: 'gdemo-oshi-sparky',
        name: 'Sparky',
        aliases: ['スパーキー'],
        color: '#FFCA28',
        role: 'ドラム',
        profile: '炎のように熱いビートで、リアルタイムに会場を燃やす。',
        birthday: '5月14日',
      },
    ],
    lives: [
      {
        code: '261101',
        title: 'Hello Devs ワンマンライブ「Hot Reload」',
        lead: '新曲をたくさん持っていきます。',
        perfs: [{ day: 25, open: [18, 0], start: [19, 0], venue: '恵比寿ウィジェットホール', pref: '東京都' }],
        recs: [
          {
            name: 'オフィシャル先行（抽選）',
            start: [-12, 12, 0],
            end: [-3, 23, 59],
            result: [2, 18, 0],
            pay: [5, 23, 59],
            prices: [['スタンディング', 4800]],
          },
          {
            name: '一般発売（先着）',
            start: [9, 10, 0],
            end: [24, 23, 59],
            prices: [['スタンディング', 4800]],
          },
        ],
      },
      {
        code: '270201',
        title: 'Hello Devs 東名阪ツアー「Build & Run」',
        lead: 'はじめての東名阪ツアー。',
        perfs: [
          { day: 50, open: [18, 0], start: [18, 30], venue: '心斎橋コンパイルホール', pref: '大阪府' },
          { day: 52, open: [18, 0], start: [18, 30], venue: '栄デプロイホール', pref: '愛知県' },
          { day: 57, open: [17, 0], start: [17, 30], venue: '渋谷ビルドホール', pref: '東京都' },
        ],
        recs: [
          {
            name: 'オフィシャル先行（抽選）',
            start: [7, 12, 0],
            end: [14, 23, 59],
            result: [18, 18, 0],
            pay: [21, 23, 59],
            prices: [['スタンディング', 5000]],
          },
        ],
      },
    ],
  },
  {
    kind: 'group',
    slug: 'doodle-stars',
    id: 'gdemo-group-doodlestars',
    name: 'Doodle Stars',
    kana: 'ドゥードゥルスターズ',
    aliases: ['ドゥースタ'],
    genre: 'voice_actor',
    genreLabel: '声優',
    colors: ['#A142F4', '#F439A0', '#24C1E0'],
    catchCopy: '毎日ちがう顔で、あなたの画面に。',
    about: 'いつもの画面にこっそり住んでいる3人の声優ユニット。朗読劇とトークイベントが中心。',
    members: [
      {
        key: 'pegman',
        id: 'gdemo-oshi-pegman',
        name: 'ペグマン',
        aliases: ['Pegman'],
        color: '#FBBC04',
        role: 'リーダー',
        profile: 'どこへでも降り立つ黄色い旅人。地図を読むのが得意。',
        birthday: '5月25日',
      },
      {
        key: 'noogler',
        id: 'gdemo-oshi-noogler',
        name: 'ヌーグラー',
        aliases: ['Noogler'],
        color: '#A142F4',
        role: '最年少',
        profile: 'プロペラの付いた帽子がトレードマーク。なんでも初めてで、なんでも楽しい。',
        birthday: '4月1日',
      },
      {
        key: 'stan',
        id: 'gdemo-oshi-stan',
        name: 'スタン',
        aliases: ['Stan'],
        color: '#24C1E0',
        role: '語り',
        profile: '中庭に立つ大きな恐竜の骨格。低い声で物語を語る。',
        birthday: '7月7日',
      },
    ],
    lives: [
      {
        code: '261201',
        title: 'Doodle Stars 朗読イベント「今日のロゴ」',
        lead: '昼の部・夜の部で、ちがうお話をお届けします。',
        perfs: [
          { day: 18, open: [12, 30], start: [13, 0], venue: '中野ドゥードゥルホール', pref: '東京都', label: '昼の部' },
          { day: 18, open: [17, 30], start: [18, 0], venue: '中野ドゥードゥルホール', pref: '東京都', label: '夜の部' },
        ],
        recs: [
          {
            name: 'FC先行（抽選）',
            start: [-14, 12, 0],
            end: [-7, 23, 59],
            result: [-2, 18, 0],
            // 撮影の日の夜に入金期限（24時間以内の「急ぎ」）
            pay: [0, 21, 0],
            prices: [['指定席', 6600]],
          },
          {
            name: '一般発売（先着）',
            start: [3, 10, 0],
            end: [17, 23, 59],
            prices: [['指定席', 6600]],
          },
        ],
      },
      {
        code: '270301',
        title: 'Doodle Stars ファンミーティング 2027',
        lead: 'ファンクラブ会員限定のファンミーティング。',
        perfs: [{ day: 80, open: [14, 0], start: [15, 0], venue: '大阪ストリートビューホール', pref: '大阪府' }],
        recs: [
          {
            name: 'FC先行（抽選）',
            start: [20, 12, 0],
            end: [27, 23, 59],
            result: [31, 18, 0],
            pay: [34, 23, 59],
            prices: [['指定席', 7000]],
          },
        ],
      },
    ],
  },
  {
    kind: 'person',
    slug: 'gemini-chan',
    id: 'gdemo-oshi-gemini',
    name: 'ジェミニちゃん',
    kana: 'ジェミニちゃん',
    aliases: ['ジェミちゃん'],
    genre: 'vtuber',
    genreLabel: 'VTuber',
    colors: ['#4E7CF6', '#9B72CB', '#D96570'],
    catchCopy: 'なんでも答えるよ、歌でもね。',
    about: 'きらきらの星から生まれたソロの VTuber。歌と雑談の配信を毎週している。',
    lives: [
      {
        code: '261301',
        title: 'ジェミニちゃん 3D お披露目配信',
        lead: 'はじめての 3D の姿をお披露目します。無料で見られます。',
        perfs: [{ day: 9, start: [21, 0], venue: 'オンライン配信', pref: null }],
        recs: [],
      },
      {
        code: '270401',
        title: 'ジェミニちゃん 1st LIVE「Multimodal」',
        lead: 'はじめての現地ライブ。配信もあります。',
        perfs: [{ day: 38, open: [17, 0], start: [18, 0], venue: '幕張トークンメッセ', pref: '千葉県' }],
        recs: [
          {
            name: '最速先行（抽選）',
            start: [-2, 12, 0],
            end: [6, 23, 59],
            result: [10, 18, 0],
            pay: [13, 23, 59],
            prices: [['指定席', 8800]],
          },
          {
            name: '配信チケット',
            start: [10, 12, 0],
            end: [38, 23, 59],
            prices: [['視聴チケット', 3500]],
          },
        ],
      },
    ],
  },
];

/** 版 [version] に出すものか */
export function inVersion(item, version) {
  return !item.versions || item.versions.includes(version);
}
