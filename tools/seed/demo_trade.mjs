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
    key: 'stella-acsta',
    name: 'ステラノート TOUR 2026 ランダムアクリルスタンド',
    category: 'acrylic',
    groups: ['stellanote'],
    live: 'stella-tour',
    price: 800,
    variants: membersOf('stellanote'),
  },
  {
    key: 'stella-card',
    name: 'ステラノート トレーディングカード vol.1',
    category: 'card',
    groups: ['stellanote'],
    price: 300,
    variants: [...membersOf('stellanote'), { name: 'シークレット' }],
  },
  {
    key: 'stella-badge',
    name: 'ステラノート 缶バッジ（会場限定）',
    category: 'badge',
    groups: ['stellanote'],
    live: 'stella-tour',
    price: 500,
    variants: membersOf('stellanote'),
  },
  {
    key: 'stella-photo',
    name: 'ステラノート 生写真セット「はじまりの夜」',
    category: 'photo',
    groups: ['stellanote'],
    live: 'stella-1st',
    price: 1000,
    variants: membersOf('stellanote'),
  },
  {
    key: 'luminous-keyholder',
    name: 'ルミナス☆ガーデン ランダムアクリルキーホルダー',
    category: 'acrylic',
    groups: ['luminous'],
    price: 700,
    variants: membersOf('luminous'),
  },
  {
    key: 'luminous-photo',
    name: 'ルミナス☆ガーデン リリイベ生写真',
    category: 'photo',
    groups: ['luminous'],
    live: 'luminous-release',
    price: 500,
    variants: membersOf('luminous'),
  },
  {
    key: 'blueorbit-card',
    name: 'BLUE ORBIT トレーディングカード',
    category: 'card',
    groups: ['blueorbit'],
    price: 300,
    variants: membersOf('blueorbit'),
  },
  {
    key: 'blueorbit-badge',
    name: 'BLUE ORBIT 缶バッジ「ORBIT LINE」',
    category: 'badge',
    groups: ['blueorbit'],
    live: 'blueorbit-tour',
    price: 600,
    variants: membersOf('blueorbit'),
  },
  {
    key: 'prism-badge',
    name: 'Prism Voice 缶バッジ',
    category: 'badge',
    groups: ['prismvoice'],
    live: 'prism-1st',
    price: 500,
    variants: membersOf('prismvoice'),
  },
  {
    key: 'prism-acsta',
    name: 'Prism Voice アクリルスタンド',
    category: 'acrylic',
    groups: ['prismvoice'],
    live: 'prism-1st',
    price: 1500,
    variants: membersOf('prismvoice'),
  },
  {
    key: 'midnight-keyholder',
    name: 'ミッドナイト・トレイン ピック型キーホルダー',
    category: 'other',
    groups: ['midnight'],
    live: 'midnight-tour',
    price: 800,
    variants: membersOf('midnight'),
  },
  {
    key: 'neon-bromide',
    name: 'ネオンリンク ブロマイド',
    category: 'photo',
    groups: ['neonlink'],
    live: 'neon-3d',
    price: 400,
    variants: membersOf('neonlink'),
  },
  {
    key: 'reina-acsta',
    name: '白鳥レイナ アクリルスタンド',
    category: 'acrylic',
    oshis: ['reina'],
    live: 'reina-swan',
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
  u01: { uid: 'demo-user-01', name: 'るなまる', x: 'lunamaru_demo' },
  u02: { uid: 'demo-user-02', name: 'そらいろ', x: 'sorairo_demo' },
  u03: { uid: 'demo-user-03', name: 'ひかりんご' },
  u04: { uid: 'demo-user-04', name: 'みおみお', x: 'miomio_demo' },
  u05: { uid: 'demo-user-05', name: 'モモ担' },
  u06: { uid: 'demo-user-06', name: 'つばさ推し', x: 'tsubasa_demo' },
  u07: { uid: 'demo-user-07', name: 'はると担' },
  u08: { uid: 'demo-user-08', name: 'しずく推し', x: 'shizuku_demo' },
  u09: { uid: 'demo-user-09', name: '夜更かしベース' },
  u10: { uid: 'demo-user-10', name: 'ねおん', x: 'neon_demo' },
};

// ---------------------------------------------------------------
// 架空のユーザーの投稿（40件）
// けんの投稿とマッチするのは 01〜03 だけ。ほかの投稿は、星宮ルナのグッズを譲に入れない
// ---------------------------------------------------------------

const NOTE_SOON = '即日発送できます';

