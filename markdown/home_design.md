# おしあし（仮）ホームと画面移動のデザイン 仕様書

> 本ドキュメントは、アプリ全体のテーマ（色）、画面を移るためのタブ（外枠）、推しの画面、ホーム画面の作り直しの仕様書である。
> チームメンバーおよび開発支援に使う LLM が、この文書だけを読んで同じ前提で作業できるように、現状のコードの構造と、変更後の具体的な形を書いている。
> 「決定事項」と「未決定事項」を分けて記載している。ホームの構成は、横山の手書きの案（2026-11-07）をもとにしている。
> 前提として、プロジェクト仕様書（`markdown/app_config.md`）と `CLAUDE.md` をあわせて参照すること。

## 0. LLM への指示

- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。
- 「9. 未決定事項」に挙げた項目は独自に確定させず、必ず「提案」として、比べた案・選ぶ理由・捨てる案を添えて示すこと。
- 本仕様にない機能・作業を勝手に足さないこと。**テストコードは書かない**（ユーザーの方針）。既存のテストが壊れる場合は、壊れるテスト名と理由を示し、直すかどうかは人間が決める。
- 開発は7章のステップの順に1つずつ進めること。各ステップの終わりに `flutter analyze` で指摘が 0 件（info を含む）であることを確認し、1行程度の短いコミット文を添えること。
- **コードの編集は人間が Dev Container（Docker コンテナ）内で行う。** LLM はリポジトリを読むだけにして、変更は「どのファイルの、どこを、どう変えるか」がわかるコードとして提示すること。ファイルに直接書き込まないこと。
- 既存のコードの書き方に合わせること（Riverpod 3 を手書き・コード生成なし、画面遷移は go_router、Firebase へのアクセスは `lib/repositories/` に閉じ込める、`await` の後は `context.mounted` を確認、文言・コメントは日本語）。
- 本ドキュメントや仕様書などの MD ファイルは、ユーザーの依頼なしに変更しないこと。

## 1. 概要

| 項目 | 内容 |
|---|---|
| 機能名 | ホームと画面移動のデザイン |
| 担当 | B（横山）。ルーター（`lib/app.dart`）とホーム（`lib/features/home/`）は A（とし）の担当範囲のため、D-2・D-3 の着手前に A と共有する |
| 目的 | 見た目を整え、どの画面からでも主な機能へ移れるようにし、ホームで「次にやること」と最近の動きがひと目でわかるようにする |
| 背景 | 審査基準の「対象ユーザーが目的を達成できる UI・UX になっているか」の点を伸ばすため（11/7 の自己評価で最も伸ばせる項目） |
| ブランチ | 人間が作る |

### 1.1 現状の問題

- 色・文字が Flutter の標準（紫）のままで、無骨に見える。`MaterialApp.router` に `theme` を設定していない。
- ホームは、機能へのボタン4つが縦に並ぶだけ。ほかの画面からホームに戻らないと、別の機能に移れない。
- 今どの機能を開いているかがわからない。

### 1.2 変更後の利用の流れ

1. ログイン後、PC の幅では画面の左に、スマホの幅では画面の下に、5つのタブ（ホーム・ライブ一覧・グッズ交換・メモリー・推し）が常に出る。
2. タブを押すと、その機能の画面に移る。今いる機能のタブは強調される。詳細画面（ライブの詳細など）でも、その機能のタブが強調されたまま。
3. ホームでは、上から「あいさつと行きたいライブの追加」「次の締切」「今後のライブ」「新しい交換」「最近の思い出」を見られ、それぞれの詳細・一覧に移れる。

## 2. 現状のコードの構造（11/7 時点の `dev`）

### 2.1 `lib/app.dart`

- `routerProvider`（`Provider<GoRouter>`）でルーターを作る。`redirect` で、未ログインなら `/welcome`、プロフィール未作成なら `/profile` に移す（紹介ページの仕様書 W-1 で実装済み）。
- `App`（`MaterialApp.router`）は `title: 'おしあし'` と `routerConfig` だけを渡しており、`theme`・`scrollBehavior` は未設定。
- ルートの構成（`routes:` の中、上から順）：

