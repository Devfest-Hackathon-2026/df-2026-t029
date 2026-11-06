// lives / performances / receptions の更新と変更履歴のルール（Step4。計画書 3.8）。
// アプリの applyMerge・revert と同じ形の書き込みで、許可・拒否の両方を確かめる。
// 「一度に反映できる件数」（ルールの読み取り上限）の実測もここに置く。
import { after, afterEach, before, describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  runTransaction,
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
const ts = (day, hour = 18) => Timestamp.fromDate(new Date(Date.UTC(2026, 11, day, hour)));
const created = Timestamp.fromDate(new Date(Date.UTC(2026, 0, 1)));
const audit = { createdBy: 'bob', createdAt: created, updatedBy: 'bob', updatedAt: created };

async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

/** bob が作った既存のライブ L（g1）と、公演 nP 件・受付 nR 件をルールを通さずに置く */
async function seedLive({ nP = 1, nR = 1, groupIds = ['g1'], oshiIds = [] } = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const f = context.firestore();
    const b = writeBatch(f);
    b.set(doc(f, 'lives/L'), {
      title: 'ツアー2026',
      groupIds,
      oshiIds,
      officialUrl: 'https://e.com/t',
      ...audit,
    });
    for (let i = 0; i < nP; i++) {
      b.set(doc(f, `performances/P${i}`), {
        liveId: 'L', groupIds, oshiIds, startAt: ts(1 + (i % 28), i % 24),
        venue: `会場${i}`, prefecture: '東京都', ...audit,
      });
    }
    for (let i = 0; i < nR; i++) {
      b.set(doc(f, `receptions/R${i}`), {
        liveId: 'L', groupIds, oshiIds, type: 'fc', name: `FC${i}次先行`,
        applyStartAt: ts(1, 10), applyEndAt: ts(1 + (i % 28), i % 24),
        resultAt: ts(2), paymentDeadline: ts(3),
        prices: [{ seat: `S席${i}`, amount: 9800 + i }], winnersOnly: false, ...audit,
      });
    }
    await b.commit();
  });
}

const upd = (uid = 'alice') => ({ updatedBy: uid, updatedAt: serverTimestamp() });
const hist = (field, before, after, uid = 'alice') => ({
  field,
  ...(before === undefined ? {} : { before }),
  ...(after === undefined ? {} : { after }),
  changedBy: uid,
  changedAt: serverTimestamp(),
});

describe('ライブの更新', () => {
  test('項目の変更＋履歴（アプリの applyMerge と同じ形）は通る。他人が作ったライブでも可', async () => {
    await seedLive();
    const f = db('alice');
    const b = writeBatch(f);
    b.update(doc(f, 'lives/L'), { title: '新しい名前', ...upd() });
    b.set(doc(f, 'lives/L/history/h1'), hist('title', 'ツアー2026', '新しい名前'));
    await assertSucceeds(b.commit());
  });

  test('出演者を増やせる（子も同じバッチでそろえる）。公式 URL を消せる', async () => {
    await seedLive();
    const f = db();
    const b = writeBatch(f);
    b.update(doc(f, 'lives/L'), { groupIds: ['g1', 'g2'], officialUrl: deleteField(), ...upd() });
    b.update(doc(f, 'performances/P0'), { groupIds: ['g1', 'g2'], ...upd() });
    b.update(doc(f, 'receptions/R0'), { groupIds: ['g1', 'g2'], ...upd() });
    await assertSucceeds(b.commit());
  });

  const badUpdates = {
    '出演者（groupIds）を減らす': { groupIds: [] , oshiIds: ['o1'] },
    '出演者を入れ替える（g1 を外して g2）': { groupIds: ['g2'] },
    '他人の uid の updatedBy': { updatedBy: 'carol' },
    'updatedAt の偽装': { updatedAt: ts(5) },
    'updatedAt を書かない': { updatedAt: created },
    'createdBy の書き換え': { createdBy: 'alice' },
    'createdAt の書き換え': { createdAt: ts(5) },
    '許可していない項目': { status: 'approved' },
    'title を空白だけに': { title: '　' },
    'title が101文字': { title: 'あ'.repeat(101) },
    'officialUrl が http://': { officialUrl: 'http://e.com' },
    'groupIds が21件': { groupIds: Array.from({ length: 21 }, (_, i) => (i === 0 ? 'g1' : `g${i + 1}`)) },
  };
  for (const [name, change] of Object.entries(badUpdates)) {
    test(`拒否: ${name}`, async () => {
      await seedLive({ nP: 0, nR: 0 });
      await assertFails(updateDoc(doc(db(), 'lives/L'), { ...upd(), ...change }));
    });
  }

  test('title を消すことはできない（必須項目）', async () => {
    await seedLive({ nP: 0, nR: 0 });
    await assertFails(updateDoc(doc(db(), 'lives/L'), { title: deleteField(), ...upd() }));
  });

  test('未ログインは更新できない。削除は誰もできない', async () => {
    await seedLive({ nP: 0, nR: 0 });
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(updateDoc(doc(anon, 'lives/L'), { title: 'x', updatedBy: 'x', updatedAt: serverTimestamp() }));
    await assertFails(deleteDoc(doc(db('bob'), 'lives/L')));
  });
});

