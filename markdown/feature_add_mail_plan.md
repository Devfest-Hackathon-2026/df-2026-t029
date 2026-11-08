# 計画書: プロフィールに「メールアドレスの変更」を足す（案C「アカウントの行＋ボトムシート」。feature/add_mail）

> 担当の作業を、Claude Code の agent team（リーダー＋チームメイト3人＝**4エージェント。モデルは Sonnet 5.5**）で実装するための指示書（仕様書を兼ねる）。人間とエージェントの両方が読む。
> 4章はユーザーが渡したデザイン（`おしあし_メール表示変更_案C_ボトムシート.html`）を Dart（Flutter）で再現するための仕様。「5. 実装前に確かめること」だけが、リーダーがユーザーに聞く項目（どれも推奨案つき）。
> **この計画書のコードは、Flutter がクラウドの環境に無いため、一度もコンパイルしていない。** 写すときは `flutter analyze` で確かめる。
> 書き方は `markdown/feature_after_login_help_plan.md`・`markdown/feature_before_login_c_plan.md` に合わせた。章の番号も同じ並びにしてある。

## 0. 作業ブランチと前提

- **作業ブランチは `feature/add_mail`**（`origin/feature/add_mail` を追う。2026-11-08 時点で、位置は PR #61 のマージ `1346169`＝ログイン後のリデザインとヘルプシートを含む）。ブランチの作成・切り替え・pull・push・マージは人間が行う。エージェントはブランチを切り替えない。
- 完成したら、人間が `feature/add_mail` から `dev` へ Pull Request を出す。PR の前に、人間が `git merge origin/dev` で追いつく。
- 開始前に、リーダーは `git status -sb` で `feature/add_mail` にいて、`origin/feature/add_mail` より遅れていない（`behind` が無い）ことを確かめる。
- **前提（実装済み）**: ログイン後のデザイン（統合案 v4「ハコ色」）、ヘルプシート（`lib/features/help/**`。ボトムシートの作りの手本）、プロフィール画面（`lib/features/profile/profile_page.dart`）、メール・Google でのログイン、メールの確認待ち画面（`verify_email_page.dart`。確認メールの送り直し・5秒ごとの自動確認の手本）。Cloud Functions は動いている（Blaze に切り替え済み・11/7）が、**この機能の推奨案では使わない**（5.1）。
- **Dart（Flutter）で書く。** JavaScript・HTML で画面を作らない。見本の HTML は見た目の見本で、アプリには入れない。
- Firebase は今のまま。**デプロイ（`firebase deploy`）・`git push` はしない。** 推奨案（5.1 の案A）では、ルール・関数・索引の変更が無いので、デプロイも要らない。
- 締切: 提出は **11/10 19:00**（`markdown/add/add_K.md` より）。チームの計画では 11/8 夜に機能を凍結する予定だった。**間に合わなければ、1章の P2 から落とす**。途中の状態を `dev` に入れない。

## 1. 範囲

**優先度（提案。間に合わないときは P2 から落とす）**

| 優先度 | 内容 |
|---|---|
| P1 | メールで登録した人が、プロフィールの「アカウント」の行から、シートでメールアドレスを変えられる（入力 → 確認 → 完了）。パスワードでの本人確認（必要なときだけ）。エラーの表示 |
| P2 | Google で登録した人向けの表示（変更はできない説明）、メールアドレスの「表示／かくす」、完了後の SnackBar、ログインの有効期限が切れたときの案内 |

**作るもの**

1. プロフィール（編集のとき）の最下部に「アカウント」の区画。メールアドレス（伏せ字）の行1つ。
2. 行を押すと、下からシート（ボトムシート）が開き、「入力 → 確認 → 完了」の3ステップで変更する。
3. 変更の本体は、Firebase Authentication の `verifyBeforeUpdateEmail`（確認のリンクを新しいアドレスに送る。5.1 の案A）。
4. Google で登録した人には、変更の行ではなく説明つきの表示だけを出す。
5. 純粋関数（伏せ字・入力の検査・登録方法の判定）、`AuthRepository` のメソッド、シートの状態を持つプロバイダ。
6. 上のものを守るテスト（8章）。

**作らないもの**

- 確認の「6桁のコード」（5.1。案B は別の計画書になる）・Cloud Functions・外部のメール送信サービス・`firestore.rules` の変更
- メールアドレスの Firestore への保存（今も保存していない。Authentication だけが持つ）
- パスワードの変更・アカウントの削除・Google アカウントの連携の追加
- ログイン前の画面・確認待ち画面の見た目と動き（`verify_email_page.dart` は読むだけ）
- 写真・書体ファイルの追加・依存パッケージの追加（`pubspec.yaml` に触らない）
- 見本にだけあって、本番に出さないもの: 右の説明の枠（`.notes`）、スマホの枠、上の「表示を切り替え」（メール／Google の切り替え）、確認コード `123456`・`used@example.com` などの試し用の分岐

## 2. 決まっていること（ユーザーの指示）

| 項目 | 決定 |
|---|---|
| デザイン | ユーザーが渡した `おしあし_メール表示変更_案C_ボトムシート.html`（案C）と同じ見た目にする。見本は `markdown/design_add_mail/oshiashi_mail_C_bottom_sheet.html`（元のファイルを、ファイル名だけ変えて置いた） |
| 言語 | Dart（Flutter）。JavaScript ではない |
| 作業ブランチ | `feature/add_mail` |
| 実装のしかた | Claude Code の agent team。**最低3人のチームメイト**（auth-data・ui・qa）＋リーダー。この計画書が指示書 |
| チームのモデル | Sonnet 5.5（`claude-sonnet-5-5`）。`.claude/agents/*.md` の `model:` の有無と、リーダーの既定を、起動時に確かめる（13章の 0） |

## 3. 現状のコード（調べたこと）

| 項目 | 今の状態 | 場所 |
|---|---|---|
| プロフィール画面 | `ProfilePage`（`ConsumerStatefulWidget`）。編集のとき: アイコン → 説明 → ハンドルネーム → X → 「保存」→ 太い線 → テーマカラー → 線 → リマインド通知（`NotificationSwitch`）。**初回の作成のときは、テーマカラーと通知を出さない**。上のバーの色はテーマカラー（`primaryContainer`） | `lib/features/profile/profile_page.dart` |
| 認証のリポジトリ | `AuthRepository`（`FirebaseAuth` を受け取る）。`currentUser`・`signInWithGoogle`・`signUpWithEmail`・`signInWithEmail`・`sendPasswordResetEmail`・`resendEmailVerification`・`reloadEmailVerified`・`signOut`。**メールの変更・再認証のメソッドは無い**。`authRepositoryProvider` は呼ばれると `FirebaseAuth.instance` を使う（Firebase を初期化していないテストでは落ちる） | `lib/repositories/auth_repository.dart` |
| 確認待ち画面（手本） | 5秒ごとに `reload` して確認。送り直しは 60 秒のクールダウン。「確認しました」ボタン。エラーは `authErrorMessage(code)`。例外の中身は画面に出さない | `lib/features/auth/verify_email_page.dart` |
| エラーの文言 | `authErrorMessage(code)`。`email-already-in-use` は「…すでに登録されています。『ログイン』から入ってください。」（**登録の画面向け。メール変更では使わない**）、`requires-recent-login` は「もう一度ログインしてから、お試しください。」 | `lib/utils/auth_error_message.dart` |
| 入力の検査 | `validateEmail`（正規表現は `^[^@\s]+@[^@\s]+\.[^@\s]+$`） | `lib/utils/auth_validators.dart` |
| 登録方法の判定 | `needsEmailVerification` が `providerData` の `password` を見ている。`User.providerData` の `providerId` は、メールが `password`、Google が `google.com` | `lib/utils/auth_redirect.dart`・`auth_repository.dart` |
| ボトムシートの手本 | `showHelpSheet`（`showModalBottomSheet`・`isScrollControlled: true`・つまみ・角丸 22・2px の墨の枠・PC は最大幅 640）。新しいシートも同じ作りにする | `lib/features/help/help_sheet.dart` |
| メールアドレスの保存 | **どこにも保存していない**（`users/{uid}`・`UserProfile` に無い）。Google カレンダー連携が `user.email` を読むだけ | `lib/models/user_profile.dart`・`lib/services/google_calendar_service.dart` |
| テストの偽物 | `FakeAuthRepository implements AuthRepository`（手書き）。**`AuthRepository` にメソッドを足すと、この偽物がコンパイルできなくなる**ので、qa が同時に直す | `test/features/auth_test_helpers.dart` |
| 品質ゲート | `.claude/hooks/quality-gate.sh`（`flutter analyze`・`flutter test`・ルールのテスト）。タスクを完了にするたびに動く | `.claude/hooks/` |

