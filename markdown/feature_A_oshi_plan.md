# 機能A 実装計画: 推しの検索・フォロー・追加申請

> 担当A（とし）の機能を、Claude Code の agent team（リーダー＋チームメイト3人）で実装するための計画書。
> 人間とエージェントの両方が読む。仕様書 `markdown/app_config.md` の 4.1 を実装する。
> 「3. 実装前に合意すること」はすべて**提案**であり、ユーザーが合意するまで確定させない。

## 1. 範囲

**作るもの**

- 推しの検索（グループと個人をまとめて検索。申請中のものも「申請中」として表示する）
- 推しのフォロー・フォロー解除、フォロー中の推しの一覧
- 推しの追加申請（入力中に既存の推しを候補として表示し、重複登録を防ぐ）

**作らないもの**

- 運営の承認画面（ハッカソン版では、運営が Firebase コンソールで `status` を `approved` に書き換える。仕様書 4.1）
- ライブ・公演・受付、スクショ読み取りなど、ほかのメンバーの担当範囲
- 申請の取り下げ・編集（必要になったら提案する）

## 2. 前提（決定済み）

| 項目 | 内容 | 根拠 |
|---|---|---|
| 承認制 | 申請は `status: pending` で作成し、運営が `approved` に変えると公開される | 仕様書 4.1、ユーザー確認（11/5） |
| 申請中の表示 | 検索候補には `pending` も「申請中」として表示し、重複申請を防ぐ | DB 設計案 5章 |
| 申請中のフォロー | `pending` の推しはフォローできない | DB 設計案 5章 |
| 保存先 | `groups/{groupId}`（グループ）、`oshis/{oshiId}`（個人）、フォローは `users/{uid}` の `followingGroupIds`・`followingOshiIds` | DB 設計案 3.1・3.2・3.7 |
| 個人データ | `users/{uid}` 以下は本人だけが読み書きできる | 仕様書 5章 |

## 3. 実装前に合意すること（2026-11-05 すべて合意済み）

3.1〜3.7 は、リーダーが示した推奨案のとおりに、ユーザー（とし）が 2026-11-05 に合意した。経緯は `notes/判断ログ_A.md` にある。

### 3.1 検索の方式（合意済み: 案1）

Firestore には部分一致の全文検索がない。

| 案 | 内容 | 長所 | 短所 |
|---|---|---|---|
| **1（推奨）** | `groups` と `oshis` を購読して端末に持ち、正規化した名前・別名で部分一致を判定する | 部分一致・別名・ひらがな／カタカナの揺れに対応できる。インデックス不要。実装が小さい | 件数が数千を超えると読み取り回数と通信量が増える |
| 2 | 正規化した名前を保存し、前方一致の範囲クエリ（`>=` と `< q + ''`） | 件数が増えても読み取りが少ない | 前方一致のみ。別名は配列なので範囲クエリにできない |
| 3 | 名前を2文字ずつに分けた配列を保存し、`array-contains` で検索 | 部分一致ができる | `array-contains` は1条件だけなので結局端末で絞り込む。書き込みが大きくなる |
| 4 | 外部の全文検索サービス | 本格的な検索 | ハッカソンの規模に対して過剰。Google 以外の製品が前面に出る |

案1を採用。理由: ハッカソン版の推しは多くても数百件。検索処理をリポジトリの裏に隠しておけば、件数が増えたときに案2・3へ差し替えられる（判断ログに「捨てた案」として残す）。

### 3.2 名前の正規化と重複の判定（合意済み）

Dart の標準ライブラリには Unicode 正規化（NFKC）がないため、自前の関数で次の変換をする。

1. 前後の空白を除き、空白（全角スペースを含む）をすべて取り除く
2. 全角英数字・記号（U+FF01〜U+FF5E）を半角にする
3. 英字を小文字にする
4. ひらがな（U+3041〜U+3096）をカタカナにする
5. 半角カタカナを全角カタカナにする（濁点・半濁点の結合を含む）
6. 中黒（・･）、ピリオド、ハイフン類、アンダースコアを取り除く

