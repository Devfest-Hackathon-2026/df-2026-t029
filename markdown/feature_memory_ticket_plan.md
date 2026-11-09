# 計画書: メモリーの統合（チケットを直接タップして直す＋SNS投稿用のチケット画像＋Google フォト＋Gemini の写真えらび。案3。redesign/memory）

> 担当の作業を、Claude Code の agent team（リーダー＋チームメイト4人＝**5エージェント。モデルは Sonnet 5.5**）で実装するための指示書（仕様書を兼ねる）。人間とエージェントの両方が読む。
> 4章はユーザーが渡したデザイン（`おしあし_メモリー統合_案3_チケットを直接タップ.html`）を Dart（Flutter）で再現するための仕様。「5. 実装前に確かめること」だけが、リーダーがユーザーに聞く項目（どれも推奨案つき）。
> **この計画書のコードは、Flutter がクラウドの環境に無いため、一度もコンパイルしていない。** 写すときは `flutter analyze` で確かめる。
> 書き方は `markdown/feature_add_mail_plan.md`・`markdown/feature_after_login_help_plan.md` に合わせた。章の番号も同じ並びにしてある。
> **Google フォトの API の細かい仕様（JSON の形・上限・スコープの扱い）は、公式ドキュメントで一部しか確かめられていない。** 「要確認」と書いた箇所は、G0（技術の確認）で実機で確かめてから実装する。

## 0. 作業ブランチと前提

- **作業ブランチは `redesign/memory`**（2026-11-08 時点でユーザーが作成・切り替え済み）。ブランチの作成・切り替え・pull・push・マージは人間が行う。エージェントはブランチを切り替えない。
- 完成したら、人間が `redesign/memory` から、マージ先のブランチ（ふだんは `dev`。ユーザーに確かめる）へ Pull Request を出す。PR の前に、人間が `git merge origin/dev` で追いつく。
- 開始前に、リーダーは `git status -sb` で `redesign/memory` にいることを確かめ、`origin/dev` から大きく遅れていないか（`git log --oneline HEAD..origin/dev | head` で件数）をユーザーに報告する。**ブランチが違えば、切り替えるようユーザーに頼む（エージェントは切り替えない）。**
- **前提（実装済み）**:
  - メモリー（M-1〜M-5・add_K）: `lib/features/memory/**`、`users/{uid}/memories/{performanceId}`（座席・セトリ・感想・写真 8枚まで・公開・座席の公開）、公開の写し `publicMemories`。
  - 写真の部品: `lib/utils/photo_picker.dart`（`PickedPhoto`・`pickPhotos`）、`lib/features/common/photo_items.dart`（`PhotoItem`・`NewPhoto`・`uploadNewPhotos`・`PhotoEditSection`）、`lib/repositories/photo_repository.dart`。
  - **Google カレンダー連携**（`lib/services/google_calendar_service.dart`・`lib/features/calendar/calendar_add_sheet.dart`・`/calendar-test`）: **Google フォトの認可は、これと同じ要領で作る**（4.4）。
  - **Gemini**（`lib/services/gemini_service.dart`。`firebase_ai`・`FirebaseAI.googleAI()`・`gemini-3.5-flash-lite`・JSON のスキーマ・失敗時の再試行）: **写真えらびも、同じ作りで別のファイルに作る**（4.5）。
  - ハコ色のデザイン（`lib/theme/**`）、ヘルプシート（`lib/features/help/help_sheet.dart`。ボトムシートの作りの手本）。
- **Dart（Flutter）で書く。** JavaScript・HTML で画面を作らない。見本の HTML は見た目の見本で、アプリには入れない。
- Firebase は今のまま。**デプロイ（`firebase deploy`）・`git push` はしない。** 推奨案では、`firestore.rules`・`storage.rules`・関数・索引の変更は無い（記録に `postedAt` を足すが、既存のルールで通る。5.11）。
- 締切: 提出は **11/10 19:00**（`markdown/add/add_K.md` より）。今日は 11/8。**間に合わなければ、1章の P2 から落とす**。途中の状態を `dev` に入れない。

## 1. 範囲

**優先度（提案。間に合わないときは P2 から落とす）**

| 優先度 | 内容 |
|---|---|
| P1 | ① 記録の画面をチケット風にし、座席・セトリ・感想・写真をタップしてその場で直せる（R1）。② Google フォトとつなぐ（カレンダーと同じ要領の認可。同意の説明つき）（R2）。③ 利用者が Google フォトで選んだ候補から、Gemini が写真を選ぶ（R3）。④ 「まとめて編集して投稿」の画面: X／Instagram の切り替え、画像・文章にのせる部分の選択、投稿の文章、X の投稿画面を開く・Instagram の3ステップ（R4）。⑤ チケットの形のシェア画像を作って保存する（デザイン「チケット」・既定の形）（R5）。⑥ ホームの「ライブお疲れさまでした」カード（R6） |
| P2 | デザイン「写真メイン」（「コラージュ」は作らない。ユーザー指示 11/8）、背景色（7色。黒はなし）、ほかの画像の形（X の正方形・Instagram のストーリー 9:16）、「選ばなかった写真と理由」の一覧、メモリー一覧の「新しい記録」のカード、記録の画面の「公開」スイッチ（既存の編集画面でも変えられる）（R7） |

**作るもの**

1. 記録の画面（`/memories/:performanceId`）を、チケット風に作り替える。座席（半券）・セトリ・感想・写真をタップすると、その場で直せる。直したものは、すぐ保存する。
2. Google フォトの認可と、写真の選択（Picker API）。`GooglePhotosService`（カレンダーの `GoogleCalendarService` と同じ作りの認可）。
3. Gemini の写真えらび（`PhotoPickAi`）。選んだ写真・ほかの候補・選ばなかった写真と理由を返す。
4. 「まとめて編集して投稿」の画面（`/memories/:performanceId/share`）。
5. シェア画像（チケット）を、画面の部品として描き、PNG にして保存する（端末の中だけで作る。5.7）。
6. 投稿の文章を組み立てる純粋関数（**座席は、画像にも文章にも絶対に出さない**）。
7. ホームのカードと、記録に付ける `postedAt`（投稿した印）。
8. 純粋関数・サービス・状態・画面のテスト（8章）。

**作らないもの**

- Google フォトの Library API（2025年3月31日から、第三者のアプリは自分で作った写真しか読めない。公式の変更履歴で確認済み。5.1）。**「公演の日時と会場の近くで撮った写真を、おしあしが自動で候補にする」は作れない**（4.0）。
- Cloud Functions・外部サービス・`firestore.rules`・`storage.rules` の変更・インデックスの追加
- Instagram・X への**自動投稿**（API は使わない。X は投稿画面を開くだけ、Instagram は3ステップ）
- 画像のサーバー生成（5.7）・写真の位置情報の利用・顔の識別
- 記録の勝手な自動作成（「記録する」ボタンを押したときだけ作る。5.10）
- 見本にだけあって、本番に出さないもの: 右の説明の枠（`.notes`）、スマホの枠、上の「表示を切り替え」（案1・2・3、Google フォト 連携済み／未連携、予約の座席情報 あり／なし）、`PH`（試し用の9枚の SVG の写真）・`LIVE`（試しのライブ）、「このデモでは省略しています」のトースト
- メモリーの共有（add_K）の仕組みの変更。メモリーの編集フォーム（`memory_form_page.dart`）の作り替え（残す。5.15）

## 2. 決まっていること（ユーザーの指示）

| 項目 | 決定 |
|---|---|
| デザイン | ユーザーが渡した `おしあし_メモリー統合_案3_チケットを直接タップ.html`（案3）。見本は `markdown/design_memory_ticket/oshiashi_memory_3_tap_ticket.html`（元のファイルを、ファイル名だけ変えて置いた）。見本の JS の中の `VARIANT==='3'` の分岐だけを使う |
| Google フォト | 使うときに必要な「権利関係」（OAuth の権限・同意・Cloud Console の設定）は、**Google カレンダーと同じ要領**で実装する（4.4） |
| 写真えらび | **Gemini がやる**（4.5） |
| 言語 | Dart（Flutter）。JavaScript ではない |
| 作業ブランチ | `redesign/memory` |
| 実装のしかた | Claude Code の agent team。**最低3人のチームメイト**（この計画書は4人: photos-data・ui-record・ui-share・qa）＋リーダー。この計画書が指示書 |
| チームのモデル | **チームメイト4人は Sonnet 5.5（`claude-sonnet-5-5`）、リーダー（メインセッション）だけ Opus 5.5（`claude-opus-5-5`）**（ユーザー指示 11/8）。`.claude/agents/*.md` の `model:` の有無を、起動時に確かめる（13章の 0） |
| 記録の作り方（5.10 の回答） | **利用者が「記録する」を押したときに記録が作られる**（勝手な自動作成はしない）。見本のとおり、メモリー一覧の「参戦済み」の見出しの下に、説明文「参戦が終わったライブは、「記録する」を押すと、チケット風の記録が作られます。」を出す（見本の `.sec-d`。4.0 の表） |

## 3. 現状のコード（調べたこと）

| 項目 | 今の状態 | 場所 |
|---|---|---|
| 記録のモデル | `LiveMemory`: `performanceId`・`liveId`・`liveTitle`・`startAt`・`venue`・`seat`・`setlist`（文字列の一覧）・`impression`・`images`（Storage のパス。1枚目が表紙）・`isPublic`・`publicSeat`・`createdAt`・`updatedAt`。`copyWithContent(...)`。**アーティスト名の項目は無い**（`Live` は `groupIds`・`oshiIds` を持つ。名前は `allOshisProvider` の `OshiSummary.name` で引く） | `lib/models/live_memory.dart`・`live.dart`・`oshi.dart` |
| 記録の取得 | `myMemoriesProvider`（自分の記録すべての購読）・`memoryProvider(performanceId)`・`memoryAlbumProvider`・`nowProvider`（1分ごと） | `lib/providers/memory_providers.dart`・`live_providers.dart` |
| 記録の保存 | `MemoryRepository`: `create`・`update`（座席・セトリ・感想・写真・公開・`updatedAt`）・`delete`。`update` は `seat`・`impression` が null なら項目を消す | `lib/repositories/memory_repository.dart` |
| 記録の画面 | 詳細 `MemoryDetailPage`（読むだけ＋「編集」ボタン）、フォーム `MemoryFormPage`（作成・編集。写真の追加・並び・保存・公開の写しの更新 `_syncPublic`・削除）。保存の順は「新しい写真をアップロード → 記録を保存 → 公開の写し → 外した写真を消す」。**`_syncPublic` は `_MemoryFormState` の中の private なメソッド**（そのままでは使い回せない） | `lib/features/memory/memory_detail_page.dart`・`memory_form_page.dart` |
| 写真の部品 | `PickedPhoto(bytes, contentType, extension)`、`maxPhotosPerItem = 8`、`photoMaxSide = 1600`、`maxPhotoBytes = 5MB`、`uploadNewPhotos`、`photoPathsOf`、`PhotoGrid`、`StorageImage`（`Image.network` で表示） | `lib/utils/photo_picker.dart`・`lib/features/common/` |
| Storage のルール | `users/{uid}/memories/{performanceId}/{file}`: 本人が作成（5MB 未満の jpeg/png/webp/gif）・削除。読むのは本人か、公開メモリーがあるとき | `storage.rules` |
| カレンダー連携の認可（手本） | `GoogleCalendarService._accessToken()`: ① メモリー上のトークンが有効（50分）ならそれを返す ② 未ログインなら `StateError` ③ ログイン方法に `google.com` があれば `user.reauthenticateWithPopup(GoogleAuthProvider()..addScope(scope)..setCustomParameters({'login_hint': user.email}))`（`user-mismatch` は「ログイン中のアカウント（…）を選んでください」） ④ 無ければ `user.linkWithPopup(...)`（`credential-already-in-use`・`email-already-in-use` は「別のおしあしのアカウントで使われています」。`provider-already-linked` は再認証） ⑤ `result.credential?.accessToken` を保存。**「ボタンを押した処理の中で最初に呼ぶ」**（ポップアップを止められないため）。呼び出し側は `http` で REST を叩き、`Authorization: Bearer` を付ける | `lib/services/google_calendar_service.dart` |
| カレンダーのシート（手本） | `showCalendarAddSheet`: `showModalBottomSheet`・処理中は `_adding`・エラーは `'$e'` を赤で出す（**この計画書では、例外の文字列をそのまま出さず、日本語の文言にする**）。接続テストの画面 `/calendar-test` がある | `lib/features/calendar/` |
| Gemini（手本） | `GeminiService`: `FirebaseAI.googleAI().generativeModel(model: 'gemini-3.5-flash-lite', generationConfig: GenerationConfig(responseMimeType: 'application/json', responseSchema: …))`、画像は `InlineDataPart(mimeType, bytes)`、`_withRetry`（最大3回・60秒でタイムアウト）、`geminiServiceProvider` | `lib/services/gemini_service.dart` |
| ホーム | `HomePage` に `HomeRecentMemories`（参戦済みの記録の横並び）などの区画 | `lib/features/home/` |
| ルート | `/memories`（一覧）の下に `:performanceId`（詳細）・`:performanceId/edit`（編集）。`/lives/:liveId/memory/:performanceId`（作成）。`/calendar-test` | `lib/app.dart` |
| 依存パッケージ | `http`・`url_launcher`・`image_picker`・`firebase_ai`・`firebase_storage` など。**`web`・`share_plus` などは無い** | `pubspec.yaml` |
| Google フォトの設定 | **何も無い**（`photospicker` の語がコードにも `web/` にも無い） | — |
| 運用の記録 | カレンダー連携は「テストユーザーのみ」で運用している（公開ステータスがテストの間は、登録したアカウントしか許可できない） | `markdown/deploy_手順.md` 2.2 |
| テストの偽物 | メモリーのリポジトリの偽物・写真のリポジトリの偽物などは手書き（`test/features/photo_test_helpers.dart`・`public_memory_test_helpers.dart`）。**`MemoryRepository` にメソッドを足すと、偽物がコンパイルできなくなる**ので、qa が同時に直す | `test/features/` |
| 品質ゲート | `.claude/hooks/quality-gate.sh`（`flutter analyze`・`flutter test`・ルールのテスト）。タスクを完了にするたびに動く | `.claude/hooks/` |

## 4. 仕様（デザイン）

### 4.0 見本の読み方

見本の HTML は **試し用のデータと、見本だけの切り替え**を含む。**本番に入れてよいのは、見た目・並び・文言・動き**だけ。次の表のとおり、見本から変える箇所がある（**本物のデータ・本物の API に合わせるため**）。