## 4. 仕様（デザイン）

### 4.0 見本の読み方

- 見本は `markdown/design_add_mail/oshiashi_mail_C_bottom_sheet.html`（1ファイル）。**CSS の値が正**。見るのは `VARIANT='C'` の分岐だけ（`A`・`B` は別案。作らない）。`loginA`・`fieldB` は使わない。`accountC()`・`flowHTML()`・`stepper()` と、`.sheet` まわりの CSS を見る。
- **px はそのまま論理ピクセル**にする。書体の太さ 800 は 700 にする（`HakoFonts.jp` は 700 まで）。行の高さは `HakoFonts` の既定（1.75）のままにせず、見本の `line-height` を渡す。
- 見本の色は `--c`（テーマカラー）と `--onc`（その上の文字）。アプリでは **`colorScheme.primaryContainer` と `onPrimaryContainer`** を使う（ほかの画面と同じ）。`--err`（`#B3261E`）は `BrandColors.errorText`、`--muted` は `BrandColors.sub`、`--line` は `BrandColors.rowLine`。
- **見本のとおりにしない箇所（意図して変える）**:

| 見本 | 変えること | 理由 |
|---|---|---|
| 新しいアドレスに「6桁の確認コード」を送る | **確認のリンク**を送る。コードの入力欄・「確認して変更する」は無い。ステップ2は「リンクを開くのを待つ」画面（4.4） | Firebase の標準では、6桁のコードのメールは送れない（5.1） |
| 有効期限10分・入力は3回まで | 無い（リンクの有効期限は Firebase の既定。数字は画面に出さない） | コードが無いため |
| 再送の待ち 30 秒 | **60 秒** | 既存の確認待ち画面と同じ。メールの送りすぎを避ける |
| 変更前の本人確認（見本の「決めておきたいこと」） | **必要になったときだけ**、パスワード欄を足す（4.6） | Firebase が「最近のログイン」を求めるため（5.2） |
| 「変更後、これまでのアドレスにもお知らせを送りました」と言い切る | Firebase 標準のお知らせ。**届くことを動作確認（12章）で確かめるまで、完了の文は「届きます」の形**（4.9） | 送るのは Firebase で、アプリは送らない |
| 「心当たりがない場合は、お問い合わせください」 | 「心当たりがない場合は、ログイン画面の『パスワードを忘れた方』から、パスワードを変え直してください。」 | アプリに問い合わせ先が無い |
| 見本の説明文は「シート内の『表示』で全体を確認」とあるが、**見本のコードでは、「表示」は Google の行にだけあり、メール登録の行とシートには無い** | シートの「いまのメールアドレス」の横に「表示／かくす」を付ける（P2）。ページ上の行は伏せ字のまま | 説明文のとおりにする |
| 確認メールが届いたかを `Enter` などで確かめる（試し用） | 無い | 試し用 |

- 見本は端末の書体（Mac なら Hiragino Sans）で出る。アプリは BIZ UDPGothic なので、文字の形と折り返しが少し違う。

### 4.1 要件の一覧

| ID | 優先 | 内容 | 章 |
|---|---|---|---|
| M1 | P1 | プロフィール（編集）の最下部に「アカウント」の区画。メール登録の人には、メールアドレス（伏せ字）の行 | 4.2 |
| M2 | P1 | 行を押すとシートが開く。入力 → 確認 → 完了 | 4.3・4.4 |
| M3 | P1 | 入力の検査とエラーの表示 | 4.5 |
| M4 | P1 | 必要なときだけのパスワードでの本人確認 | 4.6 |
| M5 | P2 | Google 登録の人には、変更の行ではなく説明つきの表示 | 4.2 |
| M6 | P2 | 「表示／かくす」・完了後の SnackBar・ログインの有効期限が切れたときの案内 | 4.2・4.7 |

### 4.2 「アカウント」の区画（M1・M5）

- **出す場所**: `ProfilePage` の、`NotificationSwitch` の下。**編集のときだけ**（初回の作成では出さない。テーマカラー・通知と同じ条件）。上に 22 の余白。
- **出す条件**: 登録方法（`accountKindOf`。7章）が `email` か `google` のとき。`other` のときは区画ごと出さない。**パスワードでのログイン方法を持っている人は `email`**（Google も連携している人も `email`）。
- **見出し**: 「アカウント」（18・700）。下に 10。

**メール登録の人（`email`）の行**

| 項目 | 値（見本の `.row-btn`） |
|---|---|
| 行 | 全幅のボタン。最小の高さ 64。上に 1.5px の線（`rowLine`）。左のアイコン（`Icons.mail_outline` 24）・中央のテキスト・右に `Icons.chevron_right` 20。間 12 |
| 題 | 「メールアドレス」（16・600→700） |
| 補足 | 伏せ字のメールアドレス（13・`sub`・折り返しは文字の途中でもよい）。上に 2 |
| 下の説明 | 「ログインに使うメールアドレスです。タップして変更できます。」（12・`sub`・行の高さ 1.6） |
| 押したとき | シートを開く（4.3） |

**Google 登録の人（`google`）の行（P2）**

| 項目 | 値 |
|---|---|
| 行 | 押せない（タップしても何も起きない）。左のアイコン（`Icons.verified_user_outlined` 24）・題・補足・右に「表示／かくす」 |
| 題 | 「Googleアカウントでログイン中」 |
| 補足 | 伏せ字（「表示」を押すと全体） |
| 下の説明 | 「メールアドレスは、Googleアカウント側で管理されています。変更するには、Googleアカウントの設定から行ってください。」 |

**伏せ字**（`maskEmail`。7章）: `@` の前の先頭 2 文字だけを出し、残りは `*`。`*` の数は「`@` の前の長さ − 2」、**最低 3 個**。`@` の後ろはそのまま。例: `ken-oshi@example.com` → `ke******@example.com`（`*` が 6 個）、`ab@x.com` → `ab***@x.com`、`a@x.com` → `a***@x.com`。`@` が無い文字列は `***`。メールアドレスが無い（null）ときは行ごと出さない。

**「表示／かくす」ボタン（P2）**: 見本の `.eye`。アイコン（`Icons.visibility_outlined`／`visibility_off_outlined` 18）＋文字（13・700・下線）。高さ 40 以上。押すたびに全体と伏せ字が切り替わる。状態は画面を開くたびに「かくす」に戻る（保存しない）。ページの行（Google のとき）とシートの「いまのメールアドレス」で、同じ状態を使う。

### 4.3 シート（M2）

`showHelpSheet` と同じ作りの `showModalBottomSheet`。ルートは足さない。

