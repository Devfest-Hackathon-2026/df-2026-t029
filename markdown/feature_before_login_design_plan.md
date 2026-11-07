# 計画書: ログイン前の画面のデザイン変更（案6「ハコ色」）

> 担当A（とし）の作業を、Claude Code の agent team（リーダー＋チームメイト3人。**モデルは Sonnet 5.5**）で実装するための指示書（仕様書を兼ねる）。人間とエージェントの両方が読む。
> 4章はユーザーが選んだデザイン（案6）を Dart（Flutter）で再現するための仕様。「5. 実装前に確かめること」だけが、リーダーがユーザーに聞く項目（どれも推奨案つき）。

## 0. 作業ブランチと前提

- **作業ブランチは `design/before_login`。** ブランチの作成・切り替え・pull・push は人間が行う。エージェントはブランチを切り替えない。
- 完成したら、人間が `design/before_login` から `dev` へ Pull Request を出す。
- 開始前に、リーダーは `git status -sb` で `design/before_login` にいて、GitHub より遅れていない（`behind` が無い）ことを確かめる。遅れていたらユーザーに `git pull --no-rebase` を頼む。
- **前提（実装済み）**: メールアドレスでの登録・ログイン、確認メール、パスワードの再設定、確認待ち画面（`markdown/feature_front1_auth_plan.md`）。今回は**見た目の差し替え**で、**動き（ロジック）は変えない**。
- **Dart（Flutter）で書く。** JavaScript・HTML で画面を作らない（`web/index.html` も触らない）。参照用の HTML は見た目の見本であって、アプリには入れない。
- Firebase は Spark（無料）プランのまま。
- 締切: チームの計画では **11/8 の夜に機能を凍結**する。**見た目の差し替えが間に合わなければ、このブランチを `dev` に入れず、今のデザインのまま提出する**（途中の状態を `dev` に入れない）。

## 1. 範囲

**作るもの**

1. 紹介ページ（`/welcome`）を案6にする。
2. ログイン画面（`/login`）を案6にする（ログイン／新規登録の切り替え、Google、メール、「パスワードを忘れた方」のダイアログを含む）。
3. メールの確認待ち画面（`/verify-email`）を、同じ部品で作り直す（見本の HTML には無いので、4.4 で決める）。
4. 共通の色・書体・部品（`lib/theme/` に置く）。
5. 既存テストの書き直しと、新しい部品のテスト。

**作らないもの**

- ロジックの変更（認証・ルーター・振り分け・入力の検査・エラーの文言）
- 画面の移動先の変更（今のとおり。「始める」→ `/login?mode=signup`、右上の「ログイン」→ `/login`、戻る → `/welcome`）
- ログイン後の画面と、アプリ全体のテーマ（`lib/theme/app_theme.dart`。横山さんのファイル）
- 写真・イラスト・動画（案6は色と文字だけで作る）
- PC 専用のレイアウト（紙・色の帯・ハコの色は画面の全幅。中身だけ幅 430 以下の 1 列を中央に置く（`HakoContent`）。**ユーザーの指示で、HTML の `max-width: 430px` から変更**）
- 「くわしく」の説明ページ

## 2. 決まっていること（ユーザーの指示）

| 項目 | 決定 |
|---|---|
| デザイン | ユーザーが選んだ案6「ハコ色」と同じ見た目にする（`markdown/design_before_login/hako_案6_ハコ色.html`） |
| 言語 | Dart（Flutter）。JavaScript ではない |
| 画面の移動 | 「始める」「ログイン」を押すと、ログイン画面（次のページ）へ移る（今までと同じ） |
| チームのモデル | Sonnet 5.5（`claude-sonnet-5-5`） |

## 3. 現状のコード（調べたこと）

| 項目 | 今の状態 | 場所 |
|---|---|---|
| 紹介ページ | 夜の色の3段構成（写真の最初の画面・6つの機能・締め）。`BrandColors` を `_Palette` の別名で使う。「始める」→ `context.go('/login?mode=signup')`、右上の「ログイン」→ `context.go('/login')`。**移動の動きは今のままでよい**。キー: `welcome_page`・`welcome_login_button`・`welcome_start_button`・`welcome_scroll_hint` | `lib/features/welcome/welcome_page.dart`（652行） |
| ログイン画面 | `SegmentedButton<LoginMode>`（ラベルの `Text` にキー `login_mode_signin`・`login_mode_signup`）、Google の `OutlinedButton`（`login_google_button`）、`TextFormField`（`login_email_field`・`login_password_field`・`login_password_confirm_field`・目のアイコン `login_password_toggle`）、送信 `GradientButton`（`login_submit_button`）、`TextButton`（`login_forgot_password_button`）、エラーの帯（`login_error`）、再設定のダイアログ `_ResetPasswordDialog`（`reset_email_field`・`reset_send_button`・`reset_close_button`・`reset_sent_message`・`reset_error`） | `lib/features/auth/login_page.dart`（416行） |
| 確認待ち画面 | `AuthShell` の中に、見出し・説明・帯・`GradientButton`（`verify_check_button`）・`TextButton`（`verify_resend_button`・`verify_sign_out_button`）。キー `verify_email_page`・`verify_description`・`verify_message` | `lib/features/auth/verify_email_page.dart`（207行） |
| 共通部品 | `AuthShell`（夜→紫の背景・ピンクの光・白い大きなアプリ名・紙色のカード。戻るボタン `login_back_button`）、`GradientButton`、`AuthMessageBanner`、`AuthRecaptchaNotice`（`login_recaptcha_notice`。リンクは `urlLauncherProvider` で開く） | `lib/features/auth/auth_widgets.dart`（283行） |
| 色 | `BrandColors`（night・violet・pink・purple など、夜のライブ会場の色）。**使っているのは紹介ページとログイン系の3ファイルだけ** | `lib/theme/brand_colors.dart` |
| アプリのテーマ | `buildAppTheme` が、アプリ全体の既定の書体を **Outfit** にし、ユーザーが選んだ色で配色を作る（横山さん）。**ログイン前の画面は、テーマの書体と色に頼らず、書体と色をすべて自分で指定する** | `lib/theme/app_theme.dart` |
| ルート | `/welcome`・`/login`（`?mode=signup` で新規登録）・`/verify-email` は、タブの無い外枠の外にある。**ルートは変えない** | `lib/app.dart` |
| 書体のパッケージ | `google_fonts: ^9.0.0` が入っている。`flutter_svg` は入っていない | `pubspec.yaml` |
| テスト | `test/features/welcome_page_test.dart`（83行）・`login_page_test.dart`（646行）・`verify_email_page_test.dart`（320行）・`auth_test_helpers.dart`（偽の `AuthRepository`）。紹介ページのテストは `GoogleFonts.config.allowRuntimeFetching = false` でフォントを取りに行かない。ログイン画面のテストは `SegmentedButton<LoginMode>`・`OutlinedButton`・`TextButton`・`TextFormField` の型を直接見ている箇所がある | `test/features/` |

## 4. 仕様（デザイン）

### 4.0 見本の読み方

- 見本は2つ。**HTML（`markdown/design_before_login/hako_案6_ハコ色.html`）の CSS が正**。もう1つは、幅 390px で描画した画像（`hako_案6_390px_ref.png`。画像を Read で見られる）。画像の上から: 紹介ページ（色の帯・ヘッダー・最初の画面・6つのハコ・「始める」）、続けてログイン画面。
- この章の数値は、HTML の CSS を写し、実際に幅 390 / 360 / 430px で描画して測ったもの。食い違いに気づいたら、HTML を正とし、リーダーに報告する。ただし「**追加・変更**」と書いた箇所は、この計画書が正。
- HTML を Chrome で開くと実物を見られる（Google Fonts を読むので、ネットが要る）。

