# ログイン後のデザイン（統合案 v4）レビュー記録

## T0: 見た目の部品に頼っている既存テスト（2026-11-07）

`test/flutter_test_config.dart` を新規作成（`GoogleFonts.config.allowRuntimeFetching = false`）。ロジックは変わらないので、振る舞いのテストは原則そのまま通る想定。下は、部品の型・位置・アイコンに頼っていて、画面の書き直しで落ちうるもの。

| ファイル:行 | 頼っているもの | 落ちうる理由・対応 |
|---|---|---|
| trade_board_view_test.dart:197, 331 | `find.byType(Card)` のキーで投稿の並びを確認 | 交換の投稿を `HakoBox` にすると `Card` でなくなる。Card のまま使うか、キー付きの部品を列挙する形に直す（並びの期待は弱めない） |
| trade_match_view_test.dart:141 | `find.byType(Card)` のキーで相互／片方の並びを確認 | 同上 |
| chat_list_page_test.dart:126, 146 | `find.byType(Badge)`（未読の印） | 未読の印を作り替えたら更新 |
| live_merge_flow_test.dart:545, 572 | `find.byType(InputChip)`（出演者のチップ） | 出演者チップを独自部品にしたら更新 |
| live_merge_flow_test.dart:681-687, live_form_save_test.dart:141-263 | `AlertDialog`（`content` を `Text` として読む） | ダイアログの作りを変えたら更新 |
| live_pages_test.dart:150 | `find.byType(FloatingActionButton)` が1つ | 右下のボタンを `FloatingActionButton.extended` で作る限り通る |
| live_pages_test.dart:215-216, 454 / live_add_page_test.dart:131 / upcoming_deadlines_section_test.dart:292 | `getTopLeft(...).dy` で並び順（行の位置） | 行の部品が変わっても、キーが行に付いていれば通る。キーの付け替えに注意 |
| live_pages_test.dart:349, 744-749 / trade_board_view_test.dart:260-269 / trade_post_detail_page_test.dart:154 / oshi_test_helpers.dart:210 | `find.byType(Scrollable)`（`.first`・`.last`）・`ListView` の下の `Scrollable` | 横スクロールのカード列（ホーム・メモリー）や `HakoPageScaffold` で `Scrollable` の数・順が変わりうる。`.first`/`.last` が別のものを指したら、キー指定に直す |
| trade_match_view_test.dart:222 | `find.byType(ListView)` を fling | `ListView` が複数になったら更新 |
| upcoming_deadlines_section_test.dart:373-380 | `Icons.warning_amber_rounded` | 次の締切の行のアイコンを HTML のもの（`caledit` など）にすると落ちる。警告の意味が残る形にする（期待は弱めない） |
| official_url_link_test.dart:125-300 | `Icons.open_in_new` | 公式 URL のリンクのアイコンを変えたら更新 |
| official_url_link_test.dart:130, 247 / login_page_test.dart:342-431 | `SnackBar` が出ない | テーマの `SnackBarThemeData` のみ。通る想定 |
| welcome_page_test.dart:172 / login_page_test.dart:628, 687 | `hako_column` の幅・通知の幅（案6） | ログイン前の画面は変えないので通る想定 |
| theme/hako_widgets_test.dart（12箇所） | `ColoredBox`・色・`Scaffold` | `hako_widgets.dart` を変えたら更新 |
| oshi_page_test.dart・oshi_request_page_test.dart・oshi_search_page_test.dart（文言・キー中心） | `Scaffold`/`AppBar` のタイトルの文言（`find.text`） | PC の幅で、タイトルが上のバーでなく本文の上に出る。幅 390 では上のバー。同じ文言が2か所に出ると `findsOneWidget` が崩れるので注意 |
| 全体 | 文言（`find.text`）・キー（`find.byKey`） | 5.3 の案A（文言はそのまま）なので通る想定。落ちたら実装のバグを疑う |

### 書体
- 各テストの `setUpAll`（紹介ページ・ログイン画面・`hako_widgets_test`）は残してよい。`flutter_test_config.dart` で全体に効く。

## 指摘一覧

