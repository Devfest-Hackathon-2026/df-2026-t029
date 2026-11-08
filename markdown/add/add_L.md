# おしあし（仮）ライブ情報の自動取得 仕様書（add_L）

> 本ドキュメントは、11/8 にユーザー（横山）が決めた「推しが登録（承認）されたら、その推しの公式サイトを調べて、今後のライブ情報を自動で取ってきて共通データに登録する」を、提出（11/10 19:00）までに作るための仕様書である。
> ねらいは、Google の技術（Gemini・Google 検索によるグラウンディング・URL コンテキスト・Vertex AI・Cloud Functions・Cloud Scheduler）をはっきり使い、「推しをフォローするだけで予定が埋まる」体験を見せること。
> チームメンバーおよび開発支援に使う LLM が、この文書だけを読んで同じ前提で作業できるように、データ・処理の流れ・変えるファイルを具体的に書いている。
> 前提として、`CLAUDE.md`・`markdown/Database_config.md`・`markdown/deploy_手順.md`・`markdown/add/add_E.md`（Cloud Functions の Callable 関数とシークレットの前例）・`markdown/fixes/fix_Fd.md`（ライブ一覧・推しの行の ⋮）をあわせて参照すること。
> 名前は「ライブ（Live）」の L。

## 0. LLM への指示

- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。「9. 未決定事項」は独自に確定させず、提案として示すこと。
- 本仕様にない作業を勝手に足さないこと。**テストコードは書かない**。
- **コードの編集は人間が Dev Container 内で行う。** LLM はリポジトリを読むだけにする。小さな変更は変わる部分だけ、大きな変更はメソッド・クラス・ファイル単位で丸ごと出す。**変更ごとにファイルの場所（パス）を書く**（「1〜3に同じものを適用」のようにまとめない）。
- 7章のステップの順に進め、各ステップに1行のコミット文を添えること。画面の確認は最後にまとめて、Claude in Chrome（人の Chrome）で行う。
- 見た目はログイン後のデザイン「ハコ色」（`lib/theme/hako_app_widgets.dart`・`brand_colors.dart`・`hako_fonts.dart`）に合わせる。
- コメントで章を書くときは「add_L 3.1」のように仕様書の名前を付ける。
- 追加してよいパッケージは、Functions の `@google/genai`（Gemini の呼び出し）と `robots-parser`（robots.txt の確認）だけ。アプリには足さない（`cloud_functions` は add_E で導入済み）。
- 秘密情報をリポジトリに書かない。Vertex AI はサービス アカウントの権限で呼ぶので、API キーは使わない。`firebase deploy`・コンソールの設定は人間が行う。
- **権利の決まり（2.3）を必ず守る。** 公式サイトの文章・画像・ロゴを保存しない。

## 1. 概要

| 項目 | 内容 |
|---|---|
| 名前 | add_L（ライブ情報の自動取得） |
| 担当 | B（横山）。ライブ一覧・ライブ詳細・推しの行は A（とし）と共有する |
| ブランチ | `dev` から `features/L` |
| 状況 | 未着手（11/8 に仕様書を作成） |

### 1.1 できるようになること

1. 推しが承認されると、Gemini がその推しの公式サイトを探し、今後のライブ・公演・受付を読み取って共通データに登録する。公式サイトの URL・公式 X が空なら、それも埋める。
2. 推しの行の ⋮ と、ライブ一覧の「◯◯の今後のライブ」から、「公式サイトからライブを探す」を押して、その場で取得できる（デモで見せる入口）。
3. 毎日1回、フォローされている推しの公式サイトを確かめ、更新があれば取り直して、新しいライブ・公演・受付だけを足す。
4. AI が登録したものには、ライブ詳細に「AI が公式サイトから登録」と出典のリンクが出る。間違いは、今の編集と変更履歴の仕組みで誰でも直せる。

### 1.2 使う Google の技術

| 技術 | 使い方 |
|---|---|
| Gemini（Vertex AI 経由） | 公式サイトを探し、ページを読んで、ライブ情報を決めた形（JSON）にする |
| Google 検索によるグラウンディング | 公式サイト・ライブのページを Google 検索で探す |
| URL コンテキスト | 公式サイトのライブ・ツアーのページを Gemini に直接読ませる |
| 構造化出力（JSON スキーマ） | 登録できる形のデータに変える |
| Cloud Functions（第2世代） | 承認のトリガー・Callable 関数・定期実行。Firestore への書き込み（Admin SDK） |
| Cloud Scheduler | 毎日の再取得（`onSchedule`） |

