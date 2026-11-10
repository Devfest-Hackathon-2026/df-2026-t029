# おしあし提出前の改善の方針書（Fc）
 
> 本ドキュメントは、11/7 夜にユーザー（横山）が挙げた改善の候補（推しページ・推しを探す・掲示板・PC の横幅・推しの色）を、提出（11/10 19:00）までに進めるための方針書である。
> チームメンバーおよび開発支援に使う LLM が、この文書だけを読んで同じ前提で作業できるように、今の作り・直し方・変えるファイルを具体的に書いている。
> 前提として、`markdown/Database_config.md`・`CLAUDE.md`・`markdown/fixes/fix_Fb.md`・`markdown/spec/goods_spec.md` をあわせて参照すること。
 
## 0. LLM への指示
 
- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。「9. 未決定事項」は独自に確定させず、提案として示すこと。
- 本仕様にない作業を勝手に足さないこと。**テストコードは書かない**。
- **コードの編集は人間が Dev Container 内で行う。** LLM はリポジトリを読むだけにして、変更は置き換える部分を丸ごと（メソッド・クラス・ファイル単位で）コードとして提示すること。「ここだけ変える」「外側だけ包む」のような部分的な説明はしない。
- 開発は6章のステップの順に進め、各ステップに1行程度のコミット文を添えること。画面の確認は最後にまとめて行う（人が再起動してから、LLM が Chrome で確かめてよい）。
- 見た目はログイン後のデザイン「ハコ色」（`lib/theme/hako_app_widgets.dart`・`brand_colors.dart`・`hako_fonts.dart`）に合わせる。
- コメントで章を書くときは「Fc 3.1」のように方針書の名前を付ける。
- **`firestore.rules` は変えない**。新しい個人のデータは `users/{uid}/settings/` の下に置く（今のルールの `users/{userId}/{subcollection}/{document=**}` で本人だけが読み書きできる）。
## 1. 概要
 
| 項目 | 内容 |
|---|---|
| 名前 | Fc |
| 担当 | B（横山）。推しの画面・`app` の共通部品（`hako_app_widgets.dart`）は A（とし）の担当範囲なので、A と共有する |
| ブランチ | `features/Fc`（`dev` にマージ済み。PR #50） |
| 状況 | **Fc-1〜Fc-7 完了（11/7、画面で確認済み。8章）** |
 
### 1.1 改善の候補と順番（11/7 夜に決定）
 
| 候補 | ステップ |
|---|---|
| 推しページの絞り込み（グループ／個人）と最推し | Fc-1・Fc-2 |
| グループのメンバーをその場で開く・メンバー全員をフォロー | Fc-3 |
| 推しを探す画面の入れ子とアイコン | Fc-4 |
| 掲示板の最新フィード（フォロー中の推し全部）と、グッズの種別での絞り込み | Fc-5（Fc-5x：選んでいた推しのフォローを外したら「フォロー中すべて」を出す） |
| PC の横幅を使う（まずメモリーを2列） | Fc-6 |
| 推しの色（メンバーの色が無ければグループの色にそろえる） | Fc-7 |
 
## 2. 着手前の作り（11/7 夜時点の `dev`）
 
