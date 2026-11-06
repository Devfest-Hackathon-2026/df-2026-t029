# 公開（デプロイ）の手順と確認項目

> 人が行う手順書（Step7 の L2）。エージェントは `firebase deploy` を実行しない。
> Firebase プロジェクトは `oshiashi-test`（Spark プラン）。公開先の URL は `https://oshiashi-test.web.app`（`https://oshiashi-test.firebaseapp.com` でも開ける）。
> 審査の必須条件: Google Cloud の実行基盤（Firebase Hosting）で動いていること、**デプロイ URL を 11/14 まで稼働させること**、API キーに利用制限をかけること。

## 0. 事前の準備（初回だけ）

1. Dev Container で `firebase login` 済みであること（`firebase projects:list` に `oshiashi-test` が出る）。
2. 下の「2. コンソールでの設定」の 2.4（App Check のサイトキー）を先に済ませ、**reCAPTCHA v3 のサイトキー**を手元に用意する。サイトキーはリポジトリに書かない（コミットしない）。

## 1. ビルドと公開

### 1.1 ビルド

```bash
flutter pub get
flutter build web --release --dart-define=APP_CHECK_SITE_KEY=<reCAPTCHA v3 のサイトキー>
```

- サイトキーを渡さずにビルドすると、App Check は無効のまま動く（アプリ自体は動く）。
- 出力は `build/web`。`firebase.json` の Hosting の設定がこのフォルダを公開する（すべてのパスを `/index.html` に書き換えるので、`/lives/xxx` を直接開いても表示される）。

### 1.2 まずプレビューに公開して確かめる

```bash
firebase hosting:channel:deploy preview --expires 7d
```

- 表示された URL（`https://oshiashi-test--preview-xxxxxxxx.web.app`）を開き、「3. 公開後の確認」を行う。
- **プレビューの URL では Google ログインがそのままでは失敗する**。2.1 で、表示されたドメインを Authentication の承認済みドメインに一時的に足す（確認後に消してよい）。

### 1.3 本番に公開

```bash
firebase deploy --only hosting
```

### 1.4 ルールとインデックス（変えたときだけ）

```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

- **Step7 では `firestore.rules` と `firestore.indexes.json` は変えていない**（監査の結果、重大な指摘が無かったため）。dev にほかの変更が入っていなければ、デプロイは不要。
- `firestore.rules` は横山さんと共有なので、デプロイの前に一声かける。
- インデックスは作成に数分かかる。コンソールの「Firestore → インデックス」で「有効」になるまで、該当の画面（グッズ交換の掲示板・マッチング・チャット一覧）がエラーになることがある。

## 2. コンソールでの設定

### 2.1 Firebase Authentication の承認済みドメイン

Firebase コンソール → Authentication → 設定 → 承認済みドメイン に、次があることを確かめる。

- `localhost`
- `oshiashi-test.firebaseapp.com`
- `oshiashi-test.web.app`
- （プレビューで確かめるときだけ）`oshiashi-test--preview-xxxxxxxx.web.app`

### 2.2 Google カレンダー連携（OAuth 同意画面）

カレンダー連携は、Firebase の Google ログインのポップアップで `calendar.events` の権限を求めている（`lib/services/google_calendar_service.dart`）。

- Google Cloud コンソール → API とサービス → **Google Calendar API が有効**であること。
- OAuth 同意画面:
  - `calendar.events` は「機密性の高いスコープ」。公開ステータスが **テスト** の間は、**テストユーザーに登録したアカウントしか**カレンダーの権限を許可できない（ほかの人は「アクセスをブロック」になる）。
  - デモに使うアカウントと、チームのアカウントをテストユーザーに足す。
  - **審査員が自分のアカウントでカレンダー連携を試すと失敗する**。提出物の説明に「カレンダー連携はテストユーザーのみ（Google の審査が必要なため）」と書くか、デモ動画で見せる。チームで方針を決める。
- アプリ名・サポートのメールアドレスが入っていること。

### 2.3 Firebase AI Logic（スクショ読み取り）

- Firebase コンソール → AI Logic で、Gemini Developer API が有効になっていること（スクショ読み取りが動いていれば済んでいる）。

### 2.4 App Check（reCAPTCHA v3。最初は監視だけ）

1. Google Cloud コンソール → **reCAPTCHA**（または https://www.google.com/recaptcha/admin ）で **v3** のキーを作る。ドメインに `oshiashi-test.web.app`・`oshiashi-test.firebaseapp.com`・`localhost` を入れる。サイトキーとシークレットキーができる。
2. Firebase コンソール → App Check → アプリ（Web）→ reCAPTCHA v3 を選び、**シークレットキー**を登録する。
3. **サイトキー**は 1.1 のビルドで `--dart-define` に渡す。リポジトリには書かない。
4. この時点では「適用（Enforce）」しない。App Check → API の画面で、Cloud Firestore と Firebase AI Logic のリクエストを**監視**する。
5. 公開して数日、「検証済み」のリクエストが大半になっていることを確かめてから、Cloud Firestore と AI Logic を「適用」に切り替える（**適用を誤ると、公開したアプリが動かなくなる**。審査期間中に切り替えるかはチームで決める）。

- ローカル（`flutter run`）で開発するとき: サイトキーを渡さないデバッグ実行では、デバッグ用プロバイダが使われ、ブラウザのコンソールに **デバッグトークン** が出る。適用に切り替えた後もローカルで動かすには、そのトークンを App Check → アプリ → デバッグトークンの管理 に登録する（トークンもコミットしない）。
- reCAPTCHA のバッジは CSS で隠し、ログイン画面に「reCAPTCHA で保護されている」旨と Google のプライバシーポリシー・利用規約へのリンクを出している（Google の条件。ユーザーの判断）。

### 2.5 API キーの利用制限（審査の必須条件）

Google Cloud コンソール → API とサービス → 認証情報 → `lib/firebase_options.dart` の Web 用 API キー（「Browser key (auto created by Firebase)」）:

- **アプリケーションの制限**: 「ウェブサイト」（HTTP リファラー）にし、次だけを許可する。
  - `https://oshiashi-test.web.app/*`
  - `https://oshiashi-test.firebaseapp.com/*`（ログインのポップアップが使う。消すとログインできない）
  - `https://oshiashi-test--*.web.app/*`（プレビュー）
  - `http://localhost:8080/*`
