# front1 実装計画: メールアドレスでの登録・ログインと、ログイン画面の作り直し

> 担当A（とし）の作業を、Claude Code の agent team（リーダー＋チームメイト3人）で実装するための指示書（仕様書を兼ねる）。人間とエージェントの両方が読む。
> 2章はユーザーと合意済みの決定事項。5章はリーダーが実装前にユーザーへ確かめる項目。

## 0. 作業ブランチと前提

- **作業ブランチは `feature/front1`。** ブランチの作成・切り替え・pull・push は人間が行う。エージェントはブランチを切り替えない。
- 開始前に、リーダーは `git status -sb` で `feature/front1` にいて、GitHub より遅れていない（`behind` が無い）ことを確かめる。遅れていたらユーザーに `git pull --no-rebase` を頼む。
- 完成したら、人間が `feature/front1` から `dev` へ Pull Request を出す。
- 直前のコミット（`65554d3`）で、紹介ページ（`/welcome`）を作り直した。今は「始める」「ログイン」を押すと、その場で Google のログインが開く。**今回これをやめ、ログイン画面（`/login`）へ移す形に戻す。**
- Firebase は **Spark（無料）プランのまま**。メールアドレスとパスワードのログイン、確認メール、パスワードの再設定メールは Spark で使える。
- 締切: チームの計画では **11/8 の夜に機能を凍結**する。提出は 11/10（火）17:00。

## 1. 範囲

**作るもの**

1. **メールアドレスとパスワードでの新規登録とログイン**。新規登録ではパスワードを2回入れる。
2. **確認メール**: 新規登録したら確認メールを送る。**メールのリンクを開いて確認するまで、アプリを使えない**（確認待ちの画面 `/verify-email` に留める）。
3. **パスワードの再設定**: 「パスワードを忘れた方」から、再設定のメールを送る。
4. **ログイン画面（`/login`）の作り直し**: 「ログイン」と「新規登録」を切り替えられる。Google のログインもここに置く。紹介ページと同じ色・雰囲気にする。
5. **紹介ページの変更**: 「始める」→ ログイン画面の「新規登録」、右上の「ログイン」→ ログイン画面の「ログイン」へ移す。
6. **Google カレンダーへの追加（メールで登録した人）**: 初めて追加するときに、Google アカウントをつなぐ（`linkWithPopup`）。つないだ後は、今の Google でログインした人と同じ動きにする。

**作らないもの**

- **Apple でのログイン**（ユーザーの判断で今回はやめる。Apple Developer Program の登録と設定が、機能の凍結に間に合わないため）
- メールのリンクだけでのログイン（パスワード無し）、電話番号でのログイン
- メールアドレス・パスワードの変更画面、退会
- **セキュリティルールでの「メール未確認の人」の遮断**（5.3。今回は画面の振り分けだけで止める。判断ログに理由を書く）
- Firebase の Auth エミュレータの導入（テストは偽物のクラスで行う。動作確認は本物のプロジェクトで行う）
- `firebase deploy`、Firebase コンソールの設定（人間が行う。12章）

## 2. 決まっていること（ユーザーと合意済み）

| 項目 | 決定 |
|---|---|
| ログインの方法 | Google と、メールアドレス＋パスワードの2つ。Apple は作らない |
| 確認メール | 送る。**確認するまで使えない** |
| パスワードの再設定 | 入れる |
| 紹介ページのボタン | 「始める」も「ログイン」も、ログイン画面へ移す（その場で Google のログインを開かない） |
| メールで登録した人のカレンダー | 初めて追加するときに Google アカウントをつなぐ |

## 3. 前提（既存のコード）

