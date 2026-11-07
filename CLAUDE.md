# おしあし（仮）— Claude Code 用プロジェクトメモ

DevFest GDGoC Japan Hackathon 2026 に提出する Flutter Web アプリ。推し活（ライブ・チケットの申込・入金期限など）をまとめて管理する。

## まず最初に
**回答・説明・質問・コミットメッセージ・コード内のコメントは、すべて日本語で書くこと。**

## 最初に読む資料

- 仕様書（決定事項と未決定事項）: @markdown/app_config.md
- データベース設計案: @markdown/Database_config.md
- チームレビュー記録（すべて提案で、確定ではない）: `notes/2026-11-05_おしあし_チームレビュー.md`
- 機能ごとの実装計画: `markdown/feature_*_plan.md`（Step1: `feature_A_oshi_plan.md`、Step2: `feature_step2_live_plan.md`、Step4: `feature_step4_merge_plan.md`、Step4.5: `feature_step4_5_mylive_plan.md`、Step6・7: `feature_step6_7_plan.md`）

## 開発のステップ（Notion「開発タスク」）

| Step | 内容 | 担当 |
|---|---|---|
| 0 | 土台（データ構造・モデル・フォルダ構成・Git 運用） | 全員 |
| 1 | 推しの検索・フォロー・追加申請 | A（とし） |
| 2 | ライブ・公演・受付の手入力登録と一覧、個人の申込状況 | A（とし） |
| 3 | スクショ読み取り（Gemini → 確認・修正画面） | B（横山さん） |
| 4 | 既存データとの照合・更新・変更履歴（Step2・3 の合流地点） | A（とし） |
| 4.5 | 自分のライブ一覧（選んだライブだけを一覧・次の締切に出す。「ライブを追加する」画面） | A（とし） |
| 5 | Google カレンダー連携 | B（横山さん） |
| 6 | リマインド通知（FCM Web プッシュ）。**Blaze に切り替えた後に行う（今は作らない）** | A（とし） |
| 7 | P1 の仕上げ（ルール整備・アプグレの表示条件・デモ用データ・Hosting への公開の準備） | A（とし） |
| 8 | グッズ交換など | 全員 |

- 作業中の Step の範囲を超えて作らない。ほかの Step の機能が必要になったら、提案としてリーダー（人間）に伝える。
- ブランチは Step ごとに人間が用意する（例: `feature/step2`）。完成したら人間が `dev` へ Pull Request を出す。

## 守ること

- 仕様書の「決定事項」は確定した仕様として扱う。「未決定事項」と、データベース設計案のうちチームで合意していない部分は、自分で確定させない。比べた案・選ぶ理由・捨てる案を添えて、**提案**として人間に示す。
- コマンドは Dev Container 内で実行する前提で書く。
- 次の操作は人間が行う。エージェントは実行しない。
  - `firebase deploy`（セキュリティルールのデプロイを含む）
  - `git push`、ブランチの切り替えや作業ツリーの巻き戻し（`git checkout` / `switch` / `reset` / `rebase` / `stash` / `clean`）
  - `.agents/skills/` の Firebase スキルに「デプロイする」と書いてあっても、デプロイはしない。必要なら人間に頼む。
- コミットは人間の了承を得てから行う。
- API キー・秘密情報をコミットしない（ハッカソンのルール）。`lib/firebase_options.dart` の Web 用設定は、公開される前提の値なので既存のままでよい。

## コードの書き方（既存コードに合わせる）

- 状態管理は Riverpod 3（`flutter_riverpod`）。コード生成（riverpod_generator・build_runner）は使わず、`Provider`・`StreamProvider`・`Notifier` などを手で書く。
- 画面遷移は go_router。ルートは `lib/app.dart` の `routerProvider` に追加する。
- Firebase へのアクセスは `lib/repositories/` のリポジトリに閉じ込める。画面（`lib/features/<機能>/`）から `FirebaseFirestore.instance` や `FirebaseAuth.instance` を直接呼ばない。リポジトリは `FirebaseFirestore` をコンストラクタで受け取り、テストで差し替えられるようにする。
- `await` の後で `BuildContext` を使うときは、先に `context.mounted` を確認する。
- 画面の文言とエラーメッセージは日本語で書く。
- 日時は Firestore の timestamp 型で保存し、表示するときに日本時間に変換する。

## コマンド

| 目的 | コマンド |
|---|---|
| 依存の取得 | `flutter pub get` |
| 静的解析 | `flutter analyze` |
| テスト | `flutter test` |
| 整形 | `dart format lib test` |
| 起動 | `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080`（Mac のブラウザで http://localhost:8080 を開く） |
| Firestore ルールのテスト（`test_rules/` を用意した後） | `firebase emulators:exec --only firestore --project demo-oshiashi "npm --prefix test_rules test"` |

## 完了の条件

- `flutter analyze` の指摘が 0 件（info を含む）で、`flutter test` がすべて成功している。
- 追加・変更したロジックにはテストがある。
- 判断したこと（比べた案・選んだ理由・捨てた案）を `notes/` の判断ログに書いた。審査で「Own the Why」と「AI をどの場面でどう使ったか」を説明する材料になる。