| 見本 | 本番 | 理由 |
|---|---|---|
| 「Googleフォトとつなぐと、写真を自動で選べます」「公演の日時と会場の近くで撮った写真だけを、おしあしが候補にします」 | **「Googleフォトの画面で、公演の日に撮った写真をまとめて選ぶと、その中から、おしあしがいい写真を選びます」**（4.3）。利用者が Google の選択画面で候補を選ぶ → Gemini が選ぶ | Google フォトの Library API は2025年3月31日から、第三者のアプリが利用者の写真全体を読む・検索することができない（公式の変更履歴）。使えるのは Picker API だけで、**利用者が Google の画面で選んだ写真**しか渡されない。**位置情報も使えない**（公式の説明に location の項目が無い。要確認 G0）ので、「会場の近く」では絞れない |
| 「予約情報から自動入力」の札（座席） | 座席が入っていれば、説明の文だけ「参戦予定に登録した座席です。違っていれば書き換えられます。」。札は出さない | 本物のデータには「予約から入れた」という印が無い（参戦予定の記録に利用者が入れた座席） |
| 「下書き（自動作成）」の札・「保存して完成」ボタン・「NEW」 | **出さない。** 札は「参戦済み」「参戦予定」だけ（既存どおり）。直したものは、決定するたびに保存する | 記録は「記録する」で作った時点で保存されている（5.10）。「完成」の状態は持たない |
| 「Googleフォト 連携済み／未連携」（見本の切り替え） | 「つないでいる」＝このブラウザのタブの中で認可の権限（トークン）を持っている間。**画面を開き直すと、また押したときにポップアップが出る**（カレンダーと同じ。4.4） | トークンを保存しない（5.4） |
| 写真の自動えらびが、画面を開くと始まる | **利用者がボタンを押したときだけ始まる** | ポップアップは、ボタンを押した処理の中でないとブラウザに止められる（カレンダーと同じ）。写真は利用者のものなので、勝手に読まない |
| 「選んでいます…」のスピナー（1.3秒の試し） | 本物の待ち（認可 → 選択画面 → 縮小版の取得 → Gemini）。段階ごとに文を変える（4.11） | 本物は数秒〜数十秒かかる |
| `PH`（9枚の SVG の写真）・`LIVE` | 本物の記録（`LiveMemory`）・本物の写真（Storage の `images`／Google フォトから選んだ写真） | 試し用 |
| 画像の保存・「文章をコピー」が「（デモ）」 | 本物のダウンロード・クリップボード | 試し用 |
| 画面の `st.sel`（選んだ写真の ID） | 保存済みの写真（`SavedPhoto`）＋新しい写真（`NewPhoto`）の並び（`PhotoItem`）。1枚目が表紙 | 既存の部品に合わせる |
| 見本のフォント（端末の書体）・`font-weight:800` | `HakoFonts.jp(...)`。**太さは 400 と 700 だけ**なので、800・900 は **700** にする | 書体ファイルを足さない（既存の約束） |
| 見本の `🙂` のような絵文字・SVG のアイコン | Flutter の `Icons.*`（見本の SVG に近いもの） | 画像を足さない |
| 見本の説明文「参戦が終わったライブは、チケット風の記録が自動で作られます。」（参戦済みの見出しの下。`.sec-d`） | **同じ場所（メモリー一覧 `memory_list_page.dart` の「参戦済み」の見出しの下）に**「参戦が終わったライブは、「記録する」を押すと、チケット風の記録が作られます。」を出す（`muted`・小さい字。見本の `.sec-d` の見た目）。見本は「保存済みのとき」は隠す。本番は、**参戦済みの記録が0件のときだけ**出し、既存の見出しの下の説明「行ったライブの思い出です。」（`hint_memory_done`）を**置き換える**（重ねない）。1件以上あるときは、既存の説明のまま | 公演の特定が曖昧なので、勝手には作らない |
| 見本の `window.open(...)` | `url_launcher` の `launchUrl(..., webOnlyWindowName: '_blank')` | Flutter |

**見本の見た目の数値（余白・角丸・枠・色）は、見本の CSS（`<style>` の中）を正とする。** この計画書の数値は要約。色は既存の `BrandColors` を使い、無い色（AI の薄紫 `#EADCFF`・`#F3EAFF`）だけ、`lib/features/memory/ticket/` の中の定数にする。

### 4.1 要件の一覧

| ID | 優先 | 要件 | 担当 |
|---|---|---|---|
| R1 | P1 | 記録の画面がチケット風になり、座席・セトリ・感想・写真をタップしてその場で直せる。決定したら、すぐ保存する | ui-record |
| R2 | P1 | Google フォトの認可（カレンダーと同じ要領）・同意の説明・つなぐ／選び直す／やめる | photos-data・ui-record |
| R3 | P1 | Gemini が、利用者の選んだ候補から写真を選ぶ（選んだ写真・ほかの候補・選ばなかった理由） | photos-data・ui-record |
| R4 | P1 | 「まとめて編集して投稿」の画面（X／Instagram・のせる部分・文章・投稿の動作） | ui-share・photos-data |
| R5 | P1 | チケットのシェア画像を描き、PNG で保存する | ui-share |
| R6 | P1 | ホームの「ライブお疲れさまでした」カード（ミニのチケット付き）。`postedAt` | ui-record・photos-data |
| R7 | P2 | 他の2つのデザイン・背景色・他の画像の形・選ばなかった写真の一覧・一覧の「新しい記録」・公開スイッチ | ui-share・ui-record |

### 4.2 記録の画面（R1。`/memories/:performanceId`）

既存の `MemoryDetailPage` を、見本の `recordC()`（記録ページ）の見た目に作り替える。**既存の `MemoryFormPage`（作成・編集・削除）は残す**（5.15）。

**上のバー**: 「戻る」と「記録」（既存の `HakoPageScaffold`。`showBack: true`、`backFallback: '/memories'`）。AppBar の「編集」は、フォーム（`/memories/:performanceId/edit`）へ移る入口として**残す**（削除・公開の設定をここで変えられるように）。

**チケット**（`.ticket`。枠 2px・角丸 16・影 `5px 5px 0` の墨色・白地）:

1. 写真の欄（`.tphotos`。高さ 210・2:1 の2列で、左の1枚が縦に2段ぶち抜き・すき間 2px・下の線 2px）。`images` の先頭から**最大3枚**。3枚に足りないところは `#d8d2bf` の色の枠。0枚のときは、高さ 120 の緑（`green-s`）の枠に「写真はまだありません」＋ボタン（Google フォトにつないでいなければ「Googleフォトとつなぐ」、つないでいれば「写真を追加」）。**写真の欄は全体がボタン**（タップで「写真を直す」シート。4.3）。最小 44px。
2. 本文（余白 14/16）: 札（`参戦済み`／`参戦予定`。既存の `HakoTagChip`）→ ライブ名（19・太さ 700・行の高さ 1.4）→ 日時（カレンダーのアイコン）・会場（ピンのアイコン）（13・`muted`・行の高さ 1.6）。日時は `formatDateTime(startAt)`＋「開演」（既存の詳細と同じ）。
3. ミシン目（`.perf`）: 破線 2.5px。左右の端に直径 24 の半円の切り欠き（背景色で塗り、2px の枠。左に -14、右に -14、上に -13）。
4. 半券（`.stub`。地は `green-s`・余白 12/16）: 「SEAT / 座席」（11・700・字間 .08em）→ 座席（17・700。無ければ「未入力」）。右に小さな「直す」ボタン（`out` `sm`。ペンのアイコン。**ラベル「座席を直す」**）。

**チケットの下**（上に 18 あけ・縦に 12 ずつ）: セトリ・感想の2つの枠（`.blank`。破線 2px・角丸 12・最小の高さ 96・白地）。

- 空: ペンのアイコン＋「セトリを書く」／「感想を書く」（14・700）＋ヒント（4.11）。
- 入っている: 見出し（「セトリ」「感想」）＋「直す」の札（ペン・白地）＋中身。セトリは1行1曲（番号付き）、感想は全文。
- 枠全体がボタン。タップすると、**その枠の下に、その場の編集カード**（`#inlineEdit`。枠 2px・影 `4px 4px 0`・角丸 `card`）が開く。座席も同じ（座席は1行の入力欄）。カードは「○○を書く」の見出し・入力欄・緑の「決定」ボタン。開いたら入力欄にフォーカスし、画面をカードまでスクロールする。**同時に開くカードは1つ**（別の枠を押すと、開いているものは閉じる。入力中の文字は、閉じるときに捨てる）。

**保存**: 「決定」を押すと、`MemoryEditor.saveFields(...)`（7章）で**すぐ保存**する（成功したらカードを閉じ、チケットが新しい値になる。失敗したら SnackBar「保存できませんでした。もう一度お試しください」を出し、カードは開いたまま・入力は残す）。保存中は「決定」を押せなくする。座席・感想の前後の空白は除き、空なら項目を消す。セトリは1行1曲・空行は捨てる。上限は既存どおり（座席 100 文字・感想 2000 文字・セトリ 100 曲・1曲 100 文字。`memory_form_page.dart` の定数を使う）。超えたら、カードの中に赤い文で出し、決定を押せなくする。

**補足の行**: 「座席は、この記録だけに表示されます。SNSの画像と文章には出ません。」（`info` のアイコン付き）。座席が入っていれば、座席の欄の下に「参戦予定に登録した座席です。違っていれば書き換えられます。」。

**進み具合**: 「n/4 入力済み」（写真1枚以上・座席・セトリ・感想の4つのうち、入っている数）。バー（高さ 10・枠 2px・角丸 6・中は緑・幅は n×25%・動き .3s）。`memoryProgress(memory)`（7章）で数える。

**公開**（P2。R7）: 見本の `pubBlock()`。「同じ推しのファンに公開する」（スイッチ）・「座席も公開する」（上がオフのときは無効・薄く）。**文言・動きは、既存のフォーム（`memory_form_page.dart`）の公開の欄と同じにする**（見本と違えば、既存を優先）。スイッチを動かすと `MemoryEditor.setPublic(...)` で保存し、公開の写しを書き換える。P2 に落とすときは、この区画を出さない（フォームで変えられる）。

**下の固定のバー**（見本の `.stick`）: **参戦済みの記録だけ**に、既存の `HakoSaveBar`（なければ同じ見た目）で「まとめて編集して投稿」（`dark`・共有のアイコン）を出す。押すと `/memories/:performanceId/share`（4.6）へ移る（`push`。戻ると記録に戻る）。参戦予定の記録には出さない。

**4状態**: 読み込み中（中央の `CircularProgressIndicator`）・記録なし（`HakoEmpty('この記録は見つかりませんでした')`。既存のキーを残す）・エラー（`HakoEmpty('記録を読み込めませんでした')`）・表示。

### 4.3 写真の欄と「写真を直す」シート（R1・R2・R3）

記録の画面の写真の欄・投稿の画面のチケットの写真・「写真」のチップのペン（4.6）のどれを押しても、同じ**「写真を直す」シート**（`ボトムシート`。作りは `help_sheet.dart` と同じ: つまみ・角丸 22・2px の墨の枠・PC は最大幅 640・Esc で閉じる・`disableAnimations` なら動かさない）が開く。見出し「写真を直す」・右に「とじる」（×）。中身は見本の `photosBlock()`。最後に緑の「決定」ボタン。

**状態（上から判定する）**

| 状態 | 見た目 |
|---|---|
| ① つないでいない、かつ写真が0枚 | 破線の枠（`.connect`・2px の破線・角丸 14・白地・中央そろえ）: 見出し「Googleフォトとつなぐと、おしあしが写真を選びます」（15・700）・説明・緑の小さなボタン「Googleフォトとつなぐ」（カメラのアイコン）・リンク「つながずに、写真を自分で追加する」（既存の `pickNewPhotos`。端末から選ぶ） |
| ② 処理中（認可・選択・取得・Gemini） | 中央にスピナー＋段階の文（4.11）。「やめる」リンク。**写真の欄は押せない** |
| ③ Google の選択画面の待ち | 説明の文＋ボタン「Googleフォトを開く」（4.4 の4）・リンク「やめる」 |
| ④ 写真がある | 紫の説明（`.ainote`。AI が選んだ直後だけ）→ 選んだ写真の格子 → 「ほかの候補（タップで追加）」→「選ばなかった写真（n枚）と理由を見る」 → 下に「Googleフォトから選び直す」「端末から写真を追加」 |

**格子**（`.pgrid`）: 3列・すき間 8・各マスは正方形・枠 2px・角丸 12。選んだ写真には右上に「×」（30px の円・白）、下に帯のラベル（11・白地に黒の 78% 透明）。ラベルは、Gemini がつけた短い言葉（ステージ・客席など。最大10文字。無ければ付けない）。「ほかの候補」は薄く（不透明度 .55）、右上に緑の「＋」の円。**選べる枚数の上限は、既存と同じ 8枚**（`maxPhotosPerItem`。超えるときは「＋」を押せなくする）。

**選ばなかった写真**（P2）: 開くと、縮小の写真・理由の文（4.5 の固定の文）・「戻す」リンクの行が並ぶ。

**決定**: 「決定」を押すと、`MemoryEditor.savePhotos(memory, items)`（7章）で保存する。Google フォトから選んだ写真は、**この時点で大きいサイズ（長辺 1600px）を取り直して** `NewPhoto` にする（取り直しに失敗したら「写真を取り込めませんでした。もう一度選び直してください」。縮小の写真しか持っていないものは保存しない）。「×」で外しただけの写真は、保存したとき Storage から消える（既存のフォームと同じ順序・同じ失敗の扱い）。**「とじる」（×）・暗幕・Esc は、変更を捨てて閉じる**（変更があるときは確認しない。**ただし、保存中は閉じられない**）。

### 4.4 Google フォトとつなぐ（R2。カレンダーと同じ要領）

**「権利関係」とは**: Google フォトの写真を読む許可（OAuth の権限）を利用者から取ること、そのためのアプリ側の設定（Google Cloud の API の有効化・OAuth 同意画面）、そして写真の扱いの説明（同意）。**カレンダーと同じ方式**で作る。

#### 4.4.1 カレンダーと同じにするもの・違うもの

| 項目 | カレンダー（今あるもの） | Google フォト（作るもの） |
|---|---|---|
| 認可の方法 | Firebase Auth の Google ポップアップに、権限（スコープ）を足して求める | **同じ**。`GoogleAuthProvider()..addScope(スコープ)` |
| スコープ | `https://www.googleapis.com/auth/calendar.events` | `https://www.googleapis.com/auth/photospicker.mediaitems.readonly`（**読み取り専用**。公式の Picker API の説明で確認済み） |
| ログイン方法の分岐 | `google.com` があれば `reauthenticateWithPopup`（`login_hint` に `user.email`）／無ければ `linkWithPopup` | **同じ分岐・同じエラーの扱い**（文言の「カレンダー」を「Googleフォト」にするだけ） |
| トークンの扱い | メモリーに持つ。50分で取り直す。**保存しない** | **同じ**（メモリーだけ。Firestore・Storage・ローカルに保存しない。5.4）。写真の縮小版の取得（`baseUrl`）は60分で切れる（公式） |
| 呼び出しの順 | ボタンの処理の中で、**最初に** `_accessToken()` を呼ぶ | **同じ**。つなぐボタンの処理の中で、最初に認可を呼ぶ |
| 例外の見せ方 | `'$e'` を画面に出している | **出さない。** 日本語の文言に直す（4.11 のエラー）。コード・例外の中身・トークンはログにも出さない |
| 接続テストの画面 | `/calendar-test` | `/photos-test`（同じ作り。ログイン後の画面から開ける。本番の導線には出さない） |
| Google Cloud の設定 | Calendar API を有効にする・OAuth 同意画面にスコープを足す・テストユーザーを登録する | **Photos Picker API を有効にする**・OAuth 同意画面にスコープを足す・テストユーザーを登録する（12.0。**人間が行う**） |
| 運用 | 「テストユーザーのみ」。審査員のアカウントでは失敗する | **同じ**（5.6）。**つながなくても使えるように、「端末から写真を追加」を必ず残す**（①の状態のリンク） |
| 呼ぶ API | Calendar API（`GET`/`POST`/`PUT`） | **Photos Picker API**（`https://photospicker.googleapis.com/v1/...`。下の 4.4.3） |
| 追加の手順 | なし（呼べばすぐ読み書きできる） | **利用者が Google の選択画面で写真を選ぶ手順が入る**（セッション → 選択画面 → ポーリング → 一覧 → 縮小版の取得） |

#### 4.4.2 同意の説明（アプリの中。`openConsent()`）

つなぐボタンを**このタブで最初に押したとき**だけ、同意のダイアログを出す（`AlertDialog`。見本の `.modal`: 枠 2px・角丸 18・影 `6px 6px 0`）。見出し「Googleフォトとつなぎますか？」。本文は 4.11。ボタンは「今はしない」（`out`）と「つなぐ」（緑。**開いたらここにフォーカス**）。「つなぐ」を押すと、**そのボタンの処理の中で最初に**認可のポップアップ（4.4.1）を開く。「今はしない」は閉じるだけ。**同意したかは、保存しない**（このタブのメモリーの中の印だけ。同じタブで2回目以降は、ダイアログなしでポップアップへ進む。5.4）。

