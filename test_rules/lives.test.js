// lives / performances / receptions のルール（計画書 3.1・3.6、Step2）。
// ログイン済みなら読める。作成は1つのバッチ（ライブ1件＋公演1〜50件＋受付0〜30件）だけ。
// 更新・削除は Step2 では不可。
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

// 料金の上限（受付ごと）。ユーザーの判断待ち（10 か 20）。決まったらここを合わせる
const MAX_PRICES = 10;

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

const ts = (day, hour = 18) => Timestamp.fromDate(new Date(Date.UTC(2026, 11, day, hour)));

/** アプリの create と同じ形のライブ */
function liveData(uid, extra = {}) {
  return {
    title: 'ツアー2026',
    groupIds: ['g1'],
    oshiIds: ['p1'],
    createdBy: uid,
    createdAt: serverTimestamp(),
    updatedBy: uid,
    updatedAt: serverTimestamp(),
    ...extra,
  };
}

/** 公演。i で中身を変える（同じ中身を並べると、式の数が少なく数えられるため） */
function perfData(uid, liveId, i = 0, extra = {}) {
  return {
    liveId,
    groupIds: ['g1'],
    oshiIds: ['p1'],
    startAt: ts(1 + (i % 28), i % 24),
    venue: `会場${i}`,
    createdBy: uid,
    createdAt: serverTimestamp(),
    updatedBy: uid,
    updatedAt: serverTimestamp(),
    ...extra,
  };
}

/** 受付。i で中身を変える */
function recData(uid, liveId, i = 0, extra = {}) {
  return {
    liveId,
    groupIds: ['g1'],
    oshiIds: ['p1'],
    type: 'fc',
    name: `FC${i}次先行`,
    applyEndAt: ts(1 + (i % 28), i % 24),
    prices: [{ seat: `S席${i}`, amount: 9800 + i }],
    winnersOnly: false,
    createdBy: uid,
    createdAt: serverTimestamp(),
    updatedBy: uid,
    updatedAt: serverTimestamp(),
    ...extra,
  };
}

/**
 * ライブ1件＋公演 perfs 件＋受付 recs 件を1つのバッチで作る。
 * live / perf / rec で各ドキュメントの中身を差し替えられる。
 */
function batchOf(
  firestore,
  {
    uid = 'alice',
    perfs = 1,
    recs = 0,
    live = (d) => d,
    perf = (d) => d,
    rec = (d) => d,
    includeLive = true,
  } = {},
) {
  const b = writeBatch(firestore);
  const liveRef = doc(collection(firestore, 'lives'));
  if (includeLive) b.set(liveRef, live(liveData(uid)));
  for (let i = 0; i < perfs; i++) {
    b.set(doc(collection(firestore, 'performances')), perf(perfData(uid, liveRef.id, i), i));
  }
  for (let i = 0; i < recs; i++) {
    b.set(doc(collection(firestore, 'receptions')), rec(recData(uid, liveRef.id, i), i));
  }
  return { batch: b, liveId: liveRef.id };
}

const commit = (opts) => batchOf(db(opts?.uid ?? 'alice'), opts).batch.commit();

async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

/** 既存のライブ・公演・受付を、ルールを通さずに置く */
async function seedExisting() {
  const created = Timestamp.fromDate(new Date(Date.UTC(2026, 0, 1)));
  const audit = { createdBy: 'bob', createdAt: created, updatedBy: 'bob', updatedAt: created };
  await seed('lives/old', { title: '既存', groupIds: ['g1'], oshiIds: [], ...audit });
  await seed('performances/oldP', {
    liveId: 'old', groupIds: ['g1'], oshiIds: [], startAt: ts(1), venue: '会場', ...audit,
  });
  await seed('receptions/oldR', {
    liveId: 'old', groupIds: ['g1'], oshiIds: [], type: 'fc', name: 'FC',
    applyEndAt: ts(1), prices: [], winnersOnly: false, ...audit,
  });
}

