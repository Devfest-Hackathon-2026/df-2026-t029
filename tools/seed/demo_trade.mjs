// デモ用データの定義：グッズと、架空のユーザーの交換の投稿（すべて架空）。
// 検索用キー（giveKeys・wantKeys）は、アプリ（lib/utils/trade_keys.dart）と同じ規則で作る。
// 品目・求める対象の表示名（label）も、アプリと同じ形（グッズ名（種類名）・グッズ名（全種類）・メンバー名）。
// 仕様はプロジェクトの「デモ用データの仕様書」5.4〜5.6。

import {
  DEMO_UID,
  GROUPS,
  SOLOS,
  at,
  groupId,
  liveId,
  oshiId,
  perfId,
} from './demo_data.mjs';

export const goodsId = (key) => `demo-goods-${key}`;
export const postId = (key) => `demo-post-${key}`;

// ---------------------------------------------------------------
// 推しの名前・メンバー
// ---------------------------------------------------------------

const memberName = new Map([
  ...GROUPS.flatMap((g) => g.members.map(([key, name]) => [key, name])),
  ...SOLOS.map(([key, name]) => [key, name]),
]);

/** グループのメンバーを、グッズの種類の形（名前とメンバーのキー）にする */
const membersOf = (groupKey) =>
  GROUPS.find((g) => g.key === groupKey).members.map(([key, name]) => ({
    name,
    oshi: key,
  }));

// ---------------------------------------------------------------
// グッズ（13）。種類の ID は v1・v2…の連番。メンバー別の種類には oshiId を入れる
// ---------------------------------------------------------------

const GOODS = [
  {
    key: 'workspace-acsta',
    name: 'Work☆Space TOUR 2026 ランダムアクリルスタンド',
    category: 'acrylic',
    groups: ['workspace'],
    live: 'workspace-tour',
    price: 800,
    variants: membersOf('workspace'),
  },
  {
    key: 'workspace-card',
    name: 'Work☆Space トレーディングカード vol.1',
    category: 'card',
    groups: ['workspace'],
    price: 300,
    variants: [...membersOf('workspace'), { name: 'シークレット' }],
  },
  {
    key: 'workspace-badge',
    name: 'Work☆Space 缶バッジ（会場限定）',
    category: 'badge',
    groups: ['workspace'],
    live: 'workspace-tour',
    price: 500,
    variants: membersOf('workspace'),
  },
  {
    key: 'workspace-photo',
    name: 'Work☆Space 生写真セット「はじまりの受信箱」',
    category: 'photo',
    groups: ['workspace'],
    live: 'workspace-1st',
    price: 1000,
    variants: membersOf('workspace'),
  },
  {
    key: 'maps-keyholder',
    name: 'マップ☆ガイド ランダムアクリルキーホルダー',
    category: 'acrylic',
    groups: ['maps'],
    price: 700,
    variants: membersOf('maps'),
  },
  {
    key: 'maps-photo',
    name: 'マップ☆ガイド リリイベ生写真',
    category: 'photo',
    groups: ['maps'],
    live: 'maps-release',
    price: 500,
    variants: membersOf('maps'),
  },
  {
    key: 'pixel-card',
    name: 'TEAM PIXEL トレーディングカード',
    category: 'card',
    groups: ['pixel'],
    price: 300,
    variants: membersOf('pixel'),
  },
  {
    key: 'pixel-badge',
    name: 'TEAM PIXEL 缶バッジ「SNAPSHOT」',
    category: 'badge',
    groups: ['pixel'],
    live: 'pixel-tour',
    price: 600,
    variants: membersOf('pixel'),
  },
  {
    key: 'okvoices-badge',
    name: 'OK! Voices 缶バッジ',
    category: 'badge',
    groups: ['okvoices'],
    live: 'okvoices-1st',
    price: 500,
    variants: membersOf('okvoices'),
  },
  {
    key: 'okvoices-acsta',
    name: 'OK! Voices アクリルスタンド',
    category: 'acrylic',
    groups: ['okvoices'],
    live: 'okvoices-1st',
    price: 1500,
    variants: membersOf('okvoices'),
  },
  {
    key: 'playlists-keyholder',
    name: 'The Playlists ピック型キーホルダー',
    category: 'other',
    groups: ['playlists'],
    live: 'playlists-tour',
    price: 800,
    variants: membersOf('playlists'),
  },
  {
    key: 'kotoba-bromide',
    name: 'ことばレンズ ブロマイド',
    category: 'photo',
    groups: ['kotoba'],
    live: 'kotoba-3d',
    price: 400,
    variants: membersOf('kotoba'),
  },
  {
    key: 'keep-acsta',
    name: 'キープちゃん アクリルスタンド',
    category: 'acrylic',
    oshis: ['keep'],
    live: 'keep-swan',
    price: 1800,
    variants: [{ name: '通常衣装' }, { name: 'ドレス衣装' }],
  },
];

