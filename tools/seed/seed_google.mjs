// Google にまつわる架空の推し（G-Palette ほか）を Firestore に入れる・消すスクリプト。
//
//   node seed_google.mjs --project <プロジェクト ID> --site-url https://<デモサイト>.web.app
//   node seed_google.mjs --project <プロジェクト ID> --delete
//   （--project の代わりに --emulator でエミュレータに入れる）
//
// - 入れるのは推し（グループ・メンバー・ソロ）だけ。ライブは入れない。
//   アプリの「ライブ情報を取得」で、架空の公式サイト（demo_site/）から取得する。
// - ID は gdemo- で始まる固定の値。demo- にしないのは、functions/live_fetch が
//   demo- の推しを取得の対象外にしているため。
// - 推しの名前・公式サイトのパスは demo_site/site_data.mjs と同じものを使う。
// - --delete は、gdemo- の推しと、その推しに付いたライブ・公演・受付・お知らせを消す
//   （サイトから取得したもの・スクショから追加したものを含む。変更履歴のサブコレクションごと）。
//   フォローの記録や users/{uid} 以下（本人のデータ）は消さない。

import { fileURLToPath } from 'node:url';
import { ACTS, GDEMO_PREFIX } from '../../demo_site/site_data.mjs';

const EMULATOR_HOST = '127.0.0.1:8085';
const EMULATOR_PROJECT = 'demo-oshiashi';
const SEED_UID = 'gdemo-seed'; // createdBy に入れる架空の uid

export function parseArgs(argv) {
  const opts = { emulator: false, project: null, siteUrl: null, delete: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--emulator') opts.emulator = true;
    else if (a === '--delete') opts.delete = true;
    else if (a === '--project') opts.project = argv[++i] ?? null;
    else if (a === '--site-url') opts.siteUrl = argv[++i] ?? null;
    else throw new Error(`知らない引数です: ${a}`);
  }
  if (opts.emulator === !!opts.project) {
    throw new Error('--emulator か --project <ID> のどちらか1つを指定してください');
  }
  if (!opts.delete) {
    if (!opts.siteUrl) throw new Error('--site-url（デモサイトの URL）を指定してください');
    let url;
    try {
      url = new URL(opts.siteUrl);
    } catch (e) {
      throw new Error(`--site-url が URL の形ではありません: ${opts.siteUrl}`);
    }
    if (url.protocol !== 'https:' && !opts.emulator) {
      throw new Error('--site-url は https の URL にしてください');
    }
    opts.siteUrl = url.origin;
  }
  return opts;
}

/** 書き込むドキュメント [{ path, data }]。createdAt は Date のまま（書くときに変換） */
export function buildGoogleDocs(siteUrl, now = new Date()) {
  const docs = [];
  const base = { status: 'approved', createdBy: SEED_UID, createdAt: now };
  for (const act of ACTS) {
    const official = {
      officialUrl: `${siteUrl}/${act.slug}/`,
      ...(act.officialX ? { officialX: act.officialX } : {}),
      ...(act.officialYoutube ? { officialYoutube: act.officialYoutube } : {}),
    };
    if (act.kind === 'group') {
      docs.push({
        path: `groups/${act.id}`,
        data: { name: act.name, aliases: act.aliases, genre: act.genre, ...official, ...base },
      });
      for (const m of act.members) {
        docs.push({
          path: `oshis/${m.id}`,
          data: {
            name: m.name,
            aliases: m.aliases,
            genre: act.genre,
            groupIds: [act.id],
            ...base,
          },
        });
      }
    } else {
      docs.push({
        path: `oshis/${act.id}`,
        data: {
          name: act.name,
          aliases: act.aliases,
          genre: act.genre,
          groupIds: [],
          ...official,
          ...base,
        },
      });
    }
  }
  return docs;
}

/** 消す対象の推しの ID（グループ・個人） */
export function seededIds() {
  const groupIds = ACTS.filter((a) => a.kind === 'group').map((a) => a.id);
  const oshiIds = ACTS.flatMap((a) =>
    a.kind === 'group' ? a.members.map((m) => m.id) : [a.id],
  );
  return { groupIds, oshiIds };
}

async function remove(db, FieldPath) {
  const { groupIds, oshiIds } = seededIds();
  const refs = new Map();
  // 推しに付いたライブ・公演・受付（array-contains-any は30件まで。今は30件より少ない）
  for (const col of ['lives', 'performances', 'receptions']) {
    for (const [field, ids] of [['groupIds', groupIds], ['oshiIds', oshiIds]]) {
      const snap = await db.collection(col).where(field, 'array-contains-any', ids).get();
      for (const d of snap.docs) refs.set(d.ref.path, d.ref);
    }
  }
  // お知らせ（oshiKey は group:xxx / person:xxx）
  const keys = [...groupIds.map((id) => `group:${id}`), ...oshiIds.map((id) => `person:${id}`)];
  const news = await db.collection('oshiNews').where('oshiKey', 'in', keys).get();
  for (const d of news.docs) refs.set(d.ref.path, d.ref);
  // 推し
  for (const col of ['groups', 'oshis']) {
    const snap = await db
      .collection(col)
      .where(FieldPath.documentId(), '>=', GDEMO_PREFIX)
      .where(FieldPath.documentId(), '<', 'gdemo.') // '-' の次の文字 '.' が上限
      .get();
    for (const d of snap.docs) refs.set(d.ref.path, d.ref);
  }
  for (const ref of refs.values()) await db.recursiveDelete(ref);
  return refs.size;
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.emulator) process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
  const projectId = opts.emulator ? EMULATOR_PROJECT : opts.project;

  const { initializeApp } = await import('firebase-admin/app');
  const { getFirestore, Timestamp, FieldPath } = await import('firebase-admin/firestore');
  initializeApp({ projectId });
  const db = getFirestore();

  if (opts.delete) {
    const n = await remove(db, FieldPath);
    console.log(`Google の架空の推しと、付いていたデータを ${n} 件消しました: ${projectId}`);
    return;
  }
  const docs = buildGoogleDocs(opts.siteUrl);
  const batch = db.batch();
  for (const { path, data } of docs) {
    batch.set(db.doc(path), { ...data, createdAt: Timestamp.fromDate(data.createdAt) });
  }
  await batch.commit();
  console.log(`Google の架空の推しを ${docs.length} 件入れました（公式サイト ${opts.siteUrl}）: ${projectId}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((e) => {
    console.error(e.message ?? e);
    process.exit(1);
  });
}
