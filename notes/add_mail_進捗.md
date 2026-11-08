# add_mail 進捗（プロフィールにメールアドレスの変更を足す。案C ボトムシート）

状態: 実装・テスト・レビュー・結合確認が完了。ユーザーの実メールでの動作確認（12.1）とコミットの了承待ち

> リーダーが、タスクが1つ終わるたびに更新する（計画書 `markdown/feature_add_mail_plan.md` の 14章）。
> 使用量の上限で止まって再開したときは、まずこのファイルを読む。終わったタスクはやり直さない。
> すべて終わったら、上の行を `状態: 完了` にする。

最終更新: 2026-11-08（実装・テスト・結合確認が完了。ユーザーの動作確認とコミットの了承待ち）

## 合意（2章。ユーザーの指示）

- デザインは、`markdown/design_add_mail/oshiashi_mail_C_bottom_sheet.html`（案C）のとおり（4.0 の表の変更点を除く）
- Dart（Flutter）で書く。JavaScript ではない
- ブランチは `feature/add_mail`
- agent team は、リーダー＋チームメイト3人（auth-data・ui・qa）。モデルは Sonnet 5.5

## 実装前の確認（5章。未確認。聞くまでチームメイトは作らない）

| 項目 | 推奨案 | 回答 |
|---|---|---|
| 5.1 確認の方法 | 案A: Firebase 標準の確認リンク（6桁のコードは作らない） | 案A で確定（11/8） |
| 5.2 本人確認（パスワード） | 案A: 求められたときだけ、同じシートにパスワード欄を足す | 案A で確定（11/8） |
| 5.3 これまでのアドレスへのお知らせ | 案A: Firebase 標準に任せる（届くことを動作確認で確かめる） | 案A で確定（11/8） |
| 5.4 メールアドレスの見せ方 | 案A: 見本のとおり伏せ字 | 案A で確定（11/8） |
| 5.5 動作確認で分かること | （決める項目ではない）①既に使われているアドレスでエラーが返るか ②変更後にログインが切れるか ③お知らせが届くか ④メールの文面 | |
| 5.6 共有のファイルへの変更 | 案A: マージの前に一声 | 案A で確定（11/8） |

## タスクの状況

| ID | 優先 | 担当 | 状態 | メモ（触ったファイル・次にやること） |
|---|---|---|---|---|
| L0 | | リーダー | 完了 | 0章の確認（ブランチ・品質ゲート: analyze 0件・test 1437件成功）、5章の回答、判断ログ（11/8） |
| T0 | | qa | 完了 | 直すテストは2つ: `auth_test_helpers.dart` の FakeAuthRepository（新メソッド追加。auth-data から形が届き次第）、`profile_page_test.dart` の pumpProfile に authRepositoryProvider の偽物を足す。ほかは変更不要の見込み（U1 後に確認） |
| A1 | P1 | auth-data | 完了 | `email_change.dart`・`emailChangeErrorMessage`。契約を ui・qa に送付済み。qa のレビューで問題なし |
| A2 | P1 | auth-data | 完了 | `auth_repository.dart`（追加のみ・削除0行）・`email_change_providers.dart`。契約からの変更: copyWith に `clearError`、resend が `requires-recent-login` のとき入力へ戻して needsPassword。analyze 0件。qa にレビュー依頼済み |
| U1 | P1 | ui | 完了 | `account_section.dart`・`profile_page.dart`・シートの空の入れ物。analyze 0件・profile_page_test 通過。qa にレビュー依頼済み |
| U2 | P1 | ui | 完了 | `email_change_sheet.dart`。analyze 0件・全体 test 1472件成功（ui 報告）。qa のレビュー待ち。**人間の動作確認（12.1 の 3〜10）待ち** |
| U3 | P2 | ui | 完了（動作確認の前に先行） | Google の行・表示／かくす・SnackBar・有効期限切れの形。5.5 の結果で 4.5・4.7 を直す可能性あり |
| Q1 | | qa | 完了 | `test/utils/email_change_test.dart` |
| Q2 | | qa | 完了 | FakeAuthRepository・`email_change_notifier_test.dart`（19件）・`profile_page_test.dart` |
| Q3 | | qa | 完了 | `account_section_test.dart`（22件）・`email_change_sheet_test.dart`（27件）ほか |
| C1 | | ui | 完了 | 掃除済み。成功時にパスワード欄を clear()。回帰テスト追加済み |
| R1 | | qa | 完了 | 重大・中なし、軽微2件（1件は C1 で対応）。lib の差分は6章の範囲だけ。全体 test 1522件成功・analyze 0件。430 幅のはみ出しだけ未テスト（390・700 で代用）。詳細は `notes/add_mail_レビュー記録.md` |
| L1 | | リーダー | 一部完了 | 結合確認済み（analyze 0件・test 1523件成功・差分は6章の範囲だけ）、判断ログ記入済み。残り: ユーザーの動作確認の結果（5.5）の反映、コミット案の了承 |

## 動作確認で分かったこと（5.5。12.1 の結果をここに書く）

- ① 既に使われているアドレス:
- ② 変更後のログイン:
- ③ これまでのアドレスへのお知らせ:
- ④ 確認メールの文面・リンクの先:

## ユーザーに聞きたいこと

- 5章の項目（上の表。推奨案で進めてよいか。特に 5.1）