### 4.1 共通

#### 色（`lib/theme/brand_colors.dart` に置く）

```dart
abstract final class BrandColors {
  // 紙と墨
  static const paper = Color(0xFFFBF6EA);    // 紙の色（ページの地）
  static const ink = Color(0xFF121212);      // 墨（文字・枠・黒い区画）
  static const backdrop = Color(0xFFD9D3C4); // 画面の背景（紙が全面に出るので、ほぼ見えない）
  // 6つのハコの色（上から順。色の帯も同じ順）
  static const hall1 = Color(0xFFE8452C); // 赤
  static const hall2 = Color(0xFFFF9F1C); // 橙
  static const hall3 = Color(0xFFF2D21B); // 黄
  static const hall4 = Color(0xFF2DBE7E); // 緑
  static const hall5 = Color(0xFF4A9BEF); // 青
  static const hall6 = Color(0xFFF07BAE); // 桃
  static const halls = [hall1, hall2, hall3, hall4, hall5, hall6];
  // 黒い区画の中
  static const onInkSub = Color(0xFFDDDDDD); // 補足の文字
  static const boardRule = Color(0xFF555555); // 掲示板の見出しの下線
  static const boardRow = Color(0xFF333333);  // 掲示板の行の区切り
  // エラーの文字（紙の上で 6:1）
  static const errorText = Color(0xFFB3261E);
  // Google ボタン（Google のブランドのガイドライン）
  static const googleBorder = Color(0xFF747775);
  static const googleText = Color(0xFF1F1F1F);
}
```

- 文字と背景のコントラスト（計算済み）: 墨 × 紙 17.4 / 墨 × 赤 4.7 / 墨 × 橙 9.1 / 墨 × 黄 12.5 / 墨 × 緑 7.8 / 墨 × 青 6.5 / 墨 × 桃 7.3 / 黄 × 墨 12.5 / 白 × 墨 18.7 / `onInkSub` × 墨 13.8。**ハコの上の文字は墨だけにする**（白や別の色を使わない）。
- 色だけで意味を伝えない（申込・当落・入金は、ラベルの文字でも分かる）。
- **旧い色の名前**（`night`・`violet`・`text`・`subText`・`inkSub`・`line`・`pink`・`purple`）は、新しい画面がすべて移るまで残す（途中でコンパイルが通らなくなるのを防ぐ）。`paper`・`ink` は新しい値に変えてよい（旧画面の色が少し変わるだけ）。旧い名前は C1 で消す。

#### 書体（`lib/theme/hako_fonts.dart`（新規）に集める）

| 用途 | 書体 | 入手 |
|---|---|---|
| 日本語・本文・見出し・ボタン | **BIZ UDPGothic**（400 と 700 だけ。太さは 400 か 700 の2つしか無い） | `google_fonts`（`GoogleFonts.bizUDPGothic`。名前は IDE の補完で確かめる） |
| 英字ラベル・数字（「HALL 01」「11.20」「01」など） | **ArchivoHako**（案6の横に広い Archivo。3つの静的フォント: 太さ 700（幅 110%）・800（幅 125%）・900（幅 125%）） | **同梱**（`markdown/design_before_login/fonts/`。理由は同じフォルダの README） |
| Google ボタンの文字 | Roboto 500（Google のガイドライン） | `google_fonts`（`GoogleFonts.roboto`） |

- 理由: `google_fonts` では Archivo の「幅」の軸が使えず、案6の横に広い形が出せない。同梱のフォントは、可変フォントから幅と太さを固定して取り出したもので、HTML の描画との差が出ないことを確かめてある。
- 書体の指定は、**すべて `HakoFonts` を通す**（画面に `GoogleFonts.` や `fontFamily:` を直接書かない）。テストで差し替えやすく、書体を変えるときも1か所で済む。
- 英字の書体（ArchivoHako）で出せない文字（日本語・「→」など）は、日本語の書体（BIZ UDPGothic）に落とす（`fontFamilyFallback`）。
- `Text` には必ず `style` を渡す（テーマの Outfit が混ざらないように）。`TextFormField` の入力文字・ラベル・エラー・補足の `style` も指定する。ダイアログ・SnackBar も同じ。
- **行の高さ**: CSS の `line-height` は、`TextStyle.height` に同じ倍率を入れ、`leadingDistribution: TextLeadingDistribution.even`（行の上下に均等に空ける。CSS と同じ）にする。本文の既定は 1.75。
- 字間: CSS の `letter-spacing: .14em` は `size × 0.14`（px）で入れる。
- **読み込みの重さ（要確認。5.3）**: BIZ UDPGothic は日本語のフォントで重い。woff2 に圧縮した形で、1つの太さが約 4MB（400 と 700 で計 8MB。Flutter が取る TTF はもっと大きい）。最初の表示では、読み込みが終わるまで標準の書体で出て、終わったら置き換わる。
  - 大きさは、`google_fonts` の中のファイル一覧で分かるはず: `grep -rn "BIZUDPGothic" ~/.pub-cache/hosted/pub.dev/google_fonts-*/lib/src/google_fonts_parts/`（太さごとのファイルの大きさ（バイト）が書いてある）。

#### 文字の作り方の早見表（HTML → Dart）

| HTML の指定 | `HakoFonts` の呼び方 |
|---|---|
| 本文 `400 16px/1.75`（BIZ UDPGothic） | `HakoFonts.jp(size: 16)` |
| 太字 `700` | `HakoFonts.jp(size: …, weight: FontWeight.w700, height: …)` |
| `.en`（Archivo 幅 125% 太さ 800・字間 .02em） | `HakoFonts.en(size: …, weight: FontWeight.w800, letterSpacing: size * 0.02)` |
| 英字ラベル（字間 .14em） | `HakoFonts.en(size: 12, weight: FontWeight.w800, letterSpacing: 12 * 0.14)` |
| 大きな数字（Archivo 幅 125% 太さ 900・行の高さ 1） | `HakoFonts.en(size: 84, weight: FontWeight.w900, height: 1)` |
| 日付（Archivo 幅 110% 太さ 700） | `HakoFonts.en(size: 15, weight: FontWeight.w700, height: 1.4)` |

#### ページの枠（`HakoPage`。`lib/theme/hako_widgets.dart`（新規））

- **紙（`paper`）と色の帯は常に画面の全幅**（キー `hako_column`。`backdrop` の余白は出さない）。広い画面で読みやすいよう、中身だけ `HakoContent`（幅 430 以下・中央）で包む。ハコ・「始める」の区画の背景色は全幅で、中の文字だけ 430 以下。**ユーザーの指示で、HTML の `max-width: 430px` から変更**。
- 列の中は、上から**色の帯**（高さ 10・6色を等分・`hall1`〜`hall6` の順）、中身、色の帯。
- 縦にスクロールする。**中身が短い画面（ログイン・確認）では、紙が画面の高さまで伸び、下の色の帯が画面の下に来る**（`CustomScrollView` ＋ `SliverFillRemaining(hasScrollBody: false)` など）。
- `SafeArea` の内側に置く。スクロールバーは画面の端（列の端ではなく）に出てよい。
- 装飾だけの部品（色の帯・大きな数字・英字ラベル）は `ExcludeSemantics` で読み上げから外す。

#### 部品