| 対象 | 場所 | 作り |
|---|---|---|
| 推しページ | `lib/features/oshi/oshi_page.dart` | 「推しを探す」→ 見出し「フォロー中の推し」→ `FollowingOshiList` |
| 1行 | `lib/features/oshi/oshi_list_tile.dart` の `OshiListTile` | アイコン（`Icons.group_outlined`／`Icons.person_outline`、28・墨）・名前・チップ・右にフォローのボタン。推しを探す・メンバーのシートでも使う |
| メンバーのシート | `lib/features/oshi/group_members_sheet.dart` の `showGroupMembersSheet` | 承認済み（名前順）→ 申請中（名前順）。下に「メンバーを申請する」 |
| 推しを探す | `lib/features/oshi/oshi_search_page.dart` | `searchOshis(all, 検索語)` の結果を平らに並べる。グループの行を押すとメンバーのシート |
| 掲示板 | `lib/features/trade/trade_board_view.dart`・`trade_post_providers.dart` | 推しを1つ選ぶ（最初はフォロー中の先頭を自動で選ぶ）→ `tradeBoardProvider`。絞り込みは `BoardFilter`（グッズ・譲／求・タグ・手渡しの公演） |
| グッズの種別 | `GoodsCategory` | 投稿の品目は `goodsId` と表示名だけを持つ |
| 本文の幅 | `HakoPageScaffold`（PC は幅 720 以上。本文の最大幅 `kHakoContentMaxWidth = 640`） | どの画面も1列 |
| メモリー一覧 | `lib/features/memory/memory_list_page.dart` | 参戦予定の行 → 参戦済みのカードのグリッド |
| 色 | テーマカラー（`kThemeColorPresets` の12色） | 推しには色が無い |
 
## 3. 決定事項：推しページ（Fc-1・Fc-2）
 
### 3.1 絞り込み
 
- 見出し「フォロー中の推し」の下に「すべて（n）」「グループ（n）」「個人（n）」のチップ。選んでいるものは墨の地に紙の文字、選んでいないものは白の地に墨の文字（枠は墨 2px の丸）。
- 最初は「すべて」。覚えない。選んだ種別に1件も無いときは「フォロー中のグループはありません」「フォロー中の個人はいません」。
### 3.2 最推し
 
- 1つだけ。保存先 `users/{uid}/settings/favoriteOshi`（`kind`：`group`／`person`、`id`、`updatedAt`）。外すときはドキュメントを消す。
- フォロー中の一覧の各行で、「フォロー中」ボタンの左に☆／★（★は `BrandColors.hall2`）。☆で最推しにする（置き換え）、★で外す。
- 「推しを探す」の下に見出し「最推し」と白い箱（推しの札 44・名前 20・チップ。グループなら押すとメンバーのシート）。いないときは箱を出さず、一覧の上に「☆を押すと最推しに、丸い札を押すと色を選べます」。
- 最推しのフォローを外したら最推しも外す（失敗しても無視）。フォロー中でない最推しは表示しない。
## 4. 決定事項：推し（Fc-3・Fc-4）
 
### 4.1 グループのメンバーをその場で開く（Fc-3）
 
- グループの行を押すと、すぐ下にメンバーが開く（`GroupMembersPanel`）。もう一度押すと閉じる。複数のグループを同時に開ける。開いた状態は覚えない。
- グループの行のチップは「メンバー ▼」（開いているときは「メンバー ▲」）。シートで開く画面では今までどおり「メンバーを見る ›」（`OshiListTile.membersExpanded` が null）。
- 開いた部分：左に字下げ（28）し、左端に墨 2px の縦線。上から「メンバー全員をフォロー（n人）」→ メンバーの行 → 「メンバーを申請する」。
- メンバーの並び（`groupMembersOf`）・全員フォロー（`FollowAllMembersButton`）・申請画面のパス（`memberRequestPath`）は `group_members_panel.dart` にまとめ、シートも使う。シートの見出しの下にも全員フォローのボタンを出す。
- 使う場所：推しページの「フォロー中の推し」、推しを探す。最推しの箱（グループ）はシートで開く。
### 4.2 メンバー全員をフォロー（Fc-3）
 
- 対象は、承認済みで、まだフォローしていないメンバー。n はその人数。0人なら「全員フォロー中」で押せない。承認済みのメンバーがいなければボタンを出さない。
- 押すと1人ずつ順に `runFollowAction` でフォローする（途中は押せない）。結果を「n人をフォローしました」「n人はフォローできませんでした」と SnackBar で出す。
- フォローの上限（種別ごとに200）は先に残りを数え、超える分はフォローせず「フォローできるのは200件までのため、n人はフォローしていません」と出す。
### 4.3 推しを探す画面の入れ子とアイコン（Fc-4）
 
