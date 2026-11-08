# 紹介ページ（案C 改）レビュー記録（qa）

## T0: 品質ゲートの確認（2026-11-08）

| 項目 | 結果 |
|---|---|
| `flutter analyze` | 0 件 |
| ルールのテスト | 322 件成功・失敗 0 |
| `flutter test` | 成功 1225 / 失敗 40（ui-top が `welcome_page.dart` を書き換え中の状態で実行） |

### 既存の失敗（紹介ページ以外。25 件。ユーザーが「既存の失敗として進める」と了承済み）

R1 で、今回の変更がこの一覧を増やしていないことを確かめる。

| ファイル | 件数 | テスト名 |
|---|---|---|
| test/features/oshi_search_page_test.dart | 1 | フォロー・解除 フォローすると「フォロー中」になり、解除すると戻る |
| test/features/trade_board_view_test.dart | 5 | フォロー中の先頭の推しが、最初から選ばれている ／ 絞り込み（タグと手渡しの公演・手渡しの公演の候補・条件に合う投稿がなければ・推しを変えると条件が外れる） |
| test/features/oshi_page_test.dart | 2 | フォロー中の承認済みだけを出し、解除すると0件になる ／ 解除の処理中はボタンを押せず、連打しても1回だけ |
| test/features/scan_page_test.dart | 7 | 2枚のカードの文言 ／ 「手入力する」で /live-form ／ 戻れないときの戻る ／ 幅 320・360・390・430 ではみ出さない |
| test/features/home_page_test.dart | 1 | 幅 390: 上のバーに「おしあし」とアカウントのボタン… |
| test/theme/hako_app_widgets_test.dart | 9 | HakoPageScaffold の全テスト（上のバー・境界 720/719・戻る・barColor・bottomBar・はみ出さない など） |

原因（リーダー確認）: AccountMenuButton の ProviderException、BIZ UDPGothic がアセットに無い例外。

### 紹介ページのテスト（test/features/welcome_page_test.dart）で変わるもの（8章）

現在 15 件が失敗。W2 の途中（`hako_column` が無くなった等）で、想定どおり。Q3 で新仕様に書き直す。

- `hako_column` を見る → `welcome_page` に
- 6つのハコの題・説明・番号（文言変更 4.10）
- 最初の画面の見出し・リード文
- 「始める」の上の一行の案内（なくなる）
- 幅ごとの余白（20/40/64・最大 1100 → 24／520 以下 18・最大 960）
- ハコの列数（600 で 3 列 → 761 以上 3・521〜760 で 2・520 以下 1）

## レビュー記録

| 日付 | タスク | 重さ | 内容 | 対応 |
|---|---|---|---|---|
| 2026-11-08 | W3（welcome_page.dart 362〜365行） | 重大（アクセシビリティ） | 「おしあしを始める」の `Semantics(excludeSemantics: true)` が子の InkWell の tap・focus を消し、スクリーンリーダーで押せない（実測: flags:[isButton]・actions なし）。 | ui-top に依頼。再現テストは `welcome_page_test.dart` に置き、修正まで一時的に `skip` |
| 2026-11-08 | W3 再確認 | 解決 | ui-top が Semantics から label・excludeSemantics を外し、「→」だけ ExcludeSemantics に。skip を外した再現テストが成功 | 対応済み |
| 2026-11-08 | **R1 まとめ** | OK | `flutter analyze` 0 件。`flutter test` の失敗は 25 件で、T0 の既存の失敗と同じ内訳（oshi_search 1・trade_board 5・oshi_page 2・scan_page 7・home_page 1・hako_app_widgets 9）。紹介ページ（welcome_*）は 57 件すべて成功、skip なし。ルールのテストは `firestore.rules` を触っていないため T0 の 322 件のまま。変更は `lib/features/welcome/**`・`test/features/welcome_*`・notes だけ。 | 人の確認（12.1）へ |
| 2026-11-08 | B1（SOLUTION の中央寄せ） | 仕様どおり | 計画書 4.6 は左寄せだったが、ユーザーの指示で中央寄せに変更済み（計画書 4.6 を更新・判断ログに記録）。ずれではない。中央寄せのテスト（幅 320・1000 × 文字 1.0・1.3 倍：英字・見出し・説明の中心が帯の中心、蛍光ペンが「おしあし」の下）を追加 | 対応済み |
| 2026-11-08 | W1（welcome_layout.dart の `WelcomeWrap`） | 中〜重大（見た目） | 幅の広い画面（実測は幅 1000）で、左寄せの区画（見出し・SOLUTION）が、中身の幅に縮んだまま中央にずれる（「PROBLEM 01」の左端が 44 でなく 164、SOLUTION が 136）。`Center` の緩い制約で `Column(start)` が縮むため。幅 390 では出ない。 | ui-top が `WelcomeWrap` を直した。回帰テスト（`WelcomeWrap` の左端 4 件・SOLUTION の左寄せ 4 件）を追加 |
| 2026-11-08 | B1（SOLUTION を左寄せに戻す） | 仕様どおり | ユーザーの指示で再び左寄せ（計画書 4.6）。中央寄せのテストを左寄せの期待に戻した | 対応済み |
| 2026-11-08 | **R1 最終確認（再）** | OK | `flutter analyze` 0 件。welcome_*（layout・sections・page）65 件すべて成功、skip 0。`flutter test` 全体の失敗は 25 件で T0 と同じ内訳。 | 完了 |
| 2026-11-08 | **R1 最終確認** | OK | `flutter analyze` 0 件。welcome_*（layout・sections 32・page 17）すべて成功、skip 0 件。`flutter test` 全体の失敗は 25 件で T0 と同じ内訳（増減なし）。 | 完了 |
| 2026-11-08 | W1・B1・B2・W2 | OK | 共有の差分なし（`git diff --stat` は `lib/features/welcome/**` だけ）。`GoogleFonts.`・`fontFamily`・`AnimationController`・`TextStyle(` の直書き無し。旧部品（`_Hall*`・`_Wide`）無し。`flutter analyze` 0 件。行の高さは `welcomeJp` で明示。蛍光ペンの位置・影 5px/6px・矢印の位置・FAQ の独立・列の数は Q1〜Q3 のテストで確認。 | — |
| 2026-11-08 | Q1〜Q3 | — | `welcome_layout_test.dart`（12 件）・`welcome_sections_test.dart`（28 件）・`welcome_page_test.dart`（16 件＋skip 1 件）を追加・書き直し。旧テストの期待は、新仕様（4.10・4.3）に合わせて置き換えた（弱めていない）。 | 全件成功（skip 1 を除く） |
| 2026-11-08 | 軽微 | 軽微 | 見た目の高さ（4.11 の ±8）は、テスト環境ではフォントが代用になるため、幅 390 の見出し・掲示板・ボタンだけ確認。区画ごとの縦位置は人の目で確認（12.1）。 | — |
