// デモ用データの定義：デモ用アカウント（けん）と相手役の個人データ（すべて架空）。
// users/{uid} 以下（プロフィール・ライブ一覧・申込状況・メモリー）と、
// けん・相手役の交換の投稿・返信・チャットを作る。
// 仕様はプロジェクトの「デモ用データの仕様書」6章。

import {
  LIVES,
  at,
  groupId,
  liveId,
  oshiId,
  perfId,
  recId,
} from './demo_data.mjs';
import {
  DEMO_USERS,
  give,
  postId,
  tradePostDoc,
  want,
  wants,
} from './demo_trade.mjs';

const liveByKey = new Map(LIVES.map((l) => [l.key, l]));

/** 公演の情報（メモリーに複製する値） */
function perfInfo(b, liveKey, n) {
  const live = liveByKey.get(liveKey);
  const [day, hour, minute, venue] = live.perfs[n - 1];
  return {
    id: perfId(liveKey, n),
    liveId: liveId(liveKey),
    title: live.title,
    startAt: at(b, day, hour, minute),
    venue,
  };
}

// ---------------------------------------------------------------
// けん（デモ用アカウント）
// ---------------------------------------------------------------

function buildKenProfile(b, uid, name) {
  const docs = [];
  const u = `users/${uid}`;

  docs.push({
    path: u,
    data: {
      displayName: name,
      xAccount: 'ken',
      followingGroupIds: ['workspace', 'maps', 'okvoices', 'playlists'].map(
        groupId,
      ),
      followingOshiIds: ['gmail', 'meet'].map(oshiId),
      createdAt: at(b, -30, 12),
      // これが無いと、アプリはプロフィール未作成と判断する
      profileUpdatedAt: at(b, -30, 12),
      // themeColor は入れない（動画の中で選んで見せるため）
    },
  });

  // 自分のライブ一覧（フォロー中でも、L09・L13・L15 などはあえて入れない）
  const myLives = [
    'workspace-tour',
    'cloud-fest',
    'workspace-1st',
    'maps-oneman',
    'maps-release',
    'okvoices-1st',
    'playlists-tour',
    'playlists-dawn',
    'meet-acoustic',
  ];
  myLives.forEach((key, i) => {
    docs.push({
      path: `${u}/myLives/${liveId(key)}`,
      data: { addedAt: at(b, -10 + i, 21) },
    });
  });

  // 申込状況（ホームの「次の締切」に、急ぎ・近い・通常の3段階が出るように）
  const applications = [
    ['workspace-tour', 'fc', 'won'], // 入金期限 D+7（通常）＋アップグレード（当選者のみ）D+1（近い）
    ['cloud-fest', 'pg', 'won'], // 入金期限 D+2（近い）
    ['workspace-1st', 'general', 'paid'],
    ['maps-oneman', 'fc', 'won'], // 入金期限 D+0 21:00（急ぎ）
    ['okvoices-1st', 'bd', 'applied'], // 当落発表 D+2（近い）
    ['playlists-tour', 'general', 'paid'],
    ['playlists-dawn', 'general', 'paid'],
    ['meet-acoustic', 'general', 'paid'],
    // maps-release の整理券は未申込のまま（申込期限 D+2 が近い締切に出る）
  ];
  applications.forEach(([live, rec, status], i) => {
    docs.push({
      path: `${u}/applications/${recId(live, rec)}`,
      data: { liveId: liveId(live), status, updatedAt: at(b, -9 + i, 22) },
    });
  });

  // メモリー（参戦済み3件・参戦予定2件）
  const memories = [
    {
      perf: ['workspace-1st', 1],
      seat: '1階 B列 12番',
      setlist: [
        'はじまりの受信箱',
        'Shared with You',
        '既読のメロディ',
        'スター付きのきみ',
        'ミッドナイト・リマインダー',
        'ひかりの方へ',
        'またね、Work☆Space',
        'Shared with You（アンコール）',
      ],
      impression:
        '初めてのワンマンライブ。開演の瞬間に会場がペンライトの4色に染まって鳥肌が立った。' +
        'メルルちゃんのソロパートで泣きそうになった。' +
        'アンコールでもう一度「Shared with You」を歌ってくれたのが最高だった。次のツアーも絶対行く！',
      written: [-19, 23],
    },
    {
      perf: ['playlists-dawn', 1],
      seat: 'スタンディング 整理番号 A-58',
      setlist: [
        'おすすめの次に',
        '自動再生',
        '再生リストの海',
        'ラストシグナル',
        '始発列車',
        'おやすみ東京',
      ],
      impression:
        'ライブハウスの近さがすごい。ミュージックのベースソロで床が揺れた。' +
        '最後の「おやすみ東京」は、みんなで大合唱だった。',
      written: [-7, 1],
    },
    {
      perf: ['meet-acoustic', 1],
      seat: '自由席',
      setlist: ['ミュートを外して', '海の見える部屋', '手紙', '灯り', 'またあした'],
      impression: 'ギター1本と歌だけなのに、ずっと聴いていたくなる2時間だった。新曲の「灯り」が特によかった。',
      written: [-2, 22],
    },
    {
      perf: ['workspace-tour', 1],
      seat: 'アリーナ C3ブロック 8列 21番',
      written: [-1, 19],
    },
    {
      perf: ['cloud-fest', 1],
      written: [-2, 12],
    },
  ];
  for (const m of memories) {
    const p = perfInfo(b, ...m.perf);
    const writtenAt = at(b, m.written[0], m.written[1]);
    docs.push({
      path: `${u}/memories/${p.id}`,
      data: {
        liveId: p.liveId,
        liveTitle: p.title,
        startAt: p.startAt,
        venue: p.venue,
        ...(m.seat ? { seat: m.seat } : {}),
        ...(m.setlist ? { setlist: m.setlist } : {}),
        ...(m.impression ? { impression: m.impression } : {}),
        images: [],
        createdAt: writtenAt,
        updatedAt: writtenAt,
      },
    });
  }
  return docs;
}