| 項目 | 今の状態 | 場所 |
|---|---|---|
| 認証のリポジトリ | `signInWithGoogle()`（`signInWithPopup(GoogleAuthProvider())`）、`signOut()`、`authStateChanges()`、`currentUser` だけ | `lib/repositories/auth_repository.dart` |
| ルーターの振り分け | 未ログイン → `/welcome`（`/welcome`・`/login` は見られる）。ログイン済みでプロフィールが無い → `/profile`。ログイン済みで `/welcome`・`/login` → `/` | `lib/app.dart` の `routerProvider` |
| **`/login` のルートが2つある** | `lib/app.dart` の `/welcome` の次と、`/trade/:id` の次。後ろのものは使われていない | `lib/app.dart` |
| ログイン画面 | 「Google でログイン」ボタン、戻るボタン（`login_back_button`）、reCAPTCHA の文言（`login_recaptcha_notice`） | `lib/features/auth/login_page.dart` |
| 紹介ページ | `_SignInAction`（その場で Google のログイン）と `_RecaptchaNotice` を持つ。ボタンのキーは `welcome_start_button`・`welcome_login_button`。英字・番号に google_fonts（Outfit）を使う | `lib/features/welcome/welcome_page.dart` |
| reCAPTCHA のバッジ | `web/index.html` で隠している（`visibility: hidden`）。**そのため、ログインする画面に規約の文言が必要** | `web/index.html` |
| カレンダーの権限 | `GoogleCalendarService._accessToken()` が、ログイン中のユーザーに `reauthenticateWithPopup(GoogleAuthProvider()..addScope(calendar.events))` する。**Google でログインしていない人では失敗する** | `lib/services/google_calendar_service.dart`（横山さん） |
| カレンダーのエラー表示 | 追加シートは `'$e'` をそのまま出す（`StateError` だと「Bad state: 」が付く）。今回は変えない | `lib/features/calendar/calendar_add_sheet.dart`（横山さん） |
| 表示名 | メールで登録した人には `displayName` が無い。初回はプロフィール作成画面（`/profile`）で名前を入れるので、問題ない | `lib/app.dart`・`lib/features/profile/` |
| ログアウト | ホームの右上（`home_page.dart`）から `signOut()` | |
| 認証のテスト | `test/providers/firestore_retry_test.dart` に、`FirebaseAuth` の偽物（`implements FirebaseAuth`）の例がある | |

## 4. 仕様

### 4.1 画面の流れ

```
/welcome ─「始める」──→ /login?mode=signup（新規登録が選ばれた状態）
         └「ログイン」─→ /login（ログインが選ばれた状態）

/login ─ Google で続ける ───────────────────────────→（プロフィールが無ければ /profile）→ /
       ├ メールでログイン（確認済み） ─────────────────→（同上）
       ├ メールでログイン（未確認） ──→ /verify-email
       └ 新規登録 → 確認メールを送る ─→ /verify-email ─ リンクを開く → 「確認しました」→（同上）
```

### 4.2 ログイン画面（`/login`）

**見た目**: 紹介ページの「締め」と同じ世界観にする。

- 背景: 夜の色 `#0E0A1F` → 紫 `#2E1A5C` のグラデーションに、上のほうにピンクの光（紹介ページの `_Closing` と同じ）
- 上部: 戻るボタン（白。`login_back_button`。`/welcome` へ）。アプリ名「おしあし」（既定の書体の w900、白、ピンクの光彩。紹介ページと同じ）と、ひとこと「推し活の予定を、ひとつに。」
- 中央にカード: 色 `#FAF8FD`、角丸 24、最大幅 420、内側の余白 24〜28
- 色は紹介ページの `_Palette` と同じ値を使う。**`lib/theme/brand_colors.dart`（新規）に色を移し、紹介ページとログイン画面・確認画面の両方から使う**（同じ値を2か所に書かない）

**カードの中身（上から）**

| 要素 | キー | 内容 |
|---|---|---|
| 切り替え | `login_mode_signin`・`login_mode_signup` | 「ログイン」「新規登録」の2つ（`SegmentedButton`）。`/login?mode=signup` なら「新規登録」で開く。それ以外は「ログイン」 |
| Google | `login_google_button` | 「Google で続ける」。枠線のボタン、幅いっぱい |
| 区切り | | 「または メールアドレスで」 |
| メール | `login_email_field` | キーボードの種類はメール、自動入力のヒントは email。前後の空白は除いて扱う |
| パスワード | `login_password_field` | 伏せ字。目のアイコンで表示・非表示。新規登録のときは「8文字以上」と補足 |
| 確認用 | `login_password_confirm_field` | **新規登録のときだけ**出す。「パスワード（確認）」 |
| 送信 | `login_submit_button` | ピンク → 紫のグラデーションの丸いボタン（紹介ページの「始める」と同じ）。ログインのときは「ログイン」、新規登録のときは「登録して確認メールを送る」 |
| 再設定 | `login_forgot_password_button` | **ログインのときだけ**出す。「パスワードを忘れた方」→ 4.2.1 |
| 説明 | | 新規登録のとき「登録すると確認メールが届きます。メールのリンクを開くと使えるようになります。」。両方で「Google カレンダーへの追加は、使うときに Google アカウントの許可を求めます。」 |
| エラー | `login_error` | 4.6 の文言をカードの中に出す（赤系の帯）。入力の間違いは各欄の下に出す（4.7） |

