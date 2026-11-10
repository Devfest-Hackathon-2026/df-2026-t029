# おしあしホームと画面移動のデザイン 仕様書
 
> 本ドキュメントは、アプリ全体のテーマ（色）とユーザーによるテーマカラーの設定、画面を移るためのタブ（外枠）、推しの画面、ホーム画面の作り直しの仕様書である。
> チームメンバーおよび開発支援に使う LLM が、この文書だけを読んで同じ前提で作業できるように、現状のコードの構造と、変更後の具体的な形を書いている。
> 「決定事項」と「未決定事項」を分けて記載している。ホームの構成は、横山の手書きの案（2026-11-07）をもとにしている。
> 前提として、プロジェクト仕様書（`markdown/app_config.md`）、データベース設計案（`markdown/Database_config.md`）、`CLAUDE.md` をあわせて参照すること。
> 改訂：11/7 テーマカラーをユーザーが設定できるようにする（3.1・3.8・D-6）を追加。11/7 タブの順番を「ホーム・推し・ライブ一覧・グッズ交換・メモリー」に変更（推しの優先度が高いため）。11/7 D-1〜D-6 完了。実装時に決めたことを 3.9 に追記。
 
## 0. LLM への指示
 
- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。
- 「9. 未決定事項」に挙げた項目は独自に確定させず、必ず「提案」として、比べた案・選ぶ理由・捨てる案を添えて示すこと。
- 本仕様にない機能・作業を勝手に足さないこと。**テストコードは書かない**（ユーザーの方針）。既存のテストが壊れる場合は、壊れるテスト名と理由を示し、直すかどうかは人間が決める。
- 各ステップの終わりに `flutter analyze` で指摘が 0 件（info を含む）であることを確認し、1行程度の短いコミット文を添えること。
- **コードの編集は人間が Dev Container（Docker コンテナ）内で行う。** LLM はリポジトリを読むだけにして、変更は「どのファイルの、どこを、どう変えるか」がわかるコードとして提示すること。ファイルに直接書き込まないこと。
- 既存のコードの書き方に合わせること（Riverpod 3 を手書き・コード生成なし、画面遷移は go_router、Firebase へのアクセスは `lib/repositories/` に閉じ込める、`await` の後は `context.mounted` を確認、文言・コメントは日本語）。
- 本ドキュメントや仕様書などの MD ファイルは、ユーザーの依頼なしに変更しないこと。
- `firebase deploy`（ルールを含む）は人間が行う。
## 1. 概要
 
| 項目 | 内容 |
|---|---|
| 機能名 | ホームと画面移動のデザイン |
| 担当 | B（横山）。ルーター（`lib/app.dart`）とホーム（`lib/features/home/`）は A（とし）の担当範囲のため、A と共有する。紹介ページ（`/welcome`）の見た目は A が作り直している |
| 目的 | 見た目を整え、どの画面からでも主な機能へ移れるようにし、ホームで「次にやること」と最近の動きがひと目でわかるようにする。テーマカラーを自分の推しの色にできるようにする |
| 背景 | 審査基準の「対象ユーザーが目的を達成できる UI・UX になっているか」の点を伸ばすため（11/7 の自己評価で最も伸ばせる項目） |
| ブランチ | `features/home-design` |
| 状況 | D-1〜D-6 完了（11/7） |
 
### 1.1 作業前の問題
 
- 色・文字が Flutter の標準（紫）のままで、無骨に見えた。`MaterialApp.router` に `theme` を設定していなかった。
- ホームは、機能へのボタン4つが縦に並ぶだけ。ほかの画面からホームに戻らないと、別の機能に移れなかった。
- 今どの機能を開いているかがわからなかった。
### 1.2 変更後の利用の流れ
 
1. ログイン後、PC の幅では画面の左に、スマホの幅では画面の下に、5つのタブ（ホーム・推し・ライブ一覧・グッズ交換・メモリー）が常に出る。
2. タブを押すと、その機能の画面に移る。今いる機能のタブは強調される。詳細画面（ライブの詳細など）でも、その機能のタブが強調されたまま。
3. ホームでは、上から「あいさつと行きたいライブの追加」「次の締切」「今後のライブ」「新しい交換」「最近の思い出」を見られ、それぞれの詳細・一覧に移れる。
4. プロフィールの編集画面でテーマカラーを選ぶと、ログイン後の全画面がその色になる。ほかの端末でログインしても同じ色になる。
## 2. 作業前のコードの構造（11/7 時点の `dev`）
 