- Gemini は Vertex AI 経由で呼ぶ（無料トライアルのクレジットで支払える。API キーが要らない）。

## 2. 決定事項：方針

### 2.1 登録の仕方

- 取得したものは**共通データ（`lives`・`performances`・`receptions`）に直接登録する**。人の確認は挟まない。
- 既にあるもの（人が登録したもの・前回 AI が登録したもの）は**書き換えない**。足りない公演・受付だけを足す（3.4）。人の修正が AI に上書きされないようにするため。
- 登録したドキュメントには `source: 'ai'` と出典の URL を付け、画面で人の登録と見分けられるようにする（3.1）。

### 2.2 対象にする推し

- `status` が `approved` のグループ（`groups`）と個人（`oshis`）。
- **ID が `demo-` で始まる推し（デモ用データ）は対象外**。架空の名前で検索すると、関係のない同名のサイトを公式と取り違えるおそれがあるため。デモ用データのスクリプトは変えない。
- 実在の推しは、デモ用データを入れたあとにアプリから申請し、コンソールで承認して足す（7章の L-4）。

### 2.3 権利の決まり

- 保存するのは**事実だけ**：ライブ名・日時・会場・都道府県・受付の種別と名前・期間・当落・入金期限・席種と料金。公式サイトの告知文・紹介文はそのまま保存しない。
- アーティスト写真・ジャケット・ロゴなどの画像は取り込まない。
- 出典（公式ページの URL）を必ず付ける。
- **robots.txt を守る**：公式サイトの robots.txt で、読もうとするページが禁止されていれば、取得しない（3.6）。
- 公式ページを取りに行くのは、1つの推しにつき1日1回まで（手動の取得は 10分に1回まで。4.1）。

## 3. 決定事項：データ

### 3.1 ライブ・公演・受付に足す項目

`lives`・`performances`・`receptions` に足す（どれも任意。人の登録には入れない）。

| 項目 | 型 | 内容 |
|---|---|---|
| `source` | string | `'ai'`（AI が登録したもの）。無ければ人の登録 |
| `sourceUrls` | list<string>（0〜5） | 出典の URL（公式サイトのライブのページなど） |
| `searchQueries` | list<string>（0〜5） | `lives` だけ。取得のときに Gemini が使った Google 検索の語（5.3 の表示に使う） |

- `createdBy`・`updatedBy` は `'system'`、`createdAt`・`updatedAt` はサーバー時刻。
- `groupIds`・`oshiIds` は、新しいライブなら対象の推し（グループなら `groupIds: [id]`・`oshiIds: []`、個人なら `groupIds: []`・`oshiIds: [id]`）。既にあるライブに足す公演・受付は、そのライブの値を写す。
- アプリのモデル（`Live`・`Performance`・`Reception`）は、3つの項目を読むだけにする。アプリで編集して保存するとき、これらの項目を消さない・変えないこと（L-3 で今の保存のしかたを読んで確かめる）。
- **`firestore.rules` の確認**：`lives`・`performances`・`receptions` の作成・更新で項目を `keys().hasOnly` などで絞っている場合、AI が登録したものを人が編集すると拒否される。L-3 でルールを読み、絞っていれば `source`・`sourceUrls`・`searchQueries` を「あってよい・値は変えられない」として足す。絞っていなければ変えない。

### 3.2 推しに足す項目（取得の状態）

`groups/{id}`・`oshis/{id}` に足す。書くのは Functions だけ（Admin SDK。ルールは今のまま、アプリからは更新できない）。

| 項目 | 型 | 内容 |
|---|---|---|
| `liveFetch` | map | 取得の状態（下） |
| `officialUrl`・`officialX` | string | 今ある項目。**空のときだけ** Gemini が見つけたものを入れる |

`liveFetch` の中身：

