# おしあし（仮）データベース設計案

> 本ドキュメントは、仕様書「9. 未決定事項」のうち「Firestore のデータ構造」と「推し・ライブ・公演・受付の具体的なデータ項目」についての設計案である。
> チームで合意した時点で、仕様書の決定事項に移す。

## 1. 方針

- 共通データ（グループ・推し・ライブ・公演・受付）は、それぞれトップレベルのコレクションに置く。
- ライブ・公演・受付には、親の ID（`liveId`）と出演者の ID（`groupIds`・`oshiIds`）を持たせる。推しやライブをまたいだ検索（例：フォロー中の推しの、期限が近い受付）をしやすくするためである。
- 個人データは、すべて `users/{uid}` 以下に置く。
- 本書では、グループと個人をあわせて「推し」と呼ぶ。`groups` がグループ、`oshis` が個人を表す。
- 日時はすべて Firestore の timestamp 型で保存し、表示時に日本時間に変換する。
- ドキュメント ID は、特に定めない限り自動 ID とする。

## 2. コレクション構成

```
groups/{groupId}                  グループ
oshis/{oshiId}                    推し（個人）
lives/{liveId}                    ライブ
  └ history/{historyId}           変更履歴
performances/{performanceId}      公演
  └ history/{historyId}           変更履歴
receptions/{receptionId}          受付
  └ history/{historyId}           変更履歴
users/{uid}                       ユーザー（個人データ）
  └ applications/{receptionId}    申込状況
```

## 3. 各コレクションの項目

### 3.1 groups（グループ）

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| name | string | ○ | グループ名 |
| aliases | array | | 別名・略称（string の配列）。検索と重複確認に使う |
| genre | string | ○ | ジャンル（アイドル、声優、アーティスト、アニメなど） |
| agency | string | | 事務所 |
| label | string | | レーベル |
| officialUrl | string | | 公式サイトの URL |
| officialX | string | | 公式 X アカウント |
| fanClubName | string | | ファンクラブ名 |
| parentGroupId | string | | 親グループの ID（サブユニットの場合） |
| status | string | ○ | 公開状態（4章） |
| createdBy | string | ○ | 申請者の uid |
| createdAt | timestamp | ○ | 申請日時 |

### 3.2 oshis（推し・個人）

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| name | string | ○ | 名前 |
| aliases | array | | 別名・愛称（string の配列）。検索と重複確認に使う |
| genre | string | ○ | ジャンル |
| groupIds | array | | 所属グループの ID（string の配列）。兼任があるため配列とする。ソロの場合は空 |
| agency | string | | 事務所 |
| officialUrl | string | | 公式サイトの URL |
| officialX | string | | 公式 X アカウント |
| status | string | ○ | 公開状態（4章） |
| createdBy | string | ○ | 申請者の uid |
| createdAt | timestamp | ○ | 申請日時 |

### 3.3 lives（ライブ）

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| title | string | ○ | ライブ名（ツアー名・イベント名） |
| groupIds | array | △ | 出演グループの ID（string の配列） |
| oshiIds | array | △ | 個人名義で出演する推しの ID（string の配列） |
| officialUrl | string | | 公式ページの URL。共通データの裏付けに使う |
| createdBy | string | ○ | 作成者の uid |
| createdAt | timestamp | ○ | 作成日時 |
| updatedBy | string | ○ | 最終更新者の uid |
| updatedAt | timestamp | ○ | 更新日時 |

△：`groupIds` と `oshiIds` の少なくとも一方は必須とする。フェスや対バンのように複数の推しが出演する場合は、すべてを入れる。

### 3.4 performances（公演）

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| liveId | string | ○ | ライブの ID |
| groupIds | array | △ | ライブと同じ値（検索用の複製） |
| oshiIds | array | △ | ライブと同じ値（検索用の複製） |
| startAt | timestamp | ○ | 開演日時 |
| openAt | timestamp | | 開場日時 |
| venue | string | ○ | 会場名 |
| prefecture | string | | 都道府県（遠征サポート用） |
| createdBy / createdAt / updatedBy / updatedAt | | ○ | lives と同じ |

