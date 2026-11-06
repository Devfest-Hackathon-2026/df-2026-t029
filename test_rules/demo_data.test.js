// デモ用データ（tools/seed/demo_data.mjs）が、アプリのルールの検査を満たすか。
// 管理者の権限（ルール無効）で入れたあと、ふつうのユーザーとして更新できる形か確かめる。
// （更新の検査は、項目・型・長さ・createdBy の保持・出演者の一致を含む）
import { after, afterEach, before, describe, test } from 'node:test';
import { assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, serverTimestamp, setDoc } from 'firebase/firestore';
import { readFileSync } from 'node:fs';
import { createTestEnv } from './helpers.js';
import { buildDemoData, collectionsOf } from '../tools/seed/demo_data.mjs';

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

const data = buildDemoData('2026-11-05');

async function seedAll() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const [name, docs] of collectionsOf(data)) {
      for (const [id, fields] of Object.entries(docs)) {
        await setDoc(doc(db, name, id), fields);
      }
    }
  });
}

describe('デモ用データ', () => {
  test('test/fixtures/demo_data.json が demo_data.mjs と一致している（ずれたら作り直す）', () => {
    const fixture = readFileSync(
      new URL('../test/fixtures/demo_data.json', import.meta.url),
      'utf8',
    );
    // 作り直す手順は test/repositories/demo_data_test.dart の冒頭にある
    if (JSON.stringify(JSON.parse(fixture)) !== JSON.stringify(data)) {
      throw new Error(
        'fixture が古い: test/repositories/demo_data_test.dart の手順で作り直してください',
      );
    }
  });


  test('件数: groups1・oshis4・lives3・performances5・receptions5', () => {
    const n = Object.fromEntries(
      collectionsOf(data).map(([k, v]) => [k, Object.keys(v).length]),
    );
    if (JSON.stringify(n) !== JSON.stringify({ groups: 1, oshis: 4, lives: 3, performances: 5, receptions: 5 })) {
      throw new Error(JSON.stringify(n));
    }
  });

  for (const name of ['lives', 'performances', 'receptions']) {
    test(`${name}: すべて、ふつうのユーザーが更新できる形`, async () => {
      await seedAll();
      const bob = testEnv.authenticatedContext('bob').firestore();
      for (const [id, fields] of Object.entries(data[name])) {
        await assertSucceeds(
          setDoc(doc(bob, name, id), {
            ...fields,
            updatedBy: 'bob',
            updatedAt: serverTimestamp(),
          }),
        );
      }
    });
  }

  test('ライブの出演者は、公演・受付の出演者と一致している', () => {
    for (const name of ['performances', 'receptions']) {
      for (const [id, f] of Object.entries(data[name])) {
        const live = data.lives[f.liveId];
        if (!live) throw new Error(`${id}: ライブが無い`);
        if (JSON.stringify(live.groupIds) !== JSON.stringify(f.groupIds) ||
            JSON.stringify(live.oshiIds) !== JSON.stringify(f.oshiIds)) {
          throw new Error(`${id}: 出演者がライブと違う`);
        }
      }
    }
  });
});
