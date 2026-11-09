# おしあし（仮）推しのページとお知らせ 仕様書（add_P）

> 本ドキュメントは、11/9 にユーザー（横山）が決めた「推しのページ（公式 HP・X・YouTube の動画）」「ホームのお知らせ（最推しの新しい YouTube 動画・公式サイトから見つかった新しいライブ）」「セトリの曲から YouTube を開く」を、提出（11/10 19:00）までに作るための仕様書である。
> ねらいは、Google の技術（YouTube Data API・Gemini・Cloud Functions・Cloud Scheduler）を足し、「推しをフォローするだけで、予定も新着も届く」体験を見せること。
> 前提として、`CLAUDE.md`・`markdown/Database_config.md`・`markdown/deploy_手順.md`・`markdown/add/add_L.md`（公式サイトからの取得。この仕様書はその上に乗る）・`markdown/add/add_E.md`（Functions のシークレットの前例）・`markdown/fixes/fix_Fd.md`（推しの行の ⋮・推しの今後のライブ）をあわせて参照すること。
> 名前は「推し（Page）」の P。地図と終電は別の仕様書（add_M）で扱う。

## 0. LLM への指示

- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。「9. 未決定事項」は独自に確定させず、提案として示すこと。
- 本仕様にない作業を勝手に足さないこと。**テストコードは書かない**。
- **コードの編集は人間が Dev Container 内で行う。** LLM はリポジトリを読むだけにする。小さな変更は変わる部分だけ、大きな変更はメソッド・クラス・ファイル単位で丸ごと出す。**変更ごとにファイルの場所（パス）を書く**（「1〜3に同じものを適用」のようにまとめない）。
- 7章のステップの順に進め、各ステップに1行のコミット文を添えること。画面の確認は最後にまとめて、Claude in Chrome（人の Chrome）で行う。
- 見た目はログイン後のデザイン「ハコ色」（`lib/theme/hako_app_widgets.dart`・`brand_colors.dart`・`hako_fonts.dart`）に合わせる。
- コメントで章を書くときは「add_P 3.1」のように仕様書の名前を付ける。
- 追加してよいパッケージは無し（Functions は Node の `fetch`、アプリは今ある `url_launcher`・`web` を使う）。
- 秘密情報をリポジトリに書かない。YouTube Data API のキーは Secret Manager（`YOUTUBE_API_KEY`）に置き、Functions からだけ使う。`firebase deploy`・コンソールの設定は人間が行う。
- **権利の決まり（add_L 2.3）を守る。** お知らせに保存するのは、タイトル・URL・日時・動画の ID だけ。動画の説明文や公式サイトの文章は保存しない。サムネイルは保存せず、表示のときに YouTube の URL から読む。

## 1. 概要

| 項目 | 内容 |
|---|---|
| 名前 | add_P（推しのページとお知らせ） |
| 担当 | B（横山）。推しの画面・ホームは A（とし）と共有する |
| ブランチ | `dev` から `features/P` |
| 状況 | 仕様書を作成（11/9） |

### 1.1 できるようになること

1. 推しごとのページ（`/oshi/:kind/:id`）ができる。公式サイト・公式 X・公式 YouTube へのリンク、YouTube の最新の動画（いちばん新しいものは埋め込みで再生）、色・誕生日・推して◯日、今後のライブ、（グループなら）メンバーを1か所で見られる。
2. 推しの公式 YouTube チャンネルは、add_L の取得のときに Gemini が探して埋める（公式サイト・公式 X と同じく、空のときだけ）。
3. 3時間ごとに、フォローされている推しの YouTube の新しい動画を調べ、推しごとの「お知らせ」（共通データ）に入れる。add_L の取得で新しいライブが見つかったときも、お知らせに入れる。
4. ホームのいちばん上（あいさつの下）に「お知らせ」が出る。最推しと、その所属グループの新着だけを、新しい順に並べる。
5. メモリーのセトリで、曲を押すとその曲の YouTube の検索結果を開く。

### 1.2 使う Google の技術

| 技術 | 使い方 |
|---|---|
| YouTube Data API v3 | `channels.list`（ハンドル `@xxx` からチャンネルを特定）と `playlistItems.list`（アップロードした動画の新しい順）。どちらも1回1ユニット（1日1万ユニットの無料枠） |
| YouTube の埋め込みプレーヤー | 推しのページで最新の動画を再生する（`youtube-nocookie.com/embed`） |
| Gemini（Vertex AI・add_L） | 公式サイトから公式 YouTube チャンネルを探す（3.3 のスキーマに1項目足す） |
| Cloud Functions（第2世代） | 新着の取得（定期実行と、YouTube が登録されたときのトリガー）、お知らせの書き込み（Admin SDK） |
| Cloud Scheduler | 3時間ごとの新着の取得（`onSchedule`） |