| 日付 | タスク | 重さ | 内容 | 対応 |
|---|---|---|---|---|
| 2026-11-07 | B1 | 軽微 | live_add_page: 検索欄が `floatingLabelBehavior.never` で、入力すると「ライブ名（空でもOK）」が消える（HTML の sfld と同じ。許容） | 対応なし |
| 2026-11-07 | B1 | 軽微 | scan_page: 読み取り中などで押せないカードは Opacity 0.5＋影も薄くなる（意図どおり）。テスト追加（scan_page_test 新規・live_add 幅違い） | 対応なし |
| 2026-11-07 | B1 | 結果 | 重大・中の指摘なし。キー・文言・動き維持を確認。live_add 20件・scan 7件成功 | 承認 |
| 2026-11-07 | A3 | 対応 | live_pages_test の一覧の期待を、出演者と日付を別々の Text で探す形に更新（内容は同じ。期待は弱めていない） | qa が更新 |
| 2026-11-07 | A1・A2・A3・B2・B3・B4 | 結果 | 差分のキー・文言の消失を機械的に確認（キー・文言は維持）。重大・中なし。全体 flutter analyze 0件 | 承認（A4・A5 は進行中） |
| 2026-11-07 | A4 | 中 | ライブ詳細の書き直し途中で live_pages_test「公演: 開演順…」（`live_detail_performance_future` の「2026/11/6(金) 00:00 開演」が見つからない）と live_merge_flow_test「7日以内に変わった受付…」（`live_detail_edit_button` が見つからない）が落ちる | ui-a に連絡（実装の確認待ち） |
| 2026-11-07 | A5 | 中 | memory_list_page のキー `memory_list_attended_<performanceId>` が消えている | ui-a に連絡 |
| 2026-11-07 | B3 | 結果 | memory_form_page_test を新規追加（19件）。作成・編集・削除・100曲／100文字の境界・失敗の SnackBar・二重送信・はみ出し | 承認 |
| 2026-11-07 | A1 | 中 | home_expense_summary の Row が幅 390 で右に 44px はみ出す（テストは Ahem のため過大の可能性。予算が長ければ実機でも起こる）。`/ 予算 …` を Flexible に | ui-a に連絡 |
| 2026-11-07 | C3 | 中 | HakoDateBadge が文字 1.3 倍で縦にはみ出す（home_page_test 幅 720/1000・1.3 倍） | ui-core に連絡 |
| 2026-11-07 | A1 | 記録 | ホームの AppBar の「アカウント／ログアウト」アイコン2つは AccountMenuButton（メニュー）にまとまった。home_page_test で確認 | 承認 |
| 2026-11-07 | A4 | 対応 | ライブ詳細の本文が高くなり、遅延描画で画面外になる件はテスト側を調整（live_pages_test は縦長の画面、live_merge_flow_test は編集ボタンの確認をスクロール前に移動。期待は弱めていない） | qa が更新 |
| 2026-11-07 | A5 | 記録 | メモリー詳細の編集ボタン（memory_detail_edit_button）を AppBar から本文のタイトル下へ移した | 承認（幅テストは追って） |
| 2026-11-07 | B4 | 記録 | 交換のチャットのボタン（trade_chats_button）を上のバーの右からタブの右隣へ移した。記録する画面の削除ボタン（memory_form_delete_button）は本文の右上へ | 承認 |
| 2026-11-07 | S1 | 結果 | goods_form・trade_post_form・chat_list・expense を HakoPageScaffold に置換。色の直書きなし。trade_post_detail の帯は tonal＋墨の枠。幅 320〜1000 のテストを trade_top・chat_list・chat_page・trade_post_form・trade_post_detail・oshi_page・live_pages に追加（成功） | 承認 |
| 2026-11-07 | A5 | 取り下げ | memory_list_attended_<id> のキー消失の指摘は、MemoryAlbumCard に付いたまま（機械的な照合の誤検出）。取り下げ | 対応なし |
| 2026-11-07 | Q2 | 結果 | profile_page_test 新規（作成・編集・検査・色見本・濃い色で白文字・幅320〜1000×文字1.0/1.3倍）。各画面の幅テストは追加済み | 完了 |
| 2026-11-07 | R1 | 結果 | ロジックの差分は lib/providers/theme_providers.dart の初期色のみ（models・repositories・services・utils・app.dart・firestore.rules・pubspec は差分なし）。`GoogleFonts.`・`fontFamily`・Outfit の直書きなし。`Colors.*` は white／transparent のみ（error・primary はテーマ経由）。キー・文言の消失なし。パッケージ追加なし | 承認 |
| 2026-11-07 | R1 | 残り | 第2段階で置き換えなかった画面: chat_page・trade_post_detail_page（actions あり）・merge_review_page（Navigator）・calendar_test_page は Scaffold/AppBar のまま（テーマで世界観は揃う） | 許容（人が見て確認） |
| 2026-11-07 | 品質ゲート | 結果 | flutter analyze 0件・flutter test 1250件成功・ルールのテスト 322件成功 | OK |
