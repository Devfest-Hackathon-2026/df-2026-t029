# 架空の公式サイト（デモ用）

アプリ「おしあし」の **ライブ情報の自動取得** と **スクショ読み取り** をデモするための、架空の公式サイトです。
おしあし本体（`oshiashi.web.app`）とは **別のサイト** としてホストします。登場するグループ・人物・会場はすべて架空です。

## 中身

| パス | 内容 |
|---|---|
| `/g-palette/` | G-Palette（アイドル）：Chromeくん・Androidくん・モッフィー・Chrome Dino |
| `/hello-devs/` | Hello Devs（アーティスト）：Dash・Gopher・Sparky |
| `/doodle-stars/` | Doodle Stars（声優）：ペグマン・ヌーグラー・スタン |
| `/gemini-chan/` | ジェミニちゃん（VTuber・ソロ） |
| `/<推し>/schedule/` → `/<推し>/live/<番号>/` | ライブの一覧 → 詳細（公演・受付期間・当落・入金期限・料金） |
| `/_shot/?p=1〜3` | X の投稿もどき（スクショ用）。**どこからもリンクしない** |

- クローラー（`functions/live_fetch/crawl.js`）が「トップ → 一覧 → 詳細」の2段で辿れる形にしてあります（`build.test.mjs` で確かめています）。
- 受付の状態がばらけるようにしてあります：締切間近・受付前・抽選結果待ち・**入金期限が撮影の日の 21:00**・先着で受付中・配信のみ・同じ日の2部公演・終了したライブ。
- `/_shot/` は Vertex AI に読まれないよう、robots.txt で禁止・noindex・本文は JS で描画（HTML の文字にライブの情報が無い）にしています。
  ここには **公式サイトに無いライブ**（フェス出演・対バン）だけを書いてあるので、スクショからライブを追加するデモに使えます。

## 作り方（Dev Container 内）

```bash
cd demo_site
node build.mjs --base 2026-11-20             # 版A。--base は撮影の日（省略すると今日）
node build.mjs --base 2026-11-20 --version b # 版B（下を参照）
npm test                                     # 確かめ
```

`public/` に HTML ができます（コミットしません）。

### 版A → 版B（照合・変更履歴のデモ）

版B では次の3つが変わります。版A でライブを取得した後、版B を作って再デプロイし、もう一度取得します。

- G-Palette「クリスマスライブ」が追加される（新しいライブのお知らせ）
- G-Palette ツアーに東京の追加公演が増える
- G-Palette 1st ワンマンの開場・開演が 30 分遅くなる（変更履歴）

## 公開（人間が行う）

おしあしと同じプロジェクトに、別のサイトを作って公開します（URL が別になります）。

```bash
firebase hosting:sites:create g-palette-demo --project oshiashi-test   # 初回のみ。名前が使われていたら変えて firebase.json の site も直す
cd demo_site
node build.mjs --base <撮影の日>
firebase deploy --only hosting --project oshiashi-test
```

`demo_site/firebase.json` はこのフォルダ専用なので、おしあし本体の Hosting・ルール・Functions には触れません。
別のプロジェクトに置きたいときは `--project` を変えるだけです。

公開したら、推しをシードします（`tools/seed/README.md` の「Google の架空の推し」）。

## 注意

- デモ動画では、架空のサイト・架空の投稿であることを字幕などで明示します。
- Google のロゴやキャラクターの絵は使っていません（名前と色の丸だけ）。
- G-Palette の公式 X・YouTube は、メモのとおり Google Japan（`googlejapan`・`@GoogleJapan`）にしています。正しいアカウントか、公開前に一度開いて確かめてください。
