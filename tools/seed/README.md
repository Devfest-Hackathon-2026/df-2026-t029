# デモ用データのスクリプト

架空の推し・ライブ・公演・受付を Firestore に入れる・消す。すべて架空で、実在の人物・団体・作品とは関係がない。

## 使い方

```bash
cd tools/seed
npm install                      # 初回のみ（node_modules はコミットしない）

# エミュレータ（別のターミナルで firebase emulators:start --only firestore を起動しておく）
node seed_demo.mjs --emulator
node seed_demo.mjs --emulator --delete

# 本番（認証情報は下記）
node seed_demo.mjs --project oshiashi-test
node seed_demo.mjs --project oshiashi-test --delete
```

- `--base YYYY-MM-DD`: 基準日（日本時間）。省略すると今日。日時はすべて基準日からの相対（例: FC 先行の申込期限は基準日の2日後 23:59、アプグレの入金期限は基準日の 17:00）。デモの撮影日に合わせて指定する。
- ドキュメント ID は `demo-` で始まる固定値。何度実行しても上書きされ、重複しない。
- `--delete` は `demo-` で始まる ID のドキュメントを、サブコレクション（変更履歴）ごと消す。アプリで推しをフォローした記録や、`users/{uid}` 以下（自分のライブ一覧・申込状況）は消さない（本人のデータのため）。
- 入れるのは、推し（グループ1・メンバー3・ソロ1）、ライブ3、公演5、受付5。グッズ・投稿は入れない。

## 認証情報（リポジトリに入れない）

- サービスアカウントの鍵（JSON）は、**リポジトリの外**に置き、`GOOGLE_APPLICATION_CREDENTIALS=/リポジトリの外/key.json` で渡す。
- または `gcloud auth application-default login` を使う。
- 鍵・トークンをコミットしない（ハッカソンのルール）。

## 注意

- デモ動画では、シードしたデータであることを字幕などで明示する（偽装にならないように）。
- 入れたデータはアプリから更新できる形（`firestore.rules` の項目の検査に合う形）にしてある。
- ルールのテスト: `node --test`（`npm test`）。
