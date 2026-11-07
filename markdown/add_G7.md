# おしあし（仮）グッズ交換の写真（G-7）仕様書

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
- `firebase deploy` は人間が行う。

## 1. 概要

| 項目 | 内容 |
|---|---|
| 機能名 | グッズ交換の写真（G-7） |
| 担当 | B（横山） |
| ブランチ | `features/M5` を `dev` にマージした後、`dev` から `features/G7` |
| 目的 | 譲の現物や全体の写真を投稿に付け、交換の相手が状態を確かめられるようにする |

## 2. 着手前のコードの構造（11/7 時点）

| 対象 | 場所 | 作り |
|---|---|---|
| 投稿のモデル | `lib/models/trade_post.dart` | 投稿全体の `images`、譲セット `GiveSet.images`（どちらも Storage のパスの配列）。`TradePost.maxImages = 8`・`imageCount`（合計） |
| 入力中の投稿 | `lib/features/trade/trade_post_draft.dart` | `GiveSetDraft.images`（保存済みの値をそのまま引き継ぐ）。`toPost({base})` は投稿全体の `images` を `base` から引き継ぐ |
| 作成・編集画面 | `lib/features/trade/trade_post_form_page.dart` | 譲 → 求 → 連絡先・備考 → エラー → 保存。`_save` で `validate` → `create`／`update` |
| 譲セットの入力 | `lib/features/trade/trade_sets_section.dart` の `GiveSetsSection`・`_SetCard` | |
| 投稿の詳細 | `lib/features/trade/trade_post_detail_page.dart` の `_PostBody`・`_SetCard` | |
| 一覧 | `trade_board_view.dart` の `_BoardCard`、`my_trade_posts_view.dart` の `_PostCard`、`trade_match_view.dart` の `_MatchCard` | |
| M-5 の部品 | `lib/utils/photo_picker.dart`・`lib/repositories/photo_repository.dart`・`lib/providers/photo_providers.dart`・`lib/features/common/storage_image.dart`（共通）。`memory_form_page.dart` の `_PhotoItem`・`_PhotoSection`・`_PhotoThumb`、`memory_detail_page.dart` の `_PhotoGrid`・`_PhotoViewer`（メモリー専用） | |

## 3. 決定事項：写真の扱い

### 3.1 制限・場所

- 写真を付けられるのは、**譲セットごと**と**投稿全体**の2か所。枚数は**合計で8枚まで**（`goods_spec.md` 3.2）。
- 大きさ・形式は M-5 と同じ（長辺 1600px、5MB 未満、JPEG・PNG・WebP・GIF）。

### 3.2 保存先

- Storage のパス：`tradePhotos/{uid}/{ファイル名}`（ファイル名は M-5 と同じ形）。投稿の ID に依存しないため、新しい投稿でも ID を決める前にアップロードできる。
- `images` には Storage のパスを入れる。

### 3.3 アップロード・削除の時機

- M-5 と同じく、**保存するとき**にまとめてアップロードする。失敗したら、この保存で上げた分を消し、投稿は書き換えない。
- 保存の後、もとの投稿の写真（投稿全体とすべてのセット）のうち、新しい投稿に無いものを消す（セットを消したときのセットの写真も含む）。失敗しても無視する。
- 投稿は削除せず「募集終了」にするだけなので、募集終了では写真を消さない。

## 4. 決定事項：Storage のルール

`storage.rules` に次を足す。

```
    // グッズ交換の写真（G-7）: ログイン済みなら読める。作成・削除は本人だけ
    match /tradePhotos/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == userId
        && request.resource.size < 5 * 1024 * 1024
        && request.resource.contentType.matches('image/(jpeg|png|webp|gif)');
      allow delete: if request.auth != null && request.auth.uid == userId;
    }
```

## 5. 決定事項：部品の共通化（G7-1）

M-5 のメモリー専用の部品を `lib/features/common/` に移して公開し、メモリーと交換の両方で使う。

### 5.1 `lib/features/common/photo_items.dart`（新規）

| 名前 | 内容 |
|---|---|
| `PhotoItem`（sealed）・`SavedPhoto(path)`・`NewPhoto(photo)` | 編集中の写真1枚（保存済みのパス／新しく選んだ写真） |
| `savedPhotoItems(paths)` | 保存済みのパスから `PhotoItem` の一覧を作る |
| `pickNewPhotos(context, remaining:)` | 写真を選び、知らせ（`photoPickMessage`・読み込みの失敗）を SnackBar で出して、`NewPhoto` の一覧を返す |
| `uploadNewPhotos(repo, dir, items)` | `NewPhoto` をアップロードし、`NewPhoto → パス` の Map を返す。失敗したら、この呼び出しで上げた分を消して例外を投げ直す |
| `photoPathsOf(items, uploaded)` | `PhotoItem` の並びを、パスの並びにする |
| `PhotoEditSection` | 見出し・サムネイルの並び・「写真を追加」。引数：`title`・`photos`・`canAdd`・`enabled`・`onAdd`・`onRemove`・`addButtonKey` |
| `PhotoThumb` | サムネイル1枚（96×96、角丸 8、右上に「×」） |

