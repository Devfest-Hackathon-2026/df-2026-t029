# おしあし（仮）デザイン修正（Da） 仕様書
 
> 本ドキュメントは、ホームと画面移動のデザイン（`markdown/home_design.md`、D-1〜D-6）の後に行う、見た目の改善の仕様書である。
> 11/7 に PC（1470px）とスマホ（400px）の幅で全画面を見て、「無骨に見える」原因を洗い出した結果をもとにしている。
> チームメンバーおよび開発支援に使う LLM が、この文書だけを読んで同じ前提で作業できるように、現状のコードの構造と、変更後の具体的な形を書いている。
> 「決定事項」と「未決定事項」を分けて記載している。前提として、`markdown/home_design.md`・`markdown/app_config.md`・`CLAUDE.md` をあわせて参照すること。
 
## 0. LLM への指示
 
- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。
- 「9. 未決定事項」に挙げた項目は独自に確定させず、必ず「提案」として、比べた案・選ぶ理由・捨てる案を添えて示すこと。
- 本仕様にない機能・作業を勝手に足さないこと。**テストコードは書かない**（ユーザーの方針。既存のテストが通らなくなっても直さない）。
- 開発は7章のステップの順に1つずつ進めること。各ステップの終わりに `flutter analyze` で `lib/` の指摘が 0 件であることを確認し、1行程度の短いコミット文を添えること。
- **コードの編集は人間が Dev Container（Docker コンテナ）内で行う。** LLM はリポジトリを読むだけにして、変更は「どのファイルの、どこを、どう変えるか」がわかるコードとして提示すること。ファイルや文書を勝手に作ったり書き込んだりしないこと（文書も、チャットに文面として出す）。
- 既存のコードの書き方に合わせること（Riverpod 3 を手書き・コード生成なし、画面遷移は go_router、Firebase へのアクセスは `lib/repositories/` に閉じ込める、文言・コメントは日本語）。
- 色は、テーマ（`Theme.of(context).colorScheme`）から取る。画面ごとに色を直書きしない（ユーザーが選んだテーマカラーが全画面に効くようにするため）。
- 本ドキュメントや仕様書などの MD ファイルは、ユーザーの依頼なしに変更しないこと。
## 1. 概要
 
| 項目 | 内容 |
|---|---|
| 機能名 | デザイン修正（Da） |
| 担当 | B（横山）。A（とし）の担当範囲のファイル（3.x の各節に明記）は、着手前に A と共有する |
| 目的 | 「無骨」に見える原因（色がのっぺり、PC で間延び、大事な情報が目立たない）を直し、審査基準の「UI・UX」の点を伸ばす |
| 前提 | D-1〜D-6（テーマ・外枠のタブ・ホーム・テーマカラーの設定）は完了し、`dev` にマージ済み（PR #35） |
| ブランチ | `features/da`（人間が作成） |
| 状況 | **Da-1〜Da-7 完了**（11/7） |
 
### 1.1 見つかった問題（11/7 の確認）
 
| # | 問題 | 画面 | 原因 |
|---|---|---|---|
| 1 | 背景・カード・上のバーが同じ薄い色で、区切りがない | 全画面 | テーマで `ColorScheme.fromSeed` だけを設定し、背景・カード・AppBar の色を決めていない |
| 2 | PC で中身が画面いっぱい（約1400px）に広がり、間延びする。左寄せの画面は右半分が空く | 全画面 | 外枠（`AppShell`）の中身に最大幅がない |
| 3 | タブで開いた最初の画面（推し・ライブ一覧・メモリー）に「←」が出る | 推し・ライブ一覧・メモリー | これらのルートが `/` の入れ子のため、AppBar が自動で戻るボタンを出す |
| 4 | PC で、上のバーの「おしあし」と「こんにちは、◯◯さん」が二重の見出しになり、バーがほぼ空 | ホーム | ホームの AppBar に、PC でもタイトルを出している |
| 5 | 締切の緊急度が見えない（「あと5日」と「あと26日」が同じ見た目）。強調されるのは24時間以内だけ | ホーム②次の締切 | `RemainingLabel.isUrgent` が24時間以内だけ true |
| 6 | 今後のライブのカードの中央が空白で、スカスカに見える | ホーム③ | 中身がライブ名・日時・会場の文字だけ |
| 7 | 空の画面が文字だけ（「推しを選んでください」など） | グッズ交換の掲示板ほか | 掲示板は推しが未選択だと空になる |
| 8 | ライブ詳細の操作ボタン3つ（一覧から外す・編集・カレンダーに追加）が縦に並び、雑然としている | ライブ詳細 | それぞれを `Align` で1行ずつ置いている |
| 9 | フォントがそろっていない（紹介ページは英字に Outfit、ほかは標準） | 全画面 | アプリ全体のフォントを決めていない |
 
