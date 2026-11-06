// tradePosts（投稿）と replies（返信）のルール（G-0。横山さんの担当）。
// 今の動きを確かめるテスト。ルールの中身は変えない。
import { after, afterEach, before, describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
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

const base = (uid = 'alice') => ({
  uid,
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
});

const newPost = (uid = 'alice', extra = {}) => ({
  ...base(uid),
  status: 'open',
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...extra,
});

const storedPost = (extra = {}) => ({
  ...base('alice'),
  status: 'open',
  createdAt: old,
  updatedAt: old,
  ...extra,
});

const post = (as = 'alice', id = 'p1') => doc(db(as), 'tradePosts', id);

describe('投稿の読み取り', () => {
  test('ログイン済みは読める。未ログインは読めない', async () => {
    await seed('tradePosts/p1', storedPost());
    await assertSucceeds(getDoc(post('bob')));
    await assertFails(getDoc(doc(anon(), 'tradePosts', 'p1')));
  });
  test('hidden は作成者だけが読める', async () => {
    await seed('tradePosts/p1', storedPost({ status: 'hidden' }));
    await assertSucceeds(getDoc(post('alice')));
    await assertFails(getDoc(post('bob')));
  });
  test('status == open の検索は、hidden を含んでいても通る（open だけが返る）', async () => {
    await seed('tradePosts/p1', storedPost());
    await seed('tradePosts/p2', storedPost({ status: 'hidden' }));
    const q = query(
      collection(db('bob'), 'tradePosts'),
      where('groupIds', 'array-contains', 'g1'),
      where('status', '==', 'open'),
    );
    const snap = await assertSucceeds(getDocs(q));
    if (snap.size !== 1) throw new Error(`open は1件のはず: ${snap.size}`);
  });
  test('status で絞らない一覧は、hidden が混ざるので拒否される', async () => {
    await seed('tradePosts/p2', storedPost({ status: 'hidden' }));
    await assertFails(getDocs(collection(db('bob'), 'tradePosts')));
  });
});

describe('投稿の作成', () => {
  test('正しい内容なら作れる', async () => {
    await assertSucceeds(setDoc(post('alice'), newPost()));
  });
  test('売買のタグなら priceType が必須。交換だけなら書けない', async () => {
    await assertFails(setDoc(post('alice'), newPost('alice', { tags: ['sell'] })));
    await assertSucceeds(
      setDoc(post('alice'), newPost('alice', { tags: ['sell'], priceType: 'face' })),
    );
    await assertFails(setDoc(post('alice', 'p2'), newPost('alice', { priceType: 'face' })));
  });
  test('uid が他人・未ログインなら作れない', async () => {
    await assertFails(setDoc(post('alice'), newPost('bob')));
    await assertFails(setDoc(doc(anon(), 'tradePosts', 'p1'), newPost()));
  });
  test('status が open 以外なら作れない', async () => {
    await assertFails(setDoc(post('alice'), newPost('alice', { status: 'closed' })));
    await assertFails(setDoc(post('alice'), newPost('alice', { status: 'hidden' })));
  });
  test('tags・handover が空・重複・範囲外なら作れない', async () => {
    await assertFails(setDoc(post('alice'), newPost('alice', { tags: [] })));
    await assertFails(setDoc(post('alice'), newPost('alice', { tags: ['trade', 'trade'] })));
    await assertFails(setDoc(post('alice'), newPost('alice', { tags: ['gift'] })));
    await assertFails(setDoc(post('alice'), newPost('alice', { handover: [] })));
  });
  test('手渡しでないのに performanceIds があれば作れない', async () => {
    await assertFails(setDoc(post('alice'), newPost('alice', { performanceIds: ['f1'] })));
    await assertSucceeds(
      setDoc(post('alice'), newPost('alice', { handover: ['hand'], performanceIds: ['f1'] })),
    );
  });
  test('配列の上限（images 9・giveKeys 301）を超えたら作れない', async () => {
    await assertFails(
      setDoc(post('alice'), newPost('alice', { images: Array(9).fill('a') })),
    );
    await assertFails(
      setDoc(post('alice'), newPost('alice', { giveKeys: Array(301).fill('k') })),
    );
  });
  test('xAccount・note の形が不正なら作れない', async () => {
    await assertFails(setDoc(post('alice'), newPost('alice', { xAccount: '@alice' })));
    await assertFails(setDoc(post('alice'), newPost('alice', { note: '' })));
    await assertSucceeds(
      setDoc(post('alice'), newPost('alice', { xAccount: 'alice_1', note: 'よろしく' })),
    );
  });
});

describe('投稿の更新・削除', () => {
  const upd = (extra = {}) => ({
    ...storedPost(),
    updatedAt: serverTimestamp(),
    ...extra,
  });

  test('作成者は内容を更新できる。募集終了（closed）にできる', async () => {
    await seed('tradePosts/p1', storedPost());
    await assertSucceeds(setDoc(post('alice'), upd({ note: '更新' })));
    await assertSucceeds(setDoc(post('alice'), upd({ status: 'closed' })));
  });
  test('他人は更新できない', async () => {
    await seed('tradePosts/p1', storedPost());
    await assertFails(updateDoc(post('bob'), { note: '乗っ取り' }));
  });
  test('hidden にはできない。hidden の投稿は作成者も更新できない', async () => {
    await seed('tradePosts/p1', storedPost());
    await assertFails(setDoc(post('alice'), upd({ status: 'hidden' })));
    await seed('tradePosts/p2', storedPost({ status: 'hidden' }));
    await assertFails(setDoc(post('alice', 'p2'), upd({ status: 'open' })));
  });
  test('uid・createdAt は変えられない', async () => {
    await seed('tradePosts/p1', storedPost());
    await assertFails(setDoc(post('alice'), upd({ uid: 'bob' })));
    await assertFails(setDoc(post('alice'), upd({ createdAt: new Date('2026-02-01') })));
  });
  test('updatedAt がクライアントの値なら更新できない', async () => {
    await seed('tradePosts/p1', storedPost());
    await assertFails(setDoc(post('alice'), upd({ updatedAt: old })));
  });
  test('削除はできない（作成者でも）', async () => {
    await seed('tradePosts/p1', storedPost());
    await assertFails(deleteDoc(post('alice')));
  });
});

describe('返信', () => {
  const reply = (uid = 'bob', extra = {}) => ({
    uid,
    displayName: 'ボブ',
    text: 'お願いします',
    approved: false,
    createdAt: serverTimestamp(),
    ...extra,
  });
  const r = (as = 'bob', id = 'r1', postId = 'p1') =>
    doc(db(as), 'tradePosts', postId, 'replies', id);
  const storedReply = (extra = {}) => ({
    uid: 'bob',
    displayName: 'ボブ',
    text: 'お願いします',
    approved: false,
    createdAt: old,
    ...extra,
  });

  test('ログイン済みは読める。未ログインは読めない', async () => {
    await seed('tradePosts/p1', storedPost());
    await seed('tradePosts/p1/replies/r1', storedReply());
    await assertSucceeds(getDoc(r('carol')));
    await assertFails(getDoc(doc(anon(), 'tradePosts', 'p1', 'replies', 'r1')));
  });
  test('募集中の投稿に、本人の返信を作れる', async () => {
    await seed('tradePosts/p1', storedPost());
    await assertSucceeds(setDoc(r('bob'), reply()));
  });
  test('募集終了・存在しない投稿には作れない', async () => {
    await seed('tradePosts/p1', storedPost({ status: 'closed' }));
    await assertFails(setDoc(r('bob'), reply()));
    await assertFails(setDoc(r('bob', 'r1', 'none'), reply()));
  });
  test('uid が他人・approved が true・本文が空白だけ・1001文字なら作れない', async () => {
    await seed('tradePosts/p1', storedPost());
    await assertFails(setDoc(r('bob'), reply('carol')));
    await assertFails(setDoc(r('bob'), reply('bob', { approved: true })));
    await assertFails(setDoc(r('bob'), reply('bob', { text: '　 ' })));
    await assertFails(setDoc(r('bob'), reply('bob', { text: 'あ'.repeat(1001) })));
  });
  test('linkedPostId は、自分の投稿だけ添付できる', async () => {
    await seed('tradePosts/p1', storedPost());
    await seed('tradePosts/p2', { ...storedPost(), uid: 'bob' });
    await seed('tradePosts/p3', storedPost());
    await assertSucceeds(setDoc(r('bob'), reply('bob', { linkedPostId: 'p2' })));
    await assertFails(setDoc(r('bob', 'r2'), reply('bob', { linkedPostId: 'p3' })));
    await assertFails(setDoc(r('bob', 'r3'), reply('bob', { linkedPostId: 'p1' })));
  });

  describe('承認（チャットと同じバッチ）', () => {
    const approveBatch = (as, chatExtra = {}) => {
      const d = db(as);
      const batch = writeBatch(d);
      batch.update(doc(d, 'tradePosts', 'p1', 'replies', 'r1'), { approved: true });
      batch.set(doc(d, 'chats', 'p1_bob'), {
        postId: 'p1',
        replyId: 'r1',
        memberUids: ['alice', 'bob'],
        memberNames: { alice: 'アリス', bob: 'ボブ' },
        lastMessageAt: serverTimestamp(),
        status: 'open',
        createdAt: serverTimestamp(),
        ...chatExtra,
      });
      return batch;
    };
    const setup = async () => {
      await seed('tradePosts/p1', storedPost());
      await seed('tradePosts/p1/replies/r1', storedReply());
    };

    test('投稿者が承認できる', async () => {
      await setup();
      await assertSucceeds(approveBatch('alice').commit());
    });
    test('投稿者以外（返信した本人・第三者）は承認できない', async () => {
      await setup();
      await assertFails(approveBatch('bob').commit());
      await assertFails(approveBatch('carol').commit());
    });
    test('チャットを作らない単独の承認はできない', async () => {
      await setup();
      await assertFails(
        updateDoc(doc(db('alice'), 'tradePosts', 'p1', 'replies', 'r1'), { approved: true }),
      );
    });
    test('承認以外の項目は変えられない', async () => {
      await setup();
      await assertFails(updateDoc(r('bob'), { text: '書き換え' }));
    });
  });

  test('削除は書いた本人だけで、承認前に限る', async () => {
    await seed('tradePosts/p1', storedPost());
    await seed('tradePosts/p1/replies/r1', storedReply());
    await assertFails(deleteDoc(r('carol')));
    await assertFails(deleteDoc(r('alice')));
    await assertSucceeds(deleteDoc(r('bob')));
    await seed('tradePosts/p1/replies/r2', storedReply({ approved: true }));
    await assertFails(deleteDoc(r('bob', 'r2')));
  });
});
