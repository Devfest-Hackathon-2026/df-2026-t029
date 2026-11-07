// デモ用データの定義（すべて架空。実在の人物・団体・作品・会場とは関係がありません）。
// 日時は「基準日（日本時間）」からの相対で決める。
// ドキュメント ID は demo- で始まる固定の値（何度実行しても同じ内容に上書きされる）。
// アプリのルール（firestore.rules）の hasOnly に無い項目は足さない。
// 仕様はプロジェクトの「デモ用データの仕様書」。

export const DEMO_PREFIX = 'demo-';
export const DEMO_UID = 'demo-seed'; // createdBy / updatedBy に入れる架空の uid
export const DEMO_EDITOR = 'demo-user-01'; // 変更履歴を書いた人（架空のユーザー）

/** トップレベルのコレクション（消すときに使う。サブコレクションは一緒に消える） */
export const DEMO_COLLECTIONS = [
  'groups',
  'oshis',
  'lives',
  'performances',
  'receptions',
  'goods',
  'tradePosts',
  'chats',
];

const JST_OFFSET_HOURS = 9;

/** 'YYYY-MM-DD'（日本時間の日付）を、その日の日本時間 0:00 の UTC ミリ秒にする */
export function baseMillis(base) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(base);
  if (!m) throw new Error(`--base は YYYY-MM-DD の形で指定してください: ${base}`);
  return Date.UTC(+m[1], +m[2] - 1, +m[3]) - JST_OFFSET_HOURS * 3600 * 1000;
}

/** 今日の日付（日本時間）を 'YYYY-MM-DD' で返す */
export function todayJst(now = new Date()) {
  const jst = new Date(now.getTime() + JST_OFFSET_HOURS * 3600 * 1000);
  return jst.toISOString().slice(0, 10);
}

/**
 * 基準日の dayOffset 日後の、日本時間 hour:minute の Date を返す。
 * 例: at(b, 2, 23, 59) = 基準日の2日後の 23:59
 */
export function at(baseMs, dayOffset, hour = 0, minute = 0) {
  return new Date(
    baseMs + dayOffset * 86400000 + hour * 3600000 + minute * 60000,
  );
}

// ---------------------------------------------------------------
// ID の作り方（ほかのファイルからも使う）
// ---------------------------------------------------------------

export const groupId = (key) => `demo-group-${key}`;
export const oshiId = (key) => `demo-oshi-${key}`;
export const liveId = (key) => `demo-live-${key}`;
export const perfId = (liveKey, n) => `demo-perf-${liveKey}-${n}`;
export const recId = (liveKey, recKey) => `demo-rec-${liveKey}-${recKey}`;

// ---------------------------------------------------------------
// 推し（グループ7・個人22。ジャンルの半分をアイドルにする）
// ---------------------------------------------------------------

/** メンバーは [ID のキー, 名前, 別名] */
export const GROUPS = [
  {
    key: 'stellanote',
    name: 'ステラノート',
    genre: 'idol',
    aliases: ['ステラ', 'STELLA NOTE'],
    members: [
      ['luna', '星宮ルナ', 'ルナ'],
      ['sora', '月城ソラ', 'ソラ'],
      ['hikari', '陽野ヒカリ', 'ヒカリ'],
      ['mio', '雪村ミオ', 'ミオ'],
    ],
  },
  {
    key: 'luminous',
    name: 'ルミナス☆ガーデン',
    genre: 'idol',
    aliases: ['ルミガ'],
    members: [
      ['momo', '花咲モモ', 'モモ'],
      ['rin', '桜井リン', 'リン'],
      ['tsubasa', '葉山ツバサ', 'ツバサ'],
    ],
  },
  {
    key: 'blueorbit',
    name: 'BLUE ORBIT',
    genre: 'idol',
    aliases: ['ブルオビ'],
    members: [
      ['haruto', '蒼井ハルト', 'ハルト'],
      ['ren', '黒瀬レン', 'レン'],
      ['yu', '白石ユウ', 'ユウ'],
    ],
  },
  {
    key: 'prismvoice',
    name: 'Prism Voice',
    genre: 'voice_actor',
    aliases: ['プリボ'],
    members: [
      ['yui', '天羽ユイ', 'ユイ'],
      ['shizuku', '宵宮シズク', 'シズク'],
      ['nana', '春野ナナ', 'ナナ'],
    ],
  },
  {
    key: 'midnight',
    name: 'ミッドナイト・トレイン',
    genre: 'artist',
    aliases: ['ミドトレ'],
    members: [
      ['kai', '鳴海カイ', 'カイ'],
      ['jin', '霧島ジン', 'ジン'],
      ['yuki', '早瀬ユウキ', 'ユウキ'],
      ['takumi', '真壁タクミ', 'タクミ'],
    ],
  },
  {
    key: 'neonlink',
    name: 'ネオンリンク',
    genre: 'vtuber',
    aliases: ['ネオリン'],
    members: [
      ['milk', '猫宮ミルク', 'ミルク'],
      ['ao', '竜胆アオ', 'アオ'],
    ],
  },
  {
    // 申請中のグループ（「申請中」の表示の確認用）。メンバーも申請中
    key: 'cosmodrop',
    name: 'コスモドロップ',
    genre: 'idol',
    aliases: ['コスモ'],
    pending: true,
    members: [
      ['kirara', '流星キララ', 'キララ'],
      ['riri', '宙野リリ', 'リリ'],
    ],
  },
];