**Google 側の同意画面**（ポップアップ）は Google が出す。アプリ側で作らない。公開ステータスが「テスト」のあいだは、「このアプリは Google で確認されていません」の画面が出る・テストユーザー以外は「アクセスをブロック」になる（カレンダーと同じ。12.0）。

#### 4.4.3 流れ（Picker API。公式の説明で確かめた範囲。**細かい形は G0 で確かめる**）

1. 利用者が「Googleフォトとつなぐ」／「Googleフォトから選び直す」を押す → （最初だけ）同意のダイアログ → 「つなぐ」。
2. **その処理の最初に** `GooglePhotosService.authorize()`（ポップアップ）。
3. `POST https://photospicker.googleapis.com/v1/sessions`（`Authorization: Bearer <token>`、本文は `{"pickingConfig":{"maxItemCount":"30"}}`。**`maxItemCount` の形・上限は要確認 G0**）→ `id`・`pickerUri`・`pollingConfig`（`pollInterval`・`timeoutIn`）・`mediaItemsSet` が返る。
4. **状態③**（「Googleフォトを開く」ボタン）。**ここで利用者がもう一度ボタンを押して**、`pickerUri` に **`/autoclose`** を付けた URL を新しいタブで開く（`launchUrl(..., webOnlyWindowName: '_blank')`）。**認可のポップアップのあとにすぐ開かず、ボタンを挟む理由**: 非同期の処理のあとに `window.open` すると、ブラウザのポップアップ止めに止められるため。`pickerUri` は iframe では開けない（公式）。
5. `GET .../v1/sessions/{id}` を、`pollInterval` ごとに繰り返す（返ってきた値を使う。無ければ 5 秒）。`mediaItemsSet` が `true` になったら次へ。`timeoutIn` を過ぎたら、タイムアウトの文言（4.11）で止める。**シートが閉じられた・「やめる」が押されたら、ポーリングを止める。**
6. `GET .../v1/mediaItems?sessionId={id}`（`nextPageToken` で全ページ）→ 選ばれた写真の一覧（`id`・`baseUrl`・`mimeType`・できれば `createTime`・幅・高さ。**JSON の入れ子の形は要確認 G0**。`mediaFile.baseUrl` でも `baseUrl` でも読めるように書く）。動画（`mimeType` が `image/` で始まらないもの）は捨てる。候補は最大30枚（超えた分は捨てる）。
7. 各写真の縮小版を、`baseUrl` に **`=w768-h768`** を付けて、`Authorization: Bearer <token>` つきの `GET` で取る（**ヘッダーが要る**のは公式の説明どおり。**ブラウザから取れるか（CORS）は要確認 G0**）。同時に取るのは4枚まで。取れなかった写真は飛ばす。
8. `DELETE .../v1/sessions/{id}`（失敗しても無視）。
9. Gemini に渡す（4.5）。

**CORS で `baseUrl` が取れなかったとき**（G0 の結果）: 勝手に作り替えず、リーダーがユーザーに報告する。代案は、Callable Functions で取りに行く（デプロイは人間。関数担当が1人増える）。それまで、画面は ①②③④ のまま。

**中断**: 認可のポップアップを閉じた・選択画面で何も選ばなかった・タイムアウト・ネットワークの失敗は、どれも「状態①か④に戻って、文言を出す」（4.11）。**二重に始めない**（処理中は、つなぐボタンを押せなくする）。

### 4.5 Gemini の写真えらび（R3）

利用者が選んだ候補（最大30枚の縮小版）を、**1回の呼び出し**で Gemini に渡し、選ぶ・候補に残す・選ばない（理由つき）を返してもらう。

- **場所**: `lib/services/photo_pick_ai.dart`（新規）。`GeminiService`（`gemini_service.dart`）は**変えない**。作りは同じ（`FirebaseAI.googleAI().generativeModel(model: 'gemini-3.5-flash-lite', generationConfig: GenerationConfig(responseMimeType: 'application/json', responseSchema: …))`・`Content.multi([TextPart(prompt), InlineDataPart(mimeType, bytes), ...])`・最大3回の再試行・60秒のタイムアウト）。
- **入力**: ライブ名・日時・会場・アーティスト名（4.7）。各写真に番号 `0..n-1` を付け、`TextPart('写真 0')` → `InlineDataPart` の順に並べる。撮影日時（`createTime`）が分かれば、番号の横に書く。
- **プロンプトの要点**（`photo_pick_ai.dart` の中に書く。日本語）: 「ライブの記録のカバーにする写真を、最大4枚選ぶ。構図・ピント・明るさ・ライブらしさ（ステージ・客席・会場の外観・チケット・グッズ）で選ぶ。似た写真は1枚だけ選び、ほかは『似ている』として選ばない。ピントが大きくずれた写真・スクリーンショット・ライブと関係なさそうな写真は選ばない。**人物を特定しない。顔の名前を書かない。** 撮影日時は参考にするが、決め手にしない」。
- **出力のスキーマ**（`Schema.object`）: `items` の配列。各要素 `{ index: integer, decision: enum('pick','candidate','skip'), rank: integer?（pick のときの順位。1が表紙）, label: string?（最大10文字の短い言葉）, skipKind: enum('duplicate','blurry','screenshot','unrelated','other')?（skip のとき） }`。**自由な文章の理由は返させない**（画面に出す文は、アプリ側の固定の文に変える。表示の安全のため）。
- **後処理（純粋関数 `parsePhotoPick(json, count)`）**: 範囲外・重複した `index` は捨てる／返ってこなかった番号は `candidate` にする／`pick` が5枚以上なら `rank` の小さい順（無ければ番号順）に4枚だけ残し、残りは `candidate` にする／`skip` の `skipKind` が無い・知らない値は `other`／`label` は10文字に切り、空なら null。**どんな返り値でも例外を投げない**（JSON が壊れていたら、全部 `candidate` で「AIが選べなかった」扱い）。
- **固定の理由の文**: `duplicate`＝「似ているため」・`blurry`＝「ピントがずれているため」・`screenshot`＝「スクリーンショットのため」・`unrelated`＝「ライブと関係なさそうなため」・`other`＝「今回は選ばなかったため」。
- **失敗したとき**: 再試行しても失敗（`FirebaseAIException`・タイムアウト）したら、**全部「ほかの候補」にして**、「AIが写真を選べなかったので、自分で選んでください」を出す（写真は失わない）。
- **送るもの・送らないもの**: 縮小版（長辺 768px）の画像と、ライブ名・日時・会場・アーティスト名だけ。**元の大きさの写真・位置情報・利用者の名前・メールアドレスは送らない。** 候補の写真は、端末のメモリーの中だけに置き、**保存しない**（採用して「決定」した写真だけを Storage に保存する。5.5）。
- **コスト**: 呼び出しは「選ぶ」を押した1回につき1回。やり直しで増える（再試行を除く）。30枚×約100KB＝約3MB（インラインの上限の範囲。**Gemini が30枚で安定して返るかは要確認 G0**）。

### 4.6 「まとめて編集して投稿」の画面（R4。`/memories/:performanceId/share`）

見本の `post3()`。**上のバー**（`nb`＝影なし）に「戻る」と「投稿をまとめて編集」。中身は縦のスクロール。

1. **投稿先**のタブ（`.tabs`。2つのボタン・各 46px・枠 2px・角丸 12・押されているほうは色つき）: 「X」（黒い角丸の四角に白い X のマーク）・「Instagram」（カメラのアイコン）。その下に説明「のせる内容は、XとInstagramで別々に決められます。いまは**X**の設定です。」。**画面を開くたび、投稿先は X（既定）・画像の形は 1 つめに戻す**（見本の `st.fmt[st.target]=0`）。上に固定（`.stk`）。
2. 説明（ペンのアイコン）「チケットの写真・セトリ・感想を**タップ**すると、その場で直せます。」
3. **シェア画像のプレビュー**（4.7。`hints: true`）。写真・セトリ・感想の部分は、**タップできる**（ホバーやフォーカスのとき、青 `#1D4ED8` の破線の枠）。押すと、その部分の編集シート（写真→4.3、セトリ・感想→下のシート）が開く。
4. 「画像にのせる部分」の見出し → チップ（写真・日付・会場・セトリ・感想・「おしあし」マーク）。「文章にのせる部分」の見出し → チップ（日付・会場・セトリ・感想・ハッシュタグ）。チップ（`.pchip`）: 丸い枠 2px・押すと色が付いてチェックが出る・`aria-pressed`。**画像のチップの「写真」「セトリ」「感想」には、右にペンのボタン**（44px。押すと編集シート）。**座席のチップは作らない**（座席は SNS に出さない）。
5. 折りたたみ「画像の形・デザイン・背景色を変える」（`details.look`）: 形（`FMT`。丸いボタン）・デザイン（チケット／写真メイン。コラージュは作らない）・背景（7色の丸。きいろ・みどり・ピンク・赤・青・オレンジ・紫。黒はなし。ユーザー指示 11/8）。**P1 は「チケット」と、その投稿先の1つめの形だけ**。ほかは P2（出さないか、押せない状態で出す。出すなら「準備中」とは書かず、**出さない**）。
6. 「投稿の文章」の見出し → 文章の欄（4.8）。
7. 「投稿する」の見出し → 動作のボタン（4.8）。

**投稿先ごとの設定**（のせる部分・形・デザイン・文章の手直し）は、投稿先ごとに別々に持つ（`ShareConfig`。7章）。**保存しない**（画面を閉じたら、既定に戻る。5.14）。既定（見本の `DEF`）:

| 部分 | X | Instagram |
|---|---|---|
| 写真 | 画像 | 画像 |
| 日付・会場 | 画像・文章 | 画像・文章 |
| セトリ | 画像 | 画像 |
| 感想 | 文章 | **画像** |
| ハッシュタグ | 文章 | 文章 |
| 「おしあし」マーク | 画像 | 画像 |

**編集シート**（写真以外。`ボトムシート`）: 見出し「セトリを直す」「感想を直す」・入力欄（記録の画面と同じ検査・同じ文言）・緑の「決定」。「決定」で `MemoryEditor.saveFields(...)` で**記録に保存**する（プレビューも文章も、すぐ新しい内容になる）。入力のたびに、プレビューが変わる（保存は決定のときだけ）。

**自動で作る文章**は、のせる部分を変えるたびに作り直す。ただし、**利用者が文章を直したあとは、作り直さない**（「自動で作った文章に戻す」を押すまで）。

### 4.7 シェア画像（チケット。R5）

**作り方**: 端末の中だけで作る（5.7）。Flutter のウィジェット（`ShareTicketView`）で描き、`RepaintBoundary` → `toImage(pixelRatio)` → PNG のバイト列にする。**プレビュー・ホームのミニのカード・保存する画像は、同じウィジェットを使う**（見た目がずれないように）。

**大きさ**: 保存する画像の大きさは、形ごとに固定（X の横長 16:9＝1600×900・X の正方形＝1080×1080・Instagram のフィード 4:5＝1080×1350・ストーリー 9:16＝1080×1920）。プレビューは、同じ比率で画面の幅に収める（縦長のものは、高さの上限を決めて、幅を狭める。見本の `maxh`）。**文字・余白の大きさは、画像の幅に対する割合**（見本の `cqw`＝幅の 1%）で決める。`LayoutBuilder` で幅を測り、`unit = width / 100` として、`4.6 * unit` のように書く。

**見た目の数値は、見本の CSS の `.shot`〜`.shot.wide .dz2 .ex`（見本の 233〜296 行）を正とする。** 要約（チケットのデザイン、縦長）:

| 部分 | 内容 |
|---|---|
| 背景 | 選んだ色（`BGS`: きいろ `#F5D31A`・みどり `#2DBE7E`・ピンク `#F27CB1`・くろ `#1A1A1A`）。枠 2px |
| チケット（`.tkw` / `.tk`） | 画像の端から 5（横長は 4）あけて置く。地は `#FFF9EA`・角丸 2.2。外側に墨の縁取り（.5）と、右下にずらした影（.9・1.3・黒の 28%）。半券の上に、左右から半円の切り欠き（半径 3.4。横長は 3） |
| 上の帯（`.tk-top`） | 黒地・白字「LIVE TICKET」（2.6・字間 .14em）・右に「参戦済み」（枠つき・-3度傾ける） |
| 写真（`.hero`） | 1・2・3枚で並べ方が違う（3枚は左に大きい1枚＋右に2枚）。0枚は、背景色のしま模様＋アーティスト名（白地の枠）＋「LIVE」。**0枚のときの「写真を選ぶ」はプレビューだけ（保存する画像には出さない）** |
| 本文（`.tk-body`） | ライブ名（4.6・700）→ セトリ（「SET LIST」の見出し・番号つきの行。5曲以上は2列）→ 感想（「MEMO」の見出し） |
| 半券（`.stubx`） | 背景色の地・上に破線。左に日付（`12.19 SAT` の形。6.4・700）と会場（2.7）、右にバーコード風の縞（幅 20）、「おしあし」マーク（黒地・白字） |
| 横長（`.tkw.h`） | 左に写真（幅 34%）・中央に本文・右に縦の半券（幅 25%） |

- **座席は、どのデザイン・どの形でも、画像に出さない。**（`ShareTicketView` は、座席を受け取る引数すら持たない。7章）
- セトリ・感想は、形ごとの上限で切る（`LIM`: X の横長＝セトリ 3 曲・感想 36 文字、X の正方形＝4・44、Instagram のフィード＝6・72、ストーリー＝10・150）。超えたら、セトリは「ほか○曲」、感想は「…」。切ったとき、プレビューの下に「セトリは、画像には先頭○曲まで入ります。全曲は文章にのせられます。」「感想は、画像には○文字までです。全文は文章にのせられます。」を出す。
- **空の枠（「+ セトリを書く」「+ 感想を書く」）は、プレビューだけ**に出す（`hints: true`）。保存する画像・ホームのミニのカードには出さない。
- 日付: `formatShareDate(startAt)`（日本時間。`MM.dd EEE`・曜日は英語の大文字3文字）。会場は長いとき、2行まで・はみ出したら `…`。
- アーティスト名: 記録のライブ（`Live`）の `groupIds`（無ければ `oshiIds`）を `allOshisProvider` で名前にして、先頭1つ。引けなければ空（0枚のときの枠にはライブ名の先頭を使う）。
- **写真の取り込み**: 保存済みの写真は、`StorageImage`（`Image.network`）ではなく、**バイト列を取って `Image.memory` で描く**（`Image.network` のままだと、ブラウザの制限で、画像にしたとき空白になることがある。**Storage の CORS の設定が要る可能性。要確認 G0・12.0**）。描き終わる前に PNG にしない（`precacheImage` や `decodeImageFromList` で、読み込みの完了を待つ）。
- **保存**（`file_download`。7章）: Web ではブラウザのダウンロード（`<a download>`）。ファイル名は `oshiashi_<performanceId>_<x|ig>.png`。

### 4.8 文章（キャプション）と投稿の動作（R4）

**自動で作る文章**（`buildCaption`。見本の `captionAuto`）:

```
【参戦記録】{ライブ名}
{日付(2026/12/19(土))} @ {会場}                 ← 「日付・会場」が文章のとき
セトリ：{1曲目} / {2曲目} / …                   ← 「セトリ」が文章のとき（全曲）
                                                ← 空行
{感想（改行は空白にまとめる）}                  ← 「感想」が文章のとき
                                                ← 空行
#{出演者名} #おしあし                           ← 「ハッシュタグ」が文章のとき
```

