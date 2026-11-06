# Step4 実装計画: 既存データとの照合・更新と変更履歴（Step2・3 の合流地点）

> 担当A（とし）の Step4 を、Claude Code の agent team（リーダー＋チームメイト3人）で実装するための指示書。
> 人間とエージェントの両方が読む。仕様書 `markdown/app_config.md` の 4.3（手順4）と 4.4（共通データ）を実装する。
> 「3. 実装前に合意すること」は 2026-11-06 にユーザーが推奨案どおり合意した（判断ログ `notes/判断ログ_A.md` の Step4）。

## 0. 作業ブランチと前提

- **作業ブランチは `feature/step4`。** ブランチの作成・切り替え・pull・push は人間が行う。エージェントはブランチを切り替えない。
- 完成したら、人間が `feature/step4` から `dev` へ Pull Request を出す。
- 開始前に、リーダーは `git status -sb` で `feature/step4` にいて、GitHub より遅れていない（`behind` が無い）ことを確かめる。遅れていたらユーザーに `git pull --no-rebase` を頼む。
- Step2（手入力登録・一覧・申込状況）、Step3（スクショ読み取り）、Step5（カレンダー連携）、グッズ交換（G-0・G-1）は `dev` にマージ済み。Step4 はこれらの上に作る。

## 1. 範囲

仕様書 4.4 の決定事項: 「新規登録時（手入力・スクショ読み取りの両方）、既存データがあればそれを使い、新しく作成しない。既存データと内容が異なる場合（日程変更など）は、データを更新し、変更履歴（変更前の値・変更後の値・変更者・日時）を残す。」

**作るもの**

1. **照合**: 確認・修正画面（`/live-form`）で「保存」を押したとき、同じライブが既に登録されていないかを探し、候補を示す。ユーザーが「既存のライブに反映する」か「別のライブとして新しく登録する」かを選ぶ。
2. **差分の確認**: 既存のライブを選んだら、入力と既存データの違い（追加・変更・変化なし）を一覧で見せ、反映する変更をユーザーが選ぶ。
3. **更新と変更履歴**: 選んだ変更を1回の書き込みで反映し、変わった項目ごとに履歴（`history` サブコレクション）を残す。新しい公演・受付は既存のライブに追加する。
4. **履歴の表示と取り消し**: ライブ詳細で変更履歴を見られ、誤った変更を1件ずつ元に戻せる（3.4）。
5. **ライブの編集**: ライブ詳細から既存のライブを編集できる（3.7。照合と同じ仕組みを使う）。
6. **セキュリティルール**: 更新・履歴・既存ライブへの公演・受付の追加を許すルールと、そのテスト。

**作らないもの（ほかの Step の範囲・今回は見送り）**

- ライブ・公演・受付の削除（中止の扱いを含む）
- すでに重複して登録されたライブの統合
- カレンダー連携の変更（Step5・横山さん）。ただし、更新でドキュメント ID を変えないことで、追加済みの予定との対応を保つ（3.3）。
- アプグレの表示条件・ルールの最終整備・デモ用データ（Step7）
- ライブの大量作成への対策（3.4 で扱いを決める）

## 2. 前提（決定済み・既存のコード）

| 項目 | 内容 | 根拠 |
|---|---|---|
| 変更履歴の形 | `lives`・`performances`・`receptions` の各ドキュメントの `history` サブコレクション。項目ごとに1件、`field`・`before`・`after`・`changedBy`・`changedAt` | DB 設計案 3.6 |
| 更新できる人 | 当面はログイン済みのユーザー全員。誤った更新は履歴から戻す | DB 設計案 7章（Step4 で確定させる） |
| 個人の申込状況 | 共通データに含めず `users/{uid}/applications` に置く（既存）。照合で既存の受付に合わせれば、申込状況はそのまま使える | 仕様書 4.4、Step2 |
| 保存処理 | `LiveRepository.create`（1つの WriteBatch で新規作成し `SavedLive` を返す）と、`live_form_page.dart` の `_save`（検査・二重保存防止・保存後のカレンダー追加シート・詳細への移動） | Step2・Step5 |
| 参考にできる実装 | グッズの更新と履歴: `GoodsRepository.update`（変わった項目だけ更新し、項目ごとに履歴を作る）、ルールの `isValidAuditOnUpdate`・`isValidHistory`・`isGoodsUpdatedNow` | 横山さんの G-1 |
| 名前の正規化 | `normalizeName`（`lib/utils/text_normalizer.dart`。ひらがな／カタカナ・全角／半角・空白などの揺れを吸収） | Step1 |
| 上限 | 公演50件・受付30件・料金10個・出演者は種別ごとに20件（`LiveLimits`、ルールと同じ値） | Step2 |
| ルールの読み取り上限 | ルールで別のドキュメントを読む（`get`・`getAfter`）回数には上限があり、エミュレータでも効く（Step2 で実測済み） | 判断ログ（Step2 の振り返り） |

