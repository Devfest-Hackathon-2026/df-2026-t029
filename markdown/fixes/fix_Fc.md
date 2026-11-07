# おしあし（仮）提出前の改善の方針書（Fc）

> 本ドキュメントは、11/7 夜にユーザー（横山）が挙げた改善の候補（推しページ・推しを探す・掲示板・PC の横幅・推しの色）を、提出（11/10 19:00）までに進めるための方針書である。
> チームメンバーおよび開発支援に使う LLM が、この文書だけを読んで同じ前提で作業できるように、今の作り・直し方・変えるファイルを具体的に書いている。
> 前提として、`markdown/Database_config.md`・`CLAUDE.md`・`markdown/fixes/fix_Fb.md` をあわせて参照すること。

## 0. LLM への指示

- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。「7. 未決定事項」は独自に確定させず、提案として示すこと。
- 本仕様にない作業を勝手に足さないこと。**テストコードは書かない**。
- **コードの編集は人間が Dev Container 内で行う。** LLM はリポジトリを読むだけにして、変更は置き換える部分を丸ごと（メソッド・クラス・ファイル単位で）コードとして提示すること。「ここだけ変える」「外側だけ包む」のような部分的な説明はしない。
- 開発は5章のステップの順に進め、各ステップに1行程度のコミット文を添えること。画面の確認は最後にまとめて行う。
- 見た目はログイン後のデザイン「ハコ色」（`lib/theme/hako_app_widgets.dart`・`brand_colors.dart`・`hako_fonts.dart`）に合わせる。
- コメントで章を書くときは「Fc 3.1」のように方針書の名前を付ける。
- **`firestore.rules` は変えない**（Fc-1・Fc-2）。新しい個人のデータは `users/{uid}` の下のサブコレクションに置く。

## 1. 概要

| 項目 | 内容 |
|---|---|
| 名前 | Fc |
| 担当 | B（横山）。推しの画面は A（とし）の担当範囲なので、A に一声かけてから触る（11/7 夜時点で、推しのファイルを触っている未マージのブランチはない） |
| ブランチ | `dev` から `feature/Fc` |
| 状況 | Fc-1 着手 |

### 1.1 進める順番（11/7 夜に決定）

1. 推しページの絞り込み（グループ／個人）と最推し（Fc-1・Fc-2）
2. 掲示板の最新フィード（フォロー中の推し全部、推し・グッズの種類で絞り込み）
3. メモリーの2列（PC の幅のとき）
4. 推しを探す画面の入れ子とアイコン
5. 推しの色（いちばん大きい。時間が無ければ提出後）

2〜5 は、着手するときに方針を決めてこの文書に追記する。

## 2. 今の作り（11/7 夜時点の `dev`）

| 対象 | 場所 | 作り |
|---|---|---|
| 推しページ | `lib/features/oshi/oshi_page.dart` の `OshiPage` | `HakoPageScaffold`。「推しを探す」ボタン → 見出し「フォロー中の推し」→ `FollowingOshiList` |
| フォロー中の一覧 | `lib/features/oshi/following_oshi_list.dart` | `followingOshisProvider`（個人 → グループの順、それぞれ名前順）を `OshiListTile` で並べる。グループの行を押すとメンバーのシート。使っているのは推しページだけ |
| 1行 | `lib/features/oshi/oshi_list_tile.dart` の `OshiListTile` | アイコン（グループ／個人）・名前・チップ（種別・ジャンル・所属・申請中・メンバーを見る）・右にフォローのボタン。推しを探す・メンバーのシートでも使う |
| フォロー | `users/{uid}` の `followingGroupIds`・`followingOshiIds`。`runFollowAction`（`follow_actions.dart`） | |
| 推しのキー | `OshiSummary.key` = `'${kind.name}/$id'`（例：`group/xxx`・`person/xxx`） | |
| 個人の設定の置き場 | `users/{uid}/settings/budget`（費用管理の予算） | ルールの `users/{userId}/{subcollection}/{document=**}` で本人だけが読み書きできる |

## 3. 決定事項：推しページ（Fc-1・Fc-2）

### 3.1 絞り込み

