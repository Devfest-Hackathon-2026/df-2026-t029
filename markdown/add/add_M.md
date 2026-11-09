# おしあし（仮）会場の地図と帰りの経路 仕様書（add_M）

> 本ドキュメントは、11/9 にユーザー（横山）が決めた「会場の地図」と「帰りの経路（終電）」を、提出（11/10 19:00）までに作るための仕様書である。
> ねらいは、Google Maps Platform（Maps Embed API）を使い、遠征のときに会場の場所と帰りの電車の経路をアプリの中で見られるようにすること。
> 前提として、`CLAUDE.md`・`markdown/Database_config.md`・`markdown/deploy_手順.md`・`markdown/add/add_E.md`（遠征。公演の行のリンク・遠征の一覧）・`markdown/add/add_P.md`（`WebIframe`）をあわせて参照すること。
> 名前は「地図（Maps）」の M。

## 0. LLM への指示

- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。「9. 未決定事項」は独自に確定させず、提案として示すこと。
- 本仕様にない作業を勝手に足さないこと。**テストコードは書かない**。
- **コードの編集は人間が Dev Container 内で行う。** LLM はリポジトリを読むだけにする。小さな変更は変わる部分だけ、大きな変更はメソッド・クラス・ファイル単位で丸ごと出す。**変更ごとにファイルの場所（パス）を書く**（「1〜3に同じものを適用」のようにまとめない）。
- 7章のステップの順に進め、各ステップに1行のコミット文を添えること。画面の確認は最後にまとめて、Claude in Chrome（人の Chrome）で行う。
- 見た目はログイン後のデザイン「ハコ色」（`lib/theme/hako_app_widgets.dart`・`brand_colors.dart`・`hako_fonts.dart`）に合わせる。
- コメントで章を書くときは「add_M 3.1」のように仕様書の名前を付ける。
- 追加してよいパッケージは無し（`WebIframe`・`url_launcher` を使う）。Functions は変えない。
- API キーをリポジトリに書かない。Maps Embed のキーは `--dart-define=MAPS_EMBED_KEY=...` で渡す（`FCM_VAPID_KEY` と同じ）。

## 1. 概要

| 項目 | 内容 |
|---|---|
| 名前 | add_M（会場の地図と帰りの経路） |
| 担当 | B（横山）。ライブ詳細の公演の行は A（とし）と共有する |
| ブランチ | `dev` から `features/M` |
| 状況 | 仕様書を作成（11/9）。M-0（確かめ）は完了（2.1） |

### 1.1 できるようになること

1. ライブ詳細の公演の行と、遠征の一覧のカードに「地図」のボタンが付く。押すとシートが開き、**会場の地図**（Google マップの埋め込み）が出る。
2. 同じシートの「帰りの経路」で、**会場から自分の「帰りの駅」までの電車の経路**（Google マップの埋め込み）が出る。帰りの駅は個人の設定として一度登録すれば、どの公演でも使える。
3. 「Google マップで終電を調べる」を押すと、同じ経路を Google マップで開く。時刻（終演後の出発・終電）は Google マップの側で指定する。

### 1.2 使う Google の技術

| 技術 | 使い方 |
|---|---|
| Maps Embed API（`place`） | 会場の地図 |
| Maps Embed API（`directions`、`mode=transit`） | 会場 → 帰りの駅の電車の経路 |
| Google マップ（URL） | 同じ経路を Google マップで開く（時刻・終電の指定はここで） |

## 2. 決定事項：方針

### 2.1 M-0 で確かめたこと（11/9）

- **Routes API では日本の電車の経路が返らない。** 名古屋駅 → 東京駅で、`DRIVE` は距離と時間が返ったが、`TRANSIT` は空（`{}`）だった。IGアリーナ（名古屋）→ 東京駅の 21:00・23:30 出発も空だった。
- **Maps Embed API の `directions`（`mode=transit`）では、日本の電車の経路が地図に出る。** `localhost:8080` の画面に埋め込んで、IGアリーナ → 東京駅の電車の経路が出ることを確かめた。
- このため、**終電の判定（「間に合う／間に合わない」をアプリが出す）は作らない**。経路は埋め込みで見せ、時刻は Google マップで指定してもらう。