| 項目 | 値（見本の `.sheet`・`.backdrop`） |
|---|---|
| 背景・枠 | 背景 `paper`。上と左右に 2px の墨の枠、上の角丸 22。下辺の線は、出ても許容 |
| 余白 | 上 10・左右 20・下 24（キーボードが出たら、その分だけ下を上げる。`MediaQuery.viewInsetsOf`） |
| 最大の高さ | 画面の高さの **90%**（`isScrollControlled: true`）。あふれたらシートの中をスクロール |
| 背景の暗幕 | 墨の 45%。タップで閉じる |
| 幅 | スマホは全幅。**PC（幅 720 以上）は最大幅 640 で、下の中央に置く** |
| 動き | 既定の動き。`MediaQuery.disableAnimations` のときは動かさない（`sheetAnimationStyle: AnimationStyle.noAnimation`） |
| つまみ | 幅 44・高さ 5・角丸 3・墨の 30%・中央。下に 12 |
| 見出しの行 | 左に「メールアドレスを変更」（18・700）、右に閉じるボタン（`Icons.close` 22・押せる範囲 44×44）。下に 12 |
| 閉じ方 | 閉じるボタン・暗幕のタップ・Esc キー・完了後のボタン。**途中で閉じてもよい**（確認待ちのときも。リンクは有効なまま）。閉じたら「アカウント」の行にフォーカスが戻る |

**ステッパー**（見本の `.stepper`。見出しの行の下に 4、下に 18）

- 3つの段（「入力」「確認」「完了」）を、細い棒でつなぐ。横並び・間 6。
- 1段: 丸（直径 26・枠 2px の墨・数字 13）＋ラベル（13・700）。
  - これから: 丸は白・ラベルは `sub`。
  - 今: 丸は `primaryContainer`（文字は `onPrimaryContainer`）・ラベルは墨。
  - 済み: 丸は墨・中に白いチェック（14）・ラベルは `sub`。
- 棒: 高さ 2・墨の 35%・最小幅 12・余った幅を使う。
- 読み上げ: 「ステップ N / 3」。

### 4.4 流れ（M2）

**ステップ1「入力」**

| 部品 | 値 |
|---|---|
| 説明文 | 「新しいメールアドレスに、確認のメールを送ります。メールのリンクを開くと、変更が終わります。それまでは、いまのメールアドレスのままです。」（15・行の高さ 1.7） |
| いまのメールアドレス | 小さな題「いまのメールアドレス」（13・`sub`）＋メールアドレス（15・700・折り返しは途中でもよい）。上に 14、下に 6。右に「表示／かくす」（P2）。初めは伏せ字 |
| 入力欄 | 題「新しいメールアドレス」（13・700。上に 16、下に 4）。欄は最小の高さ 50・枠 2px の墨・角丸 12・背景 白・余白 8×14・文字 17。`TextInputType.emailAddress`・`autofillHints: [email]`・自動修正と大文字化なし。ヒント「example@mail.com」。エラーのとき、枠が `errorText` の色になり、まわりに「白 2px＋エラー色 4px」の輪が出る |
| エラーの行 | 欄の下。アイコン（`Icons.error_outline` 18）＋文（13・700・`errorText`・行の高さ 1.55）。上に 8。無いときは何も出さない（高さ 0）。読み上げは `liveRegion` |
| パスワード欄 | 通常は出さない。4.6 のとき、入力欄の下に出す |
| 主ボタン | 「確認メールを送る」。全幅・高さ 48 以上・角丸 14・枠 2px の墨・背景は `FilledButton` と同じ（テーマカラー）・文字 15・700。**新しいアドレスが空のあいだは押せない**（不透明度 45%）。処理中は押せなくし、「送信中…」にする。上に 16。Enter キーでも送る |

**ステップ2「確認」（リンクを開くのを待つ）**

| 部品 | 値 |
|---|---|
| 説明文 | 「**{送ったアドレス}** に、確認のメールを送りました。メールのリンクを開いてください。」（15・1.7。アドレスは 700・折り返しは途中でもよい） |
| 補足 | 「リンクを開くと、この画面は自動で次に進みます。メールが届かないときは、迷惑メールフォルダもご確認ください。このシートを閉じても、リンクを開けば変更されます。」（13・`sub`・1.7・上に 6） |
| 主ボタン | 「リンクを開いたので確認する」。押すと、すぐに状態を読み直す（`check(manual: true)`）。まだなら、エラー行に「まだ確認できていません。メールのリンクを開いてから、もう一度押してください。」。処理中は押せなくする |
| リンク2つ（中央・縦に並べる。見本の `.links`。各 高さ 44 以上・14・700・下線） | 「確認メールを再送する」（待ちの間は「確認メールを再送する（あと{N}秒）」で押せない・不透明度 50%・下線なし）／「メールアドレスを入力し直す」（ステップ1に戻る。入力は残す） |
| 自動の確認 | 5 秒ごとに状態を読み直す。画面に何も出さない。**ステップ2を出している間だけ**動かす（閉じたら止める） |
| 再送 | 押すと確認メールをもう一度送り、「確認メールを再送しました」を SnackBar で出し、待ちを 60 秒にする |

**ステップ3「完了」**

| 部品 | 値 |
|---|---|
| 丸 | 直径 72・背景 `primaryContainer`・枠 2px の墨・中にチェック（`Icons.check` 38）。中央。下に 14 |
| 見出し | 「メールアドレスを変更しました」（20・700・中央） |
| 本文 | 「次回から、**{新しいアドレス}** でログインします。」「これまでのメールアドレスにも、変更のお知らせが届きます。心当たりがない場合は、ログイン画面の『パスワードを忘れた方』から、パスワードを変え直してください。」（14・`sub`・1.7・中央・上に 8） |
| 主ボタン | 「プロフィールに戻る」。シートを閉じ、SnackBar「メールアドレスを変更しました」を出す。行の伏せ字が、新しいアドレスに変わる |

**状態の遷移**: 入力 →（送れた）→ 確認 →（新しいアドレスになったのを確認できた）→ 完了。確認から「入力し直す」で入力へ戻れる。完了からは戻れない。

**確認できたかの判定**: `reload` したあとの `currentUser.email` が、送ったアドレスと同じ（大文字小文字は区別しない）なら完了。

### 4.5 検査とエラー（M3）

| いつ | 条件 | 出す文（エラーの行） |
|---|---|---|
| 「確認メールを送る」を押したとき | 形式が正しくない（正規表現 `^[^\s@]+@[^\s@]+\.[^\s@]{2,}$`。前後の空白は除いて見る） | メールアドレスの形式が正しくありません。（例：example@mail.com） |
| 同上 | いまのアドレスと同じ（大文字小文字は区別しない） | いま使っているメールアドレスと同じです。別のメールアドレスを入力してください。 |
| 送信の結果 | `email-already-in-use` | このメールアドレスは、すでに別のアカウントで使われています。 |
| 同上 | `invalid-email` | メールアドレスの形式が正しくありません。（例：example@mail.com） |
| 同上 | `requires-recent-login` | **文は出さない**。4.6 のパスワード欄を出す |
| 同上 | `too-many-requests` | 試した回数が多すぎます。しばらく待ってから、もう一度お試しください。 |
| 同上 | `network-request-failed` | 通信できませんでした。電波の良いところで、もう一度お試しください。 |
| 同上 | それ以外の `FirebaseAuthException` | うまくいきませんでした。もう一度お試しください。（コードは画面に出さない） |
| 同上 | `FirebaseAuthException` 以外 | うまくいきませんでした。もう一度お試しください。（例外の中身は出さない） |

- 文言は `emailChangeErrorMessage(code)`（新しい関数。7章）にまとめる。**既存の `authErrorMessage` は変えない**（登録・ログインの画面が使い、テストがある）。
- 入力を直し始めたら、エラーの行を消す。
- **注意（動作確認で確かめる。5.5）**: 既に使われているアドレスのとき、Firebase が `email-already-in-use` を返さず、成功したように見える設定（メール列挙の保護）の可能性がある。その場合、ステップ2で待ち続けるだけになる。**画面で「すでに使われています」を出せるのは、Firebase が返したときだけ**。返らないなら、見本のその文は作れないと、リーダーがユーザーに伝える。

### 4.6 パスワードでの本人確認（M4）

