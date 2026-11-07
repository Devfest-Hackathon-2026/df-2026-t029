# おしあし（仮）メモリーの写真（M-5）仕様書

> 本ドキュメントは、「ライブ参戦記録の機能の仕様書」（`markdown/memory_spec.md`）の M-5（写真）を、Blaze への切り替え後に作るための仕様書である。
> チームメンバーおよび開発支援に使う LLM が、この文書だけを読んで同じ前提で作業できるように、今のコードの構造と、変更後の形を具体的に書いている。
> 前提として、`markdown/memory_spec.md`・`markdown/Database_config.md`・`CLAUDE.md`・`markdown/deploy_手順.md` をあわせて参照すること。
> 写真の選択・縮小・アップロード・表示の部品は、グッズ交換の G-7 でもそのまま使う。

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
| ブランチ | `features/step6` を `dev` にマージした後、`dev` から `features/M-5` |
| 目的 | ライブの記録に写真を付け、アルバムらしく見せる |
| 前提 | Firebase は **Blaze**（11/7 切り替え済み） |

## 2. 着手前のコードの構造（11/7 時点の `dev`）

| 対象 | 場所 | 作り |
|---|---|---|
| 記録のモデル | `lib/models/live_memory.dart` の `LiveMemory` | `images`（`List<String>`、M-5 までは空）。`copyWithContent(seat:, setlist:, impression:)` は `images` をそのまま引き継ぐ |
| リポジトリ | `lib/repositories/memory_repository.dart` の `FirestoreMemoryRepository` | `create`（`toFirestore()` に `images` を含む）、`update`（`images` も書き換える）、`delete` |
| 作成・編集画面 | `lib/features/memory/memory_form_page.dart` の `_MemoryFormState` | 公演の表示 → 座席 → セトリ → 感想 → 保存。`_save`・`_delete` は `GoRouter`・`ScaffoldMessenger` を先に取ってから処理する |
| 詳細画面 | `lib/features/memory/memory_detail_page.dart` | `// TODO(M-5): 写真`（状態のラベルの下） |
| アルバムのカード | `lib/features/memory/memory_album_card.dart` の `MemoryAlbumCard` | `// TODO(M-5)`。表紙はアイコンを置いた色付きの枠。メモリー一覧とホームの「最近の思い出」で使う |
| 写真の選択 | `image_picker: ^1.2.4`（既存。スクショ読み取りで使用） | |
| Storage のバケット | `lib/firebase_options.dart` の `storageBucket: 'oshiashi-test.firebasestorage.app'` | まだ作っていない |

## 3. 決定事項：写真の扱い

### 3.1 制限

| 項目 | 値 |
|---|---|
| 枚数 | 1記録あたり8枚まで |
| 大きさ | 長辺 1600px に縮小（JPEG・WebP は画質 85）。縮小後に 5MB 以上のものは外す |
| 形式 | JPEG・PNG・WebP・GIF（`image/(jpeg|png|webp|gif)`）。それ以外（HEIC など）は外す |

- 外したものがあれば、「n 枚は大きすぎるか、対応していない形式のため追加できませんでした」と SnackBar で知らせる。
- 8枚を超えて選んだら、空いている枚数だけ先頭から入れ、「写真は8枚までです」と知らせる。

### 3.2 保存先

- Storage のパス：`users/{uid}/memories/{performanceId}/{ファイル名}`（`Database_config.md` のとおり）。
- ファイル名：`<日時のミリ秒>_<ランダム6文字（英小文字・数字）>.<拡張子>`（拡張子は `jpg`・`png`・`webp`・`gif`）。
- 記録の `images` には、**Storage のパス**（`users/...`）を入れる。順番は表示の順（1枚目が表紙）。

### 3.3 アップロード・削除の時機

- 写真を選んだ時点ではアップロードしない。**保存するとき**にまとめてアップロードする（途中でやめたときに、使われないファイルを残さないため）。
- 保存の順番：
  1. 新しく選んだ写真をアップロードする。1枚でも失敗したら、この保存でアップロードした分を消し、記録は書き換えずに「写真を保存できませんでした」と出す。
  2. 記録を作成・更新する（`images` に、残した写真と新しい写真のパスを並べる）。
  3. 外した写真（もとの `images` にあって、新しい `images` に無いもの）を Storage から消す。失敗しても無視する。
