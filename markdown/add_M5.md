# おしあし（仮）メモリーの写真（M-5）仕様書

> 本ドキュメントは、「ライブ参戦記録の機能の仕様書」（`markdown/memory_spec.md`）の M-5（写真）を、Blaze への切り替え後に作るための仕様書である。
> チームメンバーおよび開発支援に使う LLM が、この文書だけを読んで同じ前提で作業できるように、今のコードの構造と、変更後の形を具体的に書いている。
> 前提として、`markdown/memory_spec.md`・`markdown/Database_config.md`・`CLAUDE.md`・`markdown/deploy_手順.md` をあわせて参照すること。
> **G-7（グッズ交換の写真）で、作成・編集画面の写真の欄と詳細画面のグリッド・大きく表示する画面を `lib/features/common/` に移して共通にした**（10章。`claude/グッズ交換の写真（G-7）の仕様書.md` 5章）。

## 0. LLM への指示

- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。「9. 未決定事項」は独自に確定させず、提案として示すこと。
- 本仕様にない作業を勝手に足さないこと。**テストコードは書かない**。
- **コードの編集は人間が Dev Container 内で行う。** LLM はリポジトリを読むだけにして、変更は置き換える部分を丸ごと（メソッド・クラス・ファイル単位で）コードとして提示すること。「ここだけ変える」「外側だけ包む」のような部分的な説明はしない。
- 開発は7章のステップの順に進め、各ステップに1行程度のコミット文を添えること。画面の確認は最後にまとめて行う。
- 既存のコードの書き方に合わせること（Riverpod 3 を手書き・コード生成なし、go_router、Firebase へのアクセスは `lib/repositories/` に閉じ込める、`await` 後は `mounted`／`context.mounted` を確認、文言・コメントは日本語、色はテーマから取る）。
- 追加してよいパッケージは `firebase_storage` だけ（写真の選択は既存の `image_picker` を使う）。
- **`firestore.rules` は変えない。** 記録（`users/{uid}/memories/{performanceId}`）は今のルールのままで、`images` に Storage のパスを入れる。
- `firebase deploy`・コンソールの設定は人間が行う。

## 1. 概要

| 項目 | 内容 |
|---|---|
| 機能名 | メモリーの写真（M-5） |
| 担当 | B（横山）。`firebase.json` は A（とし）と共有する |
| ブランチ | `features/M5`（`dev` にマージ済み。PR #47） |
| 状況 | **完了（11/7）**。G7-1 で部品を共通化（10章） |
| 目的 | ライブの記録に写真を付け、アルバムらしく見せる |
| 前提 | Firebase は **Blaze**（11/7 切り替え済み） |

## 2. 着手前のコードの構造（11/7 時点の `dev`）

| 対象 | 場所 | 作り |
|---|---|---|
| 記録のモデル | `lib/models/live_memory.dart` の `LiveMemory` | `images`（`List<String>`、M-5 までは空）。`copyWithContent(seat:, setlist:, impression:)` は `images` をそのまま引き継ぐ |
| リポジトリ | `lib/repositories/memory_repository.dart` の `FirestoreMemoryRepository` | `create`（`toFirestore()` に `images` を含む）、`update`（`images` も書き換える）、`delete` |
| 作成・編集画面 | `lib/features/memory/memory_form_page.dart` の `_MemoryFormState` | 公演の表示 → 座席 → セトリ → 感想 → 保存 |
| 詳細画面 | `lib/features/memory/memory_detail_page.dart` | `// TODO(M-5): 写真`（状態のラベルの下） |
| アルバムのカード | `lib/features/memory/memory_album_card.dart` の `MemoryAlbumCard` | `// TODO(M-5)`。メモリー一覧とホームの「最近の思い出」で使う |
| 写真の選択 | `image_picker: ^1.2.4`（既存） | |
| Storage のバケット | `storageBucket: 'oshiashi-test.firebasestorage.app'` | まだ作っていない |