- データが少ない（デモ用のライブ・投稿・記録が少ない）ことも、空っぽに見える原因の一つだが、1〜5・8・9 はデータの量によらない問題である。デモ用のデータは `tools/seed/`（Step7 で作成済み）で入れられるので、本仕様の対象外とする。
## 2. 現状のコードの構造（11/7 時点の `dev`、Da 着手前）
 
| 対象 | 場所 | 現状 |
|---|---|---|
| テーマ | `lib/app.dart` の `App` | `ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: ref.watch(themeSeedColorProvider)), useMaterial3: true)` と `scrollBehavior` だけ |
| 基準の色 | `lib/providers/theme_providers.dart` | `kDefaultSeedColor`（仮に `0xFF795548`）、`themeSeedColorProvider`（ユーザーの `themeColor` か初期の色） |
| 外枠 | `lib/features/shell/app_shell.dart` | `AppShell`。PC（`kShellWideBreakpoint` = 720px 以上）は `Row(NavigationRail, VerticalDivider, Expanded(child))`、スマホは `Scaffold(body: child, bottomNavigationBar: NavigationBar)` |
| ホーム | `lib/features/home/home_page.dart` | `AppBar(title: 'おしあし')`（スマホのときだけ右にプロフィール・ログアウト）、`ListView` に①〜⑤ |
| 次の締切 | `lib/features/live/upcoming_deadlines_section.dart`（A の担当） | `_DeadlineTile` は `ListTile`。`describeNextDeadline(entry.deadline, now)` の `isUrgent`（24時間以内）のときだけ、警告のアイコンと `error` の色。一覧の下に「すべて見る」 |
| 残りの表示 | `lib/features/live/deadline_format.dart`（A の担当） | `RemainingLabel(text, isUrgent)`。日単位は「あと◯日」で `isUrgent: false`、時間単位は「あと◯時間」で `isUrgent: true` |
| 締切の種類 | `lib/utils/deadline.dart` | `DeadlineKind.apply`（申込期限）・`result`（当落発表）・`payment`（入金期限）。`NextDeadline` は `kind`・`at`・`reception`・`opensAt` を持つ |
| 今後のライブ | `lib/features/home/home_upcoming_lives.dart` | `_UpcomingLiveCard`（幅 220・高さ 150）。7日以内は「あと◯日」の印、ライブ名、`Spacer`、日時と会場 |
| タブの最初の画面 | `lib/features/oshi/oshi_page.dart`、`lib/features/live/live_list_page.dart`（A の担当）、`lib/features/memory/memory_list_page.dart`、`lib/features/trade/trade_top_page.dart` | 推し・ライブ一覧・メモリーは `/` の入れ子のため、AppBar に戻るボタンが出る。交換トップ（`/trade`）は入れ子ではないため出ない |
| 掲示板 | `lib/features/trade/trade_board_view.dart` | `boardTargetProvider`（選んでいる推し。初期値 null）が null だと「推しを選んでください」 |
| ライブ詳細の操作 | `lib/features/live/live_detail_page.dart` の `_DetailView`（A の担当） | 「ライブ一覧から外す／に追加」「このライブを編集」「Google カレンダーに追加」を、それぞれ `Align(alignment: Alignment.centerLeft)` で縦に並べる |
| フォント | `pubspec.yaml` | `google_fonts: ^9.0.0` が入っている（A が紹介ページで `GoogleFonts.outfit` を使用） |
 
