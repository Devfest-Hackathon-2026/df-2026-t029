# おしあしホームと外枠の手直しの方針書（Fe）

> 本ドキュメントは、11/8 夕方にユーザー（横山）が挙げた手直し（DEBUG の帯・ホームの当落発表・左のタブの自分のアイコン・PC の横幅）を、提出（11/10 19:00）までに進めるための方針書である。
> チームメンバーおよび開発支援に使う LLM が、この文書だけを読んで同じ前提で作業できるように、今の作り・直し方・変えるファイルを具体的に書いている。
> 前提として、`CLAUDE.md`・`markdown/fixes/fix_Fc.md`・`markdown/fixes/fix_Fd.md` をあわせて参照すること。

## 0. LLM への指示

- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。「7. 未決定事項」は独自に確定させず、提案として示すこと。
- 本仕様にない作業を勝手に足さないこと。**テストコードは書かない**。
- **コードの編集は人間が Dev Container 内で行う。** LLM はリポジトリを読むだけにする。小さな変更は変わる部分だけ、大きな変更はメソッド・クラス・ファイル単位で丸ごと出す。**変更ごとにファイルの場所（パス）を書く**（「1〜3に同じものを適用」のようにまとめない）。
- 5章のステップの順に進め、各ステップに1行のコミット文を添えること。画面の確認は最後にまとめて行う。
- 見た目はログイン後のデザイン「ハコ色」（`lib/theme/hako_app_widgets.dart`・`brand_colors.dart`・`hako_fonts.dart`）に合わせる。
- コメントで章を書くときは「Fe 3.1」のように方針書の名前を付ける。
- **`firestore.rules` とデータの形は変えない**（Fe は画面だけの手直し）。

## 1. 概要

| 項目 | 内容 |
|---|---|
| 名前 | Fe |
| 担当 | B（横山）。`app.dart`・ホーム・外枠は A（とし）と共有する範囲なので、A と共有する |
| ブランチ | `dev` から `features/Fe` |
| 状況 | 未着手 |

### 1.1 手直しの一覧と順番

| 対象 | 手直し | ステップ |
|---|---|---|
| アプリ全体 | 右上の DEBUG の帯を消す | Fe-1 |
| 外枠（PC の左のタブ） | 自分のアイコンを大きくする（28 → 48） | Fe-2 |
| ホーム | 「次の締切」から当落発表を分け、区画「当落発表」を作る | Fe-3 |
| 外枠・ホーム | 外枠の最大幅を広げ、PC のホームを左右2列にする | Fe-4 |

## 2. 着手前の作り（11/8 時点の `dev`、#61 マージ後）

| 対象 | 場所 | 作り |
|---|---|---|
| アプリ | `lib/app.dart` の `App` | `MaterialApp.router` に `debugShowCheckedModeBanner` の指定が無い（デバッグビルドで右上に帯が出る。リリースビルドでは出ない） |
| アカウントのボタン | `lib/theme/hako_app_widgets.dart` の `AccountMenuButton` | `PopupMenuButton` の `icon` が `UserAvatar(size: 28)`、`iconSize: 24`。左のタブの下（`app_shell.dart`）とスマホの上のバー（`HakoAppBar`）で使う |
| 左のタブ | `lib/features/shell/app_shell.dart` | 幅 82。タブの丸は直径 44（墨 2px の枠） |
| 外枠の最大幅 | 同上 `kShellMaxContentWidth = 960` | PC の幅で中身（`child`）を 960 までにして中央に寄せる。すべての画面の上限になっているため、メモリー・遠征の `maxContentWidth: 1080` も実際は 960 で止まっている |
| ページの枠 | `HakoPageScaffold`（`kHakoContentMaxWidth = 640`。`maxContentWidth` で変えられる） | ホームは 640・1列 |
| 次の締切 | `lib/features/live/upcoming_deadlines_section.dart` の `UpcomingDeadlinesSection` | `upcomingDeadlinesProvider`（受付ごとに次の締切を1件。種類は `DeadlineKind.apply`・`result`・`payment`）の先頭5件（`homeDeadlineLimit`）。申込・当落・入金が1つの列に混ざる。見出し「次の締切」は `home_page.dart` 側で出す |
| ホーム | `lib/features/home/home_page.dart` | 1つの `ListView` に、あいさつ → 推しの記念日 → 次の締切 → 今後のライブ → 次の遠征 → 新しい交換 → 今月の推し活費 → 最近の思い出 |

