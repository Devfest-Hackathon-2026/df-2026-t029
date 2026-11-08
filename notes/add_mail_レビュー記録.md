# add_mail レビュー記録

| 日付 | タスク | 重さ | 内容 | 対応 |
|---|---|---|---|---|
| 2026-11-08 | A1 | なし | email_change.dart・emailChangeErrorMessage を計画書7章・4.5と照合。問題なし | test/utils/email_change_test.dart（16件）を追加 |
| 2026-11-08 | U1 | 軽微 | account_section.dart: providerIds を build 内で ref.read している（ログイン方法は画面の間は変わらないので実害なし）。email_change_sheet.dart は空の入れ物、profile_page.dart は区画を足しただけ | 対応不要。profile_page_test.dart に FakeAuthRepository を差し替え済み |
| 2026-11-08 | A2 | なし | auth_repository.dart の5メンバーと EmailChangeNotifier を計画書4.4〜4.7・7章と照合。パスワードは state に残らない、二重送信・破棄・再送・sessionEnded を確認。問題なし | test/providers/email_change_notifier_test.dart（19件）を追加 |
| 2026-11-08 | U2・U3 | 軽微 | email_change_sheet.dart: 入力したパスワードが、シートを閉じるまで State の TextEditingController に残る（Notifier の state には残らない。ステップが進んでも欄の中身は消えない） | 対応任意。ui に伝えた（成功時に password.clear() を勧める） |
| 2026-11-08 | Q3 | なし | 画面のテストを追加: account_section_test.dart（22件）・email_change_sheet_test.dart（27件）・profile_page_test.dart に1件。画面が計画書4.2〜4.7のとおり動くことを確認 | 全体 flutter test 1522件成功・analyze 0件 |
| 2026-11-08 | R1 | なし | git status で、lib の変更が6章の範囲だけであることを確認（profile_page.dart は AccountSection の追加のみ、auth_repository.dart・auth_error_message.dart は追加のみ）。ルール・pubspec は未変更 | |
| 2026-11-08 | R1 | なし | 11章の観点を確認: GoogleFonts 直書き・Firebase*.instance・ログ出力・見本の試し用の分岐・6桁・10分・太さ 800 以上は無し。パスワード欄は obscureText あり。pubspec・firestore.rules・functions・app.dart の差分なし。disableAnimations 対応あり。幅 320〜1000×文字 1.3 倍×キーボードありのはみ出しテストあり（430 幅は未テスト。390 と 700 で代用） | 対応不要 |
| 2026-11-08 | C1 | なし | email_change_sheet.dart の listen で、入力ステップを抜けるとき _password.clear()。軽微の指摘への対応を確認 | 回帰テストを email_change_sheet_test.dart に追加（再送で入力に戻ったとき、パスワード欄が空）。analyze 0件・test 1523件成功 |
