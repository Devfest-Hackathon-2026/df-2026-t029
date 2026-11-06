# Step6・7 進捗（P1 の仕上げ）

状態: 完了

> リーダーが、タスクが1つ終わるたびに更新する（計画書 `markdown/feature_step6_7_plan.md` の 14章）。
> 使用量の上限で止まって再開したときは、まずこのファイルを読む。
> すべて終わったら、上の行を `状態: 完了` にする。
> Step6（リマインド通知）は今回は作らない（Blaze の後）。

最終更新: 2026-11-06 全タスク完了・コミット

## 合意（4章）

- 4.1 推奨案（見る場面で隠す・「n 件あります」・直す場面では隠さない）。カレンダーの追加シートは横山さんの了承あり → U2 を実施
- 4.2・4.4・4.5・4.6 推奨案
- 4.3 案1（App Check・監視のみ）＋ reCAPTCHA バッジを左下へ（U4 を新設。下いっぱいのボタンと重なればユーザーに聞く）
- リーダーが `firebase_app_check: ^0.5.1` を pubspec に追加済み（lock はもとから推移依存で入っていた）
- 開始時: analyze 0件、flutter test 810件、ルールのテスト 245件

## タスクの状況

| ID | 担当 | 状態 | メモ（触ったファイル・次にやること） |
|---|---|---|---|
| T0 | リーダー | 完了 | リーダーが確認（analyze 0・test 810・rules 245） |
| D1 | data | 完了 | lib/utils/winners_only.dart（winnerLiveIds・isReceptionVisible・splitVisibleReceptions） |
| D2 | data | 完了 | deadline.dart・live_providers.dart・winners_only.dart。qa レビュー待ち |
| U1 | ui | 完了 | live_detail_page.dart。テスト4件の更新を qa に依頼済み |
| U2 | ui | 完了 | calendar_add_sheet.dart（ref.watch）＋ live_form_page.dart:231（liveId を渡す） |
| Q1 | qa | 完了 | 4件を書き直し（期待は弱めていない）＋新規テスト。flutter test 834件・rules 316件成功 |
| Q2 | qa | 完了 | 重大0件。横山さん中1・軽微6、A 中2（既知の限界として判断ログへ） |
| D3 | data | 完了 | 複合インデックス5つはすべて定義済み。追加なし。ルールも変更なし |
| Q3 | qa | 完了 | goods・trade_posts・chats のテスト 71件。ルールのテスト 316件成功 |
| D4 | data | 完了 | main.dart のみ。--dart-define=APP_CHECK_SITE_KEY。キー無しの本番ビルドでは無効、デバッグでは WebDebugProvider |
| D5 | data | 完了 | tools/seed/**。.gitignore に tools/seed/node_modules/ を追加（リーダー） |
| Q4 | qa | 完了 | test_rules/demo_data.test.js・test/repositories/demo_data_test.dart（fixture: test/fixtures/demo_data.json）。test 840・rules 321 |
| U3 | ui | 完了 | firebase.json（/ と **/!(*.*) も no-cache）・web/index.html・manifest.json。build 成功 |
| U4 | ui | 完了 | CSS visibility:hidden、login_page.dart に規約の文言とリンク（Key: login_recaptcha_notice）。整形で変わった9ファイルの復元をユーザーに依頼中 |
| R1 | qa | 完了 | 重大・中なし |
| R2 | qa | 完了 | 重大・中なし。軽微: 文言はログイン画面だけ（ユーザー判断） |
| L2 | リーダー | 完了 | markdown/deploy_手順.md |
| L1 | リーダー | 完了 | 9ファイル復元済み。コミット済み |

## ユーザーに確認すること・横山さんに伝えること

- 横山さんに渡す: notes/step7_ルール監査.md の横山さんの中（goods の variants）・軽微

## 再開のメモ（止まったときの状況・再開した日時）

- 