## 2. 決定事項：方針

### 2.1 対象にする推し

- 新着を取るのは、`status` が `approved` で、**公式 YouTube が分かっていて**、**フォローしている人が1人以上いる**推し（add_L 4.3 と同じ数え方）。
- add_L の自動取得はグループとソロの個人だけだが（add_L 2.2）、公式 YouTube は**コンソールで入れればメンバーでも取る**（Gemini では埋まらないだけ）。
- デモ用データ（`demo-`）は、公式 YouTube が無いので自然に対象外になる。デモでは実在の推し（CUTIE STREET）で見せる。

### 2.2 お知らせの範囲

- お知らせは**推しごとの共通データ**（`oshiNews`）。同じ推しをフォローしている人全員が同じものを読む。YouTube の取得も推しごとに1回で済む。
- 種類は2つ：`youtube`（新しい動画）・`live`（add_L の取得で新しく登録されたライブ）。
- ホームに出すのは**最推しと、最推しの所属グループ**の新着のうち、**14日以内**のもの（最大5件）。最推しがいなければ区画ごと出さない。
- プッシュ通知は送らない（9章）。

## 3. 決定事項：データ

### 3.1 推しに足す項目

`groups/{id}`・`oshis/{id}` に足す。書くのは Functions とコンソールだけ（ルールは今のまま。アプリからは更新できない）。

| 項目 | 型 | 内容 |
|---|---|---|
| `officialYoutube` | string | 公式 YouTube。ハンドル（`@cutiestreet` のように `@` 付き）か、チャンネル ID（`UC` で始まる24文字）。**空のときだけ** Gemini が見つけたものを入れる（3.3）。コンソールで直接入れてもよい |
| `youtube` | map | 新着の取得の状態（下）。Functions だけが書く |

`youtube` の中身：

| 項目 | 型 | 内容 |
|---|---|---|
| `source` | string | `channelId` を決めたときの `officialYoutube` の値（変わったら取り直す） |
| `channelId` | string | チャンネル ID（`UC...`） |
| `title` | string | チャンネル名（リンクの表示に使う） |
| `status` | string | `ok`・`notFound`（チャンネルが見つからない）・`error` |
| `checkedAt` | timestamp | 最後に新着を調べた日時 |

- アプリのモデル `OshiSummary`（`lib/models/oshi.dart`）に `officialYoutube`・`youtubeChannelId`（`youtube.channelId`）・`youtubeTitle`（`youtube.title`）を足す（読むだけ）。`==`・`hashCode` にも足す。`OshiRequest`（申請）には足さない。

### 3.2 お知らせ `oshiNews/{newsId}`（新しいコレクション）

| 項目 | 型 | 内容 |
|---|---|---|
| `oshiKey` | string | 推しのキー（`group:xxx`・`person:xxx`。`oshiColorKey` と同じ形） |
| `oshiName` | string | 推しの名前（複製） |
| `type` | string | `youtube`・`live` |
| `title` | string | 動画のタイトル、またはライブ名（150文字まで。長ければ切る） |
| `videoId` | string | `youtube` のとき。動画の ID |
| `liveId` | string | `live` のとき。ライブの ID |
| `publishedAt` | timestamp | 動画の公開日時、またはライブを登録した日時 |
| `createdAt` | timestamp | 書き込んだ日時（サーバー時刻） |

- ドキュメント ID は `{kind}_{id}_yt_{videoId}`・`{kind}_{id}_live_{liveId}`（同じ新着を2回書かないため。書き込みは `create` で、既にあれば何もしない）。
- 動画の URL は `https://www.youtube.com/watch?v={videoId}`、サムネイルは `https://i.ytimg.com/vi/{videoId}/mqdefault.jpg`。どちらも保存せず、アプリで組み立てる。
- **ルール**：`allow read: if isAuthenticated();`、`allow write: if false;`（書くのは Functions だけ）。
- **インデックス**：`oshiNews` に `oshiKey`（昇順）・`publishedAt`（降順）の複合インデックスを `firestore.indexes.json` に足す（`oshiKey in [...]` と `orderBy('publishedAt', descending: true)` のため）。

### 3.3 Gemini のスキーマ（add_L 3.3 に1項目足す）

| 項目 | 型 | 内容 |
|---|---|---|
| `officialYoutube` | string \| null | 公式 YouTube チャンネルの URL（`https://www.youtube.com/@...` か `https://www.youtube.com/channel/UC...`）。公式サイトにリンクがあるものだけ |