## 3. 決定事項
 
### 3.1 テーマの整え（問題1・問題9）
 
`lib/app.dart` の `App` の `ThemeData` に、次を足す。色はすべて `ColorScheme` の役割の色から取る。
 
| 項目 | 設定 | 目的 |
|---|---|---|
| 背景 | `scaffoldBackgroundColor: scheme.surfaceContainerLowest`（白に近い色） | テーマの色が背景全体に広がらないようにする |
| AppBar | `appBarTheme: AppBarTheme(backgroundColor: scheme.surfaceContainerLowest, scrolledUnderElevation: 0, centerTitle: false)` | 背景と同じ色にしてすっきりさせる。スクロールしても色を変えない |
| カード | `cardTheme: CardThemeData(color: scheme.surface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: scheme.outlineVariant)))` | 白いカードに薄い枠で、背景と区別する |
| 区切り線 | `dividerTheme: DividerThemeData(color: scheme.outlineVariant)` | 線を目立たせすぎない |
| 外枠のタブ | `navigationRailTheme`・`navigationBarTheme` の背景を `scheme.surfaceContainerLowest` | 背景と同じ色にする |
 
- `ColorScheme` は `ColorScheme.fromSeed(seedColor: …, dynamicSchemeVariant: DynamicSchemeVariant.fidelity)` で作り、`ThemeData` の各項目はその `scheme` から作る（テーマカラーを変えたときに、全部いっしょに変わるようにする）。
  - **`fidelity` に決定**（Da-1）。選んだ色に近い色になる。標準の `tonalSpot` は色をやわらげる。
  - `fidelity` では `primaryContainer` も選んだ色に近い濃い色になるため、`primary` の文字を `primaryContainer` の上に置くと読めない。テーマの色の薄い背景が欲しいときは `scheme.primary.withValues(alpha: 0.12)` を使い、文字は `scheme.primary` にする（3.4・3.5）。
- **フォントは、英字を紹介ページと同じ Outfit に決定**（Da-1）。`ThemeData(fontFamily: GoogleFonts.outfit().fontFamily)` で指定する。日本語は Outfit に無いので、標準の日本語フォントになる。
  - `textTheme: GoogleFonts.outfitTextTheme(...)` は、`google_fonts` 9.0.0 で型のエラー（`TextTheme` を `TextTheme?` に渡せない）が出たため使わない。
- テーマの組み立ては、`lib/app.dart` に直接書かず、`lib/theme/app_theme.dart`（新規）の関数 `ThemeData buildAppTheme(Color seedColor)` にまとめる。`App` は `theme: buildAppTheme(ref.watch(themeSeedColorProvider))` とする。
### 3.2 外枠の整え（問題2・問題4の一部）
 
`lib/features/shell/app_shell.dart` の `AppShell` を、次のように変える。
 
- **中身の最大幅**：PC の幅のとき、`child` を最大幅 **960px**（定数 `kShellMaxContentWidth`）にして、中身の領域の中央に寄せる（`Expanded(child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: kShellMaxContentWidth), child: child)))`。元の `Expanded(child: child)` は置き換える）。スマホの幅では変えない。
  - 各画面の `Scaffold`（AppBar を含む）が 960px の中に入る形になる。
  - 広い画面では、中身の左右に背景と同じ色の余白が出る（残すかは9章）。
- **アプリ名**：左のタブの一番上（`NavigationRail` の `leading`）に、アプリ名「おしあし」をテーマの色（`scheme.primary`・`titleMedium`・太字）で置く（Key：`shell_app_name`）。ロゴの画像は使わない（9章）。
### 3.3 タブの最初の画面の「←」とホームの見出し（問題3・問題4）
 
- 推し（`oshi_page.dart`）・ライブ一覧（`live_list_page.dart`・A の担当）・メモリー（`memory_list_page.dart`）の `AppBar` に、`automaticallyImplyLeading: false` を付ける（タブで開く最初の画面なので戻るボタンを出さない）。
  - 詳細画面（ライブの詳細、記録の詳細、推しを探すなど）の戻るボタンは、これまでどおり出す。
