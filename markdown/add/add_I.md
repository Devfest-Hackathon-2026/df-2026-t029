# おしあしアイコンの機能追加 仕様書（add_I）
 
> 本ドキュメントは、`claude/11-8 朝の機能追加の計画.md` の 2番（アイコン）の仕様書である。
> 推しの絵文字・画像（個人の設定）と、プロフィールのアイコン画像を足す。
> 前提として、`claude/fix_Fc.md`（推しの色 Fc 5.3）・`markdown/add/add_M5.md`（写真の部品）・`markdown/Database_config.md`・`CLAUDE.md`・`markdown/deploy_手順.md` をあわせて参照すること。
 
## 0. LLM への指示
 
- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。「8. 未決定事項」は独自に確定させず、提案として示すこと。
- 本仕様にない作業を勝手に足さないこと。**テストコードは書かない**。
- **コードの編集は人間が Dev Container 内で行う。** LLM はリポジトリを読むだけにして、変更は置き換える部分を丸ごと（メソッド・クラス・ファイル単位で）コードとして提示すること。
- 開発は6章のステップの順に進め、各ステップに1行程度のコミット文を添えること。画面の確認は最後にまとめて行う（人が再起動してから、LLM が Chrome で確かめてよい）。
- 見た目はログイン後のデザイン「ハコ色」に合わせる。コメントで章を書くときは「add_I 3.1」のように仕様書の名前を付ける。
- パッケージは足さない（写真は M-5・G-7 の `image_picker`・`firebase_storage` の部品を使う）。
- `firestore.rules`・`storage.rules` は 4章の分だけ足す。`firestore.rules` は A（とし）と共有なので、デプロイの前に一声かける。`firebase deploy` は人間が行う。
## 1. 概要
 
| 項目 | 内容 |
|---|---|
| 機能名 | アイコンの機能追加（add_I） |
| 担当 | B（横山）。ホーム・外枠（`app_shell.dart`・`hako_app_widgets.dart`）は A（とし）と共有する |
| ブランチ | `dev` から `features/I` |
| 目的 | 推しとユーザーを、色だけでなく絵文字・顔（アイコン）で見分けられるようにする |
| 状況 | I-1〜I-5 完了（11/8） |
 
## 2. 着手前の作り（11/8 の `features/Ea`）
 
| 対象 | 場所 | 作り |
|---|---|---|
| 推しの色 | `lib/repositories/oshi_color_repository.dart`・`lib/providers/oshi_color_providers.dart`（`oshiColorsProvider`・`oshiColorKey`・`resolveOshiColor`） | `users/{uid}/settings/oshiColors` の `colors`（`group:xxx`・`person:xxx` → ARGB） |
| 色を選ぶシート | `lib/features/oshi/oshi_color_sheet.dart`（`showOshiColorSheet`） | 札を押すと開く。選ぶとすぐ保存して閉じる |
| 推しの札 | `lib/features/oshi/oshi_list_tile.dart` の `OshiKindBadge` | 丸の中に人・グループのアイコン。色で塗る |
| プロフィール | `users/{uid}`（`displayName`・`xAccount`・`themeColor`・`profileUpdatedAt`）。`UserProfile`・`ProfileRepository`・`myProfileProvider`・`lib/features/profile/profile_page.dart` | `users/{uid}` は本人しか読めない |
| ほかの人の名前 | 投稿・返信の `displayName`、チャットの `memberNames`（作成時に複製） | |
| 写真の部品 | `lib/utils/photo_picker.dart`（`PickedPhoto`・`pickPhotos`）、`PhotoRepository`（`upload`・`delete`・`downloadUrl`）、`photoUrlProvider`、`StorageImage` | |
| アカウントのボタン | `hako_app_widgets.dart` の `AccountMenuButton`（人のアイコン → プロフィール・ログアウト） | 外枠の左下と、スマホの上のバー |
 
## 3. 決定事項
 
### 3.1 推しの絵文字（I-1）
 
