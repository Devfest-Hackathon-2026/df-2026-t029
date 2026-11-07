# おしあし（仮）遠征の機能追加 仕様書（add_E）

> 本ドキュメントは、`claude/11-8 朝の機能追加の計画.md` の 1番（遠征）の仕様書である。
> 今ある遠征サポート（E-1 行き方・周辺の宿、E-2 遠征メモ。`claude/遠征サポートと費用管理の仕様書.md`）に、遠征の一覧・時刻と現地メモ・リンク・天気を足す。
> 前提として、`markdown/add/add_E_H.md`（E-1・E-2・H の仕様書）・`markdown/Database_config.md`・`CLAUDE.md`・`markdown/deploy_手順.md` をあわせて参照すること。

## 0. LLM への指示

- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。「9. 未決定事項」は独自に確定させず、提案として示すこと。
- 本仕様にない作業を勝手に足さないこと。**テストコードは書かない**。
- **コードの編集は人間が Dev Container 内で行う。** LLM はリポジトリを読むだけにして、変更は置き換える部分を丸ごと（メソッド・クラス・ファイル単位で）コードとして提示すること。
- 開発は7章のステップの順に進め、各ステップに1行程度のコミット文を添えること。画面の確認は最後にまとめて行う（人が再起動してから、LLM が Chrome で確かめてよい）。
- 見た目はログイン後のデザイン「ハコ色」に合わせる。コメントで章を書くときは「add_E 3.1」のように仕様書の名前を付ける。
- 追加してよいパッケージは `cloud_functions`（天気の呼び出し）だけ。
- **`firestore.rules` は変えない**（遠征メモは今の `users/{uid}/trips` のまま。天気の置き場は Cloud Functions だけが読み書きし、ルールではすべて拒否のまま）。
- 秘密情報（Weather API のキー）をリポジトリに書かない。`firebase deploy`・コンソールの設定は人間が行う。

## 1. 概要

| 項目 | 内容 |
|---|---|
| 機能名 | 遠征の機能追加（add_E） |
| 担当 | B（横山）。ライブ詳細・ホーム・`app.dart` は A（とし）と共有する |
| ブランチ | `dev` から `features/add_E` |
| 目的 | 遠征を「公演の行のメモ」から、独立した機能（一覧・予定・天気・現地の情報）に見せる |
| 状況 | 未着手 |

## 2. 着手前の作り（11/8 朝の `dev`）

| 対象 | 場所 | 作り |
|---|---|---|
| 遠征メモ | `lib/models/trip.dart`（`Trip`・`TravelTransport`）、`lib/repositories/trip_repository.dart`、`lib/providers/trip_providers.dart`（`myTripsProvider`）、`lib/features/travel/trip_sheet.dart`（`showTripSheet`・`tripSummary`） | `users/{uid}/trips/{performanceId}`：`liveId`・`liveTitle`・`startAt`・`venue`（複製）、交通手段・交通費・宿の名前・宿代・メモ |
| 公演の行 | `lib/features/live/live_detail_page.dart` の `_PerformanceTile` | これからの公演に「行き方」「周辺の宿」、オンライン以外に「遠征メモ」。メモがあれば「遠征：新幹線・宿あり　計 ¥23,800」 |
| リンク | `lib/utils/travel_links.dart`（`isOnlineVenue`・`directionsUri`・`hotelsUri`） | Google マップ |
| 日時の入力 | `lib/features/live_form/date_time_field.dart` の `DateTimeField`（`label`・`value`・`onChanged`）、`formatDateTime` | |
| 公演 | `Performance`（`startAt`・`openAt`・`venue`・`prefecture`） | 都道府県は文字列（例：「東京都」） |
| 自分の公演 | `myPerformancesProvider`・`myLivesProvider` | 自分のライブ一覧のライブの公演 |
| ホーム | `lib/features/home/home_page.dart` | 次の締切 → 今後のライブ → 新しい交換 → 今月の推し活費 → 最近の思い出 |
| ルート | `lib/app.dart` | `/` の子に `expenses`（費用管理）など |
| Cloud Functions | `functions/index.js`（`sendDeadlineReminders`。`asia-northeast1`） | |

## 3. 決定事項：遠征メモの項目（E-3）

`Trip` に次を足す（どれも任意）。

| 項目 | 型 | 内容 |
|---|---|---|
| `departAt` | timestamp | 行きの出発（日時） |
| `returnAt` | timestamp | 帰りの出発（日時）。終電など |
| `checkInAt` | timestamp | 宿のチェックイン（日時） |
| `localNote` | string | 現地メモ（コインロッカー・食事・グッズ列の開始時刻など。500文字まで） |