重複の扱い:

- 正規化すると空文字になる名前（空白だけ・記号だけなど）は申請できない。別名も同様に、正規化して空文字になるものは受け付けない。
- 正規化後の名前または別名が既存の推し（申請中を含む）と**完全に一致**したら、申請ボタンを押せなくし、既存の推しへ案内する。
- **部分一致**の候補は「もしかして」として表示するが、申請は止めない。
- グループと個人で同じ名前（例: ソロ名義とグループ名が同じ）がありうるため、完全一致の判定は種別ごとに行う。

### 3.3 グループと個人の見せ方（合意済み）

- 保存先は DB 設計案どおり `groups` と `oshis` に分ける。
- 検索結果は混ぜて1つのリストに出し、「グループ」「個人」のラベルを付ける。
- 並び順: 完全一致 → 前方一致 → 部分一致。同順位なら承認済みを申請中より先、その次に名前順。
- 検索欄が空のときは、承認済みの推しを名前順に表示する。

### 3.4 ジャンルの選択肢（合意済み: 選択式・英字コードで保存）

自由入力だと表記が揺れるため選択式にし、Firestore には英字コードを保存する（表示名を後から変えられる）。

| 表示名 | 保存する値 |
|---|---|
| アイドル | `idol` |
| 声優 | `voice_actor` |
| アーティスト・バンド | `artist` |
| アニメ・ゲーム | `anime_game` |
| 俳優 | `actor` |
| VTuber・配信者 | `vtuber` |
| スポーツ | `sports` |
| その他 | `other` |

- 未知の値を読み込んだときは「その他」として表示し、落ちないようにする。
- セキュリティルールでも、作成時に `genre` がこの8つのどれかであることを検査する。

### 3.5 申請フォームの項目（合意済み）

| 項目 | 必須 | 備考 |
|---|---|---|
| 種別（グループ／個人） | ○ | |
| 名前 | ○ | 1〜50文字 |
| 別名・略称 | | 最大10個、各1〜50文字 |
| ジャンル | ○ | 3.4 の選択肢 |
| 事務所 | | 最大50文字 |
| 公式サイト URL | | `https://` で始まるもの、最大200文字 |
| 公式 X アカウント | | `@` なしで保存する（入力の先頭の `@` は取り除く）。英数字と `_` のみ、1〜15文字 |
| 所属グループ（個人のみ） | | 承認済みのグループから選ぶ。最大10個 |

グループの `label`・`fanClubName`・`parentGroupId` はハッカソン版では入力させない（DB 設計案の任意項目なので、後から追加できる）。

### 3.6 `users/{uid}` を作るタイミング（合意済み: 案1）

DB 設計案では `displayName`・`createdAt` が必須だが、現状ログイン時にユーザーのドキュメントを作っていない。

| 案 | 内容 |
|---|---|
| **1（推奨）** | 最初のフォロー時に、トランザクションで「なければ `displayName`・`createdAt`・空の配列で作成、あれば `arrayUnion` で追加」する。機能Aの中で完結する |
| 2 | ログイン直後に作る。ログイン処理（共有部分）を変えるため、ほかのメンバーとの調整が要る |

`displayName` には Google アカウントの表示名を使い、無ければ「名無し」とする。

### 3.7 セキュリティルールの方針（合意済み）

| 対象 | 方針 |
|---|---|
| `groups` / `oshis` の読み取り | ログイン済みなら読める（申請中を含む） |
| `groups` / `oshis` の作成 | ログイン済み、`status == 'pending'`、`createdBy == request.auth.uid`、`createdAt == request.time`。項目は許可したものだけ（`keys().hasOnly`）、必須項目がそろっている、型と長さ・個数の上限（3.5）を検査、`genre` は 3.4 の8つのどれか |
| `groups` / `oshis` の更新・削除 | クライアントからは不可（運営がコンソールで行う） |
| `users/{uid}` 以下 | 既存どおり本人のみ。`followingGroupIds`・`followingOshiIds` は文字列の配列で、最大200件 |