## 3. 決定事項

### 3.1 DEBUG の帯（Fe-1）

- `lib/app.dart` の `MaterialApp.router` に `debugShowCheckedModeBanner: false` を足す。

### 3.2 左のタブの自分のアイコン（Fe-2）

- `AccountMenuButton` に引数 `avatarSize`（省略時 28）を足す。`UserAvatar(size: avatarSize)`、`iconSize: avatarSize` とする。
- 左のタブの下（`app_shell.dart` の `AccountMenuButton(key: Key('shell_account_button'))`）だけ `avatarSize: 48`（タブの丸 44 より少し大きい）。`UserAvatar` は 48 以上で枠が 2px になり、タブの丸の枠とそろう。
- スマホの上のバー（`HakoAppBar`）は 28 のまま。
- 未ログインのときの人のアイコン（`Icons.person_outline`）も `avatarSize` に合わせる。

### 3.3 当落発表を分ける（Fe-3）

- `UpcomingDeadlinesSection` に引数 `results`（省略時 false）を足す。
  - `results: false`（次の締切）：`kind` が `apply`・`payment` のものだけ。
  - `results: true`（当落発表）：`kind` が `result` のものだけ。
  - どちらも、振り分けた後の先頭5件（`homeDeadlineLimit`）。行（`_DeadlineTile`）の見た目はこれまでどおり。
- 空・自分のライブが0件・読み込み中・エラーのとき：

| 状態 | 次の締切（今までどおり） | 当落発表 |
|---|---|---|
| 自分のライブが0件 | 「ライブを追加すると、締切がここに出ます」と「ライブを追加する」 | 「当落発表の予定はありません」（追加のボタンは出さない。次の締切の区画と重ねないため） |
| 振り分けた後が0件 | 「近い締切はありません」 | 「当落発表の予定はありません」 |
| 読み込み中・エラー | 今までどおり | 次の締切と同じ表示（文言は「当落発表を読み込めませんでした」） |

- Key：次の締切は今までの Key のまま（既存のテストのため）。当落発表は `home_deadlines_` を `home_results_` に、`home_deadline_` を `home_result_` に置き換えたもの（例：`home_results_list`・`home_results_empty`・`home_result_tile_{受付ID}`・`home_results_see_all_button`）。
- 見出し：ホーム側で `HomeSectionHeader(title: '当落発表')` を出す。「すべて見る」は今までどおり区画の下（`/lives`）。
- スマホの幅（と PC で1列のとき）は、「次の締切」の区画のすぐ下に「当落発表」の区画を置く。

### 3.4 外枠の最大幅と、PC のホームの2列（Fe-4）

#### 外枠

- `kShellMaxContentWidth` を 960 → **1200** にする。
  - `HakoPageScaffold` を使う画面は、それぞれの `maxContentWidth`（ふつうは 640）で止まるので、見た目は変わらない。メモリー・遠征は 1080 まで広がる。
  - `HakoPageScaffold` を使わない画面（チャット `chat_page.dart`・投稿の詳細 `trade_post_detail_page.dart`・まとめの確認 `merge_review_page.dart`）は 1200 まで広がる（7章）。

#### ホーム

