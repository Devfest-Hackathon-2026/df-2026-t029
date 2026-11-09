/**
 * 公式サイトに YouTube のリンクが無い推しの公式 YouTube を、YouTube の検索で探す（add_P P-2b の B）。
 * 説明欄に「公式サイトのドメイン」か「公式 X」が書いてあり、チャンネル名に推しの名前を含むものだけを
 * 採用する（照合できなければ入れない）。1つの推しにつき7日に1回まで
 */
const logger = require("firebase-functions/logger");
const {FieldValue} = require("firebase-admin/firestore");
const {searchChannelCandidates} = require("./youtube");

const COLLECTION = {group: "groups", person: "oshis"};
const RESEARCH_MS = 7 * 24 * 60 * 60 * 1000;

/** 比べるために、全角半角・大文字小文字・空白と記号をそろえる */
function squash(s) {
  return String(s ?? "").normalize("NFKC").toLowerCase().replace(/[\s\p{P}\p{S}]/gu, "");
}

/** 公式サイト・公式 X と照合できるか */
function isVerified(channel, oshi) {
  const desc = channel.description.toLowerCase();
  const marks = [];
  if (typeof oshi.officialUrl === "string") {
    try {
      marks.push(new URL(oshi.officialUrl).host.replace(/^www\./, "").toLowerCase());
    } catch (e) {
      // 壊れた URL は照合に使わない
    }
  }
  if (typeof oshi.officialX === "string" && oshi.officialX) {
    const x = oshi.officialX.toLowerCase();
    marks.push(`x.com/${x}`, `twitter.com/${x}`);
  }
  const linked = marks.some((m) => desc.includes(m));
  const named = squash(oshi.name) !== "" && squash(channel.title).includes(squash(oshi.name));
  return linked && named;
}

/**
 * 返す形：{status: "found" | "notFound" | "skipped" | "error"}。例外は外に出さない。
 * 見つかれば officialYoutube を書く（onGroupYoutubeChanged などが新着を取る）
 */
async function searchOfficialYoutube(db, kind, id, apiKey) {
  const ref = db.collection(COLLECTION[kind]).doc(id);
  try {
    const snap = await ref.get();
    if (!snap.exists) return {status: "skipped"};
    const data = snap.data();
    if (data.status !== "approved" || data.officialYoutube) return {status: "skipped"};
    // 照合に使うものが無ければ探さない
    if (!data.officialUrl && !data.officialX) return {status: "skipped"};
    const lastMs = data.youtubeSearch?.checkedAt?.toMillis?.() ?? 0;
    if (Date.now() - lastMs < RESEARCH_MS) return {status: "skipped"};

    const candidates = await searchChannelCandidates(String(data.name ?? ""), apiKey);
    const found = candidates
        .filter((c) => isVerified(c, data))
        .sort((a, b) => b.subscribers - a.subscribers)[0];

    const update = {
      youtubeSearch: {
        status: found ? "found" : "notFound",
        checkedAt: FieldValue.serverTimestamp(),
      },
    };
    if (found) update.officialYoutube = found.handle ?? found.channelId;
    await ref.update(update);
    logger.info(`公式 YouTube の検索 ${kind}:${id}: ` +
      (found ? `${update.officialYoutube} を採用` : "照合できる候補なし"));
    return {status: found ? "found" : "notFound"};
  } catch (e) {
    logger.error(`公式 YouTube の検索に失敗しました ${kind}:${id}`, e);
    await ref.update({
      "youtubeSearch.status": "error",
      "youtubeSearch.checkedAt": FieldValue.serverTimestamp(),
    }).catch(() => {});
    return {status: "error"};
  }
}

module.exports = {searchOfficialYoutube};