## 3. 実装前に合意すること（2026-11-06 すべて推奨案で合意済み）

リーダーは、次の項目を推奨案と理由つきでユーザーに示し、回答を `notes/判断ログ_A.md` に「Step4」として記録してから実装を始める。合意した項目は見出しに「（合意済み）」と付け、内容を書き換える。

### 3.1 照合のタイミングと候補の出し方（合意済み）

- **タイミング**: `/live-form` で「保存」を押し、入力チェックが通った後。手入力・スクショ読み取りの両方で行う。
- **候補の探し方**: 入力で選んだ出演者（`groupIds`・`oshiIds`）が1つでも重なるライブを Firestore から1回だけ読み（`array-contains-any`、30件ずつ分割）、その公演も読む。
- **候補の強さ**（推奨）:

| 強さ | 条件 |
|---|---|
| ほぼ確実 | 公式 URL が同じ（末尾の `/` や大文字小文字の違いは無視）／正規化したライブ名が同じ |
| 可能性あり | 正規化したライブ名の一方が他方を含み、かつ同じ日の公演が1つ以上ある／ライブ名は違うが、同じ日・同じ会場の公演がある |

- 候補は強い順に最大3件。理由（「公式 URL が同じ」など）を添えて示す。
- **自動では統合しない。** 候補が「ほぼ確実」でも、ユーザーが選ぶ（AI の読み取りや名前の揺れで、別のツアーを誤ってまとめないため）。
- 候補が無ければ、Step2 と同じく新規作成する（今の動きのまま）。
- 比べた案: 保存前に毎回確認画面を挟む（候補が無いときも一手間増える）／入力中に候補を出す（読み取りが増え、出演者を選ぶ前は探せない）。

### 3.2 同じ公演・受付の見分け方（合意済み）

既存のライブを選んだあと、入力の公演・受付を既存のものと対応付ける。

| 対象 | 同じとみなす条件（推奨） |
|---|---|
| 公演 | 開演の日付（日本時間の日）が同じで、正規化した会場名が同じ。会場名が片方だけ空なら、日付だけで1対1に決まるとき |
| 受付 | 種別（`type`）が同じで、正規化した表示名が同じ。決まらなければ、種別と申込期限の日付が同じもの |

- 対応が付いたもの → 項目ごとに比べて「変更」か「変化なし」。
- 入力にだけあるもの → 「追加」。
- 既存にだけあるもの → 消さずに残し、「今回の入力には無い」と表示する。
- **手動の対応付け（推奨: 入れる）**: 日程変更（仕様書 4.4 の例）では日付が変わるので自動では対応が付かない。差分の確認画面で、「追加」の公演・受付を「既存の〇〇の変更として扱う」と選べるようにする。

### 3.3 差分の反映ルール（合意済み）

- **空の値では上書きしない。** 入力側が空で既存側に値がある項目（例: スクショに入金期限が無い）は「変化なし」にする。
- **出演者は追加だけ。** 入力に新しい出演者がいれば加え、既存の出演者は外さない（外すと、その推しをフォローしている人の一覧から消えてしまうため）。
- **既存の公演・受付は削除しない**（削除は Step4 の範囲外）。
- 差分の確認画面では、変更・追加ごとにチェックを付け（既定はすべてオン）、ユーザーが外したものは反映しない。
- 変更も追加も無ければ「すでに登録済みです」と知らせ、そのライブの詳細へ移る（書き込まない）。
- **ドキュメント ID は変えない。** 更新は `update` で行い、消して作り直さない。カレンダー連携（Step5）が公演・受付の ID を予定の ID に使っているため。
- 反映後は、Step5 と同じくカレンダー追加シートを出す（追加・変更した公演・受付を対象にする案）。

