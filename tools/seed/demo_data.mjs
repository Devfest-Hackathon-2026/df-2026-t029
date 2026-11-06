// デモ用データの定義（すべて架空。実在の人物・団体・作品とは関係がありません）。
// 日時は「基準日（日本時間）」からの相対で決める。
// ドキュメント ID は demo- で始まる固定の値（何度実行しても同じ内容に上書きされる）。
// アプリのルール（firestore.rules）の hasOnly に無い項目は足さない。

export const DEMO_PREFIX = 'demo-';
export const DEMO_UID = 'demo-seed'; // createdBy / updatedBy に入れる架空の uid

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

/** 基準日の「いま」（日本時間の 12:00）から hours 時間後 */
export function hoursFromNoon(baseMs, hours) {
  return new Date(baseMs + 12 * 3600000 + hours * 3600000);
}

/**
 * 定義を返す。日時は Date（書き込むときに Timestamp になる）。
 * audit は createdBy・createdAt・updatedBy・updatedAt。
 */
export function buildDemoData(base) {
  const b = baseMillis(base);
  const created = at(b, -30, 12);
  const audit = {
    createdBy: DEMO_UID,
    createdAt: created,
    updatedBy: DEMO_UID,
    updatedAt: created,
  };
  const oshiBase = {
    status: 'approved',
    createdBy: DEMO_UID,
    createdAt: created,
  };

  const groupId = 'demo-group-stellanote';
  const groups = {
    [groupId]: {
      name: 'ステラノート',
      aliases: ['ステラ', 'STELLA NOTE'],
      genre: 'idol',
      ...oshiBase,
    },
  };

  const oshis = {
    'demo-oshi-luna': {
      name: '星宮ルナ',
      aliases: ['ルナ'],
      genre: 'idol',
      groupIds: [groupId],
      ...oshiBase,
    },
    'demo-oshi-sora': {
      name: '月城ソラ',
      aliases: ['ソラ'],
      genre: 'idol',
      groupIds: [groupId],
      ...oshiBase,
    },
    'demo-oshi-hikari': {
      name: '陽野ヒカリ',
      aliases: ['ヒカリ'],
      genre: 'idol',
      groupIds: [groupId],
      ...oshiBase,
    },
    'demo-oshi-kanata': {
      name: '空野カナタ',
      aliases: ['カナタ'],
      genre: 'artist',
      groupIds: [],
      ...oshiBase,
    },
  };

  const tourId = 'demo-live-tour';
  const festId = 'demo-live-fest';
  const pastId = 'demo-live-past';
  const lives = {
    [tourId]: {
      title: 'ステラノート 全国ツアー 2026「ひかりの旋律」',
      groupIds: [groupId],
      oshiIds: [],
      ...audit,
    },
    [festId]: {
      title: 'ほしぞらフェス 2026',
      groupIds: [groupId],
      oshiIds: ['demo-oshi-kanata'],
      ...audit,
    },
    [pastId]: {
      title: 'ステラノート 1st ライブ「はじまりの夜」',
      groupIds: [groupId],
      oshiIds: [],
      ...audit,
    },
  };

  const tourScope = { liveId: tourId, groupIds: [groupId], oshiIds: [] };
  const festScope = {
    liveId: festId,
    groupIds: [groupId],
    oshiIds: ['demo-oshi-kanata'],
  };
  const pastScope = { liveId: pastId, groupIds: [groupId], oshiIds: [] };

  const performances = {
    'demo-perf-tour-1': {
      ...tourScope,
      startAt: at(b, 40, 18),
      openAt: at(b, 40, 17),
      venue: '東京ドリームホール',
      prefecture: '東京都',
      ...audit,
    },
    'demo-perf-tour-2': {
      ...tourScope,
      startAt: at(b, 47, 17),
      openAt: at(b, 47, 16),
      venue: '大阪ミライアリーナ',
      prefecture: '大阪府',
      ...audit,
    },
    'demo-perf-tour-3': {
      ...tourScope,
      startAt: at(b, 54, 17, 30),
      venue: '福岡ベイホール',
      prefecture: '福岡県',
      ...audit,
    },
    'demo-perf-fest-1': {
      ...festScope,
      startAt: at(b, 30, 12),
      openAt: at(b, 30, 10, 30),
      venue: '静岡ほしぞら公園 特設ステージ',
      prefecture: '静岡県',
      ...audit,
    },
    'demo-perf-past-1': {
      ...pastScope,
      startAt: at(b, -20, 18),
      openAt: at(b, -20, 17),
      venue: '横浜ハーバーホール',
      prefecture: '神奈川県',
      ...audit,
    },
  };

  const receptions = {
    // 申込期限が近い（基準日の2日後 23:59）
    'demo-rec-tour-fc': {
      ...tourScope,
      type: 'fc',
      name: 'FC 先行（抽選）',
      applyStartAt: at(b, -5, 12),
      applyEndAt: at(b, 2, 23, 59),
      resultAt: at(b, 6, 18),
      paymentDeadline: at(b, 9, 23, 59),
      prices: [
        { seat: 'S席', amount: 12000 },
        { seat: 'A席', amount: 9800 },
      ],
      winnersOnly: false,
      ...audit,
    },
    // 申込開始前
    'demo-rec-tour-general': {
      ...tourScope,
      type: 'general',
      name: '一般発売',
      applyStartAt: at(b, 12, 10),
      applyEndAt: at(b, 19, 23, 59),
      resultAt: at(b, 22, 18),
      prices: [{ seat: '指定席', amount: 9800 }],
      winnersOnly: false,
      ...audit,
    },
    // アプグレ（当選者のみ）。入金期限が近い（基準日の当日 17:00）
    'demo-rec-tour-upgrade': {
      ...tourScope,
      type: 'upgrade',
      name: 'アップグレード（当選者のみ）',
      applyStartAt: at(b, -3, 12),
      applyEndAt: at(b, 1, 23, 59),
      resultAt: at(b, 3, 18),
      paymentDeadline: hoursFromNoon(b, 5),
      prices: [{ seat: 'VIP席への差額', amount: 8000 }],
      winnersOnly: true,
      ...audit,
    },
    // すでに当落が出た受付
    'demo-rec-fest-first': {
      ...festScope,
      type: 'other',
      name: 'プレイガイド先行',
      applyStartAt: at(b, -14, 12),
      applyEndAt: at(b, -7, 23, 59),
      resultAt: at(b, -3, 18),
      paymentDeadline: at(b, 4, 23, 59),
      prices: [{ seat: '自由席', amount: 7500 }],
      winnersOnly: false,
      ...audit,
    },
    'demo-rec-past-general': {
      ...pastScope,
      type: 'general',
      name: '一般発売',
      applyStartAt: at(b, -60, 10),
      applyEndAt: at(b, -50, 23, 59),
      resultAt: at(b, -47, 18),
      paymentDeadline: at(b, -40, 23, 59),
      prices: [{ seat: '指定席', amount: 6800 }],
      winnersOnly: false,
      ...audit,
    },
  };

  return { groups, oshis, lives, performances, receptions };
}

/** コレクション名 → 定義の対応（書く順・消す順に使う） */
export function collectionsOf(data) {
  return [
    ['groups', data.groups],
    ['oshis', data.oshis],
    ['lives', data.lives],
    ['performances', data.performances],
    ['receptions', data.receptions],
  ];
}
