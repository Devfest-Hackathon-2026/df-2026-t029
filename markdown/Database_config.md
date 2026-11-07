# おしあし（仮）データベース設計案

> 本ドキュメントは、仕様書「9. 未決定事項」のうち「Firestore のデータ構造」と「推し・ライブ・公演・受付の具体的なデータ項目」についての設計案である。
> チームで合意した時点で、仕様書の決定事項に移す。
> グッズ交換マッチング（G-0）の項目を、3.9〜3.13 に追記した。

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
goods/{goodsId}                   グッズ
  └ history/{historyId}           変更履歴
tradePosts/{postId}               交換・売買の投稿
  └ replies/{replyId}             返信
chats/{chatId}                    個人チャット
  └ messages/{messageId}          メッセージ
users/{uid}                       ユーザー（個人データ）
  ├ applications/{receptionId}    申込状況
  ├ myLives/{liveId}              自分のライブ一覧
  └ memories/{performanceId}      ライブの記録
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

`lives`・`performances`・`receptions`・`goods` の各ドキュメントのサブコレクションとする。1回の更新で複数の項目が変わった場合は、項目ごとに1件作成する。

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
| themeColor | number | | テーマカラー（色の ARGB の32ビット値。例：`0xFFE91E63`）。未設定なら初期の色を使う。本人がプロフィールの編集画面で選ぶ（ホームのデザイン D-6） |

### 3.8 users/{uid}/applications/{receptionId}（申込状況）

ドキュメント ID は受付 ID と同じにし、1受付につき1件とする。

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| liveId | string | ○ | ライブの ID（絞り込み用） |
| status | string | ○ | 申込状況（4章） |
| updatedAt | timestamp | ○ | 更新日時 |

### 3.8.1 users/{uid}/myLives/{liveId}（自分のライブ一覧）

ドキュメント ID はライブ ID と同じにし、1ライブにつき1件とする。ここに入っているライブだけが、ライブ一覧と次の締切に出る。外しても申込状況（`applications`）は消さない。

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| addedAt | timestamp | ○ | 追加した日時（サーバー時刻） |

### 3.9 goods（グッズ）

共通データとする。運営の承認は挟まず、ログイン済みのユーザーなら誰でも登録・更新できる。

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| name | string | ○ | グッズ名（例：TOUR 2026 ランダムアクスタ） |
| aliases | array | | 別名・略称（string の配列）。検索と重複確認に使う |
| category | string | ○ | 種別（4章） |
| groupIds | array | △ | 対象のグループの ID（string の配列） |
| oshiIds | array | △ | 個人名義のグッズの場合の推しの ID（string の配列） |
| liveId | string | | ツアーグッズの場合のライブの ID |
| price | number | | 定価（円）。売買の投稿で「定価」と並べて表示する |
| officialUrl | string | | 公式の販売ページの URL |
| variants | array | ○ | 種類の一覧（下記）。1つ以上 |
| createdBy / createdAt / updatedBy / updatedAt | | ○ | lives と同じ |

△：`groupIds` と `oshiIds` の少なくとも一方は必須とする（lives と同じ）。

**種類（variants の要素）**

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| id | string | ○ | グッズ内で一意の短い ID（`v1`、`v2`…の連番） |
| name | string | ○ | 種類の名前（例：メンバーA、絵柄1） |
| oshiId | string | | 紐づくメンバーの ID |

### 3.10 tradePosts（交換・売買の投稿）

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| uid | string | ○ | 作成者の uid |
| displayName | string | ○ | 作成者の表示名（複製） |
| groupIds | array | △ | 対象のグループの ID（string の配列） |
| oshiIds | array | △ | 対象の推し（個人）の ID（string の配列） |
| tags | array | ○ | 取引のタグ（4章）。1つ以上。複数選べる |
| priceType | string | | 価格の区分（4章）。`tags` に `sell` か `buy` を含む場合は必須 |
| gives | array | | 譲セットの一覧（下記） |
| wants | array | | 求セットの一覧（下記） |
| giveKeys | array | | 譲の検索用キー（string の配列。5章） |
| wantKeys | array | | 求の検索用キー（string の配列。5章） |
| handover | array | ○ | 受け渡し方法（4章）。両方可 |
| performanceIds | array | | 手渡しの公演の ID（string の配列）。複数可 |
| xAccount | string | | X のユーザー名（@ なし） |
| note | string | | 備考 |
| images | array | | 投稿全体の写真（Storage のパスの配列） |
| status | string | ○ | 状態（4章） |
| createdAt | timestamp | ○ | 作成日時 |
| updatedAt | timestamp | ○ | 更新日時 |