- 遠征メモのシートの並び：交通手段 → **行きの出発** → **帰りの出発** → 交通費 → 宿の名前 → **チェックイン** → 宿代 → **現地メモ** → メモ。日時は `DateTimeField`。最初に開いたときの日付の候補は公演の日。
- `tripSummary` は今のまま（交通・宿・合計）。時刻は一覧（3章の E-6）と公演の行に出す（下）。
- 公演の行の遠征メモの1行の下に、時刻があれば「行き 11/9(月) 8:30 発 ／ 帰り 22:10 発」を小さく出す。

## 4. 決定事項：リンク（E-4）

`travel_links.dart` に足す。どれもオンラインの公演では null。外部のブラウザで開く。

| ボタン | アイコン | 開く先 |
|---|---|---|
| 周辺のロッカー | `Icons.luggage_outlined` | Google マップの検索「<会場 都道府県> 周辺 コインロッカー」 |
| 周辺のごはん | `Icons.restaurant` | Google マップの検索「<会場 都道府県> 周辺 ごはん」 |
| 乗換案内 | `Icons.train` | Yahoo!乗換案内（到着地に会場名を入れる。日時を入れられれば開演の1時間前着） |
| 宿を予約 | `Icons.bed` | 楽天トラベル（キーワードに都道府県と会場名、チェックインの日を公演の日） |

- 乗換案内・楽天トラベルの URL の形（パラメータ）は、実装のときに実際に開いて確かめてから決める（決められなければ、キーワードだけを入れた検索の URL にする）。
- 公演の行は、ボタンが多くなるので「行き方」「周辺の宿」「遠征メモ」は今のまま見せ、残りは「その他 ▼」（`PopupMenuButton`）にまとめる。遠征の一覧（E-6）では全部を並べる。

## 5. 決定事項：天気（E-5）

### 5.1 しくみ

- Google Maps Platform の **Weather API**（日ごとの予報 `forecast/days:lookup`。今日から最大10日。`pageSize=10` で1回で取る。`languageCode=ja`）。Essentials の SKU で月1万回の無料枠。
- アプリからは直接呼ばず、**Cloud Functions の Callable 関数 `getEventWeather`** を呼ぶ（API キーを守るため。キーは Secret Manager の `WEATHER_API_KEY`）。
- 位置は都道府県の代表地点（都道府県庁の所在地）の表で決める（`functions/prefectures.js`）。都道府県の名前は「都・道・府・県」を外して照合する（「東京」でも「東京都」でも同じ）。
- キャッシュ：Functions が `weatherCache/{都道府県のコード}` に、取った日時と10日分の要約を保存し、**3時間以内**ならそれを返す（同じ地域の公演で何度も呼ばない）。アプリはこのコレクションを読まない（ルールは今のまま拒否）。

### 5.2 Callable 関数 `getEventWeather`

| 入力 | 内容 |
|---|---|
| `prefecture` | 都道府県（例：「東京都」） |
| `date` | 公演の日（`YYYY-MM-DD`、日本時間） |

| 出力 | 内容 |
|---|---|
| `status` | `ok`・`outOfRange`（10日より先、または過去）・`unknownPlace`（都道府県が分からない） |
| `date` | 公演の日 |
| `type` | 天気の種類（`CLEAR`・`PARTLY_CLOUDY`・`CLOUDY`・`RAIN`・`SNOW` など。昼の予報 `daytimeForecast.weatherCondition.type`） |
| `text` | 天気の説明（日本語。例：「晴れ」） |
| `maxC`・`minC` | 最高・最低気温（℃、整数に丸める） |
| `rainPercent` | 昼の降水確率（%） |

- ログインしていない呼び出しは拒否する（`unauthenticated`）。
- Weather API の呼び出しに失敗したら `internal` のエラーにする（アプリは「天気を取得できませんでした」）。

### 5.3 アプリ

- パッケージ `cloud_functions` を足す。`FirebaseFunctions.instanceFor(region: 'asia-northeast1')`。
- `lib/repositories/weather_repository.dart`（`fetch(prefecture, date)`）と `lib/providers/weather_providers.dart`（`eventWeatherProvider`：`FutureProvider.family`。autoDispose にせず、同じ（都道府県・日）は1回だけ呼ぶ）。
- 表示（`lib/features/travel/weather_line.dart` の `WeatherLine`）：「天気予報 ☀ 晴れ 18℃ / 9℃ 降水 10%」。アイコンは `type` から Material のアイコンに置き換える（晴れ `Icons.wb_sunny_outlined`、曇り `Icons.cloud_outlined`、晴れ時々曇り `Icons.wb_cloudy_outlined`、雨 `Icons.umbrella`、雪 `Icons.ac_unit`、雷 `Icons.thunderstorm_outlined`、そのほか `Icons.cloud_outlined`）。Weather API の画像のアイコンは使わない（Flutter Web で外部の画像を出すには CORS が要るため）。
- 出す場所：公演の行（これからの公演で、公演の日が今日から9日後までのとき）、遠征の一覧のカード（E-6）。範囲の外では何も出さない（読み込み中は何も出さない）。