### 3.5 receptions（受付）

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| liveId | string | ○ | ライブの ID |
| groupIds | array | △ | ライブと同じ値（検索用の複製） |
| oshiIds | array | △ | ライブと同じ値（検索用の複製） |
| type | string | ○ | 受付種別（4章） |
| name | string | ○ | 表示名（例：FC1次先行） |
| applyStartAt | timestamp | | 申込開始日時 |
| applyEndAt | timestamp | ○ | 申込期限 |
| resultAt | timestamp | | 当落発表日時 |
| paymentDeadline | timestamp | | 入金期限。未発表の場合は空 |
| prices | array | | 席種と料金の一覧。要素は `{seat: string, amount: number}`（円）。例：`[{seat: 'S席', amount: 9800}, {seat: 'A席', amount: 7800}]` |
| winnersOnly | bool | ○ | 当選者のみが対象の受付か（アプグレなど） |
| createdBy / createdAt / updatedBy / updatedAt | | ○ | lives と同じ |

### 3.6 history（変更履歴）

`lives`・`performances`・`receptions` の各ドキュメントのサブコレクションとする。1回の更新で複数の項目が変わった場合は、項目ごとに1件作成する。

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| field | string | ○ | 変更した項目名 |
| before | 任意 | | 変更前の値 |
| after | 任意 | | 変更後の値 |
| changedBy | string | ○ | 変更者の uid |
| changedAt | timestamp | ○ | 変更日時 |

### 3.7 users/{uid}（ユーザー）

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| displayName | string | ○ | 表示名 |
| followingGroupIds | array | | フォロー中のグループの ID（string の配列） |
| followingOshiIds | array | | フォロー中の推し（個人）の ID（string の配列） |
| createdAt | timestamp | ○ | 登録日時 |

### 3.8 users/{uid}/applications/{receptionId}（申込状況）

ドキュメント ID は受付 ID と同じにし、1受付につき1件とする。

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| liveId | string | ○ | ライブの ID（絞り込み用） |
| status | string | ○ | 申込状況（4章） |
| updatedAt | timestamp | ○ | 更新日時 |

## 4. 値の定義

**groups / oshis の status**

| 値 | 意味 |
|---|---|
| `pending` | 申請中 |
| `approved` | 公開（運営が承認済み） |

**receptions の type**

| 値 | 意味 |
|---|---|
| `fc` | FC先行 |
| `general` | 一般 |
| `upgrade` | アプグレ |
| `other` | その他（プレイガイド先行など） |

**applications の status**

| 値 | 意味 |
|---|---|
| （ドキュメントなし） | 未申込 |
| `applied` | 申込済 |
| `won` | 当選 |
| `lost` | 落選 |
| `paid` | 入金済 |

## 5. 設計のポイント

- **推しの申請と承認**：ユーザーは `groups` または `oshis` に `status: pending` で作成する。運営は Firebase コンソールで `approved` に書き換えて公開する。申請時の検索候補には `pending` も「申請中」として表示し、重複申請を防ぐ。`pending` の推しはフォローできない。
- **グループのメンバー**：`oshis` を `groupIds` で検索して求める。`groups` 側にはメンバー一覧を持たない。
- **出演者の付け方**：グループとしての出演は `groupIds`、個人名義の出演は `oshiIds` に入れる。グループのライブに、メンバー個人の ID を重ねて入れる必要はない。
- **表示するライブの範囲**：フォロー中のグループ、フォロー中の推しの所属グループ、フォロー中の推しのライブを表示する。`groupIds` と `oshiIds` でそれぞれ検索し、結果をまとめる。
- **アプグレなどの表示条件**：自分の `applications` に、同じ `liveId` で `won` または `paid` のものがあれば、`winnersOnly` が `true` の受付を表示・通知する。
- **複製した項目の整合**：ライブの `groupIds`・`oshiIds` を変更したときは、そのライブの公演・受付の値も合わせて更新する。

## 6. セキュリティルールの方針（案）

| 対象 | 方針 |
|---|---|
| groups / oshis | ログイン済みなら読める。作成は `status` が `pending` の場合のみ。更新・削除は運営のみ（コンソール） |
| lives / performances / receptions | ログイン済みなら読み書きできる（7章） |
| history | ログイン済みなら読める・作成できる。更新・削除は不可 |
| users/{uid} 以下 | 本人のみ読み書きできる |

## 7. 未決定事項・今後の追加

- **共通データを更新できる範囲**：当面はログイン済みユーザー全員とし、誤った更新は履歴から戻す。照合・更新機能の開発時に確定する。
- **申込の席種・枚数・支払額**：費用管理（P3）の開発時に、`applications` に追加する。
- **グッズ交換・遠征・ライブの記録・カレンダー連携・通知（FCM トークンなど）**：各機能の開発時に追加する。