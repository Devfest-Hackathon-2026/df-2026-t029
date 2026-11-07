// groups / oshis のルール（計画書 3.7）: ログイン済みなら読める。作成は申請（pending）だけ。
// 更新・削除はクライアントから不可。
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

/** アプリの OshiRequest.toFirestore と同じ形の最小の申請 */
function minimal(uid = 'alice', extra = {}) {
  return {
    name: 'さくら',
    genre: 'idol',
    status: 'pending',
    createdBy: uid,
    createdAt: serverTimestamp(),
    ...extra,
  };
}

/** 任意項目をすべて入れた個人の申請 */
function full(uid = 'alice') {
  return minimal(uid, {
    aliases: ['さくちゃん', 'sakura'],
    agency: '事務所',
    officialUrl: 'https://example.com/sakura',
    officialX: 'sakura_official',
    groupIds: ['g1'],
  });
}

async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

const approvedDoc = {
  name: '承認済み',
  genre: 'idol',
  status: 'approved',
  createdBy: 'bob',
  createdAt: Timestamp.fromDate(new Date('2026-01-01')),
};

for (const col of ['groups', 'oshis']) {
  describe(`${col}: 読み取り`, () => {
    test('ログイン済みなら1件も一覧も読める（申請中を含む）', async () => {
      await seed(`${col}/a`, approvedDoc);
      await seed(`${col}/p`, { ...approvedDoc, status: 'pending' });
      await assertSucceeds(getDoc(doc(db(), `${col}/a`)));
      await assertSucceeds(getDoc(doc(db(), `${col}/p`)));
      await assertSucceeds(getDocs(collection(db(), col)));
    });

    test('未ログインでは読めない', async () => {
      await seed(`${col}/a`, approvedDoc);
      const anon = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(anon, `${col}/a`)));
      await assertFails(getDocs(collection(anon, col)));
    });
  });

  describe(`${col}: 作成（許可）`, () => {
    test('必須項目だけの申請を作成できる', async () => {
      await assertSucceeds(setDoc(doc(db(), `${col}/new`), minimal()));
    });

    test('任意項目をすべて入れた申請を作成できる', async () => {
      const data = full();
      if (col === 'groups') delete data.groupIds;
      await assertSucceeds(setDoc(doc(db(), `${col}/new`), data));
    });

    test('8つのジャンルのどれでも作成できる', async () => {
      for (const genre of [
        'idol',
        'voice_actor',
        'artist',
        'anime_game',
        'actor',
        'vtuber',
        'sports',
        'other',
      ]) {
        await assertSucceeds(
          setDoc(doc(db(), `${col}/${genre}`), minimal('alice', { genre })),
        );
      }
    });

    test('境界値: 名前50文字・別名10個・各50文字・URL 200文字・X 15文字', async () => {
      const url = 'https://example.com/' + 'a'.repeat(200 - 20);
      assert200(url);
      await assertSucceeds(
        setDoc(
          doc(db(), `${col}/edge`),
          minimal('alice', {
            name: 'あ'.repeat(50),
            aliases: Array.from({ length: 10 }, (_, i) => `${i}`.padEnd(50, 'い')),
            agency: 'え'.repeat(50),
            officialUrl: url,
            officialX: 'a'.repeat(15),
          }),
        ),
      );
    });

    test('文字数は UTF-16 単位: 絵文字25個（50単位）は可', async () => {
      await assertSucceeds(
        setDoc(doc(db(), `${col}/emoji`), minimal('alice', { name: '😀'.repeat(25) })),
      );
    });
  });

  describe(`${col}: 作成（拒否）`, () => {
    test('未ログインでは作成できない', async () => {
      const anon = testEnv.unauthenticatedContext().firestore();
      await assertFails(setDoc(doc(anon, `${col}/x`), minimal('alice')));
    });

    test('approved では作成できない', async () => {
      await assertFails(
        setDoc(doc(db(), `${col}/x`), minimal('alice', { status: 'approved' })),
      );
    });

    test('status が欠けている・未知の値なら作成できない', async () => {
      const data = minimal();
      delete data.status;
      await assertFails(setDoc(doc(db(), `${col}/x`), data));
      await assertFails(
        setDoc(doc(db(), `${col}/y`), minimal('alice', { status: 'PENDING' })),
      );
    });

    test('他人の uid を createdBy に入れて作成できない', async () => {
      await assertFails(setDoc(doc(db('alice'), `${col}/x`), minimal('bob')));
    });

    test('createdBy が欠けていると作成できない', async () => {
      const data = minimal();
      delete data.createdBy;
      await assertFails(setDoc(doc(db(), `${col}/x`), data));
    });

    test('createdAt にクライアントの時刻を入れると作成できない', async () => {
      await assertFails(
        setDoc(
          doc(db(), `${col}/x`),
          minimal('alice', { createdAt: Timestamp.now() }),
        ),
      );
    });

    test('必須項目（name・genre・createdAt）が欠けていると作成できない', async () => {
      for (const field of ['name', 'genre', 'createdAt']) {
        const data = minimal();
        delete data[field];
        await assertFails(setDoc(doc(db(), `${col}/${field}`), data));
      }
    });

    test('許可していない項目を足すと作成できない', async () => {
      for (const extra of [
        { approvedBy: 'alice' },
        { label: 'レーベル' },
        { updatedAt: serverTimestamp() },
      ]) {
        await assertFails(setDoc(doc(db(), `${col}/x`), minimal('alice', extra)));
      }
    });

    test('ジャンルが8つ以外なら作成できない', async () => {
      for (const genre of ['Idol', 'unknown', '', 1, null]) {
        await assertFails(
          setDoc(doc(db(), `${col}/x`), minimal('alice', { genre })),
        );
      }
    });

    test('名前: 空・空白だけ・51文字・文字列以外は作成できない', async () => {
      // 全角スペース・NBSP だけの名前も拒否（回帰テスト: trim() はこれらを除かない）
      for (const name of ['', '   ', '\u3000', '\u3000 \u00a0', '\u00a0', 'あ'.repeat(51), 123, ['さくら']]) {
        await assertFails(setDoc(doc(db(), `${col}/x`), minimal('alice', { name })));
      }
    });

    test('文字数は UTF-16 単位: 絵文字26個（52単位）は拒否', async () => {
      await assertFails(
        setDoc(doc(db(), `${col}/x`), minimal('alice', { name: '😀'.repeat(26) })),
      );
      await assertFails(
        setDoc(
          doc(db(), `${col}/y`),
          minimal('alice', { name: 'あ'.repeat(49) + '😀' }),
        ),
      );
    });

    test('別名: 11個・空の配列・51文字・空文字・文字列以外は作成できない', async () => {
      const eleven = Array.from({ length: 11 }, (_, i) => `別名${i}`);
      const tenthTooLong = [...Array.from({ length: 9 }, (_, i) => `${i}`), 'い'.repeat(51)];
      for (const aliases of [
        eleven,
        [],
        ['い'.repeat(51)],
        tenthTooLong,
        [''],
        ['a', 1],
        'さくら',
      ]) {
        await assertFails(
          setDoc(doc(db(), `${col}/x`), minimal('alice', { aliases })),
          `aliases=${JSON.stringify(aliases)}`,
        );
      }
    });

    test('事務所: 空文字・51文字は作成できない', async () => {
      for (const agency of ['', 'あ'.repeat(51), 1]) {
        await assertFails(setDoc(doc(db(), `${col}/x`), minimal('alice', { agency })));
      }
    });

    test('公式サイト: http・スキーム無し・空白入り・201文字は作成できない', async () => {
      const url201 = 'https://example.com/' + 'a'.repeat(181);
      for (const officialUrl of [
        'http://example.com',
        'example.com',
        'https://',
        'https://exa mple.com',
        'javascript:alert(1)',
        url201,
        '',
      ]) {
        await assertFails(
          setDoc(doc(db(), `${col}/x`), minimal('alice', { officialUrl })),
        );
      }
    });

    test('公式 X: @ 付き・16文字・記号・空文字は作成できない', async () => {
      for (const officialX of ['@sakura', 'a'.repeat(16), 'sa-kura', 'さくら', '']) {
        await assertFails(
          setDoc(doc(db(), `${col}/x`), minimal('alice', { officialX })),
        );
      }
    });
  });

  describe(`${col}: 更新・削除`, () => {
    test('自分の申請でも、承認（status の変更）・修正・削除はできない', async () => {
      await seed(`${col}/mine`, {
        ...approvedDoc,
        status: 'pending',
        createdBy: 'alice',
      });
      const ref = doc(db('alice'), `${col}/mine`);
      await assertFails(updateDoc(ref, { status: 'approved' }));
      await assertFails(updateDoc(ref, { name: '別の名前' }));
      await assertFails(setDoc(ref, minimal('alice')));
      await assertFails(deleteDoc(ref));
    });

    test('他人の承認済みの推しも更新・削除できない', async () => {
      await seed(`${col}/a`, approvedDoc);
      const ref = doc(db('alice'), `${col}/a`);
      await assertFails(updateDoc(ref, { name: '乗っ取り' }));
      await assertFails(deleteDoc(ref));
    });
  });
}

describe('groups と oshis の違い', () => {
  test('groups には groupIds を書けない', async () => {
    await assertFails(
      setDoc(doc(db(), 'groups/x'), minimal('alice', { groupIds: ['g1'] })),
    );
  });

  test('oshis の groupIds: 10個は可、11個・空・129文字の ID は拒否', async () => {
    const ten = Array.from({ length: 10 }, (_, i) => `g${i}`);
    await assertSucceeds(setDoc(doc(db(), 'oshis/ok'), minimal('alice', { groupIds: ten })));
    for (const groupIds of [[...ten, 'g10'], [], ['a'.repeat(129)], [''], [1]]) {
      await assertFails(setDoc(doc(db(), 'oshis/x'), minimal('alice', { groupIds })));
    }
    await assertSucceeds(
      setDoc(doc(db(), 'oshis/ok128'), minimal('alice', { groupIds: ['a'.repeat(128)] })),
    );
  });
});

function assert200(url) {
  if (url.length !== 200) throw new Error(`URL の長さが ${url.length}`);
}
