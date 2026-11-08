# おしあし（仮）通知の機能追加 仕様書（add_S）
 
> 本ドキュメントは、`claude/11-8 朝の機能追加の計画.md` の 4番（通知）の仕様書である。
> Step6 のリマインド通知（`claude/リマインド通知（Step6）の仕様書.md`）の仕組みに、申込開始の通知・推しの名前入りの通知・新しいマッチの通知を足す。
> 前提として、`markdown/add/add_step6.md`（Step6）・`claude/add_I.md`（推しの絵文字）・`claude/add_O.md`・`markdown/Database_config.md`・`CLAUDE.md`・`markdown/deploy_手順.md` をあわせて参照すること。
 
## 0. LLM への指示
 
- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。「7. 未決定事項」は独自に確定させず、提案として示すこと。
- 本仕様にない作業を勝手に足さないこと。**テストコードは書かない**。
- **コードの編集は人間が Dev Container 内で行う。** LLM はリポジトリを読むだけにする。変更が小さいところは変わる部分だけ、大きいところは関数・クラス・ファイル単位で丸ごと出す。**どのファイルのどこかを必ず明記し、「同じものを◯〜◯に」のようなまとめ方はしない。**
- 開発は5章のステップの順に進め、各ステップに1行程度のコミット文を添えること。画面の確認は最後にまとめて行う。
- パッケージは足さない。**`firestore.rules` は変えない**（新しい記録は `users/{uid}/sentNotifications` に置き、Functions（Admin SDK）だけが書く）。
- `firebase deploy` は人間が行う。
## 1. 概要
 
| 項目 | 内容 |
|---|---|
| 機能名 | 通知の機能追加（add_S） |
| 担当 | B（横山） |
| ブランチ | `dev` から `features/S` |
| 目的 | 申込の始まり・新しい相互マッチを逃さないようにする。通知に推しの名前を入れて、自分ごとにする |
| 状況 | S-1〜S-4 完了、S-5 確認済み（11/8） |
 
## 2. 着手前の作り（11/8 の `dev`）
 
| 対象 | 場所 | 作り |
|---|---|---|
| 締切の通知 | `functions/index.js` の `sendDeadlineReminders`（15分おき）・`remindUser` | `fcmTokens` を持つユーザーごとに、自分のライブ一覧の受付の次の締切の 1日前・3時間前に送る。記録は `users/{uid}/sentNotifications/{receptionId}_{kind}_{段階}` |
| 受付 | `receptions/{id}`（`applyStartAt`・`applyEndAt`・`resultAt`・`paymentDeadline`・`winnersOnly`・`liveId`・`name`） | |
| ライブ | `lives/{id}`（`title`・`groupIds`・`oshiIds`） | |
| フォロー | `users/{uid}`（`followingGroupIds`・`followingOshiIds`） | |
| 最推し | `users/{uid}/settings/favoriteOshi`（`kind`・`id`） | |
| 推しの絵文字 | `users/{uid}/settings/oshiEmojis`（`emojis`：`group:xxx`・`person:xxx` → 絵文字） | |
| 推しの名前 | `groups/{id}`・`oshis/{id}` の `name` | |
| 交換の投稿 | `tradePosts/{id}`（`uid`・`status`・`giveKeys`・`wantKeys`・`displayName`） | マッチの判定は `lib/utils/trade_match.dart` の `matchTradePosts`（相手の譲 ∩ 自分の求 → 片方、さらに相手の求 ∩ 自分の譲 → 相互） |
| 前面の表示 | `lib/features/common/foreground_notification_listener.dart` | `data.liveId` があれば「開く」でライブ詳細へ |
| スイッチ | `lib/features/profile/notification_switch.dart` | 「リマインド通知」。説明は締切だけ |
 
## 3. 決定事項
 
### 3.1 申込開始の通知（S-1）
 
- `sendDeadlineReminders` の中で、締切と一緒に調べる。
- 対象：自分のライブ一覧の受付で、**まだ申し込んでいない**（申込状況が無い）もの。`winnersOnly` の扱いは締切と同じ。
- タイミング：`0 < 申込開始 − 現在 ≦ 1時間`（1回だけ）。記録の ID は `{receptionId}_start_1h`。
- 内容：題名「まもなく申込開始」、本文「<ライブ名>（<受付名>）\n<申込開始の日時> から」。押すとライブ詳細。
### 3.2 推しの名前入りの通知（S-2）
 
- 締切・申込開始の通知の題名の先頭に、そのライブの推しを入れる：`【<絵文字><推しの名前>】入金期限まで あと3時間`。
- 推しの選び方：ライブの `oshiIds`（個人）・`groupIds`（グループ）のうち、自分がフォローしている推し。**最推しが入っていれば最推し**、無ければ個人 → グループの順の最初の1つ。フォロー中の推しがいなければ、今のまま（【】を付けない）。
- 絵文字は `oshiEmojis` にあれば付ける（例：`【🌙星宮ルナ】`）。
- 推しの名前は `groups`・`oshis` を `getAll` で読む（ユーザーごとに1回）。
### 3.3 新しいマッチの通知（S-3）
 
