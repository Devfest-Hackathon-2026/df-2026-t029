// 共有のデータ（推し・ライブ・公演・受付・グッズ・投稿・チャット・お知らせ・公開メモリー）を、
// ID に関係なく全部消すスクリプト。手で入れたデータ・テストで入れたデータもまとめて消える。
//
//   node reset_shared.mjs --project <プロジェクト ID>         # お試し：消す件数を表示するだけ
//   node reset_shared.mjs --project <プロジェクト ID> --yes   # 本当に消す（元に戻せない）
//   （--project の代わりに --emulator でエミュレータ）
//
// 消さないもの：users/（各自のアカウントと個人データ）、publicProfiles/（公開プロフィール）、
// そのほか下の一覧に無いコレクション（見つかったら名前だけ表示する）。
// users/{uid}/myLives・applications などは、消したライブを指したまま残る（アプリは「見つからない」として扱う）。

import { fileURLToPath } from 'node:url';

const EMULATOR_HOST = '127.0.0.1:8085';
const EMULATOR_PROJECT = 'demo-oshiashi';

/** 消すコレクション（サブコレクションの変更履歴・返信・メッセージも一緒に消える） */
export const SHARED_COLLECTIONS = [
  'groups',
  'oshis',
  'oshiNews',
  'lives',
  'performances',
  'receptions',
  'goods',
  'tradePosts',
  'chats',
  'publicMemories',
];

/** 消さないコレクション */
export const KEEP_COLLECTIONS = ['users', 'publicProfiles'];

export function parseArgs(argv) {
  const opts = { emulator: false, project: null, yes: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--emulator') opts.emulator = true;
    else if (a === '--yes') opts.yes = true;
    else if (a === '--project') opts.project = argv[++i] ?? null;
    else throw new Error(`知らない引数です: ${a}`);
  }
  if (opts.emulator === !!opts.project) {
    throw new Error('--emulator か --project <ID> のどちらか1つを指定してください');
  }
  return opts;
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.emulator) process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
  const projectId = opts.emulator ? EMULATOR_PROJECT : opts.project;

  const { initializeApp } = await import('firebase-admin/app');
  const { getFirestore } = await import('firebase-admin/firestore');
  initializeApp({ projectId });
  const db = getFirestore();

  console.log(`${opts.yes ? '消します' : 'お試し（消しません）'}: ${projectId}`);
  let total = 0;
  for (const name of SHARED_COLLECTIONS) {
    const count = (await db.collection(name).count().get()).data().count;
    total += count;
    console.log(`  ${name}: ${count} 件`);
  }
  const others = (await db.listCollections())
    .map((c) => c.id)
    .filter((id) => !SHARED_COLLECTIONS.includes(id));
  console.log(`  残すコレクション: ${others.join('、') || 'なし'}`);

  if (!opts.yes) {
    console.log(`合計 ${total} 件（サブコレクションは別）。消すときは --yes を付けて実行してください。`);
    return;
  }
  for (const name of SHARED_COLLECTIONS) {
    await db.recursiveDelete(db.collection(name));
  }
  console.log(`消しました（合計 ${total} 件とそのサブコレクション）。`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((e) => {
    console.error(e.message ?? e);
    process.exit(1);
  });
}