| 部品 | 作り | キー・備考 |
|---|---|---|
| 丸い枠のボタン（`HakoPill`） | 最小の高さ 44・左右 18・枠 2px `ink`・角丸 999・文字は日本語 14 太字 `ink`・背景は透明 | 「ログイン」「戻る」「くわしく →」（サイズだけ違う: 13 太字・上下 3・左右 14）に使う |
| 墨の大きなボタン（`HakoPrimaryButton`） | 幅いっぱい・最小の高さ 54・背景 `ink`・文字は日本語 18 太字 `hall3`（黄）・角丸 4・上の余白 22 | 送信中は文字の代わりに黄色の `CircularProgressIndicator`（22px）。押せないとき（送信中ではない）は不透明度 0.5。**キーは `HakoPrimaryButton` 自身が `super.key` で受ける**。くるくる（`CircularProgressIndicator`）とラベルの `Text` は、この部品の**子孫**に置く（今のテストは、キー付きの部品の子孫から `find.descendant` で探している）。送信中は `onPressed` を null にして、二重に送られないこと |
| 切り替えの札（`HakoTab`） | 2つ横に並べる（間 8）・最小の高さ 48・枠 2px `ink`・角丸 4・文字は日本語 16 太字。選ばれていない: 背景 白・文字 `ink`。選ばれている: 背景 `ink`・文字 白 | `selected`・`onPressed`（null で押せない）を公開フィールドにする（テストが値を読む）。`Semantics(selected:, button: true)` |
| 入力欄 | ラベル（日本語 14 太字・欄の上 4px 離す・前の欄から 14 離す）＋ `TextFormField`。欄は背景 白・枠 2px `ink`・角丸 4・最小の高さ 48・左右 12・入力文字は日本語 16 | `TextFormField` 自体に今のキーを付ける。フォーカス中は、枠を青（`hall5`）の太さ 4px にする（HTML は `ink` の枠の外側に青い輪。近い見た目でよい。**フォーカスが見えることは必ず保つ**）。カーソルは `ink`。エラー・補足の文字は日本語 12〜13（エラーは `errorText`、補足は `ink`） |
| 帯（`AuthMessageBanner`） | 背景 白・枠 2px `ink`・角丸 4・左端に太さ 8 の色のブロック（エラー: `hall1`、成功: `hall4`）・文字は日本語 14 `ink`（行の高さ 1.6）・内側の余白 12 | **追加・変更**（HTML に無い）。アイコンは付けない。キーは今のまま |
| Google の「G」 | 4.5 の `GoogleLogo` | |

### 4.2 紹介ページ（`/welcome`）

**並び**: 色の帯 → ヘッダー → 最初の画面（hero）→ 6つのハコ → 「始める」の区画（CTA）→ 色の帯。全体が `HakoPage`。

#### ヘッダー（HTML の `.top`）

- 高さ 76（上下 16・左右 20）。左: 「おしあし」（日本語 22 太字 `ink`）。右: 「ログイン」の丸い枠のボタン（キー `welcome_login_button`）→ `context.go('/login')`。両端そろえ・縦は中央。

#### 最初の画面（`.hero`。幅 390 で高さ 430.9）

| 要素 | 値 |
|---|---|
| 余白 | 上 28・左右 20・下 36 |
| 見出し（`h1`） | 2行。「推し活の予定を、」と「もう逃さない。」。日本語 40 太字・行の高さ 1.25（1行 50）・字間 −0.8（−0.02em）・`ink`。**2行目に黄色の蛍光ペン**（下の説明） |
| 蛍光ペン | 「もう逃さない。」の文字の幅（左右に 2px ずつ足す）で、色 `hall3`。**高さは文字の大きさの 0.34 倍（13.6）。位置は2行目の行の下端から 5px 上**（行の下端 = 行の枠の底）。文字の後ろに敷く（`Stack` で）。HTML の `box-shadow: inset 0 -.34em 0` の再現 |
| リード文 | 見出しの下 16。日本語 15・行の高さ 1.75・最大の幅 330。「申込、当落、入金。ばらばらの締切を、ひとつの掲示板にまとめます。」 |
| 掲示板（`.board`） | リード文の下 28。背景 `ink`・文字 白・内側の余白（上 14・左右 16・下 6）。角は丸めない |
| 掲示板の見出し | 「TODAY'S 締切」。英字の書体 12・太さ 800・字間 1.68（.14em）・色 `hall3`・下に余白 8 と下線 1px `boardRule`。「締切」は日本語の書体に落ちる |
| 掲示板の行（3行） | 上下 10・下線 1px `boardRow`（最後の行は無し）・文字 14（行の高さ 1.4）・縦は中央。左から: 日付（幅 62・英字の書体 15・太さ 700）／ラベル（幅 54）／本文（残り）。列の間 10 |
| ラベル | 幅 54・中央そろえ・文字は日本語 12 太字 `ink`・上下 2・角丸 2。色: 申込 `hall1`、当落 `hall3`、入金 `hall4` |
| 行の中身 | 11.20 ／ 入金 ／「ひかりの夜」東京公演　・　11.24 ／ 申込 ／「ミナト・ツアー」大阪　・　11.30 ／ 当落 ／「ひかりの夜」追加公演（**架空の名前**。実在の名前に変えない） |

- 掲示板は読み上げでは「締切の表示例」と言う（`Semantics(label: …)`）。キー `welcome_board`。
- 見出し（`h1`）は `Semantics(header: true)`。

#### 6つのハコ（`.hall`）

- 画面の幅いっぱい・縦に積む（隙間なし）・左右 20・文字は `ink`・位置の基準（`Stack`）。
- 中身（上から）: **英字ラベルの行**（左「HALL 0n」・右の英単語。英字の書体 12・太さ 800・字間 1.68・両端そろえ）→ 見出し（日本語 太字・行の高さ 1.25・上 10・下 6）→ 説明（日本語 15・行の高さ 1.75・最大の幅 300）→（あれば）「くわしく →」（上 14）。
- **大きな数字**: 右 16・下 6 に置く（`Positioned`）。英字の書体 84・太さ 900・行の高さ 1・色は `ink` の不透明度 0.18。押せない・読み上げない（`IgnorePointer`・`ExcludeSemantics`）。文字と重なってよい（HTML のとおり）。
- ハコごとの値（キー `welcome_hall_1`〜`welcome_hall_6`）:

| 番号 | 背景 | 余白 上／下 | 見出し（大きさ） | 説明 | くわしく | 英字（左／右） | 幅 390 での高さ |
|---|---|---|---|---|---|---|---|
| 01 | `hall1` | 40／44 | 推しをフォロー（30） | 推しを探してフォロー。見つからなければ追加を申請できます。 | あり | HALL 01／FOLLOW | 250.8 |
| 02 | `hall2` | 26／28 | スクショから読み取り（30） | 告知画像やチケットサイトのスクショから、日程・申込期限・入金期限を AI が読み取ります。 | なし | HALL 02／SCAN | 200.3 |
| 03 | `hall3` | 26／40 | 次の締切が、ひと目で（34） | 申込 → 当落 → 入金。次にやることの期限が分かります。 | あり | HALL 03／DUE | 237.8（幅 360 では見出しが2行になり 280.3） |
| 04 | `hall4` | 26／28 | みんなで共有（30） | 同じ推しのファンが登録したライブを、自分の一覧に追加できます。 | なし | HALL 04／SHARE | 174 |
| 05 | `hall5` | 20／20 | Google カレンダーに追加（26） | （説明なし） | なし | HALL 05／CALENDAR | 102.5 |
| 06 | `hall6` | 26／40 | グッズ交換（30） | 「譲」「求」を登録すると、交換できる相手が見つかります。 | なし | HALL 06／TRADE | 186 |