/** グッズのキー → 種類に ID を付けたグッズ */
const goodsByKey = new Map(
  GOODS.map((g) => [
    g.key,
    { ...g, variants: g.variants.map((v, i) => ({ id: `v${i + 1}`, ...v })) },
  ]),
);

/** グッズの種類を、メンバーのキーか種類の名前で探す */
function variantOf(goodsKey, ref) {
  const g = goodsByKey.get(goodsKey);
  const v = g?.variants.find((x) => x.oshi === ref || x.name === ref);
  if (!v) throw new Error(`グッズの種類が見つかりません: ${goodsKey} ${ref}`);
  return { g, v };
}

function buildGoodsDocs(b) {
  const created = at(b, -25, 12);
  return [...goodsByKey.values()].map((g) => ({
    path: `goods/${goodsId(g.key)}`,
    data: {
      name: g.name,
      category: g.category,
      groupIds: (g.groups ?? []).map(groupId),
      oshiIds: (g.oshis ?? []).map(oshiId),
      ...(g.live ? { liveId: liveId(g.live) } : {}),
      price: g.price,
      variants: g.variants.map((v) => ({
        id: v.id,
        name: v.name,
        ...(v.oshi ? { oshiId: oshiId(v.oshi) } : {}),
      })),
      createdBy: DEMO_UID,
      createdAt: created,
      updatedBy: DEMO_UID,
      updatedAt: created,
    },
  }));
}

// ---------------------------------------------------------------
// 投稿の部品（けんの投稿を作るときにも使う）
// ---------------------------------------------------------------

/** 譲の品目 */
function giveItem(goodsKey, ref) {
  const { g, v } = variantOf(goodsKey, ref);
  return {
    goodsId: goodsId(goodsKey),
    variantId: v.id,
    label: `${g.name}（${v.name}）`,
  };
}

/** 譲セット。refs はメンバーのキーか種類の名前。pick は「この中から N 個」 */
export function give(goodsKey, refs, pick) {
  return {
    items: refs.map((r) => giveItem(goodsKey, r)),
    ...(pick ? { pickCount: pick } : {}),
    images: [],
  };
}

/** 求める対象 */
export const want = {
  item(goodsKey, ref) {
    const { g, v } = variantOf(goodsKey, ref);
    return {
      type: 'item',
      goodsId: goodsId(goodsKey),
      variantId: v.id,
      label: `${g.name}（${v.name}）`,
    };
  },
  goods(goodsKey) {
    return {
      type: 'goods',
      goodsId: goodsId(goodsKey),
      label: `${goodsByKey.get(goodsKey).name}（全種類）`,
    };
  },
  member(oshiKey) {
    return {
      type: 'member',
      oshiId: oshiId(oshiKey),
      label: memberName.get(oshiKey),
    };
  },
};

/** 求セット */
export const wants = (...targets) => ({ targets });

/** 譲の検索用キー（品目・グッズ・メンバー）。重複は除く */
function giveKeysOf(gives) {
  const keys = new Set();
  for (const set of gives) {
    for (const it of set.items) {
      keys.add(`item:${it.goodsId}#${it.variantId}`);
      keys.add(`goods:${it.goodsId}`);
      const g = goodsByKey.get(it.goodsId.slice('demo-goods-'.length));
      const v = g.variants.find((x) => x.id === it.variantId);
      if (v.oshi) keys.add(`member:${oshiId(v.oshi)}`);
    }
  }
  return [...keys];
}

