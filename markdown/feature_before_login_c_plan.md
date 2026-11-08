# 計画書: 紹介ページ（/welcome）を「案C 改」にする（ログイン前のリデザイン）

> 担当A（とし）の作業を、Claude Code の agent team（リーダー＋チームメイト3人。**モデルは Sonnet 5.5**）で実装するための指示書（仕様書を兼ねる）。人間とエージェントの両方が読む。
> 4章はユーザーが渡したデザイン（案C 改・`oshiashi_C_v3.html`）を Dart（Flutter）で再現するための仕様。「5. 実装前に確かめること」だけが、リーダーがユーザーに聞く項目（どれも推奨案つき）。
> **この計画書のコードは、Flutter がクラウドの環境に無いため、一度もコンパイルしていない。** 写すときは `flutter analyze` で確かめる。

## 0. 作業ブランチと前提

- **作業ブランチは `redesign/before_login`**（GitHub の `origin/redesign/before_login` を追う）。古い案6のブランチ `design/before_login` とは別物。ブランチの作成・切り替え・pull・push・マージは人間が行う。エージェントはブランチを切り替えない。
- 完成したら、人間が `redesign/before_login` から `dev` へ Pull Request を出す。
- 開始前に、リーダーは `git status -sb` で `redesign/before_login` にいて、`origin/redesign/before_login` より遅れていない（`behind` が無い）ことを確かめる。遅れていたらユーザーに `git pull --no-rebase` を頼む。
- **`origin/dev` に対しては、2026-11-08 の時点で 5 コミット古い**（PR #56 の通知まわりなど。`git log --oneline HEAD..origin/dev` で見える）。紹介ページ（`lib/features/welcome/**`）とそのテストは `dev` 側で変わっていない（最後の変更は 3825c99）ので、マージで衝突しにくい。PR を出す前に、人間が `git merge origin/dev` で追いつく。
- **前提（実装済み）**: 案6の紹介ページ・ログイン・確認待ち（PR #41）、ログイン後の画面（統合案 v4。履歴に fdda7ab）。今回は**紹介ページ（`/welcome`）だけの見た目の差し替え**で、**動き（ロジック）は変えない**。
- **Dart（Flutter）で書く。** JavaScript・HTML で画面を作らない（`web/index.html` も触らない）。参照用の HTML は見た目の見本であって、アプリには入れない。
- Firebase は Spark（無料）プランのまま。**デプロイ（`firebase deploy`）・`git push` はしない。**
- 締切: チームの計画では **11/8（今日）の夜に機能を凍結**する。**見た目の差し替えが間に合わなければ、このブランチを `dev` に入れず、今の紹介ページ（案6）のまま提出する**（途中の状態を `dev` に入れない）。

## 1. 範囲

**作るもの**

1. 紹介ページ（`/welcome`）を案C 改にする。ヘッダー → 最初の画面（見出し・掲示板）→ PROBLEM 01 → FLOW → PROBLEM 02 → SOLUTION（6つのハコ）→ FAQ → CTA。
2. 紹介ページだけで使う、幅の区切りと部品（`lib/features/welcome/` の中に置く）。
3. 既存の紹介ページのテストの書き直しと、新しい区画のテスト。

**作らないもの**

- ロジックの変更・画面の移動先の変更（今のとおり。「おしあしを始める」→ `/login?mode=signup`、右上の「ログイン」→ `/login`）
- ログイン画面・確認待ち画面（`lib/features/auth/**`）、ログイン後の画面、アプリ全体のテーマ
- **共有の土台は変えない**: `lib/theme/**`（`brand_colors.dart`・`hako_fonts.dart`・`hako_widgets.dart` など。ログイン・確認待ち・ログイン後の画面が使っている）は**読むだけ**。紹介ページで足りないものは、`lib/features/welcome/` の中に作る。
- 写真・イラスト・動画・書体ファイルの追加・依存パッケージの追加（`pubspec.yaml` に触らない）
- 動き（アニメーション）。見本の HTML に動きは無い。案6の「始める」の nudge（ゆっくり動く）は**無くなる**（5.5）
- **見本にだけあって、本番に出さないもの**: 上の「案C 改」のバッジ、いちばん下の「おしあし — ログイン前画面 文言案」の行

## 2. 決まっていること（ユーザーの指示）

| 項目 | 決定 |
|---|---|
| デザイン | ユーザーが渡した `oshiashi_C_v3.html`（案C 改）と同じ見た目にする。見本は `markdown/design_before_login_c/`（元の HTML と、CSS の食い違いを2つだけ直した修正版。5.1） |
| 言語 | Dart（Flutter）。JavaScript ではない |
| 作業ブランチ | `redesign/before_login`（「このリデザイン、ビフォーログインのブランチ」） |
| 画面の移動 | 今までと同じ（「始める」→ ログイン画面の新規登録、「ログイン」→ ログイン画面） |
| チームのモデル | Sonnet 5.5（`claude-sonnet-5-5`） |

## 3. 現状のコード（調べたこと）

| 項目 | 今の状態 | 場所 |
|---|---|---|
| 紹介ページ | 案6「ハコ色」（639行）。`HakoPage`（上下に色の帯・全幅の紙）の中に、`_Header`・`_Hero`（見出し・掲示板「TODAY'S 締切」）・`_HallGrid`（6つのハコ。幅 600 以上で3列）・`_Cta`（「始める」ボタン。ゆっくり動く）。左右の余白は `_Wide`（20 / 40 / 64、最大 1100）。キー: `welcome_page`・`welcome_login_button`・`welcome_start_button`・`welcome_board`・`welcome_hall_1`〜`6`・`welcome_cta_note`・`hako_column`（`HakoPage` の紙）。「始める」→ `context.go('/login?mode=signup')`、「ログイン」→ `context.go('/login')` | `lib/features/welcome/welcome_page.dart` |
| 共有の土台（読むだけ） | `BrandColors`（paper・ink・hall1〜6・onInkSub・surface など）、`HakoFonts.jp`（BIZ UDPGothic。400/700。**行の高さの既定は 1.75**）・`HakoFonts.en`（同梱の ArchivoHako。700/800/900。日本語は jp に落ちる）、`HakoPill`（丸い枠のボタン。最小の高さ 44）、`HakoPage`・`ColorStrip`（ログイン系の画面が使う） | `lib/theme/brand_colors.dart`・`hako_fonts.dart`・`hako_widgets.dart` |
| テスト | 282行。`pumpWelcome`（`GoRouter` で `/welcome` と `/login` を用意）、動きを切る `setUp`、キー `hako_column`・`welcome_hall_*`・`welcome_board`・`welcome_cta_note` を見る、**文言**（見出し・リード文・6つのハコ・掲示板の「TODAY'S 締切」・「6つのハコ、まとめて入場。」）を見る、幅ごとの余白（20/40/64・最大 1100）と列の数（600 で3列）を見る、幅 320〜の「はみ出さない」、文字 1.3 倍。**多くは、この変更で書き直しになる**（8章） | `test/features/welcome_page_test.dart` |
| テストの共通設定 | `test/flutter_test_config.dart` が、すべてのテストの前に `GoogleFonts.config.allowRuntimeFetching = false` にする（フォントを取りに行かない） | `test/flutter_test_config.dart` |
| ルート | `/welcome` は `lib/app.dart`。**ルートは変えない** | `lib/app.dart` |
| 書体 | BIZ UDPGothic（`google_fonts`。ネットで取る）と ArchivoHako（同梱。`assets/fonts/`・`pubspec.yaml` に宣言済み）。**追加は不要** | `pubspec.yaml` |

## 4. 仕様（デザイン）

### 4.0 見本の読み方

- 見本は `markdown/design_before_login_c/`。
  - `oshiashi_C_v3.html` — ユーザーが渡した**元の HTML**（変更なし）。
  - `oshiashi_C_v3_fixed.html` — 元の HTML の CSS の食い違いを**2つだけ**直した版（5.1）。**この計画書の数値と参照画像は、この修正版を正とする**（5.1 で「元のまま」を選ばれたら、元の HTML が正）。
  - `shots/` — 参照画像（下の表）。**全面の撮影で、いちばん上に「案C 改」のバッジ（高さ 32.4）が写っている**。本番にバッジは無いので、実際の画面の位置は、画像の位置から 32.4 を引く。
  - `measure.json` — 幅 360 / 390 / 520 / 521 / 640 / 760 / 761 / 1000 / 1440px で測った、区画ごとの `[幅, 高さ, ページ上端からの位置]`（バッジ込み）。
- **参照画像は、BIZ UDPGothic（本文）と Archivo（英字・数字）で描いて撮ったもの**。見本の HTML の書体指定（Hiragino Sans など）は、アプリでは使えない（4.2）。**文字の形・折り返しの位置が、Flutter とぴったり同じにはならない**（Chrome は日本語を文節で折り返すが、Flutter は文字の間で折り返す。5.6）。大きさ・余白・色・並びを合わせる。
- 画像は Read で見られる。

| ファイル（`shots/`） | 中身 |
|---|---|
| `c3_390_1.png`〜`c3_390_4.png` | 幅 390（スマホ）。上から 1350px ずつ。1: ヘッダー・最初の画面・PROBLEM 01 ／ 2: FLOW・PROBLEM 02・SOLUTION ／ 3: 6つのハコ（1列）・FAQ ／ 4: FAQ・CTA |
| `c3_1000_1.png`・`c3_1000_2.png` | 幅 1000（PC）。上から 1750px ずつ |
| `c3_640_tiles.png` | 幅 640。SOLUTION の黒い帯と、6つのハコが **2列**のとき |
| `c3_1440_tiles.png` | 幅 1440。6つのハコが**全幅で3列**（中身の最大幅 960 の外まで広がる） |
| `c3_faq_open_390.png` | 幅 390。FAQ の1つ目と3つ目を開いたところ |
| `c3_orig_390_top.png` | **元の HTML のまま**の幅 390 の上のほう。余白が消えて詰まっている（5.1 の選択肢B） |

