/**
 * 公式サイトに貼ってある YouTube のリンクから、公式 YouTube を拾う（add_P P-2b の A）。
 * トップのページと、プロフィールらしいページ（最大3件）を開き、
 * youtube.com/@ハンドル・/channel/UC... のリンクを探す。Gemini は使わない
 */
const {isAllowed} = require("./page_check");
const {fetchHtml, extractLinks} = require("./crawl");
const {cleanYoutubeAccount} = require("./normalize");

/** プロフィールらしいページ（URL のパスかリンクの文字に含まれる語） */
const PROFILE_WORDS = /profile|about|member|sns|link|プロフィール|メンバー|について/i;

/** 開くページの上限（トップを含む） */
const MAX_PAGES = 4;

/** ページの中の YouTube のチャンネルのリンク（出てきた順） */
function youtubeLinksIn(html) {
  const re = /https?:\/\/(?:www\.|m\.)?youtube\.com\/(?:@[^"'<>\s?#/]+|channel\/UC[\w-]{22})/gi;
  return [...new Set(html.match(re) ?? [])];
}

/** 公式サイトのトップの URL から、公式 YouTube（@ハンドル か UC...）を返す。無ければ null */
async function findYoutubeOnSite(officialUrl) {
  if (!officialUrl) return null;
  const pages = [officialUrl];
  const visited = new Set();
  for (let i = 0; i < pages.length && visited.size < MAX_PAGES; i++) {
    const url = pages[i];
    if (visited.has(url)) continue;
    visited.add(url);
    if (!(await isAllowed(url))) continue;
    const html = await fetchHtml(url);
    if (!html) continue;

    for (const link of youtubeLinksIn(html)) {
      const account = cleanYoutubeAccount(link);
      if (account) return account;
    }
    // トップに無ければ、プロフィールらしいページを開く
    if (i === 0) {
      for (const l of extractLinks(html, url)) {
        if (PROFILE_WORDS.test(`${new URL(l.url).pathname} ${l.text}`)) pages.push(l.url);
      }
    }
  }
  return null;
}

module.exports = {findYoutubeOnSite};