- カードの下に、reCAPTCHA の文言（`login_recaptcha_notice`。今と同じ文言とリンク。暗い背景で読める色）。
- **処理中は、すべてのボタンと切り替えを押せなくし、押したボタンにくるくるを出す**（二重送信を防ぐ）。
- パスワード欄で Enter を押すと送信する。
- 切り替えたときは、エラーの表示を消す。入力したメールアドレスは残す。
- 幅 360px でもはみ出さない。キーボードが出てもスクロールで全部に届く。
- `await` の後で `BuildContext` を使う前に `context.mounted` を確かめる（新規登録・ログインに成功すると、ルーターが画面を移すため）。

#### 4.2.1 パスワードの再設定

- 「パスワードを忘れた方」→ ダイアログ。メール欄（`reset_email_field`。ログイン画面に入っていればその値を入れておく）と「再設定のメールを送る」（`reset_send_button`）。
- 送ったら（**成功のときも `user-not-found` のときも**）同じ文言「入力したメールアドレスが登録されていれば、パスワードを再設定するメールを送りました。」を出す。登録の有無を他人に知らせないため。
- それ以外のエラーは 4.6 の文言。

### 4.3 メールの確認画面（`/verify-email`）

- キー `verify_email_page`。背景・カードはログイン画面と同じ。
- 文言: 「確認メールを送りました」「<メールアドレス> に届いたメールのリンクを開いてから、下のボタンを押してください。」「届かないときは、迷惑メールのフォルダも見てください。」
- 「確認しました」（`verify_check_button`）: 最新の状態を読み直す（7章 `reloadEmailVerified`）。
  - 確認済み → `context.go('/')`。ルーターの振り分け（4.5）が、プロフィールの有無に応じて `/profile` か `/` に移す。
  - まだ → 「まだ確認できていません。メールのリンクを開いてから、もう一度押してください。」
- **画面を開いている間は、5秒ごとに自動で確かめる**（別のタブでリンクを開いて戻ってきたら、押さなくても進む）。画面を閉じたらタイマーを止める。確かめている途中に次の確認を重ねない。
- 「確認メールを送り直す」（`verify_resend_button`）: 送ったら「送りました」。**送った後60秒は押せない**（残り秒数を出す）。`too-many-requests` は 4.6 の文言。
- 「別のアカウントでログインする」（`verify_sign_out_button`）: ログアウトする（ルーターが `/welcome` に移す）。

### 4.4 紹介ページ（`/welcome`）の変更

- 「始める」（`welcome_start_button`）→ `context.go('/login?mode=signup')`
- 右上の「ログイン」（`welcome_login_button`）→ `context.go('/login')`
- `_SignInAction` と `_RecaptchaNotice` を消す（文言はログイン画面にある）。使わなくなった import も消す。
- 「始める」の下の説明を「メールアドレスか Google アカウントで始められます。」に変える。
- **それ以外の見た目は変えない**（直前にユーザーが確定させたデザイン）。色の定数を `lib/theme/brand_colors.dart` に移すのは可。

### 4.5 ルーターの振り分け

振り分けの判断を、純粋関数 `decideRedirect`（7章）に移し、`routerProvider` の `redirect` から呼ぶ。上から順に判定する。

| 状態 | いる場所 | 行き先 |
|---|---|---|
| 未ログイン | `/welcome`・`/login` | そのまま |
| 未ログイン | それ以外（`/verify-email` を含む） | `/welcome` |
| ログイン済み・メール未確認（※） | `/verify-email` | そのまま |
| ログイン済み・メール未確認（※） | それ以外 | `/verify-email` |
| ログイン済み・プロフィールが無い | `/profile` | そのまま |
| ログイン済み・プロフィールが無い | それ以外 | `/profile` |
| ログイン済み | `/welcome`・`/login`・`/verify-email` | `/` |
| ログイン済み | それ以外 | そのまま |

※「メール未確認」= ログインの方法に `password` があり、`emailVerified` が false。Google だけでログインした人は対象外。

- `/verify-email` のルートを足す。
- `/login` のルートは、`?mode=signup` を読んで `LoginPage(initialMode: ...)` を作る。**使われていない2つ目の `/login` のルートは消す。**
- プロフィールの「読み込み中・エラーのときは判定しない」という今の動きは変えない。

### 4.6 エラーの文言

`FirebaseAuthException.code` から文言を作る純粋関数 `authErrorMessage`（7章）を1か所に作り、ログイン画面・確認画面・再設定のダイアログで使う。

