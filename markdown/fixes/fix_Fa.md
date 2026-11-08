# おしあし（仮）Da 後の試験結果の修正方針書（Fa）
 
> 本ドキュメントは、`claude/11-7 Da後の動作試験の結果.md` の「2. 直したほうがよい点」の1〜4と、「色が全体的に気持ち悪い」というユーザーの指摘を直すための方針書である。
> チームメンバーおよび開発支援に使う LLM が、この文書だけを読んで同じ前提で作業できるように、原因・直し方・変えるファイルを具体的に書いている。
> 前提として、`markdown/design_Da.md`（Da の仕様書）・`CLAUDE.md` をあわせて参照すること。
 
## 0. LLM への指示
 
- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。「7. 未決定事項」は独自に確定させず、提案として示すこと。
- 本仕様にない作業を勝手に足さないこと。**テストコードは書かない**（既存のテストが通らなくなっても直さない）。
- **コードの編集は人間が Dev Container 内で行う。** LLM はリポジトリを読むだけにして、変更は「どのファイルの、どこを、どう変えるか」がわかるコードとして提示すること。ファイルや文書を勝手に作ったり書き込んだりしないこと。
- 開発は5章のステップの順に1つずつ進め、各ステップの終わりに `flutter analyze` で `lib/` の指摘が 0 件であることを確認し、1行程度のコミット文を添えること。
- 色は、テーマ（`Theme.of(context).colorScheme`）から取る。画面ごとに色を直書きしない。
## 1. 概要
 
| 項目 | 内容 |
|---|---|
| 名前 | Fa（Da 後の修正）。修正の名前は F（11/7 の最初の試験結果の修正）、Fa、Fb…と続ける |
| 担当 | B（横山）。A（とし）の担当範囲のファイル（3.3）は、着手前に A と共有する |
| ブランチ | 人間が作る |
| 対象 | 色（問題4と「色が気持ち悪い」）、プロフィールの幅（問題1）、ライブ一覧の追加ボタン（問題2）、投稿の対象の推しの初期選択（問題3） |
 
## 2. 原因
 
### 2.1 色
 
今のテーマ（`lib/theme/app_theme.dart`）は、`ColorScheme.fromSeed(seedColor: 選んだ色, dynamicSchemeVariant: fidelity)` の色をそのまま全部に使っている。このため、次のことが起きている。
 
| 症状 | 原因 |
|---|---|
| カード・枠線・区切り線まで、うっすら赤（ピンク）っぽい | 背景・カード・枠線の色（`surface`・`outlineVariant` など）も、選んだ色から作られている |
| 選択中のタブの印が、サーモンピンクで浮いている | タブの印は `secondaryContainer` の色で、選んだ色と少しずれた色になる |
| 右下のボタン（投稿を作るなど）が、ほかのボタンと違う赤になる | 右下のボタンは `primaryContainer`、ほかのボタンは `primary` で、色が違う |
| 黄色を選ぶと、全体が濃いオリーブ色になる（問題4） | ボタンの色（`primary`）は、白い文字が読めるように暗くされる。黄色は暗くするとオリーブ色になる |
 
### 2.2 そのほか
 
| # | 問題 | 原因 |
|---|---|---|
| 1 | プロフィールの入力欄と「保存」が、PC で横幅いっぱいに伸びる | `/profile` は外枠（`AppShell`）の外のルートなので、Da-2 の最大幅が効かない |
| 2 | ライブ一覧に、ライブを追加するボタンが1件以上あると出ない | `live_list_page.dart` の `floatingActionButton` が、0件のときだけ出る作り |
| 3 | 投稿を作る画面で、対象の推しが選ばれていない | 新規作成の下書き（`TradePostDraft`）を空で作っている |
 
## 3. 決定事項
 
### 3.1 色の考え方（Fa-1）
 
**「背景・カード・線は白と灰色だけ。選んだ色は、ボタン・選択中の印・強調だけに使う」**にする。
 
`lib/theme/app_theme.dart` の `buildAppTheme` で、色の表（`ColorScheme`）を3つの材料から組み立てる。
 
| 材料 | 作り方 | 使う場所 |
|---|---|---|
| 色の表 `accent` | `ColorScheme.fromSeed(seedColor: seed, dynamicSchemeVariant: DynamicSchemeVariant.fidelity)`（今と同じ） | 文字・アイコンの強調色（`primary`）。白い背景の上で読める濃さ |
| 灰色の表 `neutral` | `ColorScheme.fromSeed(seedColor: seed, dynamicSchemeVariant: DynamicSchemeVariant.monochrome)` | 背景・カード・枠線・区切り線・普通の文字（色みのない灰色） |
| 塗りの色 `fill` | 選んだ色そのもの（`seed`）。ただし白に近い色（`seed.computeLuminance() > 0.8`）のときは `accent.primary` | ボタンの塗り・右下のボタン・選択中のタブの印・選択中のチップ |
| 塗りの上の文字 `onFill` | `ThemeData.estimateBrightnessForColor(fill)` が暗いなら白、明るいなら黒 | 塗りの上の文字・アイコン |
 
