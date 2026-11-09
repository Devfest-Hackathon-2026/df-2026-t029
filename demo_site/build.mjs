// 架空の公式サイト（デモ用）の HTML を作る。
//
//   node build.mjs [--base YYYY-MM-DD] [--version a|b] [--out public]
//
// - 日時は基準日（日本時間）からの相対。デモの撮影日に合わせて --base を指定する（省略すると今日）。
// - 版A（最初）→ 版B（ライブ1件追加・追加公演・開演時刻の変更）に差し替えて再デプロイすると、
//   アプリの「照合・変更履歴」と「新しいライブのお知らせ」をデモできる。
// - クローラー（functions/live_fetch/crawl.js）が JS を動かさずに読めるよう、すべて素の HTML にする。
// - /_shot/ は X の投稿もどき（スクショ用）。どこからもリンクせず、robots.txt で禁止し、
//   本文は JS で描く（HTML の中にライブの情報を書かない）。

import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ACTS, inVersion } from './site_data.mjs';
import { buildShotPage } from './shot.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const JST_MS = 9 * 3600 * 1000;
const DAY_MS = 86400 * 1000;
const WEEK = ['日', '月', '火', '水', '木', '金', '土'];

// ---------------------------------------------------------------
// 日時
// ---------------------------------------------------------------

/** 'YYYY-MM-DD'（日本時間）の 0:00 の UTC ミリ秒 */
export function baseMillis(base) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(base);
  if (!m) throw new Error(`--base は YYYY-MM-DD の形で指定してください: ${base}`);
  return Date.UTC(+m[1], +m[2] - 1, +m[3]) - JST_MS;
}

/** 今日（日本時間）の 'YYYY-MM-DD' */
export function todayJst(now = new Date()) {
  return new Date(now.getTime() + JST_MS).toISOString().slice(0, 10);
}

/** 基準日の day 日後の hour:minute（日本時間）の UTC ミリ秒 */
export function at(b, day, hour = 0, minute = 0) {
  return b + day * DAY_MS + hour * 3600000 + minute * 60000;
}

/** 日本時間の年・月・日・曜日・時・分 */
export function parts(ms) {
  const d = new Date(ms + JST_MS);
  return {
    y: d.getUTCFullYear(),
    mo: d.getUTCMonth() + 1,
    d: d.getUTCDate(),
    w: WEEK[d.getUTCDay()],
    h: d.getUTCHours(),
    mi: d.getUTCMinutes(),
  };
}

const pad = (n) => String(n).padStart(2, '0');

/** 2026年12月12日（土） */
export function fmtDate(ms) {
  const p = parts(ms);
  return `${p.y}年${p.mo}月${p.d}日（${p.w}）`;
}

/** 2026年12月12日（土）18:00 */
export function fmtDateTime(ms) {
  const p = parts(ms);
  return `${fmtDate(ms)} ${p.h}:${pad(p.mi)}`;
}

/** 2026.12.12 */
function fmtDot(ms) {
  const p = parts(ms);
  return `${p.y}.${pad(p.mo)}.${pad(p.d)}`;
}

const hm = ([h, m]) => `${h}:${pad(m)}`;
const yen = (n) => `${n.toLocaleString('ja-JP')}円（税込）`;

// ---------------------------------------------------------------
// HTML の部品
// ---------------------------------------------------------------