- ルールでは「同じ名前の推しが既にあるか」を調べられない。重複防止はアプリ側の確認と運営の承認で担保する。
- 「申請中の推しをフォローしていないか」もルールでは検査しない案。フォロー一覧は本人だけのデータで、ほかのユーザーに影響しないため。アプリ側（リポジトリ）で拒否する。
- 申請の連投（荒らし）はハッカソン版では運営の承認で止める。対策は判断ログに「今後の課題」として残す。

## 4. 画面

| パス | 画面 | 内容 |
|---|---|---|
| `/` | ホーム（既存） | フォロー中の推しの一覧と、「推しを探す」への導線を追加する |
| `/oshi/search` | 推しを探す | 検索欄、結果リスト（種別ラベル・申請中バッジ・フォロー／解除ボタン）、0件のときは「追加を申請する」ボタン。結果が1件以上のときも、リストの末尾に申請の導線を出す（2026-11-05 ユーザー決定） |
| `/oshi/request` | 推しの追加申請 | 3.5 の項目。入力中に類似候補を表示。送信後は「申請しました。運営の承認後に公開されます」と表示して検索画面へ戻る。検索欄の文字列を名前の初期値として受け取る |

画面の要件:

- 読み込み中・0件・エラー・結果ありの4状態をそれぞれ表示する。
- フォロー・解除・申請のボタンは、処理中は押せなくする（二重送信の防止）。
- 失敗したら日本語の SnackBar で知らせる。
- スマホの幅（360px）でも崩れない。
- テストから探せるように、主要なウィジェットに `Key` を付ける（キー名は ui と qa で決めて、6章の契約に書き足す）。
- 入力中に `TextEditingController.text` を書き換えない（Web で日本語の変換が壊れる）。

## 5. 担当とファイル

同じファイルを2人が同時に編集すると上書きが起きる。**担当外のファイルは編集せず、担当者に SendMessage で依頼する。**

| 担当 | 名前 | 編集してよいファイル |
|---|---|---|
| リーダー | （メインセッション） | `pubspec.yaml`、`pubspec.lock`、`markdown/feature_A_oshi_plan.md`、`notes/判断ログ_A.md` |
| データ層 | `data` | `lib/models/oshi*.dart`、`lib/repositories/oshi_repository.dart`、`lib/repositories/follow_repository.dart`、`lib/utils/text_normalizer.dart`、`lib/utils/oshi_search.dart`、`lib/providers/oshi_providers.dart`、`firestore.rules`、`firestore.indexes.json` |
| 画面 | `ui` | `lib/features/oshi/**`、`lib/app.dart`（ルートの追加のみ）、`lib/features/home/home_page.dart`（一覧と導線の追加のみ） |
| テスト・レビュー | `qa` | `test/**`、`test_rules/**`、`firebase.json`（`emulators` の設定のみ）、`notes/A_レビュー記録.md` |

既存の共有ファイル（`lib/main.dart`、`lib/repositories/auth_repository.dart` など）は変更しない。必要ならリーダー経由でユーザーに相談する。

## 6. 契約（インターフェース）

データ層 `data` が最初のタスク（D1）で確定させ、`ui` と `qa` に SendMessage で知らせる。変更するときも必ず知らせる。

### 6.1 確定した契約（v1、2026-11-05 D1）

叩き台（6.2）からの主な変更・追加:

- 置き場所: モデルはすべて `lib/models/oshi.dart`。`OshiGenre`（8つ、`code`・`label`、未知の値は `other`）、`OshiRequestField`、`OshiRequestException`、`OshiDuplicateException`、`FollowState` を追加した。
- `OshiSummary.fromFirestore(kind, id, data)` は、欠けた値や型が違う値を既定値にする。名前が空か `status` が不明なら `null` を返し、一覧から除く。
- `OshiRequest.validate()` は `Map<OshiRequestField, String>`（項目ごとの日本語のエラー文）を返す。空なら OK。
  - 別名の重複や、名前と同じ別名は、黙って除かずにエラーにする。空欄の別名は無視する。
  - 文字数はコードポイント単位で数える。