/** ソロは [ID のキー, 名前, 別名, ジャンル] */
export const SOLOS = [
  ['reina', '白鳥レイナ', 'レイナ', 'idol'],
  ['minato', '柊ミナト', 'ミナト', 'voice_actor'],
  ['kanata', '空野カナタ', 'カナタ', 'artist'],
];

function buildOshiDocs(created) {
  const docs = [];
  const base = { createdBy: DEMO_UID, createdAt: created };
  for (const g of GROUPS) {
    const status = g.pending ? 'pending' : 'approved';
    docs.push({
      path: `groups/${groupId(g.key)}`,
      data: { name: g.name, aliases: g.aliases, genre: g.genre, status, ...base },
    });
    for (const [key, name, alias] of g.members) {
      docs.push({
        path: `oshis/${oshiId(key)}`,
        data: {
          name,
          aliases: [alias],
          genre: g.genre,
          groupIds: [groupId(g.key)],
          status,
          ...base,
        },
      });
    }
  }
  for (const [key, name, alias, genre] of SOLOS) {
    docs.push({
      path: `oshis/${oshiId(key)}`,
      data: {
        name,
        aliases: [alias],
        genre,
        groupIds: [],
        status: 'approved',
        ...base,
      },
    });
  }
  return docs;
}

// ---------------------------------------------------------------
// ライブ・公演・受付（ライブ15）
// 公演は [日, 時, 分, 会場, 都道府県]。都道府県が null（オンライン）なら開場も入れない
// 受付の日時は [日, 時, 分]（基準日からの相対）
// ---------------------------------------------------------------

