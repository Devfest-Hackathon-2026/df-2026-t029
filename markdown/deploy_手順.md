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
flutter build web --release \
  --dart-define=APP_CHECK_SITE_KEY=<reCAPTCHA v3 のサイトキー> \
  --dart-define=FCM_VAPID_KEY=<ウェブプッシュ証明書の鍵（2.7）>
```

- サイトキーを渡さずにビルドすると、App Check は無効のまま動く（アプリ自体は動く）。
- VAPID キーを渡さずにビルドすると、リマインド通知をオンにできない（「通知の設定がされていません」と出る。アプリ自体は動く）。
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

### 1.5 Cloud Functions（リマインド通知・天気。変えたときだけ）

```bash
firebase deploy --only functions
```

- `sendDeadlineReminders`（15分おき）と `getEventWeather`（公演の日の天気。Callable）が `asia-northeast1` にデプロイされる。Blaze プランが必要。
- `getEventWeather` はシークレット `WEATHER_API_KEY` を使う（2.9）。シークレットを作る前にデプロイすると失敗する。
- 初回は必要な API の有効化を聞かれるので進める。コンテナイメージの削除ポリシーは既定の日数でよい。
- すぐに動かして確かめるときは、Google Cloud コンソール → Cloud Scheduler → `firebase-schedule-sendDeadlineReminders-...` →「強制実行」。結果は Firebase コンソール → Functions → ログで見る。

### 1.6 Storage のルール（変えたときだけ）

```bash
firebase deploy --only storage
```

- `storage.rules`。メモリーの写真（`users/{uid}/memories/...`）は本人だけが読み書きでき、作成は 5MB 未満の画像だけ。
- 推しの画像（`users/{uid}/oshiIcons/...`）は本人だけ、プロフィールのアイコン（`userIcons/{uid}/...`）はログイン済みなら読める。作成はどちらも 2MB 未満の画像だけ（add_I）。
- add_I で `firestore.rules` に公開プロフィール（`publicProfiles`）も足したので、`firebase deploy --only firestore:rules,storage` でまとめて出す。

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
- **API の制限**は、かけるなら Firebase が使う API（Identity Toolkit・Token Service・Cloud Firestore・Firebase Installations・Firebase App Check・Firebase AI Logic〔Generative Language〕・**Firebase Cloud Messaging・FCM Registration** など）をすべて含めること。足りないと、その機能だけが動かなくなる。まずはアプリケーションの制限だけにして、動作を確かめてから API の制限を検討する。

### 2.6 予算アラート

- Blaze に切り替え済み（11/7。Google Cloud 無料トライアルの請求先アカウントを紐づけ）。Google Cloud コンソール → お支払い → 予算とアラート で、少額（例: 1,000 円）の予算アラートを作る。

### 2.7 リマインド通知（Cloud Messaging）

- Firebase コンソール → プロジェクトの設定 → Cloud Messaging で、「Firebase Cloud Messaging API（V1）」が有効なことを確かめる。
- 同じ画面の「ウェブ構成」→「ウェブプッシュ証明書」で鍵ペアを生成し、公開鍵を 1.1 のビルドの `FCM_VAPID_KEY` に渡す。リポジトリには書かない。

### 2.8 Cloud Storage（写真）

- バケットは `oshiashi-test.firebasestorage.app`（場所は US-EAST1。Storage の無料枠の対象。後から変えられない）。11/7 に作成済み。
- Flutter Web で写真を表示するため、バケットに CORS を設定してある。設定し直すときは、Google Cloud コンソールの Cloud Shell で次を1行ずつ実行する。

```bash
echo '[{"origin": ["*"], "method": ["GET"], "maxAgeSeconds": 3600}]' > cors.json
gcloud storage buckets update gs://oshiashi-test.firebasestorage.app --cors-file=cors.json
```

- 確認は `gcloud storage buckets describe gs://oshiashi-test.firebasestorage.app --format="default(cors_config)"`。
- API キーの「API の制限」をかけるときは、Cloud Storage for Firebase も含める（2.5）。

### 2.9 天気（Weather API）

- Google Cloud コンソール → API とサービス → ライブラリ で **Weather API** を有効にする（11/8 済み）。
- 認証情報で Functions 用の API キーを作り、**API の制限を Weather API だけ**にする。アプリケーションの制限は付けない（サーバーから呼ぶため）。2.5 の Web 用の API キーとは別のキーにする。
- キーは Secret Manager に保存する（リポジトリには書かない）。コマンドにはシークレットの名前だけを書き、キーは聞かれたところで貼り付ける（画面には出ない）。

```bash
firebase functions:secrets:set WEATHER_API_KEY
```

- キーを変えたときは、上のコマンドで新しい版を作り、`firebase deploy --only functions` をやり直す。
- 無料枠は月1万回（Essentials）。Functions が都道府県ごとに3時間 `weatherCache` に置くので、同じ地域の公演では呼び出しが増えない。

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
12. リマインド通知: プロフィールで「リマインド通知」をオンにできる。期限が24時間以内の受付があると、15分以内に通知が届き、押すとライブ詳細が開く（Cloud Scheduler の強制実行ですぐ確かめられる）。PC か Android の Chrome で確かめる。
13. メモリーの写真: 記録の編集で写真を追加・保存でき、詳細画面とアルバムのカードに表示される（表示されないときは 2.8 の CORS を確かめる）。
14. 遠征: ライブ詳細の公演の行と遠征の一覧（`/trips`）に、9日後までの公演の天気予報が出る。ホームに「次の遠征」が出て、「すべて見る」で一覧が開く。「行き方」「周辺の宿」などが Google マップで開く。
15. アイコン: 推しの札を押して、色・絵文字・画像を選べる（画像は自分にだけ見える）。プロフィールでアイコンを選ぶと、ホームのあいさつ・アカウントのボタン・自分の投稿と返信・チャット一覧（相手から見たとき）に出る。

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
