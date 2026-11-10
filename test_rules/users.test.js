// users/{uid} 以下のルール: 本人だけが読み書きできる。
import { after, afterEach, before, describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc } from 'firebase/firestore';
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

async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

describe('users/{uid}', () => {
  test('本人は自分のドキュメントを作成・読み取り・削除できる', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(setDoc(doc(db, 'users/alice'), { displayName: 'アリス' }));
    await assertSucceeds(getDoc(doc(db, 'users/alice')));
    await assertSucceeds(deleteDoc(doc(db, 'users/alice')));
  });

  test('本人は自分のサブコレクションを読み書きできる', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(setDoc(doc(db, 'users/alice/test/a'), { v: 1 }));
    await assertSucceeds(getDoc(doc(db, 'users/alice/test/a')));
  });

  test('自分の下でも、サブコレクションより深い所には書けない', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(setDoc(doc(db, 'users/alice/x/bob/fcmTokens/t'), { v: 1 }));
    await assertFails(setDoc(doc(db, 'users/alice/test/a/b/c'), { v: 1 }));
  });

  test('他人のドキュメントは読めない', async () => {
    await seed('users/bob', { displayName: 'ボブ' });
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(getDoc(doc(db, 'users/bob')));
  });

  test('他人のドキュメントには書けない', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(setDoc(doc(db, 'users/bob'), { displayName: '乗っ取り' }));
  });

  test('他人のサブコレクションは読み書きできない', async () => {
    await seed('users/bob/test/a', { v: 1 });
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(getDoc(doc(db, 'users/bob/test/a')));
    await assertFails(setDoc(doc(db, 'users/bob/test/b'), { v: 2 }));
  });

  test('未ログインでは読み書きできない', async () => {
    await seed('users/alice', { displayName: 'アリス' });
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'users/alice')));
    await assertFails(setDoc(doc(db, 'users/alice'), { displayName: 'x' }));
  });
});

describe('定義していないパス', () => {
  test('ログイン済みでも読み書きできない', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(getDoc(doc(db, 'other/x')));
    await assertFails(setDoc(doc(db, 'other/x'), { v: 1 }));
  });
});
