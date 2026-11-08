# before_login_design 進捗（ログイン前の画面を案6「ハコ色」にする）

状態: 完了（コミット待ち）

> リーダーが、タスクが1つ終わるたびに更新する（計画書 `markdown/feature_before_login_design_plan.md` の 14章）。
> 使用量の上限で止まって再開したときは、まずこのファイルを読む。終わったタスクはやり直さない。
> すべて終わったら、上の行を `状態: 完了` にする。

最終更新: 2026-11-07 5章の回答済み・L0 完了。チームメイト作成へ

## 合意（2章。ユーザーの指示）

- デザインは、ユーザーが選んだ案6「ハコ色」と同じ見た目（`markdown/design_before_login/hako_案6_ハコ色.html`）
- Dart（Flutter）で書く。JavaScript ではない
- 「始める」「ログイン」を押すと、ログイン画面（次のページ）へ移る（今までと同じ）
- チームのモデルは Sonnet 5.5（`claude-sonnet-5-5`）。`.claude/agents/*.md` の `model:` と `.claude/settings.local.json` の `model` に設定済み

## 実装前の確認（5章。未確認。聞くまでチームメイトは作らない）

| 項目 | 推奨案 | 回答 |
|---|---|---|
| 5.1 「くわしく →」の行き先 | 案A: `/login?mode=signup` | **案C（消す）** |
| 5.2 新規登録のときの見出し | 「はじめまして。入口はこちら。」 | 推奨どおり |
| 5.3 書体の重さ（BIZ UDPGothic） | 方針A: そのまま `google_fonts`。実機で見て遅ければ B〜D | 推奨どおり |
| 5.4 横山さんへの共有（紹介ページ・ログイン系・brand_colors・pubspec） | マージの前に一声かける | 推奨どおり |
| 5.5 著作物利用シートに書く書体 | 人間が書く（メモはリーダーが残す） | 推奨どおり |

- 開始時の品質ゲート: analyze 0件・ルール成功。`flutter test` は `live_pages_test.dart`「ライブが増えると一覧に出る」1件が失敗（Fa-3 の変更に追いついていない。無関係）。T0 で qa が直す
- Flutter はクラウドの環境に無いので、**この計画書のコードは一度もコンパイルしていない**（Google の「G」の Path と書体ファイルだけは、元のデータと描画を比べて確かめた）

## タスクの状況

| ID | 担当 | 状態 | メモ（触ったファイル・次にやること） |
|---|---|---|---|
| L0 | リーダー | 完了 | `assets/fonts/`・`pubspec.yaml`（fonts）・pub get 済み |
| T0 | qa | 完了 | live_pages_test.dart の期待を Fa-3 の新仕様に直した（1件） |
| F1 | ui-welcome | 完了 | `brand_colors.dart`（新しい色を足す）、`hako_fonts.dart` |
| F2 | ui-welcome | 完了 | `hako_widgets.dart`。契約（7章）を ui-auth・qa に送る |
| A0 | ui-auth | 完了 | `google_logo.dart`（4.5 のコードを写す） |
| W1 | ui-welcome | 完了 | `welcome_page.dart` の作り直し |
| A1 | ui-auth | 完了 | `auth_widgets.dart` |
| A2 | ui-auth | 完了 | `login_page.dart` |
| A3 | ui-auth | 完了 | `verify_email_page.dart` |
| Q1 | qa | 完了 | 共通部品のテスト |
| Q2 | qa | 完了 | 紹介ページのテスト |
| Q3 | qa | 完了 | ログイン画面・確認待ち画面のテスト |
| C1 | ui-welcome | 完了 | 旧い色の名前・`GradientButton` などの掃除 |
| R1 | qa | 完了 | まとめレビュー |
| L1 | リーダー | 完了（コミットはユーザーの了承待ち） | 結合確認・ロジックの差分が無いこと・動作確認手順・コミット案 |

## ユーザーに聞きたいこと

- 5章の5項目（上の表。推奨案で進めてよいか）