- **【5.1 の回答: 案C】「くわしく →」は作らない（消す）。`welcome_more_*` のキーも無い。表の「くわしく」列の「あり」は無視し、ハコ 01・03 の高さは約 14＋ボタンの高さ（約 30）だけ表より低くなる（±8 の合格基準は、この分を引いて見る）。** 以下は参考（作らない）: 丸い枠のボタン（13 太字・上下 3・左右 14）。キー `welcome_more_1`・`welcome_more_3`。行き先は 5.1。
- 見出しは長い文字でも**折り返して、はみ出さない**（幅 320 でも）。
- **【追加（ユーザーの指示）】広い画面では、6つのハコを列にまとめる**: 画面の幅 600 以上は3列（2行）、600 未満は1列（上の表のとおり）。隙間なしで敷き詰め、各ハコの色・中身・余白・大きな数字は同じ。同じ行のハコは高さをそろえ、背景は全面に伸びる（`IntrinsicHeight`。各ハコの幅は `SizedBox` で固定）。文字は各ハコの幅で折り返す（狭いハコでは英字ラベルの右側が次の行に回る）。説明文の幅 300 の制限は1列のときだけ（複数列では `IntrinsicHeight` が折り返しを読み違えてあふれるため）。ハコの並びだけ `HakoContent` で包まず全幅を使う（実装: `_HallGrid`）。
- **【追加（ユーザーの指示）】広い画面ではハコの上の部分も横幅を使う**: ヘッダー・最初の画面・「始める」の区画は、430 に絞らず全幅の背景。左右の余白は幅に応じて 20（〜599）・40（〜899）・64（900〜）。中身は幅 1100 まで・中央（ヘッダーは両端そろえで、最大幅なし）。幅 900 以上では見出しを 56、リード文を 17（最大幅 560）にする。実装は `_Wide`。ログイン・確認画面（`AuthShell`）は今のまま `HakoContent`（430）。
- **【変更（ユーザーの指示）】ヘッダー**: 「おしあし」は左端・「ログイン」は右端（左右の余白の中で両端そろえ）。「おしあし」は 32、ボタンの文字は 18（高さは 44 以上）。狭い画面・大きな文字では「おしあし」を縮めてはみ出しを防ぐ（`FittedBox`）。

#### 「始める」の区画（`.cta`。高さ 190.5）

| 要素 | 値 |
|---|---|
| 背景・余白 | `ink`・上 40・左右 20・下 36 |
| 一行 | 「6つのハコ、まとめて入場。」日本語 14・色 `onInkSub`・キー `welcome_cta_note` |
| ボタン（`.btn`） | 一行の下 14。幅いっぱい・最小の高さ 76・背景 `hall3`・左右 24・角丸 4・**硬い影**（右下に 6px ずらした `hall1`。ぼかし 0）。左に「始める」（日本語 34 太字 `ink`）、右に矢印「→」（34・`ink`。左右の端に離す）。キー `welcome_start_button`。押すと `context.go('/login?mode=signup')` |
| 矢印 | 英字の書体には「→」が無いので、日本語の書体（太字）の「→」でよい。読み上げから外す |
| 動き（nudge） | 2.4秒で1周、ボタン全体（影ごと）が、真ん中で左上に 2px 動いてもどる（`ease-in-out`）。ずっと繰り返す。**端末の「動きを減らす」（`MediaQuery.disableAnimationsOf`）がオンなら止める** |
| 押したとき | 波紋（`ink` の不透明度 0.1）。キーボードのフォーカスが見えること（枠は青 `hall5` 4px） |

#### 紹介ページで**やらない**こと

- 最初の画面の写真・「SCROLL」の案内・FEATURES の見出しと番号の並び・「始める」の下の説明と reCAPTCHA の文言（reCAPTCHA はログイン画面にある）は、**すべて無くす**（今の `_Hero`・`_Features`・`_Closing`・`_heroImage` も消す）。

### 4.3 ログイン画面（`/login`）

**並び**: 色の帯 → ヘッダー → 見出し → 札 → Google → 区切り → 入力欄 → … → 色の帯。`HakoPage` を使う（`AuthShell` は、この土台と見出しを包む部品に作り直す。7章）。

#### ヘッダー（**追加・変更**。HTML は紹介ページの部分だけ）

- 紹介ページのヘッダーと同じ高さ（76）。**左**: 「← 戻る」の丸い枠のボタン（キー `login_back_button`・`context.go('/welcome')`。今のテストと同じ動き）。**右**: 「おしあし」（日本語 22 太字）。

#### 本体（HTML の `.login-s`）

| 要素 | 値 |
|---|---|
| 余白 | 左右 20・上（ヘッダーの下）12・下 44 |
| 見出し | 日本語 30 太字・行の高さ 1.3。**ログイン**: 「おかえりなさい。」「入口はこちら。」の2行。**新規登録（追加・変更）**: 「はじめまして。」「入口はこちら。」 |
| 札 | 見出しの下 18・その下 20。「ログイン」「新規登録」の `HakoTab` 2つ（キー `login_mode_signin`・`login_mode_signup` を**札自身**に付ける） |
| Google | 幅いっぱい・最小の高さ 48・背景 白・枠 1px `googleBorder`・角丸 4・左右そろえて中央（G のロゴ 20 → 間 10 → 文字）。文字は「Google で続ける」の **1つの `Text`**（Roboto 500・14・`googleText`。日本語は日本語の書体に落とす）。キー `login_google_button`（**`OutlinedButton`のまま**）。処理中は文字とロゴの代わりに `CircularProgressIndicator`（20px・`googleText`） |
| 区切り | Google の下 18・その下 6。左右に線（太さ 2・`ink`）・間に「またはメールで」（日本語 13）・間隔 10 |
| メール | ラベル「メールアドレス」→ 入力欄（キー `login_email_field`） |
| パスワード | ラベル「パスワード」→ 入力欄（キー `login_password_field`。目のアイコン `login_password_toggle` は欄の右端。色 `ink`）。新規登録のときの補足「8文字以上」は欄の下（`find.text('8文字以上')` で見つかること） |
| 確認用（新規登録だけ） | ラベル「パスワード（確認）」→ 入力欄（キー `login_password_confirm_field`） |
| エラーの帯 | 今と同じ位置・同じキー `login_error`。見た目は 4.1 の帯 |
| 送信 | 上 22。`HakoPrimaryButton`。ログイン: 「ログイン」、新規登録: 「登録して確認メールを送る」。キー `login_submit_button` |
| パスワードを忘れた方 | **ログインのときだけ**。送信の下 16。**左そろえ**・日本語 14・`ink`・**下線あり**。キー `login_forgot_password_button`（**`TextButton`のまま**）。押せる範囲は高さ 44 以上 |
| 説明 | 新規登録のときだけ「登録すると確認メールが届きます。メールのリンクを開くと使えるようになります。」、両方で「Google カレンダーへの追加は、使うときに Google アカウントの許可を求めます。」。日本語 12・行の高さ 1.7・`ink`。**HTML に無いが残す**（機能の説明で、テストにもある）。上 22 |
| reCAPTCHA の文言 | 説明の下 8。今と同じ文言とリンク（キー `login_recaptcha_notice`）。日本語 12・`ink`。リンクは下線つき・`ink`。左そろえ。**`AuthRecaptchaNotice` を明るい背景用に直す。ただし構造は変えない**: キーは `Text.rich` 自身に付け、ルートの `TextSpan` の `children` に、文言 `プライバシーポリシー`・`利用規約` の `TextSpan`（それぞれ `recognizer` が `TapGestureRecognizer`）が直接並ぶこと。リンク先は `urlLauncherProvider` 経由で今のまま（今のテストが `textSpan` の `children` を直接たどって `onTap` を呼ぶ）。変えてよいのは色・大きさ・そろえだけ |

- HTML の「※ 新規登録のときは『パスワード（確認）』の欄が増えます。」は、**見本の中の注釈**で、画面には出さない。
- 入力・送信・エラー・二重送信の防止・`context.mounted` の扱いなど**動きは今のコードのまま**（見た目の部品だけを置き換える）。