### 2.1 `lib/app.dart`
 
- `routerProvider`（`Provider<GoRouter>`）でルーターを作る。`redirect` で、未ログインなら `/welcome`、プロフィール未作成なら `/profile` に移す（紹介ページの仕様書 W-1 で実装済み）。
- `App`（`ConsumerWidget` の `MaterialApp.router`）は `title: 'おしあし'` と `routerConfig` だけを渡しており、`theme`・`scrollBehavior` は未設定だった（D-1 で設定済み）。
- D-2 より前のルートの構成（`routes:` の中、上から順）：
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
### 2.2 `lib/features/home/home_page.dart`（作業前・99 行）
 
- `AppBar`（タイトル「おしあし」、右にプロフィール `/profile` とログアウトのアイコン）。
- 本文は `ListView`：「ようこそ、◯◯ さん」→ ボタン4つ（`home_search_button`：推しを探す、`home_live_list_button`：ライブ一覧、`home_trade_button`：グッズ交換、`home_memory_button`：メモリー）→「次の締切」＋ `UpcomingDeadlinesSection` →「フォロー中の推し」＋ `FollowingOshiList`。
- 右下に `FloatingActionButton.extended`（`home_add_live_fab`、「ライブを追加する」→ `/lives/add`）。
### 2.3 プロフィールの保存（テーマカラーの保存先にかかわる）
 
- プロフィールは `users/{uid}` ドキュメントの `displayName`・`xAccount`・`profileUpdatedAt` に保存する（`lib/models/user_profile.dart` の `UserProfile`、`lib/repositories/profile_repository.dart` の `ProfileRepository`／`FirestoreProfileRepository`）。
- `UserProfile.fromFirestore` は、`profileUpdatedAt` が無いドキュメントを「プロフィール未作成」として null を返す。
- `myProfileProvider`（`lib/providers/profile_providers.dart`）は、ログイン中のユーザーの `UserProfile?` を購読する。
- セキュリティルール（`firestore.rules`）の `match /users/{userId}` は、本人だけが読み書きでき、`isValidUserFields` で既知の項目だけを検査している。未知の項目は検査されない（`hasOnly` を使っていない）。
- プロフィールの画面は `lib/features/profile/profile_page.dart`（`/profile`。G-8 で B が作成）。
### 2.4 使う既存の部品・プロバイダ
 
| 名前 | 場所 | 内容 |
|---|---|---|
| `UpcomingDeadlinesSection` | `lib/features/live/upcoming_deadlines_section.dart` | 次の締切の一覧（読み込み中・エラー・0件の表示、「すべて見る」を含む） |
| `FollowingOshiList` | `lib/features/oshi/following_oshi_list.dart` | フォロー中の推しの一覧と解除（Key は `home_following_*`） |
| `myProfileProvider` | `lib/providers/profile_providers.dart` | 自分のプロフィール |
| `liveListProvider` | `lib/providers/live_providers.dart` | 自分のライブ一覧（`AsyncValue<List<LiveListEntry>>`）。`LiveListEntry` は `live`・`performances`（開演順）・`nextStartAt`（今日以降で最も早い公演の開演。終了なら null）・`isEnded` を持つ（`lib/utils/deadline.dart`） |
| `nowProvider` | `lib/providers/live_providers.dart` | 今の時刻（1分ごとに更新） |
| `memoryAlbumProvider` | `lib/providers/memory_providers.dart` | 記録の一覧（`AsyncValue<MemoryAlbum>`）。`attended` は参戦済みを新しい順 |
| `followingOshisProvider` | `lib/providers/oshi_providers.dart` | フォロー中の推し（`AsyncValue<List<OshiSummary>>`） |
| `openTradePostsProvider` | `lib/providers/trade_post_providers.dart` | 推し1つの募集中の投稿（family。引数 `({OshiKind kind, String id, int limit})`）。既存の複合インデックスで動く |
| `mergeBoardPosts` | `lib/utils/trade_board.dart` | 複数の投稿リストを、重複を除いて更新日時の新しい順にまとめる（`(List<List<TradePost>> lists, int limit)`。戻り値 `TradeBoard` の `posts`） |
| `TradePostSummaryLines` | `lib/features/trade/trade_post_summary_lines.dart` | 投稿の要約（タグ・譲・求・更新日時など）の表示行 |
| `currentUidProvider` | `lib/providers/oshi_providers.dart` | ログイン中の uid |
| `authRepositoryProvider` | `lib/repositories/auth_repository.dart` | `signOut()` |
| `formatDateTime` | `lib/features/live_form/date_time_field.dart` | 日時の表示用の文字列 |
 
