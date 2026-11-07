# おしあし（仮）リマインド通知（Step6）仕様書

> 本ドキュメントは、方針書（「コンペで作成するものの方針」の通知）と `markdown/feature_step6_7_plan.md` 5章のメモをもとに、Blaze への切り替え後にリマインド通知を作るための仕様書である。
> チームメンバーおよび開発支援に使う LLM が、この文書だけを読んで同じ前提で作業できるように、今のコードの構造と、変更後の形を具体的に書いている。
> 前提として、`markdown/Database_config.md`・`CLAUDE.md`・`markdown/deploy_手順.md` をあわせて参照すること。

## 0. LLM への指示

- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。「9. 未決定事項」は独自に確定させず、提案として示すこと。
- 本仕様にない作業を勝手に足さないこと。**テストコードは書かない**。
- **コードの編集は人間が Dev Container 内で行う。** LLM はリポジトリを読むだけにして、変更は置き換える部分を丸ごと（メソッド・クラス・ファイル単位で）コードとして提示すること。「ここだけ変える」「外側だけ包む」のような部分的な説明はしない。
- 開発は7章のステップの順に進め、各ステップに1行程度のコミット文を添えること。画面の確認は最後にまとめて行う。
- 既存のコードの書き方に合わせること（Riverpod 3 を手書き・コード生成なし、go_router、Firebase へのアクセスは `lib/repositories/` に閉じ込める、`await` 後は `context.mounted` を確認、文言・コメントは日本語、色はテーマから取る）。
- 追加してよいパッケージは `firebase_messaging` だけ。Firebase の新しい機能は Cloud Functions（定期実行）と Cloud Messaging だけを使う。
- **`firestore.rules` は変えない。** 新しいデータはすべて `users/{uid}` の下のサブコレクションに置く（今のルールの `match /users/{userId}/{subcollection}/{document=**}` で本人のみ読み書きできる。Functions は Admin SDK なのでルールを通らない）。
- **秘密情報・鍵をリポジトリに書かない。** VAPID キーは `--dart-define` で渡す（App Check のサイトキーと同じ扱い）。
- `firebase deploy`・`firebase init` は人間が行う。

## 1. 概要

| 項目 | 内容 |
|---|---|
| 機能名 | リマインド通知（Step6） |
| 担当 | B（横山）。`lib/app.dart` は A（とし）と共有する |
| ブランチ | `dev` から `feature/step6`（人間が作る） |
| 目的 | 登録した受付の「次の締切」（申込期限・当落発表・入金期限）が近づいたら、Web プッシュで知らせる |
| 方式 | FCM の Web プッシュ。送信は Cloud Functions の定期実行（15分おき） |
| 前提 | Firebase は **Blaze**（Google Cloud 無料トライアルの請求先アカウントを紐づけ済み。11/7） |

## 2. 着手前のコードの構造（11/7 時点）

| 対象 | 場所 | 作り |
|---|---|---|
| 次の締切の規則 | `lib/utils/deadline.dart` の `nextDeadlineOf` | 未申込 → `applyEndAt`（申込期限）、申込済 → `resultAt`（当落発表）、当選 → `paymentDeadline`（入金期限）、落選・入金済 → なし |
| 当選者のみの受付 | `lib/utils/winners_only.dart` の `winnerLiveIds`・`isReceptionVisible` | 同じ `liveId` に `won`・`paid` の申込状況があれば、`winnersOnly` の受付も対象 |
| データ | `lives/{liveId}`（`title`）、`receptions/{id}`（`liveId`・`name`・`applyEndAt`・`resultAt`・`paymentDeadline`・`winnersOnly`）、`users/{uid}/myLives/{liveId}`、`users/{uid}/applications/{receptionId}`（`liveId`・`status`：`applied`・`won`・`lost`・`paid`） | |
| ログイン中の uid | `lib/providers/oshi_providers.dart` の `currentUidProvider` | |
| プロフィール画面 | `lib/features/profile/profile_page.dart`（B） | 編集のとき（`!isInitial`）だけ、下に `Divider` と `ThemeColorPicker` |
| アプリ本体 | `lib/app.dart` の `App`（A と共有） | `MaterialApp.router`（`builder` は未使用） |
| 起動 | `lib/main.dart` | App Check の初期化（`--dart-define=APP_CHECK_SITE_KEY`） |
| Hosting | `firebase.json` | `/firebase-messaging-sw.js` は `no-cache` の設定済み。公開先は `https://oshiashi-test.web.app` |
| アイコン | `web/icons/Icon-192.png` | |