### 4.1 色（既存の `BrandColors` を使う。新しい色を足さない）

| HTML | 値 | アプリ |
|---|---|---|
| `--cream` | `#FBF6EA` | `BrandColors.paper`（同じ） |
| `--ink`・文字・枠 | `#111` | `BrandColors.ink`（`#121212`。差は 1/255） |
| `--yellow` | `#F2D117` | `BrandColors.hall3`（`#F2D21B`） |
| `--red` | `#E8432C` | `BrandColors.hall1`（`#E8452C`） |
| `--orange` | `#FF9F1C` | `BrandColors.hall2`（同じ） |
| `--green` | `#2BBF7E` | `BrandColors.hall4`（`#2DBE7E`） |
| `--blue` | `#4B9BF0` | `BrandColors.hall5`（`#4A9BEF`） |
| `--pink` | `#F27BB0` | `BrandColors.hall6`（`#F07BAE`） |
| `#ddd`（黒い区画の補足文） | | `BrandColors.onInkSub`（同じ） |
| `#333`（掲示板の行の区切り） | | `BrandColors.boardRow`（同じ） |
| 白（困りごと・期限の流れ・FAQ の地） | | `BrandColors.surface`（白） |
| `#444`（掲示板の見出しの下線）・`#aaa`（黒い区画の小さな補足）・`#777`（見出しの上の小さな英字） | | **紹介ページの中だけの色**として `WelcomeColors`（`welcome_layout.dart`）に置く。`#777` は、紙の上で 4.15:1 と低いので `#6B6B6B`（4.94:1）にする（5.4） |

- 色の差（最大 3/255）は見分けがつかない。**共有の `BrandColors` の値は変えない**（ほかの画面の色が変わるため）。5.2 で聞く。
- 文字と背景のコントラスト（計算済み）: 墨 × 紙 17.4 ／ 墨 × 赤 4.74 ／ 墨 × 橙 9.12 ／ 墨 × 黄 12.5 ／ 墨 × 緑 7.83 ／ 墨 × 青 6.45 ／ 墨 × 桃 7.27 ／ 黄 × 墨 12.5 ／ `#aaa` × 墨 8.06 ／ `#ddd` × 墨 13.79 ／ **白 × 赤 3.95（足りない）**。**ハコの上の文字は墨だけにする**。「申込」の札（赤）の文字は、HTML は白だが、**墨にする**（5.4）。
- 色だけで意味を伝えない（申込・当落・入金は、札の文字でも分かる）。

### 4.2 書体と文字の作り方

HTML の書体は `Hiragino Sans` / `Noto Sans JP` / `Yu Gothic` / `Meiryo`（日本語。太さ 800）と `Helvetica Neue` / `Arial`（日付・英字ラベル・大きな番号）。**Flutter Web（CanvasKit）では、端末の名前つきの書体を使えない**ので、次に置き換える（5.3）。

| 用途 | アプリの書体 | 補足 |
|---|---|---|
| 日本語・本文・見出し・ボタン | `HakoFonts.jp`（BIZ UDPGothic。**太さは 400 と 700 だけ**） | HTML の 800 は 700 にする（`HakoFonts.jp` は 600 以上を 700 にするので、`FontWeight.w800` を渡してよい）。500（`small`）は 400 になる |
| 英字・数字（日付・「HALL 01」・「FOLLOW」・大きな番号・「PROBLEM 01」・「NEXT」） | `HakoFonts.en`（同梱の ArchivoHako。700 / 800 / 900） | 日本語や「→」は、自動で日本語の書体に落ちる。ArchivoHako は Helvetica Neue より**横に広い** |

- **書体の指定はすべて `HakoFonts` を通す**（`GoogleFonts.` や `fontFamily:` を画面に直接書かない）。`Text` には必ず `style` を渡す（テーマの書体が混ざらないように）。
- **行の高さに注意**: `HakoFonts.jp`・`en` の既定は 1.75 だが、**この HTML の本文の `line-height` は 1.7**（`body`）。見出しは別の値（下の表）。**`height:` を毎回明示する**。同じ指定を何度も書かないよう、`welcome_layout.dart` に、行の高さの既定を 1.7 にした小さな関数 `welcomeJp(...)`・`welcomeEn(...)` を作ってよい（中で `HakoFonts` を呼ぶ）。
- `clamp(最小, vw, 最大)` は、`welcomeClamp(幅, min:, vw:, max:)` = `(幅 × vw / 100).clamp(最小, 最大)`（幅は `MediaQuery.sizeOf(context).width`）。
- `letter-spacing: .16em` は `size × 0.16`（px）。

**文字の一覧**（`px`。色は 4.1。「幅」は `MediaQuery` の幅）

| 要素 | 大きさ | 太さ | 行の高さ | 字間 | 色 | 書体 |
|---|---|---|---|---|---|---|
| ロゴ「おしあし」 | 30 | 700 | 1.7 | 0.6 | ink | jp |
| 「ログイン」 | 16 | 700 | （`HakoPill` に任せる） | | ink | `HakoPill(fontSize: 16)` |
| 見出し（h1） | clamp(40, 8vw, 68) | 700 | **1.2** | size×0.01 | ink | jp |
| リード文 | 17 | 400 | 1.7 | | ink | jp |
| 掲示板の見出し「NEXT 締切」 | 13 | 800 | 1.7 | 1.56 | 黄（hall3） | en |
| 掲示板の小さな補足 | **10.83**（`small` の標準） | 400 | 1.7 | 0.43 | `WelcomeColors.muted` | jp |
| 掲示板の日付 | 16 | 700 | 1.7 | 0.64 | 白 | en |
| 札（入金・申込・当落） | 12 | 700 | 1.7 | | ink | jp |
| 掲示板の行の文 | 15 | 400 | 1.7 | | 白 | jp |
| 見出しの上の英字（eyebrow） | 12 | 800 | 1.7 | 1.92 | `WelcomeColors.eyebrow`（黒い帯の中は黄） | en |
| 区画の見出し（h2） | clamp(26, 4.4vw, 36) | 700 | **1.35** | | ink | jp |
| 区画の説明文 | 16 | 400 | 1.7 | | ink | jp |
| 困りごとの「」つきの題 | 19 | 700 | **1.5** | | ink | jp |
| 困りごと・期限の説明 | 14.5 | 400 | 1.7 | | ink | jp |
| 期限の札（申込・当落・入金） | 13 | 700 | 1.7 | | ink | jp |
| 期限の小見出し | 20 | 700 | 1.7 | | ink | jp |
| SOLUTION の見出し | clamp(26, 4.6vw, 38) | 700 | **1.4** | | 白 | jp |
| SOLUTION の説明 | 16 | 400 | 1.7 | | onInkSub | jp |
| ハコの上の「HALL 01」「FOLLOW」 | 12 | 800 | 1.7 | 1.68 | ink | en |
| ハコの題 | clamp(22, 3vw, 28) | 700 | **1.3** | | ink | jp |
| ハコの説明 | 14.5 | 400 | **1.75** | | ink | jp |
| ハコの大きな番号 | 92（幅 760 以下は 72） | 900 | **1** | | 黒の 12%（`Colors.black.withValues(alpha: 0.12)`） | en |
| FAQ の質問 | 16.5 | 700 | 1.7 | | ink | jp |
| FAQ の「＋」「−」 | 22 | 700 | **1** | | ink | jp |
| FAQ の答え | 15 | 400 | 1.7 | | ink | jp |
| CTA の見出し | clamp(22, 4vw, 30) | 700 | **1.4** | | 白 | jp |
| CTA の説明 | 15 | 400 | 1.7 | | onInkSub | jp |
| ボタンの文字 | 26（幅 520 以下は 21） | 700 | 1.7 | | ink | jp |
| ボタンの「→」 | 32 | 700 | 1.7 | | ink | jp |
| CTA の注記 | 13 | 400 | 1.7 | | `WelcomeColors.muted` | jp |

- **蛍光ペン**（見出しの「もう逃さない。」と SOLUTION の「おしあし」）: CSS は `linear-gradient(transparent 80%, 色 80%)` で、文字の内容領域（BIZ UDPGothic では **文字の大きさ ×1.0**）の**下 20%** を塗り、さらに右に `padding-right: .15em` を足す。Flutter では、`WelcomeMark`（`welcome_layout.dart`）にする。
  - 作り: `Stack(clipBehavior: Clip.none)` の下に帯、上に `Text`。全体の右に `Padding(right: size × 0.15)` を足し、帯は左〜右いっぱい。
  - 帯の高さ = `size × 0.2`。帯の下端は、その行の下端から `(行の高さ − 1.0) / 2 × size` だけ上。見出し（行の高さ 1.2）は `size × 0.1`、SOLUTION（1.4）は `size × 0.2`。帯の色は、見出しは黄（hall3）、SOLUTION は赤（hall1）。
  - 見出しの「もう逃さない。」は、見出しの2行目として単独の `Text`（ブロック）。SOLUTION の「おしあし」は、文の途中なので `Text.rich` の `WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic, child: WelcomeMark(...))`。文字の大きさ・行の高さを周りと同じにする。
  - 文字の拡大でその行が折り返したら、帯は最後の行にだけ付いてよい。
- **硬い影**: `BoxShadow(color: …, offset: Offset(5, 5), blurRadius: 0)`（ぼかし 0）。
- **行の高さ**を CSS と同じ見た目にするため、`HakoFonts` は `leadingDistribution: even` を入れている。自分で `TextStyle` を作るときも同じにする。