/** 求の検索用キー（対象1つから1つ）。重複は除く */
function wantKeysOf(wantSets) {
  const keys = new Set();
  for (const set of wantSets) {
    for (const t of set.targets) {
      if (t.type === 'item') keys.add(`item:${t.goodsId}#${t.variantId}`);
      else if (t.type === 'goods') keys.add(`goods:${t.goodsId}`);
      else if (t.type === 'member') keys.add(`member:${t.oshiId}`);
    }
  }
  return [...keys];
}

/**
 * 投稿1件のドキュメントを作る。
 * perfs は [ライブのキー, 公演の番号] の配列。upd は更新日時の [日, 時]（基準日からの相対）
 */
export function tradePostDoc(b, p) {
  const updatedAt = at(b, p.upd[0], p.upd[1]);
  const gives = p.gives ?? [];
  const wantSets = p.wants ?? [];
  return {
    path: `tradePosts/${postId(p.id)}`,
    data: {
      uid: p.uid,
      displayName: p.displayName,
      groupIds: (p.groups ?? []).map(groupId),
      oshiIds: (p.oshis ?? []).map(oshiId),
      tags: p.tags,
      ...(p.priceType ? { priceType: p.priceType } : {}),
      gives,
      wants: wantSets,
      giveKeys: giveKeysOf(gives),
      wantKeys: wantKeysOf(wantSets),
      handover: p.hand,
      performanceIds: (p.perfs ?? []).map(([live, n]) => perfId(live, n)),
      ...(p.xAccount ? { xAccount: p.xAccount } : {}),
      ...(p.note ? { note: p.note } : {}),
      images: [],
      status: p.status ?? 'open',
      // 作成は更新の3時間前
      createdAt: new Date(updatedAt.getTime() - 3 * 3600000),
      updatedAt,
    },
  };
}

// ---------------------------------------------------------------
// 架空のユーザー（10人）。users/{uid} は作らない（投稿などに表示名を複製しているため）
// ---------------------------------------------------------------

export const DEMO_USERS = {
  u01: { uid: 'demo-user-01', name: 'めるまる', x: 'merumaru_demo' },
  u02: { uid: 'demo-user-02', name: 'かれんだ', x: 'karenda_demo' },
  u03: { uid: 'demo-user-03', name: 'みどりんご' },
  u04: { uid: 'demo-user-04', name: 'ふみふみ', x: 'fumifumi_demo' },
  u05: { uid: 'demo-user-05', name: 'ピン担' },
  u06: { uid: 'demo-user-06', name: 'ナビ推し', x: 'navi_demo' },
  u07: { uid: 'demo-user-07', name: 'テンソル担' },
  u08: { uid: 'demo-user-08', name: 'ネスト推し', x: 'nest_demo' },
  u09: { uid: 'demo-user-09', name: '夜更かしベース' },
  u10: { uid: 'demo-user-10', name: 'ことれん', x: 'kotoren_demo' },
};

// ---------------------------------------------------------------
// 架空のユーザーの投稿（40件）
// けんの投稿とマッチするのは 01〜03 だけ。ほかの投稿は、メルルのグッズを譲に入れない
// ---------------------------------------------------------------

const NOTE_SOON = '即日発送できます';