## 3. 決定事項：写真の扱い

### 3.1 制限

| 項目 | 値 |
|---|---|
| 枚数 | 1記録あたり8枚まで |
| 大きさ | 長辺 1600px に縮小（JPEG・WebP は画質 85）。縮小後に 5MB 以上のものは外す |
| 形式 | JPEG・PNG・WebP・GIF（`image/(jpeg|png|webp|gif)`）。それ以外（HEIC など）は外す |

- 外したものがあれば「n枚は大きすぎるか、対応していない形式のため追加できませんでした」、8枚を超えて選んだら空いている枚数だけ先頭から入れて「写真は8枚までです」と SnackBar で知らせる（文言は `photoPickMessage` に1か所でまとめる）。

### 3.2 保存先

- Storage のパス：`users/{uid}/memories/{performanceId}/{ファイル名}`。
- ファイル名：`<日時のミリ秒>_<ランダム6文字（英小文字・数字）>.<拡張子>`（`jpg`・`png`・`webp`・`gif`）。
- 記録の `images` には **Storage のパス**を入れる。1枚目が表紙。

### 3.3 アップロード・削除の時機

- 写真を選んだ時点ではアップロードせず、**保存するとき**にまとめてアップロードする。
- 保存の順番：
  1. 新しい写真をアップロードする。1枚でも失敗したら、この保存で上げた分を消し、記録は書き換えずに「写真を保存できませんでした」と出す。
  2. 記録を作成・更新する。失敗したら、この保存で上げた分を消す。
  3. 外した写真を Storage から消す（待たない。失敗しても無視）。
- 記録を削除したら、その記録の写真をすべて Storage から消す（記録の削除の後。待たない。失敗しても無視）。

### 3.4 表示

- パスからダウンロード URL を取って `Image.network` で表示する。URL はプロバイダで覚えておく（失敗しても取り直しを繰り返さない）。
- 読み込み中は色付きの枠（`surfaceContainerHighest`）、失敗したら `Icons.broken_image_outlined`。
- Flutter Web で画像を表示するため、バケットに CORS を設定する（8.1）。

## 4. 決定事項：Storage のルール（`storage.rules`）

```
match /users/{userId}/memories/{performanceId}/{fileName} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow create: if request.auth != null && request.auth.uid == userId
    && request.resource.size < 5 * 1024 * 1024
    && request.resource.contentType.matches('image/(jpeg|png|webp|gif)');
  allow delete: if request.auth != null && request.auth.uid == userId;
}
```

- `firebase.json` に `"storage": { "rules": "storage.rules" }`。G-7 で `tradePhotos/{userId}/{fileName}` を足した。

## 5. 決定事項：共通の部品

| ファイル | 内容 |
|---|---|
| `lib/utils/photo_picker.dart` | `maxPhotoBytes`・`photoMaxSide`・`maxPhotosPerItem`・`PickedPhoto`・`PhotoPickResult`・`pickPhotos({remaining})`・`photoPickMessage` |
| `lib/repositories/photo_repository.dart` | `PhotoRepository`・`FirebasePhotoRepository`（`upload`・`delete`（見つからないものは無視）・`deleteAll`（失敗しても止めない）・`downloadUrl`） |
| `lib/providers/photo_providers.dart` | `photoRepositoryProvider`・`photoUrlProvider`（family、autoDispose なし、`retry` なし） |
| `lib/features/common/storage_image.dart` | `StorageImage(path, fit)` |

## 6. 決定事項：メモリーの画面

### 6.1 モデル・保存

- `LiveMemory.copyWithContent` に `required List<String> images` を足した。`MemoryRepository` は変えていない。
- 写真のアップロード・削除は、作成・編集画面が `photoRepositoryProvider` を使って行う（3.3）。

### 6.2 作成・編集画面（`memory_form_page.dart`）