- 新しい関数 `notifyNewMatches`（Firestore のトリガー `onDocumentWritten('tradePosts/{postId}')`、`asia-northeast1`）。
- 動くとき：書き込み後の投稿が `status == 'open'` で、次のどちらか。
  - 新しく作られた
  - `status` が `open` 以外から `open` になった、または `giveKeys`・`wantKeys` が変わった
- 判定：書き込まれた投稿（新しい投稿）の `giveKeys` で `tradePosts` を `wantKeys` の `array-contains-any`（30件ずつ）で引き、コードで次に絞る：
  - `status == 'open'`、投稿者が別の人
  - 相手の `giveKeys` と新しい投稿の `wantKeys` も1つ以上一致（**相互マッチだけ**。片方マッチは送らない）
- 通知する相手：一致した**相手の投稿の投稿者**（新しい投稿を書いた本人には送らない。本人はマッチのタブで見られる）。
- 二重送信の防止：相手の `users/{相手のuid}/sentNotifications/match_{新しい投稿のID}_{相手の投稿のID}`。同じ相手に複数の投稿で一致したら、1件だけ送る（最初の組）。
- 内容：題名「新しい相互マッチ」、本文「<新しい投稿の表示名>さんの投稿と、譲と求が合っています」。押すと新しい投稿の詳細に、相手の投稿を添付した状態で開く：`/trade/<新しい投稿のID>?attach=<相手の投稿のID>`。`data.path` に同じパスを入れる。
- 相手に FCM トークンが無ければ送らない（記録も書かない）。
- インデックスは足さない（`array-contains-any` だけのクエリは単一フィールドのインデックスで足りる。`status` はコードで絞る）。
### 3.4 前面の表示とスイッチ（S-4）
 
- `ForegroundNotificationListener`：`data.path` があればそこへ、無ければ今のとおり `data.liveId` でライブ詳細へ移る。
- スイッチの説明を「申込開始（1時間前）・申込期限・当落発表・入金期限（1日前と3時間前）と、新しい相互マッチを、このブラウザへ通知します」にする。
- 通知の種類ごとのオン・オフは作らない。
## 4. データ
 
| パス | 内容 |
|---|---|
| `users/{uid}/sentNotifications/{receptionId}_start_1h` | 申込開始の通知の記録（`receptionId`・`kind: 'start'`・`stage: '1h'`・`deadlineAt`・`sentAt`） |
| `users/{uid}/sentNotifications/match_{postId}_{theirPostId}` | 新しいマッチの通知の記録（`postId`・`theirPostId`・`kind: 'match'`・`sentAt`） |
 
## 5. 開発ステップ
 
| Step | 内容 | 状況 |
|---|---|---|
| S-1 | 申込開始の通知（`functions/index.js` の `remindUser`） | 完了（S-2 と1つのコミット） |
| S-2 | 推しの名前入りの題名（`functions/index.js`） | 完了 |
| S-3 | 新しいマッチの通知（`functions/index.js` の `notifyNewMatches`） | 完了 |
| S-4 | 前面の表示（`data.path`）とスイッチの説明。`deploy_手順.md`・`Database_config.md` の追記 | 完了 |
| S-5 | デプロイと確認 | 完了（11/8。下の 6.1） |
 
## 6. 確認すること
 
1. 申込開始が1時間以内の受付（未申込）があると、強制実行で「まもなく申込開始」が届く。2回目は届かない。
2. 締切の通知の題名に【推しの名前】が付く。最推しのライブなら最推しの名前。
3. 別のアカウント（または Firestore に直接作ったデモの投稿）と相互マッチする投稿を作ると、相手に「新しい相互マッチ」が届く（相手のブラウザで通知をオンにしておく）。押すと投稿の詳細が添付付きで開く。片方マッチでは届かない。
4. Functions のログにエラーが無い。
### 6.1 確認の結果（11/8 12:05）
 
- デプロイ：`notifyNewMatches` は初回に Eventarc の権限の反映待ちで失敗し、数分後の再デプロイで成功。
- S-3：`demo-post-partner-1`（いるか）の `giveKeys`・`wantKeys` をコンソールで書き換え → ログ「新しいマッチの通知: 投稿 demo-post-partner-1、相手 1 人、送信 1 件」が2回（`demo-post-ken-2`・`demo-post-ken-1` との組）。けんの `sentNotifications` に `match_demo-post-partner-1_demo-post-ken-1`・`..._ken-2`。書き換えは元に戻した。**撮影でもう一度見せるときは、この2件の記録を消す。**
- S-1：`demo-rec-luminous-release-ticket` の `applyStartAt` を30分後にして強制実行 → 「送信 1 件」、記録 `demo-rec-luminous-release-ticket_start_1h`。`applyStartAt` は 11/7 12:00 に戻した。
- S-2：題名（【ルミナス☆ガーデン】が付くか）は、ブラウザに届いた通知で人が確認する。
## 7. 未決定事項
 
- 推しの記念日の通知（当日の朝。`oshiDays` を使う）。
- 新しいマッチを、投稿した本人にも知らせるか（アプリ内のバッジなど）。
- 片方マッチも通知するか。
 