```
/                      HomePage
  ├ oshi/search        OshiSearchPage
  ├ oshi/request       OshiRequestPage
  ├ lives              LiveListPage
  │  ├ add             LiveAddPage
  │  └ :liveId         LiveDetailPage
  │     ├ edit         LiveEditPage
  │     └ memory/:performanceId   MemoryFormPage（記録の作成）
  └ memories           MemoryListPage
     └ :performanceId  MemoryDetailPage
        └ edit         MemoryFormPage（記録の編集）
/welcome               WelcomePage
/login                 LoginPage
/register              ScanPage（ライブの登録方法の選択・スクショ読み取り）
/live-form             LiveFormPage
/calendar-test         CalendarTestPage（接続テスト）
/goods                 GoodsSearchPage
/goods/new             GoodsFormPage
/goods/:id/edit        GoodsFormPage
/trade                 TradeTopPage（?tab=board/match/mine）
/trade/board・/trade/mine   /trade?tab=… へのリダイレクト
/chats                 ChatListPage
/chats/:id             ChatPage
/trade/new             TradePostFormPage
/trade/:id/edit        TradePostFormPage
/trade/:id             TradePostDetailPage（?attach=）
/login                 LoginPage（重複。先に書いた方が使われる）
/profile               ProfilePage
```

- go_router は `^18.1.3`、flutter_riverpod は `^3.4.3`、Dart SDK は `^3.13.7`。

### 2.2 `lib/features/home/home_page.dart`（99 行）

- `AppBar`（タイトル「おしあし」、右にプロフィール `/profile` とログアウトのアイコン）。
- 本文は `ListView`：「ようこそ、◯◯ さん」→ ボタン4つ（`home_search_button`：推しを探す、`home_live_list_button`：ライブ一覧、`home_trade_button`：グッズ交換、`home_memory_button`：メモリー）→「次の締切」＋ `UpcomingDeadlinesSection` →「フォロー中の推し」＋ `FollowingOshiList`。
- 右下に `FloatingActionButton.extended`（`home_add_live_fab`、「ライブを追加する」→ `/lives/add`）。

### 2.3 使う既存の部品・プロバイダ

| 名前 | 場所 | 内容 |
|---|---|---|
| `UpcomingDeadlinesSection` | `lib/features/live/upcoming_deadlines_section.dart` | 次の締切の一覧（読み込み中・エラー・0件の表示を含む） |
| `FollowingOshiList` | `lib/features/oshi/following_oshi_list.dart` | フォロー中の推しの一覧と解除（Key は `home_following_*`） |
| `myProfileProvider` | `lib/providers/profile_providers.dart` | 自分のプロフィール（`displayName`） |
| `liveListProvider` | `lib/providers/live_providers.dart` | 自分のライブ一覧（`AsyncValue<List<LiveListEntry>>`）。`LiveListEntry` は `live`・`performances`（開演順）・`nextStartAt`（今日以降で最も早い公演の開演。終了なら null）・`isEnded` を持つ（`lib/utils/deadline.dart`） |
| `memoryAlbumProvider` | `lib/providers/memory_providers.dart` | 記録の一覧（`AsyncValue<MemoryAlbum>`）。`attended` は参戦済みを新しい順。`LiveMemory` は `performanceId`・`liveId`・`liveTitle`・`startAt`・`venue`・`images` などを持つ |
| `followingOshisProvider` | `lib/providers/oshi_providers.dart` | フォロー中の推し（`AsyncValue<List<OshiSummary>>`）。`OshiSummary` は `id`・`kind`（`OshiKind.group`／`person`）・`name`・`groupIds` を持つ |
| `openTradePostsProvider` | `lib/providers/trade_post_providers.dart` | 推し1つの募集中の投稿（family。引数 `({OshiKind kind, String id, int limit})`）。既存の複合インデックスで動く |
| `mergeBoardPosts` | `lib/utils/trade_board.dart` | 複数の投稿リストを、重複を除いて更新日時の新しい順にまとめる（`(List<List<TradePost>> lists, int limit)`） |
| `TradePostSummaryLines` | `lib/features/trade/trade_post_summary_lines.dart` | 投稿の要約（譲・求・タグなど）の表示行 |
| `currentUidProvider` | `lib/providers/oshi_providers.dart` | ログイン中の uid |
| `authRepositoryProvider` | `lib/repositories/auth_repository.dart` | `signOut()` |
| `formatDateTime` | `lib/features/live_form/date_time_field.dart` | 日時の表示用の文字列 |