#### パスワードの再設定のダイアログ（`_ResetPasswordDialog`。**追加・変更**）

- `AlertDialog` の背景 `paper`・形は角丸 4 ＋枠 2px `ink`・影なし。見出し「パスワードの再設定」は日本語 22 太字。
- 入力欄は 4.1 の入力欄（キー `reset_email_field`）。「閉じる」は `TextButton`（下線あり・`ink`。キー `reset_close_button`）、「再設定のメールを送る」は墨のボタン（背景 `ink`・文字 `hall3`。キー `reset_send_button`。送信中は黄色のくるくる）。成功・エラーは 4.1 の帯（キー `reset_sent_message`・`reset_error`）。文言は今のまま。

### 4.4 メールの確認待ち画面（`/verify-email`。HTML に無いので**同じ部品で組む**）

- `HakoPage`。ヘッダーは「おしあし」だけ（戻るボタンは無い。今と同じ）。
- 見出し: 「確認メールを送りました」（日本語 30 太字・行の高さ 1.3。幅 360 でも折り返してよい）。キー `verify_email_page` は画面の一番外側。
- 本文（日本語 15・行の高さ 1.75・`ink`）: 今の説明（キー `verify_description`）と「届かないときは、迷惑メールのフォルダも見てください。」。**文字列は今のまま**。
- 帯（キー `verify_message`）は 4.1 の帯。
- 「確認しました」: `HakoPrimaryButton`（キー `verify_check_button`。確認中は黄色のくるくる）。
- 「確認メールを送り直す」「別のアカウントでログインする」: **`TextButton` のまま**（キー `verify_resend_button`・`verify_sign_out_button`）。日本語 14・下線あり・`ink`・左そろえ・高さ 44 以上。送り直しの待ち中の文言「確認メールを送り直す（あと○秒）」は今のまま。
- 動き（5秒ごとの確認・60秒の待ち・ログアウト）は今のコードのまま。

### 4.5 Google の「G」のロゴ（`lib/theme/google_logo.dart`（新規））

見本の HTML の SVG を、`flutter_svg` を使わずに `Path` に直したもの。**座標は 48×48 の中のもの**。数字を変えない（元の SVG と描画を比べて、差が出ないことを確かめてある）。

