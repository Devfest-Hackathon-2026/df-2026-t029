# おしあし遠征サポートと費用管理 仕様書
 
> 本ドキュメントは、方針書（「コンペで作成するものの方針」4.6 遠征サポート・4.8 費用管理、どちらも P3）を、11/10 の提出までに作るための仕様書である。
> チームメンバーおよび開発支援に使う LLM が、この文書だけを読んで同じ前提で作業できるように、今のコードの構造と、変更後の形を具体的に書いている。
> 前提として、`markdown/Database_config.md`・`CLAUDE.md`・`claude/デモ用データの仕様書.md` をあわせて参照すること。
 
## 0. LLM への指示
 
- 本ドキュメントの「決定事項」は確定した仕様として扱うこと。「9. 未決定事項」は独自に確定させず、提案として示すこと。
- 本仕様にない作業を勝手に足さないこと。**テストコードは書かない**（`test/` は analyze の対象から外してある）。
- **コードの編集は人間が Dev Container 内で行う。** LLM はリポジトリを読むだけにして、変更は置き換える部分を丸ごと（メソッド・クラス・ファイル単位で）コードとして提示すること。「ここだけ変える」「外側だけ包む」のような部分的な説明はしない。
- 開発は7章のステップの順に進め、各ステップに1行程度のコミット文を添えること。画面の確認は最後にまとめて行う。
- 既存のコードの書き方に合わせること（Riverpod 3 を手書き・コード生成なし、go_router、Firebase へのアクセスは `lib/repositories/` に閉じ込める、文言・コメントは日本語、色はテーマから取る）。
- **新しいパッケージは追加しない。** Firebase の新しい機能（Storage・Functions など）も使わない。Blaze への切り替えは不要。
- **`firestore.rules` は変えない。** 新しいデータはすべて `users/{uid}` の下のサブコレクションに置く。今のルールの `match /users/{userId}/{subcollection}/{document=**}`（`applications`・`myLives` 以外は本人なら読み書きできる）でそのまま守られる。
## 1. 概要
 
| 項目 | 内容 |
|---|---|
| 機能名 | 遠征サポート（E）・費用管理（H） |
| 担当 | B（横山）。ライブ詳細・ホーム・`app.dart` など A（とし）の担当範囲のファイルは、A と共有する |
| ブランチ | `features/E`（dev にマージ済み）→ dev から `feature/H` |
| 目的 | 予定（公演・当選したチケット）と、移動・宿・お金をつなげ、「推し活をまとめて管理する」アプリとして見せる |
| 状況 | **E-1〜E-2・H-1〜H-4 完了（11/7、画面で確認済み）** |
 
## 2. 着手前のコードの構造（11/7 時点の `dev`）
 
| 対象 | 場所 | 作り |
|---|---|---|
| 公演の行 | `lib/features/live/live_detail_page.dart` の `_PerformanceTile`（A の担当） | `ListTile`。開演日時・開場・会場（都道府県）を出し、右に「記録する／記録を見る」 |
| 公演 | `lib/models/performance.dart` | `id`・`liveId`・`startAt`・`openAt`・`venue`・`prefecture` など |
| 受付 | `lib/models/reception.dart` | `applyEndAt`・`resultAt`・`paymentDeadline`・`prices`（`Price`：席種 `seat` と料金 `amount` の一覧）など |
| 申込状況 | `applicationsProvider`（`Map<受付 ID, Application>`） | `users/{uid}/applications/{receptionId}`。状態は未申込（なし）・申込済・当選・落選・入金済 |
| 自分のライブ | `myLivesProvider`・`myPerformancesProvider`・`myReceptionsProvider` | 自分のライブ一覧（`myLives`）に入っているライブだけ |
| 外部リンク | `url_launcher`（既存） | `launchUrl(uri, mode: LaunchMode.externalApplication)` |
| 金額の書き方 | `lib/features/live_form/live_draft_to_models.dart` の `formatYen(int)` | 3桁ごとにカンマ（`¥` は付かない） |
| ホーム | `lib/features/home/home_page.dart` | ①あいさつ ②次の締切 ③今後のライブ ④新しい交換 ⑤最近の思い出 |
 
## 3. 決定事項：遠征サポート（E）
 
### 3.1 行き方・周辺の宿のボタン（E-1）
 