- ホーム（`home_page.dart`）：
  - PC の幅（`kShellWideBreakpoint` 以上）では `AppBar` を出さない（`appBar: wide ? null : AppBar(...)`）。アプリ名は左のタブの上に出る（3.2）。
  - スマホの幅では、これまでどおり `AppBar`（タイトル「おしあし」、右にプロフィール・ログアウト）を出す。
  - PC で AppBar をなくすと上の余白が減るため、`ListView` の上の余白を広げる（`EdgeInsets.fromLTRB(16, wide ? 24 : 16, 16, 16)`）。
### 3.4 締切の見た目（問題5）
 
`lib/features/live/upcoming_deadlines_section.dart` の `_DeadlineTile`（A の担当）を、次のように変える。`deadline_format.dart` の `RemainingLabel` は変えない（ほかの画面でも使っているため）。
 
- **緊急度を3段階にする**（締切の日時 `entry.deadline.at` と `now` の差で決める）：
| 段階 | 条件 | 見た目 |
|---|---|---|
| 急ぎ | 24時間以内（今の `isUrgent` が true） | 残りの文字を `scheme.error` で太字、左のアイコンを `Icons.warning_amber_rounded`（`error` の色）。今と同じ |
| 近い | 7日以内（24時間より先） | 残りの文字を `scheme.primary` で太字にし、背景 `scheme.primary.withValues(alpha: 0.12)` の小さな印（角丸 8）で囲む（Key：`home_deadline_soon_<受付ID>`） |
| 通常 | それより先 | 今と同じ |
 
- 当初は印の背景を `scheme.primaryContainer` としていたが、`fidelity`（3.1）では文字と同じ濃い色になり読めなかったため、薄く透かした色に変えた（Da-4x）。
- **締切の種類をアイコンで区別する**（急ぎでないとき）：申込期限（`DeadlineKind.apply`）は `Icons.edit_calendar`、当落発表（`result`）は `Icons.campaign`、入金期限（`payment`）は `Icons.payments`。アイコンの色は `scheme.primary`。
- 3段階の判定は、`lib/utils/deadline.dart` などに純粋関数を足さず、`_DeadlineTile` の中で `entry.deadline.at.difference(now)` から決める（A の担当のユーティリティを増やさないため）。
- 一覧の下の「すべて見る」は今のまま残す（ホームの見出し側には付けない）。
### 3.5 今後のライブのカード（問題6）
 
`lib/features/home/home_upcoming_lives.dart` の `_UpcomingLiveCard` を、次の形にする（幅 220・高さ 150 は変えない）。
 
```
┌──────────────────────┐
│ ┌────┐  あと3日         │  ← 日付の枠（左）と、7日以内の印（右上）
│ │12月│                  │
│ │ 20 │  テストライブ2026 │  ← ライブ名（最大2行）
│ │ 日 │                  │
│ └────┘                  │
│ 18:00 ・ テストホール     │  ← 開演時刻と会場（1行、はみ出しは省略）
└──────────────────────┘
```
 
- 左に、次の公演の日付の枠（`_DateBlock`。幅 56、背景 `scheme.primary.withValues(alpha: 0.12)`、文字 `scheme.primary`、角丸 12）を置く。上から「12月」（`labelSmall`）・「20」（`headlineSmall`・太字）・「日」（曜日、`labelSmall`）。
  - 当初は `primaryContainer`／`onPrimaryContainer` としていたが、3.4 と同じ理由で薄く透かした色にそろえた。
- 右に、7日以内の印（今の `_DaysBadge`）とライブ名。
- 下に、時計のアイコンと、開演時刻（`HH:mm`）と会場を「・」でつないで1行で出す（会場が空なら時刻だけ）。
- 押すとライブの詳細へ（今のまま）。
### 3.6 空の画面（問題7）
 