△：`groupIds` と `oshiIds` の少なくとも一方は必須とする（lives と同じ）。

**譲セット（gives の要素）**

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| items | array | ○ | 品目の一覧（下記） |
| pickCount | number | | 選べる数（「この中から N 個」）。省略時は指定なし。マッチングの判定には使わない |
| images | array | | セットの写真（Storage のパスの配列） |
| note | string | | 備考 |

**品目（items の要素）**

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| goodsId | string | ○ | グッズの ID |
| variantId | string | ○ | 種類の ID |
| label | string | ○ | 表示名（複製。例：ランダムアクスタ（メンバーA）） |

**求セット（wants の要素）**

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| targets | array | ○ | 求める対象の一覧（下記） |
| pickCount | number | | 選べる数。省略時は指定なし |
| note | string | | 備考 |

**求める対象（targets の要素）**

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| type | string | ○ | 求の出し方（4章） |
| goodsId | string | | `type` が `item`・`goods` の場合 |
| variantId | string | | `type` が `item` の場合 |
| oshiId | string | | `type` が `member` の場合 |
| label | string | ○ | 表示名（複製。例：メンバーC） |

**例**

```
tradePosts/p1
  uid: "u1", displayName: "ユーザーA"
  groupIds: ["g1"], tags: ["trade"]
  gives: [{
    items: [
      {goodsId: "abc123", variantId: "v1", label: "ランダムアクスタ（メンバーA）"},
      {goodsId: "abc123", variantId: "v2", label: "ランダムアクスタ（メンバーB）"}
    ],
    pickCount: 1
  }]
  wants: [{
    targets: [{type: "member", oshiId: "o3", label: "メンバーC"}]
  }]
  giveKeys: ["item:abc123#v1", "item:abc123#v2", "goods:abc123", "member:o1", "member:o2"]
  wantKeys: ["member:o3"]
  handover: ["mail"], status: "open"
```

### 3.11 tradePosts/{postId}/replies/{replyId}（返信）

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| uid | string | ○ | 書いた人の uid |
| displayName | string | ○ | 表示名（複製） |
| text | string | ○ | 本文（1,000 文字まで） |
| linkedPostId | string | | 返信した人の投稿の ID（添付する場合）。投稿者が相手の譲を確認できる |
| approved | bool | ○ | 投稿者が承認したか。初期値は `false` |
| createdAt | timestamp | ○ | 投稿日時 |

返信は時系列に一列で並べ、返信への返信（スレッド）は設けない。

### 3.12 chats（個人チャット）

ドキュメント ID は `{postId}_{返信した人の uid}` とし、同じ投稿で同じ相手とのチャットが重複しないようにする。

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| postId | string | ○ | きっかけの投稿の ID |
| replyId | string | ○ | 承認した返信の ID |
| memberUids | array | ○ | 参加者2人の uid（投稿者・返信した人）。ルールと検索に使う |
| memberNames | map | ○ | uid → 表示名（複製） |
| postSummary | string | | 投稿の要約（一覧表示用。例：譲の最初の品目の `label`） |
| lastMessage | string | | 最後のメッセージ（一覧表示用） |
| lastMessageAt | timestamp | | 最後のメッセージの日時（並び順用） |
| lastReadAt | map | | uid → 最後に読んだ日時（未読の表示用） |
| status | string | ○ | 状態（4章） |
| createdAt | timestamp | ○ | 作成日時（承認した日時） |

### 3.13 chats/{chatId}/messages/{messageId}（メッセージ）

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| uid | string | ○ | 送信者の uid |
| text | string | ○ | 本文（1,000 文字まで） |
| createdAt | timestamp | ○ | 送信日時 |

メッセージは文字のみとし、作成後の編集・削除はできない。

### 3.14 users/{uid}/memories/{performanceId}（ライブの記録）

