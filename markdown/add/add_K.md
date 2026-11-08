# おしあし（仮）メモリーの共有の仕様書（add_K）
 
> 本ドキュメントは、11/8 にユーザー（横山）が決めた「メモリー（ライブの記録）を、同じ推しのほかのユーザーと共有できるようにする（共有するかは選べる）」を、提出（11/10 19:00）までに作るための仕様書である。
> チームメンバーおよび開発支援に使う LLM が、この文書だけを読んで同じ前提で作業できるように、今の作り・データ・ルール・変えるファイルを具体的に書いている。
> 前提として、`CLAUDE.md`・`markdown/Database_config.md`・メモリーの仕様書（`markdown/spec/` のライブの記録）・`markdown/add/add_M5.md`（メモリーの写真）をあわせて参照すること。
> 名前は「共有（Kyouyuu）」の K。メモリーの仕様書のステップ名（M-1〜M-5）と重ならないように、add_M ではなく add_K にした。
 
## 0. LLM への指示
 
- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。「9. 未決定事項」は独自に確定させず、提案として示すこと。
- 本仕様にない作業を勝手に足さないこと。**テストコードは書かない**。
- **コードの編集は人間が Dev Container 内で行う。** LLM はリポジトリを読むだけにする。小さな変更は変わる部分だけ、大きな変更はメソッド・クラス・ファイル単位で丸ごと出す。**変更ごとにファイルの場所（パス）を書く**。
- 7章のステップの順に進め、各ステップに1行のコミット文を添えること。画面の確認は最後にまとめて、Claude in Chrome（人の Chrome）で行う。
- 見た目はログイン後のデザイン「ハコ色」（`lib/theme/hako_app_widgets.dart`・`brand_colors.dart`・`hako_fonts.dart`）に合わせる。
- コメントで章を書くときは「add_K 3.1」のように仕様書の名前を付ける。
- ルール（`firestore.rules`・`storage.rules`）と索引（`firestore.indexes.json`）のデプロイは人が行う。
## 1. 概要
 
| 項目 | 内容 |
|---|---|
| 名前 | add_K（メモリーの共有） |
| 担当 | B（横山） |
| ブランチ | `dev` から `features/K` |
| 状況 | **K-1〜K-4 完了（11/8、Chrome で確認済み。10章）** |
 
### 1.1 できるようになること
 
1. 自分のメモリーを1件ずつ「公開する・しない」を選べる（最初は公開しない）。座席は、公開するかを別に選べる（最初は公開しない）。
2. メモリーの画面に「みんなのメモリー」を足し、フォロー中の推しの公開メモリーを新しい順に見られる。
3. ほかの人の公開メモリーを開くと、読むだけの詳細画面が出る（写真・セトリ・感想）。
4. 公開をやめる・メモリーを消すと、ほかの人からは見えなくなる。
## 2. 着手前の作り（11/8 時点の `dev`）
 
| 対象 | 場所 | 作り |
|---|---|---|
| 記録のデータ | `users/{uid}/memories/{performanceId}`（`lib/models/live_memory.dart`） | ライブ名・開演日時・会場（複製）、座席・セトリ・感想・写真（Storage のパス）・作成日時・更新日時 |
| 記録のルール | `firestore.rules` の `users/{userId}/{subcollection}/{document=**}` | 本人だけが読み書きできる |
| 写真 | Storage `users/{uid}/memories/{performanceId}/{fileName}`（`storage.rules`） | 本人だけが読める |
| 記録の作成・編集 | `lib/features/memory/memory_form_page.dart` | 写真のアップロード → `memoryRepository.create`／`update` → 外した写真を消す |
| 記録の詳細 | `lib/features/memory/memory_detail_page.dart` | 自分の記録を表示・編集・削除 |
| メモリー一覧 | `lib/features/memory/memory_list_page.dart`（`/memories`） | 参戦予定 → 参戦済み（PC は2列。Fc 5.2） |
| 公開プロフィール | `publicProfiles/{uid}` | 表示名・アイコン。ほかの人のアイコンは `UserAvatar(uid:, name:)` |
| 交換の投稿の検索 | `tradePostRepository.watchOpenFor`・`firestore.indexes.json` | `groupIds`／`oshiIds` の array-contains ＋ 並び替えの索引がある。推しごとに検索して画面でまとめる（Fc 5.1） |
 
## 3. 決定事項：データ
 
### 3.1 自分の記録に足す項目
 
`users/{uid}/memories/{performanceId}` に足す（`LiveMemory` に足す）。
 
