/**
 * YouTube Data API v3 の呼び出し（add_P 4.1）
 */
const API = "https://www.googleapis.com/youtube/v3";
const TIMEOUT_MS = 15 * 1000;

/** GET して JSON を返す。失敗したら例外 */
async function getJson(path, params, apiKey) {
  const url = new URL(`${API}/${path}`);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, String(v));
  url.searchParams.set("key", apiKey);
  const res = await fetch(url, {signal: AbortSignal.timeout(TIMEOUT_MS)});
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`YouTube Data API ${path}: ${res.status} ${body.slice(0, 200)}`);
  }
  return res.json();
}

/**
 * officialYoutube（@ハンドル か UC で始まるチャンネル ID）からチャンネルを決める。
 * 見つからない・形が違うときは null
 */
async function resolveChannel(officialYoutube, apiKey) {
  const value = String(officialYoutube ?? "").trim();
  let params;
  if (/^UC[\w-]{22}$/.test(value)) {
    params = {id: value};
  } else if (/^@[^\s/?#]{1,100}$/.test(value)) {
    params = {forHandle: value};
  } else {
    return null;
  }
  const json = await getJson("channels", {part: "snippet", ...params}, apiKey);
  const item = json.items?.[0];
  if (!item?.id) return null;
  return {channelId: item.id, title: String(item.snippet?.title ?? "").slice(0, 100)};
}

/**
 * アップロードした動画を新しい順に最大10件。
 * 返す形：[{videoId, title, publishedAt: Date}]
 */
async function latestVideos(channelId, apiKey) {
  // アップロードの再生リストは、チャンネル ID の先頭の UC を UU に変えたもの
  const playlistId = `UU${channelId.slice(2)}`;
  const json = await getJson("playlistItems", {
    part: "snippet,contentDetails",
    playlistId,
    maxResults: 10,
  }, apiKey);

  const videos = [];
  for (const item of json.items ?? []) {
    const s = item.snippet ?? {};
    const videoId = s.resourceId?.videoId;
    const title = String(s.title ?? "").trim();
    const publishedAt = new Date(item.contentDetails?.videoPublishedAt ?? s.publishedAt ?? "");
    if (typeof videoId !== "string" || !videoId) continue;
    if (!title || title === "Private video" || title === "Deleted video") continue;
    if (Number.isNaN(publishedAt.getTime())) continue;
    videos.push({videoId, title, publishedAt});
  }
  return videos;
}


/**
 * 名前でチャンネルを検索し、上位5件の詳しい情報を返す（add_P P-2b の B）。
 * search.list は1回100ユニット、channels.list は1ユニット。
 * 返す形：[{channelId, title, handle, description, subscribers}]
 */
async function searchChannelCandidates(query, apiKey) {
  const json = await getJson("search", {
    part: "snippet",
    type: "channel",
    q: query,
    maxResults: 5,
    regionCode: "JP",
  }, apiKey);
  const ids = (json.items ?? [])
      .map((i) => i.id?.channelId ?? i.snippet?.channelId)
      .filter((x) => typeof x === "string" && x);
  if (ids.length === 0) return [];

  const details = await getJson("channels", {
    part: "snippet,statistics",
    id: ids.join(","),
  }, apiKey);
  return (details.items ?? []).map((c) => ({
    channelId: c.id,
    title: String(c.snippet?.title ?? ""),
    handle: typeof c.snippet?.customUrl === "string" ? c.snippet.customUrl : null,
    description: String(c.snippet?.description ?? ""),
    subscribers: Number(c.statistics?.subscriberCount ?? 0),
  }));
}

module.exports = {resolveChannel, latestVideos, searchChannelCandidates};