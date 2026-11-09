import test from 'node:test';
import assert from 'node:assert/strict';
import { buildSite, fmtDateTime, baseMillis, at } from './build.mjs';
import { ACTS, GDEMO_PREFIX } from './site_data.mjs';
import { buildPosts } from './shot.mjs';

// functions/live_fetch/crawl.js と同じ判定（クローラーが辿れる形になっているかを確かめる）
const KEYWORDS =
  /live|schedule|tour|event|ticket|concert|ライブ|スケジュール|ツアー|イベント|チケット|公演|生誕/i;
const EXCLUDE =
  /news|blog|goods|shop|store|movie|video|discography|profile|login|mypage|join|faq|contact|privacy|terms|policy|\.(jpe?g|png|gif|webp|pdf|zip)$/i;
const isListPage = (path) => !/\d{3,}/.test(path) && !/detail/i.test(path);

function linksIn(html, fromPath) {
  const out = [];
  const re = /<a\b[^>]*?href\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
  let m;
  while ((m = re.exec(html)) !== null) {
    const url = new URL(m[1], `https://demo.example${fromPath}`);
    if (url.origin !== 'https://demo.example') continue;
    out.push({ path: url.pathname, text: m[2].replace(/<[^>]+>/g, ' ') });
  }
  return out;
}
const fileOf = (path) => `${path.replace(/^\//, '')}index.html`;

test('ID は gdemo- で始まり、demo- で始まらない（ライブ取得の対象にするため）', () => {
  for (const a of ACTS) {
    const ids = [a.id, ...(a.members ?? []).map((m) => m.id)];
    for (const id of ids) {
      assert.ok(id.startsWith(GDEMO_PREFIX), id);
      assert.ok(!id.startsWith('demo-'), id);
    }
  }
});

test('公式サイトのトップから2段で、すべてのライブの詳細ページに届く', () => {
  const files = buildSite('2026-11-20', 'a');
  for (const act of ACTS) {
    assert.ok(!EXCLUDE.test(`/${act.slug}/`), act.slug);
    const top = `/${act.slug}/`;
    const cand = (path) =>
      linksIn(files[fileOf(path)], path)
        .filter((l) => !EXCLUDE.test(l.path) && KEYWORDS.test(`${l.path} ${l.text}`))
        .map((l) => l.path);
    const level1 = cand(top);
    const lists = [...new Set(level1)].filter(isListPage).slice(0, 3);
    const level2 = lists.flatMap(cand);
    const reached = new Set([...level1, ...level2].filter((p) => !isListPage(p)));
    // 終了したライブ（3段目の「終了したライブ・イベント」）は辿らなくてよい
    const upcoming = act.lives.filter(
      (l) => !l.versions && Math.max(...l.perfs.map((p) => p.day)) >= 0,
    );
    for (const live of upcoming) {
      assert.ok(reached.has(`/${act.slug}/live/${live.code}/`), `${act.slug} ${live.code}`);
    }
  }
});

test('版B だけにライブの追加・追加公演・時刻の変更が出る', () => {
  const a = buildSite('2026-11-20', 'a');
  const b = buildSite('2026-11-20', 'b');
  assert.equal(a['g-palette/live/261005/index.html'], undefined);
  assert.ok(b['g-palette/live/261005/index.html']);
  assert.ok(!a['g-palette/live/270101/index.html'].includes('追加公演'));
  assert.ok(b['g-palette/live/270101/index.html'].includes('追加公演'));
  assert.ok(a['g-palette/live/261001/index.html'].includes('開演 18:00'));
  assert.ok(b['g-palette/live/261001/index.html'].includes('開演 18:30'));
});

test('日時は基準日からの相対（日本時間）', () => {
  const b = baseMillis('2026-11-20');
  assert.equal(fmtDateTime(at(b, 1, 23, 59)), '2026年11月21日（土） 23:59');
  const html = buildSite('2026-11-20', 'a')['doodle-stars/live/261201/index.html'];
  // 入金期限は撮影の日（基準日）の 21:00
  assert.ok(html.includes('入金期限</dt><dd>2026年11月20日（金） 21:00'));
});

test('投稿もどきは robots.txt で禁止し、HTML の文字にライブの情報を書かない', () => {
  const files = buildSite('2026-11-20', 'a');
  assert.match(files['robots.txt'], /Disallow: \/_shot\//);
  const shot = files['_shot/index.html'];
  assert.match(shot, /noindex/);
  for (const word of ['有明', 'G-Palette', '下北沢', '受付期間', '開演']) {
    assert.ok(!shot.includes(word), word);
  }
  for (const [path, html] of Object.entries(files)) {
    if (path.endsWith('.html')) assert.ok(!html.includes('_shot'), `${path} から /_shot/ にリンクしない`);
  }
  assert.equal(buildPosts('2026-11-20').length, 3);
});
