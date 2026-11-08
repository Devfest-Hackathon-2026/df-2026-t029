/**
 * Gemini の結果を、登録できる形に変えて確かめる（add_L 3.4 の「変換」「捨てるもの」）。
 * 名前をそろえる関数（重なりの判定用）もここに置く。
 */
const {findPrefecture} = require("../prefectures");

const HOUR = 60 * 60 * 1000;
const TWO_YEARS_MS = 2 * 365 * 24 * HOUR;

const MAX_LIVES = 20;
const MAX_PERFORMANCES = 50;
const MAX_RECEPTIONS = 10;
const RECEPTION_TYPES = new Set(["fc", "general", "upgrade", "other"]);

/** 配列にする（配列でなければ空） */
function arrayOf(v) {
  return Array.isArray(v) ? v : [];
}

/** 文字を整える。空・長すぎるときは null */
function cleanText(v, max) {
  if (typeof v !== "string") return null;
  const s = v.trim();
  return s && s.length <= max ? s : null;
}

/** http(s) の URL だけ通す（add_L 3.4） */
function cleanUrl(v) {
  const s = cleanText(v, 500);
  return s && /^https?:\/\//i.test(s) ? s : null;
}

/** X のユーザー名（@ なし）。URL で来ても名前だけにする */
function cleanXAccount(v) {
  const s = cleanText(v, 200);
  if (!s) return null;
  const m = s.match(/(?:x\.com|twitter\.com)\/@?([A-Za-z0-9_]{1,15})/i) ??
    s.match(/^@?([A-Za-z0-9_]{1,15})$/);
  return m ? m[1] : null;
}

/** 日本時間の日付「YYYY-MM-DD」 */
function jstDate(date) {
  return new Date(date.getTime() + 9 * HOUR).toISOString().slice(0, 10);
}

/**
 * 「YYYY-MM-DD」または「YYYY-MM-DDTHH:mm」（日本時間）を Date に。
 * 時刻が無ければ [defaultTime]（[時, 分]）。読めなければ null
 */
function parseJst(v, defaultTime) {
  if (typeof v !== "string") return null;
  const m = v.trim().match(/^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{1,2}):(\d{2}))?/);
  if (!m) return null;
  const [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const [h, mi] = m[4] !== undefined ? [Number(m[4]), Number(m[5])] : defaultTime;
  if (h > 23 || mi > 59) return null;
  const date = new Date(Date.UTC(y, mo - 1, d, h - 9, mi));
  // 2月30日など、ありえない日付を除く
  return jstDate(date) === `${m[1]}-${m[2]}-${m[3]}` ? date : null;
}

/** 「HH:mm」なら「HH:mm」（2桁）に。違えば null */
function cleanTime(v) {
  if (typeof v !== "string") return null;
  const m = v.trim().match(/^(\d{1,2}):(\d{2})$/);
  return m ? `${m[1].padStart(2, "0")}:${m[2]}` : null;
}

/** 都道府県の正式な名前（「東京」→「東京都」）。分からなければ null */
function fullPrefectureName(v) {
  const p = findPrefecture(v);
  if (!p) return null;
  if (p.name === "北海道") return p.name;
  if (p.name === "東京") return "東京都";
  if (p.name === "大阪" || p.name === "京都") return `${p.name}府`;
  return `${p.name}県`;
}

/**
 * 名前をそろえる（add_L 3.4 の重なりの判定）。
 * NFKC → 小文字 → 空白と記号を除く
 */
function normalizeName(v) {
  if (typeof v !== "string") return "";
  return v.normalize("NFKC").toLowerCase()
      .replace(/[\s\p{P}\p{S}ー〜～]/gu, "");
}

/** 公演1件。登録できなければ null */
function normalizePerformance(p, now) {
  const time = cleanTime(p?.startTime);
  if (typeof p?.date !== "string" || !time) return null; // 開演時刻が無い公演は登録しない
  const startAt = parseJst(`${p.date}T${time}`, [0, 0]);
  if (!startAt) return null;
  const ms = startAt.getTime() - now.getTime();
  if (ms < 0 || ms > TWO_YEARS_MS) return null;

  let venue = cleanText(p.venue, 200);
  if (!venue) return null;
  const online = p.online === true;
  // isOnlineVenue（lib/utils/travel_links.dart）は「オンライン」か「配信」を含む会場名で判定する
  if (online && !venue.includes("オンライン") && !venue.includes("配信")) {
    venue = `${venue}（オンライン配信）`.slice(0, 200);
  }

  const open = cleanTime(p.openTime);
  let openAt = open ? parseJst(`${p.date}T${open}`, [0, 0]) : null;
  if (openAt && openAt.getTime() > startAt.getTime()) openAt = null;

  return {
    startAt,
    openAt,
    venue,
    prefecture: online ? null : fullPrefectureName(p.prefecture),
  };
}

/** 受付1件。登録できなければ null */
function normalizeReception(r, now) {
  if (!RECEPTION_TYPES.has(r?.type)) return null;
  const name = cleanText(r.name, 100);
  if (!name) return null;
  const applyEndAt = parseJst(r.applyEndAt, [23, 59]);
  if (!applyEndAt || applyEndAt.getTime() <= now.getTime()) return null;

  const prices = arrayOf(r.prices)
      .map((x) => ({seat: cleanText(x?.seat, 50), amount: x?.amount}))
      .filter((x) => x.seat && Number.isInteger(x.amount) &&
        x.amount > 0 && x.amount < 1000000);

  return {
    type: r.type,
    name,
    applyStartAt: parseJst(r.applyStartAt, [0, 0]),
    applyEndAt,
    resultAt: parseJst(r.resultAt, [0, 0]),
    paymentDeadline: parseJst(r.paymentDeadline, [23, 59]),
    prices,
    winnersOnly: r.winnersOnly === true,
  };
}

/**
 * Gemini の結果（add_L 3.3）を確かめて、登録できる形にする。
 * 公演が1つも残らないライブは捨てる
 */
function normalizeResult(raw, now) {
  const lives = [];
  for (const l of arrayOf(raw?.lives)) {
    if (lives.length >= MAX_LIVES) break;
    const title = cleanText(l?.title, 200);
    if (!title) continue;
    const performances = arrayOf(l.performances)
        .map((p) => normalizePerformance(p, now))
        .filter(Boolean)
        .slice(0, MAX_PERFORMANCES);
    if (performances.length === 0) continue;
    const receptions = arrayOf(l.receptions)
        .map((r) => normalizeReception(r, now))
        .filter(Boolean)
        .slice(0, MAX_RECEPTIONS);
    lives.push({title, officialUrl: cleanUrl(l.officialUrl), performances, receptions});
  }
  return {
    officialUrl: cleanUrl(raw?.officialUrl),
    officialX: cleanXAccount(raw?.officialX),
    schedulePageUrl: cleanUrl(raw?.schedulePageUrl),
    lives,
  };
}

module.exports = {arrayOf, cleanUrl, jstDate, normalizeName, normalizeResult};