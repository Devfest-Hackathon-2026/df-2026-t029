# Step2 実装計画: ライブ・公演・受付の手入力登録と一覧、個人の申込状況

> 担当A（とし）の Step2 を、Claude Code の agent team（リーダー＋チームメイト3人）で実装するための指示書。
> 人間とエージェントの両方が読む。仕様書 `markdown/app_config.md` の 4.2（予定管理）と 4.4（共通データ）の一部を実装する。
> 「3. 実装前に合意すること」はすべて**提案**であり、ユーザーが合意するまで確定させない。

## 0. 作業ブランチと前提

- **作業ブランチは `feature/step2`。** ブランチの作成・切り替え・pull・push は人間が行う。エージェントはブランチを切り替えない。
- 完成したら、人間が `feature/step2` から `dev` へ Pull Request を出す。
- 開始前に、リーダーは `git status -sb` で `feature/step2` にいて、GitHub より遅れていない（`behind` が無い）ことを確かめる。遅れていたらユーザーに `git pull --no-rebase` を頼む。
- 全体の段取り（Notion「開発タスク」）: Step0 土台 → Step1 推し（完了）→ **Step2 ライブの手入力登録・一覧・申込状況（今回）** → Step3 スクショ読み取り（横山さん・完了）→ Step4 既存データとの照合・更新・変更履歴（Step2・3 の合流地点）→ Step5 カレンダー → Step6 通知 → Step7 P1 の仕上げ（ルール整備・アプグレの表示条件・デモデータ）→ Step8 グッズ交換など。

## 1. 範囲

**作るもの**

1. **保存（新規作成）**: 確認・修正画面（`/live-form`）の「保存」で、ライブ・公演・受付を Firestore に新しく作る。手入力（空のフォーム）とスクショ読み取り（Step3）の両方が、この保存処理を使う。
2. **一覧**: フォロー中の推しのライブ一覧と、ライブの詳細（公演・受付）。ホームに「次の締切」を出す。
3. **個人の申込状況**: 受付ごとに「未申込／申込済／当選／落選／入金済」を記録・変更する（`users/{uid}/applications/{receptionId}`）。
4. **導線**: ホームから「ライブを登録（手入力）」「スクショから登録」「ライブ一覧」へ行ける。
5. **セキュリティルール**: 上の読み書きに必要なルールと、そのテスト。

**作らないもの（ほかの Step の範囲）**

- 既存データとの照合・重複の防止・更新・変更履歴（Step4）。Step2 の保存は常に**新規作成**。
- ライブ・公演・受付の編集と削除（Step4 以降）
- Google カレンダー連携（Step5）、リマインド通知（Step6）
- アプグレなど `winnersOnly` の受付を当選者だけに出す条件（Step7）。Step2 では全員に表示し、「当選者のみ」のラベルを付ける。
- ルールの最終的な整備とデモ用データ（Step7）

## 2. 前提（決定済み・既存のコード）

| 項目 | 内容 | 根拠 |
|---|---|---|
| 保存先 | `lives`・`performances`・`receptions`（トップレベル）、申込状況は `users/{uid}/applications/{receptionId}` | DB 設計案 2・3章 |
| 子への複製 | 公演・受付は `liveId` と、ライブと同じ `groupIds`・`oshiIds` を持つ | DB 設計案 1・3.4・3.5章 |
| 作成者の項目 | 3つとも `createdBy`・`createdAt`・`updatedBy`・`updatedAt` が必須 | DB 設計案 3.3〜3.5 |
| 申込状況の値 | ドキュメントなし＝未申込、`applied`・`won`・`lost`・`paid` | DB 設計案 3.8・4章 |
| 出演者 | フォームで推し（承認済み）から選ぶ。`LiveDraft.groupIds`・`oshiIds` で ID が取れる | 横山さんの Step3-5（`performer_picker_sheet.dart`） |
| モデル | `Live`・`Performance`・`Reception` の `liveId`・`groupIds`・`oshiIds` は「保存時に repository が付ける」設計 | `lib/models/*.dart` のコメント |
| 表示する範囲 | フォロー中のグループ、フォロー中の推しの所属グループ、フォロー中の推しのライブ | DB 設計案 5章 |
| 日時 | Firestore の timestamp で保存し、表示は日本時間。表示の書式は `formatDateTime`（`lib/features/live_form/date_time_field.dart`）を使う | 仕様書・既存コード |

