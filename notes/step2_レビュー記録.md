# レビュー記録（Step2: ライブ・公演・受付の手入力登録と一覧、個人の申込状況）

qa（テスト・レビュー担当のエージェント）が、レビューやテストで見つけた問題を1行ずつ残す。横山さんのコードで見つけた問題もここに書き、リーダーがまとめてユーザーに伝える。

| 日付 | タスクID | 重さ | 内容 | 対応 |
|---|---|---|---|---|
| 2026-11-05 | 3.7（T0 後） | 中 | 横山さんのモデルの `fromFirestore` は、壊れたドキュメント1件で例外を投げる。`lib/models/live.dart:24` `title as String`（欠けている・型違いで落ちる）、`lib/models/performance.dart:35` `toDateTime(startAt)!`・`:36` `venue as String`、`lib/models/reception.dart:61` `name as String`・`:63` `toDateTime(applyEndAt)!`・`:16-17` `Price.fromMap` の `seat as String`・`amount as num`・`:68` `p as Map`。任意項目の `as String?`・`as bool?`（`officialUrl`・`liveId`・`prefecture`・`winnersOnly`）も、型が違う値なら落ちる。どれも `doc.data()!` も含めて、一覧の Stream 全体がエラーになる | 計画書 3.7 のとおり横山さんのファイルは変えない。data のリポジトリで1件ずつ例外を受け止めて飛ばす（D3 のレビューと Q2 のテストで確認する）。モデル側を落ちない形にするかは、リーダーがユーザー経由で横山さんに相談する |
| 2026-11-05 | 3.6 検証 | （情報） | getAfter の上限の検証（エミュレータ、firebase-tools 付属の Firestore エミュレータ）。対照実験: 1書き込みで別ドキュメント10回は許可・11回は拒否。バッチで、各書き込み10回以下・合計で別ドキュメント20回は許可、21回は拒否。同じ20ドキュメントを40回読んでも許可（同じドキュメントは1回と数える）。→ エミュレータは本番と同じ上限を強制している。本番想定: ライブ1＋公演50＋受付30 の1バッチで、各子が同じライブを getAfter → 許可。最後の受付だけ groupIds をライブと変えると拒否。ライブを同じバッチに含めない公演は拒否 | リーダーに報告。採用の判断はリーダー。条件: 子のルールで読むのは親ライブ1件だけにする（推しの存在確認などで get を足すと、別ドキュメントの数が増えて上限に近づく） |
| 2026-11-05 | 契約 | 中 | `LiveListEntry` が2か所にあった（data: `lib/utils/deadline.dart` の `buildLiveList`、日単位／ui: `lib/features/live/live_list_entries.dart` の `buildLiveListSections`、瞬間単位）。「終了」の判定が食い違う | リーダーが決定: data の `buildLiveList`（日単位・端末の日付）に統一。ui は出演者名の関数だけを残す。qa は `buildLiveList` のテストを `test/utils/deadline_test.dart` に書いた。`live_list_entries_test.dart` は ui の変更後に合わせる |
| 2026-11-05 | D2 | 中 | `checkLimits` に出演者（`groupIds`・`oshiIds`）の件数の上限が無い。D5 のルールで配列の件数に上限を設けると、上限を超えた入力が保存時に permission-denied になり、日本語の理由が出ない | data に送付。ルールの上限と同じ値を `LiveLimits` と `checkLimits` に足す案 |
| 2026-11-05 | D1 | 軽微 | `upcomingDeadlinesProvider`（`lib/providers/live_providers.dart`）で `byId[d.reception.liveId]` のキーが `String?` なので、ID が null のライブと liveId が null の受付が結び付きうる（Firestore から読んだ値では起きない） | data に送付。`liveId` が null の受付を先に除く案 |
| 2026-11-05 | D2 | （情報） | `_isHttpsUrl` の Dart の `\s` は全角スペースなども含み、ルールの RE2 の `\s` より厳しい。クライアントが厳しい側なので問題なし | 対応不要 |
| 2026-11-05 | U3 | 軽微 | `remainingLabel` は残りが1分未満のとき「あと0分」と出る | ui に送付。「あと1分未満」などにする案 |
| 2026-11-05 | 横山さん | 軽微 | `formatDateTime`（`lib/features/live_form/date_time_field.dart:57`）は `toLocal()` を呼ばない。UTC の DateTime を渡すと UTC のまま表示する。Firestore の `Timestamp.toDate()` はローカル時刻を返すので、いまの使い方では問題にならない | 記録のみ。呼ぶ側が UTC を渡さないこと。モデル側で直すかはリーダーから横山さんへ |
| 2026-11-05 | U3 | 中 | `liveDetailProvider`（`lib/features/live/live_detail_page.dart`）が `Provider.family`（autoDispose なし）。U6 で `liveProvider` などの autoDispose の family を watch すると、画面を離れても購読が残り、開いたライブの数だけ Firestore のリスナーが増える | ui に送付。`Provider.autoDispose.family` にする案 |
| 2026-11-05 | U3 | 中 | 公演の「（終了）」が瞬間単位（`p.startAt.isBefore(now)`）。一覧の「終了」は日単位（リーダーの決定）なので、当日の開演後に、一覧では「これから」、詳細では「終了」になる | ui に送付。日単位にそろえるかはリーダーに確認 |
| 2026-11-05 | U3 | 軽微 | 申込期限の行は、申込済・当選の後も「あと○日」「期限切れ」を出す。「次にやること」と並ぶので紛らわしい | ui に送付（任意） |
| 2026-11-05 | D3・D4 | （情報） | リポジトリに重大・中の指摘なし。Q2 のテスト46件を追加。「すべての分割がそろうまで流さない」は fake_cloud_firestore では途中の状態を作れず、最初の値がそろっていることしか確かめられない（コードを読んで確認） | 対応不要 |
| 2026-11-05 | U3 | 軽微 | `remainingLabel` の「あと0分」 | ui が「あと1分未満」に修正済み。回帰テストを `test/features/deadline_format_test.dart` に追加 |
| 2026-11-05 | U4 | （情報） | 「次の締切」に重大・中の指摘なし。ウィジェットテスト14件を追加（`test/features/upcoming_deadlines_section_test.dart`）。ホームに部品が入ったため、既存のホームのテストが本物の Firestore を見に行かないよう、`oshi_test_helpers.dart` の `overridesFor` に偽のリポジトリと固定の now を足した | 対応不要 |
| 2026-11-05 | D5 | 中 | 料金の上限がルール（10個）とクライアント（`LiveLimits.maxPricesPerReception` = 20）で違う。11〜20個の料金は、保存時に permission-denied になり、日本語の理由が出ない | ユーザーの判断（10 か 20）待ち。決まったら両方を同じ値にする。`test_rules/lives.test.js` の `MAX_PRICES` も合わせる |
| 2026-11-05 | D5 | 軽微 | 料金の `seat` は `trim().size() >= 1` だけで、全角スペースだけの席種を通す（ライブ名・会場名・受付名は `isNonBlankString` で拒否）。クライアントの validate は Dart の trim で全角スペースも除くので、アプリ経由では起きない | data に送付（式の数に余裕があれば `isNonBlankString` にそろえる。任意） |
| 2026-11-05 | D5 | （情報） | data の連絡では「出演者の ID は添字ごとに文字列かを検査」とあったが、`isValidIdList20` は件数だけを検査している（コメントは件数だけ、で一致） | data に確認を送付 |
| 2026-11-05 | Q3 | （情報） | ルールのテスト106件を追加（`lives.test.js`・`applications.test.js`）。対照の確認: 広いルールから applications の除外を外すと14件、getAfter の検査を外すと6件が失敗することを確かめた（テストが素通りを見逃さない） | 対応不要 |
| 2026-11-05 | D3 | 重大（リーダーが発見） | 複数のクエリをまとめる処理で、エラーの後もほかのクエリの購読が残り、古い結果と組み合わせた一覧が流れ続けた | data が修正済み（エラーを1回流し、すべて解除して閉じる）。回帰テスト11件を `test/repositories/live_repository_merge_test.dart` に追加（クエリごとに値・エラーを流せる偽の Firestore を使用。Query などは @sealed のため、このファイルだけ `subtype_of_sealed_class` を無視） |
| 2026-11-05 | D5 | （情報） | 料金の上限は 10個に決まった（`LiveLimits.maxPricesPerReception` = 10、ルールも10）。出演者は種類ごとに20 | テストを合わせた（`live_draft_to_models_test.dart`、`test_rules/lives.test.js` の `MAX_PRICES`） |
| 2026-11-05 | U3 | 中 | 公演の「（終了）」の判定（瞬間単位）が一覧（日単位）と食い違う | リーダーの決定で日単位にそろえた（前日まで「（終了）」、当日「（本日）」、以降なし）。`performanceDayOf` の単体テストと、詳細画面の文言のテストを追加 |
| 2026-11-05 | U5・U6 | （情報） | 保存（U5）と、一覧・詳細の本物のプロバイダへのつなぎ込み（U6）に指摘なし。Q4 のウィジェットテストを追加（`live_form_save_test.dart` 7件、`live_pages_test.dart` 24件）。U3 の中1（autoDispose）は、画面を離れるとプロバイダが破棄されることをテストで確認 | 対応不要 |
| 2026-11-05 | R1 | （監査） | `firebase-security-rules-auditor` の観点で Step2 のルールを監査。評価 4/5（重大・大きな穴なし）。更新による迂回: lives など3つは更新・削除不可、applications は作成と更新で同じ検査。権限の出どころ: `createdBy == request.auth.uid`、整合は getAfter（サーバー側の値）。本人以外の申込状況は読み書き不可（広いルールからの除外をテストと対照で確認）。型: すべて `is` で検査 | 軽微な残り3点はリーダーへ（下の3行） |
| 2026-11-05 | R1 | 軽微 | `groupIds`・`oshiIds` の要素は件数（20）だけを検査し、型・長さを見ない（ユーザー決定・案A）。1要素に大きな文字列を入れると、1ドキュメント1MiB まで膨らませられる（ストレージの浪費） | 記録のみ。Step7 のルール整備で、式の数に余裕があれば要素の長さの上限を足すか検討 |
| 2026-11-05 | R1 | 軽微 | ライブ・公演・受付の作成に回数の制限が無い。ログイン済みなら、任意の推しの ID を付けたライブを大量に作れ、その推しのフォロワー全員の一覧と「次の締切」に出る（共通データの性質。仕様どおり） | 記録のみ。Step4（誤った更新への対処）・公開前の App Check の検討で扱う |
| 2026-11-05 | R1 | 軽微 | 申込状況の `liveId` は、実在するライブか・受付の liveId と一致するかを検査しない。本人のデータだけに影響する | 対応不要（アプリが受付から liveId を付ける） |
| 2026-11-05 | D5 | （既知の差・意図的） | 全角スペースだけの席種をルールは通す件（上の軽微）について。料金10個分で式の上限（1000）に近いため、席種の検査は式を減らした形にしてある（data 回答）。アプリは validate（Dart の trim は全角も除く）で拒否する | 対応しない（data・qa 合意） |
| 2026-11-05 | D5 | （確認） | 出演者の ID は件数（各20）だけの検査が正（ユーザー決定・案A）。data の前の連絡（添字ごとの型の検査）は、外す前の内容だった | 対応不要 |
| 2026-11-05 | D6 | （情報） | `live_providers.dart` に指摘なし。テスト17件を追加（`test/providers/live_providers_test.dart`）: 未ログインで []・{}、フォローの読み込み中・エラーの伝わり方、中身が同じフォロー状態で購読し直さないこと、liveList・upcomingDeadlines のエラー・読み込み中、null の ID を結び付けないこと、申込状況での切り替え | 対応不要 |
| 2026-11-05 | 公式 URL のリンク | 軽微 | `officialLinkUri` は `https://example.com@evil.example/x` のような userinfo 付きの URL もリンクにする（開く先のホストは evil.example）。公式 URL は誰でも登録できる共通データなので、見た目の文字と開く先が違うリンクを作れる（URL 全体は表示されるので、よく見れば分かる） | ui に送付。`uri.userInfo.isNotEmpty` なら null にする案。採否はリーダー |
| 2026-11-05 | 公式 URL のリンク | 軽微 | 開いている間に連打すると、タブが複数開く | ui に送付（任意） |
| 2026-11-05 | 公式 URL のリンク | （情報） | テスト8件を追加（`test/features/official_url_link_test.dart`）: https を押すと1回・正しい Uri で開く、https 以外・空白入り・`https://` だけはリンクにしない、false と例外で SnackBar、待っている間に画面が消えても落ちない、360px | 対応不要 |
| 2026-11-05 | 公式 URL のリンク | （対応済み） | userinfo 付き URL の件: リーダーの決定で ui が修正（userInfo があれば null）。連打で複数タブの件は、下の行のとおり直す（ui の提案を採用） | 回帰テスト3件を追加（userinfo 付きは null・パスやクエリの @ は Uri のまま・画面で押しても開かない） |
| 2026-11-05 | 公式 URL のリンク | （対応済み） | 連打で複数タブの件: 直す（ui の提案を採用。リーダーの決定）。ui が開く処理の途中のタップを無視する形に修正（finally で戻す） | 回帰テスト5件を追加（途中の連打で1回だけ、開き終わった後・false の後・例外の後はまた押せる、見た目は押せるリンクのまま） |