Firebase は、メールアドレスの変更のような重要な操作に、**最近のログイン**を求めることがある（`requires-recent-login`）。そのときだけ、同じシートで本人確認をする。

1. ステップ1で「確認メールを送る」を押す → `requires-recent-login` が返る。
2. 入力欄の下に、パスワード欄を足す。説明の1行「安全のため、パスワードをもう一度入力してください。」（13・700・上に 16）。欄の題「パスワード」。見た目は入力欄と同じ。`obscureText`・`autofillHints: [password]`・自動修正なし。
3. もう一度「確認メールを送る」を押す → 先に再認証（`reauthenticateWithPassword`）→ 成功したら確認メールを送る。
4. 再認証に失敗（`invalid-credential`・`wrong-password`・`invalid-login-credentials`）→ エラーの行に「パスワードが違います。」。パスワード欄は残す。`too-many-requests` は 4.5 の表のとおり。
5. パスワード欄に入れた文字は、画面を閉じたら残さない。ログ・例外・テストの出力に出さない。

### 4.7 ログインの有効期限が切れたとき（M6）

メールの変更が済むと、Firebase が古いログインを無効にする場合がある（動作確認で確かめる。5.5）。確認待ちの自動確認が、`user-token-expired`・`invalid-user-token`・`user-not-found` のどれかで失敗したら、**変更が済んだ可能性が高い**ものとして、ステップ3の別の形を出す。

| 部品 | 値 |
|---|---|
| 見出し | 「ログインの有効期限が切れました」 |
| 本文 | 「メールのリンクを開いた場合は、新しいメールアドレスでログインし直してください。」 |
| 主ボタン | 「ログイン画面へ」（ログアウトして、ルーターに振り分けをやり直させる） |

アプリ側でログアウトの状態になったときは、ルーターが `/welcome` に移す（既存の動き）。そのときシートは画面ごと消える。

### 4.8 読み上げ・キー・動き・はみ出し

- **読み上げ**: シートは `Semantics(scopesRoute: true, namesRoute: true, label: 'メールアドレスを変更')`。エラーの行・SnackBar は `liveRegion`。入力欄にはラベルを付ける（見た目の題と同じ文）。伏せ字のメールアドレスは、そのまま読み上げる（`*` を「アスタリスク」と読まれないよう、行の `Semantics` のラベルは「メールアドレス、伏せて表示中」にする）。
- **キーボード**: 入力欄で Enter → 送る。シートが開いたら、フォーカスは入力欄へ。ボタン・リンクはフォーカスが見える。
- **動き**: シートの出入りと、ステッパーの切り替えに動きを付けない（`disableAnimations` と同じ扱いでよい）。
- **はみ出し**: 幅 320・360・390・430・720・1000、文字 1.0 倍と 1.3 倍で、はみ出さない。長いメールアドレスは折り返す。キーボードが出たとき、入力欄とボタンが隠れない（シートの中をスクロールできる）。
- **キー**: 4.10。既存のキー（`profile_*` など）は**残す**。

### 4.9 文言一覧（コピーして使う）

**アカウントの区画**: 4.2 の表のとおり。

**シート（共通）**

| 場所 | 文言 |
|---|---|
| 見出し | メールアドレスを変更 |
| 閉じるボタンの案内 | 閉じる |
| ステッパーの段 | 入力／確認／完了 |

**ステップ1・2・3・エラー・パスワード**: 4.4〜4.6 の表のとおり（見本から変えた箇所は 4.0 の表）。

**SnackBar**

| 場面 | 文言 |
|---|---|
| 再送したとき | 確認メールを再送しました |
| 完了のあと | メールアドレスを変更しました |

### 4.10 キー一覧（新しく付けるもの）

| キー | 付ける部品 |
|---|---|
| `profile_account_section` | 「アカウント」の区画の一番外 |
| `profile_email_row` | メール登録の人の行（タップを受ける部品自身） |
| `profile_google_row` | Google 登録の人の行 |
| `email_reveal_button` | 「表示／かくす」（ページの Google の行・シートで、それぞれ1つ。シートの中のものは `email_sheet_reveal_button`） |
| `email_sheet` | シートの中身の一番外 |
| `email_sheet_close` | 閉じるボタン |
| `email_sheet_stepper` | ステッパー |
| `email_new_field` | 新しいメールアドレスの入力欄 |
| `email_password_field` | パスワード欄 |
| `email_error` | エラーの行 |
| `email_send_button` | 「確認メールを送る」 |
| `email_check_button` | 「リンクを開いたので確認する」 |
| `email_resend_button` | 「確認メールを再送する」 |
| `email_back_button` | 「メールアドレスを入力し直す」 |
| `email_done_button` | 「プロフィールに戻る」／「ログイン画面へ」 |

## 5. 実装前に確かめること（リーダー → ユーザー）

**リーダーは、チームメイトを作る前に、下の項目をまとめてユーザーに聞く。** どれも推奨案つき。答えを `notes/判断ログ_A.md` に書き、この表の「回答」の列を埋める。**確認が済むまでチームメイトは作らない。**（CLAUDE.md の「未決定事項は自分で確定させない」に従い、案・理由・捨てる案を添えて示す）

| 項目 | 推奨案 | 理由・ほかの案 | 回答 |
|---|---|---|---|
| 5.1 確認の方法 | **案A: Firebase 標準の確認リンク**（`verifyBeforeUpdateEmail`。新しいアドレスにリンクのメールが届き、開くと変わる）。シートの見た目は見本のまま、ステップ2が「リンクを開くのを待つ」になる（コードの入力欄が無い） | 見本の「6桁のコード」は、Firebase Authentication の標準では送れない。案B: 6桁のコードにする（Callable Functions で作り、メールの送信は外部のサービス＋Secret が要る。ルール・関数のデプロイは人間。コードの有効期限・回数の上限・再送の間隔を自作する。**提出（11/10 19:00）までに、安全に作りきるのは難しい**）。案C: 見本のとおりの画面だけを作り、確認は形だけにする（**何も守らない偽の安全に見えるので捨てる**）。B を選ぶ場合、この計画書を作り直す（付録） | 案A で確定（11/8） |
| 5.2 本人確認（パスワード） | **案A: Firebase が求めたときだけ、同じシートにパスワード欄を足す**（4.6） | 見本の「決めておきたいこと」に当たる。余計な手間を増やさず、安全な操作は守れる。案B: 毎回、最初にパスワードを聞く（確実だが毎回手間）。案C: 聞かない（Firebase が求めたとき、失敗するだけになる） | 案A で確定（11/8） |
| 5.3 これまでのアドレスへのお知らせ | **案A: Firebase 標準のお知らせに任せる**（アプリでは送らない）。完了の文は「届きます」の形。12章で届くことを確かめ、届かなければ、その1文を消す | 見本は「送る前提」。アプリから送るには、メール送信の仕組み（5.1 の案B と同じ）が要る。案B: 届かなくても、見本のとおり言い切る（誤った案内になるので捨てる） | 案A で確定（11/8） |
| 5.4 メールアドレスの見せ方 | **案A: 見本のとおり伏せ字**（先頭 2 文字だけ）。「表示」で全体 | 肩越しに見られても分からないようにするため。案B: 最初から全体を出す | 案A で確定（11/8） |
| 5.5 動作確認で分かること（決める項目ではない） | 実際に動かして分かった結果を、リーダーが判断ログに書き、4.5・4.7 を直す | ① 既に使われているアドレスのとき、`email-already-in-use` が返るか（返らないなら「すでに使われています」は出せない）。② 変更後に、ログインが切れるか（切れるなら 4.7 の画面）。③ これまでのアドレスにお知らせが届くか（5.3）。④ 確認のメールの文面・リンクの先が日本語・正しいドメインか | |
| 5.6 共有のファイルへの変更 | **案A: マージの前に一声かける**。`auth_repository.dart`（認証。ログイン・確認待ちが使う）と `auth_test_helpers.dart`（偽物）と `profile_page.dart` に足す | 足すだけで、既存の動きは変えない。案B: 何も言わない | 案A で確定（11/8） |