### 4.3 ページの枠と幅の区切り

**画面全体**

- `Scaffold(key: Key('welcome_page'), backgroundColor: BrandColors.paper)` の中に、`SafeArea(bottom: false)` ＋ `SingleChildScrollView` ＋ `Column(crossAxisAlignment: stretch)`。**`HakoPage`・`ColorStrip` は使わない**（案C 改には色の帯が無い。`hako_column` は紹介ページから無くなる）。
- 紙（paper）は全幅。**黒い帯（SOLUTION・CTA）と6つのハコの格子は全幅（幅の上限なし）**。そのほかの中身は `WelcomeWrap`。
- いちばん下の CTA の黒い帯は、画面の下の安全な余白（`MediaQuery.viewPaddingOf(context).bottom`）を、帯の下の余白に足す。

**`.wrap`（`WelcomeWrap`）**: 最大幅 **960**（左右の余白を含む）・中央。左右の余白は **24**（画面の幅が 520 以下なら **18**）。つまり、幅 1000 以上で中身の幅は 912、幅 390 で 354。

**幅の区切り**（CSS の `@media (max-width: …)` と同じ。`MediaQuery.sizeOf(context).width` で決める。`LayoutBuilder` の幅ではない）

| 画面の幅 | 6つのハコ | 困りごと（2種類）・期限の流れ | 左右の余白 | ボタンの文字 | ハコの下の余白・番号 |
|---|---|---|---|---|---|
| 761 以上 | 3列 | 3列 | 24 | 26 | 下 76・番号 92・最小の高さ 260 |
| 521〜760 | 2列 | 1列 | 24 | 26 | 下 64・番号 72・最小の高さ なし |
| 520 以下 | 1列 | 1列 | **18** | **21** | 下 64・番号 72・最小の高さ なし |

- 区切りは `WelcomeBreakpoints`（`tablet = 760`・`phone = 520`）にまとめる。ほかの場所に数字を書かない。

**同じ行の高さをそろえる格子（`WelcomeGrid`）**: CSS の `grid` は、同じ行のセルを同じ高さにそろえる（`stretch`）。Flutter では、`LayoutBuilder` で幅を測り、各セルを**決まった幅の `SizedBox`** にして、行を `IntrinsicHeight(Row(crossAxisAlignment: stretch))` にする。**`Expanded` にしない**（`IntrinsicHeight` が実際より広い幅で折り返しを測り、あふれることがある。案6の紹介ページで実際に起きた）。セルの幅 = `(全体の幅 − 隙間 × (列数 − 1)) / 列数`。困りごと（隙間 16）と6つのハコ（隙間 0）で使う。

### 4.4 ヘッダー・最初の画面・掲示板

**ヘッダー**: **画面の左上に「おしあし」、右上に「ログイン」**（ユーザーの追加指示 2026-11-08。`WelcomeWrap`（最大 960）の外。左右の余白は 24・幅 520 以下は 18）。上の余白 **28**（5.1）。左に「おしあし」、右に「ログイン」。縦は中央にそろえる。ヘッダーの高さ（上の余白を含む）は **79**（ロゴの行が 51）。
- 「おしあし」は `FittedBox(fit: BoxFit.scaleDown, alignment: centerLeft)`（狭い画面・大きい文字ではみ出さないように）。
- 「ログイン」は `HakoPill(key: Key('welcome_login_button'), label: 'ログイン', fontSize: 16, onPressed: () => context.go('/login'))`。HTML の丸い枠は高さ 43.2・幅 約 103。`HakoPill` は高さ 44・幅は少し細くなる。**差は許す**（共有の部品を変えない）。

**最初の画面（hero）**: `WelcomeWrap`。上の余白 **56**、下の余白 **8**。
1. 見出し（`Semantics(header: true)`。キー `welcome_h1`）: 2行。1行目「推し活の予定を、」、2行目「もう逃さない。」（蛍光ペン）。**1行目と2行目の間で必ず改行**（HTML の `<br>`）。文字の大きさは `clamp(40, 8vw, 68)`（幅 390 で 40、幅 640 で 51.2、幅 850 以上で 68）。幅 390 で見出しの高さは **96**（2行 × 40 × 1.2）、幅 1000 で **163.2**。
2. リード文（キー `welcome_lead`）: 上の余白 **24**。最大幅 **680**（40em）。
3. 掲示板（キー `welcome_board`）: 上の余白 **32**。

**掲示板**: 地は墨（ink）・内側の余白は 上 16 / 左右 16 / 下 6。
- 見出しの行: 「NEXT 締切」（黄）に続けて、**8 空けて**小さな補足「直近の締切（表示例）」。下に 1px の線（`WelcomeColors.rule`）、線の上に 8 の余白。
- 3行（日付 ｜ 札 ｜ 文）。行の上下の余白 10・間 16。日付は**幅 52 の箱**（`SizedBox(width: 52)`。ArchivoHako は広いので、`FittedBox(fit: BoxFit.scaleDown, alignment: centerLeft)` で包み、はみ出さないようにする）。札は**幅 54**・上下 2・文字は中央・角丸なし・色は 入金=hall4（緑）／申込=hall1（赤）／当落=hall3（黄）。文は残りの幅（折り返す）。行の間に 1px の線（`boardRow`。**最後の行には付けない**）。行は縦の中央にそろえる。
- 掲示板の高さ（幅 390 で **196.7**）= 16 ＋ 見出し行 31.1 ＋ 行 48.2 ＋ 48.2 ＋ 47.2 ＋ 6。
- 読み上げ: `Semantics(label: '締切の表示例', excludeSemantics: true)`（例の表なので、中身は読まない）。

### 4.5 区画の見出しと、PROBLEM 01 ・ FLOW ・ PROBLEM 02

**区画の見出し（`WelcomeSectionTitle`）**: `WelcomeWrap`。上から: 英字（eyebrow）→ 見出し（上 4）→ 説明文（任意。上 10・最大幅 **672**（42em））。見出し全体は `Semantics(header: true)`、英字は装飾なので読み上げから外してよい。上の余白と下の余白は、区画ごとに決まる（下の表）。

**縦のリズム**（各区画の部品が、自分の余白を持つ。ページの `Column` には余白の `SizedBox` を挟まない）

| 区画 | 見出しの上 | 見出しの下 | 中身の下 |
|---|---|---|---|
| PROBLEM 01 | 56 | 20 | 56 |
| FLOW | **0**（前の中身の下の 56 がある） | 20 | 56 |
| PROBLEM 02 | **0** | 20 | 56 |
| SOLUTION（黒い帯） | 上 44 | | 下 36（帯の中） |
| FAQ | 56 | 20 | 56 |

**困りごとのカード**（PROBLEM 01 と PROBLEM 02。キー `welcome_problem1_1`〜`3`・`welcome_problem2_1`〜`3`）
- 地は白（`surface`）・枠 2px ink・内側の余白 **20**（四方）・角丸なし。**硬い影 5px**（`offset: Offset(5, 5)`、PROBLEM 01 は ink、**PROBLEM 02 は桃（hall6）**）。
- 中身: 題（「」で囲む。19・700・行の高さ 1.5）、説明（上 10・14.5）。
- 並び: 幅 761 以上は **3列**（`WelcomeGrid`・隙間 16。同じ行の高さをそろえる）、760 以下は **1列**（間 16）。**影が列の右・下に 5px はみ出す**ので、はみ出しを切らない（外側に `Clip` を付けない）。
- 高さ（参考）: 幅 1000 で 6枚とも 184.9。幅 390 で 131.8 / 156.4 / 131.8（PROBLEM 01）、156.4 / 131.8 / 131.8（PROBLEM 02）。

**期限の流れ（FLOW。キー `welcome_term_1`〜`3`）**: 全体を、地は白・枠 2px ink の箱にする（`welcome_flow`）。中に3つの区画。
- 各区画: 内側の余白 **20**。上から、札（申込=hall1 ／ 当落=hall3 ／ 入金=hall4。左右 12・上下 2・文字 13 の**横に伸びない**箱）、小見出し（上 10・下 6・20）、説明（14.5）。
- 区切り: 幅 761 以上は**3列**（`IntrinsicHeight(Row)` ＋ `Expanded`。区画の高さをそろえる）で、1つ目と2つ目の**右に 2px の線**。幅 760 以下は**縦に積み**、1つ目と2つ目の**下に 2px の線**。
- **矢印（円）**: 直径 **32** の墨の円、中に黄色の「→」（16・700）。区切りの線の**中央に重ねる**。3列のときは「→」、縦のときは「↓」。
  - **矢印は、前の区画ではなく、次の区画（2つ目・3つ目）の側に置く**。後から描かれるほうに置くと、前の区画の地に隠れない（CSS の `z-index: 2` の代わり）。区画を `Stack(clipBehavior: Clip.none)` にし、はみ出しを切らない（枠・`IntrinsicHeight` の外側に `Clip` を付けない）。
  - 3列: `Positioned(left: -17, top: 0, bottom: 0, width: 32, child: Center(円))`（円の中心が、区画の左端の 1px 外＝線の中央）。
  - 縦: `Positioned(left: 24, top: -17, width: 32, height: 32, child: 円)`（円の中心が、区画の上端の 1px 外＝線の中央）。
  - 読み上げから外す（`ExcludeSemantics`）。
- 高さ（参考）: 幅 1000 で枠が 196（区画 192）。幅 390 で枠が 510.1（区画 169.4 / 169.4 / 167.4）。

### 4.6 SOLUTION の黒い帯と、6つのハコ