### 2.4 ホームに依存する既存のテスト

- `test/features/home_following_test.dart`：`HomePage` を表示し、`home_search_button`・`home_add_live_fab`・`home_live_list_button`・`FloatingActionButton` の数・「ライブを追加する」の文言・`home_following_*` を確かめている。D-3 でホームを作り直すと、これらのテストの一部が通らなくなる（2.4 の Key と FAB がなくなり、`FollowingOshiList` が推しの画面に移るため）。直すかどうかは人間が決める。

## 3. 決定事項

### 3.1 テーマ（色）

- アプリ全体の基準の色を、落ち着いた茶色にする。
- `App` の `MaterialApp.router` に `theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: <茶色>), useMaterial3: true)` を設定する。ボタン・選択中のタブ・カードなどの色は、基準の色から自動で作られる。
- 茶色の具体的な値は D-1 で候補を示して決める（9章）。
- 各画面の色は、これまでどおりテーマ（`Theme.of(context).colorScheme`）から取る。画面ごとに色を直書きしない。
- 茶色にする理由（提出ドキュメントの「選定理由」に使う）：
  - 推し活の色はメンバーカラーで人それぞれ。アプリ自体は主張しない色にして、どの推しのファンでも使いやすくする。
  - 中心の機能は申込・入金の期限を逃さない予定管理。革の手帳のような落ち着きで、長く使う道具としての信頼感を出す。
  - ピンクが多い既存の推し活アプリと、見た目で区別する。
- 捨てた案：ピンク系（推し活らしいが、既存のアプリと似る）、今の紫を整えるだけ（印象が変わらない）、水色・ミント系（予定管理らしいが、推し活らしさが薄い）。

### 3.2 マウスでの横スクロール

- Flutter Web は、標準ではマウスのドラッグで横にスクロールできない（`ScrollBehavior.dragDevices` にマウスが含まれない）。ホームの横に並べる区画（3.5）を PC で動かせるように、`MaterialApp.router` の `scrollBehavior` に、マウスのドラッグを許す `ScrollBehavior` を設定する。

```dart
/// マウスのドラッグでもスクロールできるようにする（Web で横の一覧を動かすため）
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
      };
}
```

- 横に並べる区画には、スクロールバー（`Scrollbar`）を出して、横に続きがあることがわかるようにする。

### 3.3 画面を移るためのタブ（外枠）

#### タブと、選択中にするパス

| 順 | タブ | アイコン（目安） | 押したときの移動先 | 選択中にするパス（上から順に判定） |
|---|---|---|---|---|
| 0 | ホーム | `Icons.home_outlined`／選択中 `Icons.home` | `/` | 1〜4 のどれにも当たらないとき |
| 1 | ライブ一覧 | `Icons.event_note_outlined`／`Icons.event_note` | `/lives` | `/lives`・`/register`・`/live-form` で始まる |
| 2 | グッズ交換 | `Icons.swap_horiz` | `/trade` | `/trade`・`/chats`・`/goods` で始まる |
| 3 | メモリー | `Icons.photo_album_outlined`／`Icons.photo_album` | `/memories` | `/memories` で始まる |
| 4 | 推し | `Icons.favorite_outline`／`Icons.favorite` | `/oshi` | `/oshi` で始まる |

- 判定に使うパスは `GoRouterState.of(context).uri.path`（クエリを除いたパス）。判定は純粋関数1つにまとめる（例：`int tabIndexFor(String path)`。`lib/features/shell/app_shell.dart` 内に置く）。
- 例：`/lives/abc/memory/xyz`（記録の作成）はライブ一覧、`/chats/abc` はグッズ交換、`/oshi/search` は推し、`/` はホーム。
- タブを押したら `context.go(移動先)` で移る（タブの切り替えは履歴に積まない）。今のタブをもう一度押したときも、その機能の最初の画面（上の表の移動先）に移る。

#### 見た目