const POSTS = [
  // --- Work☆Space（16件） ---
  {
    id: '01',
    u: 'u01',
    groups: ['workspace'],
    tags: ['trade'],
    gives: [give('workspace-acsta', ['gmail'])],
    wants: [wants(want.item('workspace-acsta', 'calendar'))],
    hand: ['mail', 'hand'],
    perfs: [['workspace-tour', 1]],
    note: 'カレンちゃんのアクスタを探しています。ツアー東京1日目なら会場で交換できます',
    upd: [0, 8],
  },
  {
    id: '02',
    u: 'u03',
    groups: ['workspace'],
    tags: ['trade'],
    gives: [give('workspace-acsta', ['gmail'])],
    wants: [wants(want.item('workspace-card', 'drive'))],
    hand: ['mail'],
    upd: [-1, 12],
  },
  {
    id: '03',
    u: 'u04',
    groups: ['workspace'],
    tags: ['trade'],
    gives: [give('workspace-badge', ['gmail'])],
    wants: [wants(want.member('docs'))],
    hand: ['mail'],
    note: 'フミちゃんのグッズなら何でも嬉しいです',
    upd: [-1, 20],
  },
  {
    id: '04',
    u: 'u02',
    groups: ['workspace'],
    tags: ['trade'],
    gives: [give('workspace-card', ['drive', 'docs'], 1)],
    wants: [wants(want.item('workspace-card', 'calendar'))],
    hand: ['mail'],
    note: NOTE_SOON,
    upd: [-1, 21],
  },
  {
    id: '05',
    u: 'u02',
    groups: ['workspace'],
    tags: ['trade'],
    gives: [give('workspace-badge', ['drive'])],
    wants: [wants(want.item('workspace-badge', 'calendar'))],
    hand: ['mail', 'hand'],
    perfs: [['workspace-tour', 1]],
    upd: [-2, 19],
  },
  {
    id: '06',
    u: 'u03',
    groups: ['workspace'],
    tags: ['trade', 'sell'],
    priceType: 'face',
    gives: [give('workspace-photo', ['calendar', 'docs'])],
    wants: [wants(want.item('workspace-photo', 'drive'))],
    hand: ['mail'],
    note: '譲渡は定価＋送料でお願いします',
    upd: [-3, 22],
  },
  {
    id: '07',
    u: 'u03',
    groups: ['workspace'],
    tags: ['trade'],
    gives: [give('workspace-acsta', ['docs'])],
    wants: [wants(want.member('drive'))],
    hand: ['hand'],
    perfs: [['workspace-tour', 1]],
    note: '当日、会場の物販列付近で手渡しできます',
    upd: [0, 7],
  },
  {
    id: '08',
    u: 'u04',
    groups: ['workspace'],
    tags: ['trade'],
    gives: [give('workspace-card', ['calendar', 'drive'], 1)],
    wants: [wants(want.item('workspace-card', 'docs'))],
    hand: ['mail'],
    upd: [-4, 20],
  },
  {
    id: '09',
    u: 'u04',
    groups: ['workspace'],
    tags: ['buy'],
    priceType: 'below',
    wants: [wants(want.item('workspace-acsta', 'docs'))],
    hand: ['mail'],
    note: '定価以下でお譲りいただける方を探しています',
    upd: [-2, 12],
  },
  {
    id: '10',
    u: 'u01',
    groups: ['workspace'],
    tags: ['buy'],
    priceType: 'face',
    wants: [wants(want.item('workspace-card', 'シークレット'))],
    hand: ['mail'],
    upd: [-5, 18],
  },
  {
    id: '11',
    u: 'u05',
    groups: ['workspace', 'maps'],
    tags: ['trade'],
    gives: [give('workspace-card', ['drive'])],
    wants: [wants(want.item('maps-keyholder', 'pin'))],
    hand: ['mail'],
    upd: [-1, 10],
  },
  {
    id: '12',
    u: 'u06',
    groups: ['workspace'],
    tags: ['sell'],
    priceType: 'below',
    gives: [give('workspace-photo', ['drive', 'calendar'])],
    hand: ['mail'],
    note: 'まとめて引き取っていただける方を優先します',
    upd: [-6, 15],
  },
  {
    id: '13',
    u: 'u09',
    groups: ['workspace', 'playlists'],
    tags: ['trade'],
    gives: [give('workspace-badge', ['calendar'])],
    wants: [wants(want.item('playlists-keyholder', 'music'))],
    hand: ['hand'],
    perfs: [['cloud-fest', 1]],
    note: 'クラウドフェスの1日目に、会場で交換できます',
    upd: [-2, 23],
  },
  {
    id: '14',
    u: 'u02',
    groups: ['workspace'],
    tags: ['trade'],
    gives: [give('workspace-acsta', ['drive'])],
    wants: [wants(want.item('workspace-acsta', 'calendar'))],
    hand: ['mail'],
    status: 'closed',
    upd: [-10, 20],
  },
  {
    id: '15',
    u: 'u10',
    groups: ['workspace'],
    tags: ['trade'],
    gives: [give('workspace-card', ['docs'])],
    wants: [wants(want.goods('workspace-badge'))],
    hand: ['mail'],
    upd: [-3, 9],
  },
  {
    id: '16',
    u: 'u08',
    groups: ['workspace'],
    tags: ['trade', 'sell'],
    priceType: 'face',
    gives: [give('workspace-acsta', ['docs', 'drive'], 1)],
    wants: [wants(want.member('calendar'))],
    hand: ['mail', 'hand'],
    perfs: [['workspace-tour', 3]],
    upd: [-4, 13],
  },

  // --- マップ☆ガイド（8件） ---
  {
    id: '17',
    u: 'u05',
    groups: ['maps'],
    tags: ['trade'],
    gives: [give('maps-keyholder', ['route', 'navi'], 1)],
    wants: [wants(want.item('maps-keyholder', 'pin'))],
    hand: ['mail'],
    note: NOTE_SOON,
    upd: [0, 9],
  },
  {
    id: '18',
    u: 'u05',
    groups: ['maps'],
    tags: ['trade'],
    gives: [give('maps-photo', ['route'])],
    wants: [wants(want.item('maps-photo', 'pin'))],
    hand: ['hand'],
    perfs: [['maps-release', 1]],
    note: 'リリイベ当日、会場で交換できます',
    upd: [-1, 18],
  },
  {
    id: '19',
    u: 'u06',
    groups: ['maps'],
    tags: ['trade'],
    gives: [give('maps-keyholder', ['pin', 'route'])],
    wants: [wants(want.item('maps-keyholder', 'navi'))],
    hand: ['mail', 'hand'],
    perfs: [['maps-oneman', 1]],
    upd: [-2, 21],
  },
  {
    id: '20',
    u: 'u06',
    groups: ['maps'],
    tags: ['buy'],
    priceType: 'face',
    wants: [wants(want.item('maps-photo', 'navi'))],
    hand: ['mail'],
    upd: [-3, 11],
  },
  {
    id: '21',
    u: 'u01',
    groups: ['maps'],
    tags: ['trade'],
    gives: [give('maps-keyholder', ['navi'])],
    wants: [wants(want.item('maps-keyholder', 'route'))],
    hand: ['mail'],
    upd: [-5, 22],
  },
  {
    id: '22',
    u: 'u03',
    groups: ['maps'],
    tags: ['sell'],
    priceType: 'face',
    gives: [give('maps-photo', ['pin', 'navi'])],
    hand: ['hand'],
    perfs: [['maps-release', 2]],
    upd: [-1, 8],
  },
  {
    id: '23',
    u: 'u09',
    groups: ['maps'],
    tags: ['trade'],
    gives: [give('maps-keyholder', ['pin'])],
    wants: [wants(want.member('route'))],
    hand: ['mail'],
    upd: [-4, 17],
  },
  {
    id: '24',
    u: 'u05',
    groups: ['maps'],
    tags: ['trade'],
    gives: [give('maps-photo', ['navi'])],
    wants: [wants(want.item('maps-photo', 'pin'))],
    hand: ['mail'],
    status: 'closed',
    upd: [-12, 20],
  },

  // --- TEAM PIXEL（4件） ---
  {
    id: '25',
    u: 'u07',
    groups: ['pixel'],
    tags: ['trade'],
    gives: [give('pixel-card', ['camera', 'eraser'], 1)],
    wants: [wants(want.item('pixel-card', 'tensor'))],
    hand: ['mail'],
    note: NOTE_SOON,
    upd: [0, 11],
  },
  {
    id: '26',
    u: 'u07',
    groups: ['pixel'],
    tags: ['trade', 'sell'],
    priceType: 'below',
    gives: [give('pixel-badge', ['eraser'])],
    wants: [wants(want.item('pixel-badge', 'tensor'))],
    hand: ['mail', 'hand'],
    perfs: [['pixel-tour', 1]],
    upd: [-2, 20],
  },
  {
    id: '27',
    u: 'u10',
    groups: ['pixel'],
    tags: ['trade'],
    gives: [give('pixel-card', ['tensor'])],
    wants: [wants(want.item('pixel-card', 'camera'))],
    hand: ['mail'],
    upd: [-3, 19],
  },
  {
    id: '28',
    u: 'u07',
    groups: ['pixel'],
    tags: ['buy'],
    priceType: 'face',
    wants: [wants(want.item('pixel-badge', 'tensor'))],
    hand: ['mail'],
    upd: [-5, 12],
  },

  // --- OK! Voices（4件） ---
  {
    id: '29',
    u: 'u08',
    groups: ['okvoices'],
    tags: ['trade'],
    gives: [give('okvoices-badge', ['assistant', 'home'], 1)],
    wants: [wants(want.item('okvoices-badge', 'nest'))],
    hand: ['mail'],
    upd: [-1, 22],
  },
  {
    id: '30',
    u: 'u08',
    groups: ['okvoices'],
    tags: ['trade'],
    gives: [give('okvoices-acsta', ['home'])],
    wants: [wants(want.item('okvoices-acsta', 'nest'))],
    hand: ['hand'],
    perfs: [['okvoices-1st', 1]],
    note: '1日目の開演前に、会場付近で手渡しできます',
    upd: [-2, 14],
  },
  {
    id: '31',
    u: 'u02',
    groups: ['okvoices'],
    tags: ['trade'],
    gives: [give('okvoices-badge', ['nest'])],
    wants: [wants(want.item('okvoices-badge', 'assistant'))],
    hand: ['mail'],
    upd: [-4, 21],
  },
  {
    id: '32',
    u: 'u10',
    groups: ['okvoices'],
    tags: ['sell'],
    priceType: 'face',
    gives: [give('okvoices-acsta', ['assistant'])],
    hand: ['mail'],
    upd: [-6, 10],
  },

  // --- The Playlists（3件） ---
  {
    id: '33',
    u: 'u09',
    groups: ['playlists'],
    tags: ['trade'],
    gives: [give('playlists-keyholder', ['play', 'shorts'], 1)],
    wants: [wants(want.item('playlists-keyholder', 'music'))],
    hand: ['mail', 'hand'],
    perfs: [['playlists-tour', 3]],
    upd: [0, 6],
  },
  {
    id: '34',
    u: 'u04',
    groups: ['playlists'],
    tags: ['trade'],
    gives: [give('playlists-keyholder', ['premium'])],
    wants: [wants(want.item('playlists-keyholder', 'play'))],
    hand: ['mail'],
    upd: [-3, 23],
  },
  {
    id: '35',
    u: 'u09',
    groups: ['playlists'],
    tags: ['trade'],
    gives: [give('playlists-keyholder', ['premium'])],
    wants: [wants(want.item('playlists-keyholder', 'music'))],
    hand: ['mail'],
    status: 'closed',
    upd: [-14, 22],
  },

  // --- ことばレンズ（2件） ---
  {
    id: '36',
    u: 'u10',
    groups: ['kotoba'],
    tags: ['trade'],
    gives: [give('kotoba-bromide', ['translate'])],
    wants: [wants(want.item('kotoba-bromide', 'lens'))],
    hand: ['mail'],
    upd: [-1, 13],
  },
  {
    id: '37',
    u: 'u08',
    groups: ['kotoba'],
    tags: ['trade', 'sell'],
    priceType: 'face',
    gives: [give('kotoba-bromide', ['lens'])],
    wants: [wants(want.item('kotoba-bromide', 'translate'))],
    hand: ['mail'],
    upd: [-5, 19],
  },

  // --- キープちゃん（3件） ---
  {
    id: '38',
    u: 'u06',
    oshis: ['keep'],
    tags: ['trade'],
    gives: [give('keep-acsta', ['通常衣装'])],
    wants: [wants(want.item('keep-acsta', 'ドレス衣装'))],
    hand: ['mail', 'hand'],
    perfs: [['keep-swan', 1]],
    upd: [-2, 9],
  },
  {
    id: '39',
    u: 'u01',
    oshis: ['keep'],
    tags: ['buy'],
    priceType: 'below',
    wants: [wants(want.goods('keep-acsta'))],
    hand: ['mail'],
    upd: [-4, 15],
  },
  {
    id: '40',
    u: 'u03',
    oshis: ['keep'],
    tags: ['sell'],
    priceType: 'face',
    gives: [give('keep-acsta', ['ドレス衣装'])],
    hand: ['mail'],
    status: 'closed',
    upd: [-9, 19],
  },
];

// ---------------------------------------------------------------
// まとめ
// ---------------------------------------------------------------

/** グッズと、架空のユーザーの投稿を、[{ path, data }] の配列で返す */
export function buildTradeDocs(base, baseMs) {
  const posts = POSTS.map((p) => {
    const user = DEMO_USERS[p.u];
    return tradePostDoc(baseMs, {
      ...p,
      uid: user.uid,
      displayName: user.name,
      xAccount: user.x,
    });
  });
  return [...buildGoodsDocs(baseMs), ...posts];
}