- `toFirestore(uid)` は、空の任意項目をキーごと省く。名前などは、正規化する前の表記で保存する。
- `findExactDuplicates(all, kind:, name:, aliases:)` を `lib/utils/oshi_search.dart` に追加した。新しい名前と別名すべてを、既存の名前と別名すべてと突き合わせる。対象は同じ種別だけで、申請中も含める。
- `OshiRepository.request` でも、リポジトリ側で重複を確かめ直す（例外は `OshiDuplicateException`）。所属グループが存在しないか未承認なら `OshiRequestException`。同時に申請された場合の競合は防げないので、最終的には運営の承認で止める。
- `FollowRepository.follow(uid, target, {String? displayName})` は、トランザクションの中で推しを読み直す。
  - 推しが無い、または申請中なら `StateError`。
  - すでにフォロー中なら何もしない。
  - 上限を超えるなら `StateError`。
- `unfollow` は、フォローしていなくても、推しが削除済みでもエラーにしない。
- プロバイダ（D6 で確定）: `oshiRepositoryProvider`、`followRepositoryProvider`、`allOshisProvider`、`followStateProvider`、`followingOshisProvider`。テストでは、リポジトリのプロバイダを `overrideWithValue` で差し替える。
- v1.1（反映済み）:
  - `OshiSummary` の `==` と `hashCode` は、すべての項目で比べる。同じ推しかどうかの判定には `key`（`'${kind.name}/$id'`）を使う。
  - フォロー上限は、`followingGroupIds` と `followingOshiIds` のそれぞれに200件まで。
  - `watchAll` は、片方の購読がエラーになったら、エラーを1回流して閉じる。再試行するときは、プロバイダを作り直す。
  - `follow` は、すでにある `users/{uid}` の `displayName`・`createdAt` を上書きしない。
- v1.2（反映済み）:
  - 文字数は `String.length`（UTF-16 単位）で数える。ルールの `size()` と同じ数え方。
  - `follow` は、`users/{uid}` があれば `update`、無ければ `set` で書く。

契約の全文は、data が ui・qa に送ったメッセージにある。

### 6.1.1 ルート

- `/oshi/search` と `/oshi/request` は、`/` の子ルートにする。`go` で移動しても、戻るボタンでホームへ戻れるようにするためで、URL は変わらない。
- 検索画面は `?q=` で検索語の初期値を受け取る。申請画面は `?name=` で名前の初期値を受け取る。

### 6.1.2 テスト用の Key（2026-11-05 ui と qa で合意）

| 画面 | Key |
|---|---|
| ホーム | `home_search_button`、`home_following_loading`、`home_following_empty`、`home_following_error`、`home_following_retry_button`、`home_following_list` |
| 推しを探す | `oshi_search_field`、`oshi_search_loading`、`oshi_search_error`、`oshi_search_retry_button`、`oshi_search_empty`、`oshi_search_request_button`（0件のとき）、`oshi_search_results`、`oshi_search_footer_request_button`（結果があるときのリストの末尾） |
| 推しの行（`ValueKey`） | `oshi_tile_<kind>_<id>`、`oshi_pending_badge_<kind>_<id>`、`oshi_follow_button_<kind>_<id>`（申請中は押せず、文言は「申請中」）、`oshi_unfollow_button_<kind>_<id>`（文言は「フォロー中」。フォロー中の判定を申請中より先に行う）。`<kind>` は `group` か `person`、`<id>` はドキュメント ID |
| 推しの追加申請 | `oshi_request_kind`、`oshi_request_name_field`、`oshi_request_alias_row_<n>`・`oshi_request_alias_field_<n>`・`oshi_request_remove_alias_button_<n>`（`<n>` は追加した順の番号で、消しても詰めない）、`oshi_request_add_alias_button`、`oshi_request_genre_field`、`oshi_request_agency_field`、`oshi_request_url_field`、`oshi_request_x_field`、`oshi_request_groups_button`、`oshi_request_group_chip_<groupId>`、`oshi_request_submit_button`、`oshi_request_exact_card`、`oshi_request_similar_card`、`oshi_request_candidate_<kind>_<id>`、`oshi_request_go_search_button`、`oshi_request_load_error` |
| 所属グループのシート | `oshi_group_picker_field`、`oshi_group_picker_item_<groupId>`、`oshi_group_picker_done_button`、`oshi_group_picker_empty` |

