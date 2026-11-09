// X の投稿もどき（スクショ読み取りのデモ用）のページを作る。/_shot/?p=1 〜 3
//
// 公式サイトに無いライブ（フェス出演・対バン）を、SNS の投稿だけで告知している、という設定。
// アプリのスクショ読み取り（Gemini）で、ここからライブを追加するデモに使う。
//
// ライブ情報の自動取得（Vertex AI）に読まれないように：
// - どのページからもリンクしない
// - robots.txt で /_shot/ を禁止（functions のクローラーは robots.txt を守る）
// - <meta name="robots" content="noindex"> と、Hosting の X-Robots-Tag（firebase.json）
// - 投稿の中身は base64 にした JSON を JS で描く（HTML の文字としてはライブの情報が無い）
//
// 投稿はすべて架空。X のロゴは使わず、レイアウトだけを似せる。

import { ACTS } from './site_data.mjs';

const JST_MS = 9 * 3600 * 1000;
const DAY_MS = 86400 * 1000;
const WEEK = ['日', '月', '火', '水', '木', '金', '土'];
const WEEK_EN = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

function baseMs(base) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(base);
  if (!m) throw new Error(`基準日は YYYY-MM-DD の形で指定してください: ${base}`);
  return Date.UTC(+m[1], +m[2] - 1, +m[3]) - JST_MS;
}

function jst(ms) {
  const d = new Date(ms + JST_MS);
  return {
    y: d.getUTCFullYear(),
    mo: d.getUTCMonth() + 1,
    d: d.getUTCDate(),
    wd: d.getUTCDay(),
    h: d.getUTCHours(),
    mi: d.getUTCMinutes(),
  };
}

const pad = (n) => String(n).padStart(2, '0');

/** 投稿の本文の日付の形 12/5(土) */
const md = (ms) => {
  const p = jst(ms);
  return `${p.mo}/${p.d}(${WEEK[p.wd]})`;
};
/** 12/5(土) 12:00 */
const mdhm = (ms) => {
  const p = jst(ms);
  return `${md(ms)} ${p.h}:${pad(p.mi)}`;
};
/** チラシの日付 2026.12.05 と (Sat) */
const flyerDate = (ms) => {
  const p = jst(ms);
  return { date: `${p.y}.${pad(p.mo)}.${pad(p.d)}`, wd: WEEK_EN[p.wd] };
};
/** 投稿日時 午後8:00 · 2026年11月8日 */
const postedAt = (ms) => {
  const p = jst(ms);
  const ampm = p.h < 12 ? '午前' : '午後';
  const h12 = p.h % 12 === 0 ? 12 : p.h % 12;
  return `${ampm}${h12}:${pad(p.mi)} · ${p.y}年${p.mo}月${p.d}日`;
};

