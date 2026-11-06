# レビュー記録（Step4.5: 自分のライブ一覧）

qa（テスト・レビュー担当のエージェント）が、レビューやテストで見つけた問題と、仕様変更によるテストの書き直しを1行ずつ残す。横山さんのコードで見つけた問題もここに書き、リーダーがまとめてユーザーに伝える。

| 日付 | タスクID | 重さ | 内容 | 対応 |
|---|---|---|---|---|
| 2026-11-06 | R(D1〜D4) | - | my_live・live_repository(watch*ByIds・create/applyMerge の myLives)・live_search を差分レビュー。重大・中の問題なし。空 ID は空1回、30件分割、addedAt 不変、create は同一バッチ、applyMerge は同一トランザクションで確認 | Q1・Q2 のテストで固定（live_search_test.dart、my_live_repository_test.dart） |
| 2026-11-06 | T0 | 軽微 | 偽 LiveRepository が新メソッド3つ未実装で analyze が落ちていた | test/features/live_test_helpers.dart に実装 |
| 2026-11-06 | R(D5) | - | firestore.rules の myLives を監査。広い users/{uid}/{subcollection} から除外済みで素通りなし。addedAt 偽装・余計な項目・存在しないライブ・他人・未ログイン・下位コレクションが拒否、ライブ作成と同じバッチは許可を確認 | test_rules/mylives.test.js（12件）。既存を含め 242件成功 |
| 2026-11-06 | R(U3) | 軽微 | live_detail_page.dart の追加・外す（二重送信防止、確認ダイアログ、mounted 確認）に問題なし。一覧外でも「次にやること」は出る点は仕様の範囲 | 対応不要 |
| 2026-11-06 | U1/U4/D6 | - | 仕様変更でテスト書き直し: home_following_test（FAB の Key・文言）、live_pages_test・upcoming_deadlines_section_test（myLives 前提、空表示）、live_providers_test（myLives・liveSearch 追加） | 偽 FakeMyLiveRepository を追加。期待は変えただけで弱めていない |
| 2026-11-06 | R(U5) | 中 | live_add_page.dart の「もう一度読み込む」が効かない（searchLivesSourceProvider・searchPerformancesSourceProvider のエラーが残る） | ui に返却。test/features/live_add_page_test.dart に skip 付きで再現テスト、修正後に skip を外す |
| 2026-11-06 | U6 | - | 手渡しの公演の供給元変更に伴い、trade_post_form_page_test・trade_board_view_test を更新。0件の案内・一覧に無い公演の「外す」・候補が my* だけの検査を追加 | 期待を弱めていない |
| 2026-11-06 | Q4 | - | test/features/live_add_page_test.dart 追加（推しを選ぶ前は読まない、個人の推しは所属グループも対象、名前の揺れ、追加・外す、連打で1回、失敗の SnackBar、スマホ幅） | 全緑（再読み込みの1件は skip） |
| 2026-11-06 | 書き直し | - | 削除したテストと代わりのテスト: followTargetsProvider の2件→廃止（liveSearchProvider が FollowTargets.fromFollowing を使うため live_add_page_test「個人の推しは所属グループも対象」で代替）。livesProvider など7件（未ログインで空・呼ばない／空・読み込み中・エラー／購読し直し）→ live_providers_test「自分のライブ一覧（myLives）」group（未ログイン、空の ID、読み込み中・エラー、ID 集合が変わると購読し直す）。ホームの「登録ボタンは右下の1つだけ」は「ライブを追加するボタンは右下の1つだけ」に改名。ライブ一覧の0件も FAB 1つ | 期待は弱めていない |
| 2026-11-06 | Q3 | - | 新規作成バッチ（ライブ1＋公演50＋受付30＋myLives）、最小、他人の myLives を混ぜると全体拒否を test_rules/mylives.test.js に追加 | 245件成功 |
| 2026-11-06 | U5修正 | - | 「もう一度読み込む」の修正を確認、skip を外して回帰テスト化 | live_add_page_test 11件成功 |
| 2026-11-06 | R(D7)・R2 | - | 旧4プロバイダ（livesProvider など）の参照が lib・test に残っていないことを grep で確認。グッズ交換2ファイルの差分は手渡しの公演の供給元と0件・一覧外の表示だけ | 問題なし。全体を3回実行して全緑（干渉による失敗は再現せず）、747件 |
