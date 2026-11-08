/**
 * robots.txt とページの確認（add_L 3.6）
 */
const crypto = require("crypto");
const robotsParser = require("robots-parser");

const USER_AGENT = "OshiashiBot/1.0";
const ROBOTS_AGENT = "OshiashiBot";
const TIMEOUT_MS = 15000;

/** ユーザーエージェントとタイムアウトを付けて取得する */
function get(url) {
  return fetch(url, {
    headers: {"User-Agent": USER_AGENT},
    redirect: "follow",
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
}

/**
 * robots.txt で [url] の取得が許可されているか。
 * robots.txt が取れない（404・通信の失敗など）ときは許可とみなす
 */
async function isAllowed(url) {
  let origin;
  try {
    origin = new URL(url).origin;
  } catch (e) {
    return false;
  }
  const robotsUrl = `${origin}/robots.txt`;
  let text;
  try {
    const res = await get(robotsUrl);
    if (!res.ok) return true;
    text = await res.text();
  } catch (e) {
    return true;
  }
  return robotsParser(robotsUrl, text).isAllowed(url, ROBOTS_AGENT) !== false;
}

/**
 * ページの中身のハッシュ（SHA-256）。
 * <script>・<style> とタグを除いた文字で作る。取れなければ null
 */
async function pageHash(url) {
  try {
    const res = await get(url);
    if (!res.ok) return null;
    const html = (await res.text()).slice(0, 5 * 1024 * 1024);
    const text = html
        .replace(/<script[\s\S]*?<\/script>/gi, " ")
        .replace(/<style[\s\S]*?<\/style>/gi, " ")
        .replace(/<[^>]+>/g, " ")
        .replace(/\s+/g, " ")
        .trim();
    return crypto.createHash("sha256").update(text).digest("hex");
  } catch (e) {
    return null;
  }
}

module.exports = {isAllowed, pageHash};