/**
 * 推しの YouTube の新着を取る（add_P 4.2）。
 * チャンネルを決める → 新着を取る → お知らせに書く → 推しの youtube を更新
 */
const logger = require("firebase-functions/logger");
const {FieldValue} = require("firebase-admin/firestore");
const {resolveChannel, latestVideos} = require("./youtube");
const {writeVideoNews} = require("./news");

const COLLECTION = {group: "groups", person: "oshis"};

/**
 * kind："group" | "person"。
 * 返す形：{status: "ok" | "notFound" | "skipped" | "error", added?}。例外は外に出さない
 */
async function refreshOshiNews(db, kind, id, apiKey) {
  const ref = db.collection(COLLECTION[kind]).doc(id);
  try {
    const snap = await ref.get();
    if (!snap.exists) return {status: "skipped"};
    const data = snap.data();
    const officialYoutube =
      typeof data.officialYoutube === "string" ? data.officialYoutube.trim() : "";
    if (data.status !== "approved" || !officialYoutube) return {status: "skipped"};

    // officialYoutube が変わった・チャンネルが未定なら、決め直す
    const yt = data.youtube ?? {};
    let channelId = yt.channelId;
    let title = yt.title ?? "";
    if (yt.source !== officialYoutube || !channelId) {
      const channel = await resolveChannel(officialYoutube, apiKey);
      if (!channel) {
        await ref.update({
          youtube: {
            source: officialYoutube,
            status: "notFound",
            checkedAt: FieldValue.serverTimestamp(),
          },
        });
        return {status: "notFound"};
      }
      channelId = channel.channelId;
      title = channel.title;
    }

    const videos = await latestVideos(channelId, apiKey);
    const added = await writeVideoNews(
        db, {kind, id, name: String(data.name ?? "")}, videos);

    await ref.update({
      youtube: {
        source: officialYoutube,
        channelId,
        title,
        status: "ok",
        checkedAt: FieldValue.serverTimestamp(),
      },
    });
    if (added > 0) logger.info(`YouTube の新着 ${kind}:${id}: ${added} 件`);
    return {status: "ok", added};
  } catch (e) {
    logger.error(`YouTube の新着の取得に失敗しました ${kind}:${id}`, e);
    await ref.update({
      "youtube.status": "error",
      "youtube.checkedAt": FieldValue.serverTimestamp(),
    }).catch(() => {});
    return {status: "error"};
  }
}

module.exports = {refreshOshiNews};