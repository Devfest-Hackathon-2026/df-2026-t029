# おしあしグッズ交換の写真（G-7）仕様書

> 本ドキュメントは、「グッズ交換の仕様書」（`markdown/goods_spec.md`）の G-7（写真）を作るための仕様書である。
> M-5（メモリーの写真。`claude/メモリーの写真（M-5）の仕様書.md`）で作った部品を共通にして使う。
> 前提として、`markdown/goods_spec.md`・`markdown/Database_config.md`・`CLAUDE.md`・M-5 の仕様書をあわせて参照すること。

## 0. LLM への指示

- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。「9. 未決定事項」は独自に確定させず、提案として示すこと。
- 本仕様にない作業を勝手に足さないこと。**テストコードは書かない**。
- **コードの編集は人間が Dev Container 内で行う。** LLM はリポジトリを読むだけにして、変更は置き換える部分を丸ごと（メソッド・クラス・ファイル単位で）コードとして提示すること。
- 開発は7章のステップの順に進め、各ステップに1行程度のコミット文を添えること。画面の確認は最後にまとめて行う。
- 既存のコードの書き方に合わせること（Riverpod 3 を手書き・コード生成なし、go_router、Firebase へのアクセスは `lib/repositories/` に閉じ込める、`await` 後は `mounted`／`context.mounted` を確認、文言・コメントは日本語、色はテーマから取る）。
- 新しいパッケージは追加しない。**`firestore.rules` は変えない**（`tradePosts` の `images` は8個以下に制限済み）。
- コメントで仕様書の章を書くときは、「G-7 仕様書 6.2」のように仕様書の名前を付ける。
- `firebase deploy` は人間が行う。

## 1. 概要

| 項目 | 内容 |
|---|---|
| 機能名 | グッズ交換の写真（G-7） |
| 担当 | B（横山） |
| ブランチ | `dev` から `features/G7` |
| 状況 | **G7-1〜G7-5 完了（11/7、画面で確認済み）** |
| 目的 | 譲の現物や全体の写真を投稿に付け、交換の相手が状態を確かめられるようにする |

## 2. 着手前のコードの構造（11/7 時点）

| 対象 | 場所 | 作り |
|---|---|---|
| 投稿のモデル | `lib/models/trade_post.dart` | 投稿全体の `images`、譲セット `GiveSet.images`（どちらも Storage のパスの配列）。`TradePost.maxImages = 8`・`imageCount`（合計） |
| 入力中の投稿 | `lib/features/trade/trade_post_draft.dart` | `GiveSetDraft.images`（保存済みの値をそのまま引き継ぐ）。`toPost({base})` は投稿全体の `images` を `base` から引き継ぐ |
| 作成・編集画面 | `lib/features/trade/trade_post_form_page.dart` | 譲 → 求 → 連絡先・備考 → エラー → 保存 |
| 譲セットの入力 | `lib/features/trade/trade_sets_section.dart` の `GiveSetsSection`・`_SetCard` | `_SetCard` は求セットと共用 |
| 投稿の詳細 | `lib/features/trade/trade_post_detail_page.dart` の `_PostBody`・`_SetCard` | |
| 一覧 | `trade_board_view.dart` の `_BoardCard`、`my_trade_posts_view.dart` の `_PostCard`、`trade_match_view.dart` の `_MatchCard` | |

## 3. 決定事項：写真の扱い

### 3.1 制限・場所

- 写真を付けられるのは、**譲セットごと**と**投稿全体**の2か所。枚数は**合計で8枚まで**。
- 大きさ・形式は M-5 と同じ（長辺 1600px、5MB 未満、JPEG・PNG・WebP・GIF）。

### 3.2 保存先

- Storage のパス：`tradePhotos/{uid}/{ファイル名}`。投稿の ID に依存しないため、新しい投稿でも ID を決める前にアップロードできる。
- `images` には Storage のパスを入れる。

### 3.3 アップロード・削除の時機

- **保存するとき**にまとめてアップロードする。アップロード・投稿の保存に失敗したら、この保存で上げた分を消し、投稿は書き換えない。
- 編集の保存の後、もとの投稿の写真（投稿全体とすべてのセット）のうち、新しい投稿に無いものを消す（セットを消したときのセットの写真も含む。待たない。失敗しても無視）。
- 投稿は削除せず「募集終了」にするだけなので、募集終了では写真を消さない。

## 4. 決定事項：Storage のルール

```
match /tradePhotos/{userId}/{fileName} {
  allow read: if request.auth != null;
  allow create: if request.auth != null && request.auth.uid == userId
    && request.resource.size < 5 * 1024 * 1024
    && request.resource.contentType.matches('image/(jpeg|png|webp|gif)');
  allow delete: if request.auth != null && request.auth.uid == userId;
}
```

## 5. 決定事項：部品の共通化（G7-1）

### 5.1 `lib/features/common/photo_items.dart`

| 名前 | 内容 |
|---|---|
| `PhotoItem`（sealed）・`SavedPhoto(path)`・`NewPhoto(photo)` | 編集中の写真1枚 |
| `savedPhotoItems(paths)` | 保存済みのパスから `PhotoItem` の一覧を作る |
| `pickNewPhotos(context, remaining:)` | 写真を選び、知らせを SnackBar で出して、`NewPhoto` の一覧を返す |
| `uploadNewPhotos(repo, dir, items)` | `NewPhoto` をアップロードし、`NewPhoto → パス` の Map を返す。失敗したら上げた分を消して例外を投げ直す |
| `photoPathsOf(items, uploaded)` | `PhotoItem` の並びをパスの並びにする |
| `PhotoEditSection` | 見出し・サムネイル・「写真を追加」。引数：`title`・`photos`・`canAdd`・`enabled`・`onAdd`・`onRemove`・`addButtonKey` |
| `PhotoThumb` | サムネイル1枚（96×96、角丸 8、右上に「×」） |