## 3. 決定事項：通知の規則

### 3.1 対象

- 自分のライブ一覧（`myLives`）に入っているライブの受付。
- `winnersOnly` の受付は、そのライブで当選者のときだけ（`isReceptionVisible` と同じ条件）。
- 受付ごとに `nextDeadlineOf` と同じ規則で「次の締切」（種類と日時）を決める。期限を過ぎたものは対象外。

### 3.2 タイミング

| 段階 | 条件（残り時間＝期限 − 現在） | 記録の ID の末尾 |
|---|---|---|
| 1日前 | 3時間 ＜ 残り ≦ 24時間 | `1d` |
| 3時間前 | 0 ＜ 残り ≦ 3時間 | `3h` |

- カレンダーの予定に付けている通知（1日前・3時間前）と同じにする。
- 定期実行は15分おきなので、最大15分ほど遅れて届く。
- 登録が遅く、最初から残りが3時間以下なら、3時間前の通知だけが届く。
- 申込状況が変わると締切の種類が変わるので、新しい種類の締切として改めて通知する。

### 3.3 二重送信の防止

- 送ったら `users/{uid}/sentNotifications/{receptionId}_{kind}_{段階}`（例：`abc123_payment_3h`）に記録する。記録があれば送らない。
- `kind` は `apply`・`result`・`payment`（`DeadlineKind` の名前と同じ）。

### 3.4 通知の内容

| 項目 | 内容 |
|---|---|
| 題名 | `<種類の名前>まで あと<n>時間`（例：「入金期限まで あと3時間」。n は残り時間を時間単位で切り上げ） |
| 本文 | `<ライブ名>（<受付名>）` の改行の後に `<期限の日時> まで`（例：「11/9(月) 23:59 まで」。日本時間） |
| アイコン | `/icons/Icon-192.png` |
| 押したとき | そのライブの詳細 `https://oshiashi-test.web.app/lives/<liveId>` を開く |

- 種類の名前は「申込期限」「当落発表」「入金期限」（`DeadlineKind.label` と同じ）。

### 3.5 通知のオン・オフ

- プロフィール画面（編集のとき）に「リマインド通知」のスイッチを置く。
- オンにすると、ブラウザの通知の許可を求め、許可されたら FCM トークンを取って保存する。許可されなかったら、スイッチはオフのままにし、「ブラウザの設定で通知が拒否されています」と SnackBar で出す。
- オフにすると、FCM トークンを削除し（`deleteToken`）、保存したトークンのドキュメントも消す。
- スイッチの状態は「このブラウザの通知が許可されていて、このブラウザのトークンが保存されている」かどうか。
- 種類ごとの設定は作らない。

### 3.6 アプリを開いているとき

- アプリを開いている（前面の）ときは、ブラウザの通知は出ない（FCM の仕様）。代わりに、題名と本文を SnackBar で出し、「開く」を押すとそのライブの詳細へ移る。

## 4. 決定事項：データ

### 4.1 FCM トークン（`users/{uid}/fcmTokens/{token}`）

| 項目 | 型 | 必須 | 内容 |
|---|---|---|---|
| `createdAt` | timestamp | ○ | 保存した日時（サーバー時刻） |
| `updatedAt` | timestamp | ○ | 最後に保存し直した日時（サーバー時刻） |

- ドキュメント ID をトークンそのものにする（同じブラウザで何度オンにしても1件）。
- 送信で「無効なトークン」と返ってきたものは、Functions が消す。

### 4.2 送った記録（`users/{uid}/sentNotifications/{receptionId}_{kind}_{段階}`）

| 項目 | 型 | 内容 |
|---|---|---|
| `receptionId` | string | 受付の ID |
| `kind` | string | `apply`・`result`・`payment` |
| `stage` | string | `1d`・`3h` |
| `deadlineAt` | timestamp | 締切の日時 |
| `sentAt` | timestamp | 送った日時 |

- Functions（Admin SDK）だけが書く。アプリからは読まない。

## 5. 決定事項：クライアント（Flutter）

