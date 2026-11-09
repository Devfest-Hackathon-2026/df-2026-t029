# レビュー記録: 投稿画面の作り直し（案2改）

| 日付 | タスク | 重さ | 内容 | 対応 |
|---|---|---|---|---|
| 11/9 | T0 | - | analyze 0件。test は D1 の既定変更で5件失敗 | 期待を弱めず更新（ticket=24曲・photoMain は design 指定で従来どおり）。通過 |
| 11/9 | D1 | 問題なし | `ShareConfig.toggled`／`copyWith`／`ShareState.copyWith` が `sizes`・`sharePhotos` を引き継ぐ。`ShareContent` に座席なし。`buildCaption` は差分なし | テストで確認 |
| 11/9 | D1 | 軽微 | `removeSharePhoto` は、一覧に無いパスを渡しても操作済み扱いになる（画面は一覧にあるものしか外さないので実害なし） | 対応不要 |
| 11/9 | Q1 | - | `share_ticket_test`（ShareSizes・ShareConfig.sizes・layoutShareText の ticket/photoMain・shareImageNotes・座席）と `share_notifier_test`（sharePhotos・sizes）を追加 | 通過 |
| 11/9 | Q2・S2/S3 | 中〜重 | 上のバーの戻るボタン（`HakoPageScaffold` の `_goBack` は `context.pop()`）が `PopScope` の確認ダイアログをすり抜け、未保存の入力が確認なしで消える。端末の戻るでは確認が出る（R1-1） | ui-share／リーダーに連絡。テストは `skip: true` で置いた（直ったら外す） |
| 11/9 | U1 | 問題なし | 記録のチケットの写真の欄（1〜4枚・＋n・「写真を直す」44px 以上・欄の全体では開かない・0枚は今のまま）とシートの説明1行 | `memory_ticket_page_test`・`photo_sheet_test` に追加。通過 |
| 11/9 | Q1・Q2 | - | `share_fit_test`（単調・順番・最低1曲）・`share_page_test` の書き直し（骨組み・3タブ・写真・保存・大きさ・戻る確認・座席が出ない・記録の写真が変わらない）・`share_photo_key_test` | 通過 |
| 11/9 | R1-1 | 中〜重（修正済み） | 戻るボタンのすり抜けを `onBack`（省略可）の追加で修正。`lib/theme/hako_app_widgets.dart` の差分は `HakoAppBar`・`HakoPageScaffold` への `onBack` の追加だけで、省略時は従来どおり `_goBack`。ほかの画面は `onBack` を渡さないので動きは変わらない | 回帰テストの skip を外して通過（確認が出る・「とどまる」・「保存せずに戻る」・入力が無ければ確認なし） |
| 11/9 | Q2（プレビューの縮小） | - | プレビューが、パネルのスクロールで 100%→約50% に縮む（`SliverPersistentHeader` pinned）。テスト: 固定部分が残る・縮む（下限は約50%）・一番上で元に戻る・タブ切り替えで先頭に戻る・幅320×高さ600×文字1.3倍ではみ出さない・縮んでも投稿の欄・入力・タブが使える | `share_page_test` に追加。通過 |