- `normalize.js` で、URL から `@ハンドル` か `UC...` を取り出す（取り出せなければ null）。`run.js` で、推しの `officialYoutube` が空のときだけ書く（`officialX` と同じ）。

## 4. 決定事項：Cloud Functions

ファイルの構成（どれも `functions/` の下。リージョンは今と同じ `asia-northeast1`）：

| ファイル | 中身 |
|---|---|
| `functions/oshi_news/youtube.js` | YouTube Data API の呼び出し：`resolveChannel(officialYoutube, apiKey)`・`latestVideos(channelId, apiKey)` |
| `functions/oshi_news/news.js` | お知らせの書き込み：`writeVideoNews(db, oshi, videos)`・`writeLiveNews(db, oshi, lives)` |
| `functions/oshi_news/run.js` | `refreshOshiNews(db, kind, id, apiKey)`：チャンネルを決める → 新着を取る → 書き込む → `youtube` を更新 |
| `functions/live_fetch/gemini.js`・`normalize.js`・`run.js` | 3.3（`officialYoutube`）と 4.4（新しいライブのお知らせ） |
| `functions/index.js` | 下の関数を足す |

### 4.1 YouTube Data API の呼び出し（`youtube.js`）

- `resolveChannel`：`officialYoutube` が `UC` で始まるなら `channels.list?part=snippet&id=...`、`@` で始まるなら `channels.list?part=snippet&forHandle=...`。見つかれば `{channelId, title}`、無ければ null。
- `latestVideos`：アップロードの再生リスト（チャンネル ID の先頭の `UC` を `UU` に変えたもの）を `playlistItems.list?part=snippet&maxResults=10&playlistId=...`。返すのは `{videoId, title, publishedAt}` の配列（`snippet.resourceId.videoId`・`snippet.title`・`snippet.publishedAt`）。「Private video」「Deleted video」は除く。
- タイムアウトは 15秒。キーはクエリの `key=`。

### 4.2 新着の取得（`run.js` の `refreshOshiNews`）

1. 推しのドキュメントを読む。承認済みでない・`officialYoutube` が空なら何もしない。
2. `youtube.source` が今の `officialYoutube` と違う（または `channelId` が無い）なら、`resolveChannel` で決め直す。見つからなければ `youtube.status: 'notFound'` で終わる。
3. `latestVideos` で新しい動画（最大10件）を取り、`writeVideoNews` で書く（既にあるものは書かない）。
4. `youtube` に `source`・`channelId`・`title`・`status: 'ok'`・`checkedAt` を書く。失敗したら `status: 'error'`（例外は外に出さない）。

### 4.3 関数

| 関数 | 種類 | 中身 |
|---|---|---|
| `scheduledOshiNews` | `onSchedule({schedule: '20 */3 * * *', timeZone: 'Asia/Tokyo', timeoutSeconds: 300, secrets: [YOUTUBE_API_KEY]})` | 承認済みで `officialYoutube` があり、フォローしている人が1人以上いる推し（add_L 4.3 の `dailyLiveFetch` と同じ探し方）に、1件ずつ `refreshOshiNews`。1回で最大50件。1件の失敗で止めない |
| `onGroupYoutubeChanged`・`onOshiYoutubeChanged` | `onDocumentUpdated('groups/{id}')`・`('oshis/{id}')`、`retry: false`、`secrets: [YOUTUBE_API_KEY]` | 更新後が承認済みで、`officialYoutube` が更新の前後で変わったときだけ `refreshOshiNews`（Gemini が埋めた直後・コンソールで入れた直後に、すぐ動画が出るようにする）。`youtube` の書き込みでは `officialYoutube` が変わらないので、繰り返し動かない |

- シークレット：`const YOUTUBE_API_KEY = defineSecret("YOUTUBE_API_KEY");`（`WEATHER_API_KEY` と同じ形）。

### 4.4 新しいライブのお知らせ（add_L の `run.js`）

- `upsertLives` の結果の `lives` のうち `isNew: true` のものを、`writeLiveNews` で `type: 'live'` のお知らせにする（`publishedAt` は今）。取得のモード（`manual`・`approved`・`daily`）は問わない。
- お知らせの書き込みに失敗しても、ライブの取得は成功として扱う（ログだけ出す）。

## 5. 決定事項：アプリ

### 5.1 データの読み取り