| code | 文言 |
|---|---|
| `popup-closed-by-user`・`cancelled-popup-request` | （出さない。`null` を返す） |
| `popup-blocked` | ポップアップがブロックされました。ブラウザの設定でこのサイトのポップアップを許可してください。 |
| `invalid-email` | メールアドレスの形が正しくありません。 |
| `invalid-credential`・`invalid-login-credentials`・`wrong-password`・`user-not-found` | メールアドレスかパスワードが違います。 |
| `email-already-in-use` | このメールアドレスはすでに登録されています。「ログイン」から入ってください。 |
| `weak-password` | パスワードが弱すぎます。8文字以上にしてください。 |
| `too-many-requests` | 試した回数が多すぎます。しばらく待ってから、もう一度お試しください。 |
| `user-disabled` | このアカウントは使えなくなっています。 |
| `network-request-failed` | 通信できませんでした。電波の良いところで、もう一度お試しください。 |
| `operation-not-allowed` | この方法でのログインは、いま使えません。（管理者: Firebase コンソールで有効にしてください） |
| `account-exists-with-different-credential` | このメールアドレスは、別の方法で登録されています。登録したときの方法でログインしてください。 |
| `requires-recent-login` | もう一度ログインしてから、お試しください。 |
| それ以外 | うまくいきませんでした（<code>）。 |

- 最近の Firebase では「メールアドレスの列挙保護」が既定で有効なため、パスワード違い・未登録はどちらも `invalid-credential` になる。旧来の code も同じ文言にしておく。

### 4.7 入力の検査

純粋関数（7章）で検査し、`Form` の `validator` に使う。送信のときに全部の欄を検査する。

| 欄 | 条件 | 文言 |
|---|---|---|
| メール | 空 | メールアドレスを入れてください。 |
| メール | 前後の空白を除いて `^[^@\s]+@[^@\s]+\.[^@\s]+$` に合わない | メールアドレスの形が正しくありません。 |
| パスワード | 空 | パスワードを入れてください。 |
| パスワード（**新規登録のときだけ**） | 8文字未満 | パスワードは8文字以上にしてください。 |
| パスワード（確認） | パスワードと違う | パスワードが一致しません。 |

- ログインのときは長さを検査しない（以前の短いパスワードでも入れるように。判定は Firebase に任せる）。
- パスワードの前後の空白は除かない（パスワードの一部として扱う）。

### 4.8 Google カレンダー（メールで登録した人）

`GoogleCalendarService._accessToken()` の、トークンを取り直す部分だけを変える（**横山さんのファイル。5.1 で了承を確かめてから**）。

- ログインの方法に `google.com` がある → 今と同じ（`reauthenticateWithPopup`）。
- 無い → `user.linkWithPopup(GoogleAuthProvider()..addScope(calendar.events))` で Google アカウントをつなぎ、結果の `credential.accessToken` を使う（`login_hint` は付けない）。
  - つないだ後は、次回から Google でもログインできる（同じアカウントになる）。
  - `credential-already-in-use`・`email-already-in-use` → `StateError('この Google アカウントは、別のおしあしのアカウントで使われています。別の Google アカウントを選んでください')`
  - `provider-already-linked` → `reauthenticateWithPopup` でやり直す
  - それ以外は今と同じく、そのまま投げる
- アクセストークンの扱い（50分で取り直す）は変えない。

### 4.9 メールの言語

確認メール・再設定メールを日本語で送るため、`FirebaseAuth` の言語を `ja` にする（`setLanguageCode('ja')`）。`authRepositoryProvider` で `FirebaseAuth.instance` を渡す前に行う（テストでは偽物に差し替わるので影響しない）。コンソールのテンプレートの言語設定（12章）と合わせる。

## 5. 実装前に確かめること（リーダー → ユーザー）

リーダーは次をまとめてユーザーに聞き、回答を `notes/判断ログ_A.md` に「front1」として書いてから、チームメイトを作る。

> **（確認済み 2026-11-07）** 5.1 すべて了承（D4・Q3 も行う）／5.2 未確認（L1 の前までに）／5.3 画面の振り分けだけ／5.4 ユーザーはそばにいる。

### 5.1 横山さんのファイルを変えることの了承

- `lib/services/google_calendar_service.dart`（4.8。`_accessToken` の一部）
- `lib/features/auth/login_page.dart`（作り直し。元は横山さん、Step7 で reCAPTCHA の文言を足した）
- `lib/repositories/auth_repository.dart`・`lib/app.dart`（共有。メソッドとルートの追加）
- 了承が無いものは触らない。4.8 が無理なら、メールで登録した人には、カレンダーの追加ボタンを押したときに「Google でログインすると使えます」と出す案に切り替えるかをユーザーに聞く。

### 5.2 Firebase コンソールの設定（人間）

- 「メール / パスワード」を有効にしたか（12.1）。**動作確認（L1）の前までに**あればよい。実装は先に進めてよい。

### 5.3 ルールでの遮断はしない（推奨）

