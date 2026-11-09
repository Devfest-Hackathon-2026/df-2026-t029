import test from 'node:test';
import assert from 'node:assert/strict';
import { buildGoogleDocs, parseArgs, seededIds } from './seed_google.mjs';

const SITE = 'https://g-palette-demo.web.app';

test('推しだけを入れ、ID は gdemo- で始まる（demo- は取得の対象外のため）', () => {
  const docs = buildGoogleDocs(SITE);
  for (const { path } of docs) {
    assert.match(path, /^(groups|oshis)\/gdemo-/);
  }
  // グループ3（4人・3人・3人）＋ソロ1
  assert.equal(docs.filter((d) => d.path.startsWith('groups/')).length, 3);
  assert.equal(docs.filter((d) => d.path.startsWith('oshis/')).length, 11);
});

test('G-Palette は公式サイト・X・YouTube を持ち、メンバーはグループに入っている', () => {
  const docs = Object.fromEntries(buildGoogleDocs(SITE).map((d) => [d.path, d.data]));
  const gp = docs['groups/gdemo-group-gpalette'];
  assert.equal(gp.name, 'G-Palette');
  assert.equal(gp.status, 'approved');
  assert.equal(gp.officialUrl, `${SITE}/g-palette/`);
  assert.equal(gp.officialX, 'googlejapan');
  assert.equal(gp.officialYoutube, '@GoogleJapan');
  for (const key of ['chrome', 'android', 'moffy', 'dino']) {
    assert.deepEqual(docs[`oshis/gdemo-oshi-${key}`].groupIds, ['gdemo-group-gpalette']);
  }
  // ソロ（個人）は公式サイトを持ち、グループに入っていない
  const solo = docs['oshis/gdemo-oshi-gemini'];
  assert.deepEqual(solo.groupIds, []);
  assert.equal(solo.officialUrl, `${SITE}/gemini-chan/`);
});

test('消す対象の ID は30件以内（array-contains-any・in の上限）', () => {
  const { groupIds, oshiIds } = seededIds();
  assert.ok(groupIds.length <= 30 && oshiIds.length <= 30);
  assert.ok(groupIds.length + oshiIds.length <= 30);
});

test('引数の検査', () => {
  assert.throws(() => parseArgs(['--project', 'x']));
  assert.throws(() => parseArgs(['--project', 'x', '--site-url', 'http://a.example']));
  assert.equal(parseArgs(['--project', 'x', '--site-url', `${SITE}/g-palette/`]).siteUrl, SITE);
  assert.equal(parseArgs(['--emulator', '--delete']).delete, true);
});