### 5.2 `lib/features/common/photo_grid.dart`（新規）

| 名前 | 内容 |
|---|---|
| `PhotoGrid` | 写真のグリッド（1行3枚、正方形、最大幅 480）。押すと `PhotoViewer` |
| `PhotoViewer` | 画面いっぱいの表示（拡大、左右に送る、矢印、「n / 枚数」、閉じる） |

### 5.3 メモリーの画面

- `memory_form_page.dart`：`_PhotoItem`・`_PhotoSection`・`_PhotoThumb` をやめ、5.1 を使う。動きは変えない。
- `memory_detail_page.dart`：`_PhotoGrid`・`_PhotoViewer` をやめ、5.2 を使う。動きは変えない。

## 6. 決定事項：グッズ交換の画面

### 6.1 入力中の投稿（`trade_post_draft.dart`）

- `GiveSetDraft.images`（`List<String>`）を `photos`（`List<PhotoItem>`）に替える。`fromSet` で `savedPhotoItems(s.images)`。
- `TradePostDraft` に投稿全体の `photos`（`List<PhotoItem>`）を足す。`fromPost` で `savedPhotoItems(p.images)`。
- `photoCount`（投稿全体とセットの合計）を足す。
- `toPost({base, uploaded})`：写真は `photoPathsOf(..., uploaded)` で作る（`uploaded` の既定は空。`validate` の中の `toPost()` は写真を使わない）。

### 6.2 作成・編集画面（`trade_post_form_page.dart`・`trade_sets_section.dart`）

- 譲セットのカードの中（備考の下）に、`PhotoEditSection`（見出し「このセットの写真」）。
- 「連絡先・備考」の前に見出し「写真（投稿全体とセットで n/8）」と、`PhotoEditSection`（投稿全体の写真）。
- 「写真を追加」は、合計が8枚のとき・保存中は無効。選ぶ枚数の上限は `8 − 合計`。
- 保存：`validate` → `uploadNewPhotos`（投稿全体とすべてのセットの写真。`dir` は `tradePhotos/{uid}`）→ `toPost(base:, uploaded:)` → `create`／`update` → もとの写真のうち新しい投稿に無いものを `deleteAll`（待たない）。アップロード・保存に失敗したら、上げた分を消してエラーを出す。

### 6.3 投稿の詳細（`trade_post_detail_page.dart`）

- 投稿全体の写真があれば、譲・求の前に「写真」として `PhotoGrid`。
- 譲セットの写真は、そのセットのカードの中（品目の下）に `PhotoGrid`。

### 6.4 一覧

- 掲示板（`_BoardCard`）・自分の投稿（`_PostCard`）・マッチ（`_MatchCard`）：写真があれば、1枚目（投稿全体 → 譲セットの順）を行の右に 56×56（角丸 8）で出す。
- 1枚目を選ぶ関数 `firstPhotoOf(TradePost)` を `trade_post_summary.dart` に足す。

## 7. 開発ステップ

| Step | 内容 | 状況 |
|---|---|---|
| G7-1 | Storage のルール（4章）と部品の共通化（5章）。メモリーは共通の部品に置き換える | 未着手 |
| G7-2 | 入力中の投稿と作成・編集画面（6.1・6.2） | 未着手 |
| G7-3 | 投稿の詳細（6.3） | 未着手 |
| G7-4 | 一覧のサムネイル（6.4） | 未着手 |
| G7-5 | ルールのデプロイと確認（8章） | 未着手 |

## 8. 確認

1. 投稿の作成で、譲セットに2枚・投稿全体に1枚付けて投稿 → Storage の `tradePhotos/{uid}/` に3つ、投稿の `images`・`gives[0].images` にパス。
2. 合計8枚で「写真を追加」がすべて無効になる。
3. 詳細画面で、投稿全体の写真とセットの写真が出て、押すと大きく表示される。別のアカウント（またはコンソールで別の uid に書き換えた投稿）でも見られる。
4. 掲示板・自分の投稿・マッチの行に1枚目のサムネイルが出る。
5. 編集で1枚外す・セットを消す → 保存後、Storage からも消える。
6. メモリーの写真が今までどおり動く（共通化の影響がない）。

## 9. 未決定事項

- デモ用データの投稿に写真を入れるか
- 写真の並べ替え