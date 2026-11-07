# おしあし（仮）遠征サポートと費用管理 仕様書
 
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
| 担当 | B（横山）。ライブ詳細・ホームなど A（とし）の担当範囲のファイルは、A と共有する |
| ブランチ | 人間が作る |
| 目的 | 予定（公演・当選したチケット）と、移動・宿・お金をつなげ、「推し活をまとめて管理する」アプリとして見せる |
| 締切 | 11/10 の提出まで。11/9（月）の撮影に間に合わせたい |
 
## 2. 今のコードの構造（11/7 時点の `dev`）
 
| 対象 | 場所 | 今の作り |
|---|---|---|
| 公演の行 | `lib/features/live/live_detail_page.dart` の `_PerformanceTile`（A の担当） | `ListTile`。開演日時・開場・会場（都道府県）を出し、右に「記録する／記録を見る」 |
| 公演 | `lib/models/performance.dart` | `id`・`liveId`・`startAt`・`openAt`・`venue`・`prefecture` など |
| 受付 | `lib/models/reception.dart` | `applyEndAt`・`resultAt`・`paymentDeadline`・`prices`（席種と料金の一覧）など |
| 申込状況 | `applicationsProvider`（`Map<受付 ID, Application>`）。`status` は未申込（なし）・申込済・当選・落選・入金済 | `users/{uid}/applications/{receptionId}` |
| 自分のライブ | `myLivesProvider`・`myPerformancesProvider`・`myReceptionsProvider` | 自分のライブ一覧（`myLives`）に入っているライブだけ |
| 外部リンク | `url_launcher` が入っている | 公式ページのリンク（`OfficialUrlLink`）などで使っている |
| ホーム | `lib/features/home/home_page.dart` | ①あいさつ ②次の締切 ③今後のライブ ④新しい交換 ⑤最近の思い出 |
| ルート | `lib/app.dart` | ログイン後の画面は ShellRoute の中（外枠のタブ付き） |
| ルール | `firestore.rules` | `users/{uid}/{サブコレクション}/**` は本人なら読み書きできる（`applications`・`myLives` は専用の検査） |
 
## 3. 決定事項：遠征サポート（E）
 
### 3.1 行き方・周辺の宿のボタン（E-1）
 
ライブ詳細の公演の行（`_PerformanceTile`）に、会場をもとに Google マップを開くボタンを2つ足す。
 
| ボタン | 開く URL（`url_launcher` の `launchUrl`、外部で開く） |
|---|---|
| 行き方（`Icons.directions`） | `https://www.google.com/maps/dir/?api=1&destination=<会場名 都道府県>` |
| 周辺の宿（`Icons.hotel`） | `https://www.google.com/maps/search/?api=1&query=<会場名 都道府県 周辺 ホテル>` |
 
- クエリは `Uri.https` で作り、日本語を正しくエンコードする（文字列の連結で URL を作らない）。
- 会場名に「オンライン」または「配信」を含む公演では出さない（行く場所がないため）。
- 終了した公演では出さない。
- 行の下に、小さいボタン（`TextButton.icon`）を横に並べる（`Wrap`）。今の「記録する／記録を見る」は右のまま。
- URL を作る関数は `lib/utils/travel_links.dart`（新規）に置く：`Uri? directionsUri(Performance p)`・`Uri? hotelsUri(Performance p)`（オンラインなら null）。
### 3.2 遠征メモ（E-2）
 
公演ごとに、交通手段・交通費・宿・宿代・メモを記録できるようにする。費用管理（H）の「遠征」に使う。
 
**データ：`users/{uid}/trips/{performanceId}`（新規）**
 
| 項目 | 型 | 必須 | 内容 |
|---|---|---|---|
| `liveId` | string | ○ | ライブの ID |
| `liveTitle` | string | ○ | ライブ名（複製。一覧の表示用） |
| `startAt` | timestamp | ○ | 開演日時（複製。費用の月を決めるのに使う） |
| `venue` | string | ○ | 会場名（複製） |
| `transport` | string | | 交通手段（下の選択肢のどれか） |
| `transportCost` | number | | 交通費（円、往復の合計） |
| `hotelName` | string | | 宿の名前（100文字まで） |
| `hotelCost` | number | | 宿代（円） |
| `note` | string | | メモ（500文字まで） |
| `createdAt` / `updatedAt` | timestamp | ○ | 作成・更新日時 |
 