**黒い帯（`WelcomeSolutionBand`。キー `welcome_solution`）**: 全幅・地は墨（ink）・上 **44** / 下 **36**。中は `WelcomeWrap`。上から: 英字「SOLUTION」（黄・12・800・字間 1.92）、見出し「そんなお悩みを、**おしあし**が解決します。」（上 6。「おしあし」だけ蛍光ペン（赤）。`Semantics(header: true)`）、説明「おしあしでできる、6つのこと。」（上 10・16・onInkSub）。高さ: 幅 390 で 216.4、幅 1000 で 196.8。

**6つのハコ（`WelcomeTileGrid`。キー `welcome_hall_1`〜`6`）**: 黒い帯のすぐ下。**全幅・隙間なし**（`WelcomeWrap` で包まない。幅 1440 でも3列で全幅に広がる）。列の数は 4.3 の表。同じ行のハコは高さをそろえる（`WelcomeGrid`）。

各ハコ:
- 地の色は、上から順に hall1（赤）・hall2（橙）・hall3（黄）・hall4（緑）・hall5（青）・hall6（桃）。**文字は墨だけ**。
- 内側の余白: 上 22・左右 22・**下は幅 761 以上で 76、760 以下で 64**。最小の高さは幅 761 以上で **260**（760 以下はなし）。
- 上の行: 左に「HALL 01」、右に「FOLLOW」（`spaceBetween`・12・800・字間 1.68・en）。狭くて入らないときは、右が次の行に折り返してよい（`Wrap`）。装飾なので読み上げから外す。
- 題（`Semantics(header: true)`）: 上 10・下 8。説明: 14.5・行の高さ 1.75。
- **大きな番号**「01」〜「06」: ハコの**右下**。`Positioned(right: 10, bottom: -14)`（下に 14 はみ出す）、大きさは幅 761 以上で 92・760 以下で 72、900・行の高さ 1・黒の 12%。**ハコからはみ出した分は切る**（`Stack(clipBehavior: Clip.hardEdge)`）。題・説明より**後ろ**に描く（題・説明の文字が番号の上に出る）。`IgnorePointer`・`ExcludeSemantics`。ArchivoHako は Helvetica Neue より広いので、番号は少し横に広くなる。**番号の下の端が、ハコの下の端で 1〜2px 切れて見える**ところまで、参照画像（`c3_640_tiles.png`）に合わせる。
- 高さ（参考・幅 1000）: 6つとも 260。幅 761: 1行目 271.9、2行目 267.6（説明の折り返しで決まる）。幅 390（1列）: 203.7 ずつ。幅 640（2列）: 229.1 / 203.7 / 229.1。

### 4.7 FAQ

**FAQ の区画（`WelcomeFaqSection`。キー `welcome_faq`）**: 区画の見出し（英字「FAQ」・見出し「よくある質問」・説明なし）→ 4つの開閉。`WelcomeWrap`。見出しの上 56 / 下 20、中身の下 56。

**開閉の1項目**（HTML の `<details>`）:
- 上下の余白 **14**。下に **2px の ink の線**。**1つ目だけ、上にも 2px の線**。
- 見出しの行（これが押せる範囲。`InkWell`。キー `welcome_faq_1`〜`4` を**押せる部品自身**に付ける）: 左に質問（16.5・700）、右に「＋」（開いたら「−」（U+2212）。22・行の高さ 1）。間 12・`spaceBetween`。**行の高さ（余白込み）は、質問が1行で 58**（28.05 ＋ 14 × 2 ＋ 線 2）。
- 答え: 開いたときだけ、見出しの行の下に出す（上 8・15・最大幅 **630**（42em））。**動きは付けない**（HTML も一瞬で切り替わる）。
- 開閉は**項目ごとに独立**（1つ開けても、ほかは閉じない。HTML の `<details>` と同じ。5.8）。初めは全部閉じている。
- 読み上げ: `Semantics(button: true, expanded: 開いているか)`。質問の文字がそのままラベルになるようにする。キーボードで開閉できる（`InkWell` はフォーカスできる。フォーカスが見えること）。
- 状態は、項目ごとの小さな `StatefulWidget`（`bool _open`）で持つ。`Provider` は使わない。
- 高さ（参考）: 幅 1000 で 全体 234.2（閉じた項目 58〜60）。幅 390 で 290.3。

### 4.8 CTA（「始める」の区画）

**黒い帯（`_Cta`・`welcome_page.dart` の中。キー `welcome_cta`）**: 全幅・地は墨・上 **40** / 下 **56**（＋画面下の安全な余白）。中は `WelcomeWrap`。上から:
1. 見出し「まずは、推しをひとり。」（白。`Semantics(header: true)`）
2. 説明「新規登録して、推しをフォローするところから始めましょう。」（上 8・15・onInkSub）
3. ボタン（上 **24**）
4. 注記「新規登録・ログインの画面に進みます。」（上 16・13・`WelcomeColors.muted`。キー `welcome_cta_note`）

**ボタン（キー `welcome_start_button`。押せる部品 `InkWell` 自身に付ける）**: 全幅・**地は黄（hall3）・角丸なし・枠なし**・**硬い影 6px の赤（hall1）**（`BoxShadow(color: hall1, offset: Offset(6, 6), blurRadius: 0)`）。内側の余白は 上下 20・左右 24。左に「おしあしを始める」（26。幅 520 以下は 21。700・ink）、右に「→」（32・700）。`spaceBetween`・縦は中央。**ボタンの高さは 94.4**（「→」の行 32 × 1.7 = 54.4 ＋ 上下 20 × 2。幅が変わっても同じ）。押したら `context.go('/login?mode=signup')`。
- 押したときの波紋は墨の 10%（`InkWell` の `splashColor`・`highlightColor`）。
- **フォーカスが見えること**: フォーカス中は、ボタンの上に青（hall5）の 4px の枠を重ねる（`DecoratedBox` の `position: DecorationPosition.foreground`。**大きさが変わらない**ように、枠は内側に描く）。キーボードの Tab で止まれる。
- 読み上げ: ボタンのラベルは「おしあしを始める」（「→」は `ExcludeSemantics`）。

### 4.9 読み上げ・キー・動き・はみ出し

- **動きは無い**（5.5）。`AnimationController` を使わない。
- 押せるものは、高さ 44 以上（「ログイン」44・FAQ の行 58・ボタン 94）。キーボードで操作でき、フォーカスが見える。
- 見出しは `Semantics(header: true)`（h1・各区画の h2・ハコの題・CTA の見出し）。装飾（英字・番号・矢印・影・蛍光ペン）は読み上げない。
- **幅 320・360・390・430・520・521・760・761・1000・1440 で、はみ出さない**（`takeException` が null）。横スクロールが出ない。
- 文字の大きさを OS の設定で 1.3 倍にしても、崩れて読めなくならない（折り返す）。ハコ・カード・期限の区画は、中身に合わせて高くなる。
- **キー（残す）**: `welcome_page`・`welcome_login_button`・`welcome_start_button`・`welcome_board`・`welcome_hall_1`〜`6`・`welcome_cta_note`。
- **キー（新しい）**: `welcome_h1`・`welcome_lead`・`welcome_problem1_1`〜`3`・`welcome_flow`・`welcome_term_1`〜`3`・`welcome_problem2_1`〜`3`・`welcome_solution`・`welcome_faq`・`welcome_faq_1`〜`4`・`welcome_cta`。
- **キー（なくなる）**: `hako_column`（`HakoPage` を使わないため）。

### 4.10 文言（HTML のとおり。コピーして使う）

- **全角にするところ**（5.7）: HTML は半角の `?` と `( )` だが、アプリの日本語は全角（`？`・`（ ）`）なので、全角にする。そのほかの文字・句読点は、HTML のまま変えない。
- 「」は `<q>` が自動で付けるもの。文字列に含める。