- 画面の幅が **720px 以上**（紹介ページと同じ基準）のときは、画面の左に縦のタブ（`NavigationRail`）を置き、その右に各画面を出す。`labelType: NavigationRailLabelType.all` でラベルを常に出す。タブと画面の間に区切り線（`VerticalDivider(width: 1)`）を入れる。
- 720px 未満（スマホ）のときは、画面の下に横のタブ（`NavigationBar`）を置く。
- 選択中のタブの強調は、Material 3 の標準の表示（選択中の背景の帯と色）を使う。
- 左のタブの一番下に、アカウントのボタン（`Icons.account_circle`、Key：`shell_account_button`）を置く。押すとメニュー（`PopupMenuButton` など）で「プロフィール」（`context.push('/profile')`）と「ログアウト」（`authRepositoryProvider` の `signOut()`）を選べる。
- スマホの幅では、下のタブにアカウントは入れない。代わりに、ホームの `AppBar` の右に、今と同じプロフィールとログアウトのアイコンを置く（3.5 ①）。PC の幅では、ホームの `AppBar` に出さない（左下と重複するため）。

#### 作り方

- 新規ファイル `lib/features/shell/app_shell.dart` に、外枠の画面 `AppShell`（`child` を受け取る）を作る。`LayoutBuilder` か `MediaQuery.sizeOf(context).width` で幅を判定し、上の2つの見た目を切り替える。
- `lib/app.dart` の `routes:` で、ログイン後の画面のルートを `ShellRoute(builder: (context, state, child) => AppShell(child: child), routes: [...])` で包む。**各ルートのパス・画面・入れ子の関係は変えない**（既存の `context.go`・`context.push` のパスがそのまま動くようにする）。
- `ShellRoute` の中に入れるもの：`/`（入れ子ごと）、`/register`、`/live-form`、`/goods`・`/goods/new`・`/goods/:id/edit`、`/trade`・`/trade/board`・`/trade/mine`・`/chats`・`/chats/:id`・`/trade/new`・`/trade/:id/edit`・`/trade/:id`。順番は今と同じにする（`/trade/:id` は `/trade/new` などより後）。
- `ShellRoute` の外に置くもの：`/welcome`、`/login`、`/profile`（初回のプロフィールの作成でタブを出さないため）、`/calendar-test`（接続テスト）。重複している2つ目の `/login` は、並べ替えのついでに消し、1つだけにする。
- `redirect` は変えない。
- 各画面の `Scaffold`・`AppBar` は今のまま残す（外枠の中に各画面の `Scaffold` が入る形になる）。

### 3.4 推しの画面（新規）

- パスは `/oshi`。`/` の入れ子に `oshi` を足し、既存の `oshi/search`・`oshi/request` をその入れ子に移す（パスは `/oshi/search`・`/oshi/request` のまま変わらない）。

```
/                      HomePage
  ├ oshi               OshiPage（新規）
  │  ├ search          OshiSearchPage
  │  └ request         OshiRequestPage
  ├ lives …
  └ memories …
```

- 新規ファイル `lib/features/oshi/oshi_page.dart` に `OshiPage` を作る。
- 内容：`AppBar`（タイトル「推し」）、「推しを探す」ボタン（Key：`oshi_search_button`、`context.push('/oshi/search')`）、見出し「フォロー中の推し」と既存の `FollowingOshiList`。

### 3.5 ホーム（作り直し）

`lib/features/home/home_page.dart` を作り直す。上から順に、次の区画を `ListView` で縦に並べる。区画の部品は `lib/features/home/` に分けて置いてよい（例：`home_upcoming_lives.dart`・`home_new_trades.dart`・`home_recent_memories.dart`）。

| 区画 | 内容 | データ |
|---|---|---|
| ① あいさつ | 左に「こんにちは、◯◯さん」（`displayName`。未取得なら「ゲスト」）。右に「行きたいライブを追加」ボタン（`FilledButton.icon`、`Icons.add`、Key：`home_add_live_button`、`context.push('/lives/add')`）。幅が狭くて並ばないときは、ボタンをあいさつの下に回す（`Wrap` など） | `myProfileProvider` |
| ② 次の締切 | 見出し「次の締切」と、既存の `UpcomingDeadlinesSection` をそのまま置く | 既存 |
| ③ 今後のライブ | 見出し「今後のライブ」＋右に「すべて見る」（`context.go('/lives')`）。自分のライブ一覧のうち `isEnded == false` のものを、`nextStartAt` の近い順に最大 10 件、カードで横に並べる | `liveListProvider` |
| ④ 新しい交換 | 見出し「新しい交換」＋右に「すべて見る」（`context.go('/trade')`）。フォロー中の推しの募集中の投稿を、新しい順に最大 6 件並べる。自分の投稿は除く | 3.6 の新しいプロバイダ |
| ⑤ 最近の思い出 | 見出し「最近の思い出」＋右に「すべて見る」（`context.go('/memories')`）。`attended` を新しい順に最大 10 件、カードで横に並べる | `memoryAlbumProvider` |