describe('読み取り', () => {
  test('ログイン済みなら、他人が作ったライブ・公演・受付も読める', async () => {
    await seedExisting();
    await assertSucceeds(getDoc(doc(db('carol'), 'lives/old')));
    await assertSucceeds(getDoc(doc(db('carol'), 'performances/oldP')));
    await assertSucceeds(getDoc(doc(db('carol'), 'receptions/oldR')));
    await assertSucceeds(getDocs(collection(db('carol'), 'lives')));
  });

  test('未ログインは読めない', async () => {
    await seedExisting();
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anon, 'lives/old')));
    await assertFails(getDoc(doc(anon, 'performances/oldP')));
    await assertFails(getDoc(doc(anon, 'receptions/oldR')));
  });
});

describe('作成: 正しいバッチ', () => {
  test('ライブ1＋公演1＋受付0（最小）', async () => {
    await assertSucceeds(commit());
  });

  test('ライブ1＋公演2＋受付3、任意項目をすべて入れる', async () => {
    await assertSucceeds(
      commit({
        perfs: 2,
        recs: 3,
        live: (d) => ({ ...d, officialUrl: 'https://example.com/tour' }),
        perf: (d) => ({ ...d, openAt: ts(2, 17), prefecture: '東京都' }),
        rec: (d, i) => ({
          ...d,
          type: ['fc', 'general', 'upgrade'][i],
          applyStartAt: ts(1, 10),
          resultAt: ts(5),
          paymentDeadline: ts(8),
          winnersOnly: i === 2,
        }),
      }),
    );
  });

  test('グループだけ・個人だけの出演でも作れる', async () => {
    const onlyGroup = (d) => ({ ...d, oshiIds: [] });
    await assertSucceeds(commit({ live: onlyGroup, perf: onlyGroup, recs: 1, rec: onlyGroup }));
    const onlyOshi = (d) => ({ ...d, groupIds: [] });
    await assertSucceeds(commit({ live: onlyOshi, perf: onlyOshi, recs: 1, rec: onlyOshi }));
  });

  test('料金が空の配列・料金のキーが無い受付も作れる', async () => {
    await assertSucceeds(commit({ recs: 1, rec: (d) => ({ ...d, prices: [] }) }));
    await assertSucceeds(
      commit({
        recs: 1,
        rec: (d) => {
          const { prices, ...rest } = d;
          return rest;
        },
      }),
    );
  });

  test('上限の件数: ライブ1＋公演50＋受付30（中身はすべて違う）を1回で作れる（getAfter の上限）', async () => {
    await assertSucceeds(commit({ perfs: 50, recs: 30 }));
  });

  test('上限の件数で、出演者と料金も上限まで入れても作れる（式の上限）', async () => {
    const g = Array.from({ length: 20 }, (_, i) => `group-${i}`);
    const o = Array.from({ length: 20 }, (_, i) => `oshi-${i}`);
    const performers = (d) => ({ ...d, groupIds: g, oshiIds: o });
    await assertSucceeds(
      commit({
        perfs: 50,
        recs: 30,
        live: (d) => ({ ...performers(d), officialUrl: 'https://example.com/' + 'a'.repeat(180) }),
        perf: (d, i) => ({ ...performers(d), openAt: ts(1, i % 24), prefecture: `県${i}` }),
        rec: (d, i) => ({
          ...performers(d),
          applyStartAt: ts(1, 1),
          resultAt: ts(2, i % 24),
          paymentDeadline: ts(3, i % 24),
          prices: Array.from({ length: MAX_PRICES }, (_, j) => ({
            seat: `席${i}-${j}-` + 'あ'.repeat(40),
            amount: i * 1000 + j,
          })),
        }),
      }),
    );
  });
});