| 場所 | 文言 |
|---|---|
| ヘッダー | おしあし ／ ログイン |
| 見出し | 推し活の予定を、 ／ もう逃さない。 |
| リード文 | 推し活の締切をひとつの掲示板にまとめて、次にやることを、ひと目で確認できるアプリです。 |
| 掲示板の見出し | NEXT 締切 ／ 直近の締切（表示例） |
| 掲示板の行（架空。実在の名前に変えない） | 11.20 入金 「ひかりの夜」東京公演 ／ 11.24 申込 「ミナト・ツアー」大阪 ／ 11.30 当落 「ひかりの夜」追加公演 |
| PROBLEM 01 | PROBLEM 01 ／ こんな「うっかり」、ありませんか？ ／ 推し活は楽しい分、気をつけることがたくさん。おしあしは、その「うっかり」を減らすためのアプリです。 |
| 困りごと1 | 「申込期限、いつだっけ？」 ／ 公式サイト、SNS、メール。告知があちこちにあって、期限を見落としてしまう。 |
| 困りごと2 | 「当選したのに、入金を忘れた」 ／ 当落発表のあとには入金期限があります。過ぎてしまうと、せっかくの当選が無効になることも。 |
| 困りごと3 | 「ライブが増えて、整理できない」 ／ 追いかける推しが増えるほど、日程も期限も増えて、頭の中だけでは管理しきれない。 |
| FLOW | FLOW ／ チケットの期限は、この順番で管理していきます ／ はじめての方も安心。申込・当落・入金、それぞれの意味から説明します。 |
| 期限1 | 申込 ／ 申し込む ／ チケットの抽選などに申し込める期間。この期限を過ぎると、そもそも参加できません。 |
| 期限2 | 当落 ／ 結果を待つ ／ 当選か落選かが発表される日。発表の時間も、ライブごとに違います。 |
| 期限3 | 入金 ／ 支払う ／ 当選したあと、チケット代を支払う期限。ここを過ぎると、当選が取り消されることがあります。 |
| PROBLEM 02 | PROBLEM 02 ／ ライブ本番の前に、こんなことありませんか？ ／ チケットが取れても、推し活の悩みはまだあります。ライブの日が近づくほど気になるのが、グッズのこと。 |
| グッズの困りごと1 | 「推しのグッズ、手に入らなかった」 ／ 欲しかったグッズが売り切れていた、買いに行けなかった。ライブまでに何とか手に入れたい。 |
| グッズの困りごと2 | 「誰かとグッズを交換したい」 ／ 自分が持っているグッズと、欲しいグッズを交換できたら。そう思っても、きっかけがない。 |
| グッズの困りごと3 | 「持っている人が、見つからない」 ／ お目当てのグッズを持っている人を、SNSの投稿から探し回るのは大変で、時間もかかる。 |
| SOLUTION | SOLUTION ／ そんなお悩みを、おしあしが解決します。（「おしあし」が蛍光ペン） ／ おしあしでできる、6つのこと。 |
| ハコ1 | HALL 01 ／ FOLLOW ／ 推しをフォロー ／ 推しを探してフォロー。見つからなければ、追加を申請できます。 |
| ハコ2 | HALL 02 ／ SCAN ／ スクショで読み取り ／ 告知画像やチケットサイトのスクリーンショットから、日程・申込期限・入金期限をAIが読み取ります。 |
| ハコ3 | HALL 03 ／ DUE ／ 次の締切が、ひと目で ／ 申込・当落・入金の期限を並べて表示。次にやることが分かります。 |
| ハコ4 | HALL 04 ／ SHARE ／ みんなで共有 ／ 同じ推しのファンが登録したライブを、自分の一覧に追加できます。 |
| ハコ5 | HALL 05 ／ CALENDAR ／ Google カレンダーに追加 ／ 登録した予定を、Google カレンダーにも追加できます。 |
| ハコ6 | HALL 06 ／ TRADE ／ グッズ交換 ／ 手放したいグッズは「譲」、探しているグッズは「求」として登録。交換できる相手が見つかります。 |
| FAQ | FAQ ／ よくある質問 |
| FAQ 1 | スクショは、どんな画像を選べばいいですか？ ／ 公演名・日程・申込期間・入金期限などが写っている、告知画像やチケットサイトの画面です。登録する前に、読み取り結果を必ず確認してください。 |
| FAQ 2 | フォローしたい推しが見つからないときは？ ／ 追加の申請を送れます。 |
| FAQ 3 | 「譲」「求」って何ですか？ ／ グッズ交換で使う、ファンの間の言葉です。手放したいグッズは「譲」、探しているグッズは「求」として登録します。 |
| FAQ 4 | ほかのファンが登録したライブは、どう使えますか？ ／ 同じ推しをフォローしているファンが登録したライブを、自分の一覧に追加できます。自分で入力する手間が省けます。 |
| CTA | まずは、推しをひとり。 ／ 新規登録して、推しをフォローするところから始めましょう。 ／ おしあしを始める → ／ 新規登録・ログインの画面に進みます。 |

- **出さないもの**: 「案C 改」、「おしあし — ログイン前画面 文言案」、案6の文言（「TODAY'S 締切」「6つのハコ、まとめて入場。」「申込、当落、入金。ばらばらの締切を…」）。

### 4.11 縦の位置の早見表（ページの上端から。バッジを除いた値）

幅 390 と 1000 で、区画がどこから始まり、どれだけの高さか（修正版 HTML を BIZ UDPGothic で描いて測った）。**幅 390 で区画の高さが ±8px 以内なら合格**（文字の描画・折り返しの差は許す）。

| 区画 | 幅 390: 上端 | 高さ | 幅 1000: 上端 | 高さ |
|---|---|---|---|---|
| ヘッダー | 0 | 79 | 0 | 79 |
| 最初の画面（見出し〜掲示板） | 79 | 499.3 | 79 | 537.6 |
| 　見出し（h1） | 135 | 96 | 135 | 163.2 |
| 　リード文 | 255 | 86.7 | 322.2 | 57.8 |
| 　掲示板 | 373.7 | 196.7 | 412 | 196.7 |
| PROBLEM 01 の見出し | 578.3 | 262.1 | 616.6 | 213.4 |
| 　困りごとの1枚目 | 840.5 | 131.8 | 830 | 184.9 |
| FLOW の見出し | 1348.4 | 179 | 1070.9 | 130.2 |
| 　期限の流れの枠 | 1527.4 | 510.1 | 1201.1 | 196 |
| PROBLEM 02 の見出し | 2093.5 | 206.1 | 1453.1 | 157.4 |
| 　グッズの困りごとの1枚目 | 2299.7 | 156.4 | 1610.4 | 184.9 |
| SOLUTION の黒い帯 | 2807.6 | 216.4 | 1851.4 | 196.8 |
| 6つのハコの格子（全体） | 3024 | 1222.4 | 2048.1 | 520 |
| FAQ の見出し | 4246.4 | 135.5 | 2568.1 | 149 |
| FAQ（全体） | 4381.9 | 290.3 | 2717.1 | 234.2 |
| CTA の黒い帯 | 4728.2 | 342.3 | 3007.3 | 328 |
| 　ボタン | 4882 | 94.4 | 3146.8 | 94.4 |
| ページの終わり | 5070.5 | | 3335.3 | |

## 5. 実装前に確かめること（リーダー → ユーザー）

リーダーは、次をまとめて推奨案つきでユーザーに聞き、回答を `notes/判断ログ_A.md` に「紹介ページ（案C 改）」として書いてから、チームメイトを作る。**ユーザーが答えられないときは、推奨案（案A）で進め、進捗ファイルに「推奨案で進めた」と書く。**

| 項目 | 推奨案 | 内容 |
|---|---|---|
| 5.1 HTML の CSS の食い違い（2つ） | 案A: 意図どおりに直した修正版を正にする | 下 |
| 5.2 色の値 | 案A: `BrandColors` をそのまま使う | 下 |
| 5.3 書体 | 案A: BIZ UDPGothic ＋ 同梱の ArchivoHako | 下 |
| 5.4 コントラストの低い2か所 | 案A: 直す | 下 |
| 5.5 動き | 案A: 動きは作らない（HTML のとおり） | 下 |
| 5.6 日本語の折り返し | 案A: Flutter の標準のまま | 下 |
| 5.7 文言の半角・全角 | 案A: 全角にする | 下 |
| 5.8 FAQ の開き方 | 案A: 項目ごとに独立（複数開ける） | 下 |
| 5.9 横山さんへの共有・ブランチの追いつき | マージの前に一声かける・人間が `origin/dev` に追いつく | 下 |

### 5.1 HTML の CSS の食い違い（2つ）

元の HTML は、CSS の書き方の都合で、**宣言した値が効いていない**ところが2つある。どちらも、宣言した値のほうが意図に見える。

1. `header{padding:28px 0 0}` は、同じ要素の `.wrap{padding:0 24px}`（クラスのほうが強い）に負けて、**ヘッダーの上の余白が 0** になっている（見本ではバッジが上にあるので目立たないが、本番ではバッジが無く、ロゴが画面の上端に付く）。
2. 幅 520px 以下の `@media` の `.wrap{padding:0 18px}` が、`.hero`・`.sec-title` の**上下の余白（56・20 など）まで 0 にしてしまう**。スマホでは、見出しがヘッダーに、「PROBLEM 01」が掲示板に、カードが説明文にくっつく（`shots/c3_orig_390_top.png`）。幅 521 以上は意図どおり。

- **案A（推奨）**: ヘッダーの上の余白は 28、幅 520 以下でも上下の余白は変えず左右だけ 18。修正版 HTML（`oshiashi_C_v3_fixed.html`）のとおり。本計画書の数値（4.3〜4.11）はこちら。
- 案B: 元の HTML の描画のとおり（ヘッダーの上の余白 0、幅 520 以下で縦の余白が 0）。スマホで詰まって見える。選ばれたら、4.3〜4.11 の数値のうち、ヘッダー・各区画の上下の余白を `c3_orig_390_top.png` と元の HTML に合わせて読み替える（リーダーが追記する）。

### 5.2 色の値

HTML の色は、`BrandColors` の色に近いが、同じではない（差は最大 3/255。4.1 の表）。
- **案A（推奨）**: `BrandColors` をそのまま使う。見分けはつかない。ほかの画面と色がそろう。
- 案B: 紹介ページだけ HTML の値を使う（`WelcomeColors` に足す）。色が二重になるので非推奨。
- 案C: `BrandColors` を HTML の値に入れ替える。ログイン・ログイン後の画面の色まで変わるので、共有の土台を変える（横山さんに共有が要る）。非推奨。

### 5.3 書体

HTML の書体（Hiragino Sans など・Helvetica Neue）は Flutter Web では使えない。
- **案A（推奨）**: 日本語は BIZ UDPGothic（`HakoFonts.jp`。800 は 700 で代用）、英字・数字は同梱の ArchivoHako（`HakoFonts.en`）。案6・ログインと同じ書体で、ネットが無くても英字は出る。数字・英字は Helvetica Neue より横に広い。
- 案B: 大きな番号と日付だけ、標準の幅の Archivo（`GoogleFonts.archivo`。`HakoFonts.num` に近い）。HTML に近いが、`hako_fonts.dart`（共有）に手を入れるか、紹介ページの中で `google_fonts` を直接呼ぶ必要があり、「書体は `HakoFonts` を通す」の原則から外れる。
- BIZ UDPGothic の読み込みの重さ（400 と 700 で合計 約 8MB）は、案6のときに判断済み（方針A: そのまま）。**今回は新しい書体を足さないので、重さは増えない**。ただし、ページが長くなる分、文字が置き換わるまでの見え方を、12.1 の 7 で人が確かめる。