### 2.5 ホームに依存する既存のテスト
 
- `test/features/home_following_test.dart`：作業前の `HomePage` の Key・FAB・`FollowingOshiList` を確かめていたため、D-3 以降は通らない。ユーザーの判断で、直さない（11/7）。
## 3. 決定事項
 
### 3.1 テーマ（色）
 
- テーマは Material 3 とし、`MaterialApp.router` の `theme` に `ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: <基準の色>), useMaterial3: true)` を設定する。ボタン・選択中のタブ・カードなどの色は、基準の色から自動で作られる。
- **基準の色は、`lib/app.dart` に直書きせず、プロバイダ `themeSeedColorProvider`（`Provider<Color>`、`lib/providers/theme_providers.dart`）から読む。** `App` は `ref.watch(themeSeedColorProvider)` の色でテーマを作る。
  - ユーザーがテーマカラーを設定していれば、その色（3.8）。
  - 設定していない・未ログイン・プロフィール未作成・読み込み中なら、初期の色 `kDefaultSeedColor`。
- **初期の色**は、A が作り直している紹介ページの色に合わせる。値が決まるまでは、茶色（`0xFF795548`）を仮に置く。値が決まったら `kDefaultSeedColor` の1か所だけを直す。
- 紹介ページ・ログイン画面は未ログインで表示されるため、常に初期の色になる。
- 各画面の色は、テーマ（`Theme.of(context).colorScheme`）から取る。画面ごとに色を直書きしない（テーマカラーの変更が全画面に効くようにするため）。例外は、色見本そのものの表示（3.8）と、A が作る紹介ページ。
- 初期の色を落ち着いた色にし、テーマカラーを変えられるようにする理由（提出ドキュメントの「選定理由」に使う）：
  - 推し活の色はメンバーカラーで人それぞれ。初期の色は主張しない色にし、ユーザーが自分の推しの色に変えられるようにする。
  - 中心の機能は申込・入金の期限を逃さない予定管理。落ち着いた色で、長く使う道具としての信頼感を出す。
  - ピンクが多い既存の推し活アプリと、見た目で区別する。
- 捨てた案：ピンク系の固定（推し活らしいが、既存のアプリと似て、推しの色とも合わないことがある）、今の紫を整えるだけ（印象が変わらない）。
### 3.2 マウスでの横スクロール
 
- Flutter Web は、標準ではマウスのドラッグで横にスクロールできない（`ScrollBehavior.dragDevices` にマウスが含まれない）。`MaterialApp.router` の `scrollBehavior` に、マウスのドラッグを許す `_AppScrollBehavior`（`MaterialScrollBehavior` を継承し、`dragDevices` に `PointerDeviceKind.mouse` を足したもの）を設定する。
- 横に並べる区画には、スクロールバー（`Scrollbar`、`thumbVisibility: true`）を出して、横に続きがあることがわかるようにする。
### 3.3 画面を移るためのタブ（外枠）
 
#### タブと、選択中にするパス
 
推しの優先度が高いため、推しをホームの次に置く。
 