- 交通手段の選択肢（`TravelTransport` の enum、保存は `code`）：新幹線（`shinkansen`）・飛行機（`plane`）・高速バス（`bus`）・電車（`train`）・車（`car`）・その他（`other`）。
- 金額は 0〜1,000,000 の整数。空欄なら項目を入れない。
**画面**
 
- 公演の行の E-1 のボタンの隣に「遠征メモ」（`Icons.luggage`）を出す（オンラインの公演・終了した公演でも出す。終了後に記録したい人がいるため。ただしオンラインは出さない）。
- 押すと、下から入力のシート（`showModalBottomSheet`、`isScrollControlled: true`、`useRootNavigator: true`）を出す：交通手段（`ChoiceChip` の並び）・交通費・宿の名前・宿代・メモ・「保存」。記録があれば値を入れて開き、「削除」も出す。
- 記録がある公演の行には、「遠征：新幹線・宿あり　計 ¥32,000」のような1行を出す。
- 構成：モデル `lib/models/trip.dart`（`Trip`）、リポジトリ `lib/repositories/trip_repository.dart`（`watchAll(uid)`・`save(uid, trip)`・`delete(uid, performanceId)`）、プロバイダ `lib/providers/trip_providers.dart`（`tripsProvider`：`Map<公演 ID, Trip>`）、シート `lib/features/travel/trip_sheet.dart`。
## 4. 決定事項：費用管理（H）
 
### 4.1 出費の3つの出どころ
 
月ごとの出費は、次の3つを合わせて出す。
 
| 種類 | 出どころ | 金額 | どの月の出費か |
|---|---|---|---|
| チケット（`ticket`） | 申込状況が**当選・入金済**の受付（自分のライブ一覧のライブのもの） | 席種と枚数の設定（4.2）があればそれ。なければ受付の料金の**最初の席種 × 1枚**（料金が無ければ 0 円で「金額未設定」） | 入金期限 → なければ当落発表 → なければ申込期限 の日 |
| 遠征（`travel`） | 遠征メモ（3.2） | 交通費＋宿代（どちらも無ければ出さない） | 開演日 |
| 手入力（`goods`・`other` など） | 自分で追加した出費（4.3） | 入力した金額 | 入力した日付 |
 
- チケットと遠征は、**自動で出る**（デモで、入力しなくても合計が出るように）。
### 4.2 チケット代の設定（`users/{uid}/ticketCosts/{receptionId}`、新規）
 
| 項目 | 型 | 必須 | 内容 |
|---|---|---|---|
| `seat` | string | ○ | 席種（受付の料金の席種名。料金が無い受付は自由入力） |
| `unitPrice` | number | ○ | 1枚の料金（円） |
| `count` | number | ○ | 枚数（1〜8） |
| `updatedAt` | timestamp | ○ | 更新日時 |
 
- 費用管理の画面でチケットの行を押すと、席種（受付の料金から選ぶ `DropdownButton`。選ぶと料金が入る）と枚数を選ぶシートを出す。保存すると、金額は `unitPrice × count`。
### 4.3 手入力の出費（`users/{uid}/expenses/{自動 ID}`、新規）
 
| 項目 | 型 | 必須 | 内容 |
|---|---|---|---|
| `category` | string | ○ | 種類：グッズ（`goods`）・遠征（`travel`）・その他（`other`）。チケットは 4.1 で自動なので選ばせない |
| `title` | string | ○ | 内容（例：TOUR グッズ、ペンライト。50文字まで） |
| `amount` | number | ○ | 金額（円、1〜1,000,000 の整数） |
| `date` | timestamp | ○ | 日付（日だけ使う） |
| `liveId` | string | | 関係するライブの ID（任意。自分のライブ一覧から選ぶ） |
| `liveTitle` | string | | ライブ名（複製） |
| `createdAt` / `updatedAt` | timestamp | ○ | 作成・更新日時 |
 
