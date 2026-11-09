/**
 * お知らせ（oshiNews）の書き込み（add_P 3.2）。
 * 同じお知らせを2回書かないよう、ドキュメント ID を決めて、無いものだけ作る
 */
const {FieldValue, Timestamp} = require("firebase-admin/firestore");

const TITLE_MAX = 150;

/** 推しのキー（アプリの oshiColorKey と同じ形：group:xxx・person:xxx） */
function oshiKeyOf(kind, id) {
  return `${kind}:${id}`;
}

/** items：[{docId, data}]。無いものだけを作り、作った件数を返す */
async function writeNews(db, items) {
  if (items.length === 0) return 0;
  const refs = items.map((it) => db.collection("oshiNews").doc(it.docId));
  const snaps = await db.getAll(...refs);
  const batch = db.batch();
  let count = 0;
  snaps.forEach((snap, i) => {
    if (snap.exists) return;
    batch.create(refs[i], {...items[i].data, createdAt: FieldValue.serverTimestamp()});
    count++;
  });
  if (count > 0) await batch.commit();
  return count;
}

/**
 * YouTube の新しい動画のお知らせ。
 * oshi：{kind: "group" | "person", id, name}、videos：youtube.js の latestVideos の結果
 */
function writeVideoNews(db, oshi, videos) {
  return writeNews(db, videos.map((v) => ({
    docId: `${oshi.kind}_${oshi.id}_yt_${v.videoId}`,
    data: {
      oshiKey: oshiKeyOf(oshi.kind, oshi.id),
      oshiName: oshi.name,
      type: "youtube",
      title: v.title.slice(0, TITLE_MAX),
      videoId: v.videoId,
      publishedAt: Timestamp.fromDate(v.publishedAt),
    },
  })));
}

/**
 * 公式サイトから新しく登録されたライブのお知らせ（add_P 4.4）。
 * lives：[{id, title}]
 */
function writeLiveNews(db, oshi, lives) {
  const now = Timestamp.now();
  return writeNews(db, lives.map((l) => ({
    docId: `${oshi.kind}_${oshi.id}_live_${l.id}`,
    data: {
      oshiKey: oshiKeyOf(oshi.kind, oshi.id),
      oshiName: oshi.name,
      type: "live",
      title: String(l.title ?? "").slice(0, TITLE_MAX),
      liveId: l.id,
      publishedAt: now,
    },
  })));
}

module.exports = {writeVideoNews, writeLiveNews};