## 6. 担当とファイル

同じファイルを2人が同時に編集すると上書きが起きる。**担当外のファイルは編集せず、担当者に SendMessage で依頼する。**

| 担当 | 名前 | 編集してよいファイル |
|---|---|---|
| リーダー | （メインセッション） | この計画書、`notes/判断ログ_A.md`、`notes/add_mail_進捗.md` |
| データ層・認証 | `auth-data` | `lib/utils/email_change.dart`（新規）、`lib/utils/auth_error_message.dart`（**新しい関数 `emailChangeErrorMessage` の追加のみ**）、`lib/repositories/auth_repository.dart`（**メソッドの追加のみ**。既存のメソッドの動きは変えない）、`lib/providers/email_change_providers.dart`（新規） |
| 画面 | `ui` | `lib/features/profile/account_section.dart`（新規）、`lib/features/profile/email_change_sheet.dart`（新規）、`lib/features/profile/profile_page.dart`（**「アカウント」の区画を足すだけ**。ほかの動きは変えない） |
| テスト・レビュー | `qa` | `test/**`（`test/features/auth_test_helpers.dart` の `FakeAuthRepository` を含む）、`notes/add_mail_レビュー記録.md`（新規） |

- **読むだけ（変更禁止）**: `lib/features/auth/**`（ログイン・確認待ち）、`lib/utils/auth_redirect.dart`・`auth_validators.dart`、`lib/features/help/**`・`lib/theme/**`、`lib/app.dart`、`lib/models/**`・`lib/repositories/**`（`auth_repository.dart` を除く）・`lib/services/**`、`firestore.rules`・`storage.rules`・`test_rules/**`・`functions/**`、`pubspec.yaml`、`assets/**`、`web/**`。**差分は `git diff --stat` で確かめる。**
- 共有の部品（ボタン・色・書体）で足りないことが出たら、自分で直さず、リーダーに報告する（`lib/features/profile/` の中に作って済ませる）。
- `auth-data` が先に契約（7章）を作って渡す。`ui` と `qa` は、`auth-data` のファイルを直接直さず、`auth-data` に SendMessage で頼む。
- `AuthRepository` にメソッドを足すと、`FakeAuthRepository`（テストの偽物）が動かなくなる。**`auth-data` は、メソッドを足す前に、`qa` に「偽物に足してほしいメソッド（名前・引数・返り値）」を送る**。`qa` は同じタイミングで偽物を直す。
- **依存パッケージは足さない。** 画像・書体ファイルを足さない。

## 7. 契約（インターフェース）

> コードは**一度もコンパイルしていない**。名前・引数の形を決めるための下書き。`auth-data` が書き写して `flutter analyze` で確かめ、変えた点は `ui`・`qa` に知らせる。Firebase の関数の名前は、`firebase_auth` ^7 のものを `.dart_tool` や pub の資料で確かめてから使う。

**`lib/utils/email_change.dart`**（Firebase に依存しない純粋関数）

```dart
/// 伏せ字。'ken-oshi@example.com' → 'ke******@example.com'。
/// @ の前の先頭 2 文字だけ出し、* は max(3, 長さ-2) 個。'ab@x.com' → 'ab***@x.com'。
/// @ が無ければ '***'。
String maskEmail(String email);

/// 新しいアドレスの検査（4.5）。正しければ null。
/// 前後の空白を除いて見る。current と同じ（大文字小文字は区別しない）ならエラー。
String? validateNewEmail(String input, {required String? current});

/// 登録方法。パスワードのログイン方法を持っていれば email、
/// なくて google.com を持っていれば google、どちらも無ければ other。
enum AccountKind { email, google, other }
AccountKind accountKindOf(Iterable<String> providerIds);
```

**`lib/utils/auth_error_message.dart` に足すもの**

```dart
/// メール変更の画面用の文言（4.5）。既存の authErrorMessage は変えない。
/// requires-recent-login は null（文を出さず、パスワード欄を出す）。
String? emailChangeErrorMessage(String code);
```

**`lib/repositories/auth_repository.dart` に足すもの（メソッドの追加のみ）**

```dart
/// 今のユーザーのメールアドレス。いなければ null
String? get currentEmail;

/// 今のユーザーのログイン方法の ID（'password'・'google.com' など）
List<String> get providerIds;

/// 新しいアドレスに確認のメールを送る（verifyBeforeUpdateEmail）。
/// アドレスは前後の空白を除く。ユーザーがいなければ StateError。
/// FirebaseAuthException（requires-recent-login など）はそのまま投げる。
Future<void> startEmailChange(String newEmail);

/// パスワードで再認証する（reauthenticateWithCredential）。
/// いまのアドレスと渡したパスワードで EmailAuthProvider.credential を作る。
Future<void> reauthenticateWithPassword(String password);

/// ユーザーを読み直し、いまのメールアドレスを返す（reload）。
/// ログインが無効になっていれば FirebaseAuthException を投げる。
Future<String?> reloadCurrentEmail();
```

**`lib/providers/email_change_providers.dart`**

```dart
enum EmailChangeStep { input, waiting, done }

class EmailChangeState {
  const EmailChangeState({
    this.step = EmailChangeStep.input,
    this.newEmail = '',
    this.sentTo = '',
    this.error,               // エラーの行の文。null なら出さない
    this.needsPassword = false, // 4.6。true の間、パスワード欄を出す
    this.busy = false,        // 送信・確認の最中（ボタンを押せなくする）
    this.resendLeft = 0,      // 再送まで残りの秒数
    this.sessionEnded = false, // 4.7。done のとき、別の形を出す
  });
  // copyWith も持つ
}

/// 4.4 の流れ。シートを開くたびに新しく作る（autoDispose）。
class EmailChangeNotifier extends Notifier<EmailChangeState> {
  @override
  EmailChangeState build();   // ref.onDispose で、確認のタイマーと待ちのタイマーを止める

  /// 「確認メールを送る」。検査 → （needsPassword なら再認証）→ startEmailChange。
  /// 成功したら step=waiting・sentTo を入れ、待ち 60 秒と自動の確認を始める。
  Future<void> submit({required String newEmail, String? password});

  /// 状態を読み直す。manual は「リンクを開いたので確認する」ボタンから（結果を出す）。
  /// いまのアドレスが sentTo と同じ（大文字小文字は区別しない）なら done。
  Future<void> check({required bool manual});

  /// 「確認メールを再送する」。待ちの間は何もしない。
  Future<void> resend();

  /// 「メールアドレスを入力し直す」。入力は残し、タイマーを止める。
  void backToInput();

  /// 入力を直し始めたとき、エラーの行を消す。
  void clearError();
}

final emailChangeProvider =
    NotifierProvider.autoDispose<EmailChangeNotifier, EmailChangeState>(
  EmailChangeNotifier.new,
);

/// 自動の確認の間隔（5 秒）と、再送の待ち（60 秒）。テストで短くするために差し替えられる。
class EmailChangeTiming {
  const EmailChangeTiming({
    this.pollInterval = const Duration(seconds: 5),
    this.resendCooldown = 60,
  });
  final Duration pollInterval;
  final int resendCooldown;
}
final emailChangeTimingProvider =
    Provider<EmailChangeTiming>((ref) => const EmailChangeTiming());

/// 画面に出す、いまのメールアドレス。完了のあと、行の伏せ字を更新するために使う。
class CurrentEmailNotifier extends Notifier<String?> {
  @override
  String? build();            // authRepository.currentEmail
  void refresh();             // もう一度 currentEmail を読む
}
final currentEmailProvider =
    NotifierProvider<CurrentEmailNotifier, String?>(CurrentEmailNotifier.new);

/// 「表示／かくす」。true のとき、メールアドレスの全体を出す。
class EmailRevealNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}
final emailRevealProvider =
    NotifierProvider<EmailRevealNotifier, bool>(EmailRevealNotifier.new);
```

