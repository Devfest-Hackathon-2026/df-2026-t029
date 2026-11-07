# ログイン前のデザイン（案6）レビュー記録

| 日付 | タスク | 重さ | 内容 | 対応 |
|---|---|---|---|---|
| 2026-11-07 | T0 | 中 | live_pages_test が Fa-3（ライブを追加するボタンを件数によらず出す）に追いついていなかった | 期待を「出し続ける」に直した |
| 2026-11-07 | A0 | - | google_logo.dart は計画書 4.5 のコードと完全一致。装飾で ExcludeSemantics。指摘なし | 承認 |
| 2026-11-07 | F2 | 軽微 | HakoTab は縦の制約が緩い場所（Row を Column 直下で高さ有限など）に置くと Center で高さが伸びる。スクロールの中なら 48。呼ぶ側で縦に無制限の場所に置くこと | 周知のみ |
| 2026-11-07 | Q1 | - | test/theme/hako_widgets_test.dart（ColorStrip・HakoTab・HakoPrimaryButton・HakoPill・GoogleLogo・HakoPage）12件 | 通過 |
| 2026-11-07 | A1〜A3 | - | ロジックのファイルの差分なし。`GoogleFonts.`・`GradientButton`・`SegmentedButton` の直書きなし。落ちた2件は HakoTab の selected/onPressed に書き直し（期待は同じ）。新規: 見出しのモード別・区切り・G ロゴ・幅 320・文字 1.3 倍・確認画面の幅 320 | 通過 |
| 2026-11-07 | W1 | - | nudge は disableAnimations で止まり、dispose あり。旧い `_heroImage`・scroll hint なし。テストを書き直し（ハコ6つ・掲示板3行・くわしくが無い・幅 320〜800・動きを切ると settle） | 通過 |
| 2026-11-07 | F1・F2・W1 | 軽微 | welcome_page.dart の「始める」ボタンは、フォーカス中に枠 4px を足すため、ボタンの大きさが 8px 動く（見た目のずれ）。他は 4.2 の数値どおり（余白・蛍光ペン・掲示板・ハコの余白・大きな数字・nudge の止め方と dispose） | ui-welcome に連絡（任意） |
| 2026-11-07 | C1 | - | 旧い色の名前（night・violet・text・subText・inkSub・line・pink・purple）は lib・test から参照なし。brand_colors.dart は新しい色だけ | 承認 |
| 2026-11-07 | R1 | - | まとめレビュー（11章）。ロジックのファイル（app・repositories・utils・providers・services・web・firestore.rules・app_theme）の差分なし。login_page・verify_email_page の差分は見た目のみ（`_changeMode` の呼び出しが SegmentedButton から HakoTab に変わっただけ）。`GoogleFonts.` は hako_fonts.dart と、もとからの app_theme.dart だけ。GradientButton・_heroImage・welcome_scroll_hint は lib に無い（test は「無い」ことの確認のみ）。`assets/fonts/` は ArchivoHako 3つと OFL の全文だけ。pubspec の依存は増えていない。キーはすべて残っている。await の後に mounted を確認している。二重送信は防がれている。テストは期待を弱めずに通っている（落ちた4件は部品の型の書き直しと文言の変更のみ）。flutter analyze 0 件・flutter test 989 件成功 | 承認。未解決の指摘は「始める」のフォーカス枠で大きさが 8px 動く軽微1件（任意） |
| 2026-11-07 | HakoPage 全幅化 | 軽微 | hako_column は全幅、中身は HakoContent で 430 以下・中央になった。テストを更新（HakoPage の全幅、HakoContent の 430 以下・中央とスマホ幅、紹介ページはハコの背景が全幅で文字・ボタンが 430 以下・中央、ログイン画面は入力欄が 430 以下・中央）。期待は弱めていない | 通過 |
| 2026-11-07 | HakoPage 全幅化 | 軽微 | lib/theme/app_theme.dart に差分あり（末尾の改行が1つ増えただけ。dart format の結果と思われる）。ロジックの変更ではない | リーダーに報告（戻すか判断） |
| 2026-11-07 | ハコの列組み | 重大 | 幅 1280・文字 1.3 倍で `_HallGrid`（IntrinsicHeight）の Column が 22px あふれる。再現: textScaleFactor 1.3、画面 1280×800 | ui-welcome に「バグ修正」を依頼。修正後に 1280 を文字 1.3 倍のテストへ足す（今は 360・800 のみ。TODO をテストに残した） |
| 2026-11-07 | ハコの列組み | - | 列組みのテストを追加（幅 320〜1280 で 1・2・3 列、同じ行の top・高さが等しい、列の幅が等分、ヘッダー・掲示板・「始める」は 430 以下で中央） | 通過 |
| 2026-11-07 | ハコの列組み（再） | - | 上の重大の修正（複数列では説明文を幅いっぱいにした）を確認。文字 1.3 倍のテストを幅 320・360・600・800・900・1280 に広げ、通過 | 解決 |
| 2026-11-07 | 紹介ページの広い幅 | - | ハコは幅 600 以上すべて3列。ヘッダー・最初の画面・「始める」は全幅で、余白 20/40/64・中身最大 1100。テストを更新（2列のテストを3列に、430 のテストを余白・最大 1100 に）。ヘッダーの「おしあし」左端・「ログイン」右端・高さ 44 以上、幅 320〜1920 と文字 1.3 倍で例外なし | 通過 |