| 項目 | 型 | 内容 |
|---|---|---|
| `status` | string | `running`（取得中）・`ok`・`noOfficialSite`（公式サイトが見つからない）・`blocked`（robots.txt で禁止）・`error` |
| `startedAt` | timestamp | 最後に取得を始めた日時（10分の制限と、取得中の重なりの判定に使う） |
| `finishedAt` | timestamp | 最後に終わった日時 |
| `lastGeminiAt` | timestamp | 最後に Gemini を呼んだ日時 |
| `schedulePageUrl` | string | ライブ情報を読んだページの URL（毎日の確認に使う） |
| `pageHash` | string | そのページの中身のハッシュ（3.6） |
| `added` | map | 前回足した件数（`lives`・`performances`・`receptions`） |
| `message` | string | エラーの短い説明（`error` のとき） |

### 3.3 Gemini が返す形（構造化出力）

| 項目 | 型 | 内容 |
|---|---|---|
| `officialUrl` | string \| null | 公式サイトのトップの URL |
| `officialX` | string \| null | 公式 X のユーザー名（@ なし） |
| `schedulePageUrl` | string \| null | ライブ情報を読んだページの URL |
| `lives` | array | ライブ（下）。最大 20 件 |

ライブ（`lives` の要素）：

| 項目 | 型 | 内容 |
|---|---|---|
| `title` | string | ライブ名（ツアー名・イベント名） |
| `officialUrl` | string \| null | そのライブの公式ページの URL |
| `performances` | array | 公演。最大 50 件。要素は `date`（`YYYY-MM-DD`）・`startTime`（`HH:mm` \| null）・`openTime`（`HH:mm` \| null）・`venue`・`prefecture`（47都道府県の名前 \| null）・`online`（bool） |
| `receptions` | array | 受付。最大 10 件。要素は `type`（`fc`・`general`・`upgrade`・`other`）・`name`・`applyStartAt`・`applyEndAt`・`resultAt`・`paymentDeadline`（どれも `YYYY-MM-DD` か `YYYY-MM-DDTHH:mm` \| null）・`prices`（`{seat, amount}` の配列）・`winnersOnly`（bool） |

- 日時はすべて日本時間として書かせる。

### 3.4 確かめてから登録する（Functions の処理）

**変換**

- 公演の `startAt` は `date` と `startTime`。**`startTime` が無い公演は登録しない**（9章）。`openAt` は `openTime` があるときだけ。
- 受付の日時で時刻が無いもの：`applyEndAt`・`paymentDeadline` は 23:59、`applyStartAt`・`resultAt` は 0:00。
- オンラインの公演（`online: true`）は、会場名を今の `isOnlineVenue`（`lib/utils/travel_links.dart`）がオンラインと判定できる名前にし、`prefecture` は入れない（L-1 で `isOnlineVenue` を読んで合わせる）。

**捨てるもの**

- 開演が今より前の公演。公演が1つも残らないライブ。
- 開演が今日から2年より先の公演（読み間違いとみなす）。
- `venue` が空の公演。`prefecture` が47都道府県の名前でなければ `prefecture` だけを空にする。
- `applyEndAt` が無い、または今より前の受付（`applyEndAt` は必須のため）。`type` が4種類以外のもの。料金が 0 以下・100万円以上の席種。
- URL が `http://`・`https://` で始まらないもの（その項目だけ捨てる）。

**重なりの判定**（文字は NFKC にそろえ、小文字にし、空白と記号（「」『』""・〜~ー–—-_/()（）[]【】☆★♪!！?？ など）を除いて比べる。以下「そろえた名前」）

- 比べる相手：対象の推しの ID を `groupIds`（個人なら `oshiIds`）に含むライブと、その公演・受付。
- **ライブ**：そろえた名前が同じ、または片方がもう片方を含む（どちらも6文字以上）なら同じライブ。名前が違っても、公演に「同じ日（日本時間）で、そろえた会場名が同じか片方を含む」ものがあれば同じライブ。
- **公演**：同じライブの中で、同じ日（日本時間）で、そろえた会場名が同じか片方を含むなら同じ公演。
- **受付**：同じライブの中で、`type` が同じで、そろえた名前が同じか `applyEndAt` が同じ分なら同じ受付。

**書き込み**

- 新しいライブ：ライブ・公演・受付をまとめて作る。
- 既にあるライブ：無い公演・受付だけを足す（ライブの項目は変えない）。足した公演には今の「追加」の印が出る（ライブより後に作られた公演）。
- 1回の取得の書き込みは1つのバッチ（500件以内）。変更履歴（`history`）は作らない（新規作成だけのため）。