色の表は `accent.copyWith(...)` で次のように上書きする。
 
| 項目 | 値 |
|---|---|
| `surface`・`onSurface`・`onSurfaceVariant`・`surfaceContainerLowest`〜`surfaceContainerHighest`・`outline`・`outlineVariant`・`surfaceTint` | `neutral` の同じ項目 |
| `primaryContainer`・`secondaryContainer` | `fill` |
| `onPrimaryContainer`・`onSecondaryContainer` | `onFill` |
 
テーマには、次を足す（今の Da-1 の設定はそのまま残す）。
 
| 項目 | 設定 |
|---|---|
| `filledButtonTheme` | 背景 `fill`、文字 `onFill`（押せないときは今のまま） |
| `floatingActionButtonTheme` | 背景 `fill`、文字 `onFill` |
 
- これで、赤を選ぶとボタンは選んだ赤そのもの、黄色を選ぶとボタンは黄色に黒い文字になる（問題4）。リンクなどの文字の色（`primary`）は、読める濃さのまま。
- 白を選んだときは、塗りが白だと見えないので、今と同じ濃い灰色を使う。
- Da-4・Da-5 の印（`scheme.primary.withValues(alpha: 0.12)` の背景に `primary` の文字）は変えない。
- 今後のライブのカードの「あと◯日」（`_DaysBadge`）は `primaryContainer` を使っているので、選んだ色の塗りに変わる（強調として合っているので、そのままにする）。
- 色見本（`theme_color_picker.dart`）は変えない。選んだ色が、そのままボタンの色になるため。
### 3.2 プロフィールの幅（Fa-2）
 
`lib/features/profile/profile_page.dart` の編集画面の `ListView` を、`Align(alignment: Alignment.topCenter)` と `ConstrainedBox(constraints: BoxConstraints(maxWidth: 600))` で包む。入力の画面なので、外枠の 960px より狭い 600px にする。スマホの幅では変わらない。
 
### 3.3 ライブ一覧の追加ボタン（Fa-3、A の担当ファイル）
 
`lib/features/live/live_list_page.dart`：
 
- 右下の「ライブを追加する」（Key：`live_list_register_fab`）を、件数によらず常に出す（エラーのときと読み込み中は出さない）。
- 一覧（`_ListView` の `ListView`）の下の余白を 88 にして、最後の行がボタンに隠れないようにする（`EdgeInsets.fromLTRB(0, 8, 0, 88)`）。
### 3.4 投稿の対象の推しの初期選択（Fa-4）
 
`lib/features/trade/trade_post_form_page.dart` の新規作成（`_isEdit` が false）で、下書きを作るときに、掲示板で選んでいる推し（`boardTargetProvider`）があれば、対象の推しとして選んでおく（`draft.toggleTarget(target)`）。
 
- 編集のときは変えない。
- 掲示板で推しを選んでいなければ、今のまま空にする。
## 4. 変えるファイル
 
| ファイル | 変更 | ステップ |
|---|---|---|
| `lib/theme/app_theme.dart` | 色の組み立て（3.1） | Fa-1 |
| `lib/features/profile/profile_page.dart` | 最大幅 600px（3.2） | Fa-2 |
| `lib/features/live/live_list_page.dart` | 追加ボタンを常に出す（3.3、A と共有） | Fa-3 |
| `lib/features/trade/trade_post_form_page.dart` | 対象の推しの初期選択（3.4） | Fa-4 |
 
## 5. 開発ステップ
 
| Step | 内容 | 状況 |
|---|---|---|
| Fa-1 | 色の考え方を変える（3.1） | |
| Fa-2 | プロフィールの最大幅（3.2） | |
| Fa-3 | ライブ一覧の追加ボタン（3.3） | |
| Fa-4 | 投稿の対象の推しの初期選択（3.4） | |
 
## 6. 確認すること
 
- Fa-1：背景・カード・枠線にピンクっぽさがなく、白と灰色になる。選択中のタブの印・ボタン・右下のボタンが、選んだ色そのものになる。黄色を選ぶと、ボタンが黄色に黒い文字になる。白・黒を選んでも、ボタンの文字が読める。
- Fa-2：PC の幅で、プロフィールの入力欄が中央の 600px に収まる。
- Fa-3：ライブが1件以上あっても、ライブ一覧の右下に「ライブを追加する」が出る。最後の行が隠れない。
- Fa-4：掲示板で推しを選んだ状態で「投稿を作る」を押すと、その推しが最初から選ばれている。
## 7. 未決定事項
 
- 初期の色（`kDefaultSeedColor`、今は仮の茶色 `0xFF795548`）を、紹介ページの紫（`0xFF8B5CF6`）にするか（A と相談）
 