function buildKenTrade(b, uid, name) {
  const ken = { uid, displayName: name, xAccount: 'ken' };
  const u01 = DEMO_USERS.u01;
  const u03 = DEMO_USERS.u03;
  const docs = [];

  // けんの投稿（ken-1・ken-2 は架空のユーザーの 01〜03 とマッチする）
  docs.push(
    tradePostDoc(b, {
      ...ken,
      id: 'ken-1',
      groups: ['workspace'],
      tags: ['trade'],
      gives: [give('workspace-acsta', ['calendar', 'drive'], 1)],
      wants: [wants(want.item('workspace-acsta', 'gmail'))],
      hand: ['mail', 'hand'],
      perfs: [['workspace-tour', 1]],
      note: 'メルルのアクスタを探しています。東京1日目は会場で手渡しもできます',
      upd: [-1, 22],
    }),
    tradePostDoc(b, {
      ...ken,
      id: 'ken-2',
      groups: ['workspace'],
      tags: ['trade', 'sell'],
      priceType: 'face',
      gives: [give('workspace-badge', ['docs'])],
      wants: [wants(want.member('gmail'))],
      hand: ['mail'],
      upd: [-2, 20],
    }),
    tradePostDoc(b, {
      ...ken,
      id: 'ken-3',
      groups: ['workspace'],
      tags: ['trade'],
      gives: [give('workspace-photo', ['drive'])],
      wants: [wants(want.item('workspace-photo', 'gmail'))],
      hand: ['mail'],
      status: 'closed',
      upd: [-15, 21],
    }),
  );

  // 返信
  const reply = (post, id, user, text, linked, approved, createdAt) => ({
    path: `tradePosts/${postId(post)}/replies/demo-reply-${id}`,
    data: {
      uid: user.uid,
      displayName: user.name,
      text,
      ...(linked ? { linkedPostId: postId(linked) } : {}),
      approved,
      createdAt,
    },
  });
  docs.push(
    // 未承認（動画の中で承認して、チャットができるところを見せる）
    reply(
      'ken-1',
      'ken1-a',
      u03,
      'はじめまして！メルルのアクスタをお譲りできます。ミドリのトレカと交換していただけませんか？',
      '02',
      false,
      at(b, 0, 9),
    ),
    // 承認済み（チャットがある）
    reply(
      'ken-1',
      'ken1-b',
      u01,
      'カレンちゃんのアクスタを探していました。メルルと交換お願いできますか？',
      '01',
      true,
      at(b, -1, 17, 30),
    ),
    reply(
      'ken-3',
      'ken3-a',
      u03,
      'ミドリの生写真、メルルの生写真と交換お願いします！',
      null,
      true,
      at(b, -16, 12),
    ),
  );

  // チャット
  const chat = ({ post, user, replyId, summary, status, createdAt, messages, kenReadAt }) => {
    const id = `${postId(post)}_${user.uid}`;
    const last = messages[messages.length - 1];
    const lastAt = at(b, ...last.at);
    const result = [
      {
        path: `chats/${id}`,
        data: {
          postId: postId(post),
          replyId: `demo-reply-${replyId}`,
          memberUids: [uid, user.uid],
          memberNames: { [uid]: name, [user.uid]: user.name },
          postSummary: summary,
          lastMessage: last.text,
          lastMessageAt: lastAt,
          lastReadAt: {
            [uid]: kenReadAt ? at(b, ...kenReadAt) : lastAt,
            [user.uid]: lastAt,
          },
          status,
          createdAt: at(b, ...createdAt),
        },
      },
    ];
    messages.forEach((m, i) => {
      result.push({
        path: `chats/${id}/messages/demo-msg-${i + 1}`,
        data: {
          uid: m.from === 'ken' ? uid : user.uid,
          text: m.text,
          createdAt: at(b, ...m.at),
        },
      });
    });
    return result;
  };
  docs.push(
    // やり取り中。最後のメッセージがめるまるで、けんは未読
    ...chat({
      post: 'ken-1',
      user: u01,
      replyId: 'ken1-b',
      summary: 'Work☆Space TOUR 2026 ランダムアクリルスタンド（カレン）',
      status: 'open',
      createdAt: [-1, 17, 50],
      kenReadAt: [-1, 19, 0],
      messages: [
        { from: 'ken', at: [-1, 18, 0], text: 'はじめまして、けんです。交換のご連絡ありがとうございます！' },
        { from: 'them', at: [-1, 18, 20], text: 'よろしくお願いします！郵送と手渡し、どちらがいいですか？' },
        { from: 'ken', at: [-1, 19, 0], text: '東京1日目の開演前に、物販列の近くでどうでしょう？' },
        { from: 'them', at: [-1, 20, 10], text: '大丈夫です！当日は青いトートバッグを持っています' },
        { from: 'them', at: [-1, 20, 12], text: '当日よろしくお願いします！' },
      ],
    }),
    // 取引終了
    ...chat({
      post: 'ken-3',
      user: u03,
      replyId: 'ken3-a',
      summary: 'Work☆Space 生写真セット「はじまりの受信箱」（ミドリ）',
      status: 'closed',
      createdAt: [-16, 13],
      messages: [
        { from: 'ken', at: [-16, 13, 10], text: 'ご連絡ありがとうございます、交換お願いします！' },
        { from: 'them', at: [-15, 10, 0], text: '発送しました！届いたら教えてください' },
        { from: 'ken', at: [-14, 18, 30], text: '届きました！ありがとうございました' },
      ],
    }),
  );
  return docs;
}

