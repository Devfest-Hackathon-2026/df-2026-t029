# before_login_c 進捗（紹介ページ `/welcome` を「案C 改」にする）

状態: 実装・テスト完了。人の動作確認（12.1）とコミットの了承待ち

> リーダーが、タスクが1つ終わるたびに更新する（計画書 `markdown/feature_before_login_c_plan.md` の 14章）。
> 使用量の上限で止まって再開したときは、まずこのファイルを読む。終わったタスクはやり直さない。
> すべて終わったら、上の行を `状態: 完了` にする。

最終更新: 2026-11-08 R1 完了。L1 の結合確認まで済み。ユーザーの確認待ち

## 合意（2章。ユーザーの指示）

- デザインは、`markdown/design_before_login_c/` の `oshiashi_C_v3.html`（案C 改）のとおりに実装する（CSS が正。食い違い2つを直した修正版 `oshiashi_C_v3_fixed.html` を数値の基準にする。5.1）
- Dart（Flutter）で書く。JavaScript ではない
- ブランチは `redesign/before_login`（`origin/redesign/before_login` を追う。`origin/dev` より 5 コミット古い）
- チームのモデルは Sonnet 5.5（`claude-sonnet-5-5`）。`.claude/agents/*.md` の `model:` と `.claude/settings.local.json` の `model` に設定済み
- 共有の土台（`lib/theme/**`・`pubspec.yaml`・`lib/app.dart`・ログイン系）は変えない。変えてよいのは `lib/features/welcome/**` と `test/features/welcome_*` だけ

## 実装前の確認（5章。2026-11-08 確認済み。すべて案A）

| 項目 | 推奨案 | 回答 |
|---|---|---|
| 5.1 HTML の CSS の食い違い（ヘッダーの上の余白・幅 520 以下で縦の余白が 0） | 案A: 意図どおりに直した修正版を正にする | 案A（ユーザーが確認） |
| 5.2 色の値（`BrandColors` との差は最大 3/255） | 案A: `BrandColors` をそのまま使う | 案A（ユーザーが確認） |
| 5.3 書体 | 案A: BIZ UDPGothic ＋ 同梱の ArchivoHako | 案A（ユーザーが確認） |
| 5.4 コントラストの低い2か所（英字 `#777`・「申込」の札の白文字） | 案A: 直す（`#6B6B6B`・墨） | 案A（ユーザーが確認） |
| 5.5 動き（案6の「始める」の nudge） | 案A: 動きは作らない（HTML のとおり） | 案A（ユーザーが確認） |
| 5.6 日本語の折り返し（Chrome は文節、Flutter は文字の間） | 案A: Flutter の標準のまま | 案A（ユーザーが確認） |
| 5.7 文言の半角・全角（`?`・`( )`） | 案A: 全角にする | 案A（ユーザーが確認） |
| 5.8 FAQ の開き方 | 案A: 項目ごとに独立（複数開ける） | 案A（ユーザーが確認） |
| 5.9 横山さんへの共有・ブランチの追いつき | マージの前に一声かける・人間が `git merge origin/dev` | 案A（ユーザーが確認） |

- 開始時の品質ゲート: `flutter analyze` 0 件。`flutter test` は紹介ページ以外の既存テストが約 24 件落ちている（AccountMenuButton の ProviderException・BIZ UDPGothic が見つからない例外）。ユーザーの判断で「既存の失敗として進める」。ルールのテストは未実行
- Flutter はクラウドの環境に無いので、**この計画書のコードは一度もコンパイルしていない**
- 作業ツリーに、この作業と関係のない未コミットのファイルがある（`.claude/agents/*.md`・`CLAUDE.md`・`.claude/scripts/`・`markdown/design_after_login/`・`Claude outputs/`）。**触らない・コミットに混ぜない**

## タスクの状況

| ID | 担当 | 状態 | メモ（触ったファイル・次にやること） |
|---|---|---|---|
| L0 | リーダー | 完了 | 0章の確認、5章をユーザーに聞く、判断ログ |
| T0 | qa | 完了（既存の失敗 25 件を記録） | 品質ゲート、今の紹介ページのテストで変わるものの一覧 |
| W1 | ui-top | 完了 | `welcome_layout.dart`・空の入れ物2つ。契約を送る |
| W2 | ui-top | 完了（qa のテスト更新待ち） | `welcome_page.dart`: 枠・ヘッダー・最初の画面・掲示板 |
| W3 | ui-top | 完了 | CTA |
| B1 | ui-body | 完了（qa レビュー待ち） | `welcome_story.dart`: PROBLEM 01・FLOW・PROBLEM 02・SOLUTION の帯 |
| B2 | ui-body | 完了（FAQ の答えの上 8 に修正中） | `welcome_features.dart`: 6つのハコ・FAQ |
| Q1 | qa | 完了 | 共通部品のテスト |
| Q2 | qa | 完了 | 区画のテスト |
| Q3 | qa | 完了（読み上げのテストの skip 解除待ち） | 紹介ページのテストの書き直し |
| C1 | ui-top | 完了 | 掃除（旧い部品・使われない import） |
| R1 | qa | 完了（紹介ページのテスト 57 件成功・既存の失敗 25 件は増減なし） | まとめレビュー |
| L1 | リーダー | 進行中（共有の差分なしを確認。コミットはユーザーの了承待ち） | 結合確認・共有の差分が無いこと・動作確認手順・コミット案 |

## ユーザーに聞きたいこと

- （なし）