describe('公演・受付の更新', () => {
  test('項目の変更＋履歴は通る（ライブを書かなくてもよい。元に戻す操作と同じ形）', async () => {
    await seedLive();
    const f = db();
    const b = writeBatch(f);
    b.update(doc(f, 'performances/P0'), { venue: '新会場', prefecture: deleteField(), ...upd() });
    b.set(doc(f, 'performances/P0/history/h1'), hist('venue', '会場0', '新会場'));
    b.set(doc(f, 'performances/P0/history/h2'), hist('prefecture', '東京都', undefined));
    b.update(doc(f, 'receptions/R0'), { paymentDeadline: ts(9), ...upd() });
    b.set(doc(f, 'receptions/R0/history/h1'), hist('paymentDeadline', ts(3), ts(9)));
    await assertSucceeds(b.commit());
  });

  test('トランザクションでも通る（アプリの applyMerge）', async () => {
    await seedLive();
    const f = db();
    await assertSucceeds(
      runTransaction(f, async (tx) => {
        await tx.get(doc(f, 'lives/L'));
        await tx.get(doc(f, 'receptions/R0'));
        tx.update(doc(f, 'lives/L'), upd());
        tx.update(doc(f, 'receptions/R0'), { name: 'FC最速', ...upd() });
        tx.set(doc(f, 'receptions/R0/history/h'), hist('name', 'FC0次先行', 'FC最速'));
      }),
    );
  });

  const badPerf = {
    'liveId の付け替え': { liveId: 'other' },
    'groupIds がライブと違う': { groupIds: ['g1', 'g2'] },
    '他人の uid の updatedBy': { updatedBy: 'carol' },
    'createdBy の書き換え': { createdBy: 'alice' },
    'updatedAt を書かない': { updatedAt: created },
    'startAt が文字列': { startAt: '2026-12-01' },
    'venue を空に': { venue: '' },
    '許可していない項目': { memo: 'x' },
  };
  for (const [name, change] of Object.entries(badPerf)) {
    test(`公演の拒否: ${name}`, async () => {
      await seedLive();
      await seed('lives/other', { title: 'x', groupIds: ['g1'], oshiIds: [], ...audit });
      await assertFails(updateDoc(doc(db(), 'performances/P0'), { ...upd(), ...change }));
    });
  }

  const badRec = {
    'liveId の付け替え': { liveId: 'other' },
    'oshiIds がライブと違う': { oshiIds: ['o1'] },
    'type が一覧に無い': { type: 'lottery' },
    'applyEndAt を消す': { applyEndAt: deleteField() },
    'winnersOnly を消す': { winnersOnly: deleteField() },
    '料金の amount が負': { prices: [{ seat: 'S', amount: -1 }] },
    '他人の uid の updatedBy': { updatedBy: 'carol' },
  };
  for (const [name, change] of Object.entries(badRec)) {
    test(`受付の拒否: ${name}`, async () => {
      await seedLive();
      await seed('lives/other', { title: 'x', groupIds: ['g1'], oshiIds: [], ...audit });
      await assertFails(updateDoc(doc(db(), 'receptions/R0'), { ...upd(), ...change }));
    });
  }

  test('ライブの出演者を増やしたのに、子をそろえなければ子の更新は拒否', async () => {
    await seedLive();
    const f = db();
    const b = writeBatch(f);
    b.update(doc(f, 'lives/L'), { groupIds: ['g1', 'g2'], ...upd() });
    b.update(doc(f, 'performances/P0'), { venue: 'x', ...upd() }); // groupIds が古い
    await assertFails(b.commit());
  });

  test('削除はできない', async () => {
    await seedLive();
    await assertFails(deleteDoc(doc(db('bob'), 'performances/P0')));
    await assertFails(deleteDoc(doc(db('bob'), 'receptions/R0')));
  });
});