ライブ詳細の公演の行（`_PerformanceTile`）に、会場をもとに Google マップを開くボタンを2つ足す。
 
| ボタン | 開く URL（外部で開く） |
|---|---|
| 行き方（`Icons.directions`） | `https://www.google.com/maps/dir/?api=1&destination=<会場名 都道府県>` |
| 周辺の宿（`Icons.hotel`） | `https://www.google.com/maps/search/?api=1&query=<会場名 都道府県 周辺 ホテル>` |
 
- URL は `lib/utils/travel_links.dart` の `directionsUri(p)`・`hotelsUri(p)` が `Uri.https` で作る（日本語は正しくエンコードされる）。会場名に「オンライン」「配信」を含む公演（`isOnlineVenue(p)`）は null。
- 終了した公演には出さない。
- 行の下に、小さいボタン（`TextButton.icon`、アイコン 18）を `Wrap` で横に並べる。「記録する／記録を見る」は右のまま。
### 3.2 遠征メモ（E-2）
 
公演ごとに、交通手段・交通費・宿・宿代・メモを記録できるようにする。費用管理（H）の「遠征」に使う。
 
**データ：`users/{uid}/trips/{performanceId}`**
 
| 項目 | 型 | 必須 | 内容 |
|---|---|---|---|
| `liveId` | string | ○ | ライブの ID |
| `liveTitle` | string | ○ | ライブ名（複製） |
| `startAt` | timestamp | ○ | 開演日時（複製。費用の月を決めるのに使う） |
| `venue` | string | ○ | 会場名（複製） |
| `transport` | string | | 交通手段：新幹線（`shinkansen`）・飛行機（`plane`）・高速バス（`bus`）・電車（`train`）・車（`car`）・その他（`other`） |
| `transportCost` | number | | 交通費（円、往復の合計。0〜1,000,000） |
| `hotelName` | string | | 宿の名前（100文字まで） |
| `hotelCost` | number | | 宿代（円。0〜1,000,000） |
| `note` | string | | メモ（500文字まで） |
| `createdAt` / `updatedAt` | timestamp | ○ | 作成・更新日時（保存は丸ごと書き換え。作成日時は引き継ぐ） |
 
**画面**
 
- 公演の行に「遠征メモ」（`Icons.luggage`）を出す。オンライン以外の公演に出し、終了した公演にも出す（終わった後に記録したい人がいるため）。
- 押すと、下から入力のシート（`useRootNavigator: true`）：交通手段（`ChoiceChip`、もう一度押すと外れる）・交通費・宿の名前・宿代・メモ・「保存」。記録があれば値を入れて開き、「この遠征メモを削除」も出す。金額の欄は数字だけ入力できる。
- 記録がある公演の行には、「遠征：新幹線・宿あり　計 ¥23,800」のような1行を、テーマの色の太字で出す（`tripSummary(trip)`）。
- `_PerformanceTile` は `ConsumerWidget` にし、`myTripsProvider` を自分で読む。ライブ名を渡すため、引数 `liveTitle` を足した。
**ファイル**：`lib/models/trip.dart`（`TravelTransport`・`Trip`）、`lib/repositories/trip_repository.dart`、`lib/providers/trip_providers.dart`（`tripRepositoryProvider`・`myTripsProvider`）、`lib/features/travel/trip_sheet.dart`（`showTripSheet`・`tripSummary`）。
 
## 4. 決定事項：費用管理（H）
 
### 4.1 出費の3つの出どころ
 
| 種類 | 出どころ | 金額 | どの月の出費か |
|---|---|---|---|
| チケット | 申込状況が**当選・入金済**の受付（自分のライブ一覧のライブのもの） | チケット代の設定（4.2）があればそれ。なければ受付の料金の**最初の席種 × 1枚**（料金が無ければ 0 円で「金額未設定」） | 入金期限 → なければ当落発表 → なければ申込期限 |
| 遠征 | 遠征メモ（交通費か宿代が入っているもの） | 交通費＋宿代 | 開演日 |
| 手入力 | 自分で追加した出費（4.3） | 入力した金額 | 入力した日付 |
 
- チケットと遠征は**自動で出る**。遠征の行の名前は会場名だけにする（種類の「遠征」と重ならないように。H-2x）。
### 4.2 チケット代の設定（`users/{uid}/ticketCosts/{receptionId}`）
 
