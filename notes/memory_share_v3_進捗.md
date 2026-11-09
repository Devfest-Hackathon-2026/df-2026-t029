# 進捗: 投稿画面の作り直し（案2改）

計画書: `markdown/feature_memory_share_v3_plan.md`。判断ログ: `notes/判断ログ_memory_share_v3.md`。作業ブランチ: `fix/memory`。提出: 11/10 19:00。

| タスク | 担当 | 状態 |
|---|---|---|
| L0 ブランチ確認・5章 | リーダー | 完了（11/9。ブランチ確認・品質ゲート analyze 0件／test 2013件・5章はすべて案A） |
| T0 品質ゲート確認 | qa | 完了（11/9。analyze 0件。D1 の `layoutShareText` 既定変更で test 5件が失敗中: `share_ticket_test` の layoutShareText 4件・`share_ticket_view_test` の上限1件。qa が期待を弱めず ticket=24曲に更新する） |
| D1 契約（share_ticket.dart・share_providers.dart） | share-data | 完了（11/9。両ファイル。担当2ファイルは dart analyze 0件・全体の flutter analyze は未確認。SendMessage が名前で届かなかったため、リーダーが ui-share・qa に中継済み。ShareSizes.copyWith は NaN を 1.0 にする） |
| S0〜S4 投稿の画面・シェア画像 | ui-share | 完了（最終報告受領・qa へテスト更新依頼を転送済み。懸念: 戻るボタンが PopScope をすり抜ける可能性＝qa が確認。S1b は案A で完了。11/9。S0〜S4・P2a・P2b・C1（share_edit_sheet.dart 削除）。`flutter analyze lib` 0件。share_ticket_view_test は全通過、share_page_test は旧UI前提で落ちる＝qa が書き直し。qa への「テスト更新依頼」は最終報告に載るのでリーダーが転送する） |
| U1 記録のチケットの写真の欄・ホーム | ui-record | 完了（11/9。触ったファイル: ticket_card.dart の _PhotosArea・photos_sheet.dart の説明1行。ホームは S0 で4枚になるため変更なし。analyze 0件。qa にテスト更新依頼済み。`share_ticket_view_test` の上限2件の失敗は ui-share／qa の側で対応） |
| Q1・Q2 テスト | qa | Q1 の一部完了（11/9。D1 レビュー済み＝重大・中なし。落ちていた5件は期待を更新して通過。純粋関数・share_notifier のテスト追加・通過）。残り: share_fit_test は S1b 待ち、画面系は ui-share の連絡待ち |
| Q1・Q2・R1（qa） | qa | 完了（11/9。全体 flutter test 2101件通過・skip 1件・analyze 0件。座席・記録の写真・ログ・「（デモ）」・変更範囲は問題なし。レビュー記録: notes/memory_share_v3_レビュー記録.md。ホーム4枚は `sharePhotoBytesKey` の純粋テストで代用。ルールの emulator テストは未完了の可能性） |
| バグ修正: 上のバーの戻るが未保存の確認をすり抜ける | ui-share（lib/theme に onBack を足す。ユーザー了承済み 11/9） | 依頼済み。直ったら qa が skip を外す |
| バグ修正の確認 | qa | 完了（11/9。analyze 0件・test 2102件通過・skip 0件） |
| L1 結合確認 | リーダー | 差分の範囲確認は完了（16ファイルの変更＋新規。6章の範囲＋`lib/theme/hako_app_widgets.dart` のみ追加。pubspec・rules・functions に差分なし）。残り: ユーザーの動作確認（12章）とコミットの了承 |

次にやること: ユーザーが12章の動作確認を行い、コミット案を了承したらコミット（push・PR は人間）。

時間の目安（13章の 9）: ①11/9 夜までに S1b が終わらなければ案B ②11/10 正午までに S3・S4 が終わらなければ P2 を落とす ③11/10 15時までに Q2 が終わらなければ画面のテストを絞る ④間に合わなければ `dev` に入れず今の画面のまま提出。

次にやること: D1 の契約が届くのを待ち、S0 → S1 → … の順に進める。