- 検索の結果を `nestOshiResults(results, all)`（`lib/utils/oshi_search.dart`）で入れ子にする。
  - グループ：グループの行（4.1 で開ける）。
  - 所属グループのある個人：単独の行にせず、所属グループの行の下に入れる（所属が複数ならそれぞれ）。検索語があるときは、そのグループを**開いた状態**にし、ヒットした個人の名前を太字にする。検索語が空のときは閉じておく。
  - 所属グループの無い個人：個人の行。
  - 並びは `searchOshis` の結果の順で、最初に出てきた位置。開く・閉じるを押した状態は、検索語を変えたら戻す。
- アイコンを丸い札（`OshiKindBadge`、直径 36）にする。グループは墨の丸に白の `Icons.groups`、個人は白の丸・墨 2px の枠に墨の `Icons.person`。
## 5. 決定事項：掲示板・メモリー・色（Fc-5〜Fc-7）
 
### 5.1 掲示板の最新フィード（Fc-5）
 
- 推しの選択の先頭に「フォロー中すべて」を足し、最初はこれを選ぶ（自動で先頭の推しを選ぶのはやめた）。`boardTargetProvider` が null、または選んでいた推しのフォローを外したときは「フォロー中すべて」（Fc-5x）。
- 「フォロー中すべて」は `tradeFeedProvider(limit)`：フォロー中の推しと、フォロー中の個人の所属グループを重複なく対象にし、推しごとに `openTradePostsProvider` で検索して `mergeBoardPosts` でまとめる。50件ずつ「もっと見る」。
- 推しを1つ選んだときは今までの掲示板。
- 絞り込みに「グッズの種別」（`BoardFilter.categories`。複数選べる）を足した。譲の品目・求の対象（メンバー指定を除く）のどれかが選んだ種別なら合う。譲／求の指定は種別にもかかる。種別は `boardGoodsCategoriesProvider`（対象の範囲のグッズ → 種別）から引き、種別で絞り込むときだけ読む。引けないグッズは合わない。
- 「フォロー中すべて」のときは、グッズと手渡しの公演の欄を出さず（`BoardFilter.withoutTargetOnly`）、「グッズや手渡しの公演で絞り込むときは、推しを1つ選んでください」と出す。
### 5.2 PC の横幅を使う（Fc-6）
 
- `HakoPageScaffold` に `maxContentWidth`（省略時は `kHakoContentMaxWidth`）を足した。
- メモリー一覧は `maxContentWidth: 1080`。本文の幅が 900 以上なら、左（2/5）に参戦予定、右（3/5）に参戦済み。左右は別にスクロールする。900 未満は1列。
### 5.3 推しの色（Fc-7）
 
- 個人の設定：`users/{uid}/settings/oshiColors`（`colors`：`group:xxx`・`person:xxx` → ARGB の数、`updatedAt`）。`set(..., merge: true)` で1つずつ書き、外すときは `FieldValue.delete()`。
- 推しページのフォロー中の行の札を押すと色のシート（「色なし」と `kThemeColorPresets` の12色。選ぶとすぐ保存して閉じる）。
- `resolveOshiColor`：自分の色 → 個人なら所属グループのうち色があるものの最初 → なし。
- 色を使う場所：推しの札（グループは枠 3px をその色、個人は地をその色・人の形は `onThemeColor`）。札はすべての推しの行（推しを探す・メンバーの一覧・シートを含む）と最推しの箱に出る。掲示板の行の左端に 4px の帯（`resolvePostColor`：対象の個人 → グループの順で最初に色があるもの）。
## 6. 開発ステップ
 
| Step | 内容 | 状況 |
|---|---|---|
| Fc-1 | 最推しのデータ・リポジトリ・プロバイダ・操作（3.2） | 完了 |
| Fc-2 | 推しページの絞り込み・星・最推しの箱（3.1・3.2） | 完了 |
| Fc-3 | グループのメンバーをその場で開く・全員フォロー（4.1・4.2） | 完了 |
| Fc-4 | 推しを探す画面の入れ子とアイコンの札（4.3） | 完了 |
| Fc-5 | 掲示板の最新フィードと種別の絞り込み（5.1）。Fc-5x | 完了 |
| Fc-6 | メモリーの2列（5.2） | 完了 |
| Fc-7 | 推しの色（5.3） | 完了 |
 