### 6.2 叩き台（D1 前の案。参考として残す）

```dart
enum OshiKind { group, person } // group → groups コレクション、person → oshis コレクション
enum OshiStatus { pending, approved }

/// 検索結果・フォロー一覧に出す1件分
class OshiSummary {
  final String id;
  final OshiKind kind;
  final String name;
  final List<String> aliases;
  final String genre;
  final OshiStatus status;
  final List<String> groupIds; // 個人のみ。所属グループ
  // agency, officialUrl, officialX など
}

/// 追加申請の入力
class OshiRequest { /* 3.5 の項目 */ }

abstract class OshiRepository {
  /// groups と oshis（承認済み＋申請中）をまとめて購読する
  Stream<List<OshiSummary>> watchAll();
  /// 申請を作成し、作成したドキュメントの ID を返す
  Future<String> request(OshiRequest request, {required String uid});
}

abstract class FollowRepository {
  Stream<FollowState> watch(String uid); // followingGroupIds / followingOshiIds
  /// 申請中の推しは StateError などで拒否する
  Future<void> follow(String uid, OshiSummary target, {required String displayName});
  Future<void> unfollow(String uid, OshiSummary target);
}

/// 純粋関数（テストしやすいように Firestore に依存させない）
String normalizeName(String input);                                   // lib/utils/text_normalizer.dart
List<OshiSummary> searchOshis(List<OshiSummary> all, String query);  // lib/utils/oshi_search.dart
```

## 7. タスク一覧

リーダーが共有タスクリストに、担当と依存関係を付けて登録する。

> **運用の注記（2026-11-05）:** この環境のリーダーには共有タスクリストのツールが無かった。そのため、リーダーが SendMessage でタスクを割り当て、進み具合は完了報告で管理する。`TaskCompleted` フックによる品質ゲートが自動では動かない可能性があるので、**各メンバーは完了を報告する前に `flutter analyze` と `flutter test`（`test_rules/` があればルールのテストも）を自分で実行し、結果を報告に書く。**
>
> - T0: 完了（リーダーが確認。`flutter pub get` 後に analyze 0件、test 1/1 成功）
> - T1: 完了（`fake_cloud_firestore: ^4.5.0` を dev_dependencies に追加。既存の依存は変わらない）
> - D1〜D6、U1〜U5、Q1〜Q4、R1・R2: 完了（2026-11-05）
> - L1（2026-11-05 リーダーが実行）: `flutter analyze` 0件。`flutter test` 181件すべて成功（qa が `firestoreRetry` などのテストを足した後にもう一度実行し、約9秒）。ルールのテスト 72/72 成功（CLAUDE.md のコマンド）。共有ファイル（`lib/main.dart`・`login_page.dart`・`auth_repository.dart`）に差分なし。秘密情報なし。ルールはまだデプロイしていない
> - 動作確認（10章の手順1〜6）: 2026-11-05 ユーザーが実施し、完了