## 3. 実装前に合意すること（2026-11-05 すべて合意済み）

3.1〜3.7 は、リーダーが示した推奨案のとおりに、ユーザー（とし）が 2026-11-05 に合意した。経緯は `notes/判断ログ_A.md` の「Step2」にある。

### 3.1 保存の方法（合意済み）

- **推奨**: ライブ1件・公演 n 件・受付 m 件を、**1つの WriteBatch でまとめて作成**する。途中で失敗してもライブだけ残る、ということが起きない。
  - ドキュメント ID は自動 ID。ライブの ID を先に発行し、公演・受付の `liveId` に入れる。
  - `createdAt`・`updatedAt` はサーバー時刻（`FieldValue.serverTimestamp()`）。`createdBy`・`updatedBy` はログイン中の uid。
- 保存中はボタンを押せなくし（二重保存の防止）、成功したらライブ詳細へ移る。失敗したら日本語の SnackBar を出し、入力は残す。
- 公演・受付の件数: **公演は1件以上必須、受付は0件でも可**。公演が無いライブは一覧で日付順に並べられないため。
  - 横山さんの `LiveDraft.validate()` は変えない。ui が `_save` の中で、公演が0件なら日本語で知らせて止める（後で `validate()` に移すかは横山さんと相談する）。
- 長さ・個数の上限（ルールと同じ値）: data が `live_draft_to_models.dart` に保存前の検査を置き、日本語のエラー文で返す。`_save` は `validate()` に加えてこの検査を呼ぶ。
  - ライブ名・会場は1〜100文字、都道府県は10文字まで、受付の表示名・席種は1〜50文字
  - 料金は0〜1,000,000円の整数、席種は受付ごとに10個まで（2026-11-05 に20個から変更。ルールの式の上限1000個のため。判断ログ参照）
  - 出演者は `groupIds`・`oshiIds` それぞれ20件まで（ルールでは件数だけを検査）
  - 公演は1〜50件、受付は0〜30件
  - 公式 URL は `https://` で始まり200文字まで
  - 文字数は `String.length`（UTF-16 単位。ルールの `size()` と同じ）
- 比べた案: クライアントから1件ずつ順に書く（途中で失敗すると中途半端なデータが残る）／Cloud Functions で書く（Blaze プランが必要で、Step2 には重い）。

### 3.2 一覧の取り方（合意済み: 案1）

| 案 | 内容 | 長所 | 短所 |
|---|---|---|---|
| **1（推奨）** | `groupIds`・`oshiIds` それぞれに `array-contains-any`（1回30件まで。超えたら分割）で問い合わせ、端末で ID ごとに重複を除き、並べ替える | フォロー中の分だけ読む。複合インデックスが要らない（並べ替え・期間の絞り込みは端末側） | クエリの数が増える。結果をまとめる処理が要る |
| 2 | 全件を購読して端末で絞り込む | 実装が簡単 | ライブが増えると読み取り回数と通信量が増える |
| 3 | ユーザーごとの「タイムライン」を Cloud Functions で作る | 読み取りが最小 | Blaze プランが必要。ハッカソンでは過剰 |

- 対象の ID: フォロー中のグループ ＋ フォロー中の推しの所属グループ（`OshiSummary.groupIds`）→ `groupIds` の検索に使う。フォロー中の推し（個人）→ `oshiIds` の検索に使う。
- **フォローが0件なら問い合わせない**（`array-contains-any` に空の配列を渡すとエラーになる）。

### 3.3 「次の締切」の決め方（このアプリの中心）（合意済み）

受付ごとに、**自分の申込状況から「次にやること」と期限を決める**。当落を押すと次の締切に切り替わる。

| 申込状況 | 次の締切 | 表示例 |
|---|---|---|
| 未申込 | 申込期限（`applyEndAt`） | 「申込期限まであと2日」 |
| 申込済 | 当落発表（`resultAt`。無ければなし） | 「当落発表 11/20(金) 18:00」 |
| 当選 | 入金期限（`paymentDeadline`。未発表ならなし） | 「入金期限まであと5時間」 |
| 落選・入金済 | なし | 一覧に出さない |

