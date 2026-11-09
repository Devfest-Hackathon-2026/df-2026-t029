/**
 * 公式 YouTube の無い個人（グループのメンバーなど）の動画を、YouTube の検索で探す（fix_Ff 6.2）。
 * 検索の語は「"名前" 所属グループの名前」。結果は oshiVideoSearch/person_{id} に24時間覚え、
 * その間は API を呼ばない（search.list は1回100ユニット）。アプリはこのコレクションを読まない
 */
const {FieldValue} = require("firebase-admin/firestore");

const API = "https://www.googleapis.com/youtube/v3/search";
const CACHE_MS = 24 * 60 * 60 * 1000;
const TIMEOUT_MS = 15 * 1000;

/** search.list のタイトルは HTML の文字参照で返るので戻す */
function decode(s) {
  return String(s ?? "")
      .replace(/&#39;/g, "'")
      .replace(/&quot;/g, "\"")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&amp;/g, "&");
}

/**
 * 返す形：{status: "ok" | "skipped", query, videos: [{videoId, title, channelTitle, publishedAt}]}
 * API の失敗は例外（呼び出し側で internal にする）
 */
async function searchPersonVideos(db, id, apiKey) {
  const snap = await db.collection("oshis").doc(id).get();
  if (!snap.exists || snap.data().status !== "approved") {
    return {status: "skipped", query: "", videos: []};
  }
  const data = snap.data();

  // 24時間以内に調べていれば、それを返す
  const cacheRef = db.collection("oshiVideoSearch").doc(`person_${id}`);
  const cache = await cacheRef.get();
  const fetchedMs = cache.data()?.fetchedAt?.toMillis?.() ?? 0;
  if (cache.exists && Date.now() - fetchedMs < CACHE_MS) {
    return {
      status: "ok",
      query: cache.data().query ?? "",
      videos: Array.isArray(cache.data().videos) ? cache.data().videos : [],
    };
  }

  // 所属グループの名前（同じ名前の別人を避けるため）
  const groupNames = [];
  const groupIds = Array.isArray(data.groupIds) ? data.groupIds : [];
  for (const gid of groupIds.slice(0, 3)) {
    if (typeof gid !== "string" || !gid) continue;
    const g = await db.collection("groups").doc(gid).get();
    if (g.exists && typeof g.data().name === "string") groupNames.push(g.data().name);
  }
  const query = [`"${String(data.name ?? "")}"`, ...groupNames].join(" ");

  const url = new URL(API);
  const params = {
    part: "snippet",
    type: "video",
    q: query,
    maxResults: 6,
    regionCode: "JP",
    relevanceLanguage: "ja",
    key: apiKey,
  };
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, String(v));
  const res = await fetch(url, {signal: AbortSignal.timeout(TIMEOUT_MS)});
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`YouTube Data API search: ${res.status} ${body.slice(0, 200)}`);
  }
  const json = await res.json();

  const videos = [];
  for (const item of json.items ?? []) {
    const videoId = item.id?.videoId;
    const s = item.snippet ?? {};
    if (typeof videoId !== "string" || !videoId) continue;
    videos.push({
      videoId,
      title: decode(s.title).slice(0, 150),
      channelTitle: decode(s.channelTitle).slice(0, 100),
      publishedAt: String(s.publishedAt ?? ""),
    });
  }

  await cacheRef.set({query, videos, fetchedAt: FieldValue.serverTimestamp()});
  return {status: "ok", query, videos};
}

module.exports = {searchPersonVideos};