## 7. 変えたファイル
 
| ファイル | 変更 | ステップ |
|---|---|---|
| `lib/repositories/favorite_oshi_repository.dart`・`lib/providers/favorite_oshi_providers.dart` | 新規 | Fc-1 |
| `lib/features/oshi/follow_actions.dart` | `runFavoriteAction`、解除で最推しも外す | Fc-1 |
| `lib/features/oshi/oshi_list_tile.dart` | 星（Fc-2）、`membersExpanded`（Fc-3）、`OshiKindBadge`・`highlight`（Fc-4）、色・`onBadgeTap`（Fc-7） | Fc-2・3・4・7 |
| `lib/features/oshi/following_oshi_list.dart` | 絞り込み・星（Fc-2）、グループを開く（Fc-3）、札で色を選ぶ（Fc-7） | Fc-2・3・7 |
| `lib/features/oshi/favorite_oshi_card.dart`・`oshi_page.dart` | 最推しの箱（Fc-2）、札（Fc-7） | Fc-2・7 |
| `lib/features/oshi/group_members_panel.dart` | 新規。`groupMembersOf`・`memberRequestPath`・`FollowAllMembersButton`・`GroupMembersPanel` | Fc-3・4 |
| `lib/features/oshi/group_members_sheet.dart` | 共通の部品を使う。全員フォロー | Fc-3 |
| `lib/utils/oshi_search.dart`・`lib/features/oshi/oshi_search_page.dart` | 入れ子 | Fc-4 |
| `lib/utils/trade_board.dart`・`lib/providers/trade_post_providers.dart`・`trade_board_view.dart`・`board_filter_sheet.dart` | フィード・種別の絞り込み（Fc-5）、色の帯（Fc-7） | Fc-5・7 |
| `lib/theme/hako_app_widgets.dart`・`lib/features/memory/memory_list_page.dart` | 本文の最大幅・2列 | Fc-6 |
| `lib/repositories/oshi_color_repository.dart`・`lib/providers/oshi_color_providers.dart`・`lib/features/oshi/oshi_color_sheet.dart` | 新規 | Fc-7 |
 
## 8. 確認したこと（11/7 23時ごろ、Mac の Chrome・`localhost:8080`・アカウント「けん」）
 
| 項目 | 結果 |
|---|---|
| 推しページ | 絞り込みのチップ、最推しの箱、丸い札が出る。グループの行を押すとその場でメンバーが開き、「メンバー全員をフォロー（3人）」が出る |
| 推しの色 | ステラノートの札を押して青にすると、グループの札の枠が青に、メンバー（星宮ルナ）の札と最推しの箱が青になる（グループの色の引き継ぎ） |
| 推しを探す | 「ルナ」で、ステラノートが開いた状態で出て、星宮ルナが太字。メンバーもグループの色 |
| 掲示板 | 最初が「フォロー中すべて」で、複数の推しの投稿が新しい順に出る。ステラノートの投稿の左端に青の帯。種別「缶バッジ」で絞り込める |
| メモリー | PC の幅で、左に参戦予定・右に参戦済みの2列 |
 
- 全員フォローのボタンは押していない（デモ用アカウントのフォローが変わるため）。
- 確認で、星宮ルナを最推しに、ステラノートの色を青にしたままにしてある。
- 掲示板の色の帯は、カードの角丸と枠に一部隠れて細く見える。
## 9. 未決定事項
 
- 最推しをほかの画面で使うか（例：ホームのあいさつ、投稿の作成で最初に選ぶ推し）
- ホームなど、ほかの画面を PC で2列にするか
- 推しの色を、ライブの一覧・ホーム・カレンダーなどにも使うか。共通データ（メンバーカラー）にするか
- 掲示板の「フォロー中すべて」で、フォロー中の推しが多いときの読み取りの量（推しごとに50件を読む。今のデモ用データでは問題ない）
 