- 期限を過ぎたものは「次の締切」に出さない（ライブ詳細では「期限切れ」と表示）。
- この計算は Firestore に依存しない純粋関数にし、テストを厚くする。
- ホームには近い順に5件まで出し、「すべて見る」でライブ一覧へ。
- 未申込で、申込開始（`applyStartAt`）がまだ先の受付は、締切に「受付開始 11/10(火) 10:00〜」を添える（すぐ申し込めるように見えないように）。
- `winnersOnly` の受付も Step2 では「次の締切」に含め、「当選者のみ」のラベルを付ける（当選者だけに絞るのは Step7）。

### 3.4 申込状況の変え方（合意済み）

- 受付カードに、5つの状態を選べる部品（例: `SegmentedButton` かドロップダウン）を置く。
- **どの状態からどの状態へも変えられる案**（押し間違いを直せるように。当落の順番は強制しない）。
- 「未申込」に戻すときは、ドキュメントを削除する（DB 設計案どおり、未申込＝ドキュメントなし）。
- 保存する項目: `liveId`（絞り込み用）、`status`、`updatedAt`（サーバー時刻）。

### 3.5 画面とルート（合意済み）

| パス | 画面 | 内容 |
|---|---|---|
| `/` | ホーム（既存） | 「次の締切」（3.3）、「ライブを登録」（→ `/live-form`）、「スクショから登録」（→ `/scan`）、「ライブ一覧」（→ `/lives`）を追加。既存の「推しを探す」とフォロー中一覧は残す |
| `/lives` | ライブ一覧 | フォロー中の推しのライブ。次の公演日が近い順、公演が終わったライブは下に「終了」として |
| `/lives/:liveId` | ライブ詳細 | ライブ名・出演者・公式 URL、公演の一覧、受付の一覧（期限・料金・「当選者のみ」ラベル・自分の申込状況） |

- 新しいルートは Step1 と同じく `/` の下（子ルート）に置き、戻るボタンでホームへ戻れるようにする。
- `/live-form`・`/scan` は横山さんのルートなので変えない。
- 保存後は `/lives/:liveId` へ移る。

### 3.6 セキュリティルールの方針（合意済み）

| 対象 | 方針 |
|---|---|
| `lives`・`performances`・`receptions` の読み取り | ログイン済みなら読める（共通データ） |
| 同・作成 | ログイン済み、`createdBy == updatedBy == request.auth.uid`、`createdAt == updatedAt == request.time`、許可した項目だけ（`keys().hasOnly`）、必須項目と型・長さ・個数の上限。`groupIds`・`oshiIds` は少なくとも一方が1件以上。公演・受付の `type` などは値の一覧で検査 |
| 同・更新・削除 | **Step2 では不可**。Step4（照合・更新・変更履歴）で開ける |
| 公演・受付とライブの整合 | `getAfter()` でライブが同じバッチで作られていること、`groupIds`・`oshiIds` がライブと同じことを確かめる。**条件付き**: ルールでほかのドキュメントを読める回数には上限がある（バッチで20回）。qa が上限の件数（公演50件・受付30件）でエミュレータのテストを行い、通ったときだけ採用する。通らなければ外し、判断ログに残す |
| `users/{uid}/applications/{receptionId}` | 本人のみ。`status` は `applied`・`won`・`lost`・`paid` のどれか、`liveId` は文字列、`updatedAt == request.time`、許可した項目だけ |

- **注意（ルールは OR で効く）**: 今の `firestore.rules` には `users/{userId}/{subcollection}/{document=**}` を本人なら自由に読み書きできるルールがある。`applications` 用に厳しいルールを足しても、この広いルールが許可してしまう。**広いルールから `applications` を除外する**（例: `subcollection != 'applications'`）こと。
- `firestore.rules` は横山さんと共有。Step2 で触るのは新しい `match` ブロックと、上の除外だけにする。デプロイは人間が行う。

### 3.7 横山さんのモデルの読み込み（合意済み・リーダーの追加提案）

- `Live`・`Performance`・`Reception` の `fromFirestore` は `as String` や `!` を使っているため、壊れたドキュメントが1件あると一覧全体が落ちる。
- 横山さんのファイルは変えない。data のリポジトリで1件ずつ例外を受け止め、読めないドキュメントは飛ばす（`debugPrint` などで記録する）。
- この件は qa が `notes/step2_レビュー記録.md` に書き、リーダーがユーザー経由で横山さんに伝える。

## 4. 担当とファイル

同じファイルを2人が同時に編集すると上書きが起きる。**担当外のファイルは編集せず、担当者に SendMessage で依頼する。**

