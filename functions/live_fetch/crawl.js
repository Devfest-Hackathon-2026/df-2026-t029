/**
 * 公式サイトをたどって、ライブ情報のページの URL を集める（add_L L-4b）。
 * Gemini の URL コンテキストはページ内のリンクをたどらないため、
 * Functions 側で2段だけたどって（トップ → 一覧 → 詳細）、読ませるページを渡す。
 * 公式サイトと同じオリジンのページだけ、robots.txt で許可されたものだけを開く。
 */
const {isAllowed} = require("./page_check");

const USER_AGENT = "OshiashiBot/1.0";
const TIMEOUT_MS = 15000;

/** Gemini に渡す URL の上限（URL コンテキストで一度に読める数） */
const MAX_URLS = 20;

/** 2段目で開く一覧のページの数 */
const MAX_LIST_PAGES = 3;

/** ライブ情報らしいリンク（URL か、リンクの文字に含まれる語） */
const KEYWORDS =
  /live|schedule|tour|event|ticket|concert|ライブ|スケジュール|ツアー|イベント|チケット|公演|生誕/i;

/** 開かないページ（URL のパスで判定） */
const EXCLUDE =
  /news|blog|goods|shop|store|movie|video|discography|profile|login|mypage|join|faq|contact|privacy|terms|policy|\.(jpe?g|png|gif|webp|pdf|zip)$/i;

/** HTML を取得する。HTML でない・取れないときは null */
async function fetchHtml(url) {
  try {
    const res = await fetch(url, {
      headers: {"User-Agent": USER_AGENT},
      redirect: "follow",
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (!res.ok) return null;
    const type = res.headers.get("content-type") ?? "";
    if (!type.includes("text/html")) return null;
    return (await res.text()).slice(0, 5 * 1024 * 1024);
  } catch (e) {
    return null;
  }
}

/** ページの中の、同じオリジンのリンク（{url, text}） */
function extractLinks(html, baseUrl) {
  const origin = new URL(baseUrl).origin;
  const links = [];
  const re = /<a\b[^>]*?href\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
  let m;
  while ((m = re.exec(html)) !== null) {
    let url;
    try {
      url = new URL(m[1].replace(/&amp;/g, "&"), baseUrl);
    } catch (e) {
      continue;
    }
    if (url.origin !== origin) continue;
    url.hash = "";
    const text = m[2].replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
    links.push({url: url.href, text});
  }
  return links;
}

/** ライブ情報らしいリンクか */
function isCandidate(link) {
  const u = new URL(link.url);
  if (EXCLUDE.test(u.pathname)) return false;
  return KEYWORDS.test(`${u.pathname}${u.search} ${link.text}`);
}

/** 一覧のページか（詳細のページでない）。詳細はパスに3桁以上の数か detail を含む */
function isListPage(url) {
  const path = new URL(url).pathname;
  return !/\d{3,}/.test(path) && !/detail/i.test(path);
}

/** 重なりを除く（順は保つ） */
function unique(list) {
  return [...new Set(list)];
}

/** [url] を開いて、ライブ情報らしいリンクを返す。開けなければ空 */
async function candidateLinksOf(url) {
  if (!(await isAllowed(url))) return [];
  const html = await fetchHtml(url);
  if (!html) return [];
  return extractLinks(html, url).filter(isCandidate).map((l) => l.url);
}

/**
 * [startUrls]（公式サイトのトップ・前回読んだページ）から2段たどって、
 * Gemini に読ませるページの URL を最大20件返す。
 * 並び：1段目の一覧 → 詳細（開演時刻はたいてい詳細にある）→ 2段目の一覧（翌月など）
 */
async function collectLivePages(startUrls) {
  const level1 = [];
  for (const start of unique(startUrls)) {
    level1.push(...await candidateLinksOf(start));
  }
  const lists = unique(level1).filter(isListPage).slice(0, MAX_LIST_PAGES);

  const level2 = [];
  for (const list of lists) {
    level2.push(...await candidateLinksOf(list));
  }

  const all = unique([...level1, ...level2]);
  const details = all.filter((u) => !isListPage(u));
  const moreLists = all.filter((u) => isListPage(u) && !lists.includes(u));
  return unique([...lists, ...details, ...moreLists]).slice(0, MAX_URLS);
}

module.exports = {collectLivePages, fetchHtml, extractLinks};