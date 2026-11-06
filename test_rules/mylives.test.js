// users/{uid}/myLives/{liveId} のルール（Step4.5）。
// 本人のみ。項目は addedAt（サーバー時刻）だけ。同じ ID のライブが存在すること。
// 広い users/{uid}/{subcollection}/** から myLives が外れていることも確かめる
// （ルールは OR で効くので、外れていないと検査が素通りになる）。
import { after, afterEach, before, describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
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
const myLive = (uid, liveId = 'l1', as = uid) =>
  doc(db(as), 'users', uid, 'myLives', liveId);

async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

const liveData = { title: 'ツアー', groupIds: ['g1'], oshiIds: [] };

describe('本人の操作', () => {
  test('既存のライブを追加できる。読める・一覧できる・外せる', async () => {
    await seed('lives/l1', liveData);
    await assertSucceeds(setDoc(myLive('alice'), { addedAt: serverTimestamp() }));
    await assertSucceeds(getDoc(myLive('alice')));
    await assertSucceeds(getDocs(collection(db('alice'), 'users', 'alice', 'myLives')));
    await assertSucceeds(deleteDoc(myLive('alice')));
  });

  test('ライブの新規作成と同じバッチなら追加できる（existsAfter）', async () => {
    const alice = db('alice');
    const batch = writeBatch(alice);
    batch.set(doc(alice, 'lives', 'new1'), {
      ...liveData,
      createdBy: 'alice',
      createdAt: serverTimestamp(),
      updatedBy: 'alice',
      updatedAt: serverTimestamp(),
    });
    batch.set(doc(alice, 'users', 'alice', 'myLives', 'new1'), {
      addedAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());
  });

  test('存在しないライブは追加できない', async () => {
    await assertFails(setDoc(myLive('alice', 'nope'), { addedAt: serverTimestamp() }));
  });

  test('外した後に、同じ ID で追加し直せる。申込状況は触らない', async () => {
    await seed('lives/l1', liveData);
    await seed('users/alice/applications/r1', {
      liveId: 'l1',
      status: 'won',
      updatedAt: Timestamp.now(),
    });
    await assertSucceeds(setDoc(myLive('alice'), { addedAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(myLive('alice')));
    await assertSucceeds(setDoc(myLive('alice'), { addedAt: serverTimestamp() }));
    await assertSucceeds(getDoc(doc(db('alice'), 'users', 'alice', 'applications', 'r1')));
  });
});

describe('新規作成の上限に近いバッチ（getAfter・existsAfter の上限）', () => {
  const ts = (day, hour) => Timestamp.fromDate(new Date(Date.UTC(2026, 11, day, hour)));
  const audit = (uid) => ({
    createdBy: uid,
    createdAt: serverTimestamp(),
    updatedBy: uid,
    updatedAt: serverTimestamp(),
  });

  function bigBatch(firestore, perfs, recs, withMine = true) {
    const b = writeBatch(firestore);
    const liveRef = doc(collection(firestore, 'lives'));
    b.set(liveRef, { title: 'ツアー', groupIds: ['g1'], oshiIds: ['p1'], ...audit('alice') });
    for (let i = 0; i < perfs; i++) {
      b.set(doc(collection(firestore, 'performances')), {
        liveId: liveRef.id,
        groupIds: ['g1'],
        oshiIds: ['p1'],
        startAt: ts(1 + (i % 28), i % 24),
        venue: `会場${i}`,
        ...audit('alice'),
      });
    }
    for (let i = 0; i < recs; i++) {
      b.set(doc(collection(firestore, 'receptions')), {
        liveId: liveRef.id,
        groupIds: ['g1'],
        oshiIds: ['p1'],
        type: 'fc',
        name: `FC${i}次先行`,
        applyEndAt: ts(1 + (i % 28), i % 24),
        prices: [{ seat: `S席${i}`, amount: 9800 + i }],
        winnersOnly: false,
        ...audit('alice'),
      });
    }
    if (withMine) {
      b.set(doc(firestore, 'users', 'alice', 'myLives', liveRef.id), {
        addedAt: serverTimestamp(),
      });
    }
    return { batch: b, liveId: liveRef.id };
  }

  test('ライブ1＋公演50＋受付30＋myLives を1回で作れる', async () => {
    const { batch, liveId } = bigBatch(db('alice'), 50, 30);
    await assertSucceeds(batch.commit());
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await getDoc(doc(context.firestore(), 'users', 'alice', 'myLives', liveId));
      if (!snap.exists()) throw new Error('myLives が作られていない');
    });
  });

  test('最小（ライブ1＋公演1＋myLives）も作れる', async () => {
    await assertSucceeds(bigBatch(db('alice'), 1, 0).batch.commit());
  });

  test('他人の myLives を同じバッチで作ろうとすると、バッチ全体が拒否される', async () => {
    const alice = db('alice');
    const { batch, liveId } = bigBatch(alice, 2, 1, false);
    batch.set(doc(alice, 'users', 'bob', 'myLives', liveId), { addedAt: serverTimestamp() });
    await assertFails(batch.commit());
  });
});

describe('拒否されるべき書き込み', () => {
  test('addedAt の偽装（過去の日時・クライアントの時刻）', async () => {
    await seed('lives/l1', liveData);
    await assertFails(setDoc(myLive('alice'), { addedAt: Timestamp.fromDate(new Date('2020-01-01')) }));
    await assertFails(setDoc(myLive('alice'), { addedAt: Timestamp.now() }));
  });

  test('addedAt が無い・文字列・null', async () => {
    await seed('lives/l1', liveData);
    await assertFails(setDoc(myLive('alice'), {}));
    await assertFails(setDoc(myLive('alice'), { addedAt: 'now' }));
    await assertFails(setDoc(myLive('alice'), { addedAt: null }));
  });

  test('余計な項目', async () => {
    await seed('lives/l1', liveData);
    await assertFails(setDoc(myLive('alice'), { addedAt: serverTimestamp(), extra: 1 }));
    await assertFails(setDoc(myLive('alice'), { addedAt: serverTimestamp(), liveId: 'l1' }));
  });

  test('update でも余計な項目・存在しないライブは不可', async () => {
    await seed('lives/l1', liveData);
    await assertSucceeds(setDoc(myLive('alice'), { addedAt: serverTimestamp() }));
    await assertFails(updateDoc(myLive('alice'), { extra: 1 }));
    await assertFails(updateDoc(myLive('alice'), { addedAt: Timestamp.now() }));
  });

  test('myLives の下のサブコレクションは広いルールでも書けない', async () => {
    await seed('lives/l1', liveData);
    await assertFails(
      setDoc(doc(db('alice'), 'users', 'alice', 'myLives', 'l1', 'sub', 'x'), { a: 1 }),
    );
  });

  test('ほかのサブコレクション（test など）は従来どおり書ける', async () => {
    await assertSucceeds(
      setDoc(doc(db('alice'), 'users', 'alice', 'test', 'x'), { a: 1 }),
    );
  });
});

describe('他人・未ログイン', () => {
  test('他人の myLives は読めない・書けない・消せない', async () => {
    await seed('lives/l1', liveData);
    await seed('users/alice/myLives/l1', { addedAt: Timestamp.now() });
    await assertFails(getDoc(myLive('alice', 'l1', 'bob')));
    await assertFails(getDocs(collection(db('bob'), 'users', 'alice', 'myLives')));
    await assertFails(
      setDoc(myLive('alice', 'l2', 'bob'), { addedAt: serverTimestamp() }),
    );
    await assertFails(deleteDoc(myLive('alice', 'l1', 'bob')));
  });

  test('未ログインは読めない・書けない', async () => {
    await seed('lives/l1', liveData);
    const ref = doc(anon(), 'users', 'alice', 'myLives', 'l1');
    await assertFails(getDoc(ref));
    await assertFails(setDoc(ref, { addedAt: serverTimestamp() }));
  });
});