| 担当 | 名前 | 編集してよいファイル |
|---|---|---|
| リーダー | （メインセッション） | `pubspec.yaml`、`pubspec.lock`、この計画書、`notes/判断ログ_A.md` |
| データ層 | `data` | `lib/models/application.dart`（新規）、`lib/repositories/live_repository.dart`（新規）、`lib/repositories/application_repository.dart`（新規）、`lib/providers/live_providers.dart`（新規）、`lib/utils/deadline.dart`（新規）、`lib/features/live_form/live_draft_to_models.dart`（新規）、`firestore.rules`（3.6 の範囲のみ）、`firestore.indexes.json` |
| 画面 | `ui` | `lib/features/live/**`（新規）、`lib/app.dart`（ルートの追加のみ）、`lib/features/home/home_page.dart`（3.5 の追加のみ）、`lib/features/live_form/live_form_page.dart`（**`_save` の中身と、保存中の表示だけ**） |
| テスト・レビュー | `qa` | `test/**`、`test_rules/**`、`notes/step2_レビュー記録.md` |

**横山さんのファイルの扱い**

- `lib/features/live_form/live_form_page.dart` は ui が `_save` だけを変える。ほかの部分（出演者の選択など）は変えない。
- `lib/features/live_form/live_draft.dart`、`performer_picker_sheet.dart`、`date_time_field.dart`、`lib/features/scan/**`、`lib/services/**`、`lib/models/live.dart`・`performance.dart`・`reception.dart` は**読むだけ**。変える必要が出たら、リーダーがユーザーに相談する（ユーザーが横山さんと調整する）。
- 横山さんのコードで見つけた問題は、qa が `notes/step2_レビュー記録.md` に書き、リーダーがまとめてユーザーに伝える（勝手に直さない）。
- Step1 のファイル（`lib/models/oshi.dart`、`lib/providers/oshi_providers.dart` など）は読むだけ。`allOshisProvider`・`followStateProvider`・`currentUidProvider` はそのまま使ってよい。

## 5. 契約（インターフェース）

データ層 `data` が最初のタスク（D1）で確定させ、`ui` と `qa` に SendMessage で全文を送る。変更するときも必ず知らせる。以下は叩き台。

```dart
// lib/models/application.dart
enum ApplicationStatus { applied, won, lost, paid } // 未申込は null（ドキュメントなし）

class Application {
  final String receptionId; // ドキュメント ID と同じ
  final String liveId;
  final ApplicationStatus status;
  final DateTime? updatedAt;
  // fromFirestore は欠けた値・不明な status でも落ちない（不明なら null を返すなど）
}

// lib/features/live_form/live_draft_to_models.dart
/// 入力済みの LiveDraft を保存用のモデルに変える（validate() が空のときだけ呼ぶ）
extension LiveDraftToModels on LiveDraft {
  ({Live live, List<Performance> performances, List<Reception> receptions}) toModels();
}

// lib/repositories/live_repository.dart
/// 一覧の対象（フォロー中のグループ＋所属グループ、フォロー中の推し）
class FollowTargets { final Set<String> groupIds; final Set<String> oshiIds; }

abstract class LiveRepository {
  /// ライブ・公演・受付を1つのバッチで新規作成し、ライブの ID を返す（照合・更新は Step4）
  Future<String> create({
    required Live live,
    required List<Performance> performances,
    required List<Reception> receptions,
    required String uid,
  });
  Stream<List<Live>> watchLives(FollowTargets targets);
  Stream<List<Performance>> watchPerformances(FollowTargets targets);
  Stream<List<Reception>> watchReceptions(FollowTargets targets);
  Stream<Live?> watchLive(String liveId);
  Stream<List<Performance>> watchPerformancesOf(String liveId);
  Stream<List<Reception>> watchReceptionsOf(String liveId);
}

// lib/repositories/application_repository.dart
abstract class ApplicationRepository {
  /// receptionId → 申込状況。ドキュメントが無い受付は含まない（＝未申込）
  Stream<Map<String, Application>> watchAll(String uid);
  /// null なら未申込に戻す（ドキュメントを削除）
  Future<void> setStatus(String uid, Reception reception, ApplicationStatus? status);
}

// lib/utils/deadline.dart（純粋関数）
enum DeadlineKind { apply, result, payment }
class NextDeadline { final DeadlineKind kind; final DateTime at; final Reception reception; }
NextDeadline? nextDeadlineOf(Reception reception, ApplicationStatus? status, DateTime now);
List<NextDeadline> upcomingDeadlines(
  List<Reception> receptions, Map<String, Application> applications, DateTime now);
```

