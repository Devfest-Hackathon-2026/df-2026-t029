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
      followingGroupIds: ['stellanote', 'luminous', 'prismvoice', 'midnight'].map(
        groupId,
      ),
      followingOshiIds: ['luna', 'kanata'].map(oshiId),
      createdAt: at(b, -30, 12),
      // これが無いと、アプリはプロフィール未作成と判断する
      profileUpdatedAt: at(b, -30, 12),
      // themeColor は入れない（動画の中で選んで見せるため）
    },
  });

  // 自分のライブ一覧（フォロー中でも、L09・L13・L15 などはあえて入れない）
  const myLives = [
    'stella-tour',
    'hoshizora-fest',
    'stella-1st',
    'luminous-oneman',
    'luminous-release',
    'prism-1st',
    'midnight-tour',
    'midnight-dawn',
    'kanata-acoustic',
  ];
  myLives.forEach((key, i) => {
    docs.push({
      path: `${u}/myLives/${liveId(key)}`,
      data: { addedAt: at(b, -10 + i, 21) },
    });
  });

  // 申込状況（ホームの「次の締切」に、急ぎ・近い・通常の3段階が出るように）
  const applications = [
    ['stella-tour', 'fc', 'won'], // 入金期限 D+7（通常）＋アップグレード（当選者のみ）D+1（近い）
    ['hoshizora-fest', 'pg', 'won'], // 入金期限 D+2（近い）
    ['stella-1st', 'general', 'paid'],
    ['luminous-oneman', 'fc', 'won'], // 入金期限 D+0 21:00（急ぎ）
    ['prism-1st', 'bd', 'applied'], // 当落発表 D+2（近い）
    ['midnight-tour', 'general', 'paid'],
    ['midnight-dawn', 'general', 'paid'],
    ['kanata-acoustic', 'general', 'paid'],
    // luminous-release の整理券は未申込のまま（申込期限 D+2 が近い締切に出る）
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
      perf: ['stella-1st', 1],
      seat: '1階 B列 12番',
      setlist: [
        'はじまりの夜',
        'ステラ・ノート',
        '星降るメロディ',
        'きみと見た流星',
        'ミッドナイト・テレスコープ',
        'ひかりの方へ',
        'またね、ステラ',
        'ステラ・ノート（アンコール）',
      ],
      impression:
        '初めてのワンマンライブ。開演の瞬間に会場が星空みたいになって鳥肌が立った。' +
        'ルナちゃんのソロパートで泣きそうになった。' +
        'アンコールでもう一度「ステラ・ノート」を歌ってくれたのが最高だった。次のツアーも絶対行く！',
      written: [-19, 23],
    },
    {
      perf: ['midnight-dawn', 1],
      seat: 'スタンディング 整理番号 A-58',
      setlist: [
        '終電のあとで',
        '夜明け前',
        'ネオンの海',
        'ラストシグナル',
        '始発列車',
        'おやすみ東京',
      ],
      impression:
        'ライブハウスの近さがすごい。ユウキのベースソロで床が揺れた。' +
        '最後の「おやすみ東京」は、みんなで大合唱だった。',
      written: [-7, 1],
    },
    {
      perf: ['kanata-acoustic', 1],
      seat: '自由席',
      setlist: ['ことのは', '海の見える部屋', '手紙', '灯り', 'またあした'],
      impression: 'ギター1本と歌だけなのに、ずっと聴いていたくなる2時間だった。新曲の「灯り」が特によかった。',
      written: [-2, 22],
    },
    {
      perf: ['stella-tour', 1],
      seat: 'アリーナ C3ブロック 8列 21番',
      written: [-1, 19],
    },
    {
      perf: ['hoshizora-fest', 1],
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
      groups: ['stellanote'],
      tags: ['trade'],
      gives: [give('stella-acsta', ['sora', 'hikari'], 1)],
      wants: [wants(want.item('stella-acsta', 'luna'))],
      hand: ['mail', 'hand'],
      perfs: [['stella-tour', 1]],
      note: 'ルナのアクスタを探しています。東京1日目は会場で手渡しもできます',
      upd: [-1, 22],
    }),
    tradePostDoc(b, {
      ...ken,
      id: 'ken-2',
      groups: ['stellanote'],
      tags: ['trade', 'sell'],
      priceType: 'face',
      gives: [give('stella-badge', ['mio'])],
      wants: [wants(want.member('luna'))],
      hand: ['mail'],
      upd: [-2, 20],
    }),
    tradePostDoc(b, {
      ...ken,
      id: 'ken-3',
      groups: ['stellanote'],
      tags: ['trade'],
      gives: [give('stella-photo', ['hikari'])],
      wants: [wants(want.item('stella-photo', 'luna'))],
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
      'はじめまして！ルナのアクスタをお譲りできます。ヒカリのトレカと交換していただけませんか？',
      '02',
      false,
      at(b, 0, 9),
    ),
    // 承認済み（チャットがある）
    reply(
      'ken-1',
      'ken1-b',
      u01,
      'ソラちゃんのアクスタを探していました。ルナと交換お願いできますか？',
      '01',
      true,
      at(b, -1, 17, 30),
    ),
    reply(
      'ken-3',
      'ken3-a',
      u03,
      'ヒカリの生写真、ルナの生写真と交換お願いします！',
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
    // やり取り中。最後のメッセージがるなまるで、けんは未読
    ...chat({
      post: 'ken-1',
      user: u01,
      replyId: 'ken1-b',
      summary: 'ステラノート TOUR 2026 ランダムアクリルスタンド（月城ソラ）',
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
      summary: 'ステラノート 生写真セット「はじまりの夜」（陽野ヒカリ）',
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
// 相手役（--partner-uid を指定したときだけ）
// ---------------------------------------------------------------

function buildPartner(b, partnerUid, partnerName) {
  const partner = { uid: partnerUid, displayName: partnerName };
  return [
    {
      path: `users/${partnerUid}`,
      data: {
        displayName: partnerName,
        followingGroupIds: [groupId('stellanote')],
        followingOshiIds: [oshiId('sora')],
        createdAt: at(b, -20, 12),
        // これが無いと、アプリはプロフィール未作成と判断する
        profileUpdatedAt: at(b, -20, 12),
      },
    },
    // けんの ken-2 と相互マッチ
    tradePostDoc(b, {
      ...partner,
      id: 'partner-1',
      groups: ['stellanote'],
      tags: ['trade'],
      gives: [give('stella-card', ['luna'])],
      wants: [wants(want.item('stella-badge', 'mio'))],
      hand: ['mail'],
      upd: [0, 9],
    }),
    tradePostDoc(b, {
      ...partner,
      id: 'partner-2',
      groups: ['luminous'],
      tags: ['sell'],
      priceType: 'below',
      gives: [give('luminous-photo', ['momo', 'rin'])],
      hand: ['hand'],
      perfs: [['luminous-release', 1]],
      upd: [-1, 16],
    }),
    // けんの ken-2 への返信（未承認）
    {
      path: `tradePosts/${postId('ken-2')}/replies/demo-reply-ken2-a`,
      data: {
        uid: partnerUid,
        displayName: partnerName,
        text: 'ミオちゃんの缶バッジ、ルナのトレカと交換できませんか？',
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
  ];
  if (opts.partnerUid) {
    docs.push(...buildPartner(baseMs, opts.partnerUid, opts.partnerName));
  }
  return docs;
}