**`lib/features/profile/email_change_sheet.dart`**（ui）

```dart
/// 4.3 のシートを開く。閉じたら完了する。
Future<void> showEmailChangeSheet(BuildContext context);
```

**`lib/features/profile/account_section.dart`**（ui）

```dart
/// 4.2 の「アカウント」の区画。登録方法が other・メールアドレスが無いときは SizedBox.shrink()。
class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});
}
```

## 8. 既存のテストの扱いと、足すテスト

- **ロジックは変わらない**（足すだけ）。ログイン・確認待ち・プロフィールの保存の既存のテストは、そのまま通るはず（通らないなら、まず実装のバグを疑う）。
- **直すテスト**（qa。期待を弱めない）:
  - `test/features/auth_test_helpers.dart` の `FakeAuthRepository`: 7章の新しいメソッドを足す（`currentEmail`・`providerIds`・呼ばれた引数の記録・次の呼び出しで投げる例外・`reloadCurrentEmail` の返り値の設定）。**パスワードは架空の値にし、出力しない**。
  - `test/features/profile_page_test.dart`: `ProfilePage` が `authRepositoryProvider` を使うようになるので、**偽物に差し替える**（差し替えないと、Firebase を初期化していないテストが落ちる）。既存の保存・テーマ・通知のテストは変えない。
  - ほかに `ProfilePage` を開くテスト（あれば）も同じ。
- **テストの書き方の約束**:
  - キーは、タップを受ける部品自身に付ける（行・ボタン・リンク）。押す前に `tester.ensureVisible`。
  - 書体は `test/flutter_test_config.dart` が取りに行かない設定にしてくれる。例外が出るなら書体を変えて回避しない（リーダーに報告）。
  - 画面の大きさは `tester.view.physicalSize` と `devicePixelRatio = 1`（終わりに `addTearDown(tester.view.reset)`）。文字の拡大は `tester.platformDispatcher.textScaleFactorTestValue = 1.3`（終わりに `clearTextScaleFactorTestValue`）。
  - 自動の確認・再送の待ちは、`emailChangeTimingProvider` を短い値に差し替え、`tester.pump(Duration)` で進める（本物の時間を待たない）。
  - 失敗するテストを `test/` に置いたままにしない。
  - 画面や偽物を書き換える前に、担当の `auth-data`・`ui` は `qa` に「テスト更新依頼: <タスクID>、変わる振る舞い、落ちるはずのテスト」を送る。

**足すテスト（qa）**

- `email_change_test.dart`（純粋関数）: `maskEmail`（例 4 つ・`@` なし・先頭が 1 文字・ちょうど 2 文字・長いアドレス）、`validateNewEmail`（正しい・空・`@` なし・ドメインに `.` なし・最後の部分が 1 文字・前後の空白・いまと同じ（大文字小文字違い）・いまが null）、`accountKindOf`（password のみ・google.com のみ・両方→email・空→other）、`emailChangeErrorMessage`（4.5 の表の全部。`requires-recent-login` は null・知らないコードは「うまくいきませんでした。」で、コードを含まない）
- `email_change_notifier_test.dart`（偽の `AuthRepository`＋時間を短くしたタイミング）: 送る（成功 → waiting・sentTo・再送 60 秒）／検査エラー（形式・同じアドレス）では repository を呼ばない／`email-already-in-use` のエラー文／`requires-recent-login` で needsPassword（文は出ない）→ パスワードを付けて再送信 → 再認証 → 送る／パスワードが違う（`invalid-credential`）→「パスワードが違います。」／自動の確認で、アドレスが変わったら done／変わらなければ waiting のまま／手動の確認で、まだなら「まだ確認できていません。…」／`user-token-expired` で sessionEnded の done／再送（待ちの間は呼ばれない・成功で 60 秒に戻る）／入力し直す（入力が残る・タイマーが止まる）／二重送信しない（busy の間）／Notifier を破棄するとタイマーが止まる／**パスワードを state に残さない**
- `account_section_test.dart`: メール登録の人に行・説明が出る・伏せ字が見える／Google の人に押せない行・説明が出る／other・メールなしは何も出ない／行を押すとシートが開く／「表示」で全体が出て「かくす」で戻る／幅 320〜1000×文字 1.0／1.3 倍ではみ出さない
- `email_change_sheet_test.dart`: 開く → ステップ1（見出し・ステッパー・説明・入力欄・ボタン）／空のあいだボタンが押せない／送る → ステップ2（アドレス・補足・ボタン・リンク2つ・再送のカウントダウン）／エラーが欄の下に出て、入力を直すと消える／パスワード欄が出る（`requires-recent-login`）／確認できると、ステップ3・「プロフィールに戻る」で閉じて SnackBar／`sessionEnded` の形・「ログイン画面へ」で `signOut`／閉じるボタン・暗幕・Esc で閉じる／途中で閉じても自動の確認が止まる／PC 幅で幅 640 以内／幅 320〜1000×文字 1.0／1.3 倍×キーボードありで、はみ出さない
- `profile_page_test.dart`（追加）: 編集のときだけ「アカウント」が出る（初回の作成では出ない）。保存・テーマ・通知の既存の動きが変わらない
- ロジックが変わっていないこと: 既存の認証・プロフィール・確認待ちのテストがそのまま通る

## 9. タスク一覧

リーダーが共有タスクリストに、担当と依存関係を付けて登録する。

| ID | 優先 | 担当 | 内容 | 依存 |
|---|---|---|---|---|
| L0 | | リーダー | 0章の確認、5章をユーザーに聞く、判断ログ | |
| T0 | | qa | 品質ゲートの確認。8章の「直すテスト」の一覧をリーダーに送る | |
| A1 | P1 | auth-data | `email_change.dart`（`maskEmail`・`validateNewEmail`・`accountKindOf`）と `emailChangeErrorMessage`。**先に契約（7章）を ui と qa に全文で送る**。`AuthRepository` に足すメソッドの形を qa に送る | L0 |
| A2 | P1 | auth-data | `AuthRepository` のメソッド追加、`email_change_providers.dart`（状態・タイマー・各プロバイダ）。**先に qa へテスト更新依頼** | A1 |
| U1 | P1 | ui | `account_section.dart`（メール登録の行）と `profile_page.dart` への追加。シートはまだ無いので、押したら `showEmailChangeSheet` の空の入れ物を開く（`SizedBox.shrink()` を返すだけ。U2 で本物にする）。**先に qa へテスト更新依頼** | A1 |
| U2 | P1 | ui | `email_change_sheet.dart`: シートの枠・ステッパー・ステップ1〜3・エラー・パスワード欄（4.3〜4.6）。`emailChangeProvider` につなぐ | A2, U1 |
| U3 | P2 | ui | Google の行・「表示／かくす」・SnackBar・有効期限切れの形（4.2・4.7） | U2 |
| Q1 | | qa | 純粋関数のテスト | A1 |
| Q2 | | qa | `FakeAuthRepository` の更新と、`EmailChangeNotifier` のテスト、`profile_page_test.dart` の直し | A2 |
| Q3 | | qa | 画面のテスト（`account_section_test.dart`・`email_change_sheet_test.dart`・`profile_page_test.dart` の追加） | U2, U3 |
| C1 | | ui | 掃除: 使われなくなったコード・import を消し、`flutter analyze` を0件にする | U3 |
| R1 | | qa | まとめレビュー（11章） | すべて |
| L1 | | リーダー | 結合確認、`git diff --stat` で差分が6章の範囲だけであることの確認、ユーザーへの動作確認手順（12章）、5.5 の結果の記録、判断ログ、コミット案 | すべて |

## 10. バグを防ぐための進め方