### 3.5 Gemini の呼び出し（2段階）

確実に動くように、**検索と読み取り**と**JSON にする処理**を分けて2回呼ぶ。

| 段 | ツール | 中身 |
|---|---|---|
| 1. 調べる | Google 検索（`googleSearch`）・URL コンテキスト（`urlContext`） | 推しの名前・別名・ジャンル・（あれば）公式サイトの URL と今日の日付を渡し、「公式サイトのライブ・ツアー・イベントのページを読み、今日以降の公演と受付を書き出す」よう頼む。公式サイト（と公式サイトからリンクされた公式のチケットページ）に書いてあることだけを書き、分からないことは「不明」と書く。推測しない。文章のまとめでよい |
| 2. JSON にする | なし（`responseMimeType: 'application/json'` と 3.3 のスキーマ） | 1段目の文章を 3.3 の形に変える。書いていないことは null |

- 1段目の結果から、グラウンディングの情報（`groundingMetadata.webSearchQueries`）を `searchQueries` として残す（最大5件）。
- モデル名は `functions/live_fetch/gemini.js` の定数 `GEMINI_MODEL` にまとめる。Flash 系の新しいモデルを使う（L-1 の着手時に、Vertex AI で使えるモデル名を人がコンソールで確かめて入れる）。
- `@google/genai` を Vertex AI のモード（`vertexai: true`・`project` は `process.env.GCLOUD_PROJECT`・`location: 'global'`）で使う。
- 2回の呼び出しのどちらかが失敗したら、`liveFetch.status: 'error'` にして何も登録しない。

### 3.6 robots.txt とページの確認

- **robots.txt**：`schedulePageUrl`（無ければ `officialUrl`）のオリジンの `/robots.txt` を取り、`robots-parser` でユーザーエージェント `OshiashiBot` として許可されているかを見る。取れない（404 など）ときは許可とみなす。禁止なら、その回の取得をやめて `status: 'blocked'`。
  - 1段目より前に `officialUrl` が分かっていれば、そのときに確かめる。分かっていなければ、2段目の結果の `schedulePageUrl` で確かめ、禁止なら結果を捨てる。
- **ページの確認（毎日の取得だけ）**：`schedulePageUrl` を取得し（タイムアウト 15秒、ユーザーエージェント `OshiashiBot/1.0`）、`<script>`・`<style>` とタグを除いた文字の SHA-256 を `pageHash` と比べる。同じで、`lastGeminiAt` が7日以内なら Gemini を呼ばない（終わる）。違う・7日を過ぎた・取得できないときは Gemini を呼ぶ。
  - 画面を JavaScript で作るサイトは中身が変わらないように見えるため、7日ごとには必ず取り直す。

## 4. 決定事項：Cloud Functions

ファイルの構成（どれも `functions/` の下。リージョンは今と同じ `asia-northeast1`）：

| ファイル | 中身 |
|---|---|
| `functions/live_fetch/gemini.js` | 3.5（2段階の呼び出し・スキーマ・`GEMINI_MODEL`） |
| `functions/live_fetch/normalize.js` | 3.4 の変換・捨てるもの・名前をそろえる関数 |
| `functions/live_fetch/upsert.js` | 3.4 の重なりの判定と書き込み |
| `functions/live_fetch/page_check.js` | 3.6（robots.txt・ページのハッシュ） |
| `functions/live_fetch/run.js` | `runLiveFetch(kind, id, { mode })`：状態の記録（3.2）→ 3.5 → 3.4 をまとめて行う。`mode` は `manual`・`approved`・`daily` |
| `functions/index.js` | 下の3つの関数を足す |

### 4.1 Callable 関数 `fetchOshiLives`（手動の取得）

| 入力 | 内容 |
|---|---|
| `kind` | `group`・`person` |
| `id` | 推しの ID |

| 出力 | 内容 |
|---|---|
| `status` | `ok`・`noOfficialSite`・`blocked`・`skipped`（デモ用・承認前） |
| `added` | 足した件数（`lives`・`performances`・`receptions`） |
| `lives` | 足した・公演や受付を足したライブ（`{id, title, isNew}` の配列） |
| `officialUrl` | 公式サイトの URL（分かれば） |
| `searchQueries` | Google 検索の語 |