### 5.4 コントラストの低い2か所

- 見出しの上の小さな英字「PROBLEM 01」など: HTML は `#777`（紙の上で **4.15:1**。12px の細かい字としては足りない）。**案A（推奨）: `#6B6B6B`（4.94:1）**。案B: HTML のまま。
- 「申込」の札（赤の地）の文字: HTML は白（**3.95:1**）。**案A（推奨）: 墨（4.74:1）**。案B: HTML のまま。

### 5.5 動き

HTML に動きは無い。案6の「始める」ボタンの nudge（ゆっくり左上へ動いてもどる）は、HTML に無い。
- **案A（推奨）**: 動きは作らない（HTML のとおり。「動きを減らす」の対応も要らなくなり、テストが簡単になる）。
- 案B: nudge を残す（案6の `_StartButton` の動きを移す。「動きを減らす」で止める。テストは動きを切る）。

### 5.6 日本語の折り返し

HTML は `word-break: auto-phrase`（文節で折り返す）・`text-wrap: pretty` で、見出しや説明が文節できれいに折り返す。Flutter には文節での折り返しが無く、**文字の間で折り返す**（句読点・閉じ括弧は行頭に来ない）。幅の狭い画面で、見出しの1文字だけが次の行に落ちることがある。
- **案A（推奨）**: そのまま（Flutter の標準）。見えて気になる箇所は、人間の確認（12.1）で挙げてもらい、その見出しだけ、あとで別の指示で直す。
- 案B: 文節ごとに手で区切る補助を作る（全文言の区切りを決める必要があり、時間がかかる。今回は非推奨）。**依存パッケージは足さない。**

### 5.7 文言の半角・全角

HTML は `?`・`( )` が半角。アプリの日本語は全角の `？` を使っている（半角は 0 か所）。
- **案A（推奨）**: 全角（`？`・`（表示例）`）にする。4.10 は全角で書いてある。
- 案B: HTML のとおり半角。

### 5.8 FAQ の開き方

- **案A（推奨）**: 項目ごとに独立（1つ開けても、ほかは閉じない。HTML の `<details>` と同じ）。
- 案B: 1つだけ開く（アコーディオン）。

### 5.9 横山さんへの共有・ブランチの追いつき

次は、横山さんが作った部分を作り直す。マージの前に一声かける。
- `lib/features/welcome/welcome_page.dart`（紹介ページ。作り直し）、`lib/features/welcome/` の新しいファイル、`test/features/welcome_page_test.dart`（書き直し）

共有の土台（`lib/theme/**`・`pubspec.yaml`・`lib/app.dart`・ログイン系）は、**変えない**ので、共有は上の範囲だけ。
`redesign/before_login` は `origin/dev` より 5 コミット古い。PR の前に、人間が `git merge origin/dev` で追いつく（紹介ページは `dev` 側で変わっていないので、衝突しにくい）。

## 6. 担当とファイル

同じファイルを2人が同時に編集すると上書きが起きる。**担当外のファイルは編集せず、担当者に SendMessage で依頼する。**

| 担当 | 名前 | 編集してよいファイル |
|---|---|---|
| リーダー | （メインセッション） | この計画書、`notes/判断ログ_A.md`、`notes/before_login_c_進捗.md` |
| 画面（枠・最初の画面・CTA） | `ui-top` | `lib/features/welcome/welcome_layout.dart`（新規）、`lib/features/welcome/welcome_page.dart`。**W1 で、`welcome_story.dart`・`welcome_features.dart` の「空の入れ物」（7章の名前・引数で、`SizedBox.shrink()` を返すだけ）を作り、`ui-body` に渡す。渡したあとは編集しない** |
| 画面（中の区画） | `ui-body` | `lib/features/welcome/welcome_story.dart`（新規。PROBLEM 01・FLOW・PROBLEM 02・SOLUTION の黒い帯）、`lib/features/welcome/welcome_features.dart`（新規。6つのハコ・FAQ） |
| テスト・レビュー | `qa` | `test/features/welcome_page_test.dart`（書き直し）、`test/features/welcome_layout_test.dart`・`test/features/welcome_sections_test.dart`（新規）、`notes/before_login_c_レビュー記録.md`（新規） |

- **読むだけ（変更禁止）**: `lib/theme/**`、`lib/app.dart`、`lib/features/auth/**`、`lib/repositories/**`・`utils/**`・`providers/**`・`services/**`、`web/**`、`pubspec.yaml`、`assets/**`、`firestore.rules`、ログイン後の画面。**ロジック・共有の差分が出ていないことは、`git diff --stat` で確かめる**（変更が許されるのは `lib/features/welcome/**` と `test/features/welcome_*` だけ）。
- 共有の部品（`HakoPill`・`BrandColors`・`HakoFonts` など）で足りないことが出たら、**自分で直さず**、リーダーに報告する（紹介ページの中に作って済ませる）。
- `welcome_layout.dart` に足したい・直したいことが出たら、`ui-body` と `qa` は `ui-top` に SendMessage で頼む。
- **依存パッケージは足さない。** 画像・書体ファイルを足さない。

## 7. 契約（インターフェース）

`ui-top` が最初のタスク（W1）で確定させ、`ui-body` と `qa` に SendMessage で全文を送る。以下は叩き台（名前と引数は、ここから変えるときだけ連絡する）。

```dart
// lib/features/welcome/welcome_layout.dart
import 'package:flutter/material.dart';

/// 幅の区切り（CSS の @media (max-width: …) と同じ。MediaQuery の幅で決める）
abstract final class WelcomeBreakpoints {
  static const double tablet = 760; // 以下: ハコ 2 列・困りごと/期限の流れは 1 列
  static const double phone = 520; // 以下: ハコ 1 列・左右の余白 18・ボタンの文字 21
  static bool isStacked(double width) => width <= tablet; // 困りごと・期限の流れを縦に積む
  static bool isPhone(double width) => width <= phone;
  static int tileColumns(double width) => width <= phone ? 1 : (width <= tablet ? 2 : 3);
}

/// 紹介ページの中だけで使う色（BrandColors に無いもの）
abstract final class WelcomeColors {
  static const eyebrow = Color(0xFF6B6B6B); // 見出しの上の英字（紙の上）
  static const rule = Color(0xFF444444); // 掲示板の見出しの下線
  static const muted = Color(0xFFAAAAAA); // 黒い区画の小さな補足
}

/// CSS の clamp(min, vw, max)
double welcomeClamp(double width, {required double min, required double vw, required double max}) =>
    (width * vw / 100).clamp(min, max).toDouble();

/// HakoFonts.jp / en を、行の高さの既定 1.7 で呼ぶ（HTML の body の line-height）
TextStyle welcomeJp({required double size, FontWeight weight = FontWeight.w400,
    Color color = BrandColors.ink, double height = 1.7, double letterSpacing = 0});
TextStyle welcomeEn({required double size, FontWeight weight = FontWeight.w800,
    Color color = BrandColors.ink, double height = 1.7, double letterSpacing = 0});

/// .wrap: 最大幅 960（左右の余白込み）・中央・左右の余白 24（幅 520 以下は 18）
class WelcomeWrap extends StatelessWidget {
  const WelcomeWrap({super.key, required this.child});
  final Widget child;
}

/// 区画の見出し（英字・見出し・説明）。h2 は Semantics(header: true)。
/// topPadding / bottomPadding は 4.5 の表の値を呼ぶ側が渡す（SOLUTION の黒い帯は蛍光ペンがあるので、これを使わず WelcomeSolutionBand が自分で組む）
class WelcomeSectionTitle extends StatelessWidget {
  const WelcomeSectionTitle({super.key, required this.eyebrow, required this.title,
      this.body, this.topPadding = 56, this.bottomPadding = 20});
  final String eyebrow;
  final String title;
  final String? body;
  final double topPadding;
  final double bottomPadding;
}

/// 蛍光ペン（4.2）。text に style で文字、color で帯の色。lineHeight は style.height と同じ値
class WelcomeMark extends StatelessWidget {
  const WelcomeMark({super.key, required this.text, required this.style, required this.color});
  final String text;
  final TextStyle style; // fontSize・height を持つこと
  final Color color;
}

/// 同じ行の高さをそろえる格子（4.3）。cellBuilder は index を受け取る
class WelcomeGrid extends StatelessWidget {
  const WelcomeGrid({super.key, required this.columns, required this.itemCount,
      required this.itemBuilder, this.gap = 0});
  final int columns;
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double gap; // 列の間・行の間
}

/// 色つきの全幅の帯（黒い帯）。中身は呼ぶ側が WelcomeWrap で包む
class WelcomeBand extends StatelessWidget {
  const WelcomeBand({super.key, required this.color, required this.padding, required this.child});
  final Color color;
  final EdgeInsetsGeometry padding;
  final Widget child;
}

// lib/features/welcome/welcome_story.dart（ui-body）
class WelcomeProblemSection extends StatelessWidget { const WelcomeProblemSection({super.key}); } // PROBLEM 01（見出し＋カード3枚。下 56 まで）
class WelcomeFlowSection extends StatelessWidget { const WelcomeFlowSection({super.key}); }       // FLOW（見出しの上 0）
class WelcomeGoodsProblemSection extends StatelessWidget { const WelcomeGoodsProblemSection({super.key}); } // PROBLEM 02（見出しの上 0・影は桃）
class WelcomeSolutionBand extends StatelessWidget { const WelcomeSolutionBand({super.key}); }     // SOLUTION の黒い帯

// lib/features/welcome/welcome_features.dart（ui-body）
class WelcomeTileGrid extends StatelessWidget { const WelcomeTileGrid({super.key}); }   // 6つのハコ（全幅）
class WelcomeFaqSection extends StatelessWidget { const WelcomeFaqSection({super.key}); } // FAQ（見出しの上 56・下 56）

// lib/features/welcome/welcome_page.dart（ui-top）
class WelcomePage extends StatelessWidget { const WelcomePage({super.key}); }
// 中の並び: _Header → _Hero（見出し・リード・掲示板）→ WelcomeProblemSection → WelcomeFlowSection
//   → WelcomeGoodsProblemSection → WelcomeSolutionBand → WelcomeTileGrid → WelcomeFaqSection → _Cta
```

