// users/{uid}/applications/{receptionId} のルール（計画書 3.4・3.6、Step2）。
// 本人のみ。status は applied / won / lost / paid、許可した項目だけ、updatedAt はサーバー時刻。
// 広い users/{uid}/{subcollection}/** のルールから applications が外れていることも確かめる
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
const appDoc = (uid, receptionId = 'r1', as = uid) =>
  doc(db(as), 'users', uid, 'applications', receptionId);

/** アプリの setStatus と同じ形 */
const valid = (status = 'applied', extra = {}) => ({
  liveId: 'l1',
  status,
  updatedAt: serverTimestamp(),
  ...extra,
});

async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

describe('本人の操作', () => {
  test('4つの状態それぞれで作成できる', async () => {
    for (const [i, status] of ['applied', 'won', 'lost', 'paid'].entries()) {
      await assertSucceeds(setDoc(appDoc('alice', `r${i}`), valid(status)));
    }
  });

  test('どの状態からどの状態へも変えられる（set で上書き・update）', async () => {
    const ref = appDoc('alice');
    await assertSucceeds(setDoc(ref, valid('paid')));
    await assertSucceeds(setDoc(ref, valid('applied')));
    await assertSucceeds(updateDoc(ref, { status: 'lost', updatedAt: serverTimestamp() }));
    await assertSucceeds(setDoc(ref, valid('won')));
  });

  test('読める・一覧できる・削除（未申込に戻す）できる', async () => {
    await assertSucceeds(setDoc(appDoc('alice'), valid()));
    await assertSucceeds(getDoc(appDoc('alice')));
    await assertSucceeds(getDocs(collection(db('alice'), 'users', 'alice', 'applications')));
    await assertSucceeds(deleteDoc(appDoc('alice')));
  });

  test('無いドキュメントの削除も拒否されない', async () => {
    await assertSucceeds(deleteDoc(appDoc('alice', 'none')));
  });
});

describe('他人の操作', () => {
  test('他人の申込状況は読めない・一覧できない', async () => {
    await seed('users/alice/applications/r1', { liveId: 'l1', status: 'won', updatedAt: Timestamp.now() });
    await assertFails(getDoc(appDoc('alice', 'r1', 'bob')));
    await assertFails(getDocs(collection(db('bob'), 'users', 'alice', 'applications')));
  });

  test('他人の申込状況を作成・更新・削除できない', async () => {
    await seed('users/alice/applications/r1', { liveId: 'l1', status: 'won', updatedAt: Timestamp.now() });
    await assertFails(setDoc(appDoc('alice', 'r2', 'bob'), valid()));
    await assertFails(setDoc(appDoc('alice', 'r1', 'bob'), valid('lost')));
    await assertFails(updateDoc(appDoc('alice', 'r1', 'bob'), { status: 'lost', updatedAt: serverTimestamp() }));
    await assertFails(deleteDoc(appDoc('alice', 'r1', 'bob')));
  });

  test('未ログインは読み書きできない', async () => {
    const anon = testEnv.unauthenticatedContext().firestore();
    const ref = doc(anon, 'users', 'alice', 'applications', 'r1');
    await assertFails(getDoc(ref));
    await assertFails(setDoc(ref, valid()));
  });
});

describe('値の検査（広いルールが素通りさせていないこと）', () => {
  const bad = {
    'status が一覧に無い': valid('pending'),
    'status が空': valid(''),
    'status が大文字': valid('WON'),
    'status が無い': { liveId: 'l1', updatedAt: serverTimestamp() },
    'liveId が無い': { status: 'won', updatedAt: serverTimestamp() },
    'liveId が数値': valid('won', { liveId: 1 }),
    'liveId が空': valid('won', { liveId: '' }),
    'liveId が129文字': valid('won', { liveId: 'a'.repeat(129) }),
    'updatedAt が無い': { liveId: 'l1', status: 'won' },
    'updatedAt の偽装': valid('won', { updatedAt: Timestamp.fromDate(new Date(Date.UTC(2020, 0, 1))) }),
    '許可していない項目': valid('won', { seat: 'S席' }),
    '空のドキュメント': {},
  };
  for (const [name, data] of Object.entries(bad)) {
    test(`本人でも拒否: ${name}`, async () => {
      await assertFails(setDoc(appDoc('alice'), data));
    });
  }

  test('liveId は128文字まで', async () => {
    await assertSucceeds(setDoc(appDoc('alice'), valid('won', { liveId: 'a'.repeat(128) })));
  });

  test('update でも検査される（不明な status・余分な項目・updatedAt の据え置き）', async () => {
    await assertSucceeds(setDoc(appDoc('alice'), valid('applied')));
    await assertFails(updateDoc(appDoc('alice'), { status: 'pending', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(appDoc('alice'), { memo: 'x', updatedAt: serverTimestamp() }));
    // updatedAt を新しくしない更新は拒否
    await assertFails(updateDoc(appDoc('alice'), { status: 'won' }));
  });

  test('applications の下のさらに深いパスにも書けない', async () => {
    await assertFails(
      setDoc(doc(db('alice'), 'users/alice/applications/r1/sub/x'), { anything: true }),
    );
  });
});

describe('広い subcollection のルール（従来どおり）', () => {
  test('applications 以外のサブコレクション（動作確認用の test など）は本人なら自由に書ける', async () => {
    await assertSucceeds(setDoc(doc(db('alice'), 'users/alice/test/t1'), { anything: 1 }));
    await assertSucceeds(setDoc(doc(db('alice'), 'users/alice/test/t1/deep/x'), { anything: 2 }));
    await assertFails(setDoc(doc(db('bob'), 'users/alice/test/t1'), { anything: 1 }));
  });

  test('名前が似ているだけのサブコレクションは広いルールのまま', async () => {
    await assertSucceeds(
      setDoc(doc(db('alice'), 'users/alice/applications_backup/x'), { status: 'anything' }),
    );
  });
});
