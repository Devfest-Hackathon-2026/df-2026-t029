# 進捗: メモリーの統合（redesign/memory）

計画書: `markdown/feature_memory_ticket_plan.md`。判断ログ: `notes/判断ログ_memory_ticket.md`。

## 前提（2026-11-08）
- 5章は回答済み（5.10 は「記録する」で作る・一覧の「参戦済み」の見出しの下の説明を0件のとき置き換え。ほかは推奨案）。
- Gemini は案A（Blaze に切り替え。人間が行う）。切り替わるまで本物の Gemini は呼ばない。
- 品質ゲート: `flutter analyze` 0件、`flutter test` 1525件成功（開始時）。
- 未確認（人間）: Photos Picker API の有効化・テストユーザー・Blaze への切り替え（G0 までに）。

## チームメイト（Sonnet 5.5。リーダーは Opus 5.5）
| 名前 | 状態 | 担当タスク |
|---|---|---|
| photos-data | D1〜D5 すべて完了（11/8） | D1 → D3 → D2 → D4 → D5 |
| ui-record | U1・G0・U2・U3・U4（P2）完了。ホームの写真の差し替えだけ待ち | U1 → G0 → U2 → U3 → U4 |
| ui-share | S1 完了。S2 実施中（写真の入口は `showPhotosSheet`） | S1 → S2 |
| qa | 起動（11/8） | T0・準備 → Q1〜Q3 → R1 |

## 次にやること
- 各チームメイトの報告を受け、食い違いを調整する。
- G0（人間が 12.1 の 5〜6）は、D3 と `/photos-test` が揃い、Blaze に切り替わってから。
- 時間の管理: 11/9 昼までに U2・S2 が終わっていなければ P2 を落とす。

## G0 の結果
（未実施）

## 記録
- S1 完了（ui-share）: `share_ticket_view.dart`・`memory_share_screen.dart`（空）・`file_download*.dart`・`pubspec.yaml`（`web: ^1.1.1` の1行）。analyze 指摘0件。ui-record にインターフェースを共有済み。
- 注意: Storage の写真を http で取る方式は CORS（5.17 ④）に当たる可能性。通らなければ人間が gsutil cors（12.0 の 7）。
- D1・D3 完了（photos-data）。`markPosted` を `MemoryRepository` に追加済み（qa の偽物に `@override` 付与済み）。
- Q1 完了（qa）: `test/utils/memory_ticket_test.dart`・`share_ticket_test.dart`・`google_photos_errors_test.dart`、`test/services/google_photos_service_test.dart`。`flutter test test/utils test/services` 391件成功。
- 品質ゲートは、ui-record の lib が未作成の D4・D5（`photo_pick_ai.dart`・`photo_pick_providers.dart`）を import しているため、全体は通らない（D4・D5 待ち）。
- D1〜D5 完了（photos-data）。契約からの変更12点は photos-data の最終報告のとおり（セッション削除は「決定」の取り直しのあと。G0 で確認）。`git diff --stat` は6章の範囲内。
- 写真の入口は `showPhotosSheet(context, memory:)`（`lib/features/photos/photos_sheet.dart`）。`app.dart` に投稿画面のルートと `/photos-test` を追加済み（ui-record）。
- 判断ログ用: `markPosted` は合図の前に一度足され、戻して合図後に再度足した（順序違反は実害なし）。
- U1・G0・U2・U3・U4 完了（ui-record）。U4 の新キー: `memory_list_recent_card`・`memory_publish_switch`・`memory_publish_seat_switch`（qa に Q3 で伝える）。`app.dart` の差分は17行の追加のみ。
- 全体 analyze の残り: ui-share の `share_edit_sheet.dart`（`TicketFieldText` の import 漏れ）と `share_providers_ui.dart`（不要 import）。S2 の作業中。
- 残り: S2（ui-share）、Q2・Q3（qa）、ホームのカードの写真の差し替え、C1 掃除、R1 レビュー、L1。
- S2 完了（ui-share）。qa の R1: 重大1・中2・軽微1 は修正済みで確認済み。toggle は 4.6 を正（手直しを残す）。担当外の整形差分（lib/utils の10ファイル）は photos-data が戻した。
- 11/8 時点: `flutter analyze` 0件、`flutter test` 1911件成功、ルールのテスト 322件成功。`git diff --stat` は6章の範囲内（firestore.rules・storage.rules・functions・カレンダー・gemini_service に差分なし。pubspec は web の1行）。
- `markdown/deploy_手順.md` に 2.10「Google フォト連携」を追記（リーダーの編集範囲）。
- 残り: 実機の動作確認（G0・12.1。人間）、S3（P2）は作らない方向（ユーザー回答待ち）、コミット案（ユーザーの了承待ち）。
- 実機: 記録のチケット画面は OK（ユーザー確認 11/8）。S3（P2）は作ることになり ui-share が実施中（11/8）。
- S3 完了（ui-share）。コラージュ・X 横長のはみ出しも修正済み。qa の最終確認（11/8）: `flutter analyze` 0件、`flutter test` 2040件成功（skip 0）、ルールのテスト 322件成功。実機の確認（12.1）待ち。
- コラージュ廃止・背景7色（11/8 ユーザー指示）完了。qa 最終確認: `flutter analyze` 0件、`flutter test` 2013件成功、ルールのテスト 322件成功。実機の確認待ち。
