// chats（個人チャット）と messages のルール（G-0。横山さんの担当）。
// 今の動きを確かめるテスト。ルールの中身は変えない。
// ※ lastMessage の単独書き換え・closed 後の送信・存在確認は、監査
//   （notes/step7_ルール監査.md #4〜#6）で「軽微」とした既知の動きなので、固めるテストは書かない。
import { after, afterEach, before, describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';
import { createTestEnv } from './helpers.js';

let testEnv;
before(async () => {
  testEnv = await createTestEnv();
});
afterEach(async () => {
  await testEnv.clearFirestore();
});
after(async () => {
  await testEnv.cleanup();
});

const db = (uid = 'alice') => testEnv.authenticatedContext(uid).firestore();
const anon = () => testEnv.unauthenticatedContext().firestore();

async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

const old = new Date('2026-01-01T00:00:00Z');

const post = {
  uid: 'alice',
  displayName: 'アリス',
  groupIds: ['g1'],
  oshiIds: [],
  tags: ['trade'],
  gives: [],
  wants: [],
  giveKeys: [],
  wantKeys: [],
  handover: ['mail'],
  performanceIds: [],
  images: [],
  status: 'open',
  createdAt: old,
  updatedAt: old,
};
const storedReply = (approved) => ({
  uid: 'bob',
  displayName: 'ボブ',
  text: 'お願いします',
  approved,
  createdAt: old,
});
const storedChat = (extra = {}) => ({
  postId: 'p1',
  replyId: 'r1',
  memberUids: ['alice', 'bob'],
  memberNames: { alice: 'アリス', bob: 'ボブ' },
  lastMessageAt: old,
  status: 'open',
  createdAt: old,
  ...extra,
});
const chat = (as = 'alice', id = 'p1_bob') => doc(db(as), 'chats', id);

// 承認済みの返信と、既存のチャットを用意する
async function setupChat(extra = {}) {
  await seed('tradePosts/p1', post);
  await seed('tradePosts/p1/replies/r1', storedReply(true));
  await seed('chats/p1_bob', storedChat(extra));
}

describe('チャットの作成（返信の承認と同じバッチ）', () => {
  const newChat = (extra = {}) => ({
    postId: 'p1',
    replyId: 'r1',
    memberUids: ['alice', 'bob'],
    memberNames: { alice: 'アリス', bob: 'ボブ' },
    lastMessageAt: serverTimestamp(),
    status: 'open',
    createdAt: serverTimestamp(),
    ...extra,
  });
  const batchOf = (as, chatData, chatId = 'p1_bob') => {
    const d = db(as);
    const batch = writeBatch(d);
    batch.update(doc(d, 'tradePosts', 'p1', 'replies', 'r1'), { approved: true });
    batch.set(doc(d, 'chats', chatId), chatData);
    return batch;
  };
  const setup = async () => {
    await seed('tradePosts/p1', post);
    await seed('tradePosts/p1/replies/r1', storedReply(false));
  };

  test('投稿者が作れる（postSummary 付きでも）', async () => {
    await setup();
    await assertSucceeds(batchOf('alice', newChat({ postSummary: 'アクスタ' })).commit());
  });
  test('投稿者以外は作れない', async () => {
    await setup();
    await assertFails(batchOf('bob', newChat()).commit());
  });
  test('ID が {postId}_{返信した人の uid} でなければ作れない', async () => {
    await setup();
    await assertFails(batchOf('alice', newChat(), 'p1_carol').commit());
  });
  test('参加者・表示名・status が違えば作れない', async () => {
    await setup();
    await assertFails(batchOf('alice', newChat({ memberUids: ['alice', 'carol'] })).commit());
    await assertFails(batchOf('alice', newChat({ memberUids: ['bob', 'alice'] })).commit());
    await assertFails(
      batchOf('alice', newChat({ memberNames: { alice: 'ニセ', bob: 'ボブ' } })).commit(),
    );
    await assertFails(batchOf('alice', newChat({ status: 'closed' })).commit());
  });
  test('lastMessage・lastReadAt を最初から書くことはできない', async () => {
    await setup();
    await assertFails(batchOf('alice', newChat({ lastMessage: 'こんにちは' })).commit());
  });
  test('返信を承認しない単独の作成はできない', async () => {
    await setup();
    await assertFails(setDoc(chat('alice'), newChat()));
  });
  test('削除はできない', async () => {
    await setupChat();
    await assertFails(deleteDoc(chat('alice')));
  });
});

describe('チャットの読み取り', () => {
  test('参加者は読める。第三者・未ログインは読めない', async () => {
    await setupChat();
    await assertSucceeds(getDoc(chat('alice')));
    await assertSucceeds(getDoc(chat('bob')));
    await assertFails(getDoc(chat('carol')));
    await assertFails(getDoc(doc(anon(), 'chats', 'p1_bob')));
  });
  test('memberUids に自分を含む一覧は読める。絞らない一覧は読めない', async () => {
    await setupChat();
    const q = query(
      collection(db('alice'), 'chats'),
      where('memberUids', 'array-contains', 'alice'),
      orderBy('lastMessageAt', 'desc'),
    );
    await assertSucceeds(getDocs(q));
    await assertFails(getDocs(collection(db('alice'), 'chats')));
    const other = query(
      collection(db('carol'), 'chats'),
      where('memberUids', 'array-contains', 'alice'),
    );
    await assertFails(getDocs(other));
  });
});

describe('チャットの更新', () => {
  test('参加者は status を closed にできる', async () => {
    await setupChat();
    await assertSucceeds(updateDoc(chat('bob'), { status: 'closed' }));
  });
  test('既読は自分の分だけ、サーバー時刻で書ける', async () => {
    await setupChat();
    await assertSucceeds(
      updateDoc(chat('alice'), { lastReadAt: { alice: serverTimestamp() } }),
    );
    await assertFails(updateDoc(chat('alice'), { lastReadAt: { bob: serverTimestamp() } }));
    await assertFails(updateDoc(chat('alice'), { lastReadAt: { alice: old } }));
  });
  test('第三者は更新できない', async () => {
    await setupChat();
    await assertFails(updateDoc(chat('carol'), { status: 'closed' }));
  });
  test('許可された項目以外（memberUids・postId）は変えられない', async () => {
    await setupChat();
    await assertFails(updateDoc(chat('alice'), { memberUids: ['alice', 'carol'] }));
    await assertFails(updateDoc(chat('alice'), { postId: 'p2' }));
  });
  test('status が範囲外なら更新できない', async () => {
    await setupChat();
    await assertFails(updateDoc(chat('alice'), { status: 'hidden' }));
  });
});

describe('メッセージ', () => {
  const m = (as, id = 'm1') => doc(db(as), 'chats', 'p1_bob', 'messages', id);
  const send = (as, text = 'こんにちは', uid = as, id = 'm1') => {
    const d = db(as);
    const batch = writeBatch(d);
    batch.set(doc(d, 'chats', 'p1_bob', 'messages', id), {
      uid,
      text,
      createdAt: serverTimestamp(),
    });
    batch.update(doc(d, 'chats', 'p1_bob'), {
      lastMessage: text,
      lastMessageAt: serverTimestamp(),
    });
    return batch;
  };

  test('参加者は、チャットの更新と同じバッチで送れる', async () => {
    await setupChat();
    await assertSucceeds(send('alice').commit());
    await assertSucceeds(send('bob', 'どうも', 'bob', 'm2').commit());
  });
  test('第三者は送れない', async () => {
    await setupChat();
    await assertFails(send('carol').commit());
  });
  test('uid が他人・本文が空白だけ・1001文字なら送れない', async () => {
    await setupChat();
    await assertFails(send('alice', 'こんにちは', 'bob').commit());
    await assertFails(send('alice', '　 ').commit());
    await assertFails(send('alice', 'あ'.repeat(1001)).commit());
  });
  test('チャットを更新しない単独の送信はできない', async () => {
    await setupChat();
    await assertFails(
      setDoc(m('alice'), { uid: 'alice', text: 'やあ', createdAt: serverTimestamp() }),
    );
  });
  test('参加者だけが読める', async () => {
    await setupChat();
    await seed('chats/p1_bob/messages/m1', { uid: 'alice', text: 'やあ', createdAt: old });
    await assertSucceeds(getDoc(m('bob')));
    await assertSucceeds(getDocs(collection(db('alice'), 'chats', 'p1_bob', 'messages')));
    await assertFails(getDoc(m('carol')));
    await assertFails(getDoc(doc(anon(), 'chats', 'p1_bob', 'messages', 'm1')));
  });
  test('更新・削除はできない（送信者でも）', async () => {
    await setupChat();
    await seed('chats/p1_bob/messages/m1', { uid: 'alice', text: 'やあ', createdAt: old });
    await assertFails(updateDoc(m('alice'), { text: '編集' }));
    await assertFails(deleteDoc(m('alice')));
  });
});
