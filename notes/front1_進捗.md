# front1 進捗（メールアドレスでの登録・ログインと、ログイン画面の作り直し）

状態: 進行中

> リーダーが、タスクが1つ終わるたびに更新する（計画書 `markdown/feature_front1_auth_plan.md` の 14章）。
> 使用量の上限で止まって再開したときは、まずこのファイルを読む。
> すべて終わったら、上の行を `状態: 完了` にする。

最終更新: 2026-11-07 全タスク完了、L1（コミットの了承待ち・ユーザーの動作確認待ち）

## 合意（2章。ユーザーと合意済み）

- ログインの方法は Google と、メールアドレス＋パスワード。Apple は作らない
- 確認メールを送り、確認するまで使えない
- パスワードの再設定を入れる
- 紹介ページの「始める」「ログイン」は、ログイン画面へ移す
- メールで登録した人のカレンダーは、初めて追加するときに Google アカウントをつなぐ

## 実装前の確認（5章）

- 5.1 横山さんの了承: すべて了承（D4・Q3 も行う）
- 5.2 コンソールで「メール / パスワード」を有効にしたか: 未確認（L1 の前までに）
- 5.3 ルールでの遮断はしない: 画面の振り分けだけ（確認済み）
- 5.4 そばで見ているか: そばにいる
- 開始時の品質ゲート: analyze は下書き（Claude outputs/）を解析から外して 0件。test は横山さんの 50bc233 由来の1件が失敗 → T0 で qa が期待を新しい文言に直す。ルールのテストは成功

## タスクの状況

| ID | 担当 | 状態 | メモ（触ったファイル・次にやること） |
|---|---|---|---|
| T0 | qa | 完了 | trade_post_detail_page_test・trade_chat_repository_test の期待を 50bc233 に合わせた |
| D1 | data | 完了 | 7章の叩き台のまま確定し、ui・qa に送付 |
| U0 | ui | 完了 | brand_colors.dart・verify_email_page.dart（新規）、login_page.dart（LoginMode・initialMode のみ） |
| D2 | data | 完了 | auth_validators・auth_error_message・auth_redirect（新規）、auth_repository.dart |
| D3 | data | 完了 | app.dart（redirect を decideRedirect に、/verify-email 追加、/login の mode、重複 /login 削除。format はかけない） |
| D4 | data | 完了 | google_calendar_service.dart の _accessToken のみ。整形だけの差分を戻させている |
| U1 | ui | 完了 | login_page.dart（作り直し）、auth_widgets.dart（新規・確認画面と共用）。FirebaseAuthException 以外の例外の表示を追加させている |
| U2 | ui | 完了 | verify_email_page.dart。U1 と同じく例外の扱いを追加させている |
| U3 | ui | 完了 | welcome_page.dart（4.4 の範囲＋整形数か所）。_Palette は BrandColors の typedef |
| Q1 | qa | 完了 | test/utils/auth_*_test.dart、test/repositories/auth_repository_test.dart、test/features/auth_test_helpers.dart |
| Q2 | qa | 完了 | login_page_test（書き直し）・verify_email_page_test・welcome_page_test・widget_test |
| Q3 | qa | 完了 | test/services/google_calendar_service_test.dart |
| R1 | qa | 完了 | 重大・中なし。軽微: app.dart の import 位置（data が直す） |
| R2 | qa | 完了 | 重大・中なし。軽微は notes/front1_レビュー記録.md |
| L1 | リーダー | 進行中 | analyze 0件・test 961件成功。コミット案をユーザーに提示中 |

## ユーザーに聞きたいこと

（なし）