- 見出し「フォロー中の推し」の下に、チップを3つ並べる：「すべて（n）」「グループ（n）」「個人（n）」。n はフォロー中の数。
- 選んでいるチップは墨（`BrandColors.ink`）の地に紙（`BrandColors.paper`）の文字、選んでいないチップは白の地に墨の文字。どちらも枠は墨 2px・角丸 999（ハコ色のボタンと同じ形）。
- 最初は「すべて」。選んだものは覚えない（開き直すと「すべて」）。
- 選んだ種別に1件も無いときは、「フォロー中のグループはありません」「フォロー中の個人はいません」と出す。

### 3.2 最推し

- 最推しは**1つだけ**（グループでも個人でもよい）。
- 保存先：`users/{uid}/settings/favoriteOshi`

| 項目 | 型 | 内容 |
|---|---|---|
| `kind` | string | `group`・`person`（`OshiKind.name`） |
| `id` | string | 推しの ID |
| `updatedAt` | timestamp | 更新日時（サーバー時刻） |

- 外すときはドキュメントを消す。
- フォロー中の一覧の各行で、「フォロー中」ボタンの左に星のボタンを置く（最推しなら★ `Icons.star`、そうでなければ☆ `Icons.star_border`）。☆を押すとその推しを最推しにする（前の最推しは置き換わる）。★を押すと外す。推しを探す画面・メンバーのシートには出さない。
- 最推しは「推しを探す」ボタンの下に、見出し「最推し」と白い箱（`HakoBox`）で出す：★・名前（大きめ）・チップ（種別・ジャンル・所属）。グループなら箱を押すとメンバーのシート。
- 最推しがいないときは、見出し「最推し」の箱を出さず、フォロー中の一覧の上に「☆を押すと最推しにできます」と小さく（`BrandColors.sub`）出す（フォロー中が1件以上のとき）。
- 最推しのフォローを外したら、最推しも外す（`runFollowAction` の解除の後に消す。失敗しても無視）。フォロー中でない最推しは表示しない。
- 最推しは今回は推しページだけで使う。

## 4. 変えるファイル

| ファイル | 変更 | ステップ |
|---|---|---|
| `lib/repositories/favorite_oshi_repository.dart` | 新規。`FavoriteOshiRepository`（`watch`・`set`・`clear`） | Fc-1 |
| `lib/providers/favorite_oshi_providers.dart` | 新規。`favoriteOshiRepositoryProvider`・`favoriteOshiKeyProvider`・`favoriteOshiProvider` | Fc-1 |
| `lib/features/oshi/follow_actions.dart` | `runFavoriteAction` を足す。解除のときに最推しも外す | Fc-1 |
| `lib/features/oshi/oshi_list_tile.dart` | 星のボタン（`isFavorite`・`onToggleFavorite`。渡したときだけ出す） | Fc-2 |
| `lib/features/oshi/following_oshi_list.dart` | 絞り込みのチップ・星・案内 | Fc-2 |
| `lib/features/oshi/favorite_oshi_card.dart` | 新規。最推しの箱 | Fc-2 |
| `lib/features/oshi/oshi_page.dart` | 最推しの箱を足す | Fc-2 |

## 5. 開発ステップ

| Step | 内容 | 状況 |
|---|---|---|
| Fc-1 | 最推しのデータ・リポジトリ・プロバイダ・操作（3.2） | 未着手 |
| Fc-2 | 推しページの画面：絞り込み（3.1）・星・最推しの箱（3.2） | 未着手 |

2〜5（1.1）のステップは、着手するときに追記する。

## 6. 確認すること

1. 推しページで「グループ」「個人」を押すと、それぞれだけになり、数が合っている。
2. ☆を押すと上に最推しの箱が出て、その行が★になる。別の推しの☆を押すと最推しが替わる。★を押すと箱が消える。
3. 最推しのフォローを外すと、最推しの箱も消える（もう一度フォローしても最推しには戻らない）。
4. 開き直しても最推しが残っている（Firestore の `users/{uid}/settings/favoriteOshi`）。

## 7. 未決定事項

- 最推しをほかの画面で使うか（例：ホームのあいさつ、掲示板で最初に選ぶ推し）
- 1.1 の 2〜5 の方針