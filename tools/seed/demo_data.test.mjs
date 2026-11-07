import test from 'node:test';
import assert from 'node:assert/strict';
import { at, baseMillis, buildDemoData, collectionsOf, todayJst } from './demo_data.mjs';
import { parseArgs } from './seed_demo.mjs';

test('ID はすべて demo- で始まる', () => {
  for (const [, docs] of collectionsOf(buildDemoData('2026-11-09'))) {
    for (const id of Object.keys(docs)) assert.match(id, /^demo-/);
  }
});

test('日時は基準日からの相対（日本時間）', () => {
  const b = baseMillis('2026-11-09');
  assert.equal(at(b, 2, 23, 59).toISOString(), '2026-11-11T14:59:00.000Z');
  const d1 = buildDemoData('2026-11-09');
  const d2 = buildDemoData('2026-11-10');
  const key = 'demo-rec-stella-tour-fc';
  assert.equal(
    d2.receptions[key].applyEndAt - d1.receptions[key].applyEndAt,
    86400000,
  );
});

test('アプグレは winnersOnly で、受付は親ライブと出演者が同じ', () => {
  const d = buildDemoData('2026-11-09');
  assert.equal(d.receptions['demo-rec-stella-tour-upgrade'].winnersOnly, true);
  for (const r of Object.values(d.receptions)) {
    const live = d.lives[r.liveId];
    assert.deepEqual(r.groupIds, live.groupIds);
    assert.deepEqual(r.oshiIds, live.oshiIds);
  }
  for (const p of Object.values(d.performances)) {
    assert.deepEqual(p.groupIds, d.lives[p.liveId].groupIds);
  }
});

test('todayJst と引数の検査', () => {
  assert.equal(todayJst(new Date('2026-11-09T16:00:00Z')), '2026-11-10');
  assert.throws(() => baseMillis('11/09'));
  assert.throws(() => parseArgs([]));
  assert.throws(() => parseArgs(['--emulator', '--project', 'x']));
  assert.equal(parseArgs(['--emulator', '--delete']).delete, true);
});