1. **担当外のファイルは編集しない。** 直してほしい箇所は担当者に SendMessage で伝える。
2. **契約を先に決める。** A1 が終わるまで、`ui` と `qa` は `email_change.dart` などに依存する部分を書かない（4章を読み込むのは先に進めてよい）。
3. **各タスクの最初に、方針を3〜5行でリーダーに送る。返事を待たずに書き始める。**（`dev-ui`・`dev-data`・`dev-qa` の定義には「返事を待つ」とあるが、**この計画書とチームメイト作成時の指示が優先**する。全員が返事を待って止まるのを避ける。）リーダーは、方針に問題があるときだけ返事をする。タスクを終えたら、完了報告を送ったあと、依存が解けている次のタスクへ**すぐに進む**。
4. **作業ツリーを壊れたまま放置しない。** `AuthRepository` にメソッドを足すときは、qa が偽物を直すのと同じタイミングにする（`flutter test` が止まらないように）。
5. **品質ゲート:** タスクを完了にするたびに、`.claude/hooks/quality-gate.sh` が動く。失敗すると完了が差し戻される。
6. **見た目は数値で合わせ、見本で確かめる。** 4章の数値と見本の CSS を見比べる。見本の HTML を別のタブで開いて並べて確かめるのは、人間（12章）。
7. **実装タスクを終えたら、`qa` にレビューを依頼する。** `qa` はレビュー依頼を最優先で処理する。
8. **共有・ロジックを変えない。** 6章の「読むだけ」のファイルを触らない。`AuthRepository`・`authErrorMessage`・`ProfilePage` は、足すだけで、既存の動きを変えない。
9. **秘密情報を残さない。** パスワード・メールアドレス・トークンを、ログ・例外・テストの出力・コミットに出さない。テストのメールアドレスは `example.com` などの架空の値にする。
10. **判断を記録する。** 比べた案・選んだ理由・捨てた案は、リーダーが `notes/判断ログ_A.md` に追記する（5章の回答と、5.5 の動作確認の結果を必ず含める）。

## 11. レビューの観点

- 見た目: 4章の数値どおりか（色・大きさ・余白・枠・角丸）。ステッパーの3つの形（これから・今・済み）。エラーのときの輪。主ボタンの無効の見た目
- 書体: `HakoFonts` を通しているか（`GoogleFonts.` の直書きが無いか）。行の高さが指定どおりか。太さは 700 まで
- 安全: **メールアドレス・パスワードが、ログ・例外のメッセージ・画面のエラー・`state` に残っていないか**。パスワード欄に `obscureText` があるか。エラーに Firebase のコードが出ていないか。`Firebase*.instance` を画面から直接呼んでいないか（`AuthRepository` 経由）
- 表示の条件: 「アカウント」が**編集のときだけ**出ているか（初回の作成で出ていないか）。登録方法ごとに行が正しいか。伏せ字の規則（4.2）が合っているか
- 流れ: 入力 → 確認 → 完了。「入力し直す」で入力が残るか。シートを閉じたあと、自動の確認が止まっているか（`mounted`・タイマーの破棄）。二重送信できないか。`await` の後の `context.mounted`
- 文言: 4.4〜4.6 と一字一句同じか（全角の `（` `）` `：`・「リンク」「確認メール」）。見本の「6桁のコード」「10分」「あと3回」が残っていないか。**見本の試し用の分岐（`123456`・`used@example.com`）が残っていないか**
- 既存の動作: 既存のキーが残っているか。ログイン・確認待ち・プロフィールの保存の動作が変わっていないか。`authErrorMessage` の既存の文言が変わっていないか
- 動き: `disableAnimations` のとき、シートが動かないか
- ロジック・共有: **`git diff --stat` で、変わったファイルが6章の編集してよいファイルと文書だけか**。`pubspec.yaml`・`firestore.rules`・`functions/**`・`lib/app.dart` の差分が無いか。パッケージ・画像の追加が無いか
- はみ出し: 幅 320・360・390・430・720・1000・文字 1.3 倍・キーボードあり
- テスト: 期待を弱めていないか。純粋関数・状態・画面にテストがあるか。偽物を直したあと、既存のテストがすべて通るか

## 12. 人が行う設定と動作確認

### 12.0 開始前の準備（L0。リーダーが行う。人間が行うものを含む）

1. `git status -sb`（ブランチが `feature/add_mail` か。`behind` が無いか）。
2. 作業ツリーに、この作業と関係のない未コミットのファイルがあれば、**触らない。コミットに混ぜない**（コミットする前に、リーダーが含めるファイルをユーザーに示す）。
3. **人間が用意するもの**:
   - **メールで登録したアカウント**（Google ではない）。この機能は、メール登録の人にだけ効く。
   - **受信できる別のメールアドレス**（変更先。ふつうの受信箱で確かめられるもの）。
   - Firebase コンソールの確認: Authentication → テンプレート →「メールアドレスの変更の確認」（`verify and change email`）と「メールアドレスの変更のお知らせ」の言語が日本語か。Authentication → 設定 → 承認済みドメインに、確認に使うドメイン（`localhost`・`oshiashi-test.web.app`）があるか。**設定を変えるのは人間**（エージェントは `firebase deploy` も設定の変更もしない）。

### 12.1 動作確認（人が行う。Dev Container で `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080`、Chrome で `http://localhost:8080`。メール登録のアカウントでログインして行う）

1. Chrome の開発者ツール → 端末のツールバーで幅 **390** にする。**別のタブで `markdown/design_add_mail/oshiashi_mail_C_bottom_sheet.html` を開き、並べて見比べる**（アカウントの行・シート・ステッパー・入力欄・ボタン・完了の画面）。見本は端末の書体なので、文字の形は少し違う。
2. 右上のアカウントのメニュー →「プロフィール」。いちばん下に「アカウント」とメールアドレスの行（伏せ字）が出る。初回の作成の画面（新しいアカウント）には出ない。
3. 行を押す。シートが下から開く。ステッパーの1段目が「今」になっている。
4. 空のまま → ボタンが押せない。形のおかしいアドレス・いまと同じアドレスを入れる → エラーが出る。
5. 受信できる別のアドレスを入れて「確認メールを送る」。パスワード欄が出たら（出ないこともある）、パスワードを入れてもう一度押す。ステップ2に進む。**5.5 の①: 既に使われているアドレスで試したとき、エラーが出るか／出ずに待ち続けるかを記録する。**
6. 届いたメールの文面（日本語か・リンクの先）を確認し、リンクを開く。アプリの画面が、5 秒以内に自動でステップ3に進む（または「リンクを開いたので確認する」で進む）。**5.5 の②: ログインが切れたか（切れたなら「ログインの有効期限が切れました」の形が出るか）を記録する。**
7. 「プロフィールに戻る」で閉じ、SnackBar が出て、行の伏せ字が新しいアドレスになっている。**5.5 の③: これまでのアドレスに、変更のお知らせが届いたか**を記録する（届かなければ、完了の文の該当の1文を消す）。
8. 新しいアドレスでログインし直せる。古いアドレスではログインできない。
9. ステップ2で「確認メールを再送する」: SnackBar が出て、60 秒数える。「メールアドレスを入力し直す」で入力に戻り、入力が残っている。
10. シートを途中で閉じる（×・暗幕・Esc）。閉じたあと、エラーや画面のちらつきが出ない。
11. Google のアカウントでログインして、プロフィールを開く。押せない行と説明が出る（P2）。
12. 幅 320・720 以上（PC）・文字 1.3 倍・キーボードが出た状態で、はみ出さない。
13. キーボードだけで、行 → 入力欄 → ボタン →「閉じる」を操作できる。

## 13. リーダー（メインセッション）の進め方

