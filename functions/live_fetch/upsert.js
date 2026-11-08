/**
 * 重なりの判定と書き込み（add_L 3.4）。
 * 既にあるものは書き換えず、無いライブ・公演・受付だけを足す。
 */
const {FieldValue, Timestamp} = require("firebase-admin/firestore");
const {arrayOf, jstDate, normalizeName} = require("./normalize");

/** 1回のバッチの書き込みの上限（500 の手前で止める） */
const MAX_WRITES = 490;

/** Firestore の値を Date に（無ければ null） */
function toDate(v) {
  return v && typeof v.toDate === "function" ? v.toDate() : null;
}

/** 名前が同じ、または片方がもう片方を含む（どちらも minLength 文字以上） */
function nameMatches(a, b, minLength) {
  const x = normalizeName(a);
  const y = normalizeName(b);
  if (!x || !y) return false;
  if (x === y) return true;
  return x.length >= minLength && y.length >= minLength &&
    (x.includes(y) || y.includes(x));
}

/** 同じ公演か（同じ日・会場名が同じか片方を含む） */
function performanceMatches(a, b) {
  return jstDate(a.startAt) === jstDate(b.startAt) &&
    nameMatches(a.venue, b.venue, 1);
}

/** 同じ受付か（同じ種別で、名前が同じか申込期限が同じ分） */
function receptionMatches(a, b) {
  if (a.type !== b.type) return false;
  if (normalizeName(a.name) === normalizeName(b.name)) return true;
  return Boolean(a.applyEndAt && b.applyEndAt) &&
    Math.floor(a.applyEndAt.getTime() / 60000) ===
      Math.floor(b.applyEndAt.getTime() / 60000);
}

/** 同じライブか（名前、または公演が同じ） */
function liveMatches(existing, live) {
  return nameMatches(existing.title, live.title, 6) ||
    existing.performances.some((p) =>
      live.performances.some((q) => performanceMatches(p, q)));
}

/** URL の重なりを除き、空を除いて最大5件 */
function uniqueUrls(list) {
  return [...new Set(list.filter(Boolean))].slice(0, 5);
}

/**
 * 対象の推しの、今あるライブ・公演・受付（比べる相手）。
 * 個人は、所属グループのライブとも比べる（グループで登録済みのツアーを二重に作らない）
 */
async function loadExisting(db, target) {
  const field = target.kind === "group" ? "groupIds" : "oshiIds";
  const groupIds = target.kind === "person" ? target.groupIds.slice(0, 30) : [];

  // コレクションごとに、対象の推しの分と所属グループの分を読んで、重なりを除く
  const load = async (collection) => {
    const queries = [
      db.collection(collection).where(field, "array-contains", target.id).get(),
    ];
    if (groupIds.length > 0) {
      queries.push(db.collection(collection)
          .where("groupIds", "array-contains-any", groupIds).get());
    }
    const byId = new Map();
    for (const snap of await Promise.all(queries)) {
      for (const d of snap.docs) byId.set(d.id, d);
    }
    return [...byId.values()];
  };
  const [liveDocs, perfDocs, recDocs] = await Promise.all([
    load("lives"),
    load("performances"),
    load("receptions"),
  ]);

  const lives = liveDocs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      title: data.title ?? "",
      groupIds: arrayOf(data.groupIds),
      oshiIds: arrayOf(data.oshiIds),
      performances: [],
      receptions: [],
    };
  });
  const byId = new Map(lives.map((l) => [l.id, l]));
  for (const d of perfDocs) {
    const p = d.data();
    const startAt = toDate(p.startAt);
    const live = byId.get(p.liveId);
    if (live && startAt) live.performances.push({startAt, venue: p.venue ?? ""});
  }
  for (const d of recDocs) {
    const r = d.data();
    const live = byId.get(r.liveId);
    if (live) {
      live.receptions.push({type: r.type, name: r.name ?? "", applyEndAt: toDate(r.applyEndAt)});
    }
  }
  return lives;
}

/** 作成者・日時・出典（add_L 3.1） */
function systemFields(sourceUrls) {
  return {
    createdBy: "system",
    createdAt: FieldValue.serverTimestamp(),
    updatedBy: "system",
    updatedAt: FieldValue.serverTimestamp(),
    source: "ai",
    sourceUrls,
  };
}

/** Date があれば Timestamp の項目にする */
function timestampField(name, date) {
  return date ? {[name]: Timestamp.fromDate(date)} : {};
}

/**
 * 登録する（add_L 3.4）。
 * target]：{kind: "group" | "person", id, groupIds}（groupIds は個人の所属グループ）、[result]：normalizeResult の結果。
 * 返り値：{added: {lives, performances, receptions}, lives: [{id, title, isNew}]}
 */
async function upsertLives(db, target, result, searchQueries) {
  const field = target.kind === "group" ? "groupIds" : "oshiIds";
  const existing = await loadExisting(db, target);

  const batch = db.batch();
  let writes = 0;
  const added = {lives: 0, performances: 0, receptions: 0};
  const touched = new Map();

  for (const live of result.lives) {
    if (writes >= MAX_WRITES) break;
    const sourceUrls = uniqueUrls([live.officialUrl, result.schedulePageUrl]);

    let match = existing.find((e) => liveMatches(e, live));
    let isNew = false;
    if (!match) {
      const ref = db.collection("lives").doc();
      match = {
        id: ref.id,
        title: live.title,
        groupIds: field === "groupIds" ? [target.id] : [],
        oshiIds: field === "oshiIds" ? [target.id] : [],
        performances: [],
        receptions: [],
      };
      batch.set(ref, {
        title: live.title,
        groupIds: match.groupIds,
        oshiIds: match.oshiIds,
        ...(live.officialUrl ? {officialUrl: live.officialUrl} : {}),
        ...systemFields(sourceUrls),
        searchQueries,
      });
      existing.push(match);
      writes++;
      added.lives++;
      isNew = true;
    }

    // 公演・受付はライブの出演者を写す（add_L 3.1）
    const ids = {liveId: match.id, groupIds: match.groupIds, oshiIds: match.oshiIds};
    let changed = false;

    for (const p of live.performances) {
      if (writes >= MAX_WRITES) break;
      if (match.performances.some((e) => performanceMatches(e, p))) continue;
      batch.set(db.collection("performances").doc(), {
        ...ids,
        startAt: Timestamp.fromDate(p.startAt),
        ...timestampField("openAt", p.openAt),
        venue: p.venue,
        ...(p.prefecture ? {prefecture: p.prefecture} : {}),
        ...systemFields(sourceUrls),
      });
      match.performances.push(p);
      writes++;
      added.performances++;
      changed = true;
    }

    for (const r of live.receptions) {
      if (writes >= MAX_WRITES) break;
      if (match.receptions.some((e) => receptionMatches(e, r))) continue;
      batch.set(db.collection("receptions").doc(), {
        ...ids,
        type: r.type,
        name: r.name,
        ...timestampField("applyStartAt", r.applyStartAt),
        applyEndAt: Timestamp.fromDate(r.applyEndAt),
        ...timestampField("resultAt", r.resultAt),
        ...timestampField("paymentDeadline", r.paymentDeadline),
        ...(r.prices.length > 0 ? {prices: r.prices} : {}),
        winnersOnly: r.winnersOnly,
        ...systemFields(sourceUrls),
      });
      match.receptions.push(r);
      writes++;
      added.receptions++;
      changed = true;
    }

    if (isNew || changed) touched.set(match.id, {id: match.id, title: match.title, isNew});
  }

  if (writes > 0) await batch.commit();
  return {added, lives: [...touched.values()]};
}

module.exports = {upsertLives};