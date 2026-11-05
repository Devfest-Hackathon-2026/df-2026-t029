// users/{uid} 本体の項目の検査（計画書 3.6・3.7）。
// アプリの FirestoreFollowRepository と同じ書き方（新規は set、既存は update）で確かめる。
import { after, afterEach, before, describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  Timestamp,
  arrayRemove,
  arrayUnion,
  doc,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
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
const past = Timestamp.fromDate(new Date('2025-01-01'));

async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

const ids = (n, prefix = 'g') => Array.from({ length: n }, (_, i) => `${prefix}${i}`);

describe('users/{uid}: 最初のフォロー（新規作成）', () => {
  test('アプリと同じ形で作成できる', async () => {
    await assertSucceeds(
      setDoc(doc(db(), 'users/alice'), {
        displayName: 'アリス',
        createdAt: serverTimestamp(),
        followingGroupIds: arrayUnion('g1'),
        followingOshiIds: [],
      }),
    );
  });

  test('トランザクションでも作成できる', async () => {
    const d = db();
    await assertSucceeds(
      runTransaction(d, async (tx) => {
        const ref = doc(d, 'users/alice');
        await tx.get(ref);
        tx.set(ref, {
          displayName: '名無し',
          createdAt: serverTimestamp(),
          followingGroupIds: [],
          followingOshiIds: arrayUnion('p1'),
        });
      }),
    );
  });

  test('createdAt にクライアントの時刻を入れると作成できない', async () => {
    await assertFails(
      setDoc(doc(db(), 'users/alice'), { displayName: 'A', createdAt: past }),
    );
  });

  test('displayName: 空文字・101文字・文字列以外は作成できない、100文字は可', async () => {
    for (const displayName of ['', 'あ'.repeat(101), 1]) {
      await assertFails(setDoc(doc(db(), 'users/alice'), { displayName }));
    }
    await assertSucceeds(setDoc(doc(db(), 'users/alice'), { displayName: 'あ'.repeat(100) }));
  });

  test('配列: 200件は可、201件・配列以外は作成できない', async () => {
    await assertSucceeds(
      setDoc(doc(db(), 'users/alice'), { followingGroupIds: ids(200) }),
    );
    await testEnv.clearFirestore();
    await assertFails(setDoc(doc(db(), 'users/alice'), { followingGroupIds: ids(201) }));
    await assertFails(setDoc(doc(db(), 'users/alice'), { followingOshiIds: ids(201, 'p') }));
    await assertFails(setDoc(doc(db(), 'users/alice'), { followingOshiIds: 'p1' }));
  });

  test('他人の users は作成できない', async () => {
    await assertFails(
      setDoc(doc(db('alice'), 'users/bob'), {
        displayName: '乗っ取り',
        createdAt: serverTimestamp(),
        followingGroupIds: ['g1'],
      }),
    );
  });
});

describe('users/{uid}: 既存のユーザーへの追加・解除（更新）', () => {
  const existing = {
    displayName: 'アリス',
    createdAt: past,
    followingGroupIds: ['g0'],
    followingOshiIds: [],
  };

  test('arrayUnion で追加、arrayRemove で解除できる', async () => {
    await seed('users/alice', existing);
    const ref = doc(db(), 'users/alice');
    await assertSucceeds(updateDoc(ref, { followingGroupIds: arrayUnion('g1') }));
    await assertSucceeds(updateDoc(ref, { followingGroupIds: arrayRemove('g0') }));
  });

  test('199件に1件足して200件にできるが、200件に足して201件にはできない', async () => {
    await seed('users/alice', { ...existing, followingGroupIds: ids(199) });
    const ref = doc(db(), 'users/alice');
    await assertSucceeds(updateDoc(ref, { followingGroupIds: arrayUnion('g199') }));
    await assertFails(updateDoc(ref, { followingGroupIds: arrayUnion('g200') }));
  });

  test('欠けていた createdAt はサーバー時刻でだけ補える', async () => {
    await seed('users/alice', { displayName: 'アリス' });
    const ref = doc(db(), 'users/alice');
    await assertFails(updateDoc(ref, { createdAt: past }));
    await assertSucceeds(
      updateDoc(ref, {
        createdAt: serverTimestamp(),
        followingGroupIds: arrayUnion('g1'),
        followingOshiIds: [],
      }),
    );
  });

  test('一度入った createdAt は変えられない（サーバー時刻でも、消すのも不可）', async () => {
    await seed('users/alice', existing);
    const ref = doc(db(), 'users/alice');
    await assertFails(updateDoc(ref, { createdAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { createdAt: Timestamp.now() }));
    await assertFails(setDoc(ref, { displayName: 'アリス' }));
  });

  test('displayName の変更は本人なら可、型違いは不可', async () => {
    await seed('users/alice', existing);
    const ref = doc(db(), 'users/alice');
    await assertSucceeds(updateDoc(ref, { displayName: '新しい名前' }));
    await assertFails(updateDoc(ref, { displayName: 123 }));
  });

  test('他人の users は更新できない', async () => {
    await seed('users/bob', { ...existing, displayName: 'ボブ' });
    await assertFails(
      updateDoc(doc(db('alice'), 'users/bob'), { followingGroupIds: arrayUnion('g1') }),
    );
  });
});

describe('users/{uid}: ほかの機能の項目（hasOnly は入れない。ユーザー決定の案A）', () => {
  test('既知の4項目以外の項目（fcmToken など）も、本人なら作成・追加できる', async () => {
    const ref = doc(db(), 'users/alice');
    await assertSucceeds(
      setDoc(ref, {
        displayName: 'アリス',
        createdAt: serverTimestamp(),
        followingGroupIds: [],
        fcmToken: 'token-1',
      }),
    );
    await assertSucceeds(updateDoc(ref, { fcmToken: 'token-2', budget: 10000 }));
  });

  test('未知の項目を足しても、既知の項目の検査は効く', async () => {
    const ref = doc(db(), 'users/alice');
    await assertFails(setDoc(ref, { fcmToken: 't', displayName: 1 }));
    await assertFails(setDoc(ref, { fcmToken: 't', followingOshiIds: ids(201, 'p') }));
    await assertFails(setDoc(ref, { fcmToken: 't', createdAt: past }));
  });

  test('他人の users には未知の項目も書けない', async () => {
    await assertFails(setDoc(doc(db('alice'), 'users/bob'), { fcmToken: 't' }));
  });
});