### 3.4 更新できる人と、誤ったデータへの対処（合意済み）

| 案 | 内容 | 長所 | 短所 |
|---|---|---|---|
| **1（採用）** | ログイン済みなら誰でも直接更新できる。すべての変更に履歴を残し、ライブ詳細から1件ずつ元に戻せる | DB 設計案 7章どおり。グッズ（G-1）と同じ考え方で、実装が小さい | 荒らしの変更も一度は全員に見える |
| 2 | 直接は更新できず「修正の提案」として保存し、複数人が同じ内容を出したら反映する | 誤った変更が広がりにくい | デモの規模では人数がそろわない。仕組みが大きい（チームレビューで出た案） |

- 戻す操作も「変更」として履歴に残る（誰がいつ戻したか分かる）。
- 戻すのは、その項目の今の値が履歴の「変更後」と同じときだけ。その後さらに変わっていたら「その後に別の変更があります」と知らせて止める。
- 変更者の表示: 他人の `users/{uid}` は読めない（本人のみのルール）ので、「あなた」か「ほかのユーザー」と日時だけを出す案。名前を履歴に書き込む案は、偽れるうえ個人情報が広がるので採らない。
- **Step2 から持ち越した課題（ライブの大量作成）**: Step4 では対処せず、公開前の App Check（Step7）で扱う（合意済み・判断ログに記録）。比べた案: ユーザーごとに1日の作成数をルールで制限する（`users/{uid}` に回数を持たせ、同じバッチで更新させる。作れるが、ルールとテストが大きくなる）。

### 3.5 同時に更新されたときの扱い（合意済み）

- 反映はトランザクションで行う。差分を作ったときに読んだ各ドキュメントの `updatedAt` を覚えておき、トランザクションの中で読み直して変わっていたら中止する。
- 中止したら「ほかの人が先に更新しました。最新の内容で確認し直してください」と知らせ、差分の確認をやり直す（入力は残す）。
- 比べた案: 最後に書いた人の内容で上書きする（グッズの今の実装。他人の変更を黙って消すことがある）。

### 3.6 変更の知らせ方（合意済み）

- **ライブ詳細**: 7日以内に変わった公演・受付に「変更あり」の印を付け、直近の変更を「申込期限 11/20(金) 23:59 → 11/18(水) 23:59（2時間前）」の形で示す。色だけでなく文字でも示す。
- **変更履歴**: ライブ詳細の下に「変更履歴」を置き、ライブ・公演・受付の履歴を新しい順に並べる（項目名は日本語。日時・料金・出演者は読める形にする）。
- ホームの「次の締切」への印は、受付ごとに履歴を読む必要があり読み取りが増えるので、Step4 では見送る案。

### 3.7 ライブの編集（合意済み）

- **入れる（合意）。** ライブ詳細に「このライブを編集」を置き、既存の内容を入れた `/live-form` を開く。保存すると照合（候補探し）は飛ばし、そのライブとの差分の確認（3.2・3.3）へ進む。照合と同じ仕組みを使うので、追加の作業は小さい。
- ルートは `/lives/:liveId/edit` を追加する案（`/` の下の子ルート）。

### 3.8 セキュリティルールの方針（合意済み）