- 推しの色と同じく**個人の設定**。`users/{uid}/settings/oshiEmojis` の `emojis`（`group:xxx`・`person:xxx` → 絵文字1文字）。キーは `oshiColorKey` と同じ。
- 1文字（書記素1つ。`characters` で数える）。UTF-8 で32バイトまで（肌の色・国旗・ZWJ でつないだ絵文字も入る長さ）。
- **継承しない**（個人に絵文字が無くても、グループの絵文字は使わない。メンバーの見分けが付かなくなるため）。
- 札（`OshiKindBadge`）：絵文字があれば、人・グループのアイコンの代わりに絵文字を出す（大きさは札の 0.5 倍）。色の塗り方は今のまま。
- 選ぶ場所：今の色のシートを「**色と絵文字**」のシートにする。上に色（今のまま）、下に絵文字。
  - 絵文字：「なし」と、よく使うもの（🌙 ⭐ 🌸 🎀 💜 💙 💚 💛 🧡 ❤️ 🐬 🐰 🐱 🦊 🐻 🍓 🍒 🔥 🌈 ✨ 👑 🎤 🎸 🫶）を並べ、押すと保存して閉じる。
  - 並びに無いものは、入力欄（1文字）に入れて「決定」。
- シートの見出しは「<推しの名前>の色と絵文字」。
### 3.1b 推しの画像（I-2。11/8 追加）
 
- 推しの札に、自分で選んだ画像も使えるようにする。**個人の設定**で、本人にしか見えない（ほかの人には出さない）。
- 置き場：`users/{uid}/settings/oshiImages` の `images`（推しの色のキー → Storage のパス）。Storage は `users/{uid}/oshiIcons/<日時>_<ランダム>.<拡張子>`（本人だけが読み書きできる）。
- 写真は長辺 512px に縮小する（`photo_picker.dart` に1枚選ぶ `pickIconPhoto` を足す。`pickPhotos` は今のまま）。変えたら前のファイルを消す。
- 札の出し方の優先：**画像 → 絵文字 → 人・グループのアイコン**。画像は丸く切り抜き、枠は今のまま（グループで色があれば色の枠）。継承しない。
- 選ぶ場所：「色と絵文字」のシートの一番下に「画像」の区画（「画像を選ぶ」「外す」）。選ぶとすぐアップロードして保存し、閉じる。
### 3.2 プロフィールのアイコン（I-3）
 
- プロフィールの画面の上に、丸いアイコン（96px）と「アイコンを変える」「外す」を置く。押すと写真を1枚選び、すぐにアップロードして保存する（ほかの項目の「保存」とは別）。
- 写真は長辺 512px に縮小する（I-2 で足した `pickIconPhoto`）。
- Storage：`userIcons/{uid}/<日時>_<ランダム>.<拡張子>`（`PhotoRepository.upload`）。変えたら前のファイルを消す。
- 置き場：**公開プロフィール `publicProfiles/{uid}`**（`displayName`・`iconPath`・`updatedAt`）。ログイン済みなら誰でも読め、本人だけが書ける。
  - ほかの人のアイコンは、投稿・返信・チャットに複製せず、uid から公開プロフィールを読む（前に作った投稿・チャットにも、すぐ反映される）。
  - `displayName` もプロフィールの保存のときに一緒に書く（今後、名前の表示を公開プロフィールに寄せるときのため。今回の表示は今の複製のまま）。
- `users/{uid}` には `iconPath` を置かない（置き場は公開プロフィールの1か所）。
### 3.3 アイコンの表示（I-4）
 
- 部品 `UserAvatar`（`lib/features/common/user_avatar.dart`）：`uid`・`name`・`size`。
  - 公開プロフィールに `iconPath` があれば、その画像を丸く切り抜いて出す（`StorageImage`）。
  - 無ければ、名前の最初の1文字を、白地に墨の丸（`BrandColors`）で出す。読み込み中も同じ。
- プロバイダ `publicProfileProvider`（`StreamProvider.autoDispose.family<PublicProfile?, String>`。uid ごと）。
- 出す場所：
| 場所 | ファイル | 大きさ |
|---|---|---|
| 掲示板の行（投稿者名の左） | `trade_board_view.dart` | 24 |
| 投稿の詳細（投稿者） | `trade_post_detail_page.dart` | 32 |
| 返信の行 | `trade_replies_section.dart` | 24 |
| マッチの行（相手の名前の左） | `trade_match_view.dart` | 24 |
| チャット一覧の行（相手） | `chat_list_page.dart` | 36 |
| ホームの新しい交換 | `home_new_trades.dart` | 24 |
| ホームのあいさつの左 | `home_page.dart` | 48 |
| アカウントのボタン（人のアイコンの代わり） | `hako_app_widgets.dart` の `AccountMenuButton` | 28 |
 
## 4. 決定事項：ルール
 
### 4.1 `firestore.rules`
 
`users/{userId}/settings/oshiEmojis` は、今の「サブコレクションは本人なら読み書きできる」で足りる（変えない）。公開プロフィールを足す。
 