// ---------------------------------------------------------------
// けんの遠征メモ・出費・予算（遠征サポート・費用管理）
// 撮影の11月の合計が ¥89,700（予算 ¥100,000 の90%）になるようにしている。
//   チケット（自動）：FC先行 S席×2 ¥24,000・フェス ¥7,500・ワンマン ¥7,000・
//                     ライブハウスツアー ¥4,500・アコースティック ¥5,000
//   遠征：金沢 ¥35,500 ／ 手入力：ペンライト ¥3,800・ランダムアクスタ ¥2,400
// ---------------------------------------------------------------

function buildKenMoney(b, uid) {
  const u = `users/${uid}`;
  const docs = [];

  // 遠征メモ（users/{uid}/trips/{performanceId}）
  const trips = [
    {
      perf: ['workspace-tour', 1],
      transport: 'shinkansen',
      transportCost: 14000,
      hotelName: 'ホテル ドリームステイ東京',
      hotelCost: 9800,
      note: '物販は開場の3時間前から並ぶ。めるまるさんと開演前に交換',
      written: [-1, 22],
    },
    {
      perf: ['cloud-fest', 1],
      transport: 'shinkansen',
      transportCost: 8000,
      written: [-2, 21],
    },
    {
      perf: ['meet-acoustic', 1],
      transport: 'shinkansen',
      transportCost: 28000,
      hotelName: '金沢あかりイン',
      hotelCost: 7500,
      written: [-5, 20],
    },
  ];
  for (const t of trips) {
    const p = perfInfo(b, ...t.perf);
    const writtenAt = at(b, t.written[0], t.written[1]);
    docs.push({
      path: `${u}/trips/${p.id}`,
      data: {
        liveId: p.liveId,
        liveTitle: p.title,
        startAt: p.startAt,
        venue: p.venue,
        transport: t.transport,
        transportCost: t.transportCost,
        ...(t.hotelName ? { hotelName: t.hotelName } : {}),
        ...(t.hotelCost ? { hotelCost: t.hotelCost } : {}),
        ...(t.note ? { note: t.note } : {}),
        createdAt: writtenAt,
        updatedAt: writtenAt,
      },
    });
  }

  // チケット代の設定（FC先行は S席を2枚）
  docs.push({
    path: `${u}/ticketCosts/${recId('workspace-tour', 'fc')}`,
    data: { seat: 'S席', unitPrice: 12000, count: 2, updatedAt: at(b, -2, 19) },
  });

  // 手入力の出費（[ID, 種類, 内容, 金額, 日, ライブのキー]）
  const expenses = [
    ['1', 'goods', 'ペンライト（Work☆Space公式）', 3800, -3, 'workspace-tour'],
    ['2', 'goods', 'TOUR ランダムアクスタ 3個', 2400, -6, 'workspace-tour'],
    ['3', 'goods', '1st ライブ グッズ（タオル・Tシャツ）', 4500, -20, 'workspace-1st'],
    ['4', 'other', 'Work☆Space ファンクラブ 年会費', 4800, -25, null],
  ];
  for (const [id, category, title, amount, day, liveKey] of expenses) {
    const live = liveKey ? liveByKey.get(liveKey) : null;
    const date = at(b, day);
    docs.push({
      path: `${u}/expenses/demo-exp-${id}`,
      data: {
        category,
        title,
        amount,
        date,
        ...(live ? { liveId: liveId(live.key), liveTitle: live.title } : {}),
        createdAt: at(b, day, 21),
        updatedAt: at(b, day, 21),
      },
    });
  }

  // 1か月の予算
  docs.push({
    path: `${u}/settings/budget`,
    data: { monthly: 100000, updatedAt: at(b, -30, 12) },
  });
  return docs;
}