| 順 | タブ | アイコン | 押したときの移動先 | 選択中にするパス（上から順に判定） |
|---|---|---|---|---|
| 0 | ホーム | `Icons.home_outlined`／選択中 `Icons.home` | `/` | 1〜4 のどれにも当たらないとき |
| 1 | 推し | `Icons.favorite_outline`／`Icons.favorite` | `/oshi` | `/oshi` |
| 2 | ライブ一覧 | `Icons.event_note_outlined`／`Icons.event_note` | `/lives` | `/lives`・`/register`・`/live-form` |
| 3 | グッズ交換 | `Icons.swap_horiz` | `/trade` | `/trade`・`/chats`・`/goods` |
| 4 | メモリー | `Icons.photo_album_outlined`／`Icons.photo_album` | `/memories` | `/memories` |
 
- 「`/lives`」に当たるとは、パスが `/lives` そのもの、または `/lives/` で始まること。
- 判定に使うパスは、`ShellRoute` の `builder` に渡される `state.uri.path`（クエリを除いたパス）。判定は純粋関数 `int tabIndexFor(String path)` にまとめ、`lib/features/shell/app_shell.dart` に置く。
- タブを押したら `context.go(移動先)` で移る（タブの切り替えは履歴に積まない）。
#### 見た目
 
- 画面の幅が **720px 以上**（定数 `kShellWideBreakpoint`）のときは、画面の左に縦のタブ（`NavigationRail`、`labelType: NavigationRailLabelType.all`）を置き、区切り線（`VerticalDivider(width: 1)`）の右に各画面を出す。720px 未満（スマホ）のときは、画面の下に横のタブ（`NavigationBar`）を置く。
- 選択中のタブの強調は、Material 3 の標準の表示を使う。色はテーマカラーに従う。
- 左のタブの一番下（`trailing` に `Expanded` ＋ `Align(alignment: Alignment.bottomCenter)`）に、アカウントのボタン（`PopupMenuButton`、Key：`shell_account_button`）を置く。「プロフィール」（`context.push('/profile')`）と「ログアウト」（`signOut()`）を選べる。
- スマホの幅では、ホームの `AppBar` の右に、プロフィールとログアウトのアイコンを置く。PC の幅では、ホームの `AppBar` に出さない。
- Key：縦のタブは `shell_rail`、横のタブは `shell_bottom_bar`。
#### 作り方
 
- `lib/features/shell/app_shell.dart` の `AppShell`（`location` と `child` を受け取る `StatelessWidget`）。
- `lib/app.dart` の `routes:` で、ログイン後の画面のルートを `ShellRoute(builder: (context, state, child) => AppShell(location: state.uri.path, child: child), routes: [...])` で包む。各ルートのパス・画面・入れ子の関係は変えない。
- `ShellRoute` の外：`/welcome`、`/login`、`/profile`（初回のプロフィールの作成でタブを出さないため）、`/calendar-test`。重複していた2つ目の `/login` は削除した。
- `redirect` は変えない。各画面の `Scaffold`・`AppBar` は今のまま（外枠の中に各画面の `Scaffold` が入る）。
### 3.4 推しの画面
 
- パスは `/oshi`。`/` の入れ子に `oshi` を足し、既存の `oshi/search`・`oshi/request` をその入れ子に移した（パスは変わらない）。
- `lib/features/oshi/oshi_page.dart` の `OshiPage`：`AppBar`（「推し」）、「推しを探す」ボタン（Key：`oshi_search_button`）、見出し「フォロー中の推し」と `FollowingOshiList`。
### 3.5 ホーム
 
`lib/features/home/home_page.dart`。上から順に、次の区画を `ListView`（Key：`home_page`）で縦に並べる。
 
| 区画 | 内容 | 部品・データ |
|---|---|---|
| ① あいさつ | 「こんにちは、◯◯さん」（Key：`home_greeting`）と「行きたいライブを追加」（Key：`home_add_live_button`、`context.push('/lives/add')`）。`Wrap` で、幅が狭いときはボタンを下に回す | `home_page.dart` の `_Greeting`、`myProfileProvider` |
| ② 次の締切 | 見出し「次の締切」と `UpcomingDeadlinesSection` | 既存 |
| ③ 今後のライブ | 終わっていないライブを次の公演の近い順に最大 10 件、カード（幅 220・高さ 150）で横に並べる。「すべて見る」で `/lives` | `home_upcoming_lives.dart` の `HomeUpcomingLives`、`liveListProvider`・`nowProvider` |
| ④ 新しい交換 | フォロー中の推しの、ほかの人の募集中の投稿を新しい順に最大 6 件、縦に並べる。「すべて見る」で `/trade` | `home_new_trades.dart` の `HomeNewTrades`、`homeTradePostsProvider` |
| ⑤ 最近の思い出 | 参戦済みの記録を新しい順に最大 10 件、カード（幅 180・高さ 220）で横に並べる。「すべて見る」で `/memories` | `home_recent_memories.dart` の `HomeRecentMemories`、`memoryAlbumProvider` |
 