| 項目 | 型 | 内容 |
|---|---|---|
| `isPublic` | bool | 公開するか。無ければ false |
| `publicSeat` | bool | 座席も公開するか。無ければ false。`isPublic` が false のときは使わない |
 
- `toFirestore`・`fromFirestore`・`copyWithContent`（引数に `isPublic`・`publicSeat` を足す）・`FirestoreMemoryRepository.update`（2つも書く）を直す。
- ルールは今の `users/{userId}/{subcollection}/{document=**}` のままでよい（変えない）。
### 3.2 公開メモリー（新しいコレクション）
 
`publicMemories/{uid}_{performanceId}`。自分の記録を公開したときに、その写しを置く。ドキュメント ID は「uid」「_」「performanceId」をつなげたもの（1人1公演に1件）。
 
| 項目 | 型 | 内容 |
|---|---|---|
| `uid` | string | 書いた人 |
| `displayName` | string（1〜100） | 書いた人の表示名の写し（`myDisplayNameProvider`。交換の投稿と同じ） |
| `performanceId` | string | 公演 |
| `liveId` | string | ライブ |
| `liveTitle` | string（1〜200） | 記録の写し |
| `startAt` | timestamp | 記録の写し |
| `venue` | string（0〜200） | 記録の写し |
| `groupIds` | list<string>（0〜20） | ライブの出演グループ（`lives/{liveId}` の写し）。推しで探すのに使う |
| `oshiIds` | list<string>（0〜20） | ライブの出演者（個人）。同上 |
| `seat` | string（1〜100）・省略可 | `publicSeat` が true で座席があるときだけ入れる |
| `setlist` | list<string>（0〜100、各1〜100） | 記録の写し |
| `impression` | string（1〜2000）・省略可 | 記録の写し |
| `images` | list<string>（0〜`maxPhotosPerItem`） | 記録の写し（Storage のパス。写真はコピーしない。4章） |
| `createdAt` | timestamp | 最初に公開した日時 |
| `updatedAt` | timestamp | 最後に書いた日時 |
 
- 新しいモデル `PublicMemory`（`lib/models/public_memory.dart`）と、リポジトリ `PublicMemoryRepository`（`lib/repositories/public_memory_repository.dart`）を作る。
- リポジトリの操作：
  - `Future<void> publish(LiveMemory memory, {required String uid, required String displayName, required List<String> groupIds, required List<String> oshiIds})`：`set`（`merge` しない。丸ごと書く）。`createdAt` は最初の1回だけサーバー時刻にしたいので、トランザクションで「無ければ `createdAt` もサーバー時刻、あれば元の値」にする。`updatedAt` はサーバー時刻。
  - `Future<void> unpublish(String uid, String performanceId)`：消す（無くてもエラーにしない）。
  - `Stream<List<PublicMemory>> watchFor(OshiKind kind, String oshiId, {required int limit})`：`groupIds`／`oshiIds` の array-contains、`updatedAt` の新しい順、`limit` 件。
  - `Stream<PublicMemory?> watch(String id)`：1件。
### 3.3 索引（`firestore.indexes.json` に足す）
 
```json
{
  "collectionGroup": "publicMemories",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "groupIds", "arrayConfig": "CONTAINS" },
    { "fieldPath": "updatedAt", "order": "DESCENDING" }
  ]
},
{
  "collectionGroup": "publicMemories",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "oshiIds", "arrayConfig": "CONTAINS" },
    { "fieldPath": "updatedAt", "order": "DESCENDING" }
  ]
}
```
 
## 4. 決定事項：ルール
 
### 4.1 `firestore.rules`
 
`publicProfiles` の下に足す。
 
- 読む：ログイン済みなら読める（`isAuthenticated()`）。画面に出すのはフォロー中の推しの分だけだが、ルールではフォローを見ない（交換の投稿と同じ）。
- 作る・書き換える：次をすべて満たすとき。
  - ドキュメント ID が `request.auth.uid + '_' + data.performanceId`、`data.uid == request.auth.uid`。
  - 本人の記録 `users/{uid}/memories/{performanceId}` がある（`exists`）。
  - 項目は 3.2 の表のものだけ（`keys().hasOnly`）。型と長さが 3.2 のとおり。
  - `images` の各パスが `users/{uid}/memories/{performanceId}/` で始まる。
  - `updatedAt == request.time`。`createdAt` は作るとき `request.time`、書き換えるとき元の値のまま。
- 消す：`resource.data.uid == request.auth.uid`。
### 4.2 `storage.rules`
 