- ログインしていない呼び出しは拒否（`unauthenticated`）。App Check などの設定は `getEventWeather` にそろえる。
- 推しが無い・承認前・`demo-` で始まるときは `status: 'skipped'`。
- `liveFetch.startedAt` が10分以内なら `resource-exhausted`（取得中も含む）。始めるときはトランザクションで `status: 'running'`・`startedAt` を書く（重なりを防ぐ）。
- `timeoutSeconds: 300`・`memory: '512MiB'`。
- 失敗は `internal`（`liveFetch` に `status: 'error'`・`message`）。

### 4.2 承認のトリガー `onOshiApprovedFetchLives`

- `onDocumentUpdated('groups/{id}')` と `onDocumentUpdated('oshis/{id}')` の2つ（中身は共通）。
- 更新前の `status` が `approved` 以外で、更新後が `approved`、ID が `demo-` で始まらないときだけ `runLiveFetch(kind, id, { mode: 'approved' })`。
- 失敗しても再試行しない（`retry: false`）。

### 4.3 毎日の取得 `dailyLiveFetch`

- `onSchedule({ schedule: '10 4 * * *', timeZone: 'Asia/Tokyo', timeoutSeconds: 540 })`。
- 対象：承認済みで `demo-` で始まらない推しのうち、**フォローしている人が1人以上いるもの**（`users` を `followingGroupIds`／`followingOshiIds` の `array-contains` で1件だけ探す）。
- 1件ずつ順に `runLiveFetch(kind, id, { mode: 'daily' })`（3.6 のページの確認で、変わっていなければ Gemini を呼ばない）。1回で最大 30件。取得中（`startedAt` が10分以内で `running`）のものは飛ばす。
- 1件の失敗で全体を止めない。

## 5. 決定事項：アプリ

### 5.1 入口「公式サイトからライブを探す」

- **推しの行の ⋮**（`lib/features/oshi/oshi_list_tile.dart` の ⋮。Fd 5.3）に「公式サイトからライブを探す」（アイコン `Icons.travel_explore`）を足す。承認済みで `demo-` で始まらない推しのときだけ出す。
- **ライブ一覧の「◯◯の今後のライブ」**（Fd 3.3）の見出しの右に、小さなボタン「公式サイトから探す」。同じ条件のときだけ出す。
- 押した後の流れは共通（`lib/features/live_fetch/live_fetch_dialog.dart` の `showLiveFetchDialog(context, ref, kind, id, name)`）：
  1. ダイアログ「公式サイトからライブを探しています」（くるくると「1分ほどかかります」）。閉じられないようにする。
  2. `fetchOshiLives` を呼ぶ（`HttpsCallableOptions(timeout: Duration(minutes: 5))`）。
  3. 結果を同じダイアログに出す（5.2）。

### 5.2 結果の表示

- `ok` で足したものがあるとき：「ライブ n件・公演 n件・受付 n件を登録しました」。下に足したライブの行（新しいライブは「新規」、既にあったライブは「公演・受付を追加」のチップ）。行を押すとライブ詳細（`/lives/{id}`）。
- `ok` で足したものが無いとき：「新しいライブは見つかりませんでした」。
- `noOfficialSite`：「公式サイトが見つかりませんでした」。`blocked`：「この公式サイトは自動での取得が許可されていないため、取得しませんでした」。`skipped`：「この推しは対象外です」。
- `resource-exhausted`：「少し時間をおいてからもう一度お試しください」。そのほかのエラー：「取得できませんでした」。
- どの結果でも、`searchQueries` があれば「Google で検索」の見出しと、語ごとのチップ（押すと `https://www.google.com/search?q=<語>` を外部のブラウザで開く）を出す（5.3）。`officialUrl` があれば「公式サイト」のリンク。
- 閉じるボタン「閉じる」。

### 5.3 AI が登録したものの表示（ライブ詳細）

- ライブの `source` が `'ai'` なら、ライブ名の下に小さな札「AI が公式サイトから登録」（`Icons.auto_awesome`）と、その下に「出典」（`sourceUrls` の1つ目のドメイン。押すと外部のブラウザで開く）と「Google で検索」のチップ（5.2 と同じ。`searchQueries`）。下に小さく「内容が違うときは編集で直せます。正しい情報は公式サイトでご確認ください」。
- 人が登録したライブに AI が足した公演・受付の行には、小さな札「AI」を出す。
- 共通の部品は `lib/features/live_fetch/ai_source_widgets.dart`（`AiSourceBadge`・`AiSourceSection`・`GoogleSearchChips`）にまとめる。

