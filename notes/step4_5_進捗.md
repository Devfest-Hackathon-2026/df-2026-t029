# Step4.5 進捗（自分のライブ一覧）

状態: 完了

> リーダーが、タスクが1つ終わるたびに更新する（計画書 `markdown/feature_step4_5_mylive_plan.md` の 13章）。
> 使用量の上限で止まって再開したときは、まずこのファイルを読む。
> すべて終わったら、上の行を `状態: 完了` にする（自動再開の見張り役がこれを見て止まる）。

最終更新: 2026-11-06 L1 完了。全タスク完了（analyze 0件、test 747件、ルール 245件）

開始時: `flutter analyze` 0件、`flutter test` 709件成功（ルールのテストは T0 で qa が確認）。合意は判断ログ_A.md に記録済み。
共有タスクリストの道具が無いため、タスクの状況はこのファイルで管理する。

## 前提（ユーザーが決めたこと・2026-11-06）

- 4章はすべて推奨案で確定。リーダーはユーザーに確認せずに進める。
- グッズ交換の2ファイル（`trade_post_form_page.dart`・`board_filter_sheet.dart`）の、手渡しの公演の部分を変えてよい（4.7）。
- チームメイトは3人とも Sonnet。
- ユーザーは不在。コミット・push・ルールのデプロイ・依存パッケージの追加はしない。

## タスクの状況

| ID | 担当 | 状態 | メモ（触ったファイル・次にやること） |
|---|---|---|---|
| L0 | リーダー | 完了 | app_config.md（1章・4.2・4.4）、Database_config.md（2章・3.8.1・5章・6章） |
| T0 | qa | 完了 | test/features/live_test_helpers.dart の偽リポジトリに新メソッド3つ。analyze 0件、test 709件、ルール 230件成功 |
| D1 | data | 完了 | my_live.dart・my_live_repository.dart・live_repository.dart・live_search.dart・live_providers.dart。契約を ui・qa に送付済み |
| D2 | data | 完了 | Firestore 版 MyLiveRepository |
| D3 | data | 完了 | watch*ByIds/OfLives、create・applyMerge で myLives を自動追加 |
| D4 | data | 完了 | live_search.dart |
| D5 | data | 完了 | firestore.rules（myLives 追加・広いルールから除外）。既存ルールテスト230件通過。デプロイは人間 |
| D6 | data | 完了 | live_providers.dart（my* 切り替え・liveSearchProvider）。liveList 系の既存テスト約5件が仕様変更で落ちる → qa が書き直し |
| D7 | data | 完了 | live_providers.dart から followTargetsProvider・livesProvider・performancesProvider・receptionsProvider・_watchTargets を削除（grep で参照なし） |
| U1 | ui | 完了 | home_page.dart（FAB: Key home_add_live_fab・「ライブを追加する」→ /lives/add） |
| U2 | ui | 完了（仮データ） | live_add_page.dart・live_add_temp_data.dart（新規）、app.dart に /lives/add（:liveId の前）。本物へのつなぎは U5 |
| U3 | ui | 完了 | live_detail_page.dart（追加／外す＋確認、一覧外は申込状況の代わりにヒント）。live_pages_test は qa が書き直し |
| U4 | ui | 完了 | live_list_page.dart・upcoming_deadlines_section.dart（0件の文言・ボタン） |
| U6 | ui | 完了 | board_filter_sheet.dart（2行）・trade_post_form_page.dart（_PerformanceChips のみ。リーダーが diff で範囲を確認） |
| U5 | ui | 完了 | live_add_page を本物に接続、仮データ削除 |
| Q1 | qa | 完了 | test/utils/live_search_test.dart 5件 |
| Q2 | qa | 完了 | test/repositories/my_live_repository_test.dart 13件。D1〜D4 のレビューは問題なし |
| Q3 | qa | 完了 | test_rules/mylives.test.js 12件。ルール全体 242件成功 |
| Q4 | qa | 完了 | 既存テストの書き直し済み。live_add_page_test 10件＋skip1、ライブ詳細4件。残り: skip を外す、消したテストの my* 版の確認 |
| Q5 | qa | 完了 | グッズ交換のテスト更新済み。全体の最終確認が残り |
| R1 | qa | 完了 | 中の指摘1件（もう一度読み込むが効かない）→ ui が修正。ほかは問題なし |
| R2 | qa | 完了 | 指摘1: ライブを追加する画面の「もう一度読み込む」が効かない → ui が修正（元のプロバイダも invalidate）。live_add_page_test の skip を外して確認待ち |
| L1 | リーダー | 完了 | 最終確認・判断ログ・下の「帰宅後に確認すること」 |

## 帰宅後に確認すること（ユーザーへの質問・迷って控えめに決めた点・コミット案）