### 4.4 予算（`users/{uid}/settings/budget`、新規）
 
| 項目 | 型 | 必須 | 内容 |
|---|---|---|---|
| `monthly` | number | ○ | 1か月の予算（円） |
| `updatedAt` | timestamp | ○ | 更新日時 |
 
- `users/{uid}` 本体には足さない（本体のルールの検査を変えないため）。
### 4.5 集計（純粋関数）
 
`lib/utils/expense_summary.dart`（新規）に、画面から切り離した集計を置く。
 
- `ExpenseItem`：1件の出費（種類・内容・金額・日付・ライブ名・出どころ（チケット／遠征／手入力）・元の ID・金額未設定か）。
- `List<ExpenseItem> buildExpenseItems({受付の一覧, 申込状況, ライブの一覧, チケット代の設定, 遠征メモ, 手入力の出費})`：4.1 の規則で全件を作る。
- `MonthSummary summarizeMonth(List<ExpenseItem> items, int year, int month)`：その月の件（日付の新しい順）、合計、種類ごとの合計。
- 日付は端末の時刻（日本時間の前提）で月を決める。
### 4.6 費用管理の画面（`/expenses`、新規 `lib/features/expense/expense_page.dart`）
 
```
┌──────────────────────────────┐
│ ← 推し活費                         │
│   ‹  2026年11月  ›                │  ← 月の切り替え（前の月・次の月）
│ ┌────────────────────────┐    │
│ │ ¥58,300 / 予算 ¥60,000       │    │  ← 合計と予算（予算は押すと変えられる）
│ │ ████████████████████░ 97%    │    │  ← 予算に対する割合。超えたら error の色
│ └────────────────────────┘    │
│ チケット ¥36,000 ████████          │  ← 種類ごとの合計（横の棒。いちばん大きいものが幅いっぱい）
│ 遠征     ¥17,800 ████              │
│ グッズ   ¥4,500  █                 │
│ ─────────────────────────     │
│ 11/16 チケット ステラノート…  ¥12,000 │  ← その月の出費（日付の新しい順）
│ 11/12 チケット ルミナス…      ¥7,000  │
│ …                                  │
│                      [＋ 出費を追加] │
└──────────────────────────────┘
```
 
- 月の初期値は今月。
- 予算が未設定なら「予算を決める」ボタンを出し、割合の棒は出さない。予算を超えたら、棒と割合を `scheme.error` の色にする。
- 種類ごとの色は、テーマの色の濃さを変えて分ける（グラフ用のパッケージは使わない。`Container` の幅で棒を描く）。
- 出費の行：
  - チケット：押すと 4.2 のシート。金額未設定なら「金額未設定」と出す。
  - 遠征：押すと、その公演の遠征メモのシート（3.2）。
  - 手入力：押すと、編集のシート（4.3。「削除」もある）。
- 右下の「出費を追加」で、手入力のシートを開く（種類・内容・金額・日付・ライブ（任意））。
- その月に1件もなければ、`EmptyState`（`Icons.savings`）で「この月の出費はまだありません」。
- 構成：モデル `lib/models/expense.dart`（`Expense`・`TicketCost`・`Budget`）、リポジトリ `lib/repositories/expense_repository.dart`、プロバイダ `lib/providers/expense_providers.dart`、画面とシート `lib/features/expense/`。
### 4.7 画面への入口
 
- **ホーム**に「今月の推し活費」の区画を足す（③今後のライブの下、④新しい交換の上）。今月の合計・予算に対する割合の棒・「くわしく見る」（`/expenses` へ）。予算が未設定なら合計だけ。
  - 区画の部品は `lib/features/home/home_expense_summary.dart`（新規）。
