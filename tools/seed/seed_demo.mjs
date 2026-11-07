// デモ用データ（架空）を Firestore に入れる・消すスクリプト。
//
//   node seed_demo.mjs --project <プロジェクト ID> [--base YYYY-MM-DD]
//     [--uid <デモ用アカウントの uid> --name <表示名>]
//     [--partner-uid <相手役の uid> --partner-name <表示名>]
//   node seed_demo.mjs --project <プロジェクト ID> --delete
//   （--project の代わりに --emulator でエミュレータに入れる）
//
// --uid を指定したときだけ、個人データ（プロフィール・ライブ一覧・申込状況・メモリー・
// けんの投稿・返信・チャット）を入れる。--partner-uid は --uid と一緒に使う。
//
// 認証情報はリポジトリに入れない。本番に入れるときは、サービスアカウントの鍵を
// リポジトリの外に置いて GOOGLE_APPLICATION_CREDENTIALS で渡す
// （または gcloud auth application-default login）。詳しくは README.md。

import { fileURLToPath } from 'node:url';
import {
  DEMO_COLLECTIONS,
  DEMO_PREFIX,
  baseMillis,
  buildDemoDocs,
  todayJst,
} from './demo_data.mjs';
import { buildTradeDocs } from './demo_trade.mjs';
import { buildPersonalDocs } from './demo_personal.mjs';

const EMULATOR_HOST = '127.0.0.1:8085'; // firebase.json の Firestore エミュレータ
const EMULATOR_PROJECT = 'demo-oshiashi';
const BATCH_LIMIT = 450; // Firestore の1バッチの上限（500）より少なめ

export function parseArgs(argv) {
  const opts = {
    emulator: false,
    project: null,
    base: null,
    delete: false,
    uid: null,
    name: null,
    partnerUid: null,
    partnerName: null,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--emulator') opts.emulator = true;
    else if (a === '--delete') opts.delete = true;
    else if (a === '--project') opts.project = argv[++i] ?? null;
    else if (a === '--base') opts.base = argv[++i] ?? null;
    else if (a === '--uid') opts.uid = argv[++i] ?? null;
    else if (a === '--name') opts.name = argv[++i] ?? null;
    else if (a === '--partner-uid') opts.partnerUid = argv[++i] ?? null;
    else if (a === '--partner-name') opts.partnerName = argv[++i] ?? null;
    else throw new Error(`知らない引数です: ${a}`);
  }
  if (opts.emulator === !!opts.project) {
    throw new Error('--emulator か --project <ID> のどちらか1つを指定してください');
  }
  if (opts.uid && !opts.name) throw new Error('--uid には --name も指定してください');
  if (opts.partnerUid && !opts.uid) {
    throw new Error('--partner-uid は --uid と一緒に指定してください');
  }
  if (opts.partnerUid && !opts.partnerName) {
    throw new Error('--partner-uid には --partner-name も指定してください');
  }
  return opts;
}

/** Date は Timestamp に変換して、書き込む形にする */
function toFirestoreValue(value, Timestamp) {
  if (value instanceof Date) return Timestamp.fromDate(value);
  if (Array.isArray(value)) return value.map((v) => toFirestoreValue(v, Timestamp));
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([k, v]) => [k, toFirestoreValue(v, Timestamp)]),
    );
  }
  return value;
}

/** [{ path, data }] を、バッチを分けて書く。set は上書きなので、何度実行しても重複しない */
async function seed(db, Timestamp, docs) {
  let count = 0;
  for (let i = 0; i < docs.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    for (const { path, data } of docs.slice(i, i + BATCH_LIMIT)) {
      batch.set(db.doc(path), toFirestoreValue(data, Timestamp));
      count++;
    }
    await batch.commit();
  }
  return count;
}

/**
 * demo- で始まる ID のドキュメントを、サブコレクション（履歴・返信・メッセージ）ごと消す。
 * users/{uid} 以下の個人データは消さない（全部消すときは firebase firestore:delete を使う）
 */
async function remove(db, FieldPath) {
  let count = 0;
  for (const name of DEMO_COLLECTIONS) {
    const snap = await db
      .collection(name)
      .where(FieldPath.documentId(), '>=', DEMO_PREFIX)
      .where(FieldPath.documentId(), '<', 'demo.') // '-' の次の文字 '.' が上限
      .get();
    for (const doc of snap.docs) {
      await db.recursiveDelete(doc.ref);
      count++;
    }
  }
  return count;
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.emulator) process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
  const projectId = opts.emulator ? EMULATOR_PROJECT : opts.project;

  const { initializeApp } = await import('firebase-admin/app');
  const { getFirestore, Timestamp, FieldPath } = await import(
    'firebase-admin/firestore'
  );
  initializeApp({ projectId });
  const db = getFirestore();

  if (opts.delete) {
    const n = await remove(db, FieldPath);
    console.log(`デモ用データを ${n} 件（サブコレクションを含む）消しました: ${projectId}`);
    return;
  }
  const base = opts.base ?? todayJst();
  const b = baseMillis(base);
  const docs = [...buildDemoDocs(base), ...buildTradeDocs(base, b)];
  if (opts.uid) docs.push(...buildPersonalDocs(b, opts));
  const n = await seed(db, Timestamp, docs);
  console.log(
    `デモ用データを ${n} 件入れました（基準日 ${base}` +
      `${opts.uid ? `、個人データ: ${opts.name}` : ''}` +
      `${opts.partnerUid ? `、相手役: ${opts.partnerName}` : ''}）: ${projectId}`,
  );
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((e) => {
    console.error(e.message ?? e);
    process.exit(1);
  });
}