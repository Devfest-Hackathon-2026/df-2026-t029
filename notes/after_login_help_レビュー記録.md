# ログイン後のヘルプシート（案C）レビュー記録（qa）

形式: 日付 / タスク / 重さ / 内容 / 対応

| 日付 | タスク | 重さ | 内容 | 対応 |
|---|---|---|---|---|
| 2026-11-08 | T0 | 中 | 作業前のツリーで flutter test が 51 件失敗。主因は Fd・K のマージ後にテストが `currentUidProvider`・`myProfileProvider`・`favoriteOshiRepositoryProvider`・`publicMemoryRepositoryProvider` を差し替えておらず、AccountMenuButton などが Firebase 未初期化で例外を出し、上のバーが 99618px はみ出す連鎖。ほかに Fd の変更（ライブ一覧のキー、ジャンル選択の最初の画面、種類の札の文字、掲示板の既定が「フォロー中の推し すべて」、タグと受け渡しを1行にまとめた）にテストが追いついていなかった | test/ だけで直した（lib の本当のバグは無し）。期待は弱めていない |
| 2026-11-08 | C2 | 重大 | `help_sheet.dart` の `Semantics(scopesRoute: true)` に `explicitChildNodes: true` が無く、「?」を押すとデバッグで assert が出てシートが描画されない（`test/features/help/help_button_test.dart` で再現） | ui-core が修正済み。回帰テストあり（help_sheet_test・help_button_test） |
| 2026-11-08 | C2 | 軽微 | 閉じたあと「?」にフォーカスが戻らない可能性（4.3） | ui-core が FocusNode で対応。Esc・「とじる」の両方でフォーカスが戻るテストを追加 |
| 2026-11-08 | C2 | 軽微 | シートが開いている間は、背後の「?」が読み上げの木から外れる（scopesRoute のため）。`toggled` は読み上げでは確かめられない | 仕様どおり。toggled は見た目の反転（背景が墨）のテストで確認 |
| 2026-11-08 | C1 | 軽微 | `formatUpdatedAt` の呼び出し側（掲示板・マッチ・要約）は `now` を渡さず `DateTime.now()` を使うので、画面の「年の省略」が `nowProvider` で固定できない。テストは年を任意にする正規表現（`(\d{4}/)?`）にして、実行する年に依存しないようにした | 対応不要（提案: 呼び出し側で `ref.watch(nowProvider)` を渡すとテストが固定できる） |
| 2026-11-08 | C1 | 軽微 | `HakoGiveWantLine` の札は `Container(alignment: center)` で、親の高さが決まっている（Center の中など）と縦いっぱいに伸びる。今の使われ方（Column・Card・ListView の中）では問題なし | 対応不要。高さが決まっていない並びの中で崩れないテストを追加 |
| 2026-11-08 | C3 | 中 | ホームの初回の吹き出しが、アカウントのメニューの「ログアウト」に重なる（既存テストが落ちると ui-core が報告） | ui-core が、メニューを開くと吹き出しを消す（`onOpened`）ようにした。「メニューを開くと消える」テストを追加（app_shell_help_test） |
| 2026-11-08 | C4 | 軽微 | 下部バーの高さ 72→80。タブの部品が変わるので app_shell_test の高さ・ピルの色の確認を書き直した | 丸の色（濃い／淡い）・6 浮く・硬い影・キー・読み上げ・未読の数字を確認するテストに置き換え（期待は強めた） |
| 2026-11-08 | S1 | 軽微 | 「譲：」「求：」「もらえるもの：」「出せるもの：」「更新：」「フォロー中すべて」「合うあなたの投稿」のテストが旧文言 | 札（HakoGiveWantLine）と本文が別 Text になる形、新しい文言に書き直した。「片方マッチ」の名前が変わっていないことのテストを追加 |
| 2026-11-08 | S1・S2 | 軽微 | 4.8 の「何もしない」項目（片方マッチ、プレイガイド先行）は変更されていない。`【当選者のみ】` は受付名に含まれるとき足さない（二重にならない） | テスト追加（upcoming_deadlines_section_test） |
| 2026-11-08 | S2 | 軽微 | 補足（電球の行）が 4.5 の条件どおり。ホーム・「みんなのメモリー」には出ていない。最推しがいないとき `hint_oshi_favorite` は出ない。見出しが出ないとき（メモリー0件・マッチ0件）は補足も出ない | 各画面のテストに追加（oshi_page・live_pages・memory_pages・trade_board_view・trade_match_view） |
| 2026-11-08 | S3 | 軽微 | `demo_data.mjs` の「BD封入先行」に対応して test/fixtures/demo_data.json を作り直した（差分は1行）。`test_rules/demo_data.test.js` も通る | 完了 |
| 2026-11-08 | R1 | 中 | `git diff --stat` で、6章の範囲外の lib（約 39 ファイル。home・profile・travel・oshi・trade・live など）に整形（`dart format lib/features`）だけの差分がある。`flutter analyze` の `following_oshi_list.dart:185`（curly_braces）もこの整形が原因 | リーダー確認済み。人間が `git restore` で戻す予定。範囲外のロジックの変更は見つからなかった |
| 2026-11-08 | R1 | — | `pubspec.yaml`・`lib/app.dart`・`firestore.rules`・`storage.rules`・`test_rules`・`web`・`assets`・`lib/models|repositories|services|providers|utils`（新規の `help_providers.dart`・`updated_at_format.dart` を除く）に差分なし。「?」は `HakoAppBar` と `app_shell.dart` の2か所だけ。`GoogleFonts.` の直書きなし。「片方向マッチ」への変更なし | 確認済み |
| 2026-11-08 | R1 | — | 品質ゲート: `flutter analyze` は上記1件だけ、`flutter test` は 1435 件すべて成功、ルールのテストは 322 件成功（`npm --prefix test_rules ci` でテスト用の依存を入れた。`node_modules` は git の対象外） | 確認済み |