export const LIVES = [
  {
    key: 'stella-tour',
    title: 'ステラノート 全国ツアー 2026「ひかりの旋律」',
    groups: ['stellanote'],
    oshis: [],
    perfs: [
      [40, 18, 0, '東京ドリームホール', '東京都'],
      [41, 17, 0, '東京ドリームホール', '東京都'],
      [47, 17, 0, '大阪ミライアリーナ', '大阪府'],
      [54, 17, 30, '福岡ベイホール', '福岡県'],
      [61, 17, 0, '名古屋スターライトホール', '愛知県'],
    ],
    recs: [
      {
        key: 'fc',
        type: 'fc',
        name: 'FC先行（抽選）',
        start: [-12, 12, 0],
        end: [-5, 23, 59],
        result: [-2, 18, 0],
        pay: [7, 23, 59],
        prices: [['S席', 12000], ['A席', 9800]],
      },
      {
        key: 'upgrade',
        type: 'upgrade',
        name: 'アップグレード（当選者のみ）',
        start: [-3, 12, 0],
        end: [1, 23, 59],
        result: [3, 18, 0],
        pay: [5, 23, 59],
        prices: [['VIP席への差額', 8000]],
        winnersOnly: true,
      },
      {
        key: 'pg2',
        type: 'other',
        name: 'プレイガイド2次先行',
        start: [2, 12, 0],
        end: [8, 23, 59],
        result: [11, 18, 0],
        prices: [['S席', 12000], ['A席', 9800]],
      },
      {
        key: 'general',
        type: 'general',
        name: '一般発売',
        start: [12, 10, 0],
        end: [19, 23, 59],
        result: [22, 18, 0],
        prices: [['指定席', 9800]],
      },
    ],
  },
  {
    key: 'hoshizora-fest',
    title: 'ほしぞらフェス 2026',
    groups: ['stellanote', 'luminous', 'midnight'],
    oshis: ['kanata'],
    perfs: [
      [30, 12, 0, '静岡ほしぞら公園 特設ステージ', '静岡県'],
      [31, 12, 0, '静岡ほしぞら公園 特設ステージ', '静岡県'],
    ],
    recs: [
      {
        key: 'pg',
        type: 'other',
        name: 'プレイガイド先行',
        start: [-14, 12, 0],
        end: [-7, 23, 59],
        result: [-3, 18, 0],
        pay: [2, 23, 59],
        prices: [['1日券', 7500], ['2日通し券', 13000]],
      },
      {
        key: 'general',
        type: 'general',
        name: '一般発売',
        start: [5, 10, 0],
        end: [20, 23, 59],
        prices: [['1日券', 8000], ['2日通し券', 14000]],
      },
    ],
  },
  {
    key: 'stella-1st',
    title: 'ステラノート 1st ライブ「はじまりの夜」',
    groups: ['stellanote'],
    oshis: [],
    perfs: [[-20, 18, 0, '横浜ハーバーホール', '神奈川県']],
    recs: [
      {
        key: 'general',
        type: 'general',
        name: '一般発売',
        start: [-60, 10, 0],
        end: [-50, 23, 59],
        result: [-47, 18, 0],
        pay: [-40, 23, 59],
        prices: [['指定席', 6800]],
      },
    ],
  },
  {
    key: 'luminous-oneman',
    title: 'ルミナス☆ガーデン 秋のワンマン「花ひらく」',
    groups: ['luminous'],
    oshis: [],
    perfs: [[12, 18, 30, '渋谷フラワーホール', '東京都']],
    recs: [
      {
        key: 'fc',
        type: 'fc',
        name: 'FC先行',
        start: [-10, 12, 0],
        end: [-4, 23, 59],
        result: [-1, 18, 0],
        // 撮影の日の夜に入金期限（24時間以内の「急ぎ」）
        pay: [0, 21, 0],
        prices: [['指定席', 7000]],
      },
      {
        key: 'general',
        type: 'general',
        name: '一般発売',
        start: [1, 10, 0],
        end: [6, 23, 59],
        result: [8, 18, 0],
        prices: [['指定席', 7000]],
      },
    ],
  },
  {
    key: 'luminous-release',
    title: 'ルミナス☆ガーデン 新曲リリースイベント',
    groups: ['luminous'],
    oshis: [],
    perfs: [
      [3, 13, 0, '池袋スカイステージ', '東京都'],
      [3, 17, 0, '池袋スカイステージ', '東京都'],
    ],
    recs: [
      {
        key: 'ticket',
        type: 'other',
        name: '特典会 整理券（抽選）',
        start: [-2, 12, 0],
        end: [2, 23, 59],
        result: [3, 10, 0],
        prices: [['整理券（CD 1枚）', 1500]],
      },
    ],
  },
  {
    key: 'blueorbit-tour',
    title: 'BLUE ORBIT ARENA TOUR「ORBIT LINE」',
    groups: ['blueorbit'],
    oshis: [],
    perfs: [
      [50, 18, 0, 'さいたまブルーアリーナ', '埼玉県'],
      [51, 16, 0, 'さいたまブルーアリーナ', '埼玉県'],
      [70, 18, 0, '大阪ミライアリーナ', '大阪府'],
    ],
    recs: [
      {
        key: 'fc',
        type: 'fc',
        name: 'FC最速先行',
        start: [0, 12, 0],
        end: [6, 23, 59],
        result: [10, 18, 0],
        prices: [['指定席', 11000]],
      },
      {
        key: 'general',
        type: 'general',
        name: '一般発売',
        start: [25, 10, 0],
        end: [30, 23, 59],
        result: [33, 18, 0],
        prices: [['指定席', 11000]],
      },
    ],
  },
  {
    key: 'blueorbit-5th',
    title: 'BLUE ORBIT 5th Anniversary Live',
    groups: ['blueorbit'],
    oshis: [],
    perfs: [[-45, 17, 0, '札幌ノースホール', '北海道']],
    recs: [
      {
        key: 'general',
        type: 'general',
        name: '一般発売',
        start: [-90, 10, 0],
        end: [-80, 23, 59],
        result: [-77, 18, 0],
        pay: [-70, 23, 59],
        prices: [['指定席', 9500]],
      },
    ],
  },
  {
    key: 'prism-1st',
    title: 'Prism Voice 1st LIVE「Colorful Harmony」',
    groups: ['prismvoice'],
    oshis: [],
    perfs: [
      [25, 17, 0, '千葉ベイサイドホール', '千葉県'],
      [26, 16, 0, '千葉ベイサイドホール', '千葉県'],
    ],
    recs: [
      {
        key: 'bd',
        type: 'other',
        name: 'BD 封入先行',
        start: [-8, 12, 0],
        end: [-1, 23, 59],
        result: [2, 18, 0],
        pay: [6, 23, 59],
        prices: [['指定席', 8800]],
      },
      {
        key: 'general',
        type: 'general',
        name: '一般発売',
        start: [9, 10, 0],
        end: [15, 23, 59],
        result: [18, 18, 0],
        prices: [['指定席', 8800]],
      },
    ],
  },
  {
    key: 'minato-fanmeeting',
    title: '柊ミナト ファンミーティング 2026',
    groups: [],
    oshis: ['minato'],
    perfs: [
      [18, 14, 0, '名古屋サンライズホール', '愛知県'],
      [18, 18, 0, '名古屋サンライズホール', '愛知県'],
    ],
    recs: [
      {
        key: 'fc',
        type: 'fc',
        name: 'FC先行',
        start: [-1, 12, 0],
        end: [3, 23, 59],
        result: [6, 18, 0],
        prices: [['指定席', 6500]],
      },
    ],
  },
  {
    key: 'midnight-tour',
    title: 'ミッドナイト・トレイン LIVE HOUSE TOUR「終電のあとで」',
    groups: ['midnight'],
    oshis: [],
    perfs: [
      [9, 19, 0, '仙台ラインハウス', '宮城県'],
      [11, 19, 0, '新潟リバーサイド', '新潟県'],
      [16, 19, 0, '東京ネオンホール', '東京都'],
      [23, 19, 0, '福岡ハーバーライブ', '福岡県'],
    ],
    recs: [
      {
        key: 'general',
        type: 'general',
        name: '一般発売（先着）',
        start: [-20, 10, 0],
        end: [8, 23, 59],
        prices: [['スタンディング', 4500]],
      },
    ],
  },
  {
    key: 'midnight-dawn',
    title: 'ミッドナイト・トレイン ワンマン「夜明け前」',
    groups: ['midnight'],
    oshis: [],
    perfs: [[-8, 19, 0, '東京ネオンホール', '東京都']],
    recs: [
      {
        key: 'general',
        type: 'general',
        name: '一般発売',
        start: [-40, 10, 0],
        end: [-30, 23, 59],
        prices: [['スタンディング', 4000]],
      },
    ],
  },
  {
    key: 'neon-3d',
    title: 'ネオンリンク 3Dライブ「Link Start!」',
    groups: ['neonlink'],
    oshis: [],
    perfs: [[35, 20, 0, 'オンライン配信', null]],
    recs: [
      {
        key: 'stream',
        type: 'other',
        name: '配信チケット',
        start: [0, 10, 0],
        end: [35, 20, 0],
        prices: [['配信チケット', 3500]],
      },
    ],
  },
  {
    key: 'reina-swan',
    title: '白鳥レイナ コンサート 2026「Swan Song」',
    groups: [],
    oshis: ['reina'],
    perfs: [[20, 18, 0, '京都ノーブルホール', '京都府']],
    recs: [
      {
        key: 'fc',
        type: 'fc',
        name: 'FC先行',
        start: [-6, 12, 0],
        end: [3, 23, 59],
        result: [7, 18, 0],
        prices: [['S席', 9000]],
      },
      {
        key: 'general',
        type: 'general',
        name: '一般発売',
        start: [10, 10, 0],
        end: [14, 23, 59],
        result: [16, 18, 0],
        prices: [['S席', 9000]],
      },
    ],
  },
  {
    key: 'kanata-acoustic',
    title: '空野カナタ アコースティックライブ「ことのは」',
    groups: [],
    oshis: ['kanata'],
    perfs: [
      [-3, 19, 0, '金沢ことのはホール', '石川県'],
      [14, 19, 0, '高松しおかぜホール', '香川県'],
    ],
    recs: [
      {
        key: 'general',
        type: 'general',
        name: '一般発売',
        start: [-30, 10, 0],
        end: [10, 23, 59],
        prices: [['自由席', 5000]],
      },
    ],
  },
  {
    key: 'voice-parade',
    title: 'VOICE PARADE 2026',
    groups: ['prismvoice'],
    oshis: ['minato'],
    perfs: [[44, 15, 0, '横浜ベイアリーナ', '神奈川県']],
    recs: [
      {
        key: 'pg',
        type: 'other',
        name: 'プレイガイド先行',
        start: [1, 12, 0],
        end: [7, 23, 59],
        result: [11, 18, 0],
        prices: [['指定席', 9900]],
      },
    ],
  },
];