## 6. 人が行う設定

1. Google Cloud コンソールで **Vertex AI API**（`aiplatform.googleapis.com`）を有効にする。
2. 「IAM」で、Cloud Functions（第2世代）の実行に使うサービス アカウント（既定では `<プロジェクト番号>-compute@developer.gserviceaccount.com`）に **「Vertex AI ユーザー」** のロールを付ける。
3. Vertex AI の Model Garden で、使える Gemini の Flash 系のモデル名を確かめ、`GEMINI_MODEL` に入れる（3.5）。
4. `cd functions && npm install @google/genai robots-parser`。
5. `firebase deploy --only functions`（L-3 でルールを変えたときは `firestore:rules` も）。
6. `markdown/deploy_手順.md` に 1〜5 を追記する（L-4）。

## 7. 開発ステップ

| Step | 内容 | 状況 |
|---|---|---|
| L-1 | Functions の中身：`gemini.js`・`normalize.js`・`upsert.js`・`page_check.js`・`run.js`（3章） | 未着手 |
| L-2 | Functions の入口：`fetchOshiLives`・`onOshiApprovedFetchLives`・`dailyLiveFetch`（4章）。人が 6章の 1〜5 を行う | 未着手 |
| L-3 | アプリ：モデルの項目（3.1）・ルールの確認・入口とダイアログ（5.1・5.2）・ライブ詳細の表示（5.3） | 未着手 |
| L-4 | 実在の推しで確認（8章）。`deploy_手順.md` に追記 | 未着手 |

- L-4 の実在の推しは、デモ用データを入れたあと、アプリの「推しを申請する」から申請し、Firebase コンソールで `status` を `approved` に書き換えて足す（4.2 のトリガーが動く）。**デモ用データを入れ直す（`firestore:delete --all-collections`）と実在の推しも消えるので、入れ直したあとに申請と承認をやり直す。**
- 実在の推しは、公式サイトにツアーの日程が文字で載っていて（画像だけではない）、今後の公演が多いものを選ぶ。使う前に、その公式サイトの利用規約で自動の取得が禁止されていないかを人が確かめる。

## 8. 確認すること

1. 実在の推しを承認すると、1〜2分でその推しのライブがライブ一覧の「◯◯の今後のライブ」に出る。公式サイトの URL が空だった場合は埋まる。
2. ライブ詳細に「AI が公式サイトから登録」・出典・「Google で検索」のチップが出て、日時・会場・受付が公式サイトと合っている。
3. 推しの行の ⋮ から「公式サイトからライブを探す」を押すと、ダイアログに結果が出る。続けてもう一度押すと「新しいライブは見つかりませんでした」になり、ライブが二重に登録されない。10分以内にもう一度押すと「少し時間をおいて…」になる。
4. AI が登録したライブを人が編集して保存できる（ルールで拒否されない）。保存しても `source` が消えない。
5. デモ用の推し（`demo-` で始まる）の ⋮ とライブ一覧には、ボタンが出ない。
6. Functions のログにエラーが無い。`dailyLiveFetch` をコンソールから手動で動かすと、ページが変わっていない推しでは Gemini を呼ばずに終わる。

## 9. 未決定事項

- 開演時刻が「未定」の公演の扱い（今は登録しない。日付だけで登録するなら、`startTimeUnknown` のような項目と、画面で「時間未定」と出す変更が要る）。
- 推しの詳細画面（`add_D.md`）を作るなら、そこにも入口と `liveFetch` の状態（最後に取得した日時・公式サイト）を出すか。
- 検索の候補の表示：今は語のチップから Google 検索を開く形。グラウンディングの結果が返す検索候補の HTML（`searchEntryPoint.renderedContent`）を、そのまま画面に出す形にするか（Flutter Web で HTML を出す仕組みが要る）。
- 新しく登録された受付を、その推しをフォローしている人に通知するか（add_S の通知に足す）。
- 公式 X やチケットサイト（プレイガイド）の情報も読むか（今は公式サイトと、そこからリンクされた公式のチケットページだけ）。
- 一般公開するとき、利用規約・権利の確認をどこまで行うか。