describe('既存のライブへの公演・受付の追加', () => {
  const newPerf = (uid = 'alice', extra = {}) => ({
    liveId: 'L', groupIds: ['g1'], oshiIds: [], startAt: ts(27), venue: '大阪城ホール',
    createdBy: uid, createdAt: serverTimestamp(), ...upd(uid), ...extra,
  });
  const newRec = (uid = 'alice') => ({
    liveId: 'L', groupIds: ['g1'], oshiIds: [], type: 'general', name: '一般',
    applyEndAt: ts(5), winnersOnly: false,
    createdBy: uid, createdAt: serverTimestamp(), ...upd(uid),
  });

  test('同じバッチでライブの updatedAt・updatedBy を書けば追加できる', async () => {
    await seedLive();
    const f = db();
    const b = writeBatch(f);
    b.update(doc(f, 'lives/L'), upd());
    b.set(doc(f, 'performances/new'), newPerf());
    b.set(doc(f, 'receptions/new'), newRec());
    await assertSucceeds(b.commit());
  });

  test('ライブの updatedAt を書かない追加は拒否', async () => {
    await seedLive();
    await assertFails(setDoc(doc(db(), 'performances/new'), newPerf()));
    await assertFails(setDoc(doc(db(), 'receptions/new'), newRec()));
  });

  test('ライブを別の人の uid で更新した追加は拒否（updatedBy が本人でない）', async () => {
    await seedLive();
    const f = db();
    const b = writeBatch(f);
    b.update(doc(f, 'lives/L'), { updatedBy: 'carol', updatedAt: serverTimestamp() });
    b.set(doc(f, 'performances/new'), newPerf());
    await assertFails(b.commit());
  });

  test('追加する公演の出演者がライブと違えば拒否', async () => {
    await seedLive();
    const f = db();
    const b = writeBatch(f);
    b.update(doc(f, 'lives/L'), upd());
    b.set(doc(f, 'performances/new'), newPerf('alice', { groupIds: ['g2'] }));
    await assertFails(b.commit());
  });
});