- モデル `lib/models/oshi_news.dart`（`OshiNews`。`fromFirestore`、`videoUrl`・`thumbnailUrl` の getter）。
- リポジトリ `lib/repositories/oshi_news_repository.dart`（`watchByOshiKeys(List<String> keys, {int limit})`：`where('oshiKey', whereIn: keys).orderBy('publishedAt', descending: true).limit(limit)`。keys が空なら空のリスト）。
- プロバイダ `lib/providers/oshi_news_providers.dart`：
  - `newsKeysOf(OshiSummary oshi)`：その推しのキーと、個人なら所属グループのキー。
  - `oshiNewsProvider`（`StreamProvider.autoDispose.family`。キーの並びを `String` にまとめた引数）。
  - `favoriteOshiNewsProvider`：最推しの `newsKeysOf` で、14日以内・最大5件。

### 5.2 推しのページ（`/oshi/:kind/:id`）

- ルート：`lib/app.dart` の `/oshi` の子に `:kind/:id`（`kind` は `group`・`person`）。`lib/features/oshi/oshi_detail_page.dart` の `OshiDetailPage`。タブは「推し」のまま。推しが見つからない・承認前なら「この推しは見つかりませんでした」。
- 上から順に：
  1. **見出しの箱**：札（`OshiKindBadge`・大きめ）、名前、チップ（種別・ジャンル・所属。所属のチップを押すとそのグループのページ）、フォローのボタン、⋮（`oshiMenuItems` をそのまま）。
  2. **記念日と色**：推して◯日・誕生日（結成日）・推しの色（どれも今の個人の設定。`oshiDaysProvider`・`oshiColorsProvider`）。右に「編集」→ `showOshiColorSheet`。どれも無ければ「色・絵文字・記念日を設定する」のボタンだけ。
  3. **公式リンク**（`HakoSectionHeader('公式')`）：公式サイト・X（`https://x.com/{officialX}`）・YouTube（`youtubeChannelId` があれば `https://www.youtube.com/channel/{id}`、無ければ `officialYoutube` のハンドルで `https://www.youtube.com/{@handle}`）。あるものだけを行（`HakoRow`）で出し、押すと外部のブラウザで開く。1つも無ければ区画ごと出さない。
  4. **最新の動画**（`youtube` の新着があるとき）：いちばん新しい動画を埋め込みで出し（16:9。5.5）、その下に残り（最大4件）をサムネイル・タイトル・日付の行で出す（押すと YouTube を開く）。見出しの右に「YouTube で見る」。
  5. **お知らせ**：その推しの `live` のお知らせ（14日以内）。行を押すとライブ詳細。
  6. **今後のライブ**：今ある `OshiUpcomingLivesSection(oshi: oshi)`（`lib/features/live/oshi_upcoming_lives_section.dart`）をそのまま使う。
  7. **メンバー**（グループのとき）：今ある `GroupMembersPanel`（`lib/features/oshi/group_members_panel.dart`）を使う。
- PC の幅（本文 900 以上）では、1〜3 と 6〜7 を左、4〜5 を右の2列にする（Fe 3.4 と同じ基準）。
- **入口**：
  - 推しの行の ⋮（`lib/features/oshi/oshi_menu.dart`）の先頭に「推しのページ」（`Icons.account_circle_outlined`）。⋮ のある所（フォロー中・検索・メンバー）すべてで出る。
  - 最推しの箱（`lib/features/oshi/favorite_oshi_card.dart`）を押すと推しのページ（今のグループのメンバーのシートの代わり。メンバーはページの中で見られる）。チップ「メンバーを見る ›」は「推しのページ ›」にする。
  - ホームのお知らせの推しの名前。

### 5.3 ホームのお知らせ

- `lib/features/home/home_oshi_news.dart` の `HomeOshiNews`。ホームの `_Greeting` と `HomeOshiDays` の間に置く（1列・2列とも、いちばん上）。
- 見出し「お知らせ」（`HomeSectionHeader`。右に「推しのページ」→ 最推しのページ）。`favoriteOshiNewsProvider` が空なら区画ごと出さない。
- 1件の行：左にアイコン（`youtube`：`Icons.smart_display_outlined`、`live`：`Icons.confirmation_number_outlined`）、上に推しの名前と「◯日前」（今日なら「今日」）、下にタイトル（2行まで）。
  - `youtube`：「新しい動画」の小さな札。押すと YouTube を外部のブラウザで開く。
  - `live`：「ライブ情報」の小さな札。押すとライブ詳細（`/lives/{liveId}`）。

### 5.4 セトリの曲から YouTube（メモリーの詳細）

