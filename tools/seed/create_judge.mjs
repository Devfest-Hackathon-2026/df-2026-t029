import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

initializeApp({ credential: applicationDefault(), projectId: 'oshiashi-test' });

const user = await getAuth().createUser({
  email: 'gdgoc.2026@example.com',
  password: 'gdgoc-2026',
  emailVerified: true,
});
console.log('uid:', user.uid);