- 右下の `FloatingActionButton`（`home_add_live_fab`）は、①のボタンに置き換えるため削除する。
- 旧ボタン4つ（`home_search_button` など）は、タブに置き換えるため削除する。`FollowingOshiList` は推しの画面（3.4）に移すため、ホームからは外す。
- `AppBar`：タイトルは「おしあし」。スマホの幅のときだけ、右にプロフィール（`/profile`）とログアウトのアイコンを置く（3.3）。

#### ③ 今後のライブのカード

- 幅 220px 程度、高さはそろえる（横に並べる `ListView` の高さを固定し、カードはその高さに合わせる）。
- 中身：ライブ名（最大2行、はみ出しは省略）、次の公演の日時（`formatDateTime(nextStartAt)`）、次の公演の会場（`performances` のうち開演が `nextStartAt` のものの `venue`）。次の公演の日付まで7日以内なら、日数（「あと3日」など）を強調して出してよい（D-4 で提案）。
- 押すと `context.push('/lives/${live.id}')`。
- Key：一覧は `home_upcoming_lives`、カードは `home_upcoming_live_${live.id}`。

#### ④ 新しい交換の表示

- 1件ごとに、投稿者名（`displayName`）、`TradePostSummaryLines` による要約、更新日時を出す。押すと `context.push('/trade/${post.id}')`。
- 横に並べるか縦に並べるかは、D-5 で案を示して決める（9章）。
- Key：一覧は `home_new_trades`、1件は `home_new_trade_${post.id}`。

#### ⑤ 最近の思い出のカード

- メモリー一覧の参戦済みのカード（`lib/features/memory/memory_list_page.dart` の `_AlbumCard`）と同じ見た目にする（表紙の代わりのアイコンの枠、ライブ名、日付、会場）。共通の部品として切り出すかは D-4 で提案する（`_AlbumCard` は private のため、そのままでは使えない）。
- 押すと `context.push('/memories/${memory.performanceId}')`。
- Key：一覧は `home_recent_memories`、カードは `home_recent_memory_${performanceId}`。

#### ③〜⑤の状態ごとの表示

| 状態 | 表示 |
|---|---|
| 読み込み中 | 区画の中に小さな `CircularProgressIndicator` |
| エラー | 「読み込めませんでした」（区画ごと。ほかの区画は表示を続ける） |
| 0件 | ③「行きたいライブを追加すると、ここに出ます」、④「フォロー中の推しの交換の投稿は、まだありません」、⑤「参戦したライブを記録すると、ここに出ます」 |

### 3.6 新しい交換のプロバイダ（D-5）

- `lib/providers/trade_post_providers.dart` に `homeTradePostsProvider`（`Provider.autoDispose<AsyncValue<List<TradePost>>>`）を足す。
- 中身：`followingOshisProvider` の推しのうち先頭の最大 10 件について、`openTradePostsProvider((kind: o.kind, id: o.id, limit: 5))` を `ref.watch` し、`mergeBoardPosts` でまとめる。その結果から `uid == currentUid` の投稿を除き、先頭の 6 件を返す。
- どれかがエラーならエラー、どれかが読み込み中なら読み込み中（`tradeBoardProvider` と同じ扱い）。フォロー中の推しが0件なら、空の一覧を返す。
- 新しい Firestore の検索・インデックスは追加しない（`openTradePostsProvider` の既存の検索を使う）。読み取りは、ホームを開いたときに「推しの数 × 最大5件」まで。

### 3.7 そのほか

- 新しいパッケージは追加しない。
- データ構造・セキュリティルールは変えない。

## 4. 画面構成

| 画面 | 内容 |
|---|---|
| 外枠 `AppShell`（新規） | タブ（PC は左、スマホは下）、PC は左下にアカウントのボタン。中に各画面を出す |
| ホーム `HomePage`（作り直し） | 3.5 の5つの区画 |
| 推し `OshiPage`（新規） | 「推しを探す」と、フォロー中の推し |

## 5. 非機能要件