| 対象 | 方針 |
|---|---|
| `lives` の更新 | ログイン済み。作成時と同じ項目・型・長さの検査。`createdBy`・`createdAt` は変えない、`updatedBy == request.auth.uid`、`updatedAt == request.time`（既存の `isValidAuditOnUpdate`）。**`groupIds`・`oshiIds` は減らせない**（`hasAll` で既存を含むこと） |
| `performances`・`receptions` の更新 | 上と同じ検査。`liveId` は変えない。`groupIds`・`oshiIds` はライブ（`getAfter`）と同じ |
| 既存ライブへの公演・受付の追加 | 今の `belongsToLiveCreatedNow` は「同じバッチで作られたライブ」しか認めない。**「同じバッチで、このユーザーが作成または更新したライブ」に広げる**（追加するときは、ライブの `updatedAt` も書き直す） |
| `history`（3つのサブコレクション） | 読み取りはログイン済み。作成は `isValidHistory` と「親のドキュメントを同じバッチで、このユーザーが更新している（新規作成ではない）」こと。更新・削除は不可 |
| 削除 | 引き続き不可 |

- **注意（ルールの読み取り上限）**: 履歴の作成ごとに親のドキュメントを `getAfter` で読むので、1回の反映で変わる公演・受付が多いと上限を超えて拒否されうる。qa がエミュレータで「何件まで一度に反映できるか」を実測し、超えるならアプリ側で1回に反映できる件数を制限する（ユーザーに「一度に反映できるのは〇件までです」と知らせる）。
- `firestore.rules` は横山さんと共有。Step4 で触るのは `lives`・`performances`・`receptions` の `match` ブロックと、その検査関数だけにする。グッズ・投稿・チャットのルールは変えない（共通の関数を使うのはよい）。デプロイは人間が行う。

### 3.9 横山さんのファイルの変更範囲（合意済み）

- `lib/features/live_form/live_form_page.dart`: **`_save` の流れ（照合・差分の確認への分岐）と、編集のための引数（編集中のライブ ID）・見出しの切り替えだけ**を変える。出演者の選択などほかの部分は変えない。
- `lib/app.dart`: ルートの追加（`/lives/:liveId/edit`）だけ。
- それ以外の横山さんのファイル（`live_draft.dart`、`performer_picker_sheet.dart`、`date_time_field.dart`、`lib/features/scan/**`、`lib/features/calendar/**`、`lib/features/goods/**`、`lib/services/**`、`lib/models/live.dart`・`performance.dart`・`reception.dart`・`goods.dart`）は**読むだけ**。モデルに項目（`updatedAt` など）を足したくなっても、リポジトリ側で別に持つ（5章の `ExistingLive.versions`）。どうしても必要なら、リーダーがユーザーに相談する。
- リーダーは、変更した箇所をコミット案に必ず書く（ユーザーが横山さんに伝える）。

## 4. 担当とファイル

同じファイルを2人が同時に編集すると上書きが起きる。**担当外のファイルは編集せず、担当者に SendMessage で依頼する。**

| 担当 | 名前 | 編集してよいファイル |
|---|---|---|
| リーダー | （メインセッション） | `pubspec.yaml`、`pubspec.lock`、この計画書、`notes/判断ログ_A.md` |
| データ層 | `data` | `lib/utils/live_match.dart`（新規）、`lib/utils/live_diff.dart`（新規）、`lib/models/history_entry.dart`（新規）、`lib/repositories/live_repository.dart`、`lib/providers/live_providers.dart`、`lib/features/live_form/live_draft_to_models.dart`（編集用の「モデル → 入力」の変換の追加）、`firestore.rules`（3.8 の範囲のみ） |
| 画面 | `ui` | `lib/features/live_merge/**`（新規。候補の選択・差分の確認）、`lib/features/live/**`（ライブ詳細の履歴・変更あり・編集ボタン）、`lib/features/live_form/live_form_page.dart`（3.9 の範囲のみ）、`lib/app.dart`（ルートの追加のみ） |
| テスト・レビュー | `qa` | `test/**`、`test_rules/**`、`notes/step4_レビュー記録.md` |

- Step1・Step2 のほかのファイル（`lib/models/oshi.dart`、`lib/models/application.dart`、`lib/utils/deadline.dart` など）は読むだけ。必要な変更は担当者経由でリーダーに相談する。
- 横山さんのコードで見つけた問題は、qa が `notes/step4_レビュー記録.md` に書き、リーダーがまとめてユーザーに伝える（勝手に直さない）。

## 5. 契約（インターフェース）