const POSTS = [
  // --- ステラノート（16件） ---
  {
    id: '01',
    u: 'u01',
    groups: ['stellanote'],
    tags: ['trade'],
    gives: [give('stella-acsta', ['luna'])],
    wants: [wants(want.item('stella-acsta', 'sora'))],
    hand: ['mail', 'hand'],
    perfs: [['stella-tour', 1]],
    note: 'ソラちゃんのアクスタを探しています。ツアー東京1日目なら会場で交換できます',
    upd: [0, 8],
  },
  {
    id: '02',
    u: 'u03',
    groups: ['stellanote'],
    tags: ['trade'],
    gives: [give('stella-acsta', ['luna'])],
    wants: [wants(want.item('stella-card', 'hikari'))],
    hand: ['mail'],
    upd: [-1, 12],
  },
  {
    id: '03',
    u: 'u04',
    groups: ['stellanote'],
    tags: ['trade'],
    gives: [give('stella-badge', ['luna'])],
    wants: [wants(want.member('mio'))],
    hand: ['mail'],
    note: 'ミオちゃんのグッズなら何でも嬉しいです',
    upd: [-1, 20],
  },
  {
    id: '04',
    u: 'u02',
    groups: ['stellanote'],
    tags: ['trade'],
    gives: [give('stella-card', ['hikari', 'mio'], 1)],
    wants: [wants(want.item('stella-card', 'sora'))],
    hand: ['mail'],
    note: NOTE_SOON,
    upd: [-1, 21],
  },
  {
    id: '05',
    u: 'u02',
    groups: ['stellanote'],
    tags: ['trade'],
    gives: [give('stella-badge', ['hikari'])],
    wants: [wants(want.item('stella-badge', 'sora'))],
    hand: ['mail', 'hand'],
    perfs: [['stella-tour', 1]],
    upd: [-2, 19],
  },
  {
    id: '06',
    u: 'u03',
    groups: ['stellanote'],
    tags: ['trade', 'sell'],
    priceType: 'face',
    gives: [give('stella-photo', ['sora', 'mio'])],
    wants: [wants(want.item('stella-photo', 'hikari'))],
    hand: ['mail'],
    note: '譲渡は定価＋送料でお願いします',
    upd: [-3, 22],
  },
  {
    id: '07',
    u: 'u03',
    groups: ['stellanote'],
    tags: ['trade'],
    gives: [give('stella-acsta', ['mio'])],
    wants: [wants(want.member('hikari'))],
    hand: ['hand'],
    perfs: [['stella-tour', 1]],
    note: '当日、会場の物販列付近で手渡しできます',
    upd: [0, 7],
  },
  {
    id: '08',
    u: 'u04',
    groups: ['stellanote'],
    tags: ['trade'],
    gives: [give('stella-card', ['sora', 'hikari'], 1)],
    wants: [wants(want.item('stella-card', 'mio'))],
    hand: ['mail'],
    upd: [-4, 20],
  },
  {
    id: '09',
    u: 'u04',
    groups: ['stellanote'],
    tags: ['buy'],
    priceType: 'below',
    wants: [wants(want.item('stella-acsta', 'mio'))],
    hand: ['mail'],
    note: '定価以下でお譲りいただける方を探しています',
    upd: [-2, 12],
  },
  {
    id: '10',
    u: 'u01',
    groups: ['stellanote'],
    tags: ['buy'],
    priceType: 'face',
    wants: [wants(want.item('stella-card', 'シークレット'))],
    hand: ['mail'],
    upd: [-5, 18],
  },
  {
    id: '11',
    u: 'u05',
    groups: ['stellanote', 'luminous'],
    tags: ['trade'],
    gives: [give('stella-card', ['hikari'])],
    wants: [wants(want.item('luminous-keyholder', 'momo'))],
    hand: ['mail'],
    upd: [-1, 10],
  },
  {
    id: '12',
    u: 'u06',
    groups: ['stellanote'],
    tags: ['sell'],
    priceType: 'below',
    gives: [give('stella-photo', ['hikari', 'sora'])],
    hand: ['mail'],
    note: 'まとめて引き取っていただける方を優先します',
    upd: [-6, 15],
  },
  {
    id: '13',
    u: 'u09',
    groups: ['stellanote', 'midnight'],
    tags: ['trade'],
    gives: [give('stella-badge', ['sora'])],
    wants: [wants(want.item('midnight-keyholder', 'yuki'))],
    hand: ['hand'],
    perfs: [['hoshizora-fest', 1]],
    note: 'ほしぞらフェスの1日目に、会場で交換できます',
    upd: [-2, 23],
  },
  {
    id: '14',
    u: 'u02',
    groups: ['stellanote'],
    tags: ['trade'],
    gives: [give('stella-acsta', ['hikari'])],
    wants: [wants(want.item('stella-acsta', 'sora'))],
    hand: ['mail'],
    status: 'closed',
    upd: [-10, 20],
  },
  {
    id: '15',
    u: 'u10',
    groups: ['stellanote'],
    tags: ['trade'],
    gives: [give('stella-card', ['mio'])],
    wants: [wants(want.goods('stella-badge'))],
    hand: ['mail'],
    upd: [-3, 9],
  },
  {
    id: '16',
    u: 'u08',
    groups: ['stellanote'],
    tags: ['trade', 'sell'],
    priceType: 'face',
    gives: [give('stella-acsta', ['mio', 'hikari'], 1)],
    wants: [wants(want.member('sora'))],
    hand: ['mail', 'hand'],
    perfs: [['stella-tour', 3]],
    upd: [-4, 13],
  },

  // --- ルミナス☆ガーデン（8件） ---
  {
    id: '17',
    u: 'u05',
    groups: ['luminous'],
    tags: ['trade'],
    gives: [give('luminous-keyholder', ['rin', 'tsubasa'], 1)],
    wants: [wants(want.item('luminous-keyholder', 'momo'))],
    hand: ['mail'],
    note: NOTE_SOON,
    upd: [0, 9],
  },
  {
    id: '18',
    u: 'u05',
    groups: ['luminous'],
    tags: ['trade'],
    gives: [give('luminous-photo', ['rin'])],
    wants: [wants(want.item('luminous-photo', 'momo'))],
    hand: ['hand'],
    perfs: [['luminous-release', 1]],
    note: 'リリイベ当日、会場で交換できます',
    upd: [-1, 18],
  },
  {
    id: '19',
    u: 'u06',
    groups: ['luminous'],
    tags: ['trade'],
    gives: [give('luminous-keyholder', ['momo', 'rin'])],
    wants: [wants(want.item('luminous-keyholder', 'tsubasa'))],
    hand: ['mail', 'hand'],
    perfs: [['luminous-oneman', 1]],
    upd: [-2, 21],
  },
  {
    id: '20',
    u: 'u06',
    groups: ['luminous'],
    tags: ['buy'],
    priceType: 'face',
    wants: [wants(want.item('luminous-photo', 'tsubasa'))],
    hand: ['mail'],
    upd: [-3, 11],
  },
  {
    id: '21',
    u: 'u01',
    groups: ['luminous'],
    tags: ['trade'],
    gives: [give('luminous-keyholder', ['tsubasa'])],
    wants: [wants(want.item('luminous-keyholder', 'rin'))],
    hand: ['mail'],
    upd: [-5, 22],
  },
  {
    id: '22',
    u: 'u03',
    groups: ['luminous'],
    tags: ['sell'],
    priceType: 'face',
    gives: [give('luminous-photo', ['momo', 'tsubasa'])],
    hand: ['hand'],
    perfs: [['luminous-release', 2]],
    upd: [-1, 8],
  },
  {
    id: '23',
    u: 'u09',
    groups: ['luminous'],
    tags: ['trade'],
    gives: [give('luminous-keyholder', ['momo'])],
    wants: [wants(want.member('rin'))],
    hand: ['mail'],
    upd: [-4, 17],
  },
  {
    id: '24',
    u: 'u05',
    groups: ['luminous'],
    tags: ['trade'],
    gives: [give('luminous-photo', ['tsubasa'])],
    wants: [wants(want.item('luminous-photo', 'momo'))],
    hand: ['mail'],
    status: 'closed',
    upd: [-12, 20],
  },

  // --- BLUE ORBIT（4件） ---
  {
    id: '25',
    u: 'u07',
    groups: ['blueorbit'],
    tags: ['trade'],
    gives: [give('blueorbit-card', ['ren', 'yu'], 1)],
    wants: [wants(want.item('blueorbit-card', 'haruto'))],
    hand: ['mail'],
    note: NOTE_SOON,
    upd: [0, 11],
  },
  {
    id: '26',
    u: 'u07',
    groups: ['blueorbit'],
    tags: ['trade', 'sell'],
    priceType: 'below',
    gives: [give('blueorbit-badge', ['yu'])],
    wants: [wants(want.item('blueorbit-badge', 'haruto'))],
    hand: ['mail', 'hand'],
    perfs: [['blueorbit-tour', 1]],
    upd: [-2, 20],
  },
  {
    id: '27',
    u: 'u10',
    groups: ['blueorbit'],
    tags: ['trade'],
    gives: [give('blueorbit-card', ['haruto'])],
    wants: [wants(want.item('blueorbit-card', 'ren'))],
    hand: ['mail'],
    upd: [-3, 19],
  },
  {
    id: '28',
    u: 'u07',
    groups: ['blueorbit'],
    tags: ['buy'],
    priceType: 'face',
    wants: [wants(want.item('blueorbit-badge', 'haruto'))],
    hand: ['mail'],
    upd: [-5, 12],
  },

  // --- Prism Voice（4件） ---
  {
    id: '29',
    u: 'u08',
    groups: ['prismvoice'],
    tags: ['trade'],
    gives: [give('prism-badge', ['yui', 'nana'], 1)],
    wants: [wants(want.item('prism-badge', 'shizuku'))],
    hand: ['mail'],
    upd: [-1, 22],
  },
  {
    id: '30',
    u: 'u08',
    groups: ['prismvoice'],
    tags: ['trade'],
    gives: [give('prism-acsta', ['nana'])],
    wants: [wants(want.item('prism-acsta', 'shizuku'))],
    hand: ['hand'],
    perfs: [['prism-1st', 1]],
    note: '1日目の開演前に、会場付近で手渡しできます',
    upd: [-2, 14],
  },
  {
    id: '31',
    u: 'u02',
    groups: ['prismvoice'],
    tags: ['trade'],
    gives: [give('prism-badge', ['shizuku'])],
    wants: [wants(want.item('prism-badge', 'yui'))],
    hand: ['mail'],
    upd: [-4, 21],
  },
  {
    id: '32',
    u: 'u10',
    groups: ['prismvoice'],
    tags: ['sell'],
    priceType: 'face',
    gives: [give('prism-acsta', ['yui'])],
    hand: ['mail'],
    upd: [-6, 10],
  },

  // --- ミッドナイト・トレイン（3件） ---
  {
    id: '33',
    u: 'u09',
    groups: ['midnight'],
    tags: ['trade'],
    gives: [give('midnight-keyholder', ['kai', 'jin'], 1)],
    wants: [wants(want.item('midnight-keyholder', 'yuki'))],
    hand: ['mail', 'hand'],
    perfs: [['midnight-tour', 3]],
    upd: [0, 6],
  },
  {
    id: '34',
    u: 'u04',
    groups: ['midnight'],
    tags: ['trade'],
    gives: [give('midnight-keyholder', ['takumi'])],
    wants: [wants(want.item('midnight-keyholder', 'kai'))],
    hand: ['mail'],
    upd: [-3, 23],
  },
  {
    id: '35',
    u: 'u09',
    groups: ['midnight'],
    tags: ['trade'],
    gives: [give('midnight-keyholder', ['takumi'])],
    wants: [wants(want.item('midnight-keyholder', 'yuki'))],
    hand: ['mail'],
    status: 'closed',
    upd: [-14, 22],
  },

  // --- ネオンリンク（2件） ---
  {
    id: '36',
    u: 'u10',
    groups: ['neonlink'],
    tags: ['trade'],
    gives: [give('neon-bromide', ['ao'])],
    wants: [wants(want.item('neon-bromide', 'milk'))],
    hand: ['mail'],
    upd: [-1, 13],
  },
  {
    id: '37',
    u: 'u08',
    groups: ['neonlink'],
    tags: ['trade', 'sell'],
    priceType: 'face',
    gives: [give('neon-bromide', ['milk'])],
    wants: [wants(want.item('neon-bromide', 'ao'))],
    hand: ['mail'],
    upd: [-5, 19],
  },

  // --- 白鳥レイナ（3件） ---
  {
    id: '38',
    u: 'u06',
    oshis: ['reina'],
    tags: ['trade'],
    gives: [give('reina-acsta', ['通常衣装'])],
    wants: [wants(want.item('reina-acsta', 'ドレス衣装'))],
    hand: ['mail', 'hand'],
    perfs: [['reina-swan', 1]],
    upd: [-2, 9],
  },
  {
    id: '39',
    u: 'u01',
    oshis: ['reina'],
    tags: ['buy'],
    priceType: 'below',
    wants: [wants(want.goods('reina-acsta'))],
    hand: ['mail'],
    upd: [-4, 15],
  },
  {
    id: '40',
    u: 'u03',
    oshis: ['reina'],
    tags: ['sell'],
    priceType: 'face',
    gives: [give('reina-acsta', ['ドレス衣装'])],
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