- 時刻は引数 `now` で受け取り、テストで固定できるようにする（`DateTime.now()` を中で呼ばない）。
- プロバイダは `lib/providers/live_providers.dart` に置き、Step1 と同じく `retry: firestoreRetry` を付ける。テストでは `overrideWithValue` でリポジトリを差し替える。

### 5.1 テスト用の Key（2026-11-05 ui と qa で合意）

| 画面 | Key |
|---|---|
| ホーム | `home_register_live_button`、`home_scan_button`、`home_live_list_button`、`home_deadlines_loading`、`home_deadlines_error`、`home_deadlines_retry_button`、`home_deadlines_no_follow`、`home_deadlines_search_button`、`home_deadlines_empty`、`home_deadlines_list`、`home_deadline_tile_<receptionId>`、`home_deadlines_see_all_button` |
| ライブ一覧 | `live_list_loading`、`live_list_empty`、`live_list_register_button`、`live_list_error`、`live_list_retry_button`、`live_list`、`live_list_tile_<liveId>`、`live_list_finished_header` |
| ライブ詳細 | `live_detail_loading`、`live_detail_error`、`live_detail_retry_button`、`live_detail_not_found`、`live_detail`、`live_detail_title`、`live_detail_performers`、`live_detail_official_url`、`live_detail_performances_empty`、`live_detail_receptions_empty`、`live_detail_performance_<performanceId>`、`live_detail_reception_<receptionId>`、`live_detail_winners_only_<receptionId>`、`live_detail_next_action_<receptionId>`、`live_detail_status_<receptionId>`、`live_detail_status_busy_<receptionId>` |
| 確認・修正画面 | `live_form_save_button` |

## 6. 画面の要件

- 読み込み中・0件・エラー・結果ありの4状態をそれぞれ表示する。
- 保存・申込状況の変更ボタンは、処理中は押せなくする（二重送信の防止）。
- 失敗したら日本語の SnackBar で知らせる。`await` の後は `context.mounted` を確認する。
- スマホの幅（360px）でも崩れない。
- テストから探せるように、主要なウィジェットに `Key` を付ける（キー名は ui と qa で決めて、5章に書き足す）。
- 期限が24時間以内のものは目立たせる（色・アイコン）。色だけに頼らず文字でも示す。

## 7. タスク一覧

リーダーが共有タスクリストに、担当と依存関係を付けて登録する。

| ID | 担当 | 内容 | 依存 |
|---|---|---|---|
| T0 | qa | 品質ゲートが通る状態の確認。`flutter analyze`・`flutter test`・ルールのテストを実行。`test/` の問題は直し、それ以外（横山さんのコードなど）はリーダーに報告 | なし |
| D1 | data | `Application` モデルと契約（5章）を作り、ui・qa に通知する | T0 |
| D2 | data | `deadline.dart`（3.3）と `live_draft_to_models.dart` | D1 |
| D3 | data | Firestore 版 `LiveRepository`（バッチでの作成、一覧・詳細の購読、30件ごとの分割、重複除去） | D1 |
| D4 | data | Firestore 版 `ApplicationRepository` | D1 |
| D5 | data | `firestore.rules`（3.6） | D3, D4 |
| D6 | data | `live_providers.dart`（一覧の対象、ライブ一覧、ライブ詳細、申込状況、次の締切） | D2, D3, D4 |
| U1 | ui | ルートの追加（`/lives`、`/lives/:liveId`）とホームの導線 | D1 |
| U2 | ui | ライブ一覧画面（仮データで先に作ってよい） | D1 |
| U3 | ui | ライブ詳細画面と申込状況の切り替え | D1 |
| U4 | ui | ホームの「次の締切」 | D2 |
| U5 | ui | `live_form_page.dart` の `_save` を保存処理につなぐ（保存中の表示、成功で詳細へ、失敗で SnackBar） | D2, D3 |
| U6 | ui | 本物のプロバイダへのつなぎ込みと仕上げ（仮データを消す） | D6, U2, U3, U4, U5 |
| Q1 | qa | `deadline.dart`・`live_draft_to_models.dart` のテスト（3.3 の表の全パターン、期限切れ、日付の境界、空の項目） | D2 |
| Q2 | qa | リポジトリのテスト（`fake_cloud_firestore`。バッチで子に `liveId`・`groupIds`・`oshiIds` が入る、30件を超える分割、重複除去、フォロー0件、申込状況の作成・変更・削除） | D3, D4 |
| Q3 | qa | ルールのテスト（`test_rules/lives.test.js` など。許可されるべき操作と拒否されるべき操作の両方） | D5 |
| Q4 | qa | 画面のウィジェットテスト（4状態、申込状況の切り替えで次の締切が変わる、二重送信の防止、保存の成功と失敗） | U6 |
| R1 | qa | データ層のまとめレビュー（`firebase-security-rules-auditor` スキルでルールを監査） | D1〜D6 |
| R2 | qa | 画面のまとめレビュー | U6 |
| L1 | リーダー | 結合確認、ユーザーへの動作確認手順の提示、判断ログの更新、コミット案の提示 | すべて |