メモリーの写真の読み取りに、「公開メモリーがあれば、ログイン済みなら読める」を足す（Storage のルールから Firestore を読む）。
 
```
match /users/{userId}/memories/{performanceId}/{fileName} {
  allow read: if request.auth != null && (
    request.auth.uid == userId ||
    firestore.exists(/databases/(default)/documents/publicMemories/$(userId + '_' + performanceId))
  );
  // create・delete は今のまま
}
```
 
- 写真はコピーしない（公開をやめると、公開メモリーが消えて、ほかの人は写真も読めなくなる）。
- Storage のルールから Firestore を読むには、最初のデプロイで Firebase の権限を許可する（デプロイ時に聞かれる。人が行う）。
## 5. 決定事項：自分の記録の画面
 
### 5.1 作成・編集（`memory_form_page.dart`）
 
- 写真の欄の下に、見出し「公開」とスイッチ2つを足す。
  - 「同じ推しのファンに公開する」（`isPublic`）。下に小さく「フォロー中の推しが同じ人の『みんなのメモリー』に出ます」。
  - 「座席も公開する」（`publicSeat`）。`isPublic` が off のときは押せない（薄く出す）。
- 保存の流れ（今の 1〜3 の間に入れる）：
  1. 写真のアップロード（今のまま）
  2. 記録を保存（今のまま。`isPublic`・`publicSeat` も書く）
  3. **公開の写しを書く・消す**：`isPublic` が true なら `publish`、false なら `unpublish`。`groupIds`・`oshiIds` はライブ（`liveRepository.watchLive(liveId).first`）から取る。ライブが読めないときは空のリストで書く。
     - 失敗したら記録はそのままにして、「記録は保存しましたが、公開できませんでした。もう一度保存してください」と出す（記録の保存は戻さない）。
  4. 外した写真を消す（今のまま）。**3 が失敗したときは消さない**（写しがまだ古い写真を指しているため）
- 公開中のメモリーで写真を外したとき、公開の写しを先に書き換えてから写真を消す（3 → 4 の順なので、今の順番でよい）。
- 表示名は `myProfileProvider.future` を読み終わってから使う（読み込み中だと「匿名」になるため）。空なら「匿名」。
### 5.2 詳細（`memory_detail_page.dart`）と削除
 
- 公開中なら、ライブ名の下に「公開中」のチップ（座席も公開しているなら「公開中（座席も）」）。
- 記録を削除するときは、先に `unpublish` してから記録を消す（`unpublish` の失敗は無視して記録の削除に進む）。削除のボタンは編集画面（`memory_form_page.dart` の `_delete`）にあるので、そこに入れた。
## 6. 決定事項：みんなのメモリー
 
### 6.1 メモリーの画面のタブ（`memory_list_page.dart`）
 
- タイトルの下にタブを2つ：「自分のメモリー」（今の中身）・「みんなのメモリー」。最初は「自分のメモリー」。選んだタブは覚えない。
- 「みんなのメモリー」の中身：
  - 上に推しの選択（交換の掲示板の `_OshiSelector` と同じ形。「フォロー中すべて」と、フォロー中の推し）。最初は「フォロー中すべて」。
  - 「フォロー中すべて」は、フォロー中の推し（グループ・個人）ごとに `watchFor(…, limit: 30)` を購読し、重複（同じ ID）を除いて `updatedAt` の新しい順にまとめる。推しを1つ選んだらその推しだけ。
  - 自分の公開メモリーも出す（「自分」のチップを付ける）。
  - 0件なら「まだ公開されたメモリーはありません。自分のメモリーの編集で『公開する』を選ぶと、ここに出ます」。
  - フォロー中の推しがいないときは「推しをフォローすると、同じ推しのファンのメモリーが見られます」と「推しを探す」ボタン。
### 6.2 公開メモリーのカード
 
上から：
 
1. 名前の行：アイコン（`UserAvatar`）と名前（自分なら「自分」のチップ）、右端に公演の日付（「2026年11月8日」）。
2. 写真：1枚目（表紙）を横幅いっぱい・縦横比 16:9・角丸 8。無ければ出さない。
3. ライブ名（15・太字）と会場（12・`sub`）。
4. 感想の最初の3行（省略は「…」）。無ければ出さない。
- 押すと詳細（6.3）。
- PC の幅（本文 900 以上）では2列に並べる（メモリー一覧の幅 1080 を使う）。
### 6.3 公開メモリーの詳細（新しい画面）
 