describe('作成: 公演・受付とライブの整合（getAfter）', () => {
  test('同じバッチにライブが無い公演・受付は作れない', async () => {
    await assertFails(commit({ includeLive: false }));
    await assertFails(commit({ includeLive: false, perfs: 0, recs: 1 }));
  });

  test('既存のライブ（別のバッチで作られたもの）に公演・受付を足せない', async () => {
    await seedExisting();
    await assertFails(
      setDoc(doc(db(), 'performances/newP'), perfData('alice', 'old', 0, { oshiIds: [] })),
    );
    await assertFails(
      setDoc(doc(db(), 'receptions/newR'), recData('alice', 'old', 0, { oshiIds: [] })),
    );
  });

  test('上限の件数で、最後の受付だけ groupIds がライブと違うとバッチ全体が拒否される', async () => {
    await assertFails(
      commit({ perfs: 50, recs: 30, rec: (d, i) => (i === 29 ? { ...d, groupIds: ['g2'] } : d) }),
    );
  });

  test('公演の groupIds・oshiIds がライブと違えば拒否（順序違い・欠け・追加）', async () => {
    for (const change of [
      (d) => ({ ...d, groupIds: [] }),
      (d) => ({ ...d, oshiIds: ['p1', 'p2'] }),
      (d) => ({ ...d, groupIds: ['g9'] }),
    ]) {
      await assertFails(commit({ perf: change }));
    }
    // 順序違い
    const two = (d) => ({ ...d, groupIds: ['g1', 'g2'] });
    await assertFails(
      commit({ live: two, perf: (d) => ({ ...d, groupIds: ['g2', 'g1'] }) }),
    );
  });

  test('受付の oshiIds がライブと違えば拒否', async () => {
    await assertFails(commit({ recs: 1, rec: (d) => ({ ...d, oshiIds: [] }) }));
  });

  test('公演の liveId が存在しないライブを指すと拒否', async () => {
    const firestore = db();
    const { batch } = batchOf(firestore, {
      perf: (d) => ({ ...d, liveId: 'does-not-exist' }),
    });
    await assertFails(batch.commit());
  });
});

describe('作成: ライブの検査', () => {
  const badLives = {
    '他人の uid（createdBy）': (d) => ({ ...d, createdBy: 'bob' }),
    '他人の uid（updatedBy）': (d) => ({ ...d, updatedBy: 'bob' }),
    'createdAt の偽装': (d) => ({ ...d, createdAt: ts(1) }),
    'updatedAt の偽装': (d) => ({ ...d, updatedAt: ts(1) }),
    '許可していない項目': (d) => ({ ...d, status: 'approved' }),
    'title が無い': ({ title, ...d }) => d,
    'title が空': (d) => ({ ...d, title: '' }),
    'title が空白だけ（半角）': (d) => ({ ...d, title: '   ' }),
    'title が空白だけ（全角）': (d) => ({ ...d, title: '　　' }),
    'title が101文字': (d) => ({ ...d, title: 'あ'.repeat(101) }),
    'title が数値': (d) => ({ ...d, title: 1 }),
    'groupIds と oshiIds がどちらも空': (d) => ({ ...d, groupIds: [], oshiIds: [] }),
    'groupIds が無い': ({ groupIds, ...d }) => d,
    'oshiIds が無い': ({ oshiIds, ...d }) => d,
    'groupIds が21件': (d) => ({ ...d, groupIds: Array.from({ length: 21 }, (_, i) => `g${i}`) }),
    'oshiIds が21件': (d) => ({ ...d, oshiIds: Array.from({ length: 21 }, (_, i) => `p${i}`) }),
    'groupIds が文字列': (d) => ({ ...d, groupIds: 'g1' }),
    'officialUrl が http://': (d) => ({ ...d, officialUrl: 'http://example.com' }),
    'officialUrl が https:// だけ': (d) => ({ ...d, officialUrl: 'https://' }),
    'officialUrl に空白': (d) => ({ ...d, officialUrl: 'https://exa mple.com' }),
    'officialUrl が201文字': (d) => ({ ...d, officialUrl: 'https://e.com/' + 'a'.repeat(187) }),
  };
  for (const [name, change] of Object.entries(badLives)) {
    test(`拒否: ${name}`, async () => {
      await assertFails(commit({ live: change, perf: (d) => d }));
    });
  }

  test('title は100文字まで、officialUrl は200文字まで', async () => {
    await assertSucceeds(
      commit({
        live: (d) => ({
          ...d,
          title: 'あ'.repeat(100),
          officialUrl: 'https://e.com/' + 'a'.repeat(186),
        }),
      }),
    );
  });

  test('グループ・個人の ID は各20件まで', async () => {
    const twenty = (p) => Array.from({ length: 20 }, (_, i) => `${p}${i}`);
    const change = (d) => ({ ...d, groupIds: twenty('g'), oshiIds: twenty('p') });
    await assertSucceeds(commit({ live: change, perf: change }));
  });

  test('未ログインは作れない', async () => {
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(batchOf(anon, { uid: 'alice' }).batch.commit());
  });
});

