# メモリー統合（redesign/memory）レビュー記録

担当: qa。1行ずつ「日付｜タスク｜重さ｜内容｜対応」。

| 日付 | タスク | 重さ | 内容 | 対応 |
|---|---|---|---|---|
| 2026-11-08 | Q3（S2） | 重大 | 投稿画面の経路 `?target=ig` が効かない。`memory_share_screen.dart` の initState の microtask で `selectTarget` を呼ぶが、記録の読み込みが終わるまで誰も `shareProvider`（autoDispose）を watch せず、状態が捨てられて X に戻る。ホームの「Instagram」ボタンが X の画面を開く | 修正済み（ui-share。`ref.listenManual` で状態を生かす）。回帰テストを確定（skip なし） |
| 2026-11-08 | Q3（S2） | 中 | 投稿画面のタブ（`_TabButton` の Row）が、幅 360 以下（文字 1.0 倍でも）と、文字 1.3 倍・幅 430 以下で右にはみ出す（最大 70px） | 修正済み（ui-share。`Flexible`＋`FittedBox`）。回帰テストを確定（skip なし） |
| 2026-11-08 | Q2（D5） | 中（仕様のずれ） | 計画書 4.6 は「文章を直したあとは、チップを押しても作り直さない」、7章（契約）は「`toggle` は文章の手直しを捨てる」。実装は 7章のとおり（手直しを捨てる）。テストも実装（7章）に合わせた | 4.6 を正とする判断（リーダー）。`toggle` は手直しを捨てない形に修正済み。テストも「残る・`resetCaption` で戻る」に直した |
| 2026-11-08 | T0 | 中 | `memory_detail_seat`・`memory_detail_setlist`・`memory_detail_impression` が「残すキー」の一覧に無かった | リーダーが残す判断。ui-record が残した。テストで確認済み |
| 2026-11-08 | Q3（座席） | 確認済み | 座席の目印の文字列が、画面（プレビュー・保存する画像の部分・ホームのカード）・文章・X の URL・クリップボードに出ない。セトリ・感想・写真を保存しても座席は消えない | テスト: `share_page_test.dart`・`memory_ticket_page_test.dart`・`share_notifier_test.dart`・`photo_sheet_test.dart`・`home_memory_banner_test.dart` |
| 2026-11-08 | Q2（D3〜D5） | 確認済み | 例外・ログ・state にトークン・baseUrl・メールが出ない。やめた・画面を閉じたあとに古い処理が state を書き換えない。セッションは、大きい写真を取り終えたあと・やめた・失敗のときに消える | テスト: `google_photos_service_test.dart`・`photo_pick_notifier_test.dart` |

## R1 まとめレビュー（2026-11-08。qa）

### 差分の範囲・禁止事項（すべて問題なし）

- `git diff --stat`: 変更は `lib/app.dart`・`home_page.dart`・`memory_detail_page.dart`・`memory_list_page.dart`・`live_memory.dart`・`memory_repository.dart`・`pubspec.yaml`/`pubspec.lock`・`test/features/memory_form_page_test.dart`・`CLAUDE.md` だけ（6章の範囲）。`firestore.rules`・`storage.rules`・`functions/**`・`google_calendar_service.dart`・`gemini_service.dart`・`assets/**`・`web/**` の差分なし。
- `pubspec.yaml` の差分は `web: ^1.1.1` の1行だけ（`pubspec.lock` は transitive → direct main の1行）。
- 禁止文言（「自動で選べます」「会場の近く」「（デモ）」「このデモ」「予約情報から自動入力」「下書き（自動作成）」「NEW」「保存して完成」）: 新規・変更ファイルに無し。`GoogleFonts.` の直書き無し。w800/w900 など 700 超の太さ無し。
- `'$e'` 等の例外の文字列の画面表示: 無し（`photos_test_page.dart` も `googlePhotosErrorMessage` 経由）。`Firebase*.instance` を画面から直接呼ぶ箇所: 無し（`googlePhotosApiProvider` の既定だけ）。
- `debugPrint` は2か所のみ（「写真を取得できませんでした」「公開の写しの保存に失敗」）。トークン・baseUrl・写真・メール・座席は出ていない。
- 座席: `ShareContent`・`ShareTicketView`・`buildCaption`・X の URL・Gemini のプロンプトに座席が入らない。`seat` が出るのは `memory_share_screen.dart` 160 行（`saveFields` に座席を渡し返して、消さないため）だけ。テストで確認済み。
- Gemini には、縮小版と、ライブ名・日時・会場・アーティスト名だけを送っている（`PhotoPickRequest` にそれ以外の項目が無い）。候補の写真が Storage に行くのは `materializeSelected`（決定）→ `savePhotos` だけ。
- ポップアップ: `begin` は `await` の前に `authorize()` を呼ぶ。同意ダイアログの「つなぐ」は `onConsent()`（認可の開始）を `pop` の前に呼ぶ。`pickerUri` は「Googleフォトを開く」の2回目のボタンで開く。
- 古い処理: 世代番号と `ref.mounted` で守られている（テスト済み）。`await` のあとの `mounted`/`context.mounted` の確認: 確認した範囲で問題なし。
- 4.11 の文言（同意・状態①③・エラー）は一字一句テストで確認済み。

### 指摘（担当者別）

| 担当 | 重さ | 内容 | 直し方の案 |
|---|---|---|---|
| ui-share | 重大 | `memory_share_screen.dart` の「保存する画像を描くための部分」（`Positioned` → `IgnorePointer` → `SizedBox.shrink` → `OverflowBox` → `RepaintBoundary`）が、画面の左上に**見える状態で描かれる**。`SizedBox.shrink` は 0×0 だが、`OverflowBox` の子は大きさ 0 の親の外に描かれ、クリップされない。しかも Stack の最後なので、一覧・タブ・プレビューの**上**に重なる（幅 390 で、X の横長 800 論理ピクセルのチケットが画面の上部を覆う）。ゴールデンで確認した（確認用のファイルは削除済み）。Offstage にすると `toImage` ができなくなる | 保存用の部分を Stack の**最初**（一覧の下）に置いて一覧で隠す、または `Positioned(left: -captureWidth - 100)` で画面外に出す（Offstage・Opacity 0 は使わない）。`captureShareImage` が描けること（`debugNeedsPaint` が false）を実機で確かめる（12.1 の 11） |
| ui-share | 中 | `lib/utils/file_download_web.dart`: `anchor.click()` の直後（`finally`）で `revokeObjectURL` している。ブラウザによってはダウンロードが始まる前に URL が無効になり、保存が失敗する恐れがある | `revokeObjectURL` を `Future.delayed`（1〜数秒）のあとにする |
| ui-share / ui-record | 中 | 動きの抑制（`disableAnimations`）: シート（写真・編集）・進み具合のバー・編集カードのスクロールは対応済み。**同意のダイアログ（`showDialog`）と、トースト（SnackBar）は未対応**（4.10 は「ダイアログ・トーストの動きを止める」） | `showDialog` の `animationStyle: AnimationStyle.noAnimation`（`disableAnimations` のとき）。SnackBar は `showSnackBar(..., snackBarAnimationStyle:)` |
| photos-data | 軽微 | `PhotoPickNotifier.waitForSelection` は、`waitingPicker` のまま2回呼ぶと、ポーリングが二重に走る（今の画面は「Googleフォトを開く」を1回で消すので起きないが、状態機械側に保護が無い） | 呼び出し中のフラグ（または世代番号の再確認）で二重に始めない |
| ui-record | 軽微 | `/photos-test`（`photos_test_page.dart`）が本番の経路に残っている（計画書どおり「本番の導線には出さない」。Gemini を呼べる）。提出前に消すか、デモに不要なら外すかの判断 | リーダー判断 |

### C1（掃除）の対象

- 使われていない関数・項目（UI からも `lib/` の他からも参照が無い）: `parseSetItems`（`share_ticket.dart`。画面は `memory_form_page.dart` の `parseSetlist` を使っている）、`ShareFormat.outHeight`・`ShareDesign.photoMain/collage`・`ShareNotifier.setFormat/setDesign/setBackground`・`ShareConfig.backgroundIndex/design`（P2 の画面がまだ無いため。S3 を作らないなら削除、作るなら残す）、`hashtagsOf` は内部だけで使用。
- 不要な import・仮データ・TODO: `flutter analyze` 0 件・`TODO`/`FIXME`/仮置き/ダミーの記述は無し。ホームのカードの写真は `sharePhotoBytesProvider` で本物になっている。
- `photos_test_page.dart` の `startAt: DateTime.now()`・「接続テスト」「テスト会場」は試し用（G0 の確認が終われば画面ごと不要）。

### R1 の指摘の修正確認（2026-11-08。qa）

| 担当 | 重さ | 内容 | 結果 |
|---|---|---|---|
| ui-share | 重大 | 保存用の画像の部分が画面の左上に見えていた | 修正済み（`Positioned(left: -(captureWidth+100))`）。回帰テスト `share_page_test.dart`「保存用の画像の部分」（右端が 0 以下・幅 800・プレビューと重ならない） |
| ui-share | 中 | `revokeObjectURL` が早い | 修正済み（2 秒の Timer）。実機の確認は 12.1 の 11 |
| ui-share / ui-record | 中 | 同意ダイアログ・トーストが `disableAnimations` 未対応 | 修正済み。ダイアログは `photo_sheet_test.dart` で、動かないこと（透明度 1.0）と、設定が無いときの比較を確認。トーストはテスト未追加（コードのみ確認） |
| photos-data | 軽微 | `waitForSelection` の二重ポーリング | 修正済み（`_pollingGen`）。`photo_pick_notifier_test.dart` に「2回呼んでも1本」「cancel のあと begin し直すと再びポーリングできる」を追加 |
| ui-record | 軽微 | `/photos-test` が本番の経路に残る | リーダー判断待ち |

最終確認: `flutter analyze` 指摘 0 件・`flutter test` 1911 件成功・ルールのテスト 322 件成功。

### S3（P2: デザイン3種・形・背景）のレビュー（2026-11-08。qa）

| 担当 | 重さ | 内容 | 対応 |
|---|---|---|---|
| ui-share | 中 | コラージュ（`ShareDesign.collage`）・X の横長（16:9）で、長いタイトル・セトリ・感想を入れると、右の文章の列が下にはみ出す（幅 390 で、タイトル 72 字は 110px、短いタイトルでも 1.7px のはみ出しが出る場合あり）。ほかのデザイン・形では出ない | 修正済み（ui-share。`LayoutBuilder` + `FittedBox(scaleDown)`）。回帰テストを確定（skip・除外なし）。最終確認: `flutter analyze` 0 件・`flutter test` 2040 件成功・ルールのテスト 322 件成功 |

確認済み: デザイン3種 × 全部の形 × 写真 0〜4 枚が描ける。空の枠は、hints のチケットだけ（写真メイン・コラージュ・保存する画像・mini には出ない）。セトリ・感想の上限と「ほか○曲」・「…」。座席が画像に出ない。背景 4 色（押せる範囲 44px 以上）。投稿先ごとに別々の設定。保存する画像は、選んだ形の幅÷2・pixelRatio 2・画面の外。折りたたみは `disableAnimations` で動かない。

最終確認: `flutter analyze` 指摘 0 件・`flutter test` 2039 件成功（skip 1）・ルールのテスト 322 件成功。`firestore.rules`・`storage.rules`・`functions` の差分なし。`pubspec.yaml` は `web` の1行だけ。

### 仕様の変更（コラージュ廃止・背景 7 色）に合わせたテストの更新（2026-11-08。qa）

- 変更: `ShareDesign` は ticket・photoMain の 2 つ。背景は 7 色（きいろ・みどり・ピンク・赤・青・オレンジ・紫。黒は無し）。
- 削除: コラージュ専用のテスト（空の枠・敷き詰め 20 通り・はみ出しの回帰）、背景 4 色・黒を前提にしたテスト。
- 修正: 投稿画面の S3 グループ（デザイン 2 つ、`share_bg_0〜6`）、`share_notifier_test.dart`・`share_ticket_test.dart`（photoMain・背景 6）。
- 追加: `ShareDesign` が 2 つだけ、背景 7 色・名前、黒が無いこと、`backgroundIndex` が範囲外（-1・7・99）でも落ちない（`ShareConfig` と描画）、背景 7 色 × デザイン 2 × 投稿先 2 × 写真 0・3 枚で例外なく描ける、`share_bg_0〜6` の押せる範囲 44px 以上、幅 320・文字 1.3 倍で折り返してもはみ出さない。
- 最終確認: `flutter analyze` 指摘 0 件・`flutter test` 2013 件成功・ルールのテスト 322 件成功。指摘なし。