describe('変更履歴（history）', () => {
  test('ログイン済みなら読める。未ログインは読めない', async () => {
    await seedLive();
    await seed('receptions/R0/history/h', { field: 'name', before: 'a', after: 'b', changedBy: 'bob', changedAt: created });
    await assertSucceeds(getDocs(collection(db('carol'), 'receptions/R0/history')));
    await assertSucceeds(getDoc(doc(db('carol'), 'receptions/R0/history/h')));
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anon, 'receptions/R0/history/h')));
  });

  test('親を同じバッチで更新しない履歴だけの作成は拒否（3つとも）', async () => {
    await seedLive();
    for (const path of ['lives/L', 'performances/P0', 'receptions/R0']) {
      await assertFails(setDoc(doc(db(), `${path}/history/h`), hist('x', 'a', 'b')));
    }
  });

  test('親を別のユーザーが更新した扱い（updatedBy が他人）の履歴は拒否', async () => {
    await seedLive();
    // 親の updatedBy は自分以外にできないので、他人の履歴は changedBy で拒否される
    const f = db();
    const b = writeBatch(f);
    b.update(doc(f, 'lives/L'), { title: 'x', ...upd() });
    b.set(doc(f, 'lives/L/history/h'), hist('title', 'ツアー2026', 'x', 'carol'));
    await assertFails(b.commit());
  });

  test('changedAt の偽装・許可していない項目・field が無い／51文字は拒否', async () => {
    await seedLive();
    const cases = [
      { ...hist('title', 'a', 'b'), changedAt: ts(1) },
      { ...hist('title', 'a', 'b'), note: 'x' },
      (({ field, ...rest }) => rest)(hist('title', 'a', 'b')),
      hist('t'.repeat(51), 'a', 'b'),
    ];
    for (const h of cases) {
      const f = db();
      const b = writeBatch(f);
      b.update(doc(f, 'lives/L'), { title: 'x', ...upd() });
      b.set(doc(f, 'lives/L/history/h'), h);
      await assertFails(b.commit());
    }
  });

  test('新規作成と同じバッチの履歴は拒否（作成は変更ではない）', async () => {
    const f = db();
    const b = writeBatch(f);
    b.set(doc(f, 'lives/N'), {
      title: '新', groupIds: ['g1'], oshiIds: [],
      createdBy: 'alice', createdAt: serverTimestamp(), ...upd(),
    });
    b.set(doc(f, 'lives/N/history/h'), hist('title', undefined, '新'));
    await assertFails(b.commit());
  });

  test('after は親の反映後の値と同じでなければ拒否（偽の履歴を防ぐ）', async () => {
    await seedLive();
    let n = 0;
    const attempt = async (update, h) => {
      n += 1; // 毎回別の履歴 ID（同じ ID だと2回目は「更新」になり拒否される）
      const f = db();
      const b = writeBatch(f);
      b.update(doc(f, 'receptions/R0'), { ...update, ...upd() });
      b.set(doc(f, `receptions/R0/history/h${n}`), h);
      return b.commit();
    };
    // 既知の限界: before は検査できない（get が要り、件数の上限に当たる）ため、
    // 親の updatedAt だけを書き、今の値を after にした履歴は通る。
    // 誰でも直接更新できる設計なので、得られる力は直接更新と同じ範囲（ルールのコメント参照）
    await assertSucceeds(attempt({}, hist('applyEndAt', ts(9), ts(1, 0))));
    // 親の値と違う after（大きな値で履歴を汚すなど）は拒否
    await assertFails(attempt({}, hist('applyEndAt', ts(1, 0), 'x'.repeat(1000))));
    // after が反映後の値と違う
    await assertFails(attempt({ name: '新' }, hist('name', 'FC0次先行', '別')));
    // 項目を消したのに after がある
    await assertFails(attempt({ resultAt: deleteField() }, hist('resultAt', ts(2), ts(2))));
    // 項目が残っているのに after が無い
    await assertFails(attempt({ name: '新' }, hist('name', 'FC0次先行', undefined)));
    // そのコレクションの項目名でない（ライブの項目名・知らない項目名）
    await assertFails(attempt({ name: '新' }, hist('title', 'a', '新')));
    await assertFails(attempt({ name: '新' }, hist('memo', 'a', '新')));
    // 正しい形は通る（項目を消したときは after 無し）
    await assertSucceeds(attempt({ name: '新' }, hist('name', 'FC0次先行', '新')));
    await assertSucceeds(attempt({ resultAt: deleteField() }, hist('resultAt', ts(2), undefined)));
  });

  test('履歴の更新・削除はできない（作った本人でも）', async () => {
    await seedLive();
    await seed('lives/L/history/h', { field: 'title', before: 'a', after: 'b', changedBy: 'alice', changedAt: created });
    await assertFails(updateDoc(doc(db('alice'), 'lives/L/history/h'), { after: 'c' }));
    await assertFails(deleteDoc(doc(db('alice'), 'lives/L/history/h')));
  });
});