- 共通の部品：`home_section_header.dart`（`HomeSectionHeader`：見出しと「すべて見る」、`HomeSectionMessage`：案内・エラーの文言、`HomeSectionLoading`：読み込み中）、`home_horizontal_list.dart`（`HomeHorizontalList`：スクロールバー付きの横の一覧。専用の `ScrollController` を持つ）。
- 作業前の旧ボタン4つ・右下の FAB・フォロー中の推しは、ホームから外した。
- カードや行を押すと、`context.push` で詳細に移る（戻るとホームに戻る）。「すべて見る」は `context.go`。
- Key：③ 一覧 `home_upcoming_lives`・カード `home_upcoming_live_${liveId}`、④ 一覧 `home_new_trades`・1件 `home_new_trade_${postId}`、⑤ 一覧 `home_recent_memories`・カード `home_recent_memory_${performanceId}`。
#### ③〜⑤の状態ごとの表示
 
| 状態 | 表示 |
|---|---|
| 読み込み中 | 区画の中に小さな `CircularProgressIndicator` |
| エラー | 「読み込めませんでした」（区画ごと。ほかの区画は表示を続ける） |
| 0件 | ③「行きたいライブを追加すると、ここに出ます」、④「フォロー中の推しの交換の投稿は、まだありません」、⑤「参戦したライブを記録すると、ここに出ます」 |
 
### 3.6 新しい交換のプロバイダ
 
- `lib/providers/trade_post_providers.dart` の `homeTradePostsProvider`（`Provider.autoDispose<AsyncValue<List<TradePost>>>`）。
- `followingOshisProvider` の推しのうち先頭の最大 10 件について、`openTradePostsProvider((kind, id, limit: 5))` を `ref.watch` し、`mergeBoardPosts(…, 50)` でまとめ、`uid == currentUid` の投稿を除いて先頭の 6 件を返す。
- どれかがエラーならエラー、どれかが読み込み中なら読み込み中。フォロー中の推しが0件なら空の一覧。
- 新しい Firestore の検索・インデックスは追加しない。読み取りは、ホームを開いたときに「推しの数 × 最大5件」まで。
### 3.7 そのほか
 
- 新しいパッケージは追加しない。
- データ構造・ルールの変更は、3.8 の `themeColor` だけ。
### 3.8 テーマカラーの設定
 
#### 保存先
 
- `users/{uid}` ドキュメントの任意の項目 `themeColor`（int。色の ARGB の32ビット値。例：`0xFFE91E63`）。無い場合は初期の色。
- `markdown/Database_config.md` の `users` の項目に `themeColor` を追記する（人間が行う）。
#### セキュリティルール
 
- `isValidUserFields` に、`(!('themeColor' in data) || (data.themeColor is int && data.themeColor >= 0 && data.themeColor <= 4294967295))` を足した。デプロイは人間が行う（既存のルールは未知の項目を拒否しないため、デプロイ前でも保存はできる）。
#### モデル・リポジトリ・プロバイダ
 
- `UserProfile.themeColor`（`int?`）。`fromFirestore` で、int でなければ null。
- `ProfileRepository.saveThemeColor(String uid, int? color)`：`users/{uid}` の `themeColor` だけを `update` する。null なら `FieldValue.delete()`。`profileUpdatedAt` は変えない。
- `themeSeedColorProvider`：`myProfileProvider` の値の `themeColor` があれば `Color(themeColor)`、無ければ `kDefaultSeedColor`。
#### 画面
 