- `HomePage` の `HakoPageScaffold` を `maxContentWidth: 1200` にする。
- 本文の幅（`LayoutBuilder` の `maxWidth` から左右の余白を引いた幅）が **900 以上**なら2列、未満なら1列（メモリー一覧の `_twoColumnWidth = 900` と同じ基準）。スマホの幅はいつも1列。
- 2列のときの並び（1つの `ListView` の中で、上は全幅、その下に左右の列。左右は一緒にスクロールする）：

```
[ あいさつ・行きたいライブを追加（全幅） ]
[ 推しの記念日（全幅）                   ]
+---------------------------+------------------+
| 次の締切                  | 当落発表         |
| 今後のライブ              | 次の遠征         |
| 新しい交換                | 今月の推し活費   |
| 最近の思い出              |                  |
+---------------------------+------------------+
```

  - 左右の幅は 3：2（`Expanded(flex: 3)`・`Expanded(flex: 2)`）、間は 24。上端でそろえる（`CrossAxisAlignment.start`）。
  - 各区画の中身（横の一覧・カード）はそのまま使う。区画の並びは左・右それぞれ `Column`。
- 1列のときの並び：あいさつ → 推しの記念日 → 次の締切 → 当落発表 → 今後のライブ → 次の遠征 → 新しい交換 → 今月の推し活費 → 最近の思い出。
- 区画の一覧は1か所（左の列・右の列の部品のリスト）にまとめ、1列のときはそれを決まった順に並べ直して使う（2つの並びで区画が漏れないようにする）。

## 4. 変えるファイル

| ファイル | 変更 | ステップ |
|---|---|---|
| `lib/app.dart` | `debugShowCheckedModeBanner: false` | Fe-1 |
| `lib/theme/hako_app_widgets.dart` | `AccountMenuButton` の `avatarSize` | Fe-2 |
| `lib/features/shell/app_shell.dart` | 左のタブのアカウントのボタンを 48（Fe-2）、`kShellMaxContentWidth` を 1200（Fe-4） | Fe-2・4 |
| `lib/features/live/upcoming_deadlines_section.dart` | `results` の引数と振り分け・文言・Key | Fe-3 |
| `lib/features/home/home_page.dart` | 当落発表の区画（Fe-3）、最大幅と2列（Fe-4） | Fe-3・4 |

## 5. 開発ステップ

| Step | 内容 | 状況 |
|---|---|---|
| Fe-1 | DEBUG の帯を消す（3.1） | |
| Fe-2 | 左のタブの自分のアイコンを 48 に（3.2） | |
| Fe-3 | 当落発表を分ける（3.3） | |
| Fe-4 | 外枠の最大幅 1200・PC のホームを2列（3.4） | |

## 6. 確認すること（最後にまとめて Chrome で）

1. デバッグビルドで、右上に DEBUG の帯が出ない。
2. PC の幅で、左のタブの下の自分のアイコンがタブの丸より少し大きく、押すとプロフィール・ログアウトのメニューが出る。スマホの幅の上のバーのアイコンは今までどおり。
3. ホームの「次の締切」に申込・入金だけ、「当落発表」に当落だけが出る。どちらも5件まで。0件のときの文言。
4. PC の幅（1280px 程度）で、ホームが3.4の左右2列になる。窓を狭めて本文が 900 未満になると1列（次の締切の下に当落発表）。スマホの幅（360px）で、はみ出しの警告が出ない。
5. メモリー・遠征の2列が 1080 まで広がる。1列の画面（推し・ライブ一覧など）は今までどおり 640。チャット・投稿の詳細の見た目（7章）。

## 7. 未決定事項

- チャット・投稿の詳細・まとめの確認の画面が 1200 まで広がる。6章の5で見て広すぎれば、その画面の中で 960 に絞る（提案）。
- ほかの画面の2列（ライブ詳細・グッズ交換のトップなど）。今回はホームだけ（11/8 朝の計画の `add_X` の「ほかの画面も PC で2列」で扱う）。
- 当落発表の区画で、当落の済んだ受付（当選・落選を入れたもの）を「結果」として残して出すか（今は次の締切が当落のものだけが出る）。