- 「確認するまで使えない」は、今回は**画面の振り分けだけ**で行う。セキュリティルールに `email_verified` の条件を足すと、`firestore.rules`（横山さんと共有）と、ルールのテストのすべての認証の作り方を変える必要があり、機能の凍結（11/8 夜）に間に合わない恐れがあるため。
- 残る弱点: 確認していない人も、Firebase の API を直接呼べば読み書きできる。審査の後の課題として判断ログに書く。
- ユーザーが「ルールでも遮断する」を選んだら、data のタスクに足し、`test_rules/` の更新を qa に足す。

### 5.4 そばで見ているか

- ユーザーがそばにいないときは、判断が要る点を進捗ファイルに書いて先に進められるものを進める（14章）。

## 6. 担当とファイル

同じファイルを2人が同時に編集すると上書きが起きる。**担当外のファイルは編集せず、担当者に SendMessage で依頼する。**

| 担当 | 名前 | 編集してよいファイル |
|---|---|---|
| リーダー | （メインセッション） | この計画書、`notes/判断ログ_A.md`、`notes/front1_進捗.md` |
| データ層 | `data` | `lib/repositories/auth_repository.dart`、`lib/utils/auth_validators.dart`（新規）、`lib/utils/auth_error_message.dart`（新規）、`lib/utils/auth_redirect.dart`（新規）、`lib/app.dart`（**ルーターの振り分けと、`/login`・`/verify-email` のルートだけ**）、`lib/services/google_calendar_service.dart`（**5.1 の了承があるときだけ。`_accessToken` の部分だけ**） |
| 画面 | `ui` | `lib/features/auth/**`（`login_page.dart` の作り直し、`verify_email_page.dart`（新規）、部品のファイルを足してよい）、`lib/features/welcome/welcome_page.dart`（**4.4 の範囲だけ**）、`lib/theme/brand_colors.dart`（新規） |
| テスト・レビュー | `qa` | `test/**`、`notes/front1_レビュー記録.md`（新規） |

- **読むだけ**: `lib/features/calendar/**`、`lib/features/profile/**`、`lib/features/home/**`、`firestore.rules`、`web/**`、`pubspec.yaml`。
- **依存パッケージは足さない**（`firebase_auth_mocks` なども使わず、偽物のクラスを手で書く）。どうしても必要なら、理由を付けてリーダーに相談し、リーダーがユーザーの了承を得る。

## 7. 契約（インターフェース）

データ層 `data` が最初のタスク（D1）で確定させ、`ui` と `qa` に SendMessage で全文を送る。画面のクラス（`LoginPage`・`LoginMode`・`VerifyEmailPage`）は `ui` が U0 で先に空の形を作る。以下は叩き台。

```dart
// lib/utils/auth_validators.dart（純粋関数）
const minPasswordLength = 8;
String? validateEmail(String? value);                          // 正しければ null
String? validatePassword(String? value, {required bool isSignUp}); // 新規登録のときだけ長さを見る
String? validatePasswordConfirm(String? value, String password);

// lib/utils/auth_error_message.dart（純粋関数）
/// 利用者に知らせなくてよいエラー（自分でポップアップを閉じた）なら null
String? authErrorMessage(String code);

// lib/utils/auth_redirect.dart（純粋関数）
/// ログインの方法に password があり、メールが未確認か
bool needsEmailVerification({
  required bool emailVerified,
  required Iterable<String> providerIds,
});
/// 4.5 の表のとおりに行き先を返す。そのままなら null
String? decideRedirect({
  required String location,
  required bool loggedIn,
  required bool needsEmailVerification,
  required bool needsProfile,
});

// lib/repositories/auth_repository.dart（追加）
class AuthRepository {
  // 既存: currentUser, authStateChanges(), signInWithGoogle(), signOut()
  /// 新規登録。アカウントを作り、確認メールを送る（メールアドレスは前後の空白を除く）
  Future<void> signUpWithEmail({required String email, required String password});
  Future<void> signInWithEmail({required String email, required String password});
  Future<void> sendPasswordResetEmail(String email);
  /// 確認メールを送り直す
  Future<void> resendEmailVerification();
  /// ユーザーの状態を読み直し、確認済みなら true（確認済みならトークンも取り直す）
  Future<bool> reloadEmailVerified();
  /// 今のユーザーが、メールの確認待ちか（needsEmailVerification を使う）
  bool get currentUserNeedsEmailVerification;
}

// lib/features/auth/login_page.dart（ui）
enum LoginMode { signIn, signUp }
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.initialMode = LoginMode.signIn});
  final LoginMode initialMode;
}

// lib/features/auth/verify_email_page.dart（ui）
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});
}
```