| ID | 担当 | 内容 | 依存 |
|---|---|---|---|
| T0 | qa | 品質ゲートが通る状態の確認。`flutter analyze` と `flutter test` を実行し、指摘があれば `test/` 側で直す（`lib/` の指摘はリーダーに報告） | なし |
| T1 | リーダー | 必要な依存パッケージの追加（例: `fake_cloud_firestore` を dev_dependencies に）。ユーザーの了承を得てから | 3章の合意 |
| D1 | data | モデルと契約（6章）を作り、ui・qa に通知する | T0 |
| D2 | data | `normalizeName` と `searchOshis`（3.1〜3.3） | D1 |
| D3 | data | Firestore 版 `OshiRepository`（購読・申請） | D1 |
| D4 | data | Firestore 版 `FollowRepository`（フォロー・解除・購読、申請中の拒否、3.6） | D1 |
| D5 | data | `firestore.rules`（3.7） | D3, D4 |
| D6 | data | Riverpod のプロバイダ（リポジトリ、検索結果、フォロー状態） | D3, D4 |
| U1 | ui | ルートの追加とホームからの導線 | D1 |
| U2 | ui | 推しを探す画面（仮のリポジトリで先に作ってよい） | D1 |
| U3 | ui | 追加申請フォーム（類似候補、完全一致のブロック、二重送信の防止） | D1 |
| U4 | ui | ホームのフォロー中一覧 | D1 |
| U5 | ui | 本物のプロバイダへのつなぎ込みと仕上げ | D6, U2, U3, U4 |
| Q1 | qa | 正規化・検索のテスト（境界値: 空文字、空白だけ、全角半角、ひらがな／カタカナ、半角カナの濁点、記号、別名一致） | D2 |
| Q2 | qa | リポジトリのテスト（`fake_cloud_firestore`。ユーザーのドキュメントが無い状態でのフォロー、二重フォロー、申請中の拒否、解除） | D3, D4, T1 |
| Q3 | qa | ルールのテスト環境（`test_rules/`、`firebase.json` のエミュレータ設定）とテスト | D5 |
| Q4 | qa | 画面のウィジェットテスト（4状態の表示、申請中のフォロー不可、二重送信の防止） | U5 |
| R1 | qa | データ層のまとめレビュー（`firebase-security-rules-auditor` スキルでルールを監査） | D1〜D6 |
| R2 | qa | 画面のまとめレビュー | U5 |
| L1 | リーダー | 結合確認、ユーザーへの手動確認手順の提示、判断ログの更新、コミット案の提示 | すべて |

Q3 の注意: Firestore エミュレータの既定ポート 8080 は、Flutter の開発サーバーと重なる。`firebase.json` の `emulators.firestore.port` を `8085` にする。プロジェクト ID は実在のプロジェクトに触れない `demo-oshiashi` を使う。テストは `@firebase/rules-unit-testing` と Node.js 標準の `node --test` で書く案。

## 8. バグを防ぐための進め方

1. **担当外のファイルは編集しない。** 直してほしい箇所は担当者に SendMessage で伝える。
2. **契約を先に決める。** D1 が終わるまで、ui と qa は契約に依存する部分を書かない（画面の骨組みや、テスト基盤の準備は進めてよい）。
3. **各タスクの最初に、方針を3〜5行でリーダーに送る。** 特に最初のタスクは、リーダーの返事を待ってから書き始める。
4. **作業ツリーを壊れたまま放置しない。** 書きかけのコードで `flutter analyze` が通らない状態を長く残さない（ほかのメンバーの品質ゲートも止まる）。
5. **品質ゲート:** タスクを完了にするたびに、`.claude/hooks/quality-gate.sh` が `flutter analyze`・`flutter test`（`test_rules/` があればルールのテストも）を実行する。失敗すると完了が差し戻される。
6. **実装タスクを終えたら、qa にレビューを依頼する。** qa はレビュー依頼を最優先で処理し、指摘は担当者に SendMessage で返す。重い指摘は「バグ修正: …」というタスクを作って担当者に割り当てる。
7. **バグの報告と回帰テスト:** qa は失敗するテストを `test/` に置いたままにしない（全員の品質ゲートが止まる）。再現手順を担当者に送り、修正後に回帰テストを追加する。
8. **判断を記録する。** 比べた案・選んだ理由・捨てた案は、リーダーが `notes/判断ログ_A.md` に追記する。qa はレビューで見つけた問題を `notes/A_レビュー記録.md` に残す（「AI をどう使ったか」の材料）。