- 記録を削除したら、その記録の `images` の写真をすべて Storage から消す（記録の削除の後。失敗しても無視する）。

### 3.4 表示

- パスからダウンロード URL を取って `Image.network` で表示する。URL はプロバイダで覚えておき、同じ写真で何度も取らない。
- 読み込み中は色付きの枠（`surfaceContainerHighest`）、失敗したら `Icons.broken_image_outlined` を出す。
- Flutter Web で画像を表示するため、バケットに CORS の設定をする（8.1）。

## 4. 決定事項：Storage のルール（`storage.rules`、新規）

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // メモリーの写真（M-5）: 本人だけ。作成は 5MB 未満の画像だけ。上書きはしない
    match /users/{userId}/memories/{performanceId}/{fileName} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow create: if request.auth != null && request.auth.uid == userId
        && request.resource.size < 5 * 1024 * 1024
        && request.resource.contentType.matches('image/(jpeg|png|webp|gif)');
      allow delete: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

- ここに無いパスはすべて拒否される。G-7 のパスは G-7 のときに足す。
- `firebase.json` に `"storage": { "rules": "storage.rules" }` を足す。

## 5. 決定事項：共通の部品（G-7 でも使う）

### 5.1 写真の選択（`lib/utils/photo_picker.dart`、新規）

| 名前 | 内容 |
|---|---|
| `maxPhotoBytes` | `5 * 1024 * 1024` |
| `photoMaxSide` | `1600` |
| `maxPhotosPerItem` | `8` |
| `PickedPhoto` | 選んだ写真（`Uint8List bytes`・`String contentType`・`String extension`） |
| `PhotoPickResult` | `List<PickedPhoto> photos`、外した枚数 `rejected`、枚数の上限で入れなかった枚数 `overLimit` |
| `Future<PhotoPickResult> pickPhotos({required int remaining})` | `ImagePicker().pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 85)` → 形式（`XFile.mimeType`、無ければ名前の拡張子）と大きさで振り分け → 先頭から `remaining` 枚まで |

### 5.2 リポジトリ（`lib/repositories/photo_repository.dart`、新規）

`abstract class PhotoRepository` と `FirebasePhotoRepository`（`FirebaseStorage` をコンストラクタで受け取る）。

| メソッド | 内容 |
|---|---|
| `Future<String> upload(String dir, PickedPhoto photo)` | `dir/ファイル名`（3.2）に `putData`（`contentType` を付ける）。パスを返す |
| `Future<void> delete(String path)` | 消す。見つからない（`object-not-found`）は無視する |
| `Future<void> deleteAll(Iterable<String> paths)` | 1件ずつ消し、失敗は無視する |
| `Future<String> downloadUrl(String path)` | `getDownloadURL` |

### 5.3 プロバイダ（`lib/providers/photo_providers.dart`、新規）

- `photoRepositoryProvider`（`FirebasePhotoRepository(FirebaseStorage.instance)`）
- `photoUrlProvider`：`FutureProvider.family<String, String>`（パス → ダウンロード URL）。`autoDispose` にせず、一度取った URL を覚えておく。

### 5.4 表示の部品（`lib/features/common/storage_image.dart`、新規）

- `StorageImage`（`ConsumerWidget`）：`path`・`fit`（既定 `BoxFit.cover`）。`photoUrlProvider(path)` → `Image.network`（読み込み中・失敗の表示は 3.4）。
- `PickedPhoto` の表示は `Image.memory(photo.bytes)` を使う（共通の部品にはしない）。

## 6. 決定事項：メモリーの画面

### 6.1 モデル・保存

- `LiveMemory.copyWithContent` に `required List<String> images` を足す（今の呼び出し元は作成・編集画面だけ）。
- `MemoryRepository` は変えない（`create`・`update` は今のまま `images` を書く）。
- 写真のアップロード・削除は、作成・編集画面が `photoRepositoryProvider` を使って行う（3.3）。

