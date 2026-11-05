// Firestore ルールのテスト用の共通ヘルパー。
// firebase emulators:exec の中で実行する前提（FIRESTORE_EMULATOR_HOST が設定される）。
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { setLogLevel } from 'firebase/firestore';

// 拒否を確かめるテストで出る PERMISSION_DENIED の警告ログを抑える
setLogLevel('error');

export const PROJECT_ID = 'demo-oshiashi';

const rulesPath = fileURLToPath(new URL('../firestore.rules', import.meta.url));

function emulatorHostAndPort() {
  const value = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8085';
  const index = value.lastIndexOf(':');
  return { host: value.slice(0, index), port: Number(value.slice(index + 1)) };
}

export async function createTestEnv() {
  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(rulesPath, 'utf8'),
      ...emulatorHostAndPort(),
    },
  });
}