describe('作成: 公演の検査', () => {
  const badPerfs = {
    '他人の uid': (d) => ({ ...d, createdBy: 'bob', updatedBy: 'bob' }),
    'createdAt の偽装': (d) => ({ ...d, createdAt: ts(1) }),
    '許可していない項目': (d) => ({ ...d, memo: 'x' }),
    'startAt が無い': ({ startAt, ...d }) => d,
    'startAt が文字列': (d) => ({ ...d, startAt: '2026-12-01T18:00' }),
    'openAt が文字列': (d) => ({ ...d, openAt: '17:00' }),
    'venue が無い': ({ venue, ...d }) => d,
    'venue が空白だけ': (d) => ({ ...d, venue: '　' }),
    'venue が101文字': (d) => ({ ...d, venue: 'あ'.repeat(101) }),
    'prefecture が11文字': (d) => ({ ...d, prefecture: 'あ'.repeat(11) }),
    'prefecture が空文字': (d) => ({ ...d, prefecture: '' }),
    'liveId が無い': ({ liveId, ...d }) => d,
  };
  for (const [name, change] of Object.entries(badPerfs)) {
    test(`拒否: ${name}`, async () => {
      await assertFails(commit({ perf: change }));
    });
  }

  test('venue は100文字まで、prefecture は10文字まで', async () => {
    await assertSucceeds(
      commit({ perf: (d) => ({ ...d, venue: 'あ'.repeat(100), prefecture: 'あ'.repeat(10) }) }),
    );
  });
});