/** 投稿のデータ（基準日からの相対で日時を決める） */
export function buildPosts(base) {
  const b = baseMs(base);
  const t = (day, h = 0, m = 0) => b + day * DAY_MS + h * 3600000 + m * 60000;
  const gp = ACTS.find((a) => a.slug === 'g-palette');
  const hd = ACTS.find((a) => a.slug === 'hello-devs');

  const fest1 = t(26);
  const fest2 = t(27);
  const gpAccount = {
    name: 'G-Palette【Official】',
    handle: '@G_Palette_Official',
    initials: 'GP',
    colors: gp.colors,
  };

  return [
    {
      account: gpAccount,
      text:
        `💝#PIXELFES タイムテーブル解禁💝\n\n` +
        `${md(fest1)}\n『PIXEL FES〜Pop Idol eXperience Live〜』\n📍有明ベイサイドホール\n開場 16:00 / 開演 17:00\n\n` +
        `G-PaletteはDAY-1の\n《17:30〜18:00》に出演します！🗓️\n\n` +
        `▼ライブ配信📺\nstream.example.jp/pxf26\n\n` +
        `▼イベント公式HP🎁\npixel-fes.example.jp\n\n` +
        `@PIXELFES_IDOL #PIXELFES2026\n#GPalette #ジーパレ`,
      posted: postedAt(t(-1, 20, 0)),
      views: '2.1万',
      images: [
        {
          kind: 'timetable',
          ...flyerDate(fest1),
          venue: 'ARIAKE BAYSIDE HALL',
          rows: [
            ['16:00', '開場'],
            ['17:00', '開会セレモニー'],
            ['17:30-18:00', 'G-Palette', true],
            ['18:10-18:40', 'ステラノート'],
            ['18:50-19:20', 'ルミナス☆ガーデン'],
            ['19:30-20:00', 'Prism Voice'],
          ],
        },
        {
          kind: 'lineup',
          ...flyerDate(fest1),
          end: flyerDate(fest2),
          venues: ['ARIAKE BAYSIDE HALL', 'RINKAI DREAM ARENA'],
          names: ['G-Palette', 'ステラノート', 'ルミナス☆ガーデン', 'Prism Voice', 'and more...'],
        },
      ],
    },
    {
      account: gpAccount,
      text:
        `🎫#PIXELFES チケット情報🎫\n\n` +
        `G-Palette出演の\n『PIXEL FES〜Pop Idol eXperience Live〜』\nオフィシャル最速先行（抽選）受付中！\n\n` +
        `🗓️受付期間\n${mdhm(t(-1, 12, 0))} 〜 ${mdhm(t(4, 23, 59))}\n` +
        `📩当落発表 ${mdhm(t(7, 18, 0))}\n` +
        `💳入金期限 ${mdhm(t(10, 23, 59))}\n\n` +
        `1日券 6,800円 / 2日通し券 12,000円\n\n` +
        `▼お申し込み\npixel-fes.example.jp/ticket\n\n#GPalette #ジーパレ`,
      posted: postedAt(t(-1, 12, 5)),
      views: '1.4万',
      images: [
        {
          kind: 'ticket',
          ...flyerDate(fest1),
          end: flyerDate(fest2),
          lines: [
            ['オフィシャル最速先行', `${mdhm(t(-1, 12, 0))} 〜 ${mdhm(t(4, 23, 59))}`],
            ['当落発表', mdhm(t(7, 18, 0))],
            ['入金期限', mdhm(t(10, 23, 59))],
          ],
        },
      ],
    },
    {
      account: {
        name: 'Hello Devs【公式】',
        handle: '@HelloDevs_band',
        initials: 'HD',
        colors: hd.colors,
      },
      text:
        `📢対バンライブ出演決定！\n\n` +
        `${md(t(22))}\n『Dart × Go 2MAN LIVE "Concurrency"』\n📍下北沢フレームシアター\n開場 18:30 / 開演 19:00\n\n` +
        `共演：The Goroutines\n\n` +
        `🎫一般発売（先着）\n${mdhm(t(3, 12, 0))} 〜 ${mdhm(t(21, 23, 59))}\n前売 4,500円（+1D）\n\n` +
        `▼詳細\nhellodevs.example.jp\n\n#HelloDevs #ハロデブ`,
      posted: postedAt(t(-1, 19, 0)),
      views: '8,312',
      images: [
        {
          kind: 'twoman',
          ...flyerDate(t(22)),
          venue: 'SHIMOKITAZAWA FRAME THEATER',
          names: ['Hello Devs', 'The Goroutines'],
        },
      ],
    },
  ];
}