- **API の制限**は、かけるなら Firebase が使う API（Identity Toolkit・Token Service・Cloud Firestore・Firebase Installations・Firebase App Check・Firebase AI Logic〔Generative Language〕など）をすべて含めること。足りないと、その機能だけが動かなくなる。まずはアプリケーションの制限だけにして、動作を確かめてから API の制限を検討する。
- 設定は反映まで数分かかる。設定後に「3. 公開後の確認」をもう一度行う。

### 2.6 予算アラート

- 今は Spark（無料）なので請求は発生しない。**Blaze に切り替えたとき**（Step6 の通知など）は、Google Cloud コンソール → お支払い → 予算とアラート で、少額（例: 1,000 円）の予算アラートを作る。

## 3. 公開後の確認

プレビュー・本番の両方で、PC の Chrome とスマホのブラウザで確かめる。

1. ログイン: Google ログインができる。ログイン画面に reCAPTCHA の文言とリンクが出ている。
2. 推し: 推しを探してフォローできる。追加申請ができる。
3. ライブ: 「ライブを追加する」から自分のライブ一覧に追加できる。手入力でライブ・公演・受付を登録できる。
4. 当選者のみ: アプグレ（当選者のみ）の受付は、当選していないと次の締切・ライブ詳細に出ず、「当選すると表示される受付が n 件あります」と出る。通常の受付を「当選」にすると出る。ライブの編集では当選していなくても見える。
5. スクショ読み取り: 告知画像から抽出し、確認・修正して保存できる。
6. カレンダー連携: （テストユーザーのアカウントで）保存後のシートから Google カレンダーに予定を追加できる。
7. グッズ交換: 掲示板・マッチング・チャット一覧が開ける（インデックスのエラーが出ない）。
8. 直接開く: `https://oshiashi-test.web.app/lives/<ライブの ID>` をアドレスバーに入れて開ける。再読み込みしても表示される。
9. 更新: 公開し直した後、再読み込みで新しい版が出る（`index.html`・`main.dart.js` などはキャッシュしない設定）。
10. App Check: App Check の API の画面に、公開したアプリからのリクエストが「検証済み」として数えられている。
11. API キー: 許可していないサイトからは使えない（2.5 の設定が入っている）。

## 4. デモ用データ（架空）

`tools/seed/`（詳しくは `tools/seed/README.md`）。グループ「ステラノート」・メンバー3人・ソロ1人、ライブ3件、公演5件、受付5件を入れる。ドキュメント ID は `demo-` で始まり、何度入れても重複しない。日時は基準日（省略すると今日）からの相対。

```bash
cd tools/seed
npm install          # 初回のみ
```

- エミュレータ（ローカルでの確認）:

  ```bash
  firebase emulators:exec --only firestore --project demo-oshiashi "node tools/seed/seed_demo.mjs --emulator"
  ```

  （`emulators:exec` は終わるとデータが消える。中身を見たいときは、別のターミナルで `firebase emulators:start --only firestore` を起動しておき、`node tools/seed/seed_demo.mjs --emulator` を実行する。**アプリはエミュレータにつながない作りなので、エミュレータに入れたデータはアプリには出ない**。エミュレータはスクリプトの動作確認用。アプリで見るときは、下の本番に入れる）

- 本番（`oshiashi-test`）:

  ```bash
  gcloud auth application-default login      # または GOOGLE_APPLICATION_CREDENTIALS=<リポジトリの外の鍵>
  node tools/seed/seed_demo.mjs --project oshiashi-test --base 2026-11-09   # デモの撮影日に合わせる
  node tools/seed/seed_demo.mjs --project oshiashi-test --delete            # 消す
  ```

- サービスアカウントの鍵は**リポジトリの外**に置く。鍵・トークンをコミットしない。
- 入れた推しをフォローし、「ライブを追加する」から自分のライブ一覧に追加すると、ホームの次の締切に出る（自分のライブ一覧・申込状況はスクリプトでは入れない）。
- **デモ動画では、シードした架空のデータであることを字幕などで明示する**（デモの偽装にならないように。ハッカソンのルール）。
- `--delete` は `demo-` のドキュメントだけを消す。アプリで作った自分のライブ一覧・申込状況は残るので、気になるときはアプリから外す。