### 1. 結果
- `flutter analyze` 0件、`flutter test` 747件成功（開始時 709件）、ルールのテスト 245件成功（開始時 230件）。リーダーが最後に実行して確認。
- コミット・push・ルールのデプロイはしていない。

### 2. 不在中に決めたこと（控えめな方を選んだ点）
- 共有タスクリストの道具が無かったため、タスクの状況はこのファイルだけで管理した。
- 掲示板の絞り込み（`board_filter_sheet.dart`）は、公演の取得元を差し替えただけ。候補0件の案内は足していない（4.7 の「候補0件の表示」は投稿の作成画面の項目と読んだ）。必要なら足す。
- 仕様変更で不要になったテスト（フォロー中の推しのライブを前提にしたもの）は削除し、自分のライブ一覧の版を足した（`notes/step4_5_レビュー記録.md` に一覧）。

### 3. 動作確認の手順
- 先に `firebase deploy --only firestore:rules`（`firestore.rules` は横山さんと共有なので、デプロイ前に一声かける）。
- 手順は計画書 11章の 1〜14 のとおり。

### 4. Key の変更（テスト・qa 向け）
- ホームの右下: `home_register_live_fab` → `home_add_live_fab`（「ライブを追加する」→ `/lives/add`）
- ホームの次の締切（一覧が空）: `home_deadlines_no_follow` → `home_deadlines_no_live`、`home_deadlines_search_button` → `home_deadlines_add_button`
- `live_list_register_fab` は名前を残した（中身は「ライブを追加する」→ `/lives/add`）

### 5. 横山さんに伝えること
- `lib/features/trade/trade_post_form_page.dart`: `_PerformanceChips` の中だけ。公演の取得元を `myPerformancesProvider`・`myLivesProvider` に差し替え、候補0件の案内＋「ライブを追加する」ボタン、「ライブ一覧に無い公演が n 件選ばれています」＋「外す」を追加。
- `lib/features/trade/board_filter_sheet.dart`: `_performanceDropdown` の2行（取得元の差し替え）だけ。
- `lib/app.dart`: import 1行と `/lives/add` の子ルート（`:liveId` より前）。
- `firestore.rules`: `users/{uid}/myLives/{liveId}` のルールを追加し、広い `users/{uid}/{subcollection}` から `myLives` を除外。
- 仕様書 `markdown/app_config.md`（1章・4.2・4.4）と DB 設計案 `markdown/Database_config.md`（2章・3.8.1・5章・6章）を Step4.5 の内容に更新。

### 6. コミット案（ユーザーの了承後に実行）
- 含めるファイル: `firestore.rules`、`lib/`（app.dart、features/home/home_page.dart、features/live/*.dart、features/live_add/、features/trade/board_filter_sheet.dart・trade_post_form_page.dart、models/my_live.dart、providers/live_providers.dart、repositories/live_repository.dart・my_live_repository.dart、utils/live_search.dart）、`test/`（変更・新規すべて）、`test_rules/mylives.test.js`、`markdown/app_config.md`・`Database_config.md`・`feature_step4_5_mylive_plan.md`、`notes/判断ログ_A.md`・`step4_5_進捗.md`・`step4_5_レビュー記録.md`
- 含めるか要確認（作業前からあった変更）: `.gitignore`、`CLAUDE.md`、`.claude/scripts/`
- メッセージ案:
  ```
  Step4.5: 自分のライブ一覧（選んだライブだけを一覧・次の締切に出す）を追加

  - users/{uid}/myLives を追加し、ライブ一覧・次の締切・グッズ交換の手渡しの公演を自分のライブ一覧に切り替え
  - 「ライブを追加する」画面（/lives/add）で推し・ライブ名から探して追加
  - 登録・既存への反映で自動追加、ライブ詳細から追加・外す
  - セキュリティルールとテストを追加、仕様書・DB 設計案を更新

  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  ```

## 再開のメモ（止まったときの状況・再開した日時）

- 2026-11-06 05:4x ユーザーが auto mode に切り替えるため、チームメイト3人を停止。停止時点: D1・U2 は方針の了承直後（コードはほぼ未着手の可能性）、T0 は実行中。再開時は data・ui・qa を作り直し、`git status --short` で書きかけのファイルを確かめてから続ける。
- 2026-11-06 auto mode で再開。D1 は書きかけ（my_live.dart・my_live_repository.dart・live_search.dart・live_repository.dart・live_providers.dart）、U2 は live_add_temp_data.dart のみ。analyze エラー1件（test/features/live_test_helpers.dart の偽リポジトリに新メソッドが無い）→ qa に修正を依頼。data・ui・qa を Sonnet で作り直した。
- 2026-11-06 05:43 全員が使用量の上限で停止（解除 7:20 UTC）。解除後に data（D5）・ui（U1）・qa（Q1・Q2）へ再開を指示。停止直前の data→qa（契約・レビュー依頼）と ui→qa（U1 のテスト更新依頼）は再送させた。analyze 0件。