データ層 `data` が最初のタスク（D1）で確定させ、`ui` と `qa` に SendMessage で全文を送る。変更するときも必ず知らせる。以下は叩き台。

```dart
// lib/repositories/live_repository.dart（追加）
/// 既存のライブ一式と、読んだ時点の各ドキュメントの updatedAt（同時更新の検出用）
class ExistingLive {
  final Live live;
  final List<Performance> performances;
  final List<Reception> receptions;
  final Map<String, Object?> versions; // ドキュメントのパス → 読んだときの updatedAt
}

abstract class LiveRepository {
  // ...既存の create / watch* はそのまま...

  /// 出演者が1つでも重なるライブ一式を1回だけ読む（候補探し用）
  Future<List<ExistingLive>> fetchCandidates({
    required List<String> groupIds,
    required List<String> oshiIds,
  });

  /// ライブ1件の一式を読む（編集・差分の確認用）。無ければ null
  Future<ExistingLive?> fetchExisting(String liveId);

  /// 差分を反映する（トランザクション）。ID は変えない。
  /// 読んだ後に誰かが更新していたら LiveConflictException を投げる（何も書かない）
  Future<SavedLive> applyMerge(LiveMergePlan plan, {required String uid});

  /// ドキュメント1件の変更履歴（新しい順）
  Stream<List<HistoryEntry>> watchHistory(HistoryTarget target);

  /// 履歴1件を元に戻す（その項目の今の値が entry.after と同じときだけ）
  Future<void> revert(HistoryEntry entry, {required String uid});
}

class LiveConflictException implements Exception { /* どのドキュメントか */ }

// lib/models/history_entry.dart
enum HistoryCollection { lives, performances, receptions }
class HistoryTarget { final HistoryCollection collection; final String docId; }
class HistoryEntry {
  final String id;
  final HistoryTarget target;
  final String field;
  final Object? before; // Firestore に保存した形のまま（Timestamp・Map など）
  final Object? after;
  final String changedBy;
  final DateTime? changedAt;
}

// lib/utils/live_match.dart（純粋関数）
enum MatchStrength { sure, possible }
class LiveCandidate {
  final ExistingLive existing;
  final MatchStrength strength;
  final List<String> reasons; // 「公式 URL が同じ」など、画面に出す日本語
}
List<LiveCandidate> findLiveCandidates(LiveModels input, List<ExistingLive> existing);

// lib/utils/live_diff.dart（純粋関数）
class FieldChange { final String field; final Object? before; final Object? after; }
class DocChange<T> { final T existing; final T merged; final List<FieldChange> changes; }
class LiveMergePlan {
  final ExistingLive base;
  final List<FieldChange> liveChanges;              // ライブ名・公式 URL・出演者の追加
  final List<Performance> addedPerformances;
  final List<DocChange<Performance>> changedPerformances;
  final List<Performance> existingOnlyPerformances; // 今回の入力に無い（消さない）
  final List<Reception> addedReceptions;
  final List<DocChange<Reception>> changedReceptions;
  final List<Reception> existingOnlyReceptions;
  bool get isEmpty;
}
LiveMergePlan diffLive(ExistingLive base, LiveModels input);
/// 「追加」を「既存の変更」として対応付け直した計画を返す（3.2 の手動の対応付け）
LiveMergePlan pairManually(LiveMergePlan plan, {required String addedKey, required String existingId});
/// ユーザーが外した変更・追加を除いた計画を返す
LiveMergePlan withoutUnselected(LiveMergePlan plan, Set<String> unselectedKeys);

// lib/features/live_form/live_draft_to_models.dart（追加）
/// 既存のライブ一式から、編集用の LiveDraft を作る（出演者は allOshis から引く）
LiveDraft liveDraftFromExisting(ExistingLive existing, List<OshiSummary> allOshis);
```

- 現在時刻を使う判定（「7日以内の変更」など）は、Step2 の `nowProvider` を使い、関数には引数で渡す。
- 履歴の項目名の日本語ラベル（`applyEndAt` → 「申込期限」など）と値の表示形式は、data が1か所（`live_diff.dart` か `history_entry.dart`）にまとめ、ui はそれを使う。