### 5.4 人が行う設定

1. Google Cloud コンソールで **Weather API** を有効にする。
2. 「認証情報」で API キーを作り、**API の制限で Weather API だけ**に絞る（サーバーから使うので、アプリケーションの制限は付けない）。
3. `firebase functions:secrets:set WEATHER_API_KEY` でキーを保存する（リポジトリには書かない）。
4. `firebase deploy --only functions`。

## 6. 決定事項：遠征の一覧（E-6）

- 新しい画面 `/trips`（`lib/features/travel/trip_list_page.dart` の `TripListPage`。`/` の子に置き、戻るとホーム）。見出し「遠征」。
- **これからの遠征**：自分のライブ一覧の公演のうち、オンライン以外で、開演が今日以降のもの（開演の早い順）。1つの公演を1枚のカードにする。
  - カード：日付の札・ライブ名・開演・会場（都道府県）・天気（5章）・遠征メモの中身（交通手段と行き・帰りの時刻、宿の名前とチェックイン、現地メモ、費用の合計）。
  - 下に、行き方・乗換案内・周辺の宿・宿を予約・周辺のロッカー・周辺のごはん（4章）と「遠征メモ」（無ければ「遠征メモを作る」）。
  - カードを押すとライブ詳細へ。
- **これまでの遠征**：遠征メモがある公演のうち、開演が今日より前のもの（新しい順）。カードは小さく（ライブ名・日付・会場・交通・宿・費用）。
- 公演が1件も無いときは「自分のライブ一覧にライブを追加すると、遠征の予定がここに並びます」。
- **ホームの入口**：今後のライブの下に「次の遠征」の区画（`lib/features/home/home_next_trip.dart`）。これからの遠征の最初の1件を小さなカードで出し、「すべて見る」で `/trips`。これからの遠征が無ければ区画ごと出さない。
- PC の幅では、Fc-6 と同じく `maxContentWidth: 1080` にし、本文の幅が 900 以上ならカードを2列に並べる。

## 7. 開発ステップ

| Step | 内容 | 状況 |
|---|---|---|
| E-3 | 遠征メモの項目（時刻・現地メモ）。モデル・シート・公演の行の時刻（3章） | 未着手 |
| E-4 | リンクの追加（4章）。公演の行の「その他」 | 未着手 |
| E-5 | 天気（5章）。Functions（`getEventWeather`・都道府県の表・キャッシュ）とアプリ（リポジトリ・プロバイダ・`WeatherLine`・公演の行） | 未着手 |
| E-6 | 遠征の一覧とホームの入口（6章） | 未着手 |
| E-7 | （時間があれば）Gemini の遠征の案（9章） | 未着手 |
| E-8 | 確認。`markdown/deploy_手順.md` に Weather API・シークレットの手順を追記 | 未着手 |

## 8. 確認すること

1. 遠征メモに行き・帰り・チェックイン・現地メモを入れて保存 → 公演の行と遠征の一覧に出る。
2. 公演の行の「その他」から、ロッカー・ごはん・乗換案内・宿の予約が開く。
3. 公演の日が9日後までなら天気予報が出る（デモ用データの基準日が今日〜近い日になるように入れる）。10日より先の公演には出ない。
4. 遠征の一覧に、これからの遠征（メモが無い公演も）とこれまでの遠征が並ぶ。ホームに「次の遠征」が出て、「すべて見る」で一覧へ。
5. Functions のログにエラーが無い。同じ都道府県で2回目はキャッシュから返る（Weather API の呼び出しが増えない）。

## 9. 未決定事項

- Gemini の遠征の案（E-7）：出発地を入れると、行き方の候補・宿を取る地域・注意点を文章で出す。出発地を個人の設定に覚えるか。提案の正しさは保証できないので、Google マップ・乗換案内のリンクと並べる。
- メモリーへの天気の記録（add_R で扱う）。Weather API の履歴は過去24時間しか取れないため、公演の前後に取った予報・現在の天気を記録に保存する形になる。
- 遠征マップ（参戦した会場を地図に。提出後）。