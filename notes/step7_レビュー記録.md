# レビュー記録（Step7: P1 の仕上げ）

qa（テスト・レビュー担当のエージェント）が、レビューやテストで見つけた問題と、仕様変更によるテストの書き直しを1行ずつ残す。ルールの監査の結果は `notes/step7_ルール監査.md` に書く。横山さんのコードで見つけた問題もここに書き、リーダーがまとめてユーザーに伝える。

| 日付 | タスクID | 重さ | 内容 | 対応 |
|---|---|---|---|---|
| 2026-11-06 | Q2 | 情報 | ルール監査: 重大 0・中 4・軽微 8（詳細は notes/step7_ルール監査.md） | リーダーに報告済み。ルールは変えない |
| 2026-11-06 | Q3 | 情報 | 横山さんのコレクションのルールのテストを追加（goods 23・trade_posts 28・chats 20 件）。中・軽微の動き（variants の書き換えなど）は固めていない | ルール全体 316 件成功 |
| 2026-11-06 | D2 | 情報 | レビュー: winners_only・deadline・live_providers は契約どおり。重大・中なし | OK |
| 2026-11-06 | D4 | 軽微 | main.dart: 本番ビルドでサイトキーを渡し忘れても気づけない（debugPrint のみ） | markdown/deploy_手順.md の 1.1（--dart-define）と3章の10（App Check の確認）に書いてある。R1 で確認済み |
| 2026-11-06 | U3・U4 | 情報 | firebase.json・manifest.json は有効な JSON、emulators は不変。末尾の "**/!(*.*)" は "/" と重なるが害なし。U4 はユーザーの判断で「バッジを visibility:hidden で隠し、ログイン画面に規約の文言とリンクを出す」に変更になり、左下の固定 UI と重なる指摘は不要 | login_page_test（文言・リンクの URL・360px）で確認済み |
| 2026-11-06 | Q1 | 情報 | 仕様変更（winnersOnly を当選者だけに絞る）で落ちた4件（live_pages 2・upcoming_deadlines_section 2）は、当選の申込状況を入れる形に書き直した（期待は弱めていない） | 完了 |
| 2026-11-06 | Q1 | 情報 | 新規テスト: winners_only_test・deadline の winnerLiveIds・winnerLiveIds／次の締切／visibleReceptionsOfLiveProvider・ライブ詳細（隠した件数・当選後に出る）・次の締切・calendar_add_sheet_test（U2 の4件） | flutter analyze 0件、flutter test 834件成功 |
| 2026-11-06 | D3 | 情報 | インデックスの表をレビュー: lib/ の orderBy 5か所と where の組み合わせを突き合わせ、漏れなし。複合5つは firestore.indexes.json にある | OK |
| 2026-11-06 | D5 | 情報 | デモ用データをレビュー・テスト: ルールの検査を満たす（ふつうのユーザーが lives・performances・receptions を更新できる）、fromFirestore で全件読める（test/fixtures/demo_data.json は基準日 2026-11-05 の固定のスナップショット。demo_data.mjs を変えたら README の手順で作り直す）。重大・中なし | test_rules/demo_data.test.js・test/repositories/demo_data_test.dart を追加 |
| 2026-11-06 | U 追補 | 情報 | ログイン画面の reCAPTCHA の文言とリンク（login_page_test 3件）、カレンダー追加シートのラベル（calendar_add_sheet_test）を追加。リンクは onTap を直接呼ぶ（テスト用フォントでタップ位置の特定が不安定なため） | 問題なし |
| 2026-11-06 | R1 | 情報 | データ層のまとめレビュー（D2〜D5）: 当選者のみの判定は isReceptionVisible の1か所で、次の締切・ライブ詳細・カレンダー追加シートがこれを使う。差分の確認・編集は receptionsOfLiveProvider（絞らない）のまま。App Check はキーがコードに無く、デバッグ用は kDebugMode のみ、initializeApp の後で authStateChanges の前。デモ用データは架空の名前・ID が demo- 固定・基準日からの相対・履歴まで消える。秘密情報の grep は0件 | 重大・中なし |
| 2026-11-06 | R2 | 軽微 | 画面・公開設定のレビュー（U1〜U4）: Hosting の書き換え（** → /index.html）とキャッシュ設定は妥当。「n 件あります」は hiddenCount と一致（テスト済み）。軽微: バッジを隠すので、規約の文言はバッジが出る全画面に要るが、今はログイン画面だけ（Google の規約上は「バッジを隠す場合は文言を目立つ形で出す」）。ユーザー決定済みの範囲として記録。login_page.dart が live/official_url_link.dart の urlLauncherProvider を使っている（機能をまたぐ import。読みやすさの軽微な点） | 対応不要（公開前にユーザーが判断） |
| 2026-11-06 | R1 | 軽微 | test/fixtures/demo_data.json が demo_data.mjs とずれても気づけなかった（作り方の説明のみ） | test_rules/demo_data.test.js に、fixture と buildDemoData('2026-11-05') の一致を確かめるテストを追加（ずれたら作り直す手順をエラーで示す）。ルールのテスト 322件 |