## 6. 画面の要件

- **候補の選択**（ボトムシート）: 候補ごとにライブ名・最初の公演日・会場・理由を表示し、「このライブに反映する」を選べる。最後に「別のライブとして新しく登録する」。閉じたら何もしない（入力は残す）。
- **差分の確認**（全画面）: 「ライブ」「公演」「受付」の区分ごとに、追加（＋）・変更（変更前 → 変更後）・変化なし（折りたたむ）・今回の入力に無い（情報として表示）を並べる。変更・追加にはチェック。日程変更の手動の対応付け（3.2）。下に「反映する（n件）」ボタン。
- 読み込み中・0件・エラー・結果ありの表示、処理中はボタンを押せなくする（二重送信の防止）、日本語の SnackBar、`await` の後の `context.mounted`、360px 幅は、これまでと同じ。
- 主要なウィジェットに `Key` を付ける（キー名は ui と qa で決めて、5章に書き足す）。
- 変更の印・期限の強調は、色だけに頼らず文字でも示す。

## 7. タスク一覧

リーダーが共有タスクリストに、担当と依存関係を付けて登録する。

| ID | 担当 | 内容 | 依存 |
|---|---|---|---|
| T0 | qa | 品質ゲートが通る状態の確認（`flutter analyze`・`flutter test`・ルールのテスト）。`test/` の問題は直し、それ以外はリーダーに報告 | なし |
| D1 | data | 契約（5章）の型と抽象メソッドを作り、ui・qa に通知する | T0 |
| D2 | data | `live_match.dart`（3.1 の候補の判定） | D1 |
| D3 | data | `live_diff.dart`（3.2・3.3 の対応付けと差分、手動の対応付け、選択の除外、項目名の日本語ラベル） | D1 |
| D4 | data | リポジトリ: `fetchCandidates`・`fetchExisting`・`applyMerge`（トランザクション、同時更新の検出、履歴の作成、子の `groupIds`・`oshiIds` の同期）・`watchHistory`・`revert` | D1, D3 |
| D5 | data | `firestore.rules`（3.8） | D4 |
| D6 | data | プロバイダ（候補・既存一式・履歴）と `liveDraftFromExisting` | D2, D4 |
| U1 | ui | `_save` の分岐: 候補探し → 候補の選択シート → 新規作成（今の流れ）か差分の確認へ | D2 |
| U2 | ui | 差分の確認画面（仮データで先に作ってよい） | D1 |
| U3 | ui | 反映と結果: 同時更新の知らせ、成功したらカレンダー追加シート → ライブ詳細へ | D4, U2 |
| U4 | ui | ライブ詳細: 「変更あり」の印、変更履歴、元に戻す（確認ダイアログつき） | D6 |
| U5 | ui | 編集: 「このライブを編集」→ `/lives/:liveId/edit` → 差分の確認へ | D6, U2 |
| U6 | ui | 本物のプロバイダへのつなぎ込みと仕上げ（仮データを消す） | U1〜U5 |
| Q1 | qa | `live_match`・`live_diff` のテスト（3.1〜3.3 の表のすべての場合、空の値、出演者の追加だけ、手動の対応付け、日付の境界） | D2, D3 |
| Q2 | qa | リポジトリのテスト（`fake_cloud_firestore`。履歴が項目ごとに1件、ID が変わらない、子の複製項目の同期、同時更新で何も書かない、変化なしで書かない、戻す） | D4 |
| Q3 | qa | ルールのテスト（`test_rules/lives_update.test.js` など）。3.8 の許可・拒否の両方と、**一度に反映できる件数の実測** | D5 |
| Q4 | qa | 画面のウィジェットテスト（候補の選択、差分の選択と反映、同時更新の知らせ、変更履歴と元に戻す、編集） | U6 |
| R1 | qa | データ層のまとめレビュー（`firebase-security-rules-auditor` スキルでルールを監査） | D1〜D6 |
| R2 | qa | 画面のまとめレビュー | U6 |
| L1 | リーダー | 結合確認、ユーザーへの動作確認手順の提示、判断ログの更新、コミット案の提示 | すべて |