- キーは 4.9 のとおり。**タップを受ける部品自身**に付ける（`HakoPill`・FAQ の `InkWell`・ボタンの `InkWell`）。
- 区画の文言は、各区画の部品が持つ（`const` の一覧）。4.10 をコピーする。

## 8. 既存のテストの扱いと、足すテスト

- **ロジックは変わらない**。「始める」→ `/login?mode=signup`、「ログイン」→ `/login` のテストは、そのまま通るはず（通らないなら、まず実装のバグを疑う）。`pumpWelcome` の道具（`GoRouter` で `/welcome` と `/login` を用意）も使い回す。
- **書き直すテスト**（デザインと文言が変わるため。消して通すのではなく、新しい仕様に合わせて書き直す）:
  - `hako_column` を見ているもの（紹介ページから無くなる。代わりに `welcome_page` を見る）
  - 6つのハコの題・説明（**文言が変わった**: 「スクショから読み取り」→「スクショで読み取り」など。4.10）
  - 最初の画面（リード文が変わった）、掲示板（見出しが「NEXT 締切」になった）、「始める」の上の「6つのハコ、まとめて入場。」（無くなった）
  - 幅ごとの余白（20/40/64・最大 1100 → **24（幅 520 以下は 18）・最大 960**）と、ハコの列の数（幅 600 で3列 → **761 以上 3列・521〜760 で 2列・520 以下 1列**）
  - 「動きを切ると `pumpAndSettle` が終わる」は、動きが無くなるので `hasRunningAnimations` が false であることを見るだけに簡単にしてよい（5.5 で案B なら今のまま）。`accessibilityFeaturesTestValue` の `setUp` は、案A では要らない（あっても害は無い）。
- **テストの書き方の約束**:
  - **キーは、タップを受ける部品自身**に付ける（`HakoPill`・FAQ の `InkWell`・ボタンの `InkWell`）。押す前に `tester.ensureVisible`。
  - 書体は `test/flutter_test_config.dart` が、取りに行かない設定にしてくれる。**例外が出るなら書体を変えて回避しない**（リーダーに報告）。
  - 画面の大きさは `tester.view.physicalSize` と `devicePixelRatio = 1`（終わりに `addTearDown(tester.view.reset)`）。文字の拡大は `tester.platformDispatcher.textScaleFactorTestValue = 1.3`（終わりに `clearTextScaleFactorTestValue`）。
  - テストを消したり、期待を弱めたりして通さない（CLAUDE.md の完了の条件）。画面の書き直しを始める前に、担当の `ui-*` は qa に「テスト更新依頼: <タスクID>、変わる振る舞い、落ちるはずのテスト」を送る。

**足すテスト（qa）**

- 共通部品（`welcome_layout_test.dart`）: `WelcomeBreakpoints.tileColumns` が幅 320・520・521・760・761・1440 で 1・1・2・2・3・3、`welcomeClamp`（幅 390・640・850 で `8vw` が 40・51.2・68）、`WelcomeWrap` の中身の幅（幅 1440 で 912・幅 390 で 354・幅 600 で 552）、`WelcomeGrid`（同じ行の高さがそろう・列の数・隙間）、`WelcomeMark`（描いても例外が出ない・帯が文字の下 20%）
- 区画（`welcome_sections_test.dart`）: 困りごと（3枚ずつ。幅 1000 で横3列・幅 390 で縦1列。影の色が PROBLEM 01 は墨・PROBLEM 02 は桃）、期限の流れ（幅 1000 で横3列・矢印2つ・幅 390 で縦に積む）、SOLUTION（見出し・説明）、6つのハコ（番号 01〜06・色の順・幅 1440 で各 480・幅 640 で 320・幅 390 で 390・幅 1000 で最小の高さ 260）、FAQ（最初は答えが出ない・押すと出る・もう一度押すと消える・項目が独立・`Semantics` の `expanded`）
- 紹介ページ（`welcome_page_test.dart`）: 4.10 の文言がすべて出る（FAQ の答えは開いてから）・**出さないもの**（「案C 改」・「文言案」・「TODAY'S 締切」・「6つのハコ、まとめて入場。」・`hako_column`・`Image`）・「始める」と「ログイン」の行き先・見出しの大きさ（幅 390 で 40・幅 1000 で 68）・掲示板の幅（幅 1000 以上で 912）・どの幅（320・360・390・430・520・521・760・761・1000・1440）でも例外が出ない（文字 1.0 倍と 1.3 倍）・横スクロールが出ない・動きが無い

## 9. タスク一覧

リーダーが共有タスクリストに、担当と依存関係を付けて登録する。

| ID | 担当 | 内容 | 依存 |
|---|---|---|---|
| L0 | リーダー | 0章の確認、5章をユーザーに聞く、判断ログ | |
| T0 | qa | 品質ゲートの確認（`flutter analyze`・`flutter test`・ルールのテスト）。今の紹介ページのテストのうち、変わるものの一覧（8章）をリーダーに送る | |
| W1 | ui-top | `welcome_layout.dart`（4.2・4.3・7章）と、`welcome_story.dart`・`welcome_features.dart` の空の入れ物。契約を ui-body と qa に送る。方針をリーダーへ送り、返事を待たずに進める | L0 |
| W2 | ui-top | `welcome_page.dart` の作り直し: ページの枠・ヘッダー・最初の画面・掲示板（4.3・4.4）。区画は ui-body の入れ物を並べる。旧い区画（`_Hall*`・`_Wide`・`_StartButton`）は、置き換えたら消す。**先に qa へテスト更新依頼** | W1 |
| W3 | ui-top | CTA（4.8） | W2 |
| B1 | ui-body | `welcome_story.dart`: PROBLEM 01・FLOW・PROBLEM 02・SOLUTION の黒い帯（4.5・4.6 の前半） | W1 |
| B2 | ui-body | `welcome_features.dart`: 6つのハコ（4.6）・FAQ（4.7） | W1 |
| Q1 | qa | 共通部品のテスト（8章） | W1 |
| Q2 | qa | 区画のテスト | B1, B2 |
| Q3 | qa | 紹介ページのテストの書き直しと追加 | W2, W3, B1, B2 |
| C1 | ui-top | 掃除: 使われなくなったコード・import を消し、`flutter analyze` を0件にする | W3, B1, B2 |
| R1 | qa | まとめレビュー（11章） | すべて |
| L1 | リーダー | 結合確認、`git diff --stat` で共有・ロジックの差分が無いことの確認、ユーザーへの動作確認手順（12章）、判断ログ、コミット案 | すべて |

## 10. バグを防ぐための進め方

1. **担当外のファイルは編集しない。** 直してほしい箇所は担当者に SendMessage で伝える。共有の土台（`lib/theme/**`）は、誰も編集しない。
2. **契約を先に決める。** W1 が終わるまで、ui-body と qa は `welcome_layout.dart` に依存する部分を書かない（4.5〜4.7・4.10 を読み込むのは先に進めてよい）。
3. **各タスクの最初に、方針を3〜5行でリーダーに送る。返事を待たずに書き始める。** （`dev-ui`・`dev-qa` の定義には「返事を待つ」とあるが、**この計画書とチームメイト作成時の指示が優先**する。前回の front1 で、全員が方針の返事を待って止まった反省。）リーダーは、方針に問題があるときだけ返事をする。タスクを終えたら、完了報告を送ったあと、依存が解けている次のタスクへ**すぐに進む**。
4. **作業ツリーを壊れたまま放置しない。** ui-top は、W1 で空の入れ物を先に作り、ui-body が本物に置き換えるまでコンパイルが通る状態を保つ。
5. **品質ゲート:** タスクを完了にするたびに、`.claude/hooks/quality-gate.sh` が `flutter analyze`・`flutter test`・ルールのテストを実行する。失敗すると完了が差し戻される。
6. **見た目は数値で合わせ、画像で確かめる。** 4章の数値と、参照画像（`markdown/design_before_login_c/shots/`）を見比べる。幅 390 で、区画の高さが 4.11 の表と ±8px 以内なら合格（文字の描画・折り返しの差は許す）。Dev Container で画面を撮れるなら撮って比べてよい（撮るための道具をリポジトリの依存に足さない。一時ファイルは `/tmp` に置く）。撮れなければ省略し、最終の見た目の確認は人間が行う（12章）。
7. **実装タスクを終えたら、qa にレビューを依頼する。** qa はレビュー依頼を最優先で処理する。
8. **共有・ロジックを変えない。** `lib/theme/**`・`lib/app.dart`・認証・リポジトリ・`pubspec.yaml` を触らない。紹介ページの中で作って済ませる。
9. **秘密情報を残さない。**
10. **判断を記録する。** 比べた案・選んだ理由・捨てた案は、リーダーが `notes/判断ログ_A.md` に追記する（5章の回答を必ず含める）。

## 11. レビューの観点