ドキュメント ID は公演 ID と同じにし、1公演につき1件とする。

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| liveId | string | ○ | ライブの ID |
| liveTitle | string | ○ | ライブ名（複製。一覧の表示用） |
| startAt | timestamp | ○ | 開演日時（複製。並び順と状態の判定に使う） |
| venue | string | ○ | 会場名（複製） |
| seat | string | | 座席（100文字まで） |
| setlist | array | | 曲名（string の配列。100曲まで、各100文字まで） |
| impression | string | | 感想（2,000文字まで） |
| images | array | ○ | 写真（Storage のパス `users/{uid}/memories/{performanceId}/{ファイル名}` の配列。8枚まで。1枚目が表紙） |
| createdAt | timestamp | ○ | 作成日時 |
| updatedAt | timestamp | ○ | 更新日時 |

「参戦予定」「参戦済み」の状態は保存せず、`startAt` と現在時刻から判定する。
写真の保存先は `users/{uid}/memories/{performanceId}/{ファイル名}` とする（M-5）。

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

**goods の category**

| 値 | 意味 |
|---|---|
| `card` | トレカ |
| `acrylic` | アクスタ・アクキーなど |
| `badge` | 缶バッジ |
| `photo` | 生写真・ブロマイド |
| `other` | その他（チケットは対象外） |

**tradePosts の tags**

| 値 | 意味 |
|---|---|
| `trade` | 交換希望 |
| `sell` | 譲を売ります（譲渡） |
| `buy` | 求を買います（買取希望） |

**tradePosts の priceType**

| 値 | 意味 |
|---|---|
| `face` | 定価 |
| `below` | 定価以下 |

**tradePosts の handover**

| 値 | 意味 |
|---|---|
| `mail` | 郵送 |
| `hand` | 手渡し |

**tradePosts の status**

| 値 | 意味 |
|---|---|
| `open` | 募集中 |
| `closed` | 募集終了 |
| `hidden` | 非表示（運営のみが設定する） |

**求める対象（targets）の type**

| 値 | 意味 |
|---|---|
| `item` | 品目を指定 |
| `goods` | グッズの全種類 |
| `member` | メンバー指定 |

**chats の status**

| 値 | 意味 |
|---|---|
| `open` | やり取り中 |
| `closed` | 取引終了（どちらの参加者でも設定できる） |

## 5. 設計のポイント

### 予定管理・共通データ

- **推しの申請と承認**：ユーザーは `groups` または `oshis` に `status: pending` で作成する。運営は Firebase コンソールで `approved` に書き換えて公開する。申請時の検索候補には `pending` も「申請中」として表示し、重複申請を防ぐ。`pending` の推しはフォローできない。
- **グループのメンバー**：`oshis` を `groupIds` で検索して求める。`groups` 側にはメンバー一覧を持たない。
- **出演者の付け方**：グループとしての出演は `groupIds`、個人名義の出演は `oshiIds` に入れる。グループのライブに、メンバー個人の ID を重ねて入れる必要はない。
- **表示するライブの範囲**：自分のライブ一覧（`myLives`）に入っているライブ。ライブを追加する画面では、選んだ推しのライブ（グループ・本人・所属グループ）を探す（`groupIds` と `oshiIds` でそれぞれ検索し、結果をまとめる）。推しをフォローしただけでは、ライブは一覧に入らない。
- **アプグレなどの表示条件**：自分の `applications` に、同じ `liveId` で `won` または `paid` のものがあれば、`winnersOnly` が `true` の受付を表示・通知する。
- **複製した項目の整合**：ライブの `groupIds`・`oshiIds` を変更したときは、そのライブの公演・受付の値も合わせて更新する。

### グッズ交換（3.9〜3.13）