- **座席は、文章にも出さない。**
- ハッシュタグ: 出演者名（先頭2つまで。空白は除く）に `#` を付け、最後に `#おしあし`（5.13）。
- 文字数の上限: X は **280（重み付き。日本語などは1文字を2と数える。`xWeightedLength`。5.12）**、Instagram は 2200（素の文字数）。超えたら、数の表示を赤・太字にして「（文字数が多すぎます）」を出し、**X の「投稿画面を開く」ボタンを押せなくする**。
- 欄: 最小の高さ 150・14。入力すると「手直し済み」になる（4.6）。「自動で作った文章に戻す」は、手直し済みのときだけ出す。

**X の動作**:

- 「Xで投稿画面を開く」（黒いボタン・白い X のマーク）: `https://x.com/intent/post?text=<文章をエンコード>` を新しいタブで開く。**画像は付かない**。説明「文章が入った状態でXの投稿画面が開きます。画像は「画像を保存」してから、投稿画面で追加してください。」
- 「画像を保存」（`out`）: PNG をダウンロード。
- **画像が一度も保存されていなくても、押せる**（画像なしで投稿する人もいるため）。

**Instagram の動作**（3ステップ。`.steps3`）: ① 「画像を保存」② 「文章をコピー」（`Clipboard.setData`）③ 「Instagramを開く」（`https://www.instagram.com/` を新しいタブで開く）。①②を押したら、番号の丸が色付きになる（済み）。③は、①②の前でも押せる。説明「Instagramは、文章を自動で入れられません。画像を保存し、文章をコピーしてから、Instagramの投稿画面で貼り付けてください。」

**投稿した印**: 「Xで投稿画面を開く」・「画像を保存」・「Instagramを開く」のどれかを押したら、`MemoryEditor.markPosted(memory)`（記録に `postedAt` を書く。5.11。すでにあれば何もしない）。失敗しても、利用者の操作は止めない（無視する）。

**クリップボード・ダウンロードの失敗**: SnackBar「保存できませんでした。もう一度お試しください」「コピーできませんでした。文章を長押ししてコピーしてください」。成功は、見本のトースト（下から出る・2.6秒。チェックのアイコン）「画像を保存しました」「文章をコピーしました」。

### 4.9 ホームのカードと一覧（R6・R7）

**ホーム**（R6）: ホームの上のほう（あいさつの下・「次の締切」などの上）に、**新しい記録のカード**（見本の `.banner`）。

- 出すのは、`recentUnpostedMemory(memories, now)`（7章）が返す記録があるときだけ: 参戦済みで、開演から **7 日以内**（`recentMemoryDays`）で、`postedAt` が無い記録のうち、開演が新しい1件。
- 中身: 上にミニのシェア画像（`ShareTicketView`・`mini`・幅 190・投稿先は Instagram の形で見せる＝見本どおり。背景 `#E7E0CB` の帯の中）→ 見出し「ライブお疲れさまでした！」（アイコン付き・15・700）→ 本文「**{ライブ名}**の記録と、投稿用のチケットができています。そのままでも、まとめて直してからでも投稿できます。」→ ボタン2つ「Xに投稿」（黒）「Instagram」（`out`）→ リンク「記録を見る・セトリと感想を書く」。
- 「Xに投稿」「Instagram」は、投稿の画面（4.6）を、その投稿先を選んだ状態で開く（`/memories/:performanceId/share?target=x`・`?target=ig`）。リンクは記録の画面へ。
- **写真が0枚でも出す**（チケットの写真の枠は縞模様）。その場合のカードの本文は同じ。
- 4状態: 読み込み中は何も出さない（ホームの表示を遅らせない）・記録なしは何も出さない・エラーも何も出さない。

**メモリー一覧**（R7・P2）: 参戦済みの先頭に、**新しい記録**（同じ判定）を大きいカード（見本の `.draft`。枠 2px・角丸 14・影 `4px 4px 0`・上に写真4枚の帯 64px・下に札・ライブ名・日付と会場・進み具合・「チケットを開いて、セトリと感想を書く」）として1件だけ出す。ほかの参戦済みは、既存のカード（`MemoryAlbumCard`）のまま。写真が0枚の帯は、緑の地に「写真は、これから入れます」。

### 4.10 読み上げ・キー・動き・はみ出し

- **タップの大きさ**: すべて 44px 以上（チップのペン・格子の「×」「＋」は、見た目が小さくても押せる範囲を 44px にする）。
- **読み上げ**: チケットの写真・セトリ・感想・座席の欄は、`Semantics(button: true, label: '写真を直す')` のように「○○を直す」。シェア画像のプレビューは `Semantics(image: true, label: '投稿する画像のプレビュー')`。チップは `Semantics(toggled:)`（`aria-pressed` 相当）、スイッチは `Semantics(toggled:)`。進み具合は「記録の完成度 n/4」。ダイアログ・シートは `scopesRoute`・`namesRoute`（`help_sheet.dart` と同じ）。
- **フォーカス**: ダイアログは「つなぐ」、編集カードは入力欄、シートは見出し。Esc で閉じる。閉じたあと、開いたボタンにフォーカスを戻す。
- **動き**: `MediaQuery.disableAnimations` のとき、シート・ダイアログ・バー・トーストの動きを止める（既存の約束）。
- **はみ出し**: 幅 320・360・390・430・720・1000・文字 1.3 倍・キーボードありで、はみ出さない。シートは、PC の幅（720 以上）で最大幅 640。
- **文字の拡大**: シェア画像の中の文字は、端末の文字の拡大に**影響されない**（`MediaQuery.withNoTextScaling`）。画面の他の文字は影響を受けてよい。

### 4.11 文言一覧（コピーして使う。全角の `（` `）` `：` `！` `？` `…`）

**同意のダイアログ**: 見出し「Googleフォトとつなぎますか？」／本文（箇条書き）
- 「写真を読み取るだけです。変更や削除はしません。」
- 「Googleフォトの画面で、あなたが選んだ写真だけを使います。ライブラリ全体は見ません。」
- 「選んだ写真は、AI（Gemini）に送って、よく写っている写真を選びます。」
- 「記録に入れた写真だけを、おしあしに保存します。」
- 「やめたいときは、Googleアカウントの設定（Googleのサービスにアクセスできるアプリ）から解除できます。」

ボタン「今はしない」「つなぐ」。

**状態①**: 見出し「Googleフォトとつなぐと、おしあしが写真を選びます」／説明「Googleフォトの画面で、公演の日に撮った写真をまとめて選ぶと、その中から、おしあしがいい写真を選びます。」／ボタン「Googleフォトとつなぐ」／リンク「つながずに、写真を自分で追加する」。

**状態②（段階）**: 「Googleフォトとつないでいます…」→「写真を取り込んでいます…」→「いい写真を選んでいます…」。リンク「やめる」。

**状態③**: 「Googleフォトを開いて、公演の日に撮った写真を選び（最大30枚）、「完了」を押してください。」／ボタン「Googleフォトを開く」／リンク「やめる」／選択待ちの間は「選び終わるのを待っています…」。

**状態④**: 紫の説明「**おしあしが選びました。**あなたが選んだ{n}枚の中から、よく写っている写真を{m}枚えらんでいます。入れ替えもできます。」／「ほかの候補」（タップで追加）／「選ばなかった写真（{n}枚）と理由を見る」「選ばなかった写真をとじる」「戻す」／「Googleフォトから選び直す」「端末から写真を追加」。

**エラー・お知らせ**（画面には、これらだけを出す。コード・例外の中身・トークンは出さない）:

| 場面 | 文言 |
|---|---|
| ポップアップを閉じた・やめた（`popup-closed-by-user`・`cancelled-popup-request`） | 「Googleフォトにつなぎませんでした。」 |
| ポップアップを止められた（`popup-blocked`） | 「ポップアップが止められました。ブラウザの設定で許可してから、もう一度お試しください。」 |
| 別の Google アカウントを選んだ（`user-mismatch`） | 「ログイン中のアカウント（{メール}）を選んでください」（カレンダーと同じ） |
| 他のおしあしのアカウントで使われている Google アカウント | 「この Google アカウントは、別のおしあしのアカウントで使われています。別の Google アカウントを選んでください」（カレンダーと同じ） |
| 権限を取れなかった | 「Googleフォトの権限を取得できませんでした。」 |
| Picker API が 403・API 未設定 | 「Googleフォトを使えませんでした。しばらくしてからもう一度お試しください。」（原因の詳細は出さない。12.0 の設定の確認はリーダーに連絡） |
| 選ぶ時間が過ぎた（`timeoutIn`） | 「選ぶ時間が過ぎました。もう一度やり直してください。」 |
| 何も選ばれなかった | 「写真が選ばれませんでした。」 |
| 縮小版を1枚も取れなかった | 「写真を取り込めませんでした。もう一度お試しください。」 |
| Gemini が失敗 | 「AIが写真を選べなかったので、自分で選んでください。」 |
| 保存で大きい写真を取り直せなかった | 「写真を取り込めませんでした。もう一度選び直してください。」 |
| 保存の失敗 | 「写真を保存できませんでした。もう一度お試しください」（既存と同じ）・「記録を保存できませんでした。もう一度お試しください」（既存と同じ） |
| ネットワーク | 「通信できませんでした。もう一度お試しください。」 |

**記録の画面**: 「セトリを書く」ヒント「公演のあとに、覚えている曲から書けます」／「感想を書く」ヒント「心に残ったことを、自由に書いてください」／「直す」／「決定」／「写真はまだありません」／「Googleフォトとつなぐ」／「写真を追加」／「SEAT / 座席」／「未入力」／「n/4 入力済み」／「まとめて編集して投稿」／セトリの欄「覚えている曲から、1行に1曲ずつ書けます。」と例（「1. 曲名」「2. 曲名」）／感想の欄「いちばん心に残ったこと、うれしかったこと、MCの話など。」「思い出したときに、少しずつでも大丈夫です。」／座席の例「アリーナ C3ブロック 8列 21番 / 自由席」／札「公演のあとに書く」。

**投稿の画面・ホーム**: 4.6・4.8・4.9 に書いたとおり。

### 4.12 キー一覧（新しく付けるもの。**タップを受ける部品自身に付ける**）

| キー | 部品 |
|---|---|
| `memory_ticket` | 記録のチケット全体 |
| `memory_ticket_photos` | チケットの写真の欄（ボタン） |
| `memory_ticket_seat_edit` | 座席の「直す」ボタン |
| `memory_ticket_setlist` / `memory_ticket_impression` | セトリ・感想の枠（ボタン） |
| `memory_inline_editor` / `memory_inline_input` / `memory_inline_save` | 編集カード・入力欄・決定 |
| `memory_progress` | 進み具合 |
| `memory_share_button` | 「まとめて編集して投稿」 |
| `memory_publish_switch` / `memory_publish_seat_switch` | 公開スイッチ（P2） |
| `photo_sheet` / `photo_sheet_close` / `photo_sheet_done` | 写真を直すシート・とじる・決定 |
| `photo_connect_button` / `photo_manual_add` | 「Googleフォトとつなぐ」・「つながずに…」「端末から写真を追加」 |
| `photo_open_picker` / `photo_cancel` | 「Googleフォトを開く」・「やめる」 |
| `photo_reselect` | 「Googleフォトから選び直す」 |
| `photo_selected_{i}` / `photo_remove_{i}` | 選んだ写真・外す |
| `photo_candidate_{i}` | ほかの候補（追加） |
| `photo_skipped_toggle` / `photo_skipped_restore_{i}` | 選ばなかった写真（P2） |
| `photo_ai_note` | 紫の説明 |
| `photo_error` | エラーの文 |
| `google_photos_consent` / `google_photos_consent_yes` / `google_photos_consent_no` | 同意のダイアログ・つなぐ・今はしない |
| `share_page` / `share_tab_x` / `share_tab_ig` | 投稿の画面・タブ |
| `share_preview` / `share_part_photo` / `share_part_setlist` / `share_part_memo` | プレビュー・タップできる部分 |
| `share_chip_img_{photo|info|setlist|memo|mark}` / `share_chip_cap_{info|setlist|memo|tags}` | チップ |
| `share_chip_edit_{photo|setlist|memo}` | チップのペン |
| `share_caption` / `share_caption_reset` / `share_caption_count` | 文章の欄・戻す・文字数 |
| `share_post_x` / `share_save_image` / `share_copy_caption` / `share_open_ig` | 動作のボタン |
| `share_edit_sheet` / `share_edit_input` / `share_edit_done` | 編集シート・入力欄・決定 |
| `home_memory_banner` / `home_memory_banner_x` / `home_memory_banner_ig` / `home_memory_banner_open` | ホームのカード・ボタン・リンク |
| `memory_list_recent_card` | 一覧の新しい記録のカード（P2） |

## 5. 実装前に確かめること（リーダー → ユーザー）

**リーダーは、チームメイトを作る前に、下の項目をまとめてユーザーに聞く。** どれも推奨案つき。答えを `notes/判断ログ_memory_ticket.md`（新規）に書き、この表の「回答」の列を埋める。**確認が済むまでチームメイトは作らない。**（CLAUDE.md の「未決定事項は自分で確定させない」に従い、案・理由・捨てる案を添えて示す。5.1・5.4・5.5・5.6 は、依頼文の「Google カレンダーと同じ要領」「写真えらびは Gemini」で方針が決まっているので、**確認というより、前提の読み合わせ**として短く聞く。）

