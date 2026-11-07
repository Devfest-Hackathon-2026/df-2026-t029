# front1 レビュー記録（qa）

| 日付 | タスク | 重さ | 内容 | 対応 |
|---|---|---|---|---|
| 2026-11-07 | T0 | 中 | trade_post_detail_page_test の承認後の文言が古かった（50bc233 で「（募集を終了しました）」が付いた） | テストの期待を新文言に更新 |
| 2026-11-07 | T0 | 中 | trade_chat_repository_test の approveReply が、投稿ドキュメントが無く not-found で落ちていた（50bc233 で投稿も更新するようになった） | setUp に投稿を追加し、status=closed・updatedAt も確かめるようにした |
| 2026-11-07 | R1（D2） | - | auth_validators・auth_error_message・auth_redirect・AuthRepository を4.5〜4.7・7章と照合。指摘なし。純粋関数・リポジトリのテスト（Q1）を追加し、すべて通った | 対応不要 |
| 2026-11-07 | R1（D3） | 軽微 | app.dart の import が並び順どおりでない（auth_redirect が features の間にある）。動作に影響なし | 担当者の判断に任せる |
| 2026-11-07 | R1（D4）/Q3 | - | google_calendar_service の `_accessToken` を4.8と照合。google.com あり／なし、各エラー、50分のキャッシュをテスト（Q3）。指摘なし | 対応不要 |
| 2026-11-07 | R2（U1） | 軽微 | login_page.dart の `_google`・`_submit` は FirebaseAuthException しか捕まえない。それ以外の例外（通信の層の想定外など）は、帯に何も出ないまま処理中だけ解除される | ui に伝える（任意） |
| 2026-11-07 | Q2（U1） | - | ログイン画面のテストを書き直し（モードの初期値と切り替え、検査、送信の引数、Enter、処理中の二重送信防止、エラーの帯、ポップアップを閉じたとき、再設定のダイアログ、戻る、reCAPTCHA、360px）。widget_test.dart も「Google で続ける」に更新。すべて通った | 対応不要 |
| 2026-11-07 | R2（U2） | 軽微 | verify_email_page.dart: 自動の確認の途中に「確認しました」を押すと、何の反応もなく無視される（確認は重ならないので動作は安全） | 任意。5秒以内に終わるので、そのままでよい |
| 2026-11-07 | R2（U3） | 軽微 | welcome_page.dart: 計画外の整形（既存の長い行の折り返し）の差分が混ざっている。見た目は変わっていない | 対応不要（リーダーがコミット前に知っておく） |
| 2026-11-07 | Q2（U2・U3） | - | 確認画面（表示、確認しました、5秒の自動確認、重ならない、閉じたらタイマー停止、送り直しの60秒、ログアウト）と紹介ページ（ボタンの行き先、説明の文言、reCAPTCHA が無い、360px、google_fonts は allowRuntimeFetching=false で pumpAndSettle まで例外なし）のテストを追加。flutter analyze 0件、flutter test 961件成功 | 対応不要 |