- ルート `/expenses` は ShellRoute の中に置き、外枠のタブは「ホーム」を選んだ状態にする（`tabIndexFor` は今のまま。`/expenses` はどの条件にも当たらないので 0 になる）。
- ライブ詳細には入口を足さない（遠征メモは公演の行から入れる）。
## 5. デモ用データ（H-4）
 
`tools/seed/demo_personal.mjs` に、けんの分を足す（`firebase firestore:delete` で消してから入れ直す前提）。
 
| 種類 | 内容 |
|---|---|
| 遠征メモ | L01 の東京1日目（新幹線 ¥14,000・宿 ¥9,800）、L02 の1日目（新幹線 ¥8,000、宿なし）、L14 の金沢公演（新幹線 ¥28,000・宿 ¥7,500。終了済み） |
| チケット代の設定 | L01 の FC 先行（S席 ¥12,000 × 2枚） |
| 手入力の出費 | グッズ3件（例：TOUR グッズ ¥4,500、ペンライト ¥3,800、ランダムアクスタ ¥2,400）、その他1件（例：CD ¥1,500）。日付は基準日の前後の今月と先月にばらけさせる |
| 予算 | 1か月 ¥60,000 |
 
- 撮影の月（11月）に、予算に近い（90%前後の）合計が出るように金額を調整する。
## 6. 変えるファイル
 
| ファイル | 変更 | ステップ |
|---|---|---|
| `lib/utils/travel_links.dart` | 新規（行き方・宿の URL） | E-1 |
| `lib/features/live/live_detail_page.dart` | 公演の行にボタンと遠征の1行（A と共有） | E-1・E-2 |
| `lib/models/trip.dart`・`lib/repositories/trip_repository.dart`・`lib/providers/trip_providers.dart`・`lib/features/travel/trip_sheet.dart` | 新規 | E-2 |
| `lib/models/expense.dart`・`lib/repositories/expense_repository.dart`・`lib/providers/expense_providers.dart`・`lib/utils/expense_summary.dart` | 新規 | H-1 |
| `lib/features/expense/expense_page.dart` と、シート（チケット代・手入力・予算） | 新規 | H-2 |
| `lib/features/home/home_expense_summary.dart`・`lib/features/home/home_page.dart`・`lib/app.dart` | ホームの区画、ルート（A と共有） | H-3 |
| `tools/seed/demo_personal.mjs` | デモ用データ | H-4 |
 
## 7. 開発ステップ
 
| Step | 内容 | 状況 |
|---|---|---|
| E-1 | 行き方・周辺の宿のボタン（3.1） | |
| E-2 | 遠征メモ（3.2） | |
| H-1 | 費用のデータ・リポジトリ・集計（4.1〜4.5） | |
| H-2 | 費用管理の画面とシート（4.6） | |
| H-3 | ホームの区画とルート（4.7） | |
| H-4 | デモ用データ（5章） | |
 
- 時間が足りなければ、E-1・E-2 を先に仕上げ、H は H-1〜H-3 までを優先する。
## 8. 確認すること（最後にまとめて）
 
- E-1：ライブ詳細の未来の公演に「行き方」「周辺の宿」が出て、押すと Google マップが会場で開く。オンライン配信・終了した公演には出ない。
- E-2：「遠征メモ」で交通・宿を保存でき、公演の行に合計が出る。開き直すと値が入っていて、削除もできる。
- H-1〜H-2：費用管理で、当選・入金済のチケット代と遠征費が自動で出る。チケットの席種・枚数を変えると金額が変わる。出費を追加・編集・削除できる。月を切り替えられる。予算を超えると色が変わる。
- H-3：ホームに今月の合計と予算の棒が出て、「くわしく見る」で費用管理が開く。
- H-4：デモ用データを入れ直すと、けんの11月の合計が予算の90%前後になる。
## 9. 未決定事項
 
- 遠征サポートで、Gemini に移動・宿の候補を提案させるか（時間が余れば。提案の正しさは保証できないため、Google マップのリンクと組み合わせる）
- 費用の CSV 書き出し（今回は作らない）
- 自分のライブ一覧に入っていないライブの受付のチケット代（今回は対象外）
 