- `lib/features/profile/theme_color_picker.dart` の `ThemeColorPicker` を、プロフィールの**編集**画面の「保存」ボタンの下（区切り線の下）に置く。初回の作成画面には出さない。
- 色見本（丸いボタン、40×40）を押すとすぐに保存し、アプリ全体の色が変わる。選択中の色には、色の明るさに合わせた白か黒のチェックを付ける。保存中は押せない。保存に失敗したら SnackBar を出す。
- 「初期の色に戻す」（Key：`theme_color_reset`）で `themeColor` を消す。未設定のときは押せない。
- Key：色見本は `theme_color_${ARGBの16進}`。
### 3.9 実装時に決めたこと（11/7）
 
| 項目 | 決めたこと | 理由・捨てた案 |
|---|---|---|
| ③ カードの日数 | 次の公演の日付が7日以内なら、カードの上に「あと◯日」「今日」の印を出す（日付で数える） | 直近のライブを目立たせる |
| ⑤ のカード | メモリー一覧の `_AlbumCard` を、共通の部品 `MemoryAlbumCard`（`lib/features/memory/memory_album_card.dart`。押したときの動きは呼ぶ側が `onTap` で渡す）に切り出し、メモリー一覧とホームで使う | 同じ見た目を2か所に書かない。M-5 の写真も1か所で直せる |
| ④ の並べ方 | 縦の一覧（カード。投稿者名と `TradePostSummaryLines`） | 投稿ごとに文字の量が大きく違い、横のカードでは譲・求が省略されて読めなくなる。捨てた案：横のカード（ライブ・思い出と見た目はそろう） |
| テーマカラーの色見本 | 赤 `E53935`・ピンク `EC407A`・オレンジ `FB8C00`・黄 `FDD835`・黄緑 `7CB342`・緑 `43A047`・水色 `29B6F6`・青 `1E88E5`・紺 `283593`・紫 `8E24AA`・白 `FFFFFF`・黒 `212121` の12色（`kThemeColorPresets`） | メンバーカラーでよく使われる色。白・黒はグレー基調になる |
| カラーコードの自由入力 | 今回は入れない | 締切までの時間が限られるため |
| 初回のプロフィール作成時のテーマカラー | 出さない（編集画面だけ） | 最初の手順を短く保つ |
 
## 4. 画面構成
 
| 画面 | 内容 |
|---|---|
| 外枠 `AppShell` | タブ（PC は左、スマホは下）、PC は左下にアカウントのボタン。中に各画面を出す |
| ホーム `HomePage` | 3.5 の5つの区画 |
| 推し `OshiPage` | 「推しを探す」と、フォロー中の推し |
| プロフィール `ProfilePage` | 編集画面にテーマカラーの欄（3.8） |
 
## 5. 非機能要件
 
- スマホの幅（360px）と PC の幅（1280px 程度）の両方で、表示が崩れない（はみ出しの警告が出ない）。
- ホームを開いたときの読み取りは、既存のプロバイダと 3.6 の範囲に限る。
- 紹介ページ・ログイン画面・初回のプロフィールの作成では、タブを出さない。
- テーマカラーは本人だけが読み書きできる（既存の `users/{uid}` のルールのまま）。
- どのテーマカラーでも、文字と背景の色の差は `ColorScheme.fromSeed` に任せる（画面で色を直書きしない）。
## 6. ファイル構成
 