> **進み具合（2026-11-05）:** T0・D1〜D6・U1〜U6・Q1〜Q4・R1・R2 は完了。
> - L1（リーダーが実行）: `flutter analyze` 0件、`flutter test` 446件すべて成功（公式 URL のリンク化の後にもう一度実行）、ルールのテスト 178件すべて成功（Step1 の分を含む）。
> - 横山さんのファイルで変えたのは `live_form_page.dart`（`_save`・保存ボタン・`_saving`・import）だけ。Step1 のファイルには差分なし。`firestore.rules` の既存部分で変えたのは、広い subcollection のルールから `applications` を除外した1行だけ。
> - ルールはまだデプロイしていない。
> - 動作確認（10章の手順1〜9と公式 URL）: 2026-11-05 ユーザーが実施し、完了。
> - 仕上げ（ユーザー決定）: `url_launcher` を追加して公式 URL をリンクにする。料金の追加ボタンは変えない。ライブの大量作成への対策は Step4 に持ち越す。

Q3 の注意: ルールのテストは既存の `test_rules/helpers.js` を使う（エミュレータのポート 8085、プロジェクト ID `demo-oshiashi`）。Step1 のテスト（`oshis.test.js`・`users*.test.js`）が引き続き通ることも確かめる。

## 8. バグを防ぐための進め方

1. **担当外のファイルは編集しない。** 直してほしい箇所は担当者に SendMessage で伝える。
2. **契約を先に決める。** D1 が終わるまで、ui と qa は契約に依存する部分を書かない（画面の骨組みや、テストの準備は進めてよい）。
3. **各タスクの最初に、方針を3〜5行でリーダーに送る。** 特に最初のタスクは、リーダーの返事を待ってから書き始める。
4. **作業ツリーを壊れたまま放置しない。** 書きかけのコードで `flutter analyze` が通らない状態を長く残さない（ほかのメンバーの品質ゲートも止まる）。
5. **品質ゲート:** タスクを完了にするたびに、`.claude/hooks/quality-gate.sh` が `flutter analyze`・`flutter test`・ルールのテストを実行する。失敗すると完了が差し戻される。
6. **実装タスクを終えたら、qa にレビューを依頼する。** qa はレビュー依頼を最優先で処理し、指摘は担当者に SendMessage で返す。重い指摘は「バグ修正: …」というタスクを作って担当者に割り当てる。
7. **バグの報告と回帰テスト:** qa は失敗するテストを `test/` に置いたままにしない（全員の品質ゲートが止まる）。再現手順を担当者に送り、修正後に回帰テストを追加する。
8. **判断を記録する。** 比べた案・選んだ理由・捨てた案は、リーダーが `notes/判断ログ_A.md` に「Step2」として追記する。qa はレビューで見つけた問題を `notes/step2_レビュー記録.md` に残す。

## 9. レビューの観点