### 6.2 作成・編集画面（`memory_form_page.dart`）

- 感想の下・保存の上に「写真」の欄を置く：
  - 見出し「写真（n/8）」。
  - サムネイル（96×96、角丸 8）を `Wrap` で並べる。残した写真は `StorageImage`、新しい写真は `Image.memory`。右上に「×」（押すと外す。確認はしない）。
  - 「写真を追加」（`OutlinedButton.icon`、`Icons.add_photo_alternate_outlined`）。8枚のとき・処理中は無効。
- 状態は、`_MemoryFormState` に写真の並び（`List<_PhotoItem>`：残した写真のパス、または新しい `PickedPhoto`）を持つ。最初はもとの `images`。
- 保存（3.3）・削除（3.3）。保存中のボタンの表示は今のまま。
- 削除の確認ダイアログの本文を「座席・セトリ・感想・写真も消え、元には戻せません」にする。

### 6.3 詳細画面（`memory_detail_page.dart`）

- `// TODO(M-5): 写真` の位置に、写真があるときだけ「写真」の区画（`_Section`）を置く。
- 写真は1行3枚のグリッド（正方形、`BoxFit.cover`、間隔 4、角丸 8）。
- 押すと、画面いっぱいのダイアログで大きく表示する（`InteractiveViewer` で拡大でき、左右に送れる `PageView`。右上に閉じる）。
- 写真が無ければ区画を出さない（「未入力」は出さない）。

### 6.4 アルバムのカード（`memory_album_card.dart`）

- `images` があれば、1枚目を `StorageImage`（`BoxFit.cover`）で表紙にする。無ければ今の色付きの枠。
- メモリー一覧・ホームの「最近の思い出」の両方に反映される。

## 7. 開発ステップ

| Step | 内容 | 状況 |
|---|---|---|
| M5-1 | `firebase_storage` の追加、`storage.rules`・`firebase.json`（4章）。人がバケットの作成・CORS・ルールのデプロイ（8.1） | 未着手 |
| M5-2 | 共通の部品（5章） | 未着手 |
| M5-3 | モデルと作成・編集画面（6.1・6.2） | 未着手 |
| M5-4 | 詳細画面とアルバムのカード（6.3・6.4） | 未着手 |
| M5-5 | 確認（8.2）。`markdown/deploy_手順.md` に Storage の設定・ルールのデプロイ・CORS を追記する | 未着手 |

## 8. 人が行う設定と確認

### 8.1 設定

1. Firebase コンソール →「Storage」→「始める」。場所は **asia-northeast1**（東京）。ルールは「本番環境モード」で始め、すぐ 4章のルールをデプロイする。バケットが `oshiashi-test.firebasestorage.app` になっていることを確かめる。
2. ルールのデプロイ：`firebase deploy --only storage`。
3. CORS：Google Cloud コンソールの Cloud Shell で次を実行する。

```bash
cat > cors.json <<'EOF'
[{"origin": ["*"], "method": ["GET"], "maxAgeSeconds": 3600}]
EOF
gcloud storage buckets update gs://oshiashi-test.firebasestorage.app --cors-file=cors.json
```

- 読み取りはダウンロード URL（トークン付き）でしかできないため、`origin` は `*` でよい。

### 8.2 確認

1. 記録の編集で写真を3枚選ぶ → サムネイルが並ぶ → 保存 → Storage の `users/{uid}/memories/{performanceId}/` に3つのファイル、記録の `images` に3つのパス。
2. 詳細画面に3枚並び、押すと大きく表示され、左右に送れる。
3. メモリー一覧・ホームの「最近の思い出」のカードの表紙が1枚目になる。
4. 編集で1枚外して保存 → Storage からも消える。
5. 記録を削除 → Storage の写真もすべて消える。
6. 9枚以上選ぶと8枚までになり、知らせが出る。大きすぎる・対応していない形式のものは外され、知らせが出る。

## 9. 未決定事項

- デモ用データに写真を入れるか（入れるなら、架空の画像を用意して `tools/seed/` から Storage にも入れる）
- 写真の並べ替え（今回は作らない。1枚目を変えたいときは外して入れ直す）
- 写真の説明文（キャプション）