0. **モデル**: チームメイトは **Sonnet 5.5（`claude-sonnet-5-5`）**。`.claude/agents/*.md` に `model:` の行があるか、リーダーの既定を決める `.claude/settings.local.json` があるかを確かめる（無いことがある）。リーダーは、起動したときのモデルを確かめ、違えば `/model claude-sonnet-5-5` に切り替えるようユーザーに伝える。チームメイトを作るときは、モデルに Sonnet 5.5 を指定する。`.claude/agents/*.md` の書き換えは、ユーザーの了承を得てから行う。
1. この文書と `CLAUDE.md` を読む。リーダーは自分でコードを書かず、調整・タスク管理・ユーザーへの確認に専念する。
2. `git status -sb` で `feature/add_mail` にいて最新であることを確かめる（0章）。
3. `flutter analyze`・`flutter test`・ルールのテストを実行し、品質ゲートが通る状態かを確認する。通らなければ、原因をユーザーに報告して判断を仰ぐ。
4. 5章をまとめてユーザーに聞き、回答を判断ログに書き、5章の「回答」の列を埋める。**5.1 で案B（6桁のコード）が選ばれたら、チームメイトは作らず、付録のとおり計画書の作り直しをユーザーに相談する。確認が済むまでチームメイトは作らない。**
5. チームメイトを3人作る（**モデルは Sonnet 5.5**）。各チームメイトはリーダーの会話履歴を見られないので、作成時の指示に必要なことを書く。
   - `dev-data` エージェントタイプで、名前 `auth-data`。指示: 「markdown/feature_add_mail_plan.md を読み、担当 auth-data として A1 から始めて。4.2・4.4〜4.6 と7章を読み、A1 の方針（3〜5行）を私（リーダー）に送ること（返事を待たずに進めてよい。問題があれば私から連絡する）。契約（7章）は、A1 が終わったら ui と qa に全文を送ること。AuthRepository にメソッドを足す前に、qa に偽物へ足してほしいメソッドの形を送ること。6章の『読むだけ』のファイル・既存のメソッドの動き・pubspec.yaml・firestore.rules・functions は変えないこと。依存パッケージを足さないこと。パスワード・メールアドレスをログや例外に出さないこと」
   - `dev-ui` エージェントタイプで、名前 `ui`。指示: 「markdown/feature_add_mail_plan.md を読み、担当 ui として、4章（特に 4.2〜4.4・4.8・4.9）を読み込んでおき、auth-data から A1 の契約が届いたら U1 から始めて。見本は markdown/design_add_mail/oshiashi_mail_C_bottom_sheet.html の VARIANT='C' の分岐だけ。ただし 4.0 の表のとおり、見本から変える箇所がある（確認コードは作らない）。ボトムシートの作りは lib/features/help/help_sheet.dart を手本にする（help_sheet.dart は変えない）。方針は私（リーダー）に送るが、返事を待たずに進めてよい。6章の『読むだけ』のファイル・ProfilePage の既存の動き・pubspec.yaml は変えないこと。依存パッケージを足さないこと。文言は 4.4〜4.9 のとおり一字一句」
   - `dev-qa` エージェントタイプで、名前 `qa`。指示: 「markdown/feature_add_mail_plan.md を読み、担当 qa として T0 から始めて。以降はレビュー依頼とテスト更新依頼を最優先に。auth-data から偽物に足すメソッドの形が届いたら、FakeAuthRepository を同じタイミングで直す。8章の方針（期待を弱めない・書体を変えて回避しない・パスワードは架空の値で出力しない）を守ること。パッケージを足さないこと」
6. 9章のタスクを共有タスクリストに登録する（担当・依存関係つき）。
7. 進行中は、担当外ファイルの編集・同じファイルの同時編集・契約の食い違い・**共有ファイル（`AuthRepository`・`ProfilePage`）の既存の動きの変更**・**テストを消して通していないか**・**パッケージや画像の追加**・**パスワード・メールアドレスのログへの出力**・**見本の試し用の分岐（`123456` など）の混入**を見張る。ユーザーが決めるべきことは、まとめてユーザーに聞く。**誰も動いていない時間ができたら（全員が返事待ちになる、完了報告のあと止まる、など）、すぐに次の指示を出す。**
8. U2 が終わったら、**ユーザーに見てもらい、12.1 の 3〜10 を実際のメールで確かめてもらう**。その結果（5.5 の①〜④）を判断ログと 4.5・4.7 に反映する。そのあと U3 に進む。時間が足りなければ、P2 から落とす（1章）。
9. すべて完了したら L1 を行う。ユーザーに12章の動作確認手順と、コミット案（メッセージと含めるファイル）を示し、了承を得てからコミットする。含めるのは、6章の編集してよいファイル・`test/**` の変更・`markdown/feature_add_mail_plan.md`・`markdown/design_add_mail/**`・`notes/add_mail_*`・`notes/判断ログ_A.md`・`CLAUDE.md` の1行。`git push`・Pull Request・デプロイはユーザーが行う。
10. 最後にチームメイトを終了させ、チームを片付ける。

## 14. 使用量の上限で止まったときのために

- リーダーは `notes/add_mail_進捗.md` を、**タスクが1つ終わるたび**に更新する（状態・担当・触ったファイル・次にやること・ユーザーに聞きたいこと）。止まって再開するときは、まずこのファイルを読み、終わったタスクはやり直さない。
- Claude Code が終了してチームメイトがいなくなったら、まだ終わっていないタスクの担当だけを作り直す（13章の指示に「notes/add_mail_進捗.md を読み、自分の未完了のタスクから再開すること」を足す）。
- 使用量を抑えるルール（全員）: メッセージは短く、ファイルの中身やテストの出力を丸ごと貼らない。作業中のテストは関係するファイルだけを実行し、全体は完了時の品質ゲートに任せる。長い出力は末尾だけを見る。計画書は自分に関係する章だけを読み直す。進み具合の確認のためだけのメッセージを送り合わない。
- 許可の確認で止まらないように、シェルのコマンドは1つずつ実行する（`;`・`&&`・`|` でつながない、`$変数` を使わない）。ファイルの読み書き・検索は Read・Edit・Grep などの道具を使う。

## 付録: 5.1 で案B（6桁のコード）を選んだ場合の違い

見本のとおりの流れ（6桁のコード・有効期限10分・入力3回まで・再送30秒）にできるが、次が増える。**この計画書の範囲を超えるので、選ばれたら、リーダーが計画書を作り直す**（チームメイトは4人目の `fn`＝Cloud Functions 担当が増える）。

- **Cloud Functions（Callable）を2つ**: 変更の依頼（新しいアドレスの検査・コードの作成・メールの送信）と、確認（コードの照合・`getAuth().updateUser(uid, {email, emailVerified: true})`）。`functions/index.js` に足す。デプロイは人間（Blaze は切り替え済み）。
- **コードの保存**: Firestore に、コードの**ハッシュ**・有効期限・失敗の回数・最後に送った時刻を持つ（例: `emailChangeRequests/{uid}`）。クライアントからは読み書きできないルール（`firestore.rules` の変更・ルールのテスト・デプロイは人間）。
- **メールの送信**: Firebase Authentication は6桁のコードのメールを送れない。外部のメール送信サービス（またはメール送信の拡張機能）と、API キー（`defineSecret` の Secret。**コミットしない**）が要る。送信元のドメインの設定・迷惑メールに入らないかの確認も要る。
- **決める値**: 有効期限・失敗の上限・再送の間隔・1時間あたりの依頼の上限（見本の「決めておきたいこと」の3つめ）。
- **本人確認**: 関数の中で、依頼のときに再認証（最近のログイン）を確認するかを決める（5.2）。
- **お知らせの送信**: 変更が済んだら、これまでのアドレスに自前で送る（5.3 の案Bの内容を、送れる形にする）。
- 画面は、見本のとおり（4.0 の表の「6桁のコード」「10分」「あと3回」「30 秒」の行を戻す）。
- 提出（11/10 19:00）までに、メールの送信の準備（外部サービスの契約・Secret・ドメイン）が間に合うかを、先にユーザーに確かめる。
