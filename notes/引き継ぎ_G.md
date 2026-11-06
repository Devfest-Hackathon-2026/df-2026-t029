# 引き継ぎ（担当B: グッズ交換 G）— 2026-11-06

## 現在の状況
- G-0〜G-5 は完了（`markdown/goods_spec.md` 6章）。G-5 は PR #21（`features/g5` → `dev`）でマージ済み。
- 今のブランチは `dev`（最新 `e46a9d5`）。G-6 のブランチは人間が `features/g6` などで用意する。
- 残り: G-6 スクショから投稿を作る → G-7 写真（Blaze 切り替えが要る）→ G-8 プロフィール（着手前に A と共有）。

## 最初に読む資料
- 仕様: `markdown/goods_spec.md`（G の仕様・小ステップ）、`markdown/Database_config.md` 3.9〜3.13・4〜6章
- 判断ログ: `notes/判断ログ_G.md`（決めたことと理由。新しいものを下に追記する）

## ファイル構成（lib 以下）
| ファイル | 役割 |
|---|---|
| models/goods.dart | グッズ・種類（GoodsVariant）・種別 |
| models/trade_post.dart | 投稿・譲セット（GiveSet/GiveItem）・求セット（WantSet/WantTarget）・タグなどの値 |
| models/trade_reply.dart / trade_chat.dart / trade_message.dart | 返信・個人チャット・メッセージ |
| repositories/goods_repository.dart | グッズの取得・登録・更新（変更履歴つき） |
| repositories/trade_post_repository.dart | 投稿の取得・作成・更新・状態変更。保存時に検索用キーを作る |
| repositories/trade_reply_repository.dart | 返信の購読・作成・削除 |
| repositories/trade_chat_repository.dart | チャット・メッセージ、承認（バッチ）、既読、取引終了 |
| providers/goods_providers.dart | グッズのリポジトリ・推しごとのグッズ・ID での取得 |
| providers/trade_post_providers.dart | 投稿・掲示板・マッチ・返信・チャットのプロバイダすべて |
| utils/goods_search.dart | グッズの名前・別名の検索と重複確認 |
| utils/trade_keys.dart | 検索用キー（`item:` `goods:` `member:`）の作成 |
| utils/trade_board.dart | 掲示板の結果のまとめ（重複除去・並べ替え）と絞り込み（BoardFilter） |
| utils/trade_match.dart | 相互・片方マッチの判定と一致した品目 |
| utils/text_normalizer.dart | 名前の正規化（`normalizeName`。A と共用） |
| features/goods/goods_search_page.dart / goods_form_page.dart / goods_draft.dart | グッズの検索・登録・編集画面と入力中の値 |
| features/trade/trade_top_page.dart | 交換トップ（掲示板／マッチ／自分の投稿のタブ、右上にチャット） |
| features/trade/trade_board_view.dart / board_filter_sheet.dart | 掲示板と絞り込みのシート |
| features/trade/trade_match_view.dart | マッチのタブ |
| features/trade/my_trade_posts_view.dart | 自分の投稿のタブ（編集・募集終了・再開） |
| features/trade/trade_post_form_page.dart | 投稿の作成・編集画面 |
| features/trade/trade_post_draft.dart | 入力中の投稿・譲セット・求セットと保存前の検査 |
| features/trade/trade_sets_section.dart | 作成画面の譲セット・求セットの欄 |
| features/trade/trade_item_picker_sheet.dart | 品目・全種類・メンバーを選ぶシート |
| features/trade/trade_post_summary.dart / trade_post_summary_lines.dart | 投稿の要約の文字列と表示行 |
| features/trade/trade_post_detail_page.dart / trade_replies_section.dart | 投稿の詳細と返信・承認 |
| features/trade/chat_list_page.dart / chat_page.dart | チャットの一覧と画面 |