- **検索用キー**：譲の品目1つから、`item:{goodsId}#{variantId}`・`goods:{goodsId}`・`member:{oshiId}`（種類に `oshiId` がある場合のみ）の3種類を作る。求める対象1つからは、`type` に応じていずれか1つを作る。キーは投稿の保存時に `goods` の種類を参照して作り、重複を除いて保存する。
- **種類の ID**：種類は追加と名前の変更のみとし、削除しない。既存の投稿のキーが参照先を失わないようにするためである。種類のないグッズは、「通常」という種類を1つ持たせる。
- **グッズの検索・重複確認**：対象の推しで絞り込んだうえで、`name` と `aliases` をアプリ側で照合する。
- **表示名の複製**：`users/{uid}` は本人しか読めないため、`tradePosts`・`replies`・`chats` に表示名を複製する。
- **グッズ名の複製**：品目と求める対象に `label` を持たせ、一覧の表示のたびに `goods` を読まずに済むようにする。
- **掲示板の検索**：Firestore では推し（`groupIds` または `oshiIds` の `array-contains`）と `status` で絞り込み、グッズ・譲／求・タグ・公演の絞り込みはアプリ側で行う。配列の検索は1回の検索に1つまでしか使えないためである。一覧は `updatedAt` の新しい順とする。
- **マッチングの検索**：自分の `wantKeys` で、`giveKeys` に一致するものを含む `status: open` の投稿を探す（`array-contains-any`。1回30個までのため、超える場合は分けて検索する）。見つかった投稿のうち、相手の `wantKeys` が自分の `giveKeys` と一致するものを相互マッチとする。タグは判定に使わず、結果に表示する。
- **写真の枚数**：セットの `images` と投稿全体の `images` の合計で8枚までとし、アプリ側で制限する。
- **返信の承認とチャットの作成**：投稿者が承認すると、返信の `approved` を `true` にする更新と、チャットの作成を1回のバッチで書き込む。
- **メッセージの送信**：メッセージの作成と、チャットの `lastMessage`・`lastMessageAt` の更新を1回のバッチで書き込む。
- **チャット一覧**：`memberUids` に自分を含むチャットを、`lastMessageAt` の新しい順に取得する（複合インデックスが必要）。

## 6. セキュリティルールの方針（案）

| 対象 | 方針 |
|---|---|
| groups / oshis | ログイン済みなら読める。作成は `status` が `pending` の場合のみ。更新・削除は運営のみ（コンソール） |
| lives / performances / receptions | ログイン済みなら読み書きできる（7章） |
| goods | ログイン済みなら読める・作成・更新できる。削除は不可 |
| history | ログイン済みなら読める・作成できる。更新・削除は不可 |
| tradePosts | ログイン済みなら読める（`hidden` は作成者のみ）。作成は `uid` が本人で、`status` が `open` の場合のみ。更新は作成者のみで、`status` は `open`・`closed` の間でのみ変更できる。削除は不可（募集終了で代替する）。`hidden` への変更は運営のみ（コンソール） |
| replies | ログイン済みなら読める。作成は `uid` が本人で、`approved` が `false` の場合のみ。`approved` を `true` にできるのは投稿者のみ（他の項目は変更不可）。削除は書いた本人のみ |
| chats | 参加者のみ読める。作成は投稿者のみで、同じバッチでその返信を承認する場合に限る。更新は参加者のみで、`lastMessage`・`lastMessageAt`・`lastReadAt`・`status` に限る |
| messages | 参加者のみ読める・作成できる（`uid` が本人）。更新・削除は不可 |
| users/{uid} 以下 | 本人のみ読み書きできる |
| users/{uid}/myLives | 本人のみ読み書きできる。作成・更新は項目が `addedAt` だけで `addedAt == request.time`、そのライブが存在する場合のみ（同じバッチで作る場合があるので `existsAfter`）。削除は本人なら可 |

## 7. 未決定事項・今後の追加

- **共通データを更新できる範囲**：当面はログイン済みユーザー全員とし、誤った更新は履歴から戻す。照合・更新機能の開発時に確定する。
- **申込の席種・枚数・支払額**：費用管理（P3）の開発時に、`applications` に追加する。
- **写真の保存先（Cloud Storage のパス構成）**：決定（11/7）。メモリーは `users/{uid}/memories/{performanceId}/{ファイル名}`（本人だけが読み書き）、グッズ交換は `tradePhotos/{uid}/{ファイル名}`（ログイン済みなら読める。作成・削除は本人だけ）。どちらも 5MB 未満の画像だけ。ルールは `storage.rules`。
- **遠征・通知（FCM トークンなど）**：各機能の開発時に追加する。