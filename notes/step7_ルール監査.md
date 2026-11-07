# Firestore ルールの監査（Step7 Q2）

2026-11-06 qa。対象: `firestore.rules`（946行・全コレクション）。観点は `firebase-security-rules-auditor`（create と update の差、権限の出どころ、hasOnly と所有者検査、サイズ・型、OR で効く広いルール）。方法はルールを読んで経路をたどった（エミュレータでの再現は、下の「重大」が無いため行っていない）。

重さの基準: 他人の個人データを読める・書ける・消せる＝重大／共通データの改ざんや仕様とのずれ＝中／自分のデータだけの崩れ・容量・読みやすさ＝軽微。

## 結論

- **重大は 0 件**（A の担当・横山さんの担当とも）。他人の `users/**`、`chats`・`messages`、`tradePosts` の更新、返信の承認を、本人以外が読み書きする経路は見つからなかった。
- OR で広く効くルールによる素通りは無い。`users/{userId}/{subcollection}/{document=**}` は `applications`・`myLives` を除外済みで、専用ルールが効いている。ルールに書かれていないパスは既定で拒否される。
- 中が 3 件（A 2、横山さん 1＋1）、軽微が複数。

## 指摘

| # | 重さ | 担当 | コレクション | 内容 | 直し方の案 |
|---|---|---|---|---|---|
| 1 | 中 | A | lives / performances / receptions | 更新と変更履歴が別々に書ける。履歴の作成は「同じバッチで親を更新していること」を要求するが、**親の更新は履歴なしでも通る**。誰でも履歴を残さずにライブ・公演・受付を書き換えられ、「誤った更新は履歴から戻す」（Database_config 7章）が成り立たない | 更新のルールで、同じバッチに履歴があることを `existsAfter` で要求する（履歴の ID が事前に分からないため難しい）。難しければ、ユーザーに「既知の限界」として示し、判断ログに残す（Step4 の決定の範囲） |
| 2 | 中 | A | performances / receptions | 既存ライブへの公演・受付の追加と更新が、ログイン済みなら誰でも可（Step4 の決定）。件数の上限が無く、1つのライブに大量の公演・受付を足せる | 件数はルールでは数えられない。App Check（4.3・監視のみ）と、運営の掃除（コンソール）で対応する。今は記録だけでよい |
| 3 | 中 | 横山さん | goods | 更新で `variants` は**件数が減らないことしか検査していない**。他人が既存の種類の `id`・`name` を書き換えられ、投稿の検索用キー（`item:{goodsId}#{variantId}`）やマッチングが壊れる | 更新時に、既存の `variants[i].id` が保たれることを（件数の上限が小さいので）数個ずつ検査する。または、書き換えを許す仕様なら現状のままにし、横山さんに確認する |
| 4 | 軽微 | 横山さん | chats | 更新で `lastMessage` を、メッセージを作らずに書き換えられる（参加者2人のどちらも）。一覧に偽の「最後のメッセージ」を出せる。相手のデータではなくチャットの当事者だけの範囲 | メッセージの作成と同じバッチを要求する（getAfter でメッセージの存在を調べるには ID が要る）。現状のままでよい |
| 5 | 軽微 | 横山さん | chats / messages | `status: closed`（取引終了）でも、メッセージを送れる | `isValidNewMessage` で `getAfter(chat).status == 'open'` を要求する。仕様の確認が先 |
| 6 | 軽微 | 横山さん | chats | チャットの `get` は、存在しないときも許す設計（承認前の確認のため）。存在する非参加者のチャットは拒否されるので、**存在の有無（`{postId}_{uid}`）だけ**が分かる。内容は漏れない | 現状のままでよい |
| 7 | 軽微 | 横山さん | tradePosts / replies / chats | `displayName`（`memberNames`）は本人が自由に書ける。他人の名前を名乗れる | 今は直せない（`users` は本人しか読めないため複製している設計）。記録のみ |
| 8 | 軽微 | 横山さん | tradePosts / goods | 配列の要素（`gives`・`wants`・`variants`）の中身と大きさを検査していない（ルールの冒頭に既知として記載）。1ドキュメント 1MB まで書ける。`giveKeys` を偽って、自分の投稿を偽のマッチに見せることもできる（影響は自分の投稿のみ） | 現状のままでよい |
| 9 | 軽微 | A / 横山さん | history（4つ） | `before` が型・大きさを問わず（既知の限界としてコメントあり）。`field` の項目名の検査は lives・performances・receptions にはあるが、**goods の history には無い**（任意の 1〜50 文字の項目名を書ける） | goods の history にも項目名の検査を足す（任意） |
| 10 | 軽微 | A | users / users/**/test | `users/{uid}` と、`applications`・`myLives` 以外のサブコレクションに、本人なら任意の項目・任意のドキュメントを書ける（動作確認用のルールの残り）。自分の容量だけの問題 | 公開前に、`users/{uid}/{subcollection}` の汎用ルールを消すか、使っているサブコレクション名だけに絞る。`test` を使うコードが無ければ消せる（data が確認） |
| 11 | 軽微 | A | lives / performances / receptions | `createdBy`・`updatedBy` の uid が全員に見える（共通データの設計） | 設計どおり。記録のみ |
| 12 | 軽微 | 横山さん | replies | 同じ投稿に、同じ人が返信を何件でも作れる（スパム） | App Check（監視のみ）で様子を見る |