### 2.2 キーの扱い

- Maps Embed のキー（`MapsEmbed_key`）は iframe の URL に入るので、画面を見る人には見える（Maps Embed API の決まった使い方）。代わりに、**API の制限（Maps Embed API だけ）とウェブサイトの制限**（`http://localhost:8080/*`・`https://oshiashi-test.web.app/*`・`https://oshiashi-test.firebaseapp.com/*`）を付けた（11/9 済み）。
- キーはビルドのときに `--dart-define=MAPS_EMBED_KEY=...` で渡す。**渡さないときは、埋め込みの代わりに「Google マップで開く」のボタンだけを出す**（アプリは動く）。
- プレビューの URL（`oshiashi-test--preview-xxxx.web.app`）はウェブサイトの制限に入っていないので、埋め込みの地図はエラーになる。プレビューで確かめるときは、一時的に制限に足す。
- Maps Embed API は無料で、回数の上限も無い。

### 2.3 オンラインの公演

- `isOnlineVenue`（`lib/utils/travel_links.dart`）が true の公演には、「地図」のボタンを出さない（今の「行き方」などと同じ）。

## 3. 決定事項：データ

### 3.1 帰りの駅（個人の設定）`users/{uid}/settings/travel`

| 項目 | 型 | 内容 |
|---|---|---|
| `homeStation` | string | 帰りの駅（例：「東京駅」「静岡駅」）。1〜50文字。前後の空白を除く。空にすると消す |
| `updatedAt` | timestamp | サーバー時刻 |

- ルールは今の `users/{userId}/{subcollection}/{document=**}`（本人だけ読み書き）のままで足りる。変えない。
- モデル `lib/models/travel_settings.dart`（`TravelSettings`：`homeStation`。`fromMap`）。
- リポジトリ `lib/repositories/travel_settings_repository.dart`（`watch(uid)`・`setHomeStation(uid, String? station)`。`oshi_days_repository.dart` と同じ形で `set(..., SetOptions(merge: true))`。null か空なら `FieldValue.delete()`）。
- プロバイダ `lib/providers/travel_settings_providers.dart`（`travelSettingsRepositoryProvider`・`travelSettingsProvider`：`StreamProvider`。未ログインなら空の設定）。

## 4. 決定事項：URL

`lib/utils/maps_embed.dart` にまとめる（`travel_links.dart` の `_placeOf` と同じく「会場名 都道府県」を場所にする。`_placeOf` は `placeOf` として公開し、こちらから使う）。

| 関数 | 中身 |
|---|---|
| `const mapsEmbedKey = String.fromEnvironment('MAPS_EMBED_KEY');` | キー。空なら埋め込みを出さない |
| `venueMapEmbedUrl(Performance p)` | `https://www.google.com/maps/embed/v1/place?key=..&q=<会場名 都道府県>&language=ja&region=JP`。キーが空・オンラインなら null |
| `homeRouteEmbedUrl(Performance p, String homeStation)` | `https://www.google.com/maps/embed/v1/directions?key=..&origin=<会場名 都道府県>&destination=<帰りの駅>&mode=transit&language=ja&region=JP`。キーが空・オンライン・駅が空なら null |
| `homeRouteUri(Performance p, String homeStation)` | `https://www.google.com/maps/dir/?api=1&origin=<会場名 都道府県>&destination=<帰りの駅>&travelmode=transit`（Google マップで開く。キーは要らない） |
| `venueMapUri(Performance p)` | `https://www.google.com/maps/search/?api=1&query=<会場名 都道府県>`（キーが無いときの代わり） |

- URL の組み立ては `Uri.https(...)` で行い、クエリは自動でエンコードさせる。

## 5. 決定事項：画面

### 5.1 地図のシート `showVenueMapSheet(context, performance)`