| ファイル | 変更 | 内容 |
|---|---|---|
| `lib/providers/theme_providers.dart` | 新規（D-1・D-6） | `kDefaultSeedColor`、`themeSeedColorProvider` |
| `lib/app.dart` | 変更（A と共有） | テーマ、`scrollBehavior`、`ShellRoute`、`/oshi` のルート、重複した `/login` の削除 |
| `lib/features/shell/app_shell.dart` | 新規（D-2） | 外枠（タブ、アカウントのボタン、`tabIndexFor`、`kShellWideBreakpoint`） |
| `lib/features/oshi/oshi_page.dart` | 新規（D-2） | 推しの画面 |
| `lib/features/home/home_page.dart` | 作り直し（D-3〜D-5・A と共有） | ホーム |
| `lib/features/home/home_section_header.dart` | 新規（D-3・D-4） | 見出し・案内・読み込み中 |
| `lib/features/home/home_horizontal_list.dart` | 新規（D-4） | 横の一覧 |
| `lib/features/home/home_upcoming_lives.dart` | 新規（D-4） | ③ 今後のライブ |
| `lib/features/home/home_recent_memories.dart` | 新規（D-4） | ⑤ 最近の思い出 |
| `lib/features/home/home_new_trades.dart` | 新規（D-5） | ④ 新しい交換 |
| `lib/features/memory/memory_album_card.dart` | 新規（D-4） | 参戦済みの記録のカード（共通） |
| `lib/features/memory/memory_list_page.dart` | 変更（D-4） | `_AlbumCard` を `MemoryAlbumCard` に置き換え |
| `lib/providers/trade_post_providers.dart` | 変更（D-5） | `homeTradePostsProvider` |
| `lib/models/user_profile.dart` | 変更（D-6） | `themeColor` |
| `lib/repositories/profile_repository.dart` | 変更（D-6） | `saveThemeColor` |
| `lib/features/profile/theme_color_picker.dart` | 新規（D-6） | テーマカラーの選択 |
| `lib/features/profile/profile_page.dart` | 変更（D-6） | テーマカラーの欄 |
| `firestore.rules` | 変更（D-6） | `isValidUserFields` に `themeColor` の検査 |
 
## 7. 開発ステップ
 
| Step | 内容 | 状況 |
|---|---|---|
| D-1 | テーマ（3.1）と、マウスでの横スクロール（3.2） | 完了 |
| D-2 | 外枠とタブ（3.3）、推しの画面（3.4）、重複した `/login` の削除 | 完了 |
| D-3 | ホームの①②、旧ボタン・FAB・フォロー中の推しの削除、`AppBar` の出し分け | 完了 |
| D-4 | ホームの③今後のライブ・⑤最近の思い出、`MemoryAlbumCard` の切り出し | 完了 |
| D-5 | ホームの④新しい交換（3.6 のプロバイダを含む） | 完了 |
| D-6 | テーマカラーの設定（3.8） | 完了（ルールのデプロイと `Database_config.md` の追記は人間が行う） |
 
## 8. 確認すること（画面で確認）
 
### タブ
 
- どの画面からでもタブで5つの機能に移れ、今いる機能のタブが選択中になる。タブの順番は「ホーム・推し・ライブ一覧・グッズ交換・メモリー」。
- 詳細画面でも、その機能のタブが選択中になる（例：推しを探す→推し、ライブの詳細→ライブ一覧、チャット→グッズ交換）。
- PC の幅では左、スマホの幅では下にタブが出る。
- 左下のアカウントのボタンから、プロフィールを開け、ログアウトできる。
- 紹介ページ・ログイン画面・初回のプロフィールの作成では、タブが出ない。
### ホーム
 
- 「行きたいライブを追加」でライブの追加画面に移る。
- ③〜⑤の各カード・各行から、それぞれの詳細に移れる。「すべて見る」で一覧に移れる。0件のとき、案内が出る。
- PC のマウスで、横に並べた区画をドラッグしてスクロールでき、スクロールバーが出る。
- スマホの幅（360px）で、はみ出しの警告が出ない。
### テーマカラー
 
- プロフィールの編集画面で色を選ぶと、すぐにアプリ全体の色が変わる。再読み込み・別のブラウザでも選んだ色のまま。
- 「初期の色に戻す」で初期の色に戻る。ログアウトすると、紹介ページ・ログイン画面は初期の色になる。
- 明るい色・濃い色を選んでも、文字が読める。
## 9. 未決定事項
 
以下は未決定である。LLM は独自に確定させず、提案として提示すること。
 
- 初期の色の具体的な値（A の紹介ページの色に合わせる。それまでは仮に `0xFF795548`）
- テーマの色の作り方の調整（`ColorScheme.fromSeed` の標準は選んだ色をやわらげるため、選んだ色に近づけたい場合は `dynamicSchemeVariant` の変更を検討する）
- カラーコードの自由入力（今回は入れない）
- ダークモードに対応するか（今回は対応しない前提）
- 各画面の `AppBar` の見直し（外枠のタブと役割が重なる「戻る」やタイトルの扱い）
- フォントの変更（今回は標準のまま）