- バッチ: ライブ・公演・受付が1つのバッチで作られるか。子に `liveId`・`groupIds`・`oshiIds` が正しく入るか。`createdBy`・`updatedBy`・`createdAt`・`updatedAt` がそろっているか
- 一覧: フォロー0件で問い合わせていないか。30件を超えるときに分割しているか。グループと推しの両方に当たるライブが重複していないか。所属グループのライブも出るか
- Firestore から読んだ値が欠けている・型が違うときに落ちないか（既存のモデルの `fromFirestore` は `as String` や `!` を使っているので、壊れたドキュメントで落ちうる。見つけたら記録してリーダーへ）
- 時刻: 日本時間で表示されるか。期限ちょうど・日付の変わり目・期限切れの扱い。`DateTime.now()` を直接使って、テストが日によって変わっていないか
- 申込状況: 未申込に戻すとドキュメントが消えるか。状態を変えると「次の締切」が切り替わるか。他人の申込状況を読み書きできないか
- 二重送信: 保存ボタンの連打で同じライブが2件作られないか
- `await` の後の `context.mounted`、Stream の購読の解除
- ルール: 広い `users/.../{subcollection}` のルールが `applications` の検査を素通りさせていないか。他人の uid での作成、`createdAt` の偽装、更新・削除、許可していない項目、長すぎる文字列、空の `groupIds`・`oshiIds`
- 横山さんのフォーム（`/live-form`）を、スクショ経由で開いたときも保存できるか

## 10. ユーザーが行う動作確認

ルールを変えた後は、実際の Firestore で試す前に、人間が `firebase deploy --only firestore:rules` でデプロイする（`firestore.rules` は横山さんと共有なので、デプロイ前に一声かける）。

1. 推しを1つフォローしておく
2. ホームの「ライブを登録」から、出演者・ライブ名・公演1件・受付2件（FC先行と一般）を入力して保存 → ライブ詳細に移る
3. ホームの「次の締切」に、受付の申込期限が近い順に出る
4. 受付の申込状況を「申込済」→「当選」に変える → 次の締切が「当落発表」→「入金期限」に切り替わる。「入金済」にすると消える
5. 「未申込」に戻すと、申込期限が再び出る
6. 再読み込みしても申込状況が残る
7. 推しのフォローを外すと、そのライブが一覧から消える
8. 「スクショから登録」で読み取った結果も、同じように保存できる
9. 別の Google アカウントでログインし、同じ推しをフォローすると、ライブは見えるが申込状況は見えない

## 11. リーダー（メインセッション）の進め方

1. この文書と `CLAUDE.md` を読む。リーダーは自分でコードを書かず、調整・タスク管理・ユーザーへの確認に専念する。
2. `git status -sb` で `feature/step2` にいて最新であることを確かめる（0章）。
3. `flutter analyze`・`flutter test` を実行し、品質ゲートが通る状態かを確認する。通らなければ、原因（どのファイルか、誰のコードか）をユーザーに報告して判断を仰ぐ。
4. 「3. 実装前に合意すること」を、項目ごとに推奨案と理由を付けてユーザーに示す。まとめて質問し、回答を判断ログに書き、3章を更新する。**合意するまでチームメイトは作らない。**
5. 新しい依存パッケージが必要になったら、ユーザーの了承を得てからリーダーが追加する。
6. チームメイトを3人作る。各チームメイトはリーダーの会話履歴を見られないので、作成時の指示に必要なことを書く。
   - `dev-data` エージェントタイプで、名前 `data` のチームメイト。指示: 「markdown/feature_step2_live_plan.md を読み、担当 data として D1 から始めて。D1 の方針を先に私（リーダー）に送ること」
   - `dev-ui` エージェントタイプで、名前 `ui` のチームメイト。指示: 「markdown/feature_step2_live_plan.md を読み、担当 ui として、D1 の契約が届くまでは U1・U2 の骨組みから始めて。live_form_page.dart は _save 以外を変えないこと」
   - `dev-qa` エージェントタイプで、名前 `qa` のチームメイト。指示: 「markdown/feature_step2_live_plan.md を読み、担当 qa として T0 から始めて。以降はレビュー依頼を最優先に」
7. 7章のタスクを共有タスクリストに登録する（担当・依存関係つき）。
8. 進行中は、担当外ファイルの編集・同じファイルの同時編集・契約の食い違い・**横山さんのファイルへの想定外の変更**を見張る。チームメイトからの質問のうちユーザーが決めるべきものは、まとめてユーザーに聞く。
9. すべて完了したら L1 を行う。ユーザーに 10章の動作確認手順と、コミット案（メッセージと含めるファイル、横山さんのファイルを変えた箇所）を示し、了承を得てからコミットする。`git push`・Pull Request・ルールのデプロイはユーザーが行う。
10. 最後にチームメイトを終了させ、チームを片付ける。