- ルート：`/shared-memories/:id`（ホームの下。`id` は `uid_performanceId`）。新しい画面 `SharedMemoryDetailPage`（`lib/features/memory/shared_memory_detail_page.dart`）。
- 読むだけ。上から：名前の行（アイコン・名前）／ライブ名・日時・会場／座席（あれば）／写真（すべて。今の記録の詳細と同じ並べ方）／セトリ／感想。
- ライブ名の行を押すとライブ詳細（`/lives/{liveId}`）。
- 自分の公開メモリーなら、下に「自分のメモリーを開く」（`/memories/{performanceId}`）。
- 無い（公開をやめた・消した）ときは「このメモリーは公開されていません」。
## 7. 開発ステップ
 
| Step | 内容 | 状況 |
|---|---|---|
| K-1 | データ（3.1・3.2）・リポジトリ・プロバイダ・索引（3.3）・ルール（4章）。K-1x：`flutter analyze` の指摘（null を省く書き方） | 完了 |
| K-2 | 作成・編集のスイッチと保存の流れ、詳細の「公開中」と削除（5章） | 完了 |
| K-3 | メモリーの画面のタブ・みんなのメモリーの一覧とカード（6.1・6.2） | 完了 |
| K-4 | 公開メモリーの詳細画面（6.3） | 完了 |
 
- K-1 の後、人がルールと索引をデプロイする（`firebase deploy --only firestore:rules,firestore:indexes,storage`）。
## 8. 変えたファイル
 
| ファイル | 変更 | ステップ |
|---|---|---|
| `lib/models/live_memory.dart` | `isPublic`・`publicSeat` | K-1 |
| `lib/repositories/memory_repository.dart` | `update` で2つも書く | K-1 |
| `lib/models/public_memory.dart` | 新規 | K-1 |
| `lib/repositories/public_memory_repository.dart` | 新規 | K-1 |
| `lib/providers/public_memory_providers.dart` | 新規。リポジトリ・推しごとの購読・フィード・1件 | K-1・3 |
| `firestore.rules`・`storage.rules`・`firestore.indexes.json` | 4章・3.3 | K-1 |
| `lib/features/memory/memory_form_page.dart` | スイッチ・保存の流れ | K-2 |
| `lib/features/memory/memory_detail_page.dart` | 「公開中」・削除で `unpublish` | K-2 |
| `lib/features/memory/memory_list_page.dart` | タブ | K-3 |
| `lib/features/memory/shared_memories_view.dart` | 新規。みんなのメモリー（選択・一覧・カード） | K-3 |
| `lib/features/memory/shared_memory_detail_page.dart` | 新規 | K-4 |
| `lib/app.dart` | `/shared-memories/:id` | K-4 |
 
## 9. 未決定事項
 
- ライブ詳細にも「このライブのみんなのメモリー」を出すか（`liveId` で探す索引が要る）。
- 公開メモリーへの反応（いいね・コメント）を付けるか。
- 通報・非表示の仕組み（今は無い。ハッカソンの提出では入れない見込み）。
- 表示名を変えたとき、公開メモリーの `displayName` を書き換えるか（今は次に保存したときに変わる。交換の投稿と同じ）。
- 公開メモリーの詳細（`/shared-memories/:id`）はホームの下に置いたので、左のメニューで「ホーム」が選ばれた状態になる。メモリーの下（`/memories/shared/:id`）に移すか。
## 10. 確認したこと（11/8 15時ごろ、Mac の Chrome・`localhost:8080`・アカウント「けん」）
 
| 項目 | 結果 |
|---|---|
| 編集画面 | 写真の下に「公開」とスイッチ2つ。公開がオフのとき「座席も公開する」は薄く押せない |
| 公開して保存 | 「空野カナタ アコースティックライブ『ことのは』」を公開して保存 → 詳細に「公開中」。エラーなし（ルール・索引のデプロイ済み） |
| みんなのメモリー | 「フォロー中すべて」で、そのメモリーが「けん・自分」付きのカードで出る（表紙の写真・ライブ名・会場・感想の3行） |
| 公開メモリーの詳細 | 名前・ライブ名（押すとライブ詳細）・日時・会場・写真2枚・セトリ・感想・「自分のメモリーを開く」。座席は公開していないので出ない |
| 公開をやめる | オフにして保存 → 「公開中」が消え、みんなのメモリーは「まだ公開されたメモリーはありません」 |
 
- 確認のあと、公開はオフに戻した（デモ用のデータは元のまま）。
- ほかのアカウントから写真が読めるか（Storage のルール）は、別のアカウントでのログインが要るため確かめていない。
 