- `lib/features/travel/venue_map_sheet.dart`。ボトムシート（`isScrollControlled: true`、高さは画面の 85% まで）。PC の幅では幅 720 までにして中央に出す（今の遠征メモのシートと同じ出し方にそろえる）。
- 見出し：会場名（都道府県）。その下に `SegmentedButton`「会場」「帰りの経路」（最初は「会場」）。
- **会場**：`WebIframe(src: venueMapEmbedUrl(p), aspectRatio: 4 / 3)`。下に「Google マップで開く」（`venueMapUri`）。キーが無ければ埋め込みは出さず、ボタンだけ。
- **帰りの経路**：
  - 上に「帰りの駅」の行：登録済みなら「帰りの駅：◯◯」と「変更」、未登録なら入力欄（ヒント「例）東京駅」）と「保存」。保存は `setHomeStation`。保存したら入力欄を閉じる。
  - 帰りの駅があれば `WebIframe(src: homeRouteEmbedUrl(p, station), aspectRatio: 4 / 3)`。駅が無ければ「帰りの駅を登録すると、会場からの電車の経路が出ます」。
  - 下にボタン「Google マップで終電を調べる」（`homeRouteUri`）と、小さな説明「出発の時刻（終演後）や終電は、Google マップで指定できます」。
  - 遠征メモに「帰りの時刻」（`returnAt`）があれば、説明の上に「遠征メモの帰りの出発：11/23(月) 21:30」と出す（判定はしない）。
- 閉じるボタン「閉じる」。

### 5.2 入口

- **ライブ詳細の公演の行**（`lib/features/live/live_detail_page.dart` の `_PerformanceTile`）：ボタンの並び（「行き方」「周辺の宿」「遠征メモ」「その他 ▼」）の先頭に `TextButton.icon`「地図」（`Icons.map_outlined`）。終わった公演・オンラインの公演には出さない（「行き方」と同じ条件）。
- **遠征の一覧のカード**（`lib/features/travel/trip_list_page.dart`）：リンクの並び（`travelLinksOf`）の先頭に同じ「地図」。

## 6. 人が行う設定

1. Google Cloud コンソールで **Maps Embed API** と **Routes API** を有効にする（11/9 済み。Routes API は M-0 の確かめに使っただけで、今は使わない）。
2. 認証情報で `MapsEmbed_key` を作り、API の制限を Maps Embed API だけ、ウェブサイトの制限を 2.2 の3つにする（11/9 済み）。
3. 起動とビルドに `--dart-define=MAPS_EMBED_KEY=<MapsEmbed_key のキー>` を足す（`flutter run` も同じ）。
4. `markdown/deploy_手順.md` の 1.1（ビルド）と 2章に追記する（M-4）。

## 7. 開発ステップ

| Step | 内容 | 状況 |
|---|---|---|
| M-0 | Routes API・Maps Embed API で日本の電車の経路が出るかを確かめる（2.1） | 完了 |
| M-1 | URL（4章）と地図のシートの「会場」（5.1）、入口（5.2） | 未 |
| M-2 | 帰りの駅のデータ（3.1） | 未 |
| M-3 | 地図のシートの「帰りの経路」（5.1） | 未 |
| M-4 | 確認（8章）と `deploy_手順.md` への追記 | 未 |

## 8. 確認すること

1. ライブ詳細の、これからの公演（オンライン以外）に「地図」が出る。押すとシートに会場の地図が出る。終わった公演・オンラインの公演には出ない。
2. 「帰りの経路」で帰りの駅を登録すると、会場からその駅までの電車の経路が地図に出る。別の公演を開いても同じ駅が使われる。
3. 「Google マップで終電を調べる」で、Google マップに同じ経路が電車で開く。
4. 遠征の一覧のカードからも同じシートが開く。
5. `MAPS_EMBED_KEY` を渡さずに起動すると、埋め込みは出ず、「Google マップで開く」のボタンだけが出る。

## 9. 未決定事項

- **車で帰る人向けの所要時間**（Routes API の `DRIVE`。M-0 で返ることを確かめた）。遠征メモの交通手段が車のとき、終演後に出たときの所要時間と到着の目安を Functions で出すか。キー `RoutesAPI_key` は作ってある（使わないなら消す）。
- 終電の判定（間に合う／間に合わない）。Google の API では日本の電車の時刻が取れないため、やるなら日本の乗換案内の API（NAVITIME・駅すぱあと など）が要る。提出後の候補。
- 帰りの駅をプロフィールの画面でも変えられるようにするか（今はシートの中だけ）。
- 行き（自宅 → 会場）の経路も埋め込みで出すか（今は「行き方」のリンクのまま）。