Q3 の注意: 既存の `test_rules/helpers.js` を使う（エミュレータのポート 8085、プロジェクト ID `demo-oshiashi`）。Step1・Step2・グッズのルールのテストが引き続き通ることも確かめる。

## 8. バグを防ぐための進め方

1. **担当外のファイルは編集しない。** 直してほしい箇所は担当者に SendMessage で伝える。
2. **契約を先に決める。** D1 が終わるまで、ui と qa は契約に依存する部分を書かない（画面の骨組みや、テストの準備は進めてよい）。
3. **各タスクの最初に、方針を3〜5行でリーダーに送る。** 特に最初のタスクは、リーダーの返事を待ってから書き始める。
4. **作業ツリーを壊れたまま放置しない。** 書きかけのコードで `flutter analyze` が通らない状態を長く残さない（ほかのメンバーの品質ゲートも止まる）。
5. **品質ゲート:** タスクを完了にするたびに、`.claude/hooks/quality-gate.sh` が `flutter analyze`・`flutter test`・ルールのテストを実行する。失敗すると完了が差し戻される。
6. **実装タスクを終えたら、qa にレビューを依頼する。** qa はレビュー依頼を最優先で処理し、指摘は担当者に SendMessage で返す。重い指摘は「バグ修正: …」というタスクを作って担当者に割り当てる。
7. **バグの報告と回帰テスト:** qa は失敗するテストを置いたままにしない（全員の品質ゲートが止まる）。再現手順を担当者に送り、修正後に回帰テストを追加する。
8. **推測で決めず、実際に確かめる。** ルールの上限・トランザクションの挙動など、動かせば分かることはエミュレータやテストで確かめてから決める（Step2 の教訓）。
9. **同じ判定を2か所に作らない。** 「同じ公演か」「7日以内か」などの判定は data の関数に一本化し、ui は呼ぶだけにする（Step2 で「終了」の判定が二重になった教訓）。
10. **判断を記録する。** 比べた案・選んだ理由・捨てた案は、リーダーが `notes/判断ログ_A.md` に「Step4」として追記する。qa はレビューで見つけた問題を `notes/step4_レビュー記録.md` に残す。

## 9. レビューの観点

- 照合: 別のツアー（名前が似ている・出演者が同じ）を誤って候補の上位に出していないか。候補が無いときに今の新規作成の流れが変わっていないか。スクショ経由でも手入力でも同じように動くか
- 差分: 空の値で既存の値を消していないか。出演者を減らしていないか。既存の公演・受付を消していないか。日付の比較が日本時間の日で行われているか。料金（配列）の比較で順番の違いだけを「変更」にしていないか
- 反映: 1回の書き込み（トランザクション）にまとまっているか。ID を変えていないか。変わった項目ごとに履歴が1件ずつあるか。ライブの出演者が増えたとき、公演・受付の `groupIds`・`oshiIds` もそろえているか。何も変わらないときに書き込んでいないか
- 同時更新: 差分を作った後に他人が更新したら、上書きせずに止まるか
- 元に戻す: その後に別の変更があるときに止まるか。戻した操作も履歴に残るか。値が無かった項目（`before` が無い）を戻すと項目が消えるか
- ルール: 他人の uid の `updatedBy`、`createdBy`・`createdAt` の書き換え、出演者の削除、`liveId` の付け替え、親を更新しない履歴だけの作成、履歴の書き換え・削除、既存ライブへの公演の追加でライブの `updatedAt` を書かない場合、が拒否されるか。グッズのルールに影響していないか
- 申込状況: 既存の受付に反映したとき、ほかのユーザーの申込状況や「次の締切」が壊れないか
- カレンダー: 更新後も公演・受付の ID が同じで、追加済みの予定と対応が保たれるか
- 二重送信、`await` の後の `context.mounted`、Stream の購読の解除

## 10. ユーザーが行う動作確認

ルールを変えた後は、実際の Firestore で試す前に、人間が `firebase deploy --only firestore:rules` でデプロイする（`firestore.rules` は横山さんと共有なので、デプロイ前に一声かける）。