| 項目 | 型 | 必須 | 内容 |
|---|---|---|---|
| `seat` | string | ○ | 席種 |
| `unitPrice` | number | ○ | 1枚の料金（円） |
| `count` | number | ○ | 枚数（1〜8） |
| `updatedAt` | timestamp | ○ | 更新日時 |
 
- 費用管理でチケットの行を押すと、席種（受付の料金から選ぶ。料金が無い受付は席種と料金を手で入力）と枚数のシート。合計を出す。設定があれば「最初の席種 × 1枚に戻す」（設定を消す）も出す。
### 4.3 手入力の出費（`users/{uid}/expenses/{自動 ID}`）
 
| 項目 | 型 | 必須 | 内容 |
|---|---|---|---|
| `category` | string | ○ | グッズ（`goods`）・遠征（`travel`）・その他（`other`）。チケット（`ticket`）は自動なので選ばせない |
| `title` | string | ○ | 内容（50文字まで） |
| `amount` | number | ○ | 金額（1〜1,000,000 円） |
| `date` | timestamp | ○ | 日付（その日の 0:00 で保存） |
| `liveId` / `liveTitle` | string | | 関係するライブ（任意。自分のライブ一覧から選ぶ） |
| `createdAt` / `updatedAt` | timestamp | ○ | 作成・更新日時 |
 
### 4.4 予算（`users/{uid}/settings/budget`）
 
| 項目 | 型 | 必須 | 内容 |
|---|---|---|---|
| `monthly` | number | ○ | 1か月の予算（円） |
| `updatedAt` | timestamp | ○ | 更新日時 |
 
- `users/{uid}` 本体には足さない（本体のルールの検査を変えないため）。「予算を消す」でドキュメントを消す。
### 4.5 集計（`lib/utils/expense_summary.dart`）
 
- `ExpenseSource`（`ticket`・`trip`・`manual`）、`ExpenseItem`（出どころ・元の ID・種類・内容・金額・日付・ライブ名・補足（例：「S席 × 2枚」「新幹線・宿あり」）・金額未設定か）。
- `buildExpenseItems({receptions, applications, lives, ticketCosts, trips, expenses})`：4.1 の規則で全件を作る。
- `summarizeMonth(items, year, month)` → `MonthSummary`（その月の件を日付の新しい順、合計、種類ごとの合計（全種類を持ち、無ければ 0））。
- プロバイダ（`lib/providers/expense_providers.dart`）：`expenseRepositoryProvider`・`myExpensesProvider`・`myTicketCostsProvider`・`myBudgetProvider`・`expenseItemsProvider`（6つの元データのどれかがエラーならエラー、どれかが読み込み中なら読み込み中）。
### 4.6 費用管理の画面（`/expenses`）
 
- `lib/features/expense/expense_page.dart`（`ExpensePage`）。上から：月の切り替え（‹ 2026年11月 ›、初期値は今月）、合計と予算のカード（予算に対する割合の棒。超えたら `scheme.error` の色で「予算を ¥◯ 超えています」。「予算を決める／変える」）、種類ごとの横棒（いちばん大きい種類が幅いっぱい。色はテーマの色を透かして分ける）、その月の出費の一覧（日付の新しい順）。
- 出費の行を押すと、出どころに合わせたシート：チケット → チケット代、遠征 → 遠征メモ（その公演が自分のライブ一覧にあるとき）、手入力 → 編集（削除もできる）。
- 右下の「出費を追加」で手入力のシート。その月に1件もなければ `EmptyState`（「この月の出費はまだありません」）。
- シートは `lib/features/expense/expense_sheets.dart`（`showManualExpenseSheet`・`showTicketCostSheet`・`showBudgetSheet`）。
### 4.7 画面への入口
 
- **ホーム**の③今後のライブの下に「今月の推し活費」（`lib/features/home/home_expense_summary.dart`）：今月の合計・予算・割合の棒。カードか「すべて見る」で `/expenses` へ。
- ルート `/expenses` は `/` の子として ShellRoute の中に置く（戻るとホーム。外枠のタブは「ホーム」）。
## 5. デモ用データ（H-4）
 