## 確認できたこと（問題なし）

- groups / oshis: 作成は `pending` のみ・項目の検査あり、更新・削除は拒否。
- users: 本人のみ。`createdAt` は変更不可。`applications` は status・liveId・サーバー時刻を検査、本人のみ。
- myLives: 項目は `addedAt` だけ、サーバー時刻、ライブの存在を検査。
- lives: 出演者を減らせない（`hasAll`）、`createdBy`・`createdAt` は変更不可、削除不可。
- performances / receptions: `liveId` 変更不可、出演者はライブと同じ、料金は形を検査。
- tradePosts: 作成者のみ更新、`hidden` は作成者以外に読めず作成者も更新不可、`uid`・`createdAt` は変更不可、削除不可。
- replies: 承認は投稿者のみ・false→true のみ・自分の返信は不可・同じバッチでチャットを作る場合のみ。削除は本人かつ承認前。
- chats / messages: 作成は投稿者のみ（返信の承認と同じバッチ）、参加者2人固定、更新は4項目のみ、既読は自分の分だけ、メッセージは参加者のみ・更新削除不可。

## インデックスの確認（D3 が記入）

アプリの `lib/` のクエリを洗い出した結果（data が記入。`collectionGroup` のクエリは無い）。**`firestore.indexes.json` に足すものは無い。**

| クエリ（ファイル） | 条件 | 必要なインデックス | 対応 |
|---|---|---|---|
| 自分の投稿（trade_post_repository `watchMine`） | `uid ==` ＋ `orderBy updatedAt desc` | 複合 | あり（uid ↑・updatedAt ↓） |
| 推しの募集中の投稿（`watchOpenFor`・グループ） | `groupIds array-contains` ＋ `status ==` ＋ `orderBy updatedAt desc` | 複合 | あり |
| 同（個人） | `oshiIds array-contains` ＋ `status ==` ＋ `orderBy updatedAt desc` | 複合 | あり |
| マッチング（`fetchOpenGiving`） | `giveKeys array-contains-any` ＋ `status ==`（orderBy なし） | 複合 | あり（giveKeys 配列・status ↑） |
| チャット一覧（trade_chat_repository） | `memberUids array-contains` ＋ `orderBy lastMessageAt desc` | 複合 | あり |
| 返信（trade_reply_repository） | `orderBy createdAt`（サブコレクション） | 単一項目 | 自動 |
| メッセージ（`watchMessages`） | `orderBy createdAt`（サブコレクション） | 単一項目 | 自動 |
| 公演・受付（live_repository） | `liveId ==`、`liveId in`（並び替えはアプリ側） | 単一項目 | 自動 |
| ライブ・公演・受付の検索 | `groupIds` / `oshiIds array-contains-any`、`documentId in` | 単一項目 | 自動 |
| グッズ（goods_repository） | `groupIds` / `oshiIds array-contains-any` | 単一項目 | 自動 |
| 変更履歴（`watchHistory`） | サブコレクション全件（並び替えはアプリ側） | なし | — |
| 申込状況・自分のライブ一覧 | サブコレクション全件 | なし | — |

- 範囲の条件（`<`・`>`）と、複数の `array-contains` を同時に使うクエリは無い。
- 今後 `where` と `orderBy` の組み合わせを足したら、この表に足し、`firestore.indexes.json` を確かめること。
- 指摘 #10（汎用サブコレクションのルール）の参考: アプリが `users/{uid}` の下で使うサブコレクションは `applications` と `myLives` だけ（`grep` で確認）。ルールは変えない方針（リーダー）。公開前の見直しの材料として残す。