- 感想の下・保存の上に「写真（n/8）」の欄（サムネイル 96×96・角丸 8・右上に「×」、「写真を追加」）。8枚のとき・処理中は追加できない。
- 削除の確認ダイアログの本文は「座席・セトリ・感想・写真も消え、元には戻せません」。
- G7-1 以降は、共通の `PhotoEditSection`・`pickNewPhotos`・`uploadNewPhotos`・`photoPathsOf` を使う（10章）。

### 6.3 詳細画面（`memory_detail_page.dart`）

- 状態のラベルの下に、写真があるときだけ「写真」の区画。1行3枚のグリッド（最大幅 480）。押すと画面いっぱいに表示（拡大・左右に送る・矢印・「n / 枚数」・閉じる）。
- G7-1 以降は、共通の `PhotoGrid`・`PhotoViewer` を使う（10章）。

### 6.4 アルバムのカード（`memory_album_card.dart`）

- `images` があれば1枚目を `StorageImage` で表紙にする。メモリー一覧・ホームの「最近の思い出」に反映される。

## 7. 開発ステップ

| Step | 内容 | 状況 |
|---|---|---|
| M5-1 | `firebase_storage` の追加、`storage.rules`・`firebase.json`。人がバケットの作成・CORS・ルールのデプロイ | 完了 |
| M5-2 | 共通の部品（5章） | 完了 |
| M5-3 | モデルと作成・編集画面（6.1・6.2） | 完了 |
| M5-4 | 詳細画面とアルバムのカード（6.3・6.4） | 完了 |
| M5-5 | 確認、`markdown/deploy_手順.md` に Storage の設定・ルールのデプロイ・CORS（1.6・2.8・3 の13）を追記 | 完了 |

## 8. 人が行う設定と確認

### 8.1 設定（11/7 済み）

1. Firebase コンソール →「Storage」→「始める」。場所は **US-EAST1**（Storage の無料枠の対象。後から変えられない）。バケットは `oshiashi-test.firebasestorage.app`。
2. ルールのデプロイ：`firebase deploy --only storage`。
3. CORS：Cloud Shell で1行ずつ実行する（ヒアドキュメントは行頭の空白で失敗しやすいため使わない）。

```bash
echo '[{"origin": ["*"], "method": ["GET"], "maxAgeSeconds": 3600}]' > cors.json
gcloud storage buckets update gs://oshiashi-test.firebasestorage.app --cors-file=cors.json
```

### 8.2 確認（11/7）

- 記録への写真の追加・保存、詳細画面のグリッドと大きく表示する画面、一覧・ホームの表紙を確認済み。
- G7-1 の共通化の後も、詳細画面（グリッド・左右に送る）と編集画面（写真の欄）が今までどおり表示されることを確認した。

## 9. 未決定事項

- デモ用データに写真を入れるか
- 写真の並べ替え・説明文（キャプション）

## 10. G-7 での変更（G7-1）

| もとの場所（M-5） | 移した先 |
|---|---|
| `memory_form_page.dart` の `_PhotoItem`・`_SavedPhoto`・`_NewPhoto`・`_PhotoSection`・`_PhotoThumb` | `lib/features/common/photo_items.dart` の `PhotoItem`・`SavedPhoto`・`NewPhoto`・`PhotoEditSection`・`PhotoThumb`。あわせて `savedPhotoItems`・`pickNewPhotos`・`uploadNewPhotos`・`photoPathsOf` |
| `memory_detail_page.dart` の `_PhotoGrid`・`_PhotoViewer` | `lib/features/common/photo_grid.dart` の `PhotoGrid`・`PhotoViewer` |

- 動きは変えていない。`memory_list_page.dart` の古い `_AlbumCard` のコメントアウト（`TODO(M-5)` を含む）は G7-4x で消した。
- コメントの「仕様書 ○.○」は、どの仕様書かが分かるように「M-5 仕様書」「Step6 仕様書」と書く（G7-4x）。