| 項目 | 推奨案 | 理由・ほかの案 | 回答 |
|---|---|---|---|
| 5.1 Google フォトの方式 | **案A: Picker API**（利用者が Google の選択画面で候補を選ぶ → 渡された写真だけを読む）。見本の「近くで撮った写真を自動で候補にする」は作らない（4.0） | Library API は2025年3月31日から、第三者のアプリは利用者の写真全体を読む・検索できない（公式の変更履歴）。案B: Library API で全体から自動で選ぶ（**使えない**。403 になる）。案C: 端末から写真を選ぶだけにする（Google フォトを使わない。**依頼と違うので、案A が動かなかったときの代案**） | |
| 5.2 Gemini の担当 | **案A: 利用者が選んだ候補（最大30枚）の中から、Gemini が最大4枚を選び、ほかを候補・「選ばなかった」に分ける**（理由は固定の文） | 案B: 写真全体から選ぶ（5.1 の理由で不可能）。案C: Gemini が自由な文章で理由を書く（表示の安全・文のばらつきのため、固定の文にする） | |
| 5.3 候補の枚数・大きさ | **案A: 候補は最大30枚・Gemini に送るのは長辺 768px** | 1回の呼び出しの大きさ・時間・費用のため。案B: 20枚・512px（軽い）。案C: 50枚・1024px（重い。タイムアウトの恐れ）。**実測は G0 の結果で決め直す** | |
| 5.4 認可の実装 | **案A: カレンダーと同じ作り**（Firebase Auth のポップアップにスコープを足す・トークンはメモリーだけ・保存しない・最初に呼ぶ）を、`GooglePhotosService` に**書き写す** | 依頼どおり。案B: カレンダーと共通の部品に作り直す（動いているカレンダーを触るので、提出前は危ない。**捨てる**。落ち着いたあとの整理に回す） | |
| 5.5 写真データの扱い | **案A: 候補の写真は端末のメモリーだけに置く。Gemini には縮小版だけを送る。「決定」した写真だけを大きいサイズで取り直して Storage に保存する。同意のダイアログで、AI に送ることを書く（4.4.2）** | 写真は利用者のものなので、必要な分だけ使う。案B: 候補もすべて保存する（**捨てる**。使わない写真を残さない）。**Google の「API サービスのユーザーデータポリシー」（Limited Use）と、写真を AI に送ることの関係は、人間が公式の文書で確かめる**（12.0。ここでは判断できない） | |
| 5.6 認可の公開状態 | **案A: カレンダーと同じく「テスト」のまま、テストユーザーだけ**。審査員のアカウントでは Google フォトにつなげないかもしれない。**つながなくても使える「端末から写真を追加」を必ず残す**。提出物の説明か動画で伝える | 機密性の高いスコープなら、公開には Google の審査が要る（日数がかかる。提出に間に合わない）。案B: 審査を申請する（**間に合わない見込み**。人間の判断）。**スコープが「機密」かどうかは、同意画面の設定のときに分かる（5.17 ③）** | |
| 5.7 シェア画像の作り方 | **案A: 端末の中で、Flutter のウィジェットを PNG にする** | サーバーに送る写真が増えず、デプロイも要らない。案B: Cloud Functions で画像を作る（**捨てる**。デプロイは人間・時間がない・写真をサーバーで扱う） | |
| 5.8 画像の保存（ダウンロード） | **案A: `pubspec.yaml` に `web`（すでに Flutter が使っているパッケージ。新しい取得は要らない）を1行だけ足し、`<a download>` で保存する**（Web 用と、テスト用の何もしない版を、条件付きの import で分ける） | 案B: パッケージを足さず `dart:js_interop` だけで書く（動くが読みにくい）。案C: `share_plus` を足す（新しい依存。**捨てる**） | |
| 5.9 保存の形式 | **案A: PNG** | 文字がくっきりする。案B: JPEG（軽いが、文字がにじむ） | |
| 5.10 記録の作成 | **ユーザー回答（11/8）: 「記録する」を押したときに作る（勝手な自動作成はしない）。見本のとおり、メモリー一覧の「参戦済み」の見出しの下に説明文を足す**（4.0 の表）。見本の「自動で作られます」の文は「押すと作られます」に言い換える |
| 5.11 投稿した印 | **案A: 記録に `postedAt`（任意の日時）を足す**。ホームのカードを、投稿したら消すため。ルールの変更は要らない（`users/{uid}/memories/**` は本人が書ける。公開の写しには写さない） | 案B: 足さず、開演から7日で消えるだけにする（投稿しても出続ける）。**`live_memory.dart`・`memory_repository.dart` の共有ファイルに足す**（5.16） | |
| 5.12 X の文字数 | **案A: X の数え方（日本語などは1文字を2と数え、280まで）で判定する** | 見本は素の文字数 280（日本語だと、実際は140文字ほどで投稿できなくなる）。案B: 見本どおり素の文字数（投稿画面で切れる恐れ）。**数え方の細部は X の公式の説明で確かめる**（`xWeightedLength` の範囲は 7章） | |
| 5.13 ハッシュタグ | **案A: 出演者名（先頭2つまで）＋「#おしあし」** | 本物のデータにタグの項目が無い。見本の2つ目（「ひかりの旋律」）はライブ名の一部で、機械では切れない。案B: ライブ名の先頭の語も足す（ばらつく） | |
| 5.14 投稿先ごとの設定の保存 | **案A: 保存しない**（画面を閉じたら、既定に戻る） | 見本もそう。案B: 端末か Firestore に保存する（項目と検査が増える） | |
| 5.15 記録の画面の置き換え | **案A: `MemoryDetailPage` をチケットの画面に作り替える。`MemoryFormPage` は残す**（作成・削除・公開の設定の入口。AppBar の「編集」から行く） | 既存のテスト・導線を壊さない。案B: フォームを消してチケットの画面だけにする（**範囲が大きい**。作成の入口を作り直すことになる） | |
| 5.16 共有のファイルへの変更 | **案A: マージの前に一声かける**。`lib/models/live_memory.dart`（`postedAt` を足す）・`lib/repositories/memory_repository.dart`（`markPosted` を足す）・`lib/app.dart`（ルートを足す）・`lib/features/home/home_page.dart`（ウィジェットを1つ足す）・`lib/features/memory/memory_detail_page.dart`・`memory_list_page.dart`・`pubspec.yaml`（`web` を1行）・`test/**` の偽物 | 足すだけで、既存の動きは変えない。案B: 何も言わない | |
| 5.17 動作確認で分かること（決める項目ではない） | 実際に動かして分かった結果を、リーダーが判断ログに書き、4章・5.1〜5.6 を直す（**G0 の確認＝12.1 の 5〜10**） | ① Picker API の実際の JSON の形（`maxItemCount` の型・上限、`pickerUri`・`pollingConfig`・`mediaItems` の入れ子、`createTime`・幅・高さ・位置情報の有無）。② `baseUrl` の取得（`Authorization` つきの `fetch`）が、ブラウザから CORS で通るか。③ スコープが「機密」か・テストユーザーでの同意画面の出方・「未確認のアプリ」の画面。④ Storage の写真を `Image.memory` で描いて PNG にできるか（CORS）。⑤ Gemini が30枚（768px）で、10秒台〜で安定して返るか。⑥ X の投稿画面・Instagram が、スマホのブラウザでも開くか。⑦ 同意のダイアログ・ポップアップが、ブラウザに止められないか | |

## 6. 担当とファイル

同じファイルを2人が同時に編集すると上書きが起きる。**担当外のファイルは編集せず、担当者に SendMessage で依頼する。**

| 担当 | 名前 | 編集してよいファイル |
|---|---|---|
| リーダー | （メインセッション） | この計画書、`notes/判断ログ_memory_ticket.md`（新規）、`notes/memory_ticket_進捗.md`、`markdown/deploy_手順.md`（**「2.4 Google フォト連携」の追記のみ**。12.0 の内容） |
| データ層・サービス・AI | `photos-data` | `lib/utils/memory_ticket.dart`・`lib/utils/share_ticket.dart`・`lib/utils/google_photos_errors.dart`（新規）、`lib/services/google_photos_service.dart`・`lib/services/photo_pick_ai.dart`（新規）、`lib/providers/memory_ticket_providers.dart`・`lib/providers/photo_pick_providers.dart`・`lib/providers/share_providers.dart`（新規）、`lib/models/live_memory.dart`（**`postedAt` の追加のみ**。既存の項目・メソッドの動きは変えない）、`lib/repositories/memory_repository.dart`（**`markPosted` の追加のみ**） |
| 画面（記録・写真・ホーム） | `ui-record` | `lib/features/memory/memory_detail_page.dart`（作り替え）、`lib/features/memory/ticket/**`（新規）、`lib/features/photos/**`（新規。`/photos-test`・写真を直すシート・同意のダイアログ）、`lib/features/home/home_memory_banner.dart`（新規）・`lib/features/home/home_page.dart`（**1行足すだけ**）、`lib/features/memory/memory_list_page.dart`（**P1: 「参戦済み」の見出しの下に説明文を足す（4.0）。P2: 「新しい記録」のカードを足す**）、`lib/app.dart`（**ルートを足すだけ**） |
| 画面（投稿・シェア画像） | `ui-share` | `lib/features/memory/share/**`（新規。投稿の画面・`ShareTicketView`・編集シート・動作のボタン・画像の取り込み）、`lib/utils/file_download.dart`・`file_download_web.dart`・`file_download_stub.dart`（新規）、`pubspec.yaml`（**5.8 が案A のとき、`web` の1行だけ**。足したら `flutter pub get`） |
| テスト・レビュー | `qa` | `test/**`（メモリー・写真のリポジトリの偽物 `test/features/photo_test_helpers.dart`・`public_memory_test_helpers.dart` などを含む）、`notes/memory_ticket_レビュー記録.md`（新規） |

- **読むだけ（変更禁止）**: `lib/features/memory/memory_form_page.dart`・`shared_memories_view.dart`・`shared_memory_detail_page.dart`・`memory_album_card.dart`、`lib/features/common/**`・`lib/features/calendar/**`・`lib/features/help/**`・`lib/features/live*/**`、`lib/services/google_calendar_service.dart`・`gemini_service.dart`・`calendar_events.dart`、`lib/repositories/**`（`memory_repository.dart` を除く）・`lib/models/**`（`live_memory.dart` を除く）・`lib/providers/**`（新規のものを除く）、`lib/theme/**`、`lib/utils/photo_picker.dart`、`firestore.rules`・`storage.rules`・`test_rules/**`・`functions/**`、`assets/**`、`web/**`。**差分は `git diff --stat` で確かめる。**
- **カレンダーの連携は変えない。** `google_calendar_service.dart` を**読んで書き写す**（`photos-data` が `google_photos_service.dart` に同じ分岐・同じ日本語のエラーで書く）。
- 共有の部品（ボタン・色・書体・`HakoSaveBar` など）で足りないことが出たら、自分で直さず、リーダーに報告する（`lib/features/memory/ticket/` などの中に作って済ませる）。
- `photos-data` が先に契約（7章）を作って渡す。`ui-record`・`ui-share`・`qa` は、`photos-data` のファイルを直接直さず、`photos-data` に SendMessage で頼む。**`ui-share` と `ui-record` の境目**: 写真の欄（`MemoryPhotosSection`）は `ui-record` が `lib/features/photos/` に作り、`ui-share` は**それを使うだけ**で直さない（足りないものは `ui-record` に頼む）。投稿の画面のルートの足し込みは `ui-record`（`app.dart` の担当）に頼む。
- `MemoryRepository` にメソッドを足すと、メモリーのリポジトリの偽物が動かなくなる。**`photos-data` は、足す前に、`qa` に「偽物に足してほしいメソッド（名前・引数・返り値）」を送る**。`qa` は同じタイミングで偽物を直す。
- **依存パッケージは、`web` の1行（5.8 の案A）以外は足さない。** 画像・書体ファイルを足さない。

## 7. 契約（インターフェース）

> コードは**一度もコンパイルしていない**。名前・引数の形を決めるための下書き。`photos-data` が書き写して `flutter analyze` で確かめ、変えた点は `ui-record`・`ui-share`・`qa` に知らせる。Google フォト・`firebase_ai` の関数の名前・型は、`.dart_tool` や pub の資料で確かめてから使う。**Picker API の JSON の形は G0 で確かめて直す。**

**`lib/utils/memory_ticket.dart`**（Firebase に依存しない純粋関数）

```dart
import '../models/live_memory.dart';

/// 開演から何日以内の記録を「新しい記録」とするか（4.9）
const recentMemoryDays = 7;

/// Gemini が選ぶ写真の最大枚数・候補の最大枚数・縮小版の長辺（4.5・5.3）
const maxAiPicks = 4;
const maxPickCandidates = 30;
const pickThumbSide = 768;

/// 記録の進み具合 0〜4。写真が1枚以上・座席・セトリ・感想のうち入っている数
/// （座席・感想は前後の空白を除いて空なら入っていない）
int memoryProgress(LiveMemory m);

/// 「新しい記録」。参戦済み（startAt が now 以前）・開演から [recentMemoryDays] 日以内・
/// postedAt が無い記録のうち、startAt が最も新しい1件。無ければ null
LiveMemory? recentUnpostedMemory(Iterable<LiveMemory> memories, DateTime now);
```

**`lib/utils/share_ticket.dart`**（純粋関数。**座席を受け取る引数・項目を一切持たない**）

```dart
import '../models/live_memory.dart';

enum ShareTarget { x, instagram }
enum SharePart { photo, info, setlist, memo, tags, mark }
enum ShareLayer { image, caption }
enum ShareDesign { ticket, photoMain, collage }

/// 画像の形。比率・保存する大きさ・セトリと感想の上限（4.7）
class ShareFormat {
  const ShareFormat(this.label, this.aspectW, this.aspectH, this.outWidth,
      this.outHeight, this.maxSetlist, this.maxMemoChars);
  final String label; // '横長 16:9' など（4.11）
  final int aspectW, aspectH, outWidth, outHeight, maxSetlist, maxMemoChars;
}

/// X: 横長16:9（1600×900・セトリ3・感想36）／正方形1:1（1080×1080・4・44）
/// Instagram: フィード4:5（1080×1350・6・72）／ストーリー9:16（1080×1920・10・150）
const Map<ShareTarget, List<ShareFormat>> shareFormats = {/* ... */};

/// 投稿先ごとの設定。copyWith で更新する（不変）
class ShareConfig {
  const ShareConfig({required this.parts, this.formatIndex = 0,
      this.design = ShareDesign.ticket, this.backgroundIndex = 0});
  /// 4.6 の表の既定
  factory ShareConfig.defaults(ShareTarget t);
  final Map<SharePart, Set<ShareLayer>> parts;
  final int formatIndex;
  final ShareDesign design;
  final int backgroundIndex; // 0:きいろ 1:みどり 2:ピンク 3:くろ
  bool isOn(SharePart p, ShareLayer l);
  /// photo・setlist・memo・mark は image のみ、tags は caption のみ、info は両方、
  /// memo は両方、setlist は両方。**押せる組み合わせだけ**を許す
  ShareConfig toggled(SharePart p, ShareLayer l);
  ShareConfig copyWith({int? formatIndex, ShareDesign? design, int? backgroundIndex});
}

/// 投稿・画像に出す内容。**座席は無い**
class ShareContent {
  const ShareContent({required this.title, required this.startAt,
      required this.venue, this.artist, this.setlist = const [],
      this.impression, this.performerNames = const [], this.photoCount = 0});
  factory ShareContent.fromMemory(LiveMemory m,
      {String? artist, List<String> performerNames = const []});
  final String title; final DateTime startAt; final String venue;
  final String? artist; final List<String> setlist; final String? impression;
  final List<String> performerNames; final int photoCount;
}

/// セトリの入力（1行1曲）から先頭の番号（'1. ' '2) ' '３、' など）を除いた曲名の一覧。空行は捨てる
List<String> parseSetItems(String text);

/// 改行・連続する空白を1つの空白にし、前後を除く
String oneLine(String text);

/// '12.19 SAT'（日本時間。曜日は英語の大文字3文字）
String formatShareDate(DateTime startAt);

/// '2026/12/19(土)'（日本時間）
String formatCaptionDate(DateTime startAt);

/// 出演者名（空白を除く・先頭2つまで）に '#' を付け、最後に '#おしあし'
List<String> hashtagsOf(List<String> performerNames);

/// 4.8 の形の文章。**座席は入れない**。cfg の caption に入れた部分だけ
String buildCaption(ShareTarget target, ShareConfig cfg, ShareContent c);

/// X の重み付きの長さ。コードポイントが 0〜4351・8192〜8205・8208〜8223・8242〜8247 は1、
/// それ以外は2（5.12。範囲は X の公式の説明で確かめる）
int xWeightedLength(String text);

/// X は 280（重み付き）、Instagram は 2200（素の文字数）
int captionLimit(ShareTarget t);
bool isCaptionTooLong(ShareTarget t, String caption);

/// 画像に入れる文字（上限で切ったあと）
class ShareImageText {
  const ShareImageText(this.setShown, this.setMore, this.memoShown, this.memoCut);
  final List<String> setShown; // 先頭 maxSetlist 曲
  final int setMore;           // 切った曲数（0なら無し）
  final String memoShown;      // maxMemoChars を超えたら、先頭 maxMemoChars 文字＋'…'
  final bool memoCut;
}
ShareImageText layoutShareText(ShareContent c, ShareFormat f);
```

**`lib/utils/google_photos_errors.dart`**（純粋関数）

```dart
/// 画面に出す日本語の文言（4.11）。例外の中身・コード・トークンを含めない。
/// GooglePhotosException の kind で選ぶ。知らない例外は「通信できませんでした。…」ではなく
/// 「Googleフォトを使えませんでした。しばらくしてからもう一度お試しください。」
String googlePhotosErrorMessage(Object error);
```

**`lib/services/google_photos_service.dart`**（カレンダーと同じ認可＋ Picker API）

```dart
enum GooglePhotosFailure {
  cancelled, popupBlocked, accountMismatch, accountInUse, noToken,
  apiUnavailable, timeout, noneSelected, network, other,
}

/// 文言を持たない。email は accountMismatch の文言に使う
class GooglePhotosException implements Exception {
  const GooglePhotosException(this.kind, {this.email});
  final GooglePhotosFailure kind;
  final String? email;
}

class PickerSession {
  const PickerSession({required this.id, required this.pickerUri,
      required this.pollInterval, required this.timeoutAt, required this.mediaItemsSet});
  final String id; final Uri pickerUri;
  final Duration pollInterval; // 無ければ 5 秒
  final DateTime timeoutAt;    // 作った時刻 + timeoutIn
  final bool mediaItemsSet;
}

class PickedItem {
  const PickedItem({required this.id, required this.baseUrl, required this.mimeType,
      this.createTime, this.width, this.height});
  final String id; final String baseUrl; final String mimeType;
  final DateTime? createTime; final int? width, height;
}

/// 画面・状態はこの抽象だけに依存する（テストは偽物に差し替える）
abstract class GooglePhotosApi {
  /// このタブで権限（トークン）を持っているか
  bool get hasToken;
  /// ポップアップで権限を求める（カレンダーの `_accessToken()` と同じ分岐）。
  /// **つなぐボタンの処理の中で、最初に呼ぶ**。失敗は GooglePhotosException
  Future<void> authorize();
  Future<PickerSession> createSession({int maxItemCount = 30});
  Future<PickerSession> getSession(String sessionId);
  /// 全ページ。動画は除く。maxPickCandidates 枚まで
  Future<List<PickedItem>> listPickedItems(String sessionId);
  /// baseUrl に =w{maxSide}-h{maxSide} を付け、Authorization つきで取る
  Future<Uint8List> fetchImage(PickedItem item, {required int maxSide});
  /// 失敗しても例外を投げない
  Future<void> deleteSession(String sessionId);
}

class GooglePhotosService implements GooglePhotosApi {
  GooglePhotosService(this._auth, {http.Client? client,
      Future<String> Function()? tokenForTest});
  // scope = 'https://www.googleapis.com/auth/photospicker.mediaitems.readonly'
  // baseUrl = 'https://photospicker.googleapis.com/v1'
  // トークンは 50 分、メモリーだけ。ログ・例外・state に出さない
}
final googlePhotosApiProvider = Provider<GooglePhotosApi>(
    (ref) => GooglePhotosService(FirebaseAuth.instance));
```

**`lib/services/photo_pick_ai.dart`**（Gemini の写真えらび。`GeminiService` は変えない）

```dart
enum PhotoDecision { pick, candidate, skip }
enum SkipKind { duplicate, blurry, screenshot, unrelated, other }

class PhotoJudgement {
  const PhotoJudgement(this.index, this.decision, {this.rank, this.label, this.skipKind});
  final int index; final PhotoDecision decision;
  final int? rank; final String? label; final SkipKind? skipKind;
}

class PhotoPickCandidate {
  const PhotoPickCandidate(this.bytes, this.mimeType, {this.createTime});
  final Uint8List bytes; final String mimeType; final DateTime? createTime;
}

class PhotoPickRequest {
  const PhotoPickRequest({required this.title, required this.startAt,
      required this.venue, this.artist, required this.candidates});
  final String title; final DateTime startAt; final String venue;
  final String? artist; final List<PhotoPickCandidate> candidates;
}

/// 4.5 の後処理。どんな json でも例外を投げず、count 個すべてに判定を返す
/// （返ってこなかった番号は candidate・pick は maxPicks 枚まで・label は10文字まで）
List<PhotoJudgement> parsePhotoPick(Object? json, int count, {int maxPicks = 4});

/// 固定の理由の文（4.5）
String skipReasonText(SkipKind? kind);

abstract class PhotoPickAi {
  /// 失敗（再試行のあとも）は例外を投げる。呼び出し側が「AIが選べなかった」にする
  Future<List<PhotoJudgement>> choose(PhotoPickRequest request);
}

class GeminiPhotoPickAi implements PhotoPickAi { /* gemini-3.5-flash-lite・最大3回・60秒 */ }
final photoPickAiProvider = Provider<PhotoPickAi>((ref) => GeminiPhotoPickAi());
```

**`lib/providers/memory_ticket_providers.dart`**（記録の保存の窓口。画面は `MemoryRepository` を直接呼ばない）

```dart
class MemorySaveResult {
  const MemorySaveResult(this.memory, {required this.publicSynced});
  final LiveMemory memory;     // 保存したあとの記録
  final bool publicSynced;     // 公開の写しを書けたか（公開していなければ true）
}

class MemoryEditor {
  /// 座席・セトリ・感想を保存する（前後の空白を除き、空なら項目を消す）。
  /// 公開中なら、公開の写しも書き直す。記録の保存に失敗したら例外
  Future<MemorySaveResult> saveFields(LiveMemory memory,
      {String? seat, required List<String> setlist, String? impression});

  /// 写真の並びを保存する。順は「新しい写真をアップロード → 記録を保存 → 公開の写し →
  /// 外した写真を消す」（memory_form_page.dart の `_save` と同じ。失敗の扱いも同じ:
  /// 上げた分は消す・写しを書けなかったら外した写真は消さない）
  Future<MemorySaveResult> savePhotos(LiveMemory memory, List<PhotoItem> items);

  /// 公開・座席の公開を保存し、公開の写しを書く・消す（add_K 5.1 の `_syncPublic` と同じ）
  Future<MemorySaveResult> setPublic(LiveMemory memory,
      {required bool isPublic, required bool publicSeat});

  /// postedAt を書く。すでにあれば何もしない。失敗しても例外を投げない
  Future<void> markPosted(LiveMemory memory);
}
final memoryEditorProvider = Provider<MemoryEditor>(/* リポジトリ・ログイン中の uid を読む */);

/// 画面用: 記録 + 出演者名（allOshisProvider から引く）+ 写真の数 → ShareContent。
/// 記録が無ければ null。読み込み中・エラーは AsyncValue のまま
final shareContentProvider =
    Provider.autoDispose.family<AsyncValue<ShareContent?>, String>(/* performanceId */);
```

**`lib/providers/photo_pick_providers.dart`**（Google フォトの選択の状態機械）

```dart
enum PhotoPickStage { idle, authorizing, waitingPicker, fetching, analyzing, done, failed }

class PickCandidate {
  const PickCandidate({required this.item, required this.thumb, this.judgement});
  final PickedItem item; final Uint8List thumb; final PhotoJudgement? judgement;
}

class PhotoPickState {
  final PhotoPickStage stage;
  final PickerSession? session;          // waitingPicker のとき
  final List<PickCandidate> candidates;  // done のとき
  final List<int> selected;              // 選んだ候補の番号（表紙が先頭）。最大 8 から既存の枚数を引いた数まで
  final bool aiFailed;                   // Gemini が失敗した（全部「ほかの候補」）
  final String? error;                   // 4.11 の文言（googlePhotosErrorMessage の結果）
  bool get busy; // authorizing / fetching / analyzing / 待ちのとき true
}

class PhotoPickNotifier extends Notifier<PhotoPickState> {
  /// **つなぐボタンの処理の最初に呼ぶ**（ポップアップ。同意は ui が先に取る）。
  /// authorize → createSession → waitingPicker。二重に呼んでも始めない（busy のとき無視）
  Future<void> begin({required PhotoPickRequestInfo info, required int remainingSlots});
  /// waitingPicker のあと: ポーリング → 一覧 → 縮小版 → Gemini → done。
  /// ui が「Googleフォトを開く」を押して pickerUri を開いた直後に呼ぶ
  Future<void> waitForSelection();
  /// やめる／シートを閉じる。ポーリングを止め、セッションを消し、idle に戻す。世代番号で古い処理を無視する
  void cancel();
  void toggle(int candidateIndex); // 選ぶ／外す（上限を超える選択は無視）
  /// 「決定」: 選んだ候補の大きい写真（長辺 photoMaxSide）を取り、NewPhoto にして返す。
  /// 取れなかったら例外（ui が 4.11 の文言を出す）。5MB を超えたら再圧縮はせず「取り込めませんでした」
  Future<List<NewPhoto>> materializeSelected();
}
final photoPickProvider =
    NotifierProvider.autoDispose<PhotoPickNotifier, PhotoPickState>(PhotoPickNotifier.new);

/// 同意のダイアログを、このタブで出したか（保存しない。4.4.2）
final googlePhotosConsentedProvider = NotifierProvider<ConsentNotifier, bool>(ConsentNotifier.new);
```

**`lib/providers/share_providers.dart`**（投稿の画面の状態。保存しない）

```dart
class ShareState {
  final ShareTarget target;                       // 既定 x
  final Map<ShareTarget, ShareConfig> configs;    // 既定 ShareConfig.defaults
  final Map<ShareTarget, String?> captionOverride;// 手直し済みの文章（null なら自動）
  final bool imageSaved, captionCopied;           // Instagram の番号の丸の色
}
class ShareNotifier extends Notifier<ShareState> {
  void selectTarget(ShareTarget t);               // 形は 1 つめに戻す
  void toggle(SharePart p, ShareLayer l);         // 文章の手直しは捨てない（4.6。手直し済みの文章は resetCaption まで残す。リーダー判断 11/8）
  void setFormat(int i); void setDesign(ShareDesign d); void setBackground(int i);
  void setCaption(String text);                   // 手直し済みにする
  void resetCaption();
  void markImageSaved(); void markCaptionCopied();
}
final shareProvider = NotifierProvider.autoDispose
    .family<ShareNotifier, ShareState, String>(/* performanceId。初期の target は引数かクエリ */);
/// 今の自動の文章 or 手直しの文章
String currentCaption(ShareState s, ShareContent c);
```

**`lib/models/live_memory.dart` に足すもの**: `final DateTime? postedAt;`（`fromFirestore` で `toDateTime(data['postedAt'])`・`copyWithContent` は今の値を引き継ぐ・`toFirestore` には入れない）。
**`lib/repositories/memory_repository.dart` に足すもの**: `Future<void> markPosted(String uid, String performanceId)`（`update({'postedAt': FieldValue.serverTimestamp()})`。`updatedAt` は変えない）。

**`lib/utils/file_download.dart`**（ui-share。条件付きの import）

```dart
export 'file_download_stub.dart'
    if (dart.library.js_interop) 'file_download_web.dart';
// どちらも: Future<void> downloadBytes(Uint8List bytes, String fileName, {String mimeType = 'image/png'});
// stub は UnsupportedError を投げる（テストでは差し替える）
```

**`lib/features/memory/share/share_ticket_view.dart`**（ui-share）

```dart
/// プレビュー・ホームのミニのカード・保存する画像で共通。**座席の引数は無い**
class ShareTicketView extends StatelessWidget {
  const ShareTicketView({super.key, required this.content, required this.config,
      required this.target, required this.photoBytes, this.hints = false,
      this.mini = false, this.onTapPart});
  final ShareContent content; final ShareConfig config; final ShareTarget target;
  final List<Uint8List> photoBytes;   // 表紙から順。描く前に読み込み済みのもの
  final bool hints;                   // 空の枠（+ セトリを書く…）とタップの枠線を出す（プレビューだけ）
  final bool mini;                    // ホームのカード用（hints は無視）
  final void Function(SharePart part)? onTapPart; // photo・setlist・memo
}
/// RepaintBoundary の GlobalKey から PNG を作る。pixelRatio は outWidth / 表示の幅
Future<Uint8List> captureShareImage(GlobalKey boundaryKey, {required double pixelRatio});
```

## 8. 既存のテストの扱いと、足すテスト

- **ロジックは変わらない**（足すだけ）。既存のメモリー・写真・公開のテストは、**画面（`MemoryDetailPage`）を作り替えるもの以外**は、そのまま通るはず（通らないなら、まず実装のバグを疑う）。
- **直すテスト**（qa。期待を弱めない）:
  - `test/features/memory_pages_test.dart` の詳細画面のテスト: 詳細の作りが変わる（チケット・「直す」・固定のバー）。**変わる振る舞い**（キーの名前・「編集」ボタンが残ること・ライブ名・日時・会場・座席・セトリ・感想・写真の表示・公開の札）を `ui-record` が qa に送ってから、期待を新しい作りに合わせる（**既存のキー `memory_detail`・`memory_detail_edit_button`・`memory_detail_state`・`memory_detail_public`・`memory_detail_photos`・`memory_detail_loading`・`memory_detail_error`・`memory_detail_not_found` は残す**。残せないものは、リーダーに報告）。
  - メモリーのリポジトリの偽物（`markPosted` を足す・呼ばれた引数の記録）。写真のリポジトリの偽物（そのままで足りるはず）。`LiveMemory` を作るテストの共通の関数があれば `postedAt` を足す。
  - `home_page_test.dart`: 新しいウィジェットを足しても、既存の区画の表示が変わらないこと（バナーの有無の確認を足す）。
  - `app_shell_test.dart` などでルートを数えているものがあれば、新しいルートに合わせる。
- **テストの書き方の約束**:
  - キーは、タップを受ける部品自身に付ける。押す前に `tester.ensureVisible`。
  - 書体は `test/flutter_test_config.dart` が取りに行かない設定にしてくれる。例外が出るなら書体を変えて回避しない（リーダーに報告）。
  - 画面の大きさは `tester.view.physicalSize` と `devicePixelRatio = 1`（終わりに `addTearDown(tester.view.reset)`）。文字の拡大は `tester.platformDispatcher.textScaleFactorTestValue = 1.3`（終わりに `clearTextScaleFactorTestValue`）。
  - 時刻は `nowProvider.overrideWithValue(DateTime(...))` で固定する。待ち時間（ポーリング）は、偽物の `GooglePhotosApi` の `pollInterval` を短くし、`tester.pump(Duration)` で進める（本物の時間を待たない）。
  - **Google・Gemini・ネットワーク・ダウンロード・クリップボードは、すべて偽物に差し替える**（`googlePhotosApiProvider`・`photoPickAiProvider`・`downloadBytes` の差し替え口）。**本物のトークン・写真・メールアドレスをテストに書かない**（架空の値）。
  - 失敗するテストを `test/` に置いたままにしない。
  - 画面や偽物を書き換える前に、担当の `photos-data`・`ui-record`・`ui-share` は `qa` に「テスト更新依頼: <タスクID>、変わる振る舞い、落ちるはずのテスト」を送る。

**足すテスト（qa）**

- `memory_ticket_test.dart`（純粋関数）: `memoryProgress`（0〜4・座席が空白だけ・感想が空白だけ・写真0枚）、`recentUnpostedMemory`（ちょうど7日・8日・参戦予定は除く・`postedAt` ありは除く・複数から最新・空の入力で null）
- `share_ticket_test.dart`（純粋関数）: `parseSetItems`（`1. ` `2) ` `３、` `4: ` の除去・空行・前後の空白・番号だけの行）、`oneLine`、`formatShareDate`（日本時間の日付・曜日 3文字・深夜0時の境目）、`formatCaptionDate`、`hashtagsOf`（2つまで・空白除去・`#おしあし` が最後・空のとき `#おしあし` だけ）、`buildCaption`（**X・Instagram の既定のとおり／各部分のオンオフ／ライブ名だけ／セトリの全曲／感想の改行が空白になる／タグの有無／座席が出ないこと**。`ShareContent` に座席の項目が無いので、座席が入らないことはコンパイルで守られる。座席を渡す手段が無いことを、テストの冒頭のコメントに書く。座席の文字列そのものを確かめるテストは、画面のテスト `share_page_test.dart` で行う）、`xWeightedLength`（英数字1・日本語2・絵文字・改行・境目のコードポイント）、`captionLimit`・`isCaptionTooLong`（X は日本語140字ちょうどで通り、141字で超える・Instagram は素の2200）、`layoutShareText`（各形の上限・ちょうど上限・超える・空・感想が `…` で終わる）、`ShareConfig`（既定・`toggled` が許さない組み合わせを無視する・`copyWith`）
- `google_photos_errors_test.dart`: 種類ごとの文言（4.11 のとおり・例外の中身・メールを含む場合のみ `accountMismatch` に含む・知らない例外・トークンらしい文字列が出ない）
- `google_photos_service_test.dart`（`http.Client` の偽物＋`tokenForTest`）: セッション作成（リクエストの URL・`Authorization`・本文）→ `PickerSession` の変換（`pollInterval` の文字列 `"5s"`・無いとき 5 秒・`timeoutAt`）／`getSession`／`listPickedItems`（複数ページ・動画の除外・30枚で打ち切り・入れ子の2通りの形）／`fetchImage`（`=w768-h768` が付く・`Authorization` つき・200以外は例外）／403 → `apiUnavailable`／ネットワークの失敗 → `network`／`deleteSession` が失敗しても投げない／**トークンが例外・ログに出ない**
- `photo_pick_ai_test.dart`: `parsePhotoPick`（正常・範囲外の番号・重複・返ってこない番号・`pick` が5枚以上・`rank` なし・知らない `skipKind`・`label` が11文字以上・JSON が配列でない・null・空）、`skipReasonText`、`GeminiPhotoPickAi` は呼ばない（偽物でリクエストの組み立て＝番号つきの順序・メタ情報だけを確認）
- `photo_pick_notifier_test.dart`（偽の `GooglePhotosApi`・偽の `PhotoPickAi`）: 正常（begin → waitingPicker → waitForSelection → fetching → analyzing → done・既定の選択＝`pick` の `rank` 順）／二重の `begin` は始めない／認可の失敗（`cancelled` など）→ failed とエラー文・idle に戻せる／何も選ばれなかった／タイムアウト／縮小版が1枚も取れない／一部だけ取れない（飛ばす）／Gemini が失敗 → `aiFailed`・全部「ほかの候補」・選択は空／`cancel` でポーリングが止まりセッションが消える／キャンセル後に古い処理が state を書き換えない／`toggle` の上限／`materializeSelected`（大きい写真を取る・失敗で例外）／**トークン・写真のバイト列がログに出ない**
- `memory_editor_test.dart`（偽のリポジトリ）: `saveFields`（空白を除く・空なら消す・公開中なら写しを書き直す・写しの失敗は `publicSynced: false` で記録は保存済み・記録の保存の失敗は例外で写しを書かない）／`savePhotos`（アップロード失敗で上げた分を消して例外・記録の保存失敗で上げた分を消す・外した写真が消える・写しの失敗では外した写真を消さない）／`setPublic`／`markPosted`（すでにあれば呼ばない・失敗しても投げない）
- `share_notifier_test.dart`: 既定・`selectTarget`（形が1つめに戻る）・`toggle`（文章の手直しが残る）・`setCaption`・`resetCaption`・投稿先ごとに設定が別々
- 画面のテスト: `memory_ticket_page_test.dart`（チケットの内容・0枚の枠・座席／セトリ／感想をタップして編集カード・決定で保存・失敗で残る・同時に1つ・進み具合・参戦済みだけに固定のバー・参戦予定には出ない・4状態・幅 320〜1000×文字 1.0／1.3 倍）、`photo_sheet_test.dart`（状態①〜④・同意のダイアログ「今はしない」「つなぐ」・2回目はダイアログなし・「Googleフォトを開く」・やめる・「端末から追加」・ほかの候補の追加・外す・上限8枚・決定で保存・失敗の文言）、`share_page_test.dart`（タブ・既定のチップ・チップのオンオフで文章が変わる・文章を直したら自動で変わらない・「自動で作った文章に戻す」・超過で X のボタンが押せない・Instagram の3ステップ（偽のダウンロード・クリップボード）・投稿したら `markPosted`・**座席の文字列が画面の画像の部分にも文章にも出ないこと（記録の座席に目印の文字を入れて確認）**・プレビューの部分をタップで編集シート・決定で保存・幅 320〜1000×文字 1.3 倍）、`share_ticket_view_test.dart`（0〜3枚・セトリが上限で切れて「ほか○曲」・感想が `…`・`hints` のときだけ空の枠・`mini` では出ない・座席の引数が無い）、`home_memory_banner_test.dart`（出る・投稿済みで消える・8日前で出ない・参戦予定で出ない・ボタンで投稿の画面へ・4状態）、`photos_test_page_test.dart`（P2。あれば）
- ロジックが変わっていないこと: 既存のメモリー・写真・公開・カレンダーのテストがそのまま通る

## 9. タスク一覧

リーダーが共有タスクリストに、担当と依存関係を付けて登録する。**P1 は `photos-data` の仕事が多いので、順番は D1 → D3 → D2 → D4 → D5**（画面は偽物・抽象のインターフェースで先に進める）。

| ID | 優先 | 担当 | 内容 | 依存 |
|---|---|---|---|---|
| L0 | | リーダー | 0章の確認、5章をユーザーに聞く、判断ログ、12.0 の準備をユーザーに頼む | |
| T0 | | qa | 品質ゲートの確認。8章の「直すテスト」の一覧をリーダーに送る | |
| D1 | P1 | photos-data | `memory_ticket.dart`・`share_ticket.dart`（7章の純粋関数）。**先に契約（7章の全部）を ui-record・ui-share・qa に全文で送る** | L0 |
| D3 | P1 | photos-data | `google_photos_errors.dart`・`google_photos_service.dart`（認可はカレンダーの書き写し・Picker API・縮小版）。**これが終わったら、リーダーに「G0 を始められる」と知らせる** | D1 |
| D2 | P1 | photos-data | `LiveMemory.postedAt`・`MemoryRepository.markPosted`（**先に qa へテスト更新依頼**）・`MemoryEditor`・`shareContentProvider` | D1 |
| D4 | P1 | photos-data | `photo_pick_ai.dart`（`parsePhotoPick`・`GeminiPhotoPickAi`） | D1 |
| D5 | P1 | photos-data | `photo_pick_providers.dart`（状態機械・同意の印）・`share_providers.dart` | D3, D4, D2 |
| G0 | P1 | ui-record＋人間 | **技術の確認（5.17）**: `/photos-test`（接続テストの画面。認可 → セッション → 選択画面 → 一覧 → 縮小版 → Gemini を1画面で試す。**画面には、JSON のキーの一覧・件数・バイト数・所要時間・結果の判定だけを出す。トークン・写真そのものは出さない**）を作り、人間が 12.1 の 5〜10 を行う。結果をリーダーが判断ログと 4章・5章に反映 | D3, D4（偽物の Gemini でも画面は作れる） |
| U1 | P1 | ui-record | 記録のチケットの画面（4.2）。座席・セトリ・感想の編集カード・進み具合・固定のバー・4状態。`MemoryEditor`（偽物で先に）につなぐ。**先に qa へテスト更新依頼**（詳細画面のテスト） | D1, D2 |
| S1 | P1 | ui-share | `ShareTicketView`（チケットのデザイン・縦と横・0〜3枚・上限で切る・`hints`・`mini`）・`captureShareImage`・`file_download`（pubspec の `web`）。**最初に、`MemoryShareScreen` の空の入れ物と、`ShareTicketView` の引数の形を ui-record に送る**（ルートとホームのカードのため） | D1 |
| U2 | P1 | ui-record | `lib/features/photos/`: `MemoryPhotosSection`（4.3 の状態①〜④）・「写真を直す」シート・同意のダイアログ（4.4.2）・つなぐ流れ（`photoPickProvider`）・「Googleフォトを開く」（`launchUrl`）。`app.dart` に投稿のルートと `/photos-test` を足す | D5, U1 |
| S2 | P1 | ui-share | 投稿の画面（4.6・4.8）: タブ・プレビュー・チップ・文章・X／Instagram の動作・編集シート（セトリ・感想。写真は `MemoryPhotosSection`）・`markPosted` | S1, D5, U2 |
| U3 | P1 | ui-record | ホームのカード（4.9）。`home_page.dart` に1行。`ShareTicketView(mini)` を使う | S1, D2 |
| U4 | P2 | ui-record | 一覧の「新しい記録」・公開スイッチ（4.2・4.9） | U1 |
| S3 | P2 | ui-share | 他の2つのデザイン・背景色・他の画像の形・「選ばなかった写真と理由」（4.3・4.6・4.7） | S2 |
| Q1 | | qa | 純粋関数・エラー文言のテスト | D1, D3 |
| Q2 | | qa | 偽物の更新、サービス・AI の後処理・状態・`MemoryEditor`・`ShareNotifier` のテスト | D2, D4, D5 |
| Q3 | | qa | 画面のテスト（8章の画面のテスト） | U2, S2, U3 |
| C1 | | ui-record・ui-share | 掃除: 使われなくなったコード・import・仮データを消し、`flutter analyze` を0件にする | U3, S2 |
| R1 | | qa | まとめレビュー（11章） | すべて |
| L1 | | リーダー | 結合確認、`git diff --stat` で差分が6章の範囲だけであることの確認、ユーザーへの動作確認手順（12章）、5.17 の結果の記録、`markdown/deploy_手順.md` の追記、判断ログ、コミット案 | すべて |

## 10. バグを防ぐための進め方

1. **担当外のファイルは編集しない。** 直してほしい箇所は担当者に SendMessage で伝える。
2. **契約を先に決める。** D1 が終わるまで、`ui-record`・`ui-share`・`qa` は `memory_ticket.dart`・`share_ticket.dart` などに依存する部分を書かない（4章を読み込むのは先に進めてよい）。画面は、`GooglePhotosApi`・`PhotoPickAi`・`MemoryEditor` の**抽象と偽物**に対して先に作ってよい。
3. **各タスクの最初に、方針を3〜5行でリーダーに送る。返事を待たずに書き始める。**（`dev-ui`・`dev-data`・`dev-qa` の定義には「返事を待つ」とあるが、**この計画書とチームメイト作成時の指示が優先**する。全員が返事待ちで止まるのを避ける。）リーダーは、方針に問題があるときだけ返事をする。タスクを終えたら、完了報告を送ったあと、依存が解けている次のタスクへ**すぐに進む**。
4. **作業ツリーを壊れたまま放置しない。** `MemoryRepository` にメソッドを足すときは、qa が偽物を直すのと同じタイミングにする（`flutter test` が止まらないように）。
5. **品質ゲート:** タスクを完了にするたびに、`.claude/hooks/quality-gate.sh` が動く。失敗すると完了が差し戻される。
6. **見た目は数値で合わせ、見本で確かめる。** 4章の数値と見本の CSS を見比べる。見本の HTML を別のタブで開いて並べて確かめるのは、人間（12章）。
7. **実装タスクを終えたら、`qa` にレビューを依頼する。** `qa` はレビュー依頼を最優先で処理する。
8. **カレンダーを変えない。** `google_calendar_service.dart`・`calendar_add_sheet.dart`・`/calendar-test` は読むだけ。**書き写したものを、あとで共通にしない**（5.4）。
9. **秘密情報・個人の情報を残さない。** **アクセストークン・`baseUrl`・写真のバイト列・メールアドレス・座席**を、ログ（`debugPrint` を含む）・例外のメッセージ・画面のエラー・`state` のうち不要な場所・テストの出力・コミットに出さない。テストのメールアドレス・トークン・URL は `example.com` などの架空の値にする。
10. **座席を SNS に出さない。** 画像・文章・URL（X の投稿画面のクエリ）・クリップボードのどこにも、座席が入らない。`ShareContent` に座席を持たせない（7章）。レビューでも必ず見る。
11. **ポップアップは、ボタンを押した処理の中で最初に呼ぶ。** `await` を挟んでから `authorize()` を呼ばない。`pickerUri` を開くのは、利用者の2回目のボタン（4.4.3 の4）。
12. **例外の文字列を画面に出さない。** `'$e'` を `Text` に入れない（カレンダーの書き方を真似しない）。必ず `googlePhotosErrorMessage` か 4.11 の文言を通す。
13. **古い処理に state を書かせない。** 認可・ポーリング・Gemini のあいだに利用者がやめた・画面を閉じたとき、あとから返ってきた結果で state を書き換えない（世代番号か `ref.mounted`）。ポーリングは必ず止まる。セッションは消す。
14. **判断を記録する。** 比べた案・選んだ理由・捨てた案は、リーダーが `notes/判断ログ_memory_ticket.md` に追記する（5章の回答と、5.17 の動作確認の結果を必ず含める）。

## 11. レビューの観点

- 見た目: 4章の数値どおりか（色・大きさ・余白・枠・角丸・影）。チケットの切り欠き・ミシン目・半券。シェア画像の割合の大きさ（`unit = width / 100`）。0〜3枚の写真の並べ方。横長と縦長
- 書体: `HakoFonts` を通しているか（`GoogleFonts.` の直書きが無いか）。**太さは 700 まで**（見本の 800・900 を 700 にしているか）
- 安全（最重要）:
  - **座席が、画像・文章・X の URL・クリップボードのどこにも出ていないか**（`ShareContent`・`ShareTicketView` が座席を持っていないか）
  - **トークン・`baseUrl`・写真のバイト列・メールが、ログ・例外・画面・`state` の不要な場所に残っていないか**
  - **例外の文字列を画面に出していないか**（`'$e'`）
  - Gemini に送るのが、縮小版の画像とライブ名・日時・会場・アーティスト名だけか（元の写真・位置情報・利用者の名前・メールを送っていないか）
  - 候補の写真を保存していないか（「決定」した写真だけを Storage へ）
  - `Firebase*.instance` を画面から直接呼んでいないか（プロバイダ・`MemoryEditor` 経由）
- カレンダーと同じ要領か: 認可の分岐（`google.com` の有無・`reauthenticateWithPopup`／`linkWithPopup`・`login_hint`・エラーの扱い）・トークンの50分・保存しない・「最初に呼ぶ」。**違う点は 4.4.1 の表のものだけ**か
- 流れ: 二重に始めない・やめる・シートを閉じる・画面を離れる・ポップアップを閉じる・タイムアウト・何も選ばれない・Gemini の失敗で、どれも画面が壊れず、写真を失わないか。ポーリングが止まるか。セッションが消えるか。`await` の後の `context.mounted`
- Gemini: `parsePhotoPick` がどんな返り値でも例外を投げないか。選ぶ枚数の上限が守られているか。理由が固定の文か（Gemini の自由な文を画面に出していないか）
- 保存: 保存の順と失敗の扱いが `memory_form_page.dart` と同じか。公開中の記録の写しが、写真・セトリ・感想の変更のあとも合っているか。外した写真が消えるか／写しが書けなかったときは消えないか。`postedAt` が `updatedAt` を動かしていないか
- 編集: 同時に開く編集カードが1つか。決定で保存・失敗で残るか。保存中に二重に押せないか。入力中の `TextEditingController.text` を書き換えていないか
- 表示の条件: 固定の「まとめて編集して投稿」が参戦済みの記録だけか。ホームのカードが「新しい記録」だけ（7日・`postedAt` なし）か。空の枠（`+ セトリを書く`）が、保存する画像・ミニのカードに出ていないか
- 文言: 4.11・4.6・4.8・4.9 と一字一句同じか（全角の `（` `）` `：` `！` `？`）。**見本の「自動で選べます」「会場の近くで撮った」「（デモ）」「このデモでは省略しています」「予約情報から自動入力」「下書き（自動作成）」が残っていないか**
- 既存の動作: 既存のキーが残っているか（8章）。メモリーの作成・編集・削除・公開・共有（add_K）・カレンダーの動作が変わっていないか
- 動き: `disableAnimations` のとき、シート・ダイアログ・バー・トーストが動かないか
- ロジック・共有: **`git diff --stat` で、変わったファイルが6章の編集してよいファイルと文書だけか**。`pubspec.yaml` の差分が `web` の1行だけか。`firestore.rules`・`storage.rules`・`functions/**` の差分が無いか。画像・書体の追加が無いか
- はみ出し: 幅 320・360・390・430・720・1000・文字 1.3 倍・キーボードあり。シェア画像の中の文字が端末の文字の拡大に影響されていないか
- テスト: 期待を弱めていないか。純粋関数・サービス・状態・画面にテストがあるか。偽物を直したあと、既存のテストがすべて通るか。**本物の Google・Gemini・ネットワークを呼んでいないか**

## 12. 人が行う設定と動作確認

### 12.0 開始前の準備（L0。リーダーが行う。人間が行うものを含む）

1. `git status -sb`（ブランチが `redesign/memory` か）。
2. 作業ツリーに、この作業と関係のない未コミットのファイルがあれば、**触らない。コミットに混ぜない**（コミットする前に、リーダーが含めるファイルをユーザーに示す）。
3. **人間が行うもの（Google フォトの「権利関係」。カレンダーのときと同じ場所・同じ手順）**。**設定を変えるのは人間**（エージェントは `firebase deploy` も、Google Cloud・Firebase の設定の変更もしない）。リーダーは、結果を `markdown/deploy_手順.md` の「2.4 Google フォト連携」に書き足す。
   1. **Google Cloud コンソール**（Firebase プロジェクトと同じプロジェクト）→ API とサービス → ライブラリ →「**Photos Picker API**」を**有効にする**。
   2. **OAuth 同意画面**（Google Auth Platform）→ データアクセス（スコープ）→ スコープを追加 → `https://www.googleapis.com/auth/photospicker.mediaitems.readonly`。**このスコープが「機密性の高い」「制限付き」のどれに分類されるかを、画面の表示で確かめ、判断ログに書く**（5.17 ③）。
   3. **公開ステータスが「テスト」のまま**、テストユーザーに、デモに使う Google アカウントと、チームのアカウントを足す（カレンダーで登録済みのものは、そのままでよい）。**審査員が自分のアカウントでつなぐと失敗するかもしれない**ので、提出物の説明か動画で「Google フォトの連携はテストユーザーのみ。つながなくても『端末から写真を追加』で使える」と書く（5.6）。
   4. アプリ名・サポートのメールアドレスが入っていること（カレンダーで済んでいるはず）。
   5. **Google の「Google Photos API の利用規約」と「API サービスのユーザーデータポリシー（Limited Use）」を読み、写真を AI（Gemini）に送ることが許されるかを確かめる**（判断は人間。**許されない・不明なら、5.5 と 4.5 を直す**＝Gemini に送らず、利用者が自分で選ぶだけにする。リーダーに報告）。
   6. Firebase コンソール → AI Logic で、Gemini Developer API が有効（スクショ読み取りが動いていれば済み）。**複数の画像（30枚）を1回で送る呼び出しが、割り当ての範囲に収まるか**を、G0 で確かめる。
   7. **Cloud Storage の CORS**（G0 で④が通らなかったときだけ）: 次の内容で、人間が `gsutil cors set <ファイル> gs://<バケット名>` を実行する（`localhost` と公開先のドメイン。例は架空）。

   ```json
   [
     {
       "origin": ["http://localhost:8080", "https://example-oshiashi.web.app"],
       "method": ["GET"],
       "maxAgeSeconds": 3600,
       "responseHeader": ["Content-Type"]
     }
   ]
   ```

### 12.1 動作確認（人が行う。Dev Container で `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080`、Chrome で `http://localhost:8080`。**テストユーザーの Google アカウントでログインして行う**。参戦済みの記録（開演が過ぎた記録）を1件用意する）

1. Chrome の開発者ツール → 端末のツールバーで幅 **390** にする。**別のタブで `markdown/design_memory_ticket/oshiashi_memory_3_tap_ticket.html` を開き、並べて見比べる**（記録のチケット・投稿の画面・シェア画像・ホームのカード）。見本は端末の書体なので、文字の形は少し違う。
2. 記録の画面: チケット風になっている。座席・セトリ・感想をタップすると、その場で編集カードが開き、「決定」で保存される（再読み込みしても残る）。進み具合が変わる。
3. 写真が0枚の記録: 「写真はまだありません」＋「Googleフォトとつなぐ」。押すと同意のダイアログ → 「つなぐ」でポップアップ。**5.17 ③: 同意画面の見た目（「未確認のアプリ」の画面が出るか・テストユーザーでないとブロックされるか）を記録する。**
4. 「つながずに、写真を自分で追加する」で、端末から写真を入れられる（Google フォトにつながなくても使える）。
5. **G0（`/photos-test`）**: 認可 → セッション作成 → 選択画面（新しいタブ）で写真を数枚〜30枚選んで完了 → 一覧 → 縮小版の取得。**5.17 ①: JSON のキーの一覧（`createTime`・幅・高さ・位置情報の有無）を記録する。② `baseUrl` の取得が CORS で通ったか。**通らなかったら、リーダーに伝える（Cloud Functions の代案を相談する）。
6. `/photos-test` で Gemini の写真えらび（縮小版を送る）: **⑤ 30枚で、何秒で返るか・エラーが出ないか**を記録する。選ばれた写真・ラベル・選ばなかった理由が、それらしいか。
7. 記録の画面から写真のシートを開き、Googleフォトから選ぶ（本番の流れ）: 段階の文が変わる → 「Googleフォトを開く」→ 新しいタブで選ぶ → 自動で閉じる → 4枚が選ばれ、紫の説明・ほかの候補が出る。「×」で外す・候補を追加できる。「決定」で保存され、チケットの写真が変わる。
8. 選択画面で何も選ばずに閉じる・途中でシートを閉じる・ポップアップを閉じる: エラーの文が出て、画面が壊れない。閉じたあと、エラーや処理の続きが出ない。
9. 「まとめて編集して投稿」: 投稿の画面が開く。X／Instagram のタブで、のせる部分の既定が見本のとおり（4.6 の表）。チップを押すと文章が変わる。文章を直したあとは、チップを押しても直した文章が消えない場合と、「自動で作った文章に戻す」で戻る。**座席が、画像にも文章にも出ていない**（記録の座席に目印の文字を入れて確かめる）。
10. プレビューの写真・セトリ・感想をタップ → 編集シートで直せる。プレビューがその場で変わる。決定で記録に保存される。
11. 「画像を保存」: PNG が保存される。**④ 開いて、写真が空白になっていないか・文字が崩れていないか**を確かめる（空白なら、12.0 の 7）。X の横長（16:9）・Instagram のフィード（4:5）で、チケットの形・半券・「おしあし」マークが見本に近い。
12. 「Xで投稿画面を開く」: 文章が入った X の投稿画面が新しいタブで開く（**⑥ スマホのブラウザでも確かめる**）。文字数が多いと押せなくなる（日本語は140字ほど）。
13. Instagram: ①画像を保存 ②文章をコピー（貼り付けて確かめる）③Instagram を開く。
14. 投稿したあと、ホームの「ライブお疲れさまでした！」のカードが消える。開演から8日たった記録・参戦予定の記録・投稿前の記録で、カードの出方が合っている。
15. 幅 320・720 以上（PC）・文字 1.3 倍・キーボードが出た状態で、はみ出さない。キーボードだけで、チケットの各部分・シート・ダイアログを操作できる。
16. **カレンダー連携が壊れていない**（`/calendar-test` が今までどおり動く）。
17. 既存: 記録の作成・編集・削除・公開・「みんなのメモリー」が、今までどおり動く。

## 13. リーダー（メインセッション）の進め方

0. **モデル**: チームメイトは **Sonnet 5.5（`claude-sonnet-5-5`）**、リーダーだけ **Opus 5.5（`claude-opus-5-5`）**（ユーザー指示）。`.claude/agents/*.md` に `model:` の行があるか、リーダーの既定を決める `.claude/settings.local.json` があるかを確かめる（無いことがある）。リーダーは、起動したときのモデルを確かめ、違えば `/model claude-opus-5-5` に切り替えるようユーザーに伝える。チームメイトを作るときは、モデルに Sonnet 5.5 を指定する。`.claude/agents/*.md` の書き換えは、ユーザーの了承を得てから行う。
1. この文書と `CLAUDE.md` を読む。リーダーは自分でコードを書かず、調整・タスク管理・ユーザーへの確認に専念する。
2. `git status -sb` で `redesign/memory` にいることを確かめる（0章）。無ければ、ユーザーに作るよう頼む。
3. `flutter analyze`・`flutter test`・ルールのテストを実行し、品質ゲートが通る状態かを確認する。通らなければ、原因をユーザーに報告して判断を仰ぐ。
4. 5章をまとめてユーザーに聞き、回答を判断ログに書き、5章の「回答」の列を埋める。**同時に、12.0 の 3（Google Cloud の設定）を今すぐ始めるよう頼む**（G0 に必要。時間がかかる）。**確認が済むまでチームメイトは作らない。**
5. チームメイトを4人作る（**モデルは Sonnet 5.5**）。各チームメイトはリーダーの会話履歴を見られないので、作成時の指示に必要なことを書く。
   - `dev-data` エージェントタイプで、名前 `photos-data`。指示: 「markdown/feature_memory_ticket_plan.md を読み、担当 photos-data として D1 から始めて（順番は D1 → D3 → D2 → D4 → D5）。4.4・4.5・4.8 と7章を読み、D1 の方針（3〜5行）を私（リーダー）に送ること（返事を待たずに進めてよい。問題があれば私から連絡する）。契約（7章）は、D1 が終わったら ui-record・ui-share・qa に全文を送ること。D3 では lib/services/google_calendar_service.dart を読み、同じ分岐・同じ日本語のエラーで書き写すこと（カレンダーのファイルは変えない）。MemoryRepository にメソッドを足す前に、qa に偽物へ足してほしいメソッドの形を送ること。6章の『読むだけ』のファイル・既存のメソッドの動き・firestore.rules・functions は変えないこと。依存パッケージを足さないこと。トークン・baseUrl・写真・メール・座席をログや例外に出さないこと。座席を ShareContent に入れないこと」
   - `dev-ui` エージェントタイプで、名前 `ui-record`。指示: 「markdown/feature_memory_ticket_plan.md を読み、担当 ui-record として、4.2・4.3・4.4・4.9〜4.12 を読み込んでおき、photos-data から D1 の契約が届いたら U1 から始めて（先に G0 の /photos-test を、D3 のあと人間が試せるように作る）。見本は markdown/design_memory_ticket/oshiashi_memory_3_tap_ticket.html の VARIANT==='3' の分岐だけ。ただし 4.0 の表のとおり、見本から変える箇所がある（自動えらびは作らない・下書きの札は出さない）。ボトムシートの作りは lib/features/help/help_sheet.dart を手本にする（変えない）。ポップアップは必ずボタンの処理の最初に呼ぶ。例外の文字列を画面に出さない。memory_form_page.dart は変えない。投稿の画面のルートは ui-share の入れ物ができたら app.dart に足す。方針は私（リーダー）に送るが、返事を待たずに進めてよい。依存パッケージを足さないこと。文言は 4.11 のとおり一字一句」
   - `dev-ui` エージェントタイプで、名前 `ui-share`。指示: 「markdown/feature_memory_ticket_plan.md を読み、担当 ui-share として、4.6〜4.8・4.10〜4.12 と 7章の ShareTicketView を読み込んでおき、photos-data から D1 の契約が届いたら S1 から始めて。最初に、MemoryShareScreen の空の入れ物と ShareTicketView の引数の形を ui-record に送ること。見本の CSS（見本の 233〜296 行）の割合の数値を unit = width / 100 で写す。座席を引数にも画面にも持たないこと。写真の欄は ui-record の MemoryPhotosSection を使うだけで、直さない。pubspec.yaml に足してよいのは web の1行だけ（5.8 が案A のとき）。例外の文字列を画面に出さない。方針は私（リーダー）に送るが、返事を待たずに進めてよい。文言は 4.6・4.8・4.11 のとおり一字一句」
   - `dev-qa` エージェントタイプで、名前 `qa`。指示: 「markdown/feature_memory_ticket_plan.md を読み、担当 qa として T0 から始めて。以降はレビュー依頼とテスト更新依頼を最優先に。photos-data から偽物に足すメソッドの形が届いたら、メモリーのリポジトリの偽物を同じタイミングで直す。8章の方針（期待を弱めない・書体を変えて回避しない・本物の Google・Gemini・ネットワークを呼ばない・トークンやメールは架空の値で出力しない・座席が SNS に出ないことのテストを必ず入れる）を守ること。パッケージを足さないこと」
6. 9章のタスクを共有タスクリストに登録する（担当・依存関係つき）。
7. 進行中は、担当外ファイルの編集・同じファイルの同時編集・契約の食い違い・**共有ファイル（`LiveMemory`・`MemoryRepository`・`app.dart`・`home_page.dart`・`MemoryDetailPage`）の既存の動きの変更**・**カレンダーのファイルの変更**・**テストを消して通していないか**・**パッケージや画像の追加（`web` の1行以外）**・**トークン・写真・メール・座席のログへの出力**・**例外の文字列の画面表示**・**見本の試し用の分岐・文言の混入**を見張る。ユーザーが決めるべきことは、まとめてユーザーに聞く。**誰も動いていない時間ができたら（全員が返事待ちになる、完了報告のあと止まる、など）、すぐに次の指示を出す。**
8. **G0 の結果が出たら（D3 のあと、人間が 12.1 の 5〜6）**、5.17 の①〜⑤を判断ログと 4章・5章に反映し、`ui-record`・`photos-data` に変更を伝える。**② が通らない・⑤ が遅い・12.0 の 5 で「Gemini に送れない」と分かったら、止めて、ユーザーに代案（Cloud Functions で取る・枚数を減らす・Gemini に送らず自分で選ぶ）を相談する。**
9. **時間の管理（提出は 11/10 19:00）**: 11/9 の昼までに P1 の U2・S2 が終わっていなければ、P2 をすべて落とし、さらに「選ばなかった写真の一覧」「デザインの切り替え」を出さない（4.3・4.6 のとおり、P1 は最小の形）。11/9 の夜までに G0 の② か⑤ が通らなければ、R2・R3 を「端末から写真を追加」のままにして、R1・R4・R5・R6 を仕上げる（Google フォトの連携は `/photos-test` まで）。
10. すべて完了したら L1 を行う。ユーザーに12章の動作確認手順と、コミット案（メッセージと含めるファイル）を示し、了承を得てからコミットする。含めるのは、6章の編集してよいファイル・`test/**` の変更・`markdown/feature_memory_ticket_plan.md`・`markdown/design_memory_ticket/**`・`markdown/deploy_手順.md` の追記・`notes/memory_ticket_*`・`notes/判断ログ_memory_ticket.md`・`CLAUDE.md` の1行。`git push`・Pull Request・デプロイはユーザーが行う。
11. 最後にチームメイトを終了させ、チームを片付ける。

## 14. 使用量の上限で止まったときのために

- リーダーは `notes/memory_ticket_進捗.md` を、**タスクが1つ終わるたび**に更新する（状態・担当・触ったファイル・次にやること・ユーザーに聞きたいこと・G0 の結果）。止まって再開するときは、まずこのファイルを読み、終わったタスクはやり直さない。
- Claude Code が終了してチームメイトがいなくなったら、まだ終わっていないタスクの担当だけを作り直す（13章の指示に「notes/memory_ticket_進捗.md を読み、自分の未完了のタスクから再開すること」を足す）。
- 使用量を抑えるルール（全員）: メッセージは短く、ファイルの中身やテストの出力を丸ごと貼らない。作業中のテストは関係するファイルだけを実行し、全体は完了時の品質ゲートに任せる。長い出力は末尾だけを見る。計画書は自分に関係する章だけを読み直す（この計画書は長い）。進み具合の確認のためだけのメッセージを送り合わない。
- 許可の確認で止まらないように、シェルのコマンドは1つずつ実行する（`;`・`&&`・`|` でつながない、`$変数` を使わない）。ファイルの読み書き・検索は Read・Edit・Grep などの道具を使う。