- `lib/features/memory/memory_detail_page.dart` のセトリの各行（`'${i + 1}. $song'`）の右に小さなアイコン（`Icons.smart_display_outlined`、ツールチップ「YouTube で探す」）。押すと `https://www.youtube.com/results?search_query=<語>` を外部のブラウザで開く。
- 語は「推しの名前 曲名」。推しの名前は、そのメモリーのライブ（`liveProvider(liveId)`）の `groupIds`・`oshiIds` の最初の推しの名前（`allOshisProvider`）。分からなければ曲名だけ。
- 行そのもの（セトリの枠を押すと編集が開く今の動き）は変えない。アイコンだけが YouTube を開く。

### 5.5 埋め込みの共通部品

- `lib/features/common/web_iframe.dart` の `WebIframe({required String src, double aspectRatio = 16 / 9})`：`HtmlElementView.fromTagName(tagName: 'iframe', onElementCreated: ...)` で `src`・`allow`（`autoplay; encrypted-media; picture-in-picture`）・`allowFullscreen`・枠なしを設定し、`AspectRatio` で包む。add_M の地図でも使う。
- YouTube の埋め込みの URL は `https://www.youtube-nocookie.com/embed/{videoId}`。
- サムネイルは `Image.network(url, webHtmlElementStrategy: WebHtmlElementStrategy.prefer)`（外部の画像の CORS を避ける）。読めないときは灰色の箱。

## 6. 人が行う設定

1. Google Cloud コンソールで **YouTube Data API v3** を有効にする。
2. 「認証情報」で API キーを作り、**API の制限で YouTube Data API v3 だけ**に絞る（サーバーから使うので、アプリケーションの制限は付けない）。
3. `firebase functions:secrets:set YOUTUBE_API_KEY`（キーは聞かれたところで貼り付ける）。
4. `firebase deploy --only functions,firestore:rules,firestore:indexes`。
5. CUTIE STREET で確かめる：⋮ の「公式サイトからライブを探す」で `officialYoutube` が埋まるのを待つか、コンソールで `groups/{CUTIE STREET の ID}` に `officialYoutube`（`@...`）を直接入れる。
6. `markdown/deploy_手順.md` に 1〜4 を追記する。

## 7. 開発ステップ

| Step | 内容 | 状況 |
|---|---|---|
| P-1 | Functions：`oshi_news/`（4.1・4.2）、`index.js` の3つの関数（4.3）、ルールとインデックス（3.2）。人が 6章の 1〜4 を行う | 未 |
| P-2 | Functions：add_L に `officialYoutube`（3.3）と新しいライブのお知らせ（4.4） | 未 |
| P-3 | アプリのデータ：`OshiSummary` の項目（3.1）、`OshiNews`・リポジトリ・プロバイダ（5.1）、`WebIframe`（5.5） | 未 |
| P-4 | 推しのページと入口（5.2） | 未 |
| P-5 | ホームのお知らせ（5.3） | 未 |
| P-6 | セトリの曲から YouTube（5.4） | 未 |
| P-7 | 確認（8章）と `deploy_手順.md` への追記 | 未 |

## 8. 確認すること

1. CUTIE STREET に `officialYoutube` が入ると、1分以内に `oshiNews` に動画が入り、`youtube.status` が `ok` になる。
2. 推しのページに、公式リンク（サイト・X・YouTube）、埋め込みの動画（再生できる）、動画の行、今後のライブ、メンバーが出る。デモ用の推しのページでは、動画の区画が出ない。
3. CUTIE STREET（またはメンバー）を最推しにすると、ホームのいちばん上に「お知らせ」が出て、動画を押すと YouTube が開く。最推しを外すと区画が消える。
4. 「公式サイトからライブを探す」で新しいライブが登録されると、お知らせに「ライブ情報」が出て、押すとライブ詳細が開く。
5. メモリーのセトリで、曲のアイコンを押すと「推しの名前 曲名」の YouTube の検索結果が開く。
6. `scheduledOshiNews` をコンソールから手動で動かすと、エラー無く終わり、同じ動画が二重に入らない。

## 9. 未決定事項

- お知らせのプッシュ通知（add_S の通知に、最推しの新着を足すか）。
- 推しのページの共通のプロフィール（メンバーカラー・誕生日を、個人の設定ではなく共通データとして Gemini で埋めるか）。今は個人の設定を出す。
- 推しの申請フォームに公式 YouTube の欄を足すか（今はコンソールか Gemini だけ）。
- 公式サイトのお知らせ（ニュース）の新着。今は新しいライブだけ。
- 共有されたメモリー（`shared-memories`）のセトリにも YouTube を出すか。
- お知らせを古いものから消すか（今は残す。件数は推しごとに多くない）。