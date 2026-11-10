import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

// 審査用アカウントを作る（あればパスワードだけ変える）。
// パスワードはリポジトリに書かず、環境変数で渡す:
//   JUDGE_PASSWORD='...' node create_judge.mjs
const EMAIL = 'gdgoc.2026@example.com';
const password = process.env.JUDGE_PASSWORD;
if (!password) {
  console.error('JUDGE_PASSWORD を指定してください');
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), projectId: 'oshiashi-test' });
const auth = getAuth();

try {
  const user = await auth.getUserByEmail(EMAIL);
  await auth.updateUser(user.uid, { password, emailVerified: true });
  console.log('パスワードを更新しました uid:', user.uid);
} catch (e) {
  if (e.code !== 'auth/user-not-found') throw e;
  const user = await auth.createUser({ email: EMAIL, password, emailVerified: true });
  console.log('作成しました uid:', user.uid);
}