// ---------------------------------------------------------------
// 相手役（--partner-uid を指定したときだけ）
// ---------------------------------------------------------------

function buildPartner(b, partnerUid, partnerName) {
  const partner = { uid: partnerUid, displayName: partnerName };
  return [
    {
      path: `users/${partnerUid}`,
      data: {
        displayName: partnerName,
        followingGroupIds: [groupId('workspace')],
        followingOshiIds: [oshiId('calendar')],
        createdAt: at(b, -20, 12),
        // これが無いと、アプリはプロフィール未作成と判断する
        profileUpdatedAt: at(b, -20, 12),
      },
    },
    // けんの ken-2 と相互マッチ
    tradePostDoc(b, {
      ...partner,
      id: 'partner-1',
      groups: ['workspace'],
      tags: ['trade'],
      gives: [give('workspace-card', ['gmail'])],
      wants: [wants(want.item('workspace-badge', 'docs'))],
      hand: ['mail'],
      upd: [0, 9],
    }),
    tradePostDoc(b, {
      ...partner,
      id: 'partner-2',
      groups: ['maps'],
      tags: ['sell'],
      priceType: 'below',
      gives: [give('maps-photo', ['pin', 'route'])],
      hand: ['hand'],
      perfs: [['maps-release', 1]],
      upd: [-1, 16],
    }),
    // けんの ken-2 への返信（未承認）
    {
      path: `tradePosts/${postId('ken-2')}/replies/demo-reply-ken2-a`,
      data: {
        uid: partnerUid,
        displayName: partnerName,
        text: 'フミちゃんの缶バッジ、メルルのトレカと交換できませんか？',
        linkedPostId: postId('partner-1'),
        approved: false,
        createdAt: at(b, 0, 9, 30),
      },
    },
  ];
}

// ---------------------------------------------------------------
// まとめ
// ---------------------------------------------------------------

/**
 * 個人データを [{ path, data }] の配列で返す。
 * opts: { uid, name, partnerUid, partnerName }（partnerUid が無ければ相手役は作らない）
 */
export function buildPersonalDocs(baseMs, opts) {
  const docs = [
    ...buildKenProfile(baseMs, opts.uid, opts.name),
    ...buildKenTrade(baseMs, opts.uid, opts.name),
    ...buildKenMoney(baseMs, opts.uid),
  ];
  if (opts.partnerUid) {
    docs.push(...buildPartner(baseMs, opts.partnerUid, opts.partnerName));
  }
  return docs;
}