```
// 公開プロフィール（add_I 3.2）。ログイン済みなら読める。書くのは本人だけ
match /publicProfiles/{userId} {
  allow read: if isAuthenticated();
  allow create, update: if isOwner(userId) &&
    request.resource.data.keys().hasOnly(['displayName', 'iconPath', 'updatedAt']) &&
    isValidOptionalString(request.resource.data, 'displayName', 1, 100) &&
    (!('iconPath' in request.resource.data) ||
      (request.resource.data.iconPath is string &&
       request.resource.data.iconPath.matches('userIcons/' + userId + '/[^/]{1,100}'))) &&
    request.resource.data.updatedAt == request.time;
  allow delete: if isOwner(userId);
}
```
 
### 4.2 `storage.rules`
 
```
// 推しの画像（add_I 3.1b）: 本人だけ。作成は 2MB 未満の画像だけ
match /users/{userId}/oshiIcons/{fileName} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow create: if request.auth != null && request.auth.uid == userId
    && request.resource.size < 2 * 1024 * 1024
    && request.resource.contentType.matches('image/(jpeg|png|webp|gif)');
  allow delete: if request.auth != null && request.auth.uid == userId;
}
 
// プロフィールのアイコン（add_I 3.2）: ログイン済みなら読める。作成・削除は本人だけ
match /userIcons/{userId}/{fileName} {
  allow read: if request.auth != null;
  allow create: if request.auth != null && request.auth.uid == userId
    && request.resource.size < 2 * 1024 * 1024
    && request.resource.contentType.matches('image/(jpeg|png|webp|gif)');
  allow delete: if request.auth != null && request.auth.uid == userId;
}
```
 
## 5. データ
 
| パス | 項目 | 内容 |
|---|---|---|
| `users/{uid}/settings/oshiEmojis` | `emojis`（map）・`updatedAt` | 推しの色のキー → 絵文字1文字 |
| `users/{uid}/settings/oshiImages` | `images`（map）・`updatedAt` | 推しの色のキー → Storage のパス |
| Storage `users/{uid}/oshiIcons/{file}` | | 推しの画像（本人だけ。2MB 未満、長辺 512px） |
| `publicProfiles/{uid}` | `displayName`（string）・`iconPath`（string、任意）・`updatedAt`（サーバー時刻） | 公開プロフィール |
| Storage `userIcons/{uid}/{file}` | | アイコン画像（2MB 未満、長辺 512px） |
 
`markdown/Database_config.md` に上の5つを追記する（I-5）。
 
## 6. 開発ステップ
 
| Step | 内容 | 状況 |
|---|---|---|
| I-1 | 推しの絵文字（リポジトリ・プロバイダ・シート・札） | 完了 |
| I-2 | 推しの画像（3.1b。`storage.rules`・`pickIconPhoto`・リポジトリ・シート・札） | 完了 |
| I-3 | プロフィールのアイコン（ルール・公開プロフィールのリポジトリ・`publicProfileProvider`・`UserAvatar`・プロフィールの画面） | 完了 |
| I-4 | アイコンの表示（3.3 の場所） | 完了 |
| I-5 | 確認。`Database_config.md`・`deploy_手順.md`（ルールのデプロイ）の追記 | 完了（11/8。Chrome で7章の1〜3を確認。4 は別のアカウントが要るので、自分の側の表示と頭文字の表示だけ確認） |
 
## 7. 確認すること
 
1. 推しの札を押して絵文字を選ぶ → 推しのページ・検索・メンバーの一覧・最推しの箱の札に出る。「なし」で戻る。入力欄で並びに無い絵文字も決められる。
2. 推しの画像を選ぶ → 札が画像になる（絵文字より優先）。「外す」で絵文字・アイコンに戻る。別のアカウントには出ない。
3. プロフィールでアイコンを選ぶ → プロフィール・アカウントのボタン・ホームのあいさつに出る。変えると前のファイルが消える。「外す」で名前の1文字に戻る。
4. 別のアカウントで、自分の投稿・返信・マッチ・チャット一覧にアイコンが出る（前に作った投稿にも出る）。
5. ルール：ほかの人の公開プロフィールは書けない。ほかの人の `userIcons`・`oshiIcons` には上げられない。
## 8. 未決定事項
 
- 名前の表示も公開プロフィールから読むか（名前を変えたら前の投稿にも反映。今回は複製のまま）。
- 推しの公式のアイコン画像（共通データとしてみんなに出す。権利の確認が要るので提出後。今回の 3.1b は本人にしか見えない個人の設定）。
 