function buildLiveDocs(b, created) {
  const t = ([day, hour, minute]) => at(b, day, hour, minute);
  const audit = {
    createdBy: DEMO_UID,
    createdAt: created,
    updatedBy: DEMO_UID,
    updatedAt: created,
  };
  const docs = [];
  for (const live of LIVES) {
    const lid = liveId(live.key);
    const scope = {
      liveId: lid,
      groupIds: live.groups.map(groupId),
      oshiIds: live.oshis.map(oshiId),
    };
    docs.push({
      path: `lives/${lid}`,
      data: {
        title: live.title,
        groupIds: scope.groupIds,
        oshiIds: scope.oshiIds,
        ...audit,
      },
    });
    live.perfs.forEach(([day, hour, minute, venue, prefecture], i) => {
      const startAt = at(b, day, hour, minute);
      docs.push({
        path: `performances/${perfId(live.key, i + 1)}`,
        data: {
          ...scope,
          startAt,
          // オンライン配信は、開場・都道府県を入れない
          ...(prefecture
            ? { openAt: new Date(startAt.getTime() - 3600000), prefecture }
            : {}),
          venue,
          ...audit,
        },
      });
    });
    for (const r of live.recs) {
      docs.push({
        path: `receptions/${recId(live.key, r.key)}`,
        data: {
          ...scope,
          type: r.type,
          name: r.name,
          ...(r.start ? { applyStartAt: t(r.start) } : {}),
          applyEndAt: t(r.end),
          ...(r.result ? { resultAt: t(r.result) } : {}),
          ...(r.pay ? { paymentDeadline: t(r.pay) } : {}),
          prices: r.prices.map(([seat, amount]) => ({ seat, amount })),
          winnersOnly: r.winnersOnly ?? false,
          ...audit,
        },
      });
    }
  }
  return docs;
}