- **掲示板の推しの初期選択**：`lib/features/trade/trade_board_view.dart` で、`boardTargetProvider` が null かつフォロー中の推し（`followingOshisProvider`）が1件以上あるときは、先頭の推しを選んだ状態にする。
  - 方法：`initState` で `ref.listenManual(followingOshisProvider, …, fireImmediately: true)` し、推しが読めて未選択なら、`WidgetsBinding.instance.addPostFrameCallback` の中で `boardTargetProvider.notifier.select(oshis.first)` を呼ぶ（画面を作っている途中にプロバイダを変えないため）。
- **空の状態の表示をそろえる**：アイコン（48px、`scheme.outline` の色）＋案内の文言（`titleMedium`）＋（あれば）補足（`bodySmall`）＋（あれば）次にやることのボタン、を縦に中央に並べる部品 `EmptyState(icon, title, message?, action?)`（`lib/features/common/empty_state.dart`・新規）を作り、次の画面で使う。
| 画面 | アイコン | 文言 | ボタン |
|---|---|---|---|
| 掲示板（フォロー中の推しが0件） | `Icons.favorite_outline` | 推しをフォローすると、交換の投稿が見られます | 推しを探す（`/oshi/search` へ push。Key：`trade_board_find_oshi_button`） |
| メモリーの記録が1件もない | `Icons.photo_album_outlined` | 参戦したライブを記録すると、ここに並びます（補足：ライブの詳細の公演から「記録する」で残せます） | なし |
| メモリーの参戦済みが0件（参戦予定はある） | `Icons.photo_album_outlined` | 参戦したライブを記録すると、ここに並びます | なし |
| ホーム③〜⑤の0件 | 使わない（区画の中の1行の案内のまま） | — | — |
 
- 掲示板でフォロー中の推しが0件のときは、上の推しの選択欄の文（「フォロー中の推しがいません…」）は出さず、`EmptyState` だけを出す。
### 3.7 ライブ詳細の操作ボタン（問題8）
 
`lib/features/live/live_detail_page.dart` の `_DetailView`（A の担当）で、「ライブ一覧から外す／に追加」「このライブを編集」「Google カレンダーに追加」の3つを、縦の `Align` ではなく、1つの `Wrap(spacing: 8, runSpacing: 8)` に横に並べる（上に `SizedBox(height: 12)`）。
 
- 「ライブ一覧に追加」（未追加）は `FilledButton.icon`、「ライブ一覧から外す」（追加済み）は `OutlinedButton.icon`（今のまま）。
- 「このライブを編集」「Google カレンダーに追加」は `OutlinedButton.icon` にそろえる。
- 各ボタンの Key・押したときの動きは変えない。
### 3.8 そのほか
 
- 新しいパッケージは追加しない（`google_fonts` は既存）。
- データ構造・セキュリティルールは変えない。
- 既存の Key は変えない。
## 4. 画面ごとの変更のまとめ
 
| 画面 | 変更 |
|---|---|
| 全画面 | 背景・カード・AppBar・区切り線の色、色の作り方（`fidelity`）、英字のフォント（Outfit）（3.1） |
| 外枠 | PC で中身の最大幅 960px、左のタブの上にアプリ名（3.2） |
| ホーム | PC で AppBar を出さない（3.3）、締切の3段階とアイコン（3.4）、今後のライブのカード（3.5） |
| 推し・ライブ一覧・メモリー | 「←」を出さない（3.3） |
| グッズ交換の掲示板 | 推しの初期選択、空の状態（3.6） |
| メモリー | 記録0件・参戦済み0件の空の状態（3.6） |
| ライブ詳細 | 操作ボタンを横に並べる（3.7） |
 
## 5. 非機能要件
 
- スマホの幅（360px）と PC の幅（1280px 程度）の両方で、表示が崩れない（はみ出しの警告が出ない）。
- どのテーマカラー（色見本の12色と初期の色）でも、文字が読める。
- 読み取り（Firestore）を増やさない。
## 6. ファイル構成
 