- `signUpWithEmail` で、アカウントは作れたが確認メールの送信に失敗した場合: 例外を投げずに終える（ログイン済みになり、ルーターが確認画面に移すので、そこで送り直せる）。判断ログに書く。
- 画面のテストでは、`authRepositoryProvider` を偽物（`implements AuthRepository`）に差し替える。偽物は qa が `test/features/auth_test_helpers.dart` に作る。

## 8. 既存のテストの扱い

- 文言・構成が変わるので、次のテストの期待が変わる: `test/widget_test.dart`（「Google でログイン」→「Google で続ける」）、`test/features/login_page_test.dart`（reCAPTCHA の文言・リンクのテストは残す。360px のテストは両方のモードで）。
- 振る舞いを変えるタスクの担当者は、書き始める前に qa に「テスト更新依頼: <タスクID>、変わる振る舞い、落ちるはずのテスト」を送る。qa が新しい仕様に合わせて書き直す。**仕様が変わっていないのに落ちたテストはバグとして返す。テストを消して通さない。**
- **紹介ページのテストの注意**: 紹介ページは google_fonts を使うため、テストで表示するとフォントをネットワークから取りに行き、失敗することがある。qa はテストの中でフォントを取りに行かない方法を調べて選び、判断ログ用にリーダーへ伝える。紹介ページの書体を変えて回避しない（必要なら、テストのときだけ既定の書体にする小さな仕組みを ui に依頼する）。

## 9. タスク一覧

リーダーが共有タスクリストに、担当と依存関係を付けて登録する。

| ID | 担当 | 内容 | 依存 |
|---|---|---|---|
| T0 | qa | 品質ゲートが通る状態の確認（`flutter analyze`・`flutter test`・ルールのテスト）。`test/` の問題は直し、それ以外はリーダーに報告 | 5章の確認 |
| D1 | data | 契約（7章）を確定させ、ui・qa に通知する | T0 |
| U0 | ui | `LoginMode`・`LoginPage(initialMode:)`・`VerifyEmailPage` の空の形と、`lib/theme/brand_colors.dart` を作り、data に知らせる（analyze が通る状態で） | D1 |
| D2 | data | `auth_validators.dart`・`auth_error_message.dart`・`auth_redirect.dart` と、`AuthRepository` の追加メソッド、言語の設定（4.6・4.7・4.9） | D1 |
| D3 | data | `app.dart`: `decideRedirect` を使う振り分け、`/verify-email` のルート、`/login` の `mode`、重複した `/login` の削除（4.5）。**先に qa へテスト更新依頼** | D2, U0 |
| D4 | data | カレンダーの Google アカウントのつなぎ込み（4.8）。**5.1 の了承があるときだけ** | D1 |
| U1 | ui | ログイン画面の作り直し（4.2・4.2.1）。**先に qa へテスト更新依頼** | D2, U0 |
| U2 | ui | メールの確認画面（4.3） | D2, U0 |
| U3 | ui | 紹介ページの変更（4.4） | U0 |
| Q1 | qa | 純粋関数のテスト（検査の全条件、エラーの全 code、`decideRedirect` の表の全行、`needsEmailVerification`）と、`AuthRepository` のテスト（偽の `FirebaseAuth`） | D2, D3 |
| Q2 | qa | 画面のテスト: ログイン画面（モードの初期値、切り替えで欄が出る・消える、検査、送信で正しい引数、処理中に押せない、エラーの帯、ポップアップを閉じたときは何も出ない、再設定のダイアログ、360px）、確認画面（未確認・確認済み、送り直しの60秒、自動の確認とタイマーの停止、ログアウト）、紹介ページ（ボタンの行き先）。既存テストの書き直し | U1, U2, U3 |
| Q3 | qa | カレンダーのつなぎ込みのテスト（`google.com` がある・無い、各エラー）。偽の `FirebaseAuth`・`User` で | D4 |
| R1 | qa | データ層のまとめレビュー | D2〜D4 |
| R2 | qa | 画面のまとめレビュー | U1〜U3 |
| L1 | リーダー | 結合確認、ユーザーへの動作確認手順（12章）の提示、判断ログの更新、コミット案の提示 | すべて |

## 10. バグを防ぐための進め方