## 9. レビューの観点

- Firestore から読んだ値が欠けている・型が違うときに落ちないか（`fromFirestore` の防御）
- `pending` を作成できるのは本人の uid だけか。`approved` で作成できてしまわないか。更新・削除が拒否されるか
- 申請中の推しをフォローできてしまわないか（画面とリポジトリの両方）
- ユーザーのドキュメントが無い状態で最初のフォローが成功するか。フォローを2回押しても重複しないか
- 二重送信: ボタン連打で申請が2件作られないか
- `await` の後に `context.mounted` を確認しているか。Stream の購読を解除しているか
- 空文字・空白だけ・長すぎる入力・絵文字・記号だけの入力
- 正規化の揺れ（ひらがな／カタカナ、全角／半角、大文字／小文字、半角カナの濁点）
- 画面の4状態（読み込み中・0件・エラー・結果あり）が出るか
- 日本語入力中に検索や表示が壊れないか
- 不要な再描画や、検索のたびに Firestore を読み直していないか

## 10. ユーザーが行う動作確認

ルールを変えた後は、実際の Firestore で試す前に、人間が `firebase deploy --only firestore:rules` でデプロイする（`firestore.rules` はチーム共有なので、デプロイ前にほかのメンバーに一声かける）。

1. Google でログインする
2. 「推しを探す」で、まだ無い名前を検索する → 0件と「追加を申請する」が出る
3. 申請する → 検索結果に「申請中」として出て、フォローできない
4. 同じ名前をカタカナ・全角などに変えて申請しようとする → 重複として止まる
5. Firebase コンソールでその推しの `status` を `approved` に変える → 画面がリアルタイムに更新され、フォローできるようになる
6. フォローする → ホームの一覧に出る → 再読み込みしても残る → 解除できる

## 11. リーダー（メインセッション）の進め方

1. この文書と `CLAUDE.md` を読む。リーダーは自分でコードを書かず、調整・タスク管理・ユーザーへの確認に専念する。
2. `flutter analyze` と `flutter test` を実行し、品質ゲートが通る状態かを確認する。通らなければ、原因をユーザーに報告する。
3. 「3. 実装前に合意すること」を、項目ごとに推奨案と理由を付けてユーザーに示す。まとめて質問し、回答を判断ログに書き、3章を更新する。**合意するまでチームメイトは作らない。**
4. ユーザーの了承を得て T1（依存パッケージの追加）を行う。
5. チームメイトを3人作る。各チームメイトはリーダーの会話履歴を見られないので、作成時の指示に必要なことを書く。
   - `oshi-data` エージェントタイプで、名前 `data` のチームメイト。指示: 「markdown/feature_A_oshi_plan.md を読み、担当 data として D1 から始めて。D1 の方針を先に私（リーダー）に送ること」
   - `oshi-ui` エージェントタイプで、名前 `ui` のチームメイト。指示: 「markdown/feature_A_oshi_plan.md を読み、担当 ui として、D1 の契約が届くまでは U1・U2 の骨組みから始めて」
   - `oshi-qa` エージェントタイプで、名前 `qa` のチームメイト。指示: 「markdown/feature_A_oshi_plan.md を読み、担当 qa として T0 から始めて。以降はレビュー依頼を最優先に」
6. 7章のタスクを共有タスクリストに登録する（担当・依存関係つき）。
7. 進行中は、担当外ファイルの編集・同じファイルの同時編集・契約の食い違いを見張る。チームメイトからの質問のうちユーザーが決めるべきものは、まとめてユーザーに聞く。
8. すべて完了したら L1 を行う。ユーザーに 10章の動作確認手順と、コミット案（メッセージと含めるファイル）を示し、了承を得てからコミットする。`git push` とルールのデプロイはユーザーが行う。
9. 最後にチームメイトを終了させ、チームを片付ける。