1. 推しを1つフォローし、手入力でライブ（公演1件・受付2件）を登録する
2. 同じライブをもう一度手入力する（ライブ名をカタカナ・全角などに変える）→ 候補として既存のライブが出る
3. 「このライブに反映する」→ 差分の確認で「変化なし」→「すでに登録済みです」と出て、ライブは増えない
4. 受付の入金期限だけを変えて再登録 → 差分に「変更（前 → 後）」が出る → 反映 → ライブ詳細に「変更あり」と変更の内容が出る
5. 公演を1件追加して再登録 → 「追加」として反映される。元の公演は残る
6. 別のアカウントでログインし、同じ推しをフォロー → 変更後の内容と変更履歴が見える。申込状況はそれぞれのまま
7. 変更履歴から入金期限の変更を「元に戻す」→ 元の値に戻り、戻した操作も履歴に残る
8. 2つのタブで同じライブの差分の確認を開き、片方で反映した後にもう片方で反映 → 「ほかの人が先に更新しました」と出て、上書きされない
9. ライブ詳細の「このライブを編集」→ 会場名を直して保存 → 差分の確認を経て反映される
10. スクショ読み取り（`/register`）で、登録済みのライブの告知画像を読ませる → 候補が出て、差分の確認に進める
11. カレンダーに追加済みの予定がある受付を更新 → 保存後のシートから同じ予定が上書きされる（新しい予定が重複して増えない）

## 11. リーダー（メインセッション）の進め方

1. この文書と `CLAUDE.md` を読む。リーダーは自分でコードを書かず、調整・タスク管理・ユーザーへの確認に専念する。
2. `git status -sb` で `feature/step4` にいて最新であることを確かめる（0章）。
3. `flutter analyze`・`flutter test`・ルールのテストを実行し、品質ゲートが通る状態かを確認する。通らなければ、原因（どのファイルか、誰のコードか）をユーザーに報告して判断を仰ぐ。
4. 「3. 実装前に合意すること」を、項目ごとに推奨案と理由を付けてユーザーに示す。まとめて質問し、回答を判断ログに書き、3章を更新する。**合意するまでチームメイトは作らない。**
5. 新しい依存パッケージが必要になったら、ユーザーの了承を得てからリーダーが追加する。
6. チームメイトを3人作る。各チームメイトはリーダーの会話履歴を見られないので、作成時の指示に必要なことを書く。
   - `dev-data` エージェントタイプで、名前 `data` のチームメイト。指示: 「markdown/feature_step4_merge_plan.md を読み、担当 data として D1 から始めて。D1 の方針を先に私（リーダー）に送ること。グッズの GoodsRepository.update とルールの isValidAuditOnUpdate・isValidHistory を参考にしてよいが、グッズのファイルは変えないこと」
   - `dev-ui` エージェントタイプで、名前 `ui` のチームメイト。指示: 「markdown/feature_step4_merge_plan.md を読み、担当 ui として、D1 の契約が届くまでは U2 の骨組みから始めて。live_form_page.dart は 3.9 の範囲以外を変えないこと」
   - `dev-qa` エージェントタイプで、名前 `qa` のチームメイト。指示: 「markdown/feature_step4_merge_plan.md を読み、担当 qa として T0 から始めて。以降はレビュー依頼を最優先に。ルールの読み取り上限（3.8）は必ず実測すること」
7. 7章のタスクを共有タスクリストに登録する（担当・依存関係つき）。
8. 進行中は、担当外ファイルの編集・同じファイルの同時編集・契約の食い違い・**横山さんのファイルへの想定外の変更**・**同じ判定の二重実装**を見張る。チームメイトからの質問のうちユーザーが決めるべきものは、まとめてユーザーに聞く。
9. すべて完了したら L1 を行う。ユーザーに 10章の動作確認手順と、コミット案（メッセージと含めるファイル、横山さんのファイルを変えた箇所）を示し、了承を得てからコミットする。`git push`・Pull Request・ルールのデプロイはユーザーが行う。
10. 最後にチームメイトを終了させ、チームを片付ける。