- スマホの幅（360px）と PC の幅（1280px 程度）の両方で、表示が崩れない（はみ出しの警告が出ない）。
- ホームを開いたときの読み取りは、既存のプロバイダと 3.6 の範囲に限る。
- 紹介ページ・ログイン画面・初回のプロフィールの作成では、タブを出さない。

## 6. ファイル構成（予定）

| ファイル | 変更 | 内容 |
|---|---|---|
| `lib/app.dart` | 変更（A と共有） | テーマ、`scrollBehavior`、`ShellRoute`、`/oshi` のルート、重複した `/login` の削除 |
| `lib/features/shell/app_shell.dart` | 新規 | 外枠（タブ、アカウントのボタン、`tabIndexFor`） |
| `lib/features/oshi/oshi_page.dart` | 新規 | 推しの画面 |
| `lib/features/home/home_page.dart` | 作り直し（A と共有） | ホーム |
| `lib/features/home/home_*.dart` | 新規 | ホームの区画（③④⑤） |
| `lib/providers/trade_post_providers.dart` | 変更 | `homeTradePostsProvider` |
| `lib/features/memory/memory_list_page.dart` | 変更（D-4 で提案した場合のみ） | `_AlbumCard` を共通の部品にする |

## 7. 開発ステップ

| Step | 内容 | 完了の目安 | 状況 |
|---|---|---|---|
| D-1 | テーマ（3.1）と、マウスでの横スクロール（3.2）。茶色の値は候補を示して確認を取る | 全画面が茶色基調になる。`flutter analyze` 0 件 | |
| D-2 | 外枠とタブ（3.3）、推しの画面（3.4）、重複した `/login` の削除 | 8章の「タブ」の確認がすべて通る | |
| D-3 | ホームの①②、旧ボタン・FAB・フォロー中の推しの削除、`AppBar` の出し分け | ホームが①②だけになり、行きたいライブの追加ができる | |
| D-4 | ホームの③今後のライブ・⑤最近の思い出 | 横に並び、PC のマウスで動かせる。押すと詳細に移る | |
| D-5 | ホームの④新しい交換（3.6 のプロバイダを含む） | フォロー中の推しの他人の投稿が新しい順に出る | |

- D-2・D-3 は A の担当範囲（ルーター・ホーム）にかかわるため、着手前に A と共有する。
- D-3 以降で `test/features/home_following_test.dart` が通らなくなる（2.4）。各ステップで、通らなくなるテストを示す。

## 8. 確認すること（各ステップの終わりに画面で確認）

### タブ（D-2）

- どの画面からでもタブで5つの機能に移れ、今いる機能のタブが選択中になる。
- 詳細画面でも、その機能のタブが選択中になる（例：ライブの詳細→ライブ一覧、チャット→グッズ交換、推しを探す→推し）。
- PC の幅では左、スマホの幅では下にタブが出る。ブラウザの幅を変えると切り替わる。
- 左下のアカウントのボタンから、プロフィールを開け、ログアウトできる。ログアウトすると紹介ページに移る。
- 紹介ページ・ログイン画面・初回のプロフィールの作成では、タブが出ない。
- 既存の画面の「戻る」が、これまでどおり動く。

### ホーム（D-3〜D-5）

- 「行きたいライブを追加」でライブの追加画面に移る。
- ③〜⑤の各カード・各行から、それぞれの詳細に移れる。「すべて見る」で一覧に移れる。
- ③〜⑤が0件のとき、案内が出る。
- PC のマウスで、横に並べた区画をドラッグしてスクロールでき、スクロールバーが出る。
- スマホの幅（360px）で、はみ出しの警告が出ない。

## 9. 未決定事項

以下は未決定である。LLM は独自に確定させず、提案として提示すること。

- 茶色の具体的な値（D-1 で、色見本とあわせて3案程度を示す）
- ダークモードに対応するか（今回は対応しない前提）
- ④新しい交換を、横に並べるか、縦の一覧にするか（D-5 で案を示す）
- ③のカードで、次の公演までの日数を強調するか（D-4 で案を示す）
- ⑤のカードのために、`_AlbumCard` を共通の部品にするか（D-4 で案を示す）
- 各画面の `AppBar` の見直し（外枠のタブと役割が重なる「戻る」やタイトルの扱い）
- フォントの変更（今回は標準のまま）