describe('作成: 受付の検査', () => {
  const badRecs = {
    '他人の uid': (d) => ({ ...d, createdBy: 'bob', updatedBy: 'bob' }),
    'updatedAt の偽装': (d) => ({ ...d, updatedAt: ts(1) }),
    '許可していない項目': (d) => ({ ...d, status: 'won' }),
    'type が一覧に無い': (d) => ({ ...d, type: 'lottery' }),
    'type が無い': ({ type, ...d }) => d,
    'name が空白だけ': (d) => ({ ...d, name: '  ' }),
    'name が51文字': (d) => ({ ...d, name: 'あ'.repeat(51) }),
    'applyEndAt が無い': ({ applyEndAt, ...d }) => d,
    'applyEndAt が文字列': (d) => ({ ...d, applyEndAt: '2026-11-20' }),
    'resultAt が数値': (d) => ({ ...d, resultAt: 1 }),
    'paymentDeadline が文字列': (d) => ({ ...d, paymentDeadline: '未定' }),
    'winnersOnly が無い': ({ winnersOnly, ...d }) => d,
    'winnersOnly が文字列': (d) => ({ ...d, winnersOnly: 'true' }),
    [`料金が${MAX_PRICES + 1}個`]: (d) => ({
      ...d,
      prices: Array.from({ length: MAX_PRICES + 1 }, (_, j) => ({ seat: `席${j}`, amount: j })),
    }),
    '料金が配列でない': (d) => ({ ...d, prices: { seat: 'S', amount: 1 } }),
    '料金の要素が map でない': (d) => ({ ...d, prices: ['S席 9800円'] }),
    '料金の seat が無い': (d) => ({ ...d, prices: [{ amount: 1 }] }),
    '料金の amount が無い': (d) => ({ ...d, prices: [{ seat: 'S' }] }),
    '料金の seat が空白だけ': (d) => ({ ...d, prices: [{ seat: ' ', amount: 1 }] }),
    '料金の seat が51文字': (d) => ({ ...d, prices: [{ seat: 'あ'.repeat(51), amount: 1 }] }),
    '料金の amount が負': (d) => ({ ...d, prices: [{ seat: 'S', amount: -1 }] }),
    '料金の amount が1,000,001': (d) => ({ ...d, prices: [{ seat: 'S', amount: 1000001 }] }),
    '料金の amount が小数': (d) => ({ ...d, prices: [{ seat: 'S', amount: 9800.5 }] }),
    '料金の amount が文字列': (d) => ({ ...d, prices: [{ seat: 'S', amount: '9800' }] }),
    '料金の要素に余分なキー': (d) => ({ ...d, prices: [{ seat: 'S', amount: 1, note: 'x' }] }),
    // 最後の要素だけ壊れていても見逃さない
    [`${MAX_PRICES}個目の料金だけ壊れている`]: (d) => ({
      ...d,
      prices: Array.from({ length: MAX_PRICES }, (_, j) => ({
        seat: `席${j}`,
        amount: j === MAX_PRICES - 1 ? -5 : j,
      })),
    }),
  };
  for (const [name, change] of Object.entries(badRecs)) {
    test(`拒否: ${name}`, async () => {
      await assertFails(commit({ recs: 1, rec: change }));
    });
  }

  test('type は fc / general / upgrade / other のどれでも可', async () => {
    for (const type of ['fc', 'general', 'upgrade', 'other']) {
      await assertSucceeds(commit({ recs: 1, rec: (d) => ({ ...d, type }) }));
    }
  });

  test(`料金は${MAX_PRICES}個まで、seat は50文字、amount は 0〜1,000,000`, async () => {
    await assertSucceeds(
      commit({
        recs: 1,
        rec: (d) => ({
          ...d,
          name: 'あ'.repeat(50),
          prices: Array.from({ length: MAX_PRICES }, (_, j) => ({
            seat: j === 0 ? 'あ'.repeat(50) : `席${j}`,
            amount: j === 0 ? 0 : j === 1 ? 1000000 : j,
          })),
        }),
      }),
    );
  });
});

describe('更新・削除（Step2 では不可）', () => {
  test('作成者本人でも、ライブ・公演・受付を更新・削除できない', async () => {
    const firestore = db('alice');
    const { batch, liveId } = batchOf(firestore, { recs: 1 });
    await assertSucceeds(batch.commit());
    const perfId = (await getDocs(collection(firestore, 'performances'))).docs[0].id;
    const recId = (await getDocs(collection(firestore, 'receptions'))).docs[0].id;

    await assertFails(updateDoc(doc(firestore, 'lives', liveId), { title: '変更' }));
    await assertFails(updateDoc(doc(firestore, 'performances', perfId), { venue: '変更' }));
    await assertFails(updateDoc(doc(firestore, 'receptions', recId), { name: '変更' }));
    await assertFails(deleteDoc(doc(firestore, 'lives', liveId)));
    await assertFails(deleteDoc(doc(firestore, 'performances', perfId)));
    await assertFails(deleteDoc(doc(firestore, 'receptions', recId)));
  });

  test('既存のドキュメントを set で上書きできない', async () => {
    await seedExisting();
    await assertFails(setDoc(doc(db(), 'lives/old'), liveData('alice')));
  });

  test('変更履歴（history）のサブコレクションにはまだ書けない', async () => {
    await seedExisting();
    await assertFails(
      setDoc(doc(db(), 'lives/old/history/h1'), {
        field: 'title',
        before: 'a',
        after: 'b',
        changedBy: 'alice',
        changedAt: serverTimestamp(),
      }),
    );
  });
});