describe('一度に反映できる件数（ルールの読み取り上限。計画書 3.8）', () => {
  // 実測（エミュレータ）: 同じリクエストで書くドキュメントへの getAfter は上限の
  // 数に入らない。上限の件数（公演50・受付30）をすべて変えても通る。
  // ※ 本番の Firestore でも同じかは、デプロイ後に確かめる

  /** ライブ＋公演 nP 件＋受付 nR 件のすべてを変え、出演者も増やし、全項目の履歴を付ける */
  function fullMerge(tx, f, nP, nR, uid = 'alice') {
    const g = ['g1', 'g2'];
    // 履歴の after はルールで親の反映後の値と照合されるので、書く値と同じにする
    const write = (path, values) => {
      tx.update(doc(f, path), { ...values, ...upd(uid) });
      for (const [field, value] of Object.entries(values)) {
        if (field === 'groupIds' && path !== 'lives/L') continue; // 子の同期は履歴なし
        tx.set(doc(f, `${path}/history/${field}`), hist(field, 'before', value, uid));
      }
    };
    write('lives/L', { title: '新', groupIds: g, officialUrl: 'https://e.com/n' });
    for (let i = 0; i < nP; i++) {
      write(`performances/P${i}`, {
        groupIds: g, startAt: ts(1 + (i % 28), 23), openAt: ts(1 + (i % 28), 22),
        venue: `新会場${i}`, prefecture: '大阪府',
      });
    }
    for (let i = 0; i < nR; i++) {
      write(`receptions/R${i}`, {
        groupIds: g, type: 'general', name: `一般${i}`, applyStartAt: ts(2, 10),
        applyEndAt: ts(1 + (i % 28), 23), resultAt: ts(4), paymentDeadline: ts(6),
        prices: [{ seat: `A席${i}`, amount: 7000 + i }], winnersOnly: true,
      });
    }
  }

  test('上限の件数: 公演50＋受付30＋ライブのすべての項目を変え、履歴443件を1回のバッチで書ける', async () => {
    await seedLive({ nP: 50, nR: 30 });
    const f = db();
    const b = writeBatch(f);
    fullMerge(b, f, 50, 30);
    await assertSucceeds(b.commit());
    const h = await getDocs(collection(db(), 'receptions/R29/history'));
    if (h.size !== 8) throw new Error(`履歴が ${h.size} 件`);
  });

  test('上限の件数: 同じ内容をトランザクション（アプリの applyMerge と同じく先に全部読む）でも書ける', async () => {
    await seedLive({ nP: 50, nR: 30 });
    const f = db();
    await assertSucceeds(
      runTransaction(f, async (tx) => {
        await tx.get(doc(f, 'lives/L'));
        for (let i = 0; i < 50; i++) await tx.get(doc(f, `performances/P${i}`));
        for (let i = 0; i < 30; i++) await tx.get(doc(f, `receptions/R${i}`));
        fullMerge(tx, f, 50, 30);
      }),
    );
  });

  test('上限の件数: 既存のライブに公演49件＋受付30件を追加できる（1件は既存）', async () => {
    await seedLive({ nP: 1, nR: 0 });
    const f = db();
    const b = writeBatch(f);
    b.update(doc(f, 'lives/L'), upd());
    for (let i = 0; i < 49; i++) {
      b.set(doc(f, `performances/new${i}`), {
        liveId: 'L', groupIds: ['g1'], oshiIds: [], startAt: ts(1 + (i % 28), i % 24),
        venue: `会場${i}`, createdBy: 'alice', createdAt: serverTimestamp(), ...upd(),
      });
    }
    for (let i = 0; i < 30; i++) {
      b.set(doc(f, `receptions/new${i}`), {
        liveId: 'L', groupIds: ['g1'], oshiIds: [], type: 'fc', name: `FC${i}`,
        applyEndAt: ts(1 + (i % 28), i % 24), winnersOnly: false,
        createdBy: 'alice', createdAt: serverTimestamp(), ...upd(),
      });
    }
    await assertSucceeds(b.commit());
  });

  test('上限の件数で、最後の受付の履歴だけ親を更新していなければバッチ全体が拒否される', async () => {
    await seedLive({ nP: 50, nR: 31 });
    const f = db();
    const b = writeBatch(f);
    fullMerge(b, f, 50, 30);
    b.set(doc(f, 'receptions/R30/history/x'), hist('name', 'a', 'b')); // R30 は更新していない
    await assertFails(b.commit());
  });
});

describe('ほかのルールへの影響', () => {
  test('グッズの更新と履歴は従来どおり（履歴だけの作成は拒否）', async () => {
    await seed('goods/G', {
      name: 'アクスタ', category: 'acrylic', groupIds: ['g1'], oshiIds: [],
      variants: [{ id: 'v1', name: '通常' }], ...audit,
    });
    const f = db();
    const b = writeBatch(f);
    b.update(doc(f, 'goods/G'), { name: 'アクスタ2', ...upd() });
    b.set(doc(f, 'goods/G/history/h'), hist('name', 'アクスタ', 'アクスタ2'));
    await assertSucceeds(b.commit());
    await assertFails(setDoc(doc(db(), 'goods/G/history/h2'), hist('name', 'a', 'b')));
  });

  test('申込状況（users/{uid}/applications）は本人だけ', async () => {
    await seedLive();
    await assertSucceeds(
      setDoc(doc(db('alice'), 'users/alice/applications/R0'), {
        liveId: 'L', status: 'won', updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(getDoc(doc(db('bob'), 'users/alice/applications/R0')));
  });
});