/** ページの HTML（本文は JS で描く） */
export function buildShotPage(base) {
  const data = Buffer.from(JSON.stringify(buildPosts(base)), 'utf8').toString('base64');
  return `<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow, noarchive">
<title>post</title>
<style>
*{box-sizing:border-box}
body{margin:0;background:#000;color:#e7e9ea;font-family:-apple-system,BlinkMacSystemFont,"Hiragino Sans","Noto Sans JP","Segoe UI",sans-serif}
.post{width:600px;max-width:100%;margin:0 auto;padding:12px 16px 4px;border-bottom:1px solid #2f3336}
.head{display:flex;align-items:center;gap:10px}
.avatar{width:48px;height:48px;border-radius:50%;display:grid;place-items:center;font-weight:900;font-size:17px;color:#1f2330;flex:none;position:relative}
.avatar::after{content:"";position:absolute;inset:4px;border-radius:50%;background:#fbf7ec}
.avatar span{position:relative;z-index:1;letter-spacing:-.5px}
.who{flex:1;min-width:0;line-height:1.25}
.name{font-weight:800;font-size:16px;display:flex;align-items:center;gap:4px}
.badge{width:18px;height:18px;border-radius:50%;background:#1d9bf0;display:inline-grid;place-items:center}
.badge svg{width:12px;height:12px}
.handle{color:#71767b;font-size:15px}
.more{color:#71767b;font-size:20px;letter-spacing:1px}
.text{white-space:pre-wrap;font-size:17px;line-height:1.45;margin:12px 0}
.text .hl{color:#1d9bf0}
.images{display:grid;gap:2px;border-radius:16px;overflow:hidden;border:1px solid #2f3336}
.images.n2{grid-template-columns:1fr 1fr}
.flyer{aspect-ratio:4/5;position:relative;overflow:hidden;color:#6b4a7a;font-family:"Hiragino Mincho ProN","Noto Serif JP",Georgia,serif;text-align:center;padding:28px 16px 16px}
.images.n1 .flyer{aspect-ratio:16/10}
.flyer.lav{background:repeating-linear-gradient(90deg,#efe8f6 0 14px,#f6f1fa 14px 28px)}
.flyer.sky{background:repeating-linear-gradient(90deg,#dceefa 0 14px,#eaf5fc 14px 28px)}
.flyer.mint{background:repeating-linear-gradient(90deg,#def3ea 0 14px,#ecf8f2 14px 28px)}
.flyer::before{content:"";position:absolute;left:0;right:0;top:0;height:18px;background:radial-gradient(circle at 10px 0,#fff 9px,transparent 10px) 0 0/20px 18px repeat-x}
.logo{font-size:40px;font-weight:900;letter-spacing:2px;color:#e58fb6;text-shadow:2px 2px 0 #fff,4px 4px 0 #b9d7f0;line-height:1;font-family:Georgia,serif}
.logo small{display:block;font-size:11px;letter-spacing:.5px;color:#9a7aae;text-shadow:none;margin-top:4px;font-style:italic}
.fdate{font-size:22px;font-weight:900;color:#c76a9a;font-style:italic;margin-top:10px}
.fdate small{font-size:12px}
.venue{font-family:Georgia,serif;font-weight:700;letter-spacing:1px;font-size:12px;color:#6b4a7a;margin-top:6px}
.tt{margin:12px auto 0;width:92%;background:rgba(255,255,255,.85);border-radius:8px;padding:6px 10px;font-family:-apple-system,"Hiragino Sans",sans-serif;font-size:11px;color:#5b4766}
.tt div{display:flex;justify-content:space-between;padding:3px 0;border-bottom:1px dotted #d9c9e4}
.tt div:last-child{border:0}
.tt .me{background:#fff3b0;font-weight:800}
.names{margin-top:14px;font-family:-apple-system,"Hiragino Sans",sans-serif;font-weight:800;font-size:13px;line-height:1.8;color:#5b4766}
.vs{font-size:26px;font-weight:900;color:#3f6fb5;margin-top:14px;font-family:Georgia,serif}
.vs i{display:block;font-size:14px;color:#c76a9a}
.foot{color:#71767b;font-size:15px;padding:16px 0 12px;border-bottom:1px solid #2f3336}
.foot b{color:#e7e9ea}
.controls{width:600px;max-width:100%;margin:28px auto;padding:0 16px;color:#71767b;font-size:12px}
.controls a{color:#71767b;margin-right:12px}
</style>
</head>
<body>
<article class="post" id="post"></article>
<p class="controls" id="controls"></p>
<script>
(function () {
  var posts = JSON.parse(new TextDecoder().decode(Uint8Array.from(atob("${data}"), function (c) { return c.charCodeAt(0); })));
  var n = Math.min(Math.max(parseInt(new URLSearchParams(location.search).get("p") || "1", 10) || 1, 1), posts.length);
  var p = posts[n - 1];
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return {"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;"}[c]; }); }
  function hl(s) {
    return esc(s).replace(/(#[^\\s#]+|@[A-Za-z0-9_]+|[a-z0-9.-]+\\.example\\.jp[^\\s]*)/g, '<span class="hl">$1</span>');
  }
  function flyer(im) {
    var logo = '<div class="logo">PIXEL FES<small>Pop Idol eXperience Live</small></div>';
    if (im.kind === "timetable") {
      return '<div class="flyer lav">' + logo +
        '<div class="fdate">' + im.date + '<small>(' + im.wd + ')</small></div>' +
        '<div class="venue">' + esc(im.venue) + '</div>' +
        '<div class="tt">' + im.rows.map(function (r) {
          return '<div class="' + (r[2] ? "me" : "") + '"><span>' + r[0] + '</span><span>' + esc(r[1]) + '</span></div>';
        }).join("") + '</div></div>';
    }
    if (im.kind === "lineup") {
      return '<div class="flyer sky">' + logo +
        '<div class="fdate">' + im.date + '<small>(' + im.wd + ')</small>-' + im.end.date.slice(8) + '<small>(' + im.end.wd + ')</small></div>' +
        im.venues.map(function (v) { return '<div class="venue">' + esc(v) + '</div>'; }).join("") +
        '<div class="names">' + im.names.map(esc).join("<br>") + '</div></div>';
    }
    if (im.kind === "ticket") {
      return '<div class="flyer lav">' + logo +
        '<div class="fdate">' + im.date + '<small>(' + im.wd + ')</small>-' + im.end.date.slice(8) + '<small>(' + im.end.wd + ')</small></div>' +
        '<div class="tt">' + im.lines.map(function (r) {
          return '<div><span>' + esc(r[0]) + '</span><span>' + esc(r[1]) + '</span></div>';
        }).join("") + '</div></div>';
    }
    return '<div class="flyer mint"><div class="logo" style="color:#3f8fd0">2MAN LIVE<small>Concurrency</small></div>' +
      '<div class="vs">' + esc(im.names[0]) + '<i>×</i>' + esc(im.names[1]) + '</div>' +
      '<div class="fdate">' + im.date + '<small>(' + im.wd + ')</small></div>' +
      '<div class="venue">' + esc(im.venue) + '</div></div>';
  }
  var a = p.account;
  var ring = "conic-gradient(" + a.colors.join(",") + "," + a.colors[0] + ")";
  document.getElementById("post").innerHTML =
    '<div class="head">' +
      '<div class="avatar" style="background:' + ring + '"><span>' + esc(a.initials) + '</span></div>' +
      '<div class="who"><div class="name">' + esc(a.name) +
        ' <span class="badge"><svg viewBox="0 0 24 24"><path fill="#fff" d="M9.5 16.2 5.3 12l-1.4 1.4 5.6 5.6 11-11-1.4-1.4z"/></svg></span></div>' +
        '<div class="handle">' + esc(a.handle) + '</div></div>' +
      '<div class="more">···</div>' +
    '</div>' +
    '<div class="text">' + hl(p.text) + '</div>' +
    '<div class="images n' + p.images.length + '">' + p.images.map(flyer).join("") + '</div>' +
    '<div class="foot">' + esc(p.posted) + ' · <b>' + esc(p.views) + '</b> 件の表示</div>';
  document.getElementById("controls").innerHTML =
    posts.map(function (_, i) { return '<a href="?p=' + (i + 1) + '">投稿' + (i + 1) + '</a>'; }).join("") +
    '<br>架空の投稿です（アプリ「おしあし」のスクショ読み取りのデモ用）。';
})();
</script>
</body>
</html>
`;
}