| ファイル | 変更 | ステップ |
|---|---|---|
| `lib/theme/app_theme.dart` | 新規（`buildAppTheme`） | Da-1 |
| `lib/app.dart` | 変更（A と共有。`theme: buildAppTheme(...)`） | Da-1 |
| `lib/features/shell/app_shell.dart` | 変更（最大幅、アプリ名） | Da-2 |
| `lib/features/home/home_page.dart` | 変更（PC で AppBar なし、上の余白） | Da-3 |
| `lib/features/oshi/oshi_page.dart` | 変更（戻るボタンなし） | Da-3 |
| `lib/features/live/live_list_page.dart` | 変更（A と共有。戻るボタンなし） | Da-3 |
| `lib/features/memory/memory_list_page.dart` | 変更（戻るボタンなし、空の状態） | Da-3・Da-6 |
| `lib/features/live/upcoming_deadlines_section.dart` | 変更（A と共有。3段階・アイコン） | Da-4 |
| `lib/features/home/home_upcoming_lives.dart` | 変更（カード） | Da-5 |
| `lib/features/common/empty_state.dart` | 新規 | Da-6 |
| `lib/features/trade/trade_board_view.dart` | 変更（推しの初期選択、空の状態） | Da-6 |
| `lib/features/live/live_detail_page.dart` | 変更（A と共有。操作ボタン） | Da-7 |
 
## 7. 開発ステップ
 
全画面に効くものから順に進める。Da-1〜Da-4 を優先し、Da-5〜Da-7 は時間に余裕があれば行う。
 
| Step | 内容 | 優先度 | 状況 |
|---|---|---|---|
| Da-1 | テーマの整え（3.1）。`fidelity`、英字は Outfit に決定 | 高 | 完了 |
| Da-2 | 外枠の整え（3.2）：最大幅 960px、左のタブの上にアプリ名 | 高 | 完了 |
| Da-3 | タブの最初の画面の「←」を消す、ホームの AppBar を PC で出さない（3.3） | 高 | 完了 |
| Da-4 | 締切の3段階とアイコン（3.4）。印の色の修正（Da-4x）を含む | 高 | 完了 |
| Da-5 | 今後のライブのカード（3.5） | 中 | 完了 |
| Da-6 | 空の状態の部品と、掲示板の推しの初期選択（3.6） | 中 | 完了 |
| Da-7 | ライブ詳細の操作ボタンを横に並べる（3.7） | 低 | 完了 |
 
- Da-1・Da-3・Da-4・Da-7 は A の担当範囲のファイルを触るため、着手前に A と共有する。
## 8. 確認すること（各ステップの終わりに画面で確認）
 
- Da-1：背景が白に近い色、カードが白に薄い枠で、背景と区別できる。テーマカラーを変えても、背景は白に近いまま、ボタン・選択中のタブの色だけが変わる。
- Da-2：PC の幅で、どの画面の中身も 960px 以内に収まり、中央に寄る。左のタブの上に「おしあし」が出る。スマホの幅では変わらない。
- Da-3：推し・ライブ一覧・メモリーに「←」が出ない。詳細画面の「←」は出る。PC のホームに上のバーが出ず、スマホのホームには出る。
- Da-4：締切が、24時間以内は赤、7日以内は印付き（文字が読める）、それより先は通常の見た目になる。申込・当落・入金でアイコンが違う。
- Da-5：今後のライブのカードに日付の枠が出て、空白が目立たない。
- Da-6：グッズ交換を開くと、フォロー中の推しが最初から選ばれている。フォロー0件・メモリー0件で、アイコン付きの案内が出る。
- Da-7：ライブ詳細の操作ボタンが横に並び、狭い幅では折り返す。
（11/7、PC の幅で Da-1〜Da-7 の画面を確認済み）
 
## 9. 未決定事項
 
以下は未決定である。LLM は独自に確定させず、提案として提示すること。
 
- PC の中身の最大幅（3.2）を残すか。広い画面では左右に余白が出る（11/7 時点では、とりあえず 960px のまま）
- 初期の色（`kDefaultSeedColor`）を紹介ページの紫（`0xFF8B5CF6`）にするか（A と相談）
- アプリのロゴの画像を作るか（今回は文字のアプリ名だけ）
- ダークモードに対応するか（今回は対応しない）
- デモ用のデータを本番に入れる時期と内容（`tools/seed/`。本仕様の対象外）