1. **担当外のファイルは編集しない。** 直してほしい箇所は担当者に SendMessage で伝える。
2. **契約を先に決める。** D1 が終わるまで、ui と qa は契約に依存する部分を書かない。
3. **各タスクの最初に、方針を3〜5行でリーダーに送る。** 特に最初のタスクは、リーダーの返事を待ってから書き始める。
4. **作業ツリーを壊れたまま放置しない。** 書きかけのコードで `flutter analyze` が通らない状態を長く残さない。
5. **品質ゲート:** タスクを完了にするたびに、`.claude/hooks/quality-gate.sh` が `flutter analyze`・`flutter test`・ルールのテストを実行する。失敗すると完了が差し戻される。
6. **仕様変更で落ちるテストは、8章の手順で qa が書き直す。** テストを消したり、期待を弱めたりして通さない。
7. **実装タスクを終えたら、qa にレビューを依頼する。** qa はレビュー依頼を最優先で処理する。
8. **画面から `FirebaseAuth.instance` を直接呼ばない。** すべて `AuthRepository` を通す（CLAUDE.md）。
9. **パスワードをどこにも残さない。** ログ（`print`・`debugPrint`）、Firestore、エラーの文言、テストの出力に、パスワードを出さない。テストのパスワードは架空の値にする。
10. **秘密情報を書かない。** API キーなどをリポジトリに書かない。
11. **判断を記録する。** 比べた案・選んだ理由・捨てた案は、リーダーが `notes/判断ログ_A.md` に「front1」として追記する（5.3 のルールの件、7章の確認メールの送信失敗の扱い、8章のフォントの件を必ず含める）。

## 11. レビューの観点

- 認証: 画面から `FirebaseAuth` を直接呼んでいないか。メールアドレスの前後の空白を除いているか。パスワードを出力していないか。新規登録で確認メールを必ず送っているか
- 振り分け: 4.5 の表のすべての行がテストにあるか。メール未確認の人が、URL を直接打っても確認画面から出られないか。Google だけの人が確認画面に送られないか。`/verify-email` から未ログインで `/welcome` に戻るか
- 確認画面: 自動の確認のタイマーが、画面を閉じたら止まるか。確認が重ならないか。送り直しの60秒が守られるか
- エラー: 4.6 のすべての code が文言になっているか。ポップアップを閉じたときに何も出ないか。再設定で登録の有無が分からないか
- ログイン画面: 処理中に二重に送れないか。`await` の後の `context.mounted`。360px ではみ出さないか。reCAPTCHA の文言とリンクがあるか
- 紹介ページ: 4.4 以外の見た目が変わっていないか。使わない import が残っていないか
- カレンダー: `google.com` がある人の動きが変わっていないか。つないだ後のトークンの扱い
- 横山さんのファイル: 5.1 で了承した範囲の外を変えていないか

## 12. 人が行う設定と動作確認

### 12.1 Firebase コンソールの設定（実装と並行してよい。動作確認の前までに）

1. Authentication → Sign-in method → 「新しいプロバイダを追加」→「メール / パスワード」→ **「メール / パスワード」を有効**にする（「メールリンク（パスワードなしでログイン）」はオフのまま）→ 保存
2. Authentication → Templates → 「メールアドレスの確認」「パスワードの再設定」の**テンプレートの言語を日本語**にする。差出人の名前を「おしあし」にする（任意）
3. （任意）Authentication → 設定 → パスワード ポリシー → 最小の長さを 8 にする（アプリの検査と合わせる）
4. 承認済みドメインは今のまま（`localhost` と公開先が入っていること）

### 12.2 動作確認（本物のプロジェクトで。届くメールアドレスを使う）

1. `/welcome` で「始める」→ ログイン画面が「新規登録」で開く。戻って右上の「ログイン」→「ログイン」で開く。戻るボタンで紹介ページへ
2. 新規登録で、形の違うメール・7文字のパスワード・確認の不一致 → 各欄にエラー
3. 正しく入れて登録 → 確認画面へ移る。**日本語の確認メール**が届く
4. 確認前に、アドレスバーで `/` などを開く → 確認画面に戻される
5. リンクを開く前に「確認しました」→「まだ確認できていません」。送り直し → 60秒押せない
6. 別のタブでメールのリンクを開く → 元のタブが数秒で自動で進み、プロフィール作成へ。名前を入れてホームへ
7. ログアウト → 「ログイン」で、違うパスワード →「メールアドレスかパスワードが違います」。正しく入れる → ホーム
8. 「パスワードを忘れた方」→ メールが届く → リンクで新しいパスワードにする → 新しいパスワードで入れる。登録していないアドレスでも、同じ文言が出る
9. 同じメールアドレスでもう一度新規登録 →「すでに登録されています」
10. 「Google で続ける」→ 今までどおりログインできる
11. メールで登録した人で、ライブ詳細からカレンダーに追加 → Google の画面でアカウントを選ぶ → 追加される。もう一度追加 → 今までと同じ動き。ログアウトして「Google で続ける」で同じ Google を選ぶ → **同じアカウント**（同じライブ一覧）で入れる
12. 別のおしあしのアカウントで使っている Google をつなごうとする → 4.8 の文言
13. **確かめて判断ログに書くこと**: Google で登録済みの Gmail のアドレスで、メール新規登録をしたときと、メールで登録済みのアドレスの Google でログインしたときに、何が起きるか
14. スマホの幅（ブラウザの開発ツールで 360px）で、ログイン・新規登録・確認画面が崩れない