### 5.2 `lib/features/common/photo_grid.dart`

| 名前 | 内容 |
|---|---|
| `PhotoGrid(paths, maxWidth = 480)` | 1行3枚の正方形のグリッド。押すと `PhotoViewer` |
| `PhotoViewer` | 画面いっぱいの表示（拡大、左右に送る、矢印、「n / 枚数」、閉じる。黒地に白） |

### 5.3 メモリーの画面

- `memory_form_page.dart`・`memory_detail_page.dart` は 5.1・5.2 を使う。動きは変えていない。

## 6. 決定事項：グッズ交換の画面

### 6.1 入力中の投稿（`trade_post_draft.dart`）

- `GiveSetDraft.photos`（`List<PhotoItem>`）。`toSet({uploaded})`：`uploaded` が null なら写真は空（入力の検査用）。
- `TradePostDraft.photos`（投稿全体）、`photoCount`（合計）、`allPhotos`（アップロード用）。
- `toPost({base, uploaded})`：`uploaded` が null なら写真は空。`validate` に「合計8枚まで」の検査を足した。

### 6.2 作成・編集画面（`trade_post_form_page.dart`・`trade_sets_section.dart`）

- 譲セットのカードの中（備考の下）に `PhotoEditSection`（「このセットの写真」）。`_SetCard` に `footer` を足した（求セットでは使わない）。`GiveSetsSection` に `canAddPhoto`・`photosEnabled`・`onAddPhotos` を足した。
- 「求」の後・「連絡先・備考」の前に、見出し「写真（投稿全体とセットでn/8枚）」・案内・`PhotoEditSection`（「投稿全体の写真」）。
- 「写真を追加」は、合計が8枚のとき・保存中・写真を選んでいる最中は無効。選ぶ枚数の上限は `8 − 合計`。写真を選んでいる間は保存ボタンも押せない（`_picking`）。
- 保存：`validate` → `uploadNewPhotos`（`tradePhotos/{uid}`）→ `toPost(base:, uploaded:)` → `create`／`update` → 編集では外した写真を `deleteAll`（待たない）。

### 6.3 投稿の詳細（`trade_post_detail_page.dart`）

- 投稿全体の写真があれば、「譲」の前に「写真」として `PhotoGrid`。
- 譲セットの写真は、セットのカードの中（品目の下）に `PhotoGrid`（最大幅 360）。

### 6.4 一覧

- `firstPhotoOf(TradePost)`（`trade_post_summary.dart`）：投稿全体 → 譲セットの順で1枚目。
- `TradePostWithThumb`（`lib/features/trade/trade_post_thumb.dart`、新規）：中身の右に 56×56（角丸 8）のサムネイル。
- 掲示板（`_BoardCard`）・マッチ（`_MatchCard`、相手の投稿）は中身全体を包む。自分の投稿（`_PostCard`）は右上に操作のメニューがあるため、状態の行の下の要約だけを包む。

## 7. 開発ステップ

| Step | 内容 | 状況 |
|---|---|---|
| G7-1 | Storage のルール（4章）と部品の共通化（5章） | 完了 |
| G7-2 | 入力中の投稿と作成・編集画面（6.1・6.2） | 完了 |
| G7-3 | 投稿の詳細（6.3） | 完了 |
| G7-4 | 一覧のサムネイル（6.4）。G7-4x：コメントの整合（古いコメント、仕様書の名前）と、`memory_list_page.dart` の使っていないコメントアウトの削除 | 完了 |
| G7-5 | ルールのデプロイと確認（8章）。リポジトリの MD（`Database_config.md`・`memory_spec.md`・`goods_spec.md`）の写真まわりの記述を更新 | 完了 |

## 8. 確認（11/7、Mac の Chrome・`localhost:8080`・アカウント「けん」）

| 項目 | 結果 |
|---|---|
| 作成：譲セットに2枚・投稿全体に1枚 | 投稿でき、詳細画面に投稿全体の写真とセットの写真が出る |
| 合計8枚 | 見出しが「8/8枚」になり、「写真を追加」がすべて無効、「写真は8枚までです」と出る |
| 一覧 | 自分の投稿・掲示板の行の右に、1枚目（投稿全体の写真）のサムネイルが出る |
| 編集でセットの写真を1枚外して更新 | 詳細から消え、Storage に `DELETE …/tradePhotos%2F{uid}%2F….jpg` が送られ 204 |
| 大きく表示する画面 | 押すと開き、左右に送れる |
| メモリー（共通化の影響） | 詳細のグリッド・大きく表示・編集画面の写真の欄が今までどおり |

- 写真の選択は、ファイル選択のダイアログを操作できないため、ページ上で作った架空の画像（色の背景に「TEST n」）を入力に渡して試した。
- 確認用の投稿（けん・星宮ルナ・譲セット1・写真2枚）が残っている。不要なら募集終了にするか、コンソールで消す。
- 確認できていないもの：別のアカウントからの表示（ルール上はログイン済みなら読める）、マッチの一覧のサムネイル（写真付きの相手の投稿が無いため。部品は掲示板と同じ）。
- デバッグ版では、大きく表示する画面の右上の閉じるボタンに「DEBUG」の帯が重なる（公開版では出ない。Esc でも閉じられる）。

## 9. 未決定事項

- デモ用データの投稿に写真を入れるか
- 写真の並べ替え