// ---------------------------------------------------------------
// 変更履歴（ライブ詳細の「変更あり」「追加」の印。直近7日以内）
// ---------------------------------------------------------------

function addChangeHistory(docs, b) {
  const byPath = new Map(docs.map((d) => [d.path, d]));
  const changes = [
    {
      // 入金期限の延長
      path: `receptions/${recId('stella-tour', 'fc')}`,
      field: 'paymentDeadline',
      before: at(b, 6, 23, 59),
      after: at(b, 7, 23, 59),
      changedAt: at(b, -1, 15),
    },
    {
      // 会場名の修正
      path: `performances/${perfId('hoshizora-fest', 2)}`,
      field: 'venue',
      before: '静岡ほしぞら公園',
      after: '静岡ほしぞら公園 特設ステージ',
      changedAt: at(b, -4, 20),
    },
    {
      // 一般発売の前倒し
      path: `receptions/${recId('luminous-oneman', 'general')}`,
      field: 'applyStartAt',
      before: at(b, 2, 10),
      after: at(b, 1, 10),
      changedAt: at(b, -3, 12),
    },
  ];
  changes.forEach((c, i) => {
    const doc = byPath.get(c.path);
    // 本体は「変更後」の値にし、更新者・更新日時を履歴にそろえる
    doc.data[c.field] = c.after;
    doc.data.updatedBy = DEMO_EDITOR;
    doc.data.updatedAt = c.changedAt;
    docs.push({
      path: `${c.path}/history/demo-hist-${i + 1}`,
      data: {
        field: c.field,
        before: c.before,
        after: c.after,
        changedBy: DEMO_EDITOR,
        changedAt: c.changedAt,
      },
    });
  });

  // 名古屋公演は後から追加した（createdAt がライブより後なので「追加」の印が出る）
  const added = byPath.get(`performances/${perfId('stella-tour', 5)}`);
  added.data.createdBy = DEMO_EDITOR;
  added.data.createdAt = at(b, -2, 10);
  added.data.updatedBy = DEMO_EDITOR;
  added.data.updatedAt = at(b, -2, 10);
}

// ---------------------------------------------------------------
// まとめ
// ---------------------------------------------------------------

/**
 * 共通データ（誰がログインしても見える）を、[{ path, data }] の配列で返す。
 * 日時は Date（書き込むときに Timestamp になる）。
 */
export function buildDemoDocs(base) {
  const b = baseMillis(base);
  const created = at(b, -30, 12);
  const docs = [...buildOshiDocs(created), ...buildLiveDocs(b, created)];
  addChangeHistory(docs, b);
  return docs;
}