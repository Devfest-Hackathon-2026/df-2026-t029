/**
 * ライブ情報の取得を1回行う（add_L 4章の3つの関数から呼ぶ）。
 * 状態の記録（3.2）→ robots.txt・ページの確認（3.6）→ Gemini（3.5）→ 確かめて登録（3.4）
 */
const logger = require("firebase-functions/logger");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {research, structure} = require("./gemini");
const {arrayOf, cleanUrl, jstDate, normalizeResult} = require("./normalize");
const {upsertLives} = require("./upsert");
const {isAllowed, pageHash} = require("./page_check");
const {collectLivePages} = require("./crawl");
const {writeLiveNews} = require("../oshi_news/news");

const MINUTE = 60 * 1000;
/** 手動の取得の間隔・取得中とみなす時間（10分） */
const COOLDOWN_MS = 1 * MINUTE;
/** ページが変わっていなくても取り直す間隔（7日） */
const RECHECK_MS = 7 * 24 * 60 * MINUTE;

/**
 * 取得を始める（トランザクション）。
 * 対象外なら {skip: "skipped"}、取得中・10分以内なら {skip: "busy"}、
 * 始められれば {data}（推しのドキュメントの中身）
 */
function startRun(db, ref, kind, id, mode, now) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists || id.startsWith("demo-")) return {skip: "skipped"};
    const data = snap.data();
    if (data.status !== "approved") return {skip: "skipped"};
    // グループに入っている個人は対象外（ライブはグループで取る。L-4d）
    if (kind === "person" && arrayOf(data.groupIds).length > 0) return {skip: "skipped"};

    const lf = data.liveFetch ?? {};
    const startedMs = lf.startedAt?.toMillis?.() ?? 0;
    const recent = now.getTime() - startedMs < COOLDOWN_MS;
    if (recent && (mode === "manual" || lf.status === "running")) {
      return {skip: "busy"};
    }
    tx.update(ref, {
      "liveFetch.status": "running",
      "liveFetch.startedAt": Timestamp.fromDate(now),
    });
    return {data};
  });
}

/** 終わりの状態を書く（add_L 3.2） */
function finish(ref, status, extra = {}) {
  return ref.update({
    "liveFetch.status": status,
    "liveFetch.finishedAt": Timestamp.now(),
    ...(status === "error" ? {} : {"liveFetch.message": FieldValue.delete()}),
    ...extra,
  });
}

/**
 * 推し1件のライブ情報を取得して登録する。
 * [kind]：group | person、[mode]：manual | approved | daily。
 * 返り値の status：ok・noOfficialSite・blocked・skipped・busy・unchanged（毎日の取得でページが同じ）
 */
async function runLiveFetch(kind, id, {mode}) {
  const db = getFirestore();
  const ref = db.collection(kind === "group" ? "groups" : "oshis").doc(id);
  const now = new Date();

  const start = await startRun(db, ref, kind, id, mode, now);
  if (start.skip) return {status: start.skip};
  const data = start.data;
  const lf = data.liveFetch ?? {};

  try {
    const knownUrl = cleanUrl(data.officialUrl);

    // 公式サイトが分かっていれば、先に robots.txt を確かめる（3.6）
    const firstUrl = cleanUrl(lf.schedulePageUrl) ?? knownUrl;
    if (firstUrl && !(await isAllowed(firstUrl))) {
      await finish(ref, "blocked");
      return {status: "blocked", officialUrl: knownUrl};
    }

    // 毎日の取得：ページが変わっておらず、7日以内なら Gemini を呼ばない（3.6）
    if (mode === "daily" && lf.schedulePageUrl) {
      const hash = await pageHash(lf.schedulePageUrl);
      const lastGeminiMs = lf.lastGeminiAt?.toMillis?.() ?? 0;
      if (hash && hash === lf.pageHash && now.getTime() - lastGeminiMs < RECHECK_MS) {
        await finish(ref, "ok");
        return {status: "unchanged"};
      }
    }

    // Gemini（3.5）
    const today = jstDate(now);
    const target = {
      kind,
      name: data.name ?? "",
      aliases: arrayOf(data.aliases).filter((a) => typeof a === "string"),
      genre: data.genre,
      officialUrl: knownUrl,
    };
    // 公式サイトをたどって、読ませるページを集める（L-4b）
    const startUrls = [knownUrl, cleanUrl(lf.schedulePageUrl)].filter(Boolean);
    const pageUrls = startUrls.length > 0 ? await collectLivePages(startUrls) : [];
    logger.info(`ライブ情報の取得 ${kind}:${id}: 読むページ ${pageUrls.length} 件`);
    const {memo, searchQueries} = await research(target, today, pageUrls);
    const raw = await structure(memo, today);
    const geminiAt = Timestamp.now();
    const result = normalizeResult(raw, now);

    // 確かめ用のログ（L-4b）：調査メモの先頭と、確認の前後の件数
    const rawLives = Array.isArray(raw?.lives) ? raw.lives : [];
    const countPerfs = (lives) =>
      lives.reduce((n, l) => n + (Array.isArray(l?.performances) ? l.performances.length : 0), 0);
    logger.info(`ライブ情報の取得 ${kind}:${id}: 調査メモ`, memo.slice(0, 3000));
    logger.info(`ライブ情報の取得 ${kind}:${id}: Gemini のライブ ${rawLives.length} 件・` +
      `公演 ${countPerfs(rawLives)} 件 → 確認後のライブ ${result.lives.length} 件・` +
      `公演 ${countPerfs(result.lives)} 件`, JSON.stringify(rawLives).slice(0, 3000));

    const officialUrl = knownUrl ?? result.officialUrl;
    if (!officialUrl) {
      await finish(ref, "noOfficialSite", {"liveFetch.lastGeminiAt": geminiAt});
      return {status: "noOfficialSite", searchQueries};
    }

    // 読んだページが robots.txt で禁止なら、結果を捨てる（3.6）
    if (!(await isAllowed(result.schedulePageUrl ?? officialUrl))) {
      await finish(ref, "blocked", {"liveFetch.lastGeminiAt": geminiAt});
      return {status: "blocked", officialUrl, searchQueries};
    }

    // 確かめて登録（3.4）
    const {added, lives} = await upsertLives(
        db, {kind, id, groupIds: arrayOf(data.groupIds)}, result, searchQueries);

    const update = {
      "liveFetch.lastGeminiAt": geminiAt,
      "liveFetch.added": added,
    };
    if (result.schedulePageUrl) {
      update["liveFetch.schedulePageUrl"] = result.schedulePageUrl;
      const hash = await pageHash(result.schedulePageUrl);
      if (hash) update["liveFetch.pageHash"] = hash;
    }
    // 公式サイト・公式 X は空のときだけ入れる（3.2）
    if (!knownUrl && result.officialUrl) update.officialUrl = result.officialUrl;
    if (!data.officialX && result.officialX) update.officialX = result.officialX;
    // 公式 YouTube も空のときだけ（add_P 3.3）。入ると onGroupYoutubeChanged などが新着を取る
    if (!data.officialYoutube && result.officialYoutube) {
      update.officialYoutube = result.officialYoutube;
    }
    await finish(ref, "ok", update);

    // 新しく登録したライブをお知らせに入れる（add_P 4.4）。失敗しても取得は成功として扱う
    const newLives = lives.filter((l) => l.isNew);
    if (newLives.length > 0) {
      await writeLiveNews(db, {kind, id, name: String(data.name ?? "")}, newLives)
          .catch((e) => logger.error(`お知らせの書き込みに失敗しました ${kind}:${id}`, e));
    }

    logger.info(`ライブ情報の取得 ${kind}:${id}（${mode}）: ` +
      `ライブ ${added.lives}・公演 ${added.performances}・受付 ${added.receptions} 件を追加`);
    return {status: "ok", added, lives, officialUrl, searchQueries};
  } catch (e) {
    logger.error(`ライブ情報の取得に失敗しました ${kind}:${id}（${mode}）`, e);
    await finish(ref, "error", {
      "liveFetch.message": String(e?.message ?? e).slice(0, 200),
    }).catch(() => {});
    throw e;
  }
}

module.exports = {runLiveFetch};