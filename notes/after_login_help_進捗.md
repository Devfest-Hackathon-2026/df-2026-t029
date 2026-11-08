# after_login_help 進捗（ログイン後の画面に「ヘルプシート（案C）」を足す）

状態: 完了。コミット 273c01e（既存テストの修正）・065f8fb（ヘルプシート）、origin/dev をマージ（3cd1669。コンフリクトなし）。範囲外39ファイルの整形はユーザーが git restore で戻した（analyze 0 件・test 1437 件成功）。残り: 画面の確認・push と PR（人間）

> リーダーが、タスクが1つ終わるたびに更新する（計画書 `markdown/feature_after_login_help_plan.md` の 14章）。
> 使用量の上限で止まって再開したときは、まずこのファイルを読む。終わったタスクはやり直さない。
> すべて終わったら、上の行を `状態: 完了` にする。

最終更新: 2026-11-08

## 合意（2章。ユーザーの指示）

- デザインは、`markdown/design_after_login_help/oshiashi_C_help_sheet.html`（案C）のとおり
- Dart（Flutter）で書く。JavaScript ではない
- ブランチは `redesign/after_login`（ログイン後のリデザインへの追加）
- チームのモデルは Sonnet 5.5（`claude-sonnet-5-5`）

## 実装前の確認（5章。2026-11-08 確認済み。すべて案A）

| 項目 | 推奨案 | 回答 |
|---|---|---|
| 5.1 吹き出しの「初回だけ」の覚え方 | 案A: アプリを開いている間だけ | 案A |
| 5.2 PC の「?」の置き場所 | 案A: 左のタブの下 | 案A |
| 5.3 メモリーに「みんなのメモリー」の項目 | 案A: 4つ目を足す | 案A |
| 5.4 更新日時の年の省略 | 案A: 今年のときだけ省略 | 案A |
| 5.5 下部バーの未読の数字 | 案A: 出す | 案A |
| 5.6 細部の2点（用語・札の色） | 案A: 見本のとおり | 案A |
| 5.7 横山さんへの共有 | 案A: マージの前に一声 | 案A |
| 5.8 デモデータの「BD封入先行」 | 案A: 直す（再投入は人間） | 案A |

## タスクの状況

| ID | 優先 | 担当 | 状態 | メモ（触ったファイル・次にやること） |
|---|---|---|---|---|
| L0 | | リーダー | 完了 | ブランチ OK・analyze 0 件・test 51 件失敗（既存）。5章は全て案A。判断ログに記録 |
| T0 | | qa | 完了 | 既存51件を test/ だけで修正（lib のバグなし）。T0 のファイル: test/theme/hako_app_widgets_test.dart、test/features/{home_page,live_pages,oshi_search_page,scan_page,memory_form_page}_test.dart、oshi_test_helpers.dart、public_memory_test_helpers.dart（新規）。trade_board_view_test.dart は S1 の変更と混ざるのでヘルプのコミット側に入れる。全体 1288 成功・3 失敗（S1 の文言。Q4 で対応） |
| C1 | P1 | ui-core | 完了 | 契約の部品（help_topic・help_scope・help_providers・HakoHint・HakoGiveWantLine・formatUpdatedAt・淡い色）。brand_colors・hako_app_widgets・updated_at_format・help_providers・help/help_topic・help_scope。文言は 4.10 とリーダー照合済み。契約は ui-screens・qa に送付 |
| C2 | P1 | ui-core | 完了 | help_sheet・help_button・HakoAppBar。help_sheet.dart・help_button.dart（新規）、HakoAppBar に HelpButton。リーダー確認: 640・0.82・暗幕45%・noAnimation・44・toggled・文言 OK。Esc は既定の動き（Q2 で確認） |
| C3 | P1 | ui-core | 完了 | app_shell（スコープ・PC の「?」・吹き出し）。help_coach.dart（新規）・app_shell.dart。**事故**: ui-core が `dart format lib/features` で範囲外39ファイルを整形（整形のみとリーダー確認）。ユーザーに `git restore` を依頼中。C3 のテスト済み。吹き出しとアカウントのメニューの重なりを案A（onOpened で dismiss）で修正。analyze は整形起因の1件のみ、app_shell_test・test/theme 124件成功（リーダー確認） |
| S1 | P2 | ui-screens | 完了 | 譲・求のラベル、更新日時、文言の修正。trade_board_view・trade_match_view・trade_post_summary_lines・upcoming_deadlines_section。リーダー確認: 片方マッチ・詳細画面は不変、文言 OK |
| S2 | P2 | ui-screens | 完了 | 画面の中の補足。oshi_page・favorite_oshi_card・live_list_page・memory_list_page・交換2画面。hint_* 9つ確認 |
| S3 | P2 | ui-screens | 完了 | tools/seed/demo_data.mjs:414 を「BD封入先行」に（リーダー確認済み）。フィクスチャの作り直しは qa（Q4） |
| C4 | P3 | ui-core | 完了 | 下部バー・左のタブの見た目、未読の数字。app_shell.dart のみ。リーダー確認: 80・浮き6/4・影3・150ms・disableAnimations・shell_tab_*・未読の丸・既存キー OK。app_shell_test の旧仕様5件は qa が書き直し（Q5） |
| Q1 | | qa | 完了 | 契約の部品のテスト |
| Q2 | | qa | 完了 | シート・ボタンのテスト |
| Q3 | | qa | 完了 | 外枠・吹き出しのテスト |
| Q4 | | qa | 完了 | 各画面のテスト、フィクスチャの作り直し |
| Q5 | | qa | 完了 | 下部バーのテスト |
| C5 | | ui-core | 完了 | 掃除（不要な import・変数なし。変更なし） |
| R1 | | qa | 完了 | まとめレビュー。重大1件（シートの Semantics の assert）・軽微1件（フォーカスが「?」に戻らない）を ui-core が修正、回帰テストあり。記録は notes/after_login_help_レビュー記録.md |
| L1 | | リーダー | 完了（コミット待ち） | 結合確認・差分の確認・動作確認手順・コミット案。analyze は整形起因の1件のみ、flutter test 1437 件成功、ルールのテスト 322 件成功。変更禁止の範囲に差分なし |

## 開始時の品質ゲート（L0）

- `flutter analyze`: 0 件（`flutter pub get` が必要だった）
- `flutter test`: 1240 成功・51 失敗。ファイル: home_page・live_pages・memory_form_page・oshi_page・oshi_search_page・scan_page・trade_board_view・hako_app_widgets。主因は authStateProvider・publicMemoryRepositoryProvider の差し替え漏れ（Fd・K のマージ後）。qa が T0 で直す

## ユーザーに聞きたいこと

- 範囲外39ファイルの整形の巻き戻し（`git restore`。コマンドは scratchpad/fmtcheck/restore_cmd.txt）。範囲内11ファイルの整形の差分は残す案で提案中