```dart
import 'package:flutter/material.dart';

/// Google の「G」のロゴ（公式の SVG の形を Path に直したもの）。装飾なので読み上げない
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _GoogleLogoPainter()),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    canvas.drawPath(_red(), Paint()..color = const Color(0xFFEA4335));
    canvas.drawPath(_blue(), Paint()..color = const Color(0xFF4285F4));
    canvas.drawPath(_yellow(), Paint()..color = const Color(0xFFFBBC05));
    canvas.drawPath(_green(), Paint()..color = const Color(0xFF34A853));
  }

  Path _red() => Path()
    ..moveTo(24, 9.5)
    ..cubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1)
    ..lineTo(40.06, 6.25)
    ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
    ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
    ..lineTo(10.54, 19.41)
    ..cubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5)
    ..close();

  Path _blue() => Path()
    ..moveTo(46.98, 24.55)
    ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20)
    ..lineTo(24, 20)
    ..lineTo(24, 29.02)
    ..lineTo(36.94, 29.02)
    ..cubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.2)
    ..lineTo(39.89, 42.2)
    ..cubicTo(44.4, 38.02, 46.98, 31.84, 46.98, 24.55)
    ..close();

  Path _yellow() => Path()
    ..moveTo(10.53, 28.59)
    ..cubicTo(10.05, 27.14, 9.77, 25.6, 9.77, 24)
    ..cubicTo(9.77, 22.4, 10.04, 20.86, 10.53, 19.41)
    ..lineTo(2.55, 13.22)
    ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24)
    ..cubicTo(0, 27.88, 0.92, 31.54, 2.56, 34.78)
    ..lineTo(10.53, 28.59)
    ..close();

  Path _green() => Path()
    ..moveTo(24, 48)
    ..cubicTo(30.48, 48, 35.93, 45.87, 39.89, 42.19)
    ..lineTo(32.16, 36.19)
    ..cubicTo(30.01, 37.64, 27.24, 38.49, 24, 38.49)
    ..cubicTo(17.74, 38.49, 12.43, 34.27, 10.53, 28.58)
    ..lineTo(2.55, 34.77)
    ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
    ..close();

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

### 4.6 動き・読みやすさ・はみ出し

- **動きは「始める」の nudge だけ**。「動きを減らす」がオンなら止める。
- 押せるものは、高さ 44 以上（HTML は 44〜48）。キーボードで操作でき、フォーカスが見える。
- 幅 **320・360・390・430・800** で、はみ出さない（`takeException` が null）。横スクロールが出ない。
- 文字の大きさを OS の設定で 1.3 倍にしても、崩れて読めなくならない（折り返す）。
- 色の帯・大きな数字・英字ラベルなど装飾は、読み上げない。見出しは `Semantics(header: true)`。

## 5. 実装前に確かめること（リーダー → ユーザー）

リーダーは、次をまとめて推奨案つきでユーザーに聞き、回答を `notes/判断ログ_A.md` に「ログイン前のデザイン（案6）」として書いてから、チームメイトを作る。**ユーザーが答えられないときは、推奨案で進め、進捗ファイルに「推奨案で進めた」と書く。**

### 5.1 「くわしく →」の行き先

HTML では `href="#"` で、行き先が無い。
- **案A（推奨）**: 押すと `/login?mode=signup`（「始める」と同じ）。説明のページが無いので、いちばん近い行き先にする。
- 案B: 見た目だけ（押しても何も起きない）。紛らわしいので非推奨。
- 案C: 「くわしく →」を消す（見本からの削除になる）。

### 5.2 新規登録のときの見出し

HTML には「おかえりなさい。入口はこちら。」しか無い。新規登録のときも同じ文言だと違和感があるので、「はじめまして。入口はこちら。」に変える提案（4.3）。変えないなら、同じ文言のまま。

### 5.3 書体の読み込みの重さ

BIZ UDPGothic（400 と 700）は 4.1 のとおり重い。**方針A（そのまま `google_fonts` で取る）で進める。** 最初の画面ができたら、人間が実機（またはスマホの回線の速さに絞った Chrome）で、文字が置き換わるまでの時間を見る。遅いとユーザーが感じたら、次のどれかを選ぶ（別の指示書で行う）:
- B: 紹介ページとログイン画面で使う文字だけに絞った（サブセットにした）フォントを同梱する（OFL のライセンスで改変できるか確かめる）
- C: 太字（700）だけ BIZ UDPGothic にして、本文は標準の書体にする
- D: 別の日本語の書体に変える（見た目が変わる）

### 5.4 横山さんへの共有

次は、横山さんが作った部分を作り直す、または共有の部分を変える。マージの前に一声かける。
- `lib/features/welcome/welcome_page.dart`（紹介ページ。作り直し）
- `lib/features/auth/login_page.dart`・`auth_widgets.dart`・`verify_email_page.dart`（見た目だけ）
- `lib/theme/brand_colors.dart`（色を入れ替える。使っているのは上の画面だけ）
- `pubspec.yaml`（書体の同梱の宣言を足す）・`assets/fonts/`（同梱の書体）

### 5.5 著作物利用シート

使う書体（BIZ UDPGothic・Roboto は Google Fonts のページでライセンスを確かめる。ArchivoHako は Archivo を改変したもので OFL）を、人間が著作物利用シートに書く（リーダーは、書く内容のメモを進捗ファイルに残す）。

## 6. 担当とファイル

同じファイルを2人が同時に編集すると上書きが起きる。**担当外のファイルは編集せず、担当者に SendMessage で依頼する。**

| 担当 | 名前 | 編集してよいファイル |
|---|---|---|
| リーダー | （メインセッション） | この計画書、`notes/判断ログ_A.md`、`notes/before_login_design_進捗.md`、**`pubspec.yaml`（書体の宣言だけ）・`assets/fonts/**`（同梱の書体のコピー）** |
| 画面（紹介ページと土台） | `ui-welcome` | `lib/theme/brand_colors.dart`、`lib/theme/hako_fonts.dart`（新規）、`lib/theme/hako_widgets.dart`（新規）、`lib/features/welcome/**` |
| 画面（ログイン系） | `ui-auth` | `lib/features/auth/**`、`lib/theme/google_logo.dart`（新規） |
| テスト・レビュー | `qa` | `test/**`、`notes/before_login_design_レビュー記録.md`（新規） |

- **読むだけ（変更禁止）**: `lib/app.dart`、`lib/theme/app_theme.dart`、`lib/repositories/**`、`lib/utils/**`、`lib/providers/**`、`lib/services/**`、`web/**`、`firestore.rules`、ログイン後の画面（`lib/features/` のうち上の担当以外）。**ロジックの差分が出ていないことは、`git diff --stat` で確かめる**（ロジックのファイルが1つでも変わっていたら、理由をリーダーに報告）。
- 共通部品に足したい・直したいことが出たら、`ui-auth` と `qa` は `ui-welcome` に SendMessage で頼む。
- **依存パッケージは足さない。** `flutter_svg` や色・書体の追加パッケージは使わない。
- 画像ファイルを足さない（書体ファイルだけ）。

## 7. 契約（インターフェース）

`ui-welcome` が最初の部品タスク（F2）で確定させ、`ui-auth` と `qa` に SendMessage で全文を送る。以下は叩き台。

```dart
// lib/theme/hako_fonts.dart
abstract final class HakoFonts {
  static TextStyle jp({
    required double size,
    FontWeight weight = FontWeight.w400, // 400 か 700 だけ
    Color color = BrandColors.ink,
    double height = 1.75,
    double letterSpacing = 0,
  });
  static TextStyle en({
    required double size,
    FontWeight weight = FontWeight.w800, // 700 / 800 / 900 のどれか（同梱の ArchivoHako）
    Color color = BrandColors.ink,
    double height = 1.75,
    double letterSpacing = 0,
  });
  static TextStyle googleButton(); // Roboto 500・14・googleText（日本語は jp に落とす）
}

// lib/theme/hako_widgets.dart
/// 土台。全面に紙（key: hako_column）。上下に色の帯（全幅）。スクロールする。中身は HakoContent（幅 430 以下・中央）で包める
class HakoPage extends StatelessWidget {
  const HakoPage({super.key, required this.child});
  final Widget child; // 色の帯の間に入る中身
}
class ColorStrip extends StatelessWidget { const ColorStrip({super.key}); } // 高さ 10・6色
class HakoPill extends StatelessWidget {
  const HakoPill({super.key, required this.label, required this.onPressed, this.small = false});
}
class HakoPrimaryButton extends StatelessWidget {
  const HakoPrimaryButton({super.key, required this.label, required this.onPressed, this.busy = false});
}
class HakoTab extends StatelessWidget {
  const HakoTab({super.key, required this.label, required this.selected, required this.onPressed});
  final bool selected; final VoidCallback? onPressed;
}
InputDecoration hakoInputDecoration({String? helperText, Widget? suffixIcon});
Widget hakoFieldLabel(String text); // 入力欄の上のラベル

// lib/theme/google_logo.dart  → 4.5 の GoogleLogo

// lib/features/auth/auth_widgets.dart（作り直し）
/// ログイン画面・確認画面の土台。HakoPage の中に、ヘッダー（戻る・アプリ名）・見出し・本文を並べる。
/// 今の引数 card・footer をやめ、heading・body にする（呼ぶのは login_page.dart と verify_email_page.dart だけ）。
/// 画面のキー（login_page・verify_email_page）は、各ページが AuthShell の `key:` に渡す（今のとおり）
class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.heading, required this.body, this.showBack = false});
  final String heading; // 改行は \n
  final Widget body;    // reCAPTCHA の文言も、ログイン画面では body の末尾に置く（footer は無くなる）
  final bool showBack;  // 戻る（key: login_back_button。HakoPill 自身にキーを付ける）
}
// AuthMessageBanner（引数は今のまま）、AuthRecaptchaNotice（今のキー・今の文言）は見た目だけ直す
// GradientButton は無くなる（HakoPrimaryButton に置き換える）
```

- 新しいキー: `hako_column`・`welcome_board`・`welcome_hall_1`〜`welcome_hall_6`・`welcome_cta_note`（`welcome_more_*` は作らない）。
- **残すキー（すべて今のまま）**: `welcome_page`・`welcome_login_button`・`welcome_start_button`・`login_page`・`login_back_button`・`login_mode_signin`・`login_mode_signup`・`login_google_button`・`login_email_field`・`login_password_field`・`login_password_toggle`・`login_password_confirm_field`・`login_error`・`login_submit_button`・`login_forgot_password_button`・`login_recaptcha_notice`・`reset_*`・`verify_*`。**`welcome_scroll_hint` だけは無くなる**。

## 8. 既存のテストの扱い

- **ロジックは変わらないので、振る舞いのテストは原則そのまま通る**。通らないテストは、まず実装のバグを疑う。
- 変えてよいのは、**見た目の部品の型に頼っている箇所**と、**文言が変わった箇所**だけ:
  - `login_page_test.dart`: `SegmentedButton<LoginMode>` を見ている2か所（`selected`・`onSelectionChanged`）→ `HakoTab` の `selected`・`onPressed` に書き直す。
  - `welcome_page_test.dart`: 「始める」の下の説明（`メールアドレスか Google アカウントで始められます。`）を見るテスト → 「6つのハコ、まとめて入場。」（`welcome_cta_note`）と、reCAPTCHA の文言が無いことを見るテストに書き直す。
  - 紹介ページの動き（nudge）は、止まらない動きなので、そのままでは `pumpAndSettle` が終わらない。**テストでは `tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true)` で動きを切る**（終わりに `clearAccessibilityFeaturesTestValue`）。
- **今のテストが頼っている構造（変えない）**:
  - キーは、**タップを受ける部品自身**に付ける（`HakoPill`・`HakoTab`・`HakoPrimaryButton` は `super.key`）。`login_back_button`・`login_mode_*`・`login_submit_button`・`verify_check_button` は `tester.tap(find.byKey(...))` の対象（タップの位置は、画面の中にあること）。
  - 型を直接読むもの: `login_google_button` は `OutlinedButton`、`login_forgot_password_button`・`reset_close_button`・`verify_resend_button`・`verify_sign_out_button` は `TextButton`（`.onPressed` を読む）、入力欄は `TextFormField`（`.controller`、`EditableText.obscureText`）。
  - `login_submit_button`・`verify_check_button`・`reset_send_button` は、キー付きの部品の**子孫**に `CircularProgressIndicator`（送信中だけ）。送信ボタンのラベルは、同じ子孫の `Text`（`find.text('ログイン')` など）。
  - `find.text('Google で続ける')`・`find.text('8文字以上')` は、画面に**ちょうど1つ**。`Google カレンダーへの追加は、使うときに Google アカウントの許可を求めます。` の説明も1つ。
  - 幅 360×640 のテストが、`login_google_button`・`login_email_field`・`login_password_field`・`login_submit_button` の左右が 0〜360 に収まること、`login_recaptcha_notice` の幅が 360 以下であることを確かめる。
  - ログイン画面のテストは `MaterialApp(home: LoginPage(...))`（ルーター無し）でも動く。`context.go` は戻るボタンを**押したときだけ**呼ぶ（build のときに `GoRouter` を探さない）。
- 書体: 画面を出すテストはすべて、`setUpAll` で `GoogleFonts.config.allowRuntimeFetching = false`（今の紹介ページのテストと同じ）にし、`tester.takeException()` が null であることを確かめる。それで例外が出る場合は、`HakoFonts` を1か所のスイッチでテスト用の書体に切り替えられるようにする（`ui-welcome` に頼む）。**書体を変えて回避しない**。
- テストを消したり、期待を弱めたりして通さない（CLAUDE.md の完了の条件）。画面のテストの書き直しを始める前に、担当の `ui-*` は qa に「テスト更新依頼: <タスクID>、変わる振る舞い、落ちるはずのテスト」を送る。

**足すテスト（qa）**

- 共通部品: `ColorStrip`（6色・`hall1`〜`hall6` の順）、`HakoTab`（選択・押せない）、`GoogleLogo`（描いても例外が出ない）、`HakoPage`（幅 800 で `hako_column` が画面の全幅）、`HakoContent`（幅 800 で 430 以下・中央）
- 紹介ページ: 6つのハコの見出しと説明が出る・番号 01〜06・「くわしく →」が無いこと・掲示板の3行・「始める」「ログイン」の行き先（今のテスト）・幅 320・360・430・800 ではみ出さない・動きを切ると `pumpAndSettle` が終わる
- ログイン画面: 見出しがモードで変わる（5.2 の答え）・「または」の区切りがある・Google ボタンに `GoogleLogo` がある・幅 320 ではみ出さない・戻るボタンが `/welcome` へ移す
- 確認待ち画面: 幅 320 ではみ出さない

## 9. タスク一覧

リーダーが共有タスクリストに、担当と依存関係を付けて登録する。

| ID | 担当 | 内容 | 依存 |
|---|---|---|---|
| L0 | リーダー | 書体ファイルを `assets/fonts/` にコピーし、`pubspec.yaml` に `fonts:` を足して `flutter pub get`（12.0 の手順）。5章の確認 | |
| T0 | qa | 品質ゲートの確認（`flutter analyze`・`flutter test`）。落ちるテストがあれば、直す（`test/` のみ）か報告 | |
| F1 | ui-welcome | `brand_colors.dart` に新しい色を足す（旧名は残す）と `hako_fonts.dart`。方針をリーダーへ送り、返事を待たずに進める | L0 |
| F2 | ui-welcome | `hako_widgets.dart`（`HakoPage`・`ColorStrip`・`HakoPill`・`HakoPrimaryButton`・`HakoTab`・入力欄）。契約（7章）を ui-auth と qa に送る | F1 |
| A0 | ui-auth | `google_logo.dart`（4.5 のコードを写す。`flutter analyze` を通す） | |
| W1 | ui-welcome | 紹介ページの作り直し（4.2）。**先に qa へテスト更新依頼** | F2 |
| A1 | ui-auth | `auth_widgets.dart`（`AuthShell`・`AuthMessageBanner`・`AuthRecaptchaNotice`。`GradientButton` を消す） | F2 |
| A2 | ui-auth | `login_page.dart`（4.3。再設定のダイアログを含む）。**先に qa へテスト更新依頼** | A0, A1 |
| A3 | ui-auth | `verify_email_page.dart`（4.4） | A1 |
| Q1 | qa | 共通部品のテスト（8章） | F2, A0 |
| Q2 | qa | 紹介ページのテストの書き直しと追加 | W1 |
| Q3 | qa | ログイン画面・確認待ち画面のテストの書き直しと追加 | A2, A3 |
| C1 | ui-welcome | 旧い色の名前を消す（`grep` で使われていないことを確かめてから）。使われなくなった部品・import を消し、`flutter analyze` を0件にする | W1, A1〜A3 |
| R1 | qa | まとめレビュー（11章） | すべて |
| L1 | リーダー | 結合確認、`git diff --stat` でロジックの差分が無いことの確認、ユーザーへの動作確認手順（12章）、判断ログ、コミット案 | すべて |

## 10. バグを防ぐための進め方

1. **担当外のファイルは編集しない。** 直してほしい箇所は担当者に SendMessage で伝える。
2. **契約を先に決める。** F2 が終わるまで、ui-auth と qa は共通部品に依存する部分を書かない（A0 は先に進めてよい）。
3. **各タスクの最初に、方針を3〜5行でリーダーに送る。返事を待たずに書き始める。** リーダーは、方針に問題があるときだけ返事をする（前回の front1 で、全員が方針の返事を待って止まった反省）。タスクを終えたら、完了報告を送ったあと、依存が解けている次のタスクへ**すぐに進む**（「次の方針を送る」ことを理由に待たない）。
4. **作業ツリーを壊れたまま放置しない。** 旧い色の名前は、全部の画面が移るまで消さない（2つの画面担当が別々に進めても、コンパイルが通る）。
5. **品質ゲート:** タスクを完了にするたびに、`.claude/hooks/quality-gate.sh` が `flutter analyze`・`flutter test`・ルールのテストを実行する。失敗すると完了が差し戻される。
6. **見た目は数値で合わせ、画像で確かめる。** 4章の数値と、参照画像（`hako_案6_390px_ref.png`）を見比べる。幅 390 で、区画の高さが 4章の表と ±8px 以内なら合格（文字の描画の差は許す）。Dev Container で画面を撮れるなら撮って比べてよい（撮るための道具をリポジトリの依存に足さない。一時ファイルは `/tmp` に置く）。撮れなければ省略し、最終の見た目の確認は人間が行う（12章）。
7. **実装タスクを終えたら、qa にレビューを依頼する。** qa はレビュー依頼を最優先で処理する。
8. **ロジックを変えない。** 認証・ルーター・検査・文言（エラーなど）の関数・リポジトリを触らない。`FirebaseAuth` を画面から直接呼ばない。
9. **秘密情報・パスワードを残さない。** ログ・テストの出力に出さない。テストの値は架空にする。
10. **判断を記録する。** 比べた案・選んだ理由・捨てた案は、リーダーが `notes/判断ログ_A.md` に追記する（5章の回答、書体を同梱にした理由、nudge の止め方を必ず含める）。

## 11. レビューの観点

- 見た目: 4章の数値どおりか（色・大きさ・余白・字間・行の高さ）。蛍光ペンの位置。6つのハコの高さ。硬い影。大きな数字の重なり。ヘッダー・戻る・見出し（モード別）
- 書体: `HakoFonts` を通しているか（`GoogleFonts.` の直書きが無いか）。`Text` にテーマの書体が混ざっていないか。英字ラベルが ArchivoHako（横に広い形）になっているか。日本語が BIZ UDPGothic の 400/700 だけか
- 動き: nudge がボタンの影ごと動くか。「動きを減らす」で止まるか。ほかに動きが無いか。画面を閉じたときにコントローラを破棄しているか
- 操作: 押せる範囲が 44 以上か。フォーカスが見えるか。二重送信が防がれているか（今の動きのまま）。`await` の後の `context.mounted`
- ロジック: **ロジックのファイルの差分が無いか**（`lib/app.dart`・`repositories`・`utils`・`providers`）。キーがすべて残っているか
- はみ出し: 幅 320・360・390・430・800・文字 1.3 倍
- テスト: 期待を弱めていないか。新しい部品・紹介ページ・ログイン画面・確認画面にテストがあるか。動きを切って `pumpAndSettle` が終わるか
- 旧い部品: `GradientButton`・旧い色の名前・`_heroImage` が残っていないか
- ライセンス: 同梱の書体に OFL の全文があるか。`assets/fonts/` の中に不要なファイルが無いか
- 横山さんのファイル: 5.4 で共有した範囲の外を変えていないか

## 12. 人が行う設定と動作確認

### 12.0 開始前の準備（L0。リーダーが行う）

1. `assets/fonts/` を作り、`markdown/design_before_login/fonts/` の `ArchivoHako-*.ttf` と `OFL-Archivo.txt` をコピーする（`cp -n`）。
2. `pubspec.yaml` の `flutter:` の下に足す（既にあれば足さない）:

```yaml
  fonts:
    - family: ArchivoHako
      fonts:
        - asset: assets/fonts/ArchivoHako-Bold110.ttf
          weight: 700
        - asset: assets/fonts/ArchivoHako-ExtraBold125.ttf
          weight: 800
        - asset: assets/fonts/ArchivoHako-Black125.ttf
          weight: 900
```

3. `flutter pub get`。

### 12.1 動作確認（人が行う。Dev Container で `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080`、Mac の Chrome で `http://localhost:8080`）

1. Chrome の開発者ツール → 端末のツールバーで幅 390 にする。**別のタブで参照の HTML を開き、並べて見比べる**（色・文字の大きさ・余白・ハコの高さ・蛍光ペン・大きな数字・硬い影）
2. 紹介ページ: 「始める」→ ログイン画面（**新規登録**の札が選ばれ、見出しが「はじめまして。」（5.2）。右上の「ログイン」→ ログインの札。「← 戻る」で紹介ページへ
3. 「始める」ボタンが、ゆっくり左上に動いてもどる。OS の「視差効果を減らす」（Mac: システム設定 → アクセシビリティ → ディスプレイ）をオンにすると止まる
4. ログイン画面: 札の切り替え（欄が出る・消える）、Google で続ける（今までどおりログインできる）、メールで登録 → 確認待ち画面（新しい見た目）→ メールのリンク → 先へ進む。「パスワードを忘れた方」のダイアログ。エラーの帯
5. 幅 320・360・430 と、PC の幅（1280）。PC では紙と色の帯が全幅に出て、中身だけが幅 430 以下で中央に並ぶ
6. キーボードだけで操作する（Tab で移動し、フォーカスが見える）
7. 書体の読み込み: 開発者ツールの Network で、BIZ UDPGothic のファイルの大きさと、文字が置き換わるまでの時間（スロットリングを「Fast 4G」にして）を見る。遅ければ 5.3 の B〜D から選ぶ
8. 文字の大きさを 1.3 倍にしても崩れない

## 13. リーダー（メインセッション）の進め方

0. **モデル**: チームメイトは **Sonnet 5.5（`claude-sonnet-5-5`）**。`.claude/agents/*.md` の `model:` と、`.claude/settings.local.json` の `model`（リーダーの既定）に設定済み。起動したとき、違うモデルになっていたら、`/model claude-sonnet-5-5` に切り替えるようユーザーに伝える（リーダーを別のモデルにしたい場合は、ユーザーが `/model` で選ぶ）。
1. この文書と `CLAUDE.md` を読む。リーダーは自分でコードを書かず、調整・タスク管理・ユーザーへの確認に専念する。
2. `git status -sb` で `design/before_login` にいて最新であることを確かめる（0章）。
3. `flutter analyze`・`flutter test`・ルールのテストを実行し、品質ゲートが通る状態かを確認する。通らなければ、原因をユーザーに報告して判断を仰ぐ。
4. 5章をまとめてユーザーに聞き、回答を判断ログに書き、5章に結果を書き足す。L0（書体の宣言）を行う。**確認が済むまでチームメイトは作らない。**
5. チームメイトを3人作る（**モデルは Sonnet 5.5**）。各チームメイトはリーダーの会話履歴を見られないので、作成時の指示に必要なことを書く。
   - `dev-ui` エージェントタイプで、名前 `ui-welcome`。指示: 「markdown/feature_before_login_design_plan.md を読み、担当 ui-welcome として F1 から始めて。F1 の方針を私（リーダー）に送ること（返事を待たずに進めてよい。問題があれば私から連絡する）。ロジックのファイル（lib/app.dart・repositories・utils・providers）は変えないこと。依存パッケージを足さないこと」
   - `dev-ui` エージェントタイプで、名前 `ui-auth`。指示: 「markdown/feature_before_login_design_plan.md を読み、担当 ui-auth として、まず A0（google_logo.dart）を。F2 の契約が届いたら A1 へ。認証の動き（ログイン・登録・検査・エラーの文言）は変えず、見た目の部品だけ置き換えること。キーはすべて残すこと」
   - `dev-qa` エージェントタイプで、名前 `qa`。指示: 「markdown/feature_before_login_design_plan.md を読み、担当 qa として T0 から始めて。以降はレビュー依頼とテスト更新依頼を最優先に。8章の方針（期待を弱めない・書体を変えて回避しない・動きを切る）を守ること。パッケージを足さないこと」
6. 9章のタスクを共有タスクリストに登録する（担当・依存関係つき）。
7. 進行中は、担当外ファイルの編集・同じファイルの同時編集・契約の食い違い・**ロジックのファイルの変更**・**横山さんのファイルへの想定外の変更**・**テストを消して通していないか**・**パッケージや画像の追加**を見張る。ユーザーが決めるべきことは、まとめてユーザーに聞く。**誰も動いていない時間ができたら（全員が返事待ちになる、完了報告のあと止まる、など）、すぐに次の指示を出す。**
8. W1 とログイン系（A2）の最初の見た目ができたら、**ユーザーに見てもらう**（12.1 の 1・2・7）。書体の重さ（5.3）はここで判断を仰ぐ。
9. すべて完了したら L1 を行う。ユーザーに 12章の動作確認手順と、コミット案（メッセージと含めるファイル、横山さんのファイル・共有ファイルを変えた箇所）を示し、了承を得てからコミットする。`git push`・Pull Request・デプロイはユーザーが行う。
10. 最後にチームメイトを終了させ、チームを片付ける。

## 14. 使用量の上限で止まったときのために

- リーダーは `notes/before_login_design_進捗.md` を、**タスクが1つ終わるたび**に更新する（状態・担当・触ったファイル・次にやること・ユーザーに聞きたいこと）。止まって再開するときは、まずこのファイルを読み、終わったタスクはやり直さない。
- Claude Code が終了してチームメイトがいなくなったら、まだ終わっていないタスクの担当だけを作り直す（13章の指示に「notes/before_login_design_進捗.md を読み、自分の未完了のタスクから再開すること」を足す）。
- 自動で再開させるときは、引数で進捗ファイルと計画書を渡す。
  - 見張り役（tmux）: `bash .claude/scripts/auto-resume.sh <送り先のペイン> notes/before_login_design_進捗.md`
  - 非対話（tmux なし）: `bash .claude/scripts/auto-resume-headless.sh notes/before_login_design_進捗.md markdown/feature_before_login_design_plan.md`
- 使用量を抑えるルール（全員）: メッセージは短く、ファイルの中身やテストの出力を丸ごと貼らない。作業中のテストは関係するファイルだけを実行し、全体は完了時の品質ゲートに任せる。長い出力は末尾だけを見る。計画書は自分に関係する章だけを読み直す。進み具合の確認のためだけのメッセージを送り合わない。
- 許可の確認で止まらないように、シェルのコマンドは1つずつ実行する（`;`・`&&`・`|` でつながない、`$変数` を使わない）。ファイルの読み書き・検索は Read・Edit・Grep などの道具を使う。