- 見た目: 4章の数値どおりか（色・大きさ・余白・字間・行の高さ）。蛍光ペンの位置と色（見出しは黄・SOLUTION は赤）。硬い影（5px と 6px）。大きな番号の位置・切れ方。矢印の円が区切りの線の中央にあるか。6つのハコの高さがそろうか。全幅の黒い帯と格子（幅 1440）
- 書体: `HakoFonts` を通しているか（`GoogleFonts.` の直書きが無いか）。`Text` にテーマの書体が混ざっていないか。**行の高さが 1.7（見出しは 1.2 / 1.35 / 1.4 / 1.3 / 1.5）になっているか**（`HakoFonts` の既定の 1.75 のままになっていないか）。英字が ArchivoHako になっているか
- 幅の区切り: 3つの値（760・520・`clamp`）が `WelcomeBreakpoints` と `welcomeClamp` の1か所にまとまっているか。`LayoutBuilder` の幅ではなく画面の幅で決めているか（ただし格子のセルの幅は `LayoutBuilder`）
- 操作: 押せる範囲が 44 以上か。フォーカスが見えるか（ボタン・FAQ・「ログイン」）。FAQ が独立して開閉するか
- 動き: **動きが無いか**（`AnimationController`・`AnimatedBuilder` が無いか）。ボタンが一瞬で状態を切り替えるか
- 文言: 4.10 と一字一句同じか（全角の `？`・`（表示例）`）。バッジ・「文言案」が出ていないか
- ロジック・共有: **`git diff --stat` で、変わったファイルが `lib/features/welcome/**` と `test/features/welcome_*` と文書だけか**。キーが残っているか
- はみ出し: 幅 320・360・390・430・520・521・760・761・1000・1440・文字 1.3 倍
- テスト: 期待を弱めていないか。新しい部品・区画・紹介ページにテストがあるか
- 旧い部品: `_Hall*`・`_Wide`・`_StartButton`・使われない import が残っていないか
- 横山さんのファイル: 5.9 の範囲の外を変えていないか

## 12. 人が行う設定と動作確認

### 12.0 開始前の準備（L0。リーダーが行う）

1. `git status -sb`（ブランチが `redesign/before_login` か。`behind` が無いか）。
2. 作業ツリーに、この作業と関係のない未コミットのファイル（`.claude/agents/*.md`・`CLAUDE.md`・`.claude/scripts/`・`markdown/design_after_login/`・`Claude outputs/` など）がある。**触らない。コミットに混ぜない**（コミットする前に、リーダーが含めるファイルをユーザーに示す）。
3. 書体・パッケージの準備は要らない（共有の `pubspec.yaml` に ArchivoHako が宣言済み）。

### 12.1 動作確認（人が行う。Dev Container で `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080`、Mac の Chrome で `http://localhost:8080`。ログアウトした状態で紹介ページを開く）

1. Chrome の開発者ツール → 端末のツールバーで幅 **390** にする。**別のタブで `markdown/design_before_login_c/oshiashi_C_v3_fixed.html` を開き、並べて見比べる**（色・文字の大きさ・余白・カードの影・期限の矢印・ハコの高さ・蛍光ペン・大きな番号）。見本の HTML は端末の書体（Mac なら Hiragino Sans）で出るので、文字の形はアプリと少し違う。
2. 上から下まで通して見る: ヘッダー → 見出し・掲示板 → PROBLEM 01 → FLOW（矢印が線の中央か）→ PROBLEM 02（影が桃か）→ SOLUTION → 6つのハコ → FAQ → CTA。バッジ・「文言案」が出ていないこと。
3. 幅を 640（ハコが2列）・1000（3列・中身は最大 960）・1440（ハコが全幅）・320 にして、はみ出さないこと。
4. 「おしあしを始める」→ ログイン画面（**新規登録**の札が選ばれる）。右上の「ログイン」→ ログインの札。「← 戻る」で紹介ページへ。
5. FAQ の4項目を開閉する（マウスとキーボード。複数同時に開ける）。
6. キーボードだけで操作する（Tab で移動し、「ログイン」・FAQ・ボタンでフォーカスが見える）。
7. 書体の読み込み: 開発者ツールの Network で、スロットリングを「Fast 4G」にして、文字が置き換わるまでの時間を見る（ページが長いので、最初の画面が先に出ること）。
8. 日本語の折り返し（5.6）: 見出し・カードの題で、1文字だけ次の行に落ちるなど見苦しい箇所があれば、箇所を挙げる（あとで直す）。
9. 文字の大きさを 1.3 倍にしても崩れない。

## 13. リーダー（メインセッション）の進め方

0. **モデル**: チームメイトは **Sonnet 5.5（`claude-sonnet-5-5`）**。`.claude/agents/*.md` の `model:` と、`.claude/settings.local.json` の `model`（リーダーの既定）に設定済み。起動したとき、違うモデルになっていたら、`/model claude-sonnet-5-5` に切り替えるようユーザーに伝える。
1. この文書と `CLAUDE.md` を読む。リーダーは自分でコードを書かず、調整・タスク管理・ユーザーへの確認に専念する。
2. `git status -sb` で `redesign/before_login` にいて最新であることを確かめる（0章）。
3. `flutter analyze`・`flutter test`・ルールのテストを実行し、品質ゲートが通る状態かを確認する。通らなければ、原因をユーザーに報告して判断を仰ぐ。
4. 5章をまとめてユーザーに聞き、回答を判断ログに書き、5章に結果を書き足す。**確認が済むまでチームメイトは作らない。**
5. チームメイトを3人作る（**モデルは Sonnet 5.5**）。各チームメイトはリーダーの会話履歴を見られないので、作成時の指示に必要なことを書く。
   - `dev-ui` エージェントタイプで、名前 `ui-top`。指示: 「markdown/feature_before_login_c_plan.md を読み、担当 ui-top として W1 から始めて。W1 の方針（3〜5行）を私（リーダー）に送ること（返事を待たずに進めてよい。問題があれば私から連絡する）。契約（7章）は、W1 が終わったら ui-body と qa に全文を送ること。lib/theme/**・ロジック・pubspec.yaml は変えないこと。依存パッケージを足さないこと」
   - `dev-ui` エージェントタイプで、名前 `ui-body`。指示: 「markdown/feature_before_login_c_plan.md を読み、担当 ui-body として、4.5〜4.7 と 4.10 を読み込んでおき、ui-top から W1 の契約が届いたら B1 から始めて。方針は私（リーダー）に送るが、返事を待たずに進めてよい。lib/theme/**・ロジック・pubspec.yaml は変えないこと。依存パッケージを足さないこと。文言は 4.10 のとおり一字一句」
   - `dev-qa` エージェントタイプで、名前 `qa`。指示: 「markdown/feature_before_login_c_plan.md を読み、担当 qa として T0 から始めて。以降はレビュー依頼とテスト更新依頼を最優先に。8章の方針（期待を弱めない・書体を変えて回避しない）を守ること。パッケージを足さないこと」
6. 9章のタスクを共有タスクリストに登録する（担当・依存関係つき）。
7. 進行中は、担当外ファイルの編集・同じファイルの同時編集・契約の食い違い・**共有（`lib/theme/**` など）やロジックのファイルの変更**・**横山さんのファイルへの想定外の変更**・**テストを消して通していないか**・**パッケージや画像の追加**を見張る。ユーザーが決めるべきことは、まとめてユーザーに聞く。**誰も動いていない時間ができたら（全員が返事待ちになる、完了報告のあと止まる、など）、すぐに次の指示を出す。**
8. W2 と B1 の最初の見た目ができたら、**ユーザーに見てもらう**（12.1 の 1〜3・8）。折り返し（5.6）はここで判断を仰ぐ。
9. すべて完了したら L1 を行う。ユーザーに 12章の動作確認手順と、コミット案（メッセージと含めるファイル）を示し、了承を得てからコミットする。含めるのは、`lib/features/welcome/**`・`test/features/welcome_*`・この計画書・`markdown/design_before_login_c/**`・`notes/before_login_c_*`・`notes/判断ログ_A.md`・`CLAUDE.md` の計画書の行。**`CLAUDE.md` の差分には、ログイン後の計画書の行（別の作業）も含まれる**ので、含めるかをユーザーに聞く。`git push`・Pull Request・デプロイはユーザーが行う。
10. 最後にチームメイトを終了させ、チームを片付ける。

## 14. 使用量の上限で止まったときのために

- リーダーは `notes/before_login_c_進捗.md` を、**タスクが1つ終わるたび**に更新する（状態・担当・触ったファイル・次にやること・ユーザーに聞きたいこと）。止まって再開するときは、まずこのファイルを読み、終わったタスクはやり直さない。
- Claude Code が終了してチームメイトがいなくなったら、まだ終わっていないタスクの担当だけを作り直す（13章の指示に「notes/before_login_c_進捗.md を読み、自分の未完了のタスクから再開すること」を足す）。
- 自動で再開させるときは、引数で進捗ファイルと計画書を渡す。
  - 見張り役（tmux）: `bash .claude/scripts/auto-resume.sh <送り先のペイン> notes/before_login_c_進捗.md`
  - 非対話（tmux なし）: `bash .claude/scripts/auto-resume-headless.sh notes/before_login_c_進捗.md markdown/feature_before_login_c_plan.md`
- 使用量を抑えるルール（全員）: メッセージは短く、ファイルの中身やテストの出力を丸ごと貼らない。作業中のテストは関係するファイルだけを実行し、全体は完了時の品質ゲートに任せる。長い出力は末尾だけを見る。計画書は自分に関係する章だけを読み直す。進み具合の確認のためだけのメッセージを送り合わない。
- 許可の確認で止まらないように、シェルのコマンドは1つずつ実行する（`;`・`&&`・`|` でつながない、`$変数` を使わない）。ファイルの読み書き・検索は Read・Edit・Grep などの道具を使う。