### 5.1 パッケージと設定

- `flutter pub add firebase_messaging`（`firebase_core` に合う版が入る）。追加後はホットリスタートではなく再起動する。
- VAPID キーは `--dart-define=FCM_VAPID_KEY=<鍵>` で渡す。開発中の起動も同じ：

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --dart-define=FCM_VAPID_KEY=<鍵>
```

- 鍵が空のときは、スイッチを押しても「通知の設定がされていません」と SnackBar で出すだけにする（アプリは動く）。

### 5.2 Service Worker（`web/firebase-messaging-sw.js`、新規）

- サイトのルートに置く（`firebase_messaging` がここを登録する）。中身は、Firebase の compat 版の SDK を `importScripts` で読み、`firebase.initializeApp`（`lib/firebase_options.dart` の Web の値と同じ）と `firebase.messaging()` を呼ぶだけ。通知の表示は、送信側の `notification`・`webpush.fcmOptions.link` で自動で行われる。
- SDK の版は、FlutterFire が読む版にそろえる。Dev Container で次を実行して確かめる：

```bash
grep -rh "supportedFirebaseJsSdkVersion" ~/.pub-cache/hosted/pub.dev/firebase_core_web-*/lib
```

### 5.3 リポジトリ（`lib/repositories/messaging_repository.dart`、新規）

`FirebaseMessaging` と `FirebaseFirestore` をコンストラクタで受け取る。

| メソッド | 内容 |
|---|---|
| `Future<bool> isEnabled(String uid)` | 許可の状態が `authorized` で、`getToken(vapidKey:)` のトークンが `fcmTokens` にあれば true |
| `Future<NotificationEnableResult> enable(String uid)` | 許可を求める（`requestPermission`）→ 許可されたらトークンを取り、`fcmTokens/{token}` に保存（`createdAt` は初回だけ、`updatedAt` は毎回）。結果は `enabled`・`denied`・`notConfigured`（VAPID キーなし）の3つ |
| `Future<void> disable(String uid)` | トークンを取り、そのドキュメントを消してから `deleteToken()` |
| `Stream<RemoteMessage> get onForegroundMessage` | `FirebaseMessaging.onMessage` |

### 5.4 プロバイダ（`lib/providers/messaging_providers.dart`、新規）

- `messagingRepositoryProvider`
- `notificationEnabledProvider`：`FutureProvider<bool>`。`currentUidProvider` が null なら false。オン・オフの後は `ref.invalidate` で読み直す。
- `foregroundMessageProvider`：`StreamProvider<RemoteMessage>`（`onForegroundMessage`）。

### 5.5 プロフィール画面のスイッチ（`lib/features/profile/notification_switch.dart`、新規）

- `NotificationSwitch`（`ConsumerStatefulWidget`）。`SwitchListTile`：題名「リマインド通知」、説明「申込期限・当落発表・入金期限の1日前と3時間前に、このブラウザへ通知します」。処理中はスイッチを無効にする。
- `profile_page.dart` の編集のときの区画（`ThemeColorPicker` の下）に、`Divider` を挟んで置く。

### 5.6 アプリを開いているときの表示（`lib/features/common/foreground_notification_listener.dart`、新規）

- `ForegroundNotificationListener`（`ConsumerWidget`、`child` を受け取る）。`ref.listen(foregroundMessageProvider, ...)` で、届いたら `ScaffoldMessenger.of(context).showSnackBar`：題名と本文、`SnackBarAction`「開く」で `data['liveId']` があれば `ref.read(routerProvider).go('/lives/<liveId>')`。
- `lib/app.dart` の `MaterialApp.router` に `builder: (context, child) => ForegroundNotificationListener(child: child!)` を足す（A と共有。この1行だけ）。

## 6. 決定事項：送信側（Cloud Functions）

### 6.1 フォルダと設定

- `functions/`（新規）。人が Dev Container で `firebase init functions` を実行する：既存のプロジェクト（`oshiashi-test`）、**JavaScript**、ESLint なし、依存のインストールあり。`firebase.json` に `functions` の設定が足される。
- Node.js は 22（`package.json` の `engines`）。`firebase-functions`（v2 の `onSchedule`）と `firebase-admin` を使う。
- `functions/node_modules/` はコミットしない（`.gitignore`）。

### 6.2 関数 `sendDeadlineReminders`（`functions/index.js`）

```text
onSchedule({ schedule: 'every 15 minutes', timeZone: 'Asia/Tokyo', region: 'asia-northeast1' })
```

1. `collectionGroup('fcmTokens')` を読み、uid（`doc.ref.parent.parent.id`）ごとにトークンをまとめる。
2. uid ごとに：
   1. `myLives` の ID、`applications`（`receptionId → { liveId, status }`）を読む。
   2. `receptions` を `liveId` の `in`（30件ずつ）で読み、`lives` を `getAll` で読む（ライブ名）。
   3. 当選者のライブ（`won`・`paid` の `liveId`）を求め、`winnersOnly` の受付を絞る（3.1）。
   4. 受付ごとに次の締切（`nextDeadline`。`deadline.dart` の `nextDeadlineOf` と同じ規則を JS で書く）と段階（3.2）を決める。
   5. 記録（3.3）が無ければ、`sendEachForMulticast` で送る（`notification`：題名・本文、`webpush.notification.icon`、`webpush.fcmOptions.link`、`data.liveId`）。
   6. 送ったら記録を書く。エラーが `messaging/registration-token-not-registered`・`messaging/invalid-registration-token` のトークンは、`fcmTokens` から消す。
3. 日時の書き方は `Intl.DateTimeFormat('ja-JP', { timeZone: 'Asia/Tokyo', ... })` で「11/9(月) 23:59」の形にする。
4. 公開先の URL は定数 `APP_URL = 'https://oshiashi-test.web.app'`（秘密ではない）。

## 7. 開発ステップ

| Step | 内容 | 状況 |
|---|---|---|
| N-1 | `firebase_messaging` の追加、Service Worker（5.1・5.2） | 未着手 |
| N-2 | リポジトリ・プロバイダ・プロフィールのスイッチ（5.3〜5.5） | 未着手 |
| N-3 | アプリを開いているときの表示（5.6） | 未着手 |
| N-4 | Cloud Functions の送信（6章） | 未着手 |
| N-5 | 人が行う設定・デプロイと確認（8章）。`markdown/deploy_手順.md` に VAPID キーの作成・`--dart-define=FCM_VAPID_KEY`・Functions のデプロイを追記する | 未着手 |

## 8. 人が行う設定と確認

### 8.1 設定

1. Firebase コンソール →「プロジェクトの設定」→「Cloud Messaging」→「ウェブ構成」→「ウェブプッシュ証明書」で**鍵ペアを生成**し、公開鍵（VAPID キー）を控える。リポジトリには書かない。
2. 同じ画面で「Firebase Cloud Messaging API（V1）」が有効になっていることを確かめる。
3. Functions のデプロイ：`firebase deploy --only functions`。初回は必要な API（Cloud Functions・Cloud Build・Artifact Registry・Cloud Scheduler など）の有効化を聞かれるので進める。コンテナイメージの削除ポリシーを聞かれたら、既定の日数で設定する。
4. 公開するときは、ビルドに `--dart-define=FCM_VAPID_KEY=<鍵>` を足す。

### 8.2 確認（デモ用データの「けん」で）

1. プロフィール →「リマインド通知」をオン → ブラウザの許可 → Firestore の `users/{uid}/fcmTokens` に1件できる。
2. デモ用データの入金期限（当日の5時間後）が残り3時間を切ると、15分以内に「入金期限まで あと3時間」が届く。押すとライブの詳細が開く。`sentNotifications` に記録ができ、次の実行では届かない。
3. アプリを開いているときは SnackBar で出て、「開く」でライブの詳細へ移る。
4. オフにすると `fcmTokens` から消え、届かなくなる。
5. Functions のログ（Firebase コンソール →「Functions」→「ログ」）にエラーが無い。

- デモは PC か Android の Chrome で行う（iPhone はホーム画面に追加したときだけ届く）。

## 9. 未決定事項

- ログアウトのときに、そのブラウザのトークンを消すか（今は消さない。同じブラウザで別のアカウントに切り替えると、前のアカウントの通知が届く）
- アプリの起動時に、トークンを保存し直すか（トークンが変わったときの追従）
- 受付開始（`applyStartAt`）の通知
- デモの撮影用に、すぐ通知を送るボタン（テスト送信）を作るか