## 主なプロバイダ（providers/trade_post_providers.dart ほか）
- `tradePostRepositoryProvider` / `tradeReplyRepositoryProvider` / `tradeChatRepositoryProvider` / `goodsRepositoryProvider`: リポジトリ
- `myTradePostsProvider`: 自分の投稿（購読）。`tradePostByIdProvider`: ID で1件
- `boardTargetProvider`・`boardFilterProvider` → `openTradePostsProvider` → `tradeBoardProvider`: 掲示板（50件ずつ）
- `myOpenWantKeysProvider` → `matchCandidatesProvider` → `tradeMatchesProvider`: マッチ（1回の取得）
- `tradeRepliesProvider` / `myChatsProvider` / `tradeChatProvider` / `tradeMessagesProvider` / `unreadChatCountProvider`
- `myDisplayNameProvider`: 表示名（今は「匿名」固定。G-8 でここだけ差し替える）
- `goodsInScopeProvider(GoodsScope)`: 対象の推し（＋所属グループ）のグッズ。品目のシートで使う

## ルート（lib/app.dart の routerProvider）
| パス | 画面 |
|---|---|
| /trade（`?tab=board/match/mine`） | 交換トップ。/trade/board・/trade/mine はリダイレクト |
| /trade/new、/trade/:id/edit | 投稿の作成・編集 |
| /trade/:id | 投稿の詳細 |
| /chats、/chats/:id | チャットの一覧・画面 |
| /goods、/goods/new、/goods/:id/edit | グッズの検索・登録・編集 |
ホームからの入口は「グッズ交換」ボタン（`home_trade_button`）1つ。

## 約束ごとの要点
- 回答・コメント・コミットメッセージは日本語。画面の文言も日本語。
- Firestore へのアクセスはリポジトリに閉じ込め、`FirebaseFirestore` をコンストラクタで受け取る。Riverpod 3 を手書き（コード生成なし）。`await` 後は `context.mounted` を確認。
- 表示名は G-8 まで「匿名」（ルール上1文字以上必須のため空欄にしない）。`myDisplayNameProvider` 以外で決めない。
- `images` は G-7 まで空の配列。
- 仕様にない・未決定のことは自分で決めず、比べた案・理由・捨てた案を添えて提案し、人間（横山）が選ぶ。決めたら判断ログに追記。
- 完了の条件: `flutter analyze` 0 件（info 含む）、`flutter test` 全成功、追加したロジックにテスト（`test/features/trade_test_helpers.dart` に共通の部品あり。Firestore は fake_cloud_firestore）。
- コミットは人間の了承を得てから。`git push`・ブランチ切り替え・`firebase deploy`（ルール含む）は人間が行う。
- 読み取り量を抑える方針（掲示板は50件ずつ、マッチは1回の取得）。
- 終わったら `goods_spec.md` 6章の状況を「完了」にする。

## G-6 で使う・触る予定のファイル
- `lib/services/gemini_service.dart`: `extractLiveInfo` にならい、譲求の画像の抽出（スキーマと関数）を足す。`geminiServiceProvider` を流用（G-6-1）
- `lib/features/scan/scan_page.dart`: 画像の選択と呼び出し方の参考
- `lib/utils/goods_search.dart`・`lib/utils/text_normalizer.dart`: 抽出した名前を登録済みのグッズ・種類に対応付ける（G-6-2。新しい純粋関数は `lib/utils/` に置きテストを書く）
- `lib/providers/goods_providers.dart`（`goodsInScopeProvider`）: 照合先のグッズ
- `lib/features/trade/trade_post_form_page.dart`・`trade_post_draft.dart`・`trade_sets_section.dart`・`trade_item_picker_sheet.dart`: 読み取りの入口と、結果を下書きへ反映・決まらない品目を選ばせる（G-6-3）
- `markdown/goods_spec.md`・`notes/判断ログ_G.md`: 状況と判断の記録
- 未決（提案が要る）: 対象の推しを読み取り前に選ばせるか、未登録のグッズをどう扱うか、読み取り結果の確認画面を別に作るか作成画面で直接直すか