## 13. リーダー（メインセッション）の進め方

1. この文書と `CLAUDE.md` を読む。リーダーは自分でコードを書かず、調整・タスク管理・ユーザーへの確認に専念する。
2. `git status -sb` で `feature/front1` にいて最新であることを確かめる（0章）。
3. `flutter analyze`・`flutter test`・ルールのテストを実行し、品質ゲートが通る状態かを確認する。通らなければ、原因をユーザーに報告して判断を仰ぐ。
4. 5章をまとめてユーザーに聞き、回答を判断ログに書き、5章に「（確認済み）」と結果を書き足す。**確認が済むまでチームメイトは作らない。**
5. チームメイトを3人作る（**モデルは Sonnet**。使用量を抑えるため）。各チームメイトはリーダーの会話履歴を見られないので、作成時の指示に必要なことを書く。
   - `dev-data` エージェントタイプで、名前 `data`。指示: 「markdown/feature_front1_auth_plan.md を読み、担当 data として D1 から始めて。D1 の方針を先に私（リーダー）に送ること。app.dart はルーターの振り分けとルートの部分以外を変えないこと。google_calendar_service.dart は <5.1 の結果> 。パスワードを出力しないこと」
   - `dev-ui` エージェントタイプで、名前 `ui`。指示: 「markdown/feature_front1_auth_plan.md を読み、担当 ui として、D1 の契約が届いたら U0 から始めて。紹介ページは 4.4 の範囲以外を変えないこと。見た目は紹介ページに合わせること」
   - `dev-qa` エージェントタイプで、名前 `qa`。指示: 「markdown/feature_front1_auth_plan.md を読み、担当 qa として T0 から始めて。以降はレビュー依頼とテスト更新依頼を最優先に。偽物のクラスは手で書き、パッケージを足さないこと」
6. 9章のタスクを共有タスクリストに登録する（担当・依存関係つき）。5.1 で了承が無いものは登録しない。
7. 進行中は、担当外ファイルの編集・同じファイルの同時編集・契約の食い違い・**横山さんのファイルへの想定外の変更**・**パスワードや秘密情報の出力**・**テストを消して通していないか**を見張る。ユーザーが決めるべきことは、まとめてユーザーに聞く。
8. すべて完了したら L1 を行う。ユーザーに 12章の設定と動作確認の手順、コミット案（メッセージと含めるファイル、横山さんのファイル・共有ファイルを変えた箇所）を示し、了承を得てからコミットする。`git push`・Pull Request・デプロイはユーザーが行う。
9. 最後にチームメイトを終了させ、チームを片付ける。

## 14. 使用量の上限で止まったときのために

- リーダーは `notes/front1_進捗.md` を、**タスクが1つ終わるたび**に更新する（状態・担当・触ったファイル・次にやること・ユーザーに聞きたいこと）。止まって再開するときは、まずこのファイルを読み、終わったタスクはやり直さない。
- Claude Code が終了してチームメイトがいなくなったら、まだ終わっていないタスクの担当だけを作り直す（13章の指示に「notes/front1_進捗.md を読み、自分の未完了のタスクから再開すること」を足す）。
- 自動で再開させるときは、引数で進捗ファイルと計画書を渡す。
  - 見張り役（tmux）: `bash .claude/scripts/auto-resume.sh <送り先のペイン> notes/front1_進捗.md`
  - 非対話（tmux なし）: `bash .claude/scripts/auto-resume-headless.sh notes/front1_進捗.md markdown/feature_front1_auth_plan.md`
- 使用量を抑えるルール（全員）: メッセージは短く、ファイルの中身やテストの出力を丸ごと貼らない。作業中のテストは関係するファイルだけを実行し、全体は完了時の品質ゲートに任せる。長い出力は末尾だけを見る。計画書は自分に関係する章だけを読み直す。進み具合の確認のためだけのメッセージを送り合わない。
- 許可の確認で止まらないように、シェルのコマンドは1つずつ実行する（`;`・`&&`・`|` でつながない、`$変数` を使わない）。ファイルの読み書き・検索は Read・Edit・Grep などの道具を使う。
