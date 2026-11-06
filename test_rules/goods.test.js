// goods（グッズ）と goods/{id}/history のルール（G-0。横山さんの担当）。
// 今の動きを確かめるテスト。ルールの中身は変えない。
// ※ variants の中身の書き換えは今のルールでは通るが、監査（notes/step7_ルール監査.md #3）で
//   「中」と判定した既知の問題なので、許可を正しい動きとして固めるテストは書かない。
import { after, afterEach, before, describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
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

async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

const newGoods = (uid = 'alice', extra = {}) => ({
  name: 'ランダムアクスタ',
  category: 'acrylic',
  groupIds: ['g1'],
  oshiIds: [],
  variants: [{ id: 'v1', name: 'メンバーA' }],
  createdBy: uid,
  updatedBy: uid,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...extra,
});

const old = new Date('2026-01-01T00:00:00Z');
const stored = (extra = {}) => ({
  name: 'ランダムアクスタ',
  category: 'acrylic',
  groupIds: ['g1'],
  oshiIds: [],
  variants: [{ id: 'v1', name: 'メンバーA' }],
  createdBy: 'alice',
  updatedBy: 'alice',
  createdAt: old,
  updatedAt: old,
  ...extra,
});

const g = (as = 'bob', id = 'x1') => doc(db(as), 'goods', id);

describe('読み取り', () => {
  test('ログイン済みは読める。未ログインは読めない', async () => {
    await seed('goods/x1', stored());
    await assertSucceeds(getDoc(g('bob')));
    await assertFails(getDoc(doc(anon(), 'goods', 'x1')));
  });
});

describe('作成', () => {
  test('正しい内容なら作れる', async () => {
    await assertSucceeds(setDoc(g('alice'), newGoods()));
  });
  test('任意項目（aliases・price・liveId・officialUrl）付きでも作れる', async () => {
    await assertSucceeds(
      setDoc(
        g('alice'),
        newGoods('alice', {
          aliases: ['アクスタ'],
          price: 800,
          liveId: 'l1',
          officialUrl: 'https://example.com/a',
        }),
      ),
    );
  });
  test('未ログインは作れない', async () => {
    await assertFails(setDoc(doc(anon(), 'goods', 'x1'), newGoods()));
  });
  test('createdBy が他人なら作れない', async () => {
    await assertFails(setDoc(g('alice'), newGoods('bob')));
  });
  test('作成日時がクライアントの値なら作れない', async () => {
    await assertFails(setDoc(g('alice'), newGoods('alice', { createdAt: old })));
  });
  test('名前が空・空白だけ・101文字なら作れない', async () => {
    await assertFails(setDoc(g('alice'), newGoods('alice', { name: '' })));
    await assertFails(setDoc(g('alice'), newGoods('alice', { name: '　 ' })));
    await assertFails(setDoc(g('alice'), newGoods('alice', { name: 'あ'.repeat(101) })));
    await assertSucceeds(setDoc(g('alice'), newGoods('alice', { name: 'あ'.repeat(100) })));
  });
  test('category が範囲外なら作れない', async () => {
    await assertFails(setDoc(g('alice'), newGoods('alice', { category: 'ticket' })));
  });
  test('groupIds と oshiIds が両方空なら作れない', async () => {
    await assertFails(setDoc(g('alice'), newGoods('alice', { groupIds: [], oshiIds: [] })));
  });
  test('variants が空・101個なら作れない', async () => {
    await assertFails(setDoc(g('alice'), newGoods('alice', { variants: [] })));
    const many = Array.from({ length: 101 }, (_, i) => ({ id: `v${i}`, name: 'n' }));
    await assertFails(setDoc(g('alice'), newGoods('alice', { variants: many })));
  });
  test('price が負・100万超・小数なら作れない', async () => {
    await assertFails(setDoc(g('alice'), newGoods('alice', { price: -1 })));
    await assertFails(setDoc(g('alice'), newGoods('alice', { price: 1000001 })));
    await assertFails(setDoc(g('alice'), newGoods('alice', { price: 10.5 })));
  });
  test('officialUrl が https でなければ作れない', async () => {
    await assertFails(
      setDoc(g('alice'), newGoods('alice', { officialUrl: 'http://example.com/a' })),
    );
  });
  test('未知の項目があれば作れない', async () => {
    await assertFails(setDoc(g('alice'), newGoods('alice', { extra: 1 })));
  });
});

describe('更新・削除', () => {
  const upd = (extra = {}) => ({
    ...stored(),
    updatedBy: 'bob',
    updatedAt: serverTimestamp(),
    ...extra,
  });

  test('他人でも、種類を追加する更新はできる（共通データ）', async () => {
    await seed('goods/x1', stored());
    await assertSucceeds(
      setDoc(
        g('bob'),
        upd({
          variants: [
            { id: 'v1', name: 'メンバーA' },
            { id: 'v2', name: 'メンバーB' },
          ],
        }),
      ),
    );
  });
  test('種類の数を減らす更新はできない', async () => {
    await seed(
      'goods/x1',
      stored({
        variants: [
          { id: 'v1', name: 'A' },
          { id: 'v2', name: 'B' },
        ],
      }),
    );
    await assertFails(setDoc(g('bob'), upd({ variants: [{ id: 'v1', name: 'A' }] })));
  });
  test('createdBy・createdAt は変えられない', async () => {
    await seed('goods/x1', stored());
    await assertFails(setDoc(g('bob'), upd({ createdBy: 'bob' })));
    await assertFails(setDoc(g('bob'), upd({ createdAt: new Date('2026-02-01') })));
  });
  test('updatedBy が他人・updatedAt がクライアントの値なら更新できない', async () => {
    await seed('goods/x1', stored());
    await assertFails(setDoc(g('bob'), upd({ updatedBy: 'alice' })));
    await assertFails(setDoc(g('bob'), upd({ updatedAt: old })));
  });
  test('未ログインは更新できない', async () => {
    await seed('goods/x1', stored());
    await assertFails(updateDoc(doc(anon(), 'goods', 'x1'), { name: 'x' }));
  });
  test('削除はできない（作成者でも）', async () => {
    await seed('goods/x1', stored());
    await assertFails(deleteDoc(g('alice')));
    await assertFails(deleteDoc(g('bob')));
  });
});

describe('goods/{id}/history', () => {
  const hist = (uid = 'bob', extra = {}) => ({
    field: 'name',
    before: '旧',
    after: '新',
    changedBy: uid,
    changedAt: serverTimestamp(),
    ...extra,
  });
  const goodsUpdate = (uid = 'bob') => ({
    ...stored(),
    name: '新',
    updatedBy: uid,
    updatedAt: serverTimestamp(),
  });

  test('グッズの更新と同じバッチなら作れる', async () => {
    await seed('goods/x1', stored());
    const d = db('bob');
    const batch = writeBatch(d);
    batch.set(doc(d, 'goods', 'x1'), goodsUpdate());
    batch.set(doc(d, 'goods', 'x1', 'history', 'h1'), hist());
    await assertSucceeds(batch.commit());
  });
  test('グッズを更新しない単独の作成はできない', async () => {
    await seed('goods/x1', stored());
    await assertFails(setDoc(doc(db('bob'), 'goods', 'x1', 'history', 'h1'), hist()));
  });
  test('changedBy が他人なら作れない', async () => {
    await seed('goods/x1', stored());
    const d = db('bob');
    const batch = writeBatch(d);
    batch.set(doc(d, 'goods', 'x1'), goodsUpdate());
    batch.set(doc(d, 'goods', 'x1', 'history', 'h1'), hist('alice'));
    await assertFails(batch.commit());
  });
  test('読める。更新・削除はできない', async () => {
    await seed('goods/x1', stored());
    await seed('goods/x1/history/h1', {
      field: 'name',
      changedBy: 'bob',
      changedAt: old,
    });
    const h = doc(db('bob'), 'goods', 'x1', 'history', 'h1');
    await assertSucceeds(getDoc(h));
    await assertFails(updateDoc(h, { field: 'price' }));
    await assertFails(deleteDoc(h));
  });
});