export function esc(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

const DISCLAIMER =
  'このサイトは、アプリ「おしあし」のデモのために作った架空の公式サイトです。' +
  '登場するグループ・人物・会場・公演はすべて架空で、実在の団体（Google LLC を含む）とは関係ありません。';

function page({ title, act, body, depth }) {
  const root = '../'.repeat(depth);
  const vars = act
    ? `style="--c1:${act.colors[0]};--c2:${act.colors[1]};--c3:${act.colors[2] ?? act.colors[0]};--c4:${act.colors[3] ?? act.colors[1]}"`
    : '';
  const nav = act
    ? `<header class="site-head">
  <a class="logo" href="${root}${act.slug}/">${esc(act.name)}</a>
  <nav>
    <a href="${root}${act.slug}/news/">NEWS</a>
    <a href="${root}${act.slug}/schedule/">SCHEDULE</a>
    ${act.members ? `<a href="${root}${act.slug}/members/">MEMBERS</a>` : ''}
  </nav>
</header>`
    : '';
  return `<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<link rel="stylesheet" href="${root}assets/style.css">
</head>
<body ${vars}>
<p class="demo-band">架空のデモサイトです</p>
${nav}
<main>
${body}
</main>
<footer class="site-foot">
  <p>${esc(DISCLAIMER)}</p>
  <p><a href="${root}">デモサイトの一覧</a></p>
</footer>
</body>
</html>
`;
}

/** 公演の日時（一覧・詳細で使う） */
function perfLine(b, perf, version) {
  const t = version === 'b' && perf.b ? { ...perf, ...perf.b } : perf;
  const date = fmtDate(at(b, perf.day));
  if (!perf.pref) return `${date} 配信開始 ${hm(t.start)}`;
  return `${date} 開場 ${hm(t.open)} / 開演 ${hm(t.start)}`;
}

function perfsOf(live, version) {
  return live.perfs.filter((p) => inVersion(p, version));
}

function livesOf(act, version) {
  return act.lives.filter((l) => inVersion(l, version));
}

/** ライブの最後の公演の日（基準日からの相対） */
const lastDay = (live, version) => Math.max(...perfsOf(live, version).map((p) => p.day));

// ---------------------------------------------------------------
// ページ
// ---------------------------------------------------------------

function memberChips(act) {
  if (!act.members) return '';
  return `<ul class="chips">${act.members
    .map(
      (m) => `<li><span class="dot" style="background:${m.color}">${esc(m.name.slice(0, 1))}</span>${esc(m.name)}</li>`,
    )
    .join('')}</ul>`;
}

function sns(act) {
  const items = [];
  if (act.officialYoutube) {
    items.push(`<li><a href="https://www.youtube.com/${esc(act.officialYoutube)}">YouTube</a></li>`);
  }
  if (act.officialX) items.push(`<li><a href="https://x.com/${esc(act.officialX)}">X</a></li>`);
  if (items.length === 0) return '';
  return `<section class="box"><h2>OFFICIAL SNS</h2><ul class="sns">${items.join('')}</ul></section>`;
}

function liveCard(act, live, b, version, prefix) {
  const perfs = perfsOf(live, version);
  const first = perfs[0];
  const where = [...new Set(perfs.map((p) => p.venue))].join(' / ');
  const date =
    perfs.length > 1
      ? `${fmtDot(at(b, first.day))} 〜 ${fmtDot(at(b, lastDay(live, version)))}`
      : fmtDot(at(b, first.day));
  return `<li class="live-card">
  <p class="date">${date}</p>
  <p class="title"><a href="${prefix}live/${live.code}/">${esc(live.title)}</a></p>
  <p class="venue">${esc(where)}</p>
</li>`;
}

function topPage(act, b, version) {
  const upcoming = livesOf(act, version)
    .filter((l) => lastDay(l, version) >= 0)
    .sort((x, y) => perfsOf(x, version)[0].day - perfsOf(y, version)[0].day)
    .slice(0, 3);
  const body = `<section class="hero">
  <p class="genre">${esc(act.genreLabel)}</p>
  <h1>${esc(act.name)}</h1>
  <p class="kana">${esc(act.kana)}</p>
  <p class="catch">${esc(act.catchCopy)}</p>
  ${memberChips(act)}
</section>
<section class="box">
  <h2>ABOUT</h2>
  <p>${esc(act.about)}</p>
</section>
<section class="box">
  <h2>UPCOMING</h2>
  <ul class="lives">${upcoming.map((l) => liveCard(act, l, b, version, '')).join('')}</ul>
  <p class="more"><a href="schedule/">ライブ・イベントのスケジュールをすべて見る</a></p>
</section>
${sns(act)}`;
  return page({ title: `${act.name} OFFICIAL SITE`, act, body, depth: 1 });
}

function membersPage(act) {
  const body = `<h1 class="page-title">MEMBERS</h1>
<ul class="members">${act.members
    .map(
      (m) => `<li class="member">
  <span class="dot big" style="background:${m.color}">${esc(m.name.slice(0, 1))}</span>
  <div>
    <h2>${esc(m.name)}</h2>
    <p class="role">${esc(m.role)}・誕生日 ${esc(m.birthday)}</p>
    <p>${esc(m.profile)}</p>
  </div>
</li>`,
    )
    .join('')}</ul>`;
  return page({ title: `MEMBERS | ${act.name} OFFICIAL SITE`, act, body, depth: 2 });
}

function schedulePage(act, b, version, past) {
  const lives = livesOf(act, version)
    .filter((l) => (past ? lastDay(l, version) < 0 : lastDay(l, version) >= 0))
    .sort((x, y) => perfsOf(x, version)[0].day - perfsOf(y, version)[0].day);
  const prefix = past ? '../../' : '../';
  const list = lives.length
    ? `<ul class="lives">${lives.map((l) => liveCard(act, l, b, version, prefix)).join('')}</ul>`
    : '<p>現在、予定はありません。</p>';
  const other = past
    ? '<p class="more"><a href="../">これからのライブ・イベント</a></p>'
    : '<p class="more"><a href="past/">終了したライブ・イベント</a></p>';
  const body = `<h1 class="page-title">SCHEDULE<small>${past ? '終了したライブ・イベント' : 'ライブ・イベント'}</small></h1>
${list}
${other}`;
  return page({ title: `SCHEDULE | ${act.name} OFFICIAL SITE`, act, body, depth: past ? 3 : 2 });
}

function recBlock(b, rec) {
  const rows = [
    ['受付期間', `${fmtDateTime(at(b, ...rec.start))} 〜 ${fmtDateTime(at(b, ...rec.end))}`],
  ];
  if (rec.result) rows.push(['当落発表', `${fmtDateTime(at(b, ...rec.result))} 以降、順次メールでお知らせ`]);
  if (rec.pay) rows.push(['入金期限', fmtDateTime(at(b, ...rec.pay))]);
  rows.push(['料金', rec.prices.map(([seat, price]) => `${esc(seat)} ${yen(price)}`).join('<br>')]);
  return `<div class="rec">
  <h3>${esc(rec.name)}</h3>
  <dl>${rows.map(([k, v]) => `<dt>${k}</dt><dd>${v}</dd>`).join('')}</dl>
  ${rec.note ? `<p class="note">${esc(rec.note)}</p>` : ''}
</div>`;
}

function livePage(act, live, b, version) {
  const perfs = perfsOf(live, version);
  const changed = version === 'b' && perfs.some((p) => p.b);
  const rows = perfs
    .map(
      (p) => `<tr>
  <td>${p.label ? `<span class="tag">${esc(p.label)}</span>` : ''}${perfLine(b, p, version)}</td>
  <td>${esc(p.venue)}${p.pref ? `（${esc(p.pref)}）` : ''}</td>
</tr>`,
    )
    .join('');
  const ended = lastDay(live, version) < 0;
  const body = `<p class="crumb"><a href="../../schedule/">SCHEDULE</a></p>
<h1 class="page-title live-title">${esc(live.title)}</h1>
${ended ? '<p class="ended">このライブは終了しました。</p>' : ''}
<p class="lead">${esc(live.lead)}</p>
<section class="box">
  <h2>公演日程</h2>
  ${changed ? '<p class="notice">※ 開場・開演時間を変更しました。</p>' : ''}
  <table class="perfs"><thead><tr><th>日時</th><th>会場</th></tr></thead><tbody>${rows}</tbody></table>
  <p>出演：${esc(act.name)}</p>
</section>
<section class="box">
  <h2>チケット</h2>
  ${live.recs.length ? live.recs.map((r) => recBlock(b, r)).join('') : '<p>無料で視聴できます（チケットは不要です）。</p>'}
</section>`;
  return page({ title: `${live.title} | ${act.name} OFFICIAL SITE`, act, body, depth: 3 });
}

function newsPage(act, b, version) {
  const items = livesOf(act, version)
    .map((l) => ({ day: Math.min(-1, perfsOf(l, version)[0].day - 45), title: `「${l.title}」開催決定！` }))
    .concat([{ day: -3, title: '公式サイトをリニューアルしました' }])
    .sort((x, y) => y.day - x.day);
  const body = `<h1 class="page-title">NEWS</h1>
<ul class="news">${items.map((n) => `<li><span class="date">${fmtDot(at(b, n.day))}</span>${esc(n.title)}</li>`).join('')}</ul>`;
  return page({ title: `NEWS | ${act.name} OFFICIAL SITE`, act, body, depth: 2 });
}

function rootPage() {
  const body = `<h1 class="page-title">架空の公式サイト（デモ用）</h1>
<p>アプリ「おしあし」の「ライブ情報の自動取得」を試すための、架空の公式サイトです。</p>
<ul class="lives">${ACTS.map(
    (a) => `<li class="live-card"><p class="title"><a href="${a.slug}/">${esc(a.name)}</a></p><p class="venue">${esc(a.genreLabel)}</p></li>`,
  ).join('')}</ul>`;
  return page({ title: '架空の公式サイト（デモ用）', act: null, body, depth: 0 });
}

const ROBOTS = `# 架空の公式サイト（デモ用）。/_shot/ はスクショ用のページで、読み取りの対象外
User-agent: *
Disallow: /_shot/
`;

const STYLE = `
:root{--ink:#1f2330;--sub:#5f6577;--line:#e3e6ef;--bg:#fbfbfe;--card:#fff;--c1:#4285F4;--c2:#EA4335;--c3:#FBBC04;--c4:#34A853}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font-family:"Hiragino Sans","Noto Sans JP",system-ui,sans-serif;line-height:1.75}
a{color:var(--c1)}
.demo-band{margin:0;padding:4px 16px;background:#1f2330;color:#fff;font-size:12px;text-align:center;letter-spacing:.1em}
.site-head{display:flex;flex-wrap:wrap;gap:8px 24px;align-items:center;justify-content:space-between;padding:14px 24px;background:#fff;border-bottom:4px solid transparent;border-image:linear-gradient(90deg,var(--c1),var(--c2),var(--c3),var(--c4)) 1}
.logo{font-weight:800;font-size:22px;color:var(--ink);text-decoration:none;letter-spacing:.04em}
.site-head nav{display:flex;gap:18px;font-weight:700;font-size:14px;letter-spacing:.08em}
.site-head nav a{color:var(--ink);text-decoration:none}
main{max-width:880px;margin:0 auto;padding:24px 16px 48px}
.hero{padding:48px 24px;border-radius:24px;text-align:center;color:#fff;background:linear-gradient(135deg,var(--c1),var(--c2) 40%,var(--c3) 70%,var(--c4));box-shadow:0 12px 32px rgba(0,0,0,.12)}
.hero h1{margin:0;font-size:clamp(36px,8vw,64px);letter-spacing:.04em;line-height:1.1}
.hero .genre{margin:0 0 8px;font-size:12px;letter-spacing:.3em;opacity:.9}
.hero .kana{margin:4px 0 16px;opacity:.9}
.hero .catch{font-size:18px;font-weight:700}
.chips{display:flex;flex-wrap:wrap;justify-content:center;gap:8px;padding:0;margin:20px 0 0;list-style:none}
.chips li{display:flex;align-items:center;gap:6px;padding:4px 12px 4px 4px;border-radius:999px;background:rgba(255,255,255,.92);color:var(--ink);font-weight:700;font-size:14px}
.dot{display:inline-grid;place-items:center;width:26px;height:26px;border-radius:50%;color:#fff;font-size:13px;font-weight:800}
.dot.big{width:64px;height:64px;font-size:28px;flex:none}
.box{margin-top:24px;padding:20px 24px;background:var(--card);border:1px solid var(--line);border-radius:16px}
.box h2{margin:0 0 12px;font-size:16px;letter-spacing:.15em;color:var(--c1)}
.page-title{font-size:28px;letter-spacing:.08em;margin:8px 0 16px}
.page-title small{display:block;font-size:14px;color:var(--sub);letter-spacing:0}
.live-title{letter-spacing:0;font-size:24px}
.lives{list-style:none;padding:0;margin:0;display:grid;gap:12px}
.live-card{padding:14px 18px;border:1px solid var(--line);border-left:6px solid var(--c1);border-radius:12px;background:#fff}
.live-card p{margin:0}
.live-card .date{font-weight:800;color:var(--c2);font-size:14px}
.live-card .title{font-weight:700}
.live-card .venue{color:var(--sub);font-size:14px}
.more{text-align:right;margin:12px 0 0}
.sns{display:flex;gap:12px;list-style:none;padding:0;margin:0}
.sns a{display:inline-block;padding:6px 16px;border-radius:999px;border:1px solid var(--line);text-decoration:none;font-weight:700}
.members{list-style:none;padding:0;display:grid;gap:16px}
.member{display:flex;gap:16px;align-items:center;padding:16px;background:#fff;border:1px solid var(--line);border-radius:16px}
.member h2{margin:0}
.member p{margin:2px 0}
.role{color:var(--sub);font-size:14px}
.perfs{width:100%;border-collapse:collapse;font-size:15px}
.perfs th,.perfs td{padding:10px 8px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top}
.perfs th{font-size:13px;color:var(--sub)}
.tag{display:inline-block;margin-right:6px;padding:0 8px;border-radius:6px;background:var(--c3);color:#1f2330;font-size:12px;font-weight:700}
.rec{padding:12px 0;border-bottom:1px dashed var(--line)}
.rec:last-child{border-bottom:0}
.rec h3{margin:0 0 6px;font-size:16px}
.rec dl{display:grid;grid-template-columns:7em 1fr;gap:4px 12px;margin:0;font-size:15px}
.rec dt{color:var(--sub)}
.rec dd{margin:0}
.note,.notice{color:var(--c2);font-size:14px}
.ended{display:inline-block;padding:2px 10px;border-radius:6px;background:#eee;font-size:13px}
.crumb{margin:0;font-size:13px}
.news{list-style:none;padding:0}
.news li{padding:12px 0;border-bottom:1px solid var(--line)}
.news .date{display:inline-block;width:7em;color:var(--sub);font-size:14px}
.site-foot{padding:24px 16px 40px;text-align:center;color:var(--sub);font-size:12px;border-top:1px solid var(--line)}
@media (max-width:560px){.rec dl{grid-template-columns:1fr}.rec dt{margin-top:6px}}
`;

// ---------------------------------------------------------------
// 書き出し
// ---------------------------------------------------------------

/** { 'パス': '中身' } を作る（テストでも使う） */
export function buildSite(base, version) {
  if (version !== 'a' && version !== 'b') throw new Error('--version は a か b です');
  const b = baseMillis(base);
  const files = {
    'index.html': rootPage(),
    'robots.txt': ROBOTS,
    'assets/style.css': STYLE.trimStart(),
    '_shot/index.html': buildShotPage(base),
  };
  for (const act of ACTS) {
    const dir = act.slug;
    files[`${dir}/index.html`] = topPage(act, b, version);
    if (act.members) files[`${dir}/members/index.html`] = membersPage(act);
    files[`${dir}/schedule/index.html`] = schedulePage(act, b, version, false);
    files[`${dir}/schedule/past/index.html`] = schedulePage(act, b, version, true);
    files[`${dir}/news/index.html`] = newsPage(act, b, version);
    for (const live of livesOf(act, version)) {
      files[`${dir}/live/${live.code}/index.html`] = livePage(act, live, b, version);
    }
  }
  return files;
}

export function parseArgs(argv) {
  const opts = { base: null, version: 'a', out: join(HERE, 'public') };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--base') opts.base = argv[++i] ?? null;
    else if (a === '--version') opts.version = argv[++i] ?? null;
    else if (a === '--out') opts.out = argv[++i] ?? null;
    else throw new Error(`知らない引数です: ${a}`);
  }
  return opts;
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const base = opts.base ?? todayJst();
  const files = buildSite(base, opts.version);
  // 前の版のファイルを消す（消せない環境では上書きだけする。残ったページはどこからもリンクされない）
  try {
    rmSync(opts.out, { recursive: true, force: true });
  } catch (e) {
    console.warn(`古いファイルを消せませんでした（上書きします）: ${e.code ?? e.message}`);
  }
  for (const [path, content] of Object.entries(files)) {
    const full = join(opts.out, path);
    mkdirSync(dirname(full), { recursive: true });
    writeFileSync(full, content);
  }
  console.log(
    `デモサイトを作りました（基準日 ${base}・版${opts.version.toUpperCase()}・${Object.keys(files).length} ファイル）: ${opts.out}`,
  );
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try {
    main();
  } catch (e) {
    console.error(e.message ?? e);
    process.exit(1);
  }
}
