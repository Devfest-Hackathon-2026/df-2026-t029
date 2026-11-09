# デモ用データのスクリプト

## まっさらにして入れ直す（おすすめの順）

```bash
cd tools/seed
node reset_shared.mjs --project oshiashi-test          # お試し：消す件数を見るだけ
node reset_shared.mjs --project oshiashi-test --yes    # 共有データを全部消す（users/・publicProfiles/ は残す）
node seed_demo.mjs --project oshiashi-test --base <撮影の日 YYYY-MM-DD> --uid <デモ用アカウントの uid> --name けん
node seed_google.mjs --project oshiashi-test --site-url https://g-palette-demo.web.app
```

- `reset_shared.mjs` は ID に関係なく、推し・ライブ・公演・受付・グッズ・投稿・チャット・お知らせ・公開メモリーを全部消す（手で入れたデータも消える。元に戻せない）。
- `seed_demo.mjs`（demo-）はライブまで入れる。グッズ交換・メモリー・締切などの画面の確認用。
- `seed_google.mjs`（gdemo-）は推しだけ入れる。ライブは架空の公式サイトから取得する（下の「Google の架空の推し」）。

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
- 入れるのは、推し（グループ7・メンバー22・ソロ3。Google にまつわるものがモチーフ）、ライブ15とその公演・受付、グッズ・交換の投稿。`--uid` を付けると個人データ（自分のライブ一覧・申込状況・メモリー・遠征・チャットなど）も入れる。

## 認証情報（リポジトリに入れない）

- サービスアカウントの鍵（JSON）は、**リポジトリの外**に置き、`GOOGLE_APPLICATION_CREDENTIALS=/リポジトリの外/key.json` で渡す。
- または `gcloud auth application-default login` を使う。
- 鍵・トークンをコミットしない（ハッカソンのルール）。

## 注意

- デモ動画では、シードしたデータであることを字幕などで明示する（偽装にならないように）。
- 入れたデータはアプリから更新できる形（`firestore.rules` の項目の検査に合う形）にしてある。
- ルールのテスト: `node --test`（`npm test`）。

## Google の架空の推し（G-Palette ほか。ライブは公式サイトから取得）

`seed_google.mjs` は、架空の公式サイト（`demo_site/`）と組み合わせて使う。入れるのは **推しだけ**（グループ3・メンバー10・ソロ1）。ライブは入れない。

```bash
# 先に demo_site/ を公開しておく（demo_site/README.md）
node seed_google.mjs --project oshiashi-test --site-url https://g-palette-demo.web.app
node seed_google.mjs --project oshiashi-test --delete
```

- ID は `gdemo-` で始まる。`demo-` にしないのは、`functions/live_fetch` が `demo-` の推しを取得の対象外にしているため。
- 推しの名前・公式サイトのパスは `demo_site/site_data.mjs` から読む（1か所で決める）。
- 入れたあと、アプリで推しを開いて「ライブ情報を取得」を押すと、公式サイトからライブ・公演・受付が入る。
  メンバー（グループに入っている個人）は取得の対象外なので、グループで取得する。
- `--delete` は、`gdemo-` の推しと、その推しに付いたライブ・公演・受付・お知らせを消す（取得したもの・スクショから追加したものを含む）。フォローの記録と `users/{uid}` 以下は消さない。