`tools/seed/demo_personal.mjs` の `buildKenMoney`。撮影の11月の合計が **¥89,700（予算 ¥100,000 の90%）** になるようにした（最初の案の予算 ¥60,000 では、自動で出るチケット代と遠征費だけで超えてしまったため）。
 
| 種類 | 内容 |
|---|---|
| 遠征メモ | L01 東京1日目（新幹線 ¥14,000・ホテル ドリームステイ東京 ¥9,800・メモあり。12月）、L02 1日目（新幹線 ¥8,000。12月）、L14 金沢公演（新幹線 ¥28,000・金沢ことのはイン ¥7,500。11月・終了済み） |
| チケット代の設定 | L01 の FC 先行：S席 ¥12,000 × 2枚 |
| 手入力の出費 | ペンライト ¥3,800（D-3）・TOUR ランダムアクスタ 3個 ¥2,400（D-6）・1st ライブ グッズ ¥4,500（D-20）・ファンクラブ年会費 ¥4,800（D-25） |
| 予算 | ¥100,000 |
 
11月の内訳：チケット ¥48,000（FC先行 ¥24,000・フェス ¥7,500・ワンマン ¥7,000・ライブハウスツアー ¥4,500・アコースティック ¥5,000）＋遠征 ¥35,500＋グッズ ¥6,200。
 
## 6. 変えたファイル
 
| ファイル | 変更 | ステップ |
|---|---|---|
| `lib/utils/travel_links.dart` | 新規 | E-1 |
| `lib/features/live/live_detail_page.dart` | 公演の行にボタン・遠征メモ（A と共有） | E-1・E-2 |
| `lib/models/trip.dart`・`lib/repositories/trip_repository.dart`・`lib/providers/trip_providers.dart`・`lib/features/travel/trip_sheet.dart` | 新規 | E-2 |
| `lib/models/expense.dart`・`lib/repositories/expense_repository.dart`・`lib/providers/expense_providers.dart`・`lib/utils/expense_summary.dart` | 新規 | H-1（H-2x で遠征の行の名前を修正） |
| `lib/features/expense/expense_page.dart`・`lib/features/expense/expense_sheets.dart` | 新規 | H-2 |
| `lib/features/home/home_expense_summary.dart` | 新規 | H-3 |
| `lib/features/home/home_page.dart`・`lib/app.dart` | ホームの区画・ルート（A と共有） | H-3 |
| `tools/seed/demo_personal.mjs` | `buildKenMoney` | H-4 |
 
## 7. 開発ステップ
 
| Step | 内容 | 状況 |
|---|---|---|
| E-1 | 行き方・周辺の宿のボタン（3.1） | 完了 |
| E-2 | 遠征メモ（3.2） | 完了 |
| H-1 | 費用のデータ・リポジトリ・集計（4.1〜4.5） | 完了 |
| H-2 | 費用管理の画面とシート（4.6）。H-2x：遠征の行の名前を会場名だけに | 完了 |
| H-3 | ホームの区画とルート（4.7） | 完了 |
| H-4 | デモ用データ（5章） | 完了 |
 
## 8. 確認したこと（11/7、デモ用データの基準日 11/9）
 
- E-1：ライブ詳細の未来の公演に「行き方」「周辺の宿」が出る。「行き方」で Google マップが会場への経路で開く。
- E-2：東京1日目に「遠征：新幹線・宿あり　計 ¥23,800」。遠征メモのシートに入れた値が入っていて、削除のボタンも出る。
- H-1〜H-2：費用管理の11月に ¥89,700 / 予算 ¥100,000（90%）、種類ごとの横棒（チケット ¥48,000・遠征 ¥35,500・グッズ ¥6,200・その他 ¥0）、出費8件。チケットの行からチケット代のシート（S席 ¥12,000 × 2枚 = ¥24,000）が開く。
- H-3：ホームに「今月の推し活費」（¥89,700・予算の90%の棒）。
- 架空の会場名でも、Google マップは似た名前の実在の場所を出すことがある（デモでは「経路が開く」ことを見せる）。
## 9. 未決定事項
 
- 遠征サポートで、Gemini に移動・宿の候補を提案させるか（時間が余れば。提案の正しさは保証できないため、Google マップのリンクと組み合わせる）
- 費用の CSV 書き出し（今回は作らない）
- 自分のライブ一覧に入っていないライブの受付のチケット代（今回は対象外）
 