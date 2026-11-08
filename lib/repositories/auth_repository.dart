import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/auth_redirect.dart';

class AuthRepository {
  AuthRepository(this._auth);

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signInWithGoogle() async {
    await _auth.signInWithPopup(GoogleAuthProvider());
  }

  /// 新規登録。アカウントを作り、確認メールを送る（メールアドレスは前後の空白を除く）。
  /// 確認メールの送信に失敗しても例外にしない（確認画面で送り直せる）
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    try {
      await credential.user?.sendEmailVerification();
    } catch (_) {
      // 送れなくても登録は済んでいる。確認画面の「送り直す」に任せる
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  /// 確認メールを送り直す。ユーザーがいなければ何もしない
  Future<void> resendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// ユーザーの状態を読み直し、確認済みなら true（確認済みならトークンも取り直す）。
  /// reload では authStateChanges が流れないので、確認済みなら画面側で
  /// context.go('/') して、ルーターに振り分けをやり直させる
  Future<bool> reloadEmailVerified() async {
    final before = _auth.currentUser;
    if (before == null) return false;
    await before.reload();
    // reload 前の User の値は古いままなので、読み直してから見る
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) return false;
    await user.getIdToken(true);
    return true;
  }

  /// 今のユーザーが、メールの確認待ちか
  bool get currentUserNeedsEmailVerification {
    final user = _auth.currentUser;
    if (user == null) return false;
    return needsEmailVerification(
      emailVerified: user.emailVerified,
      providerIds: user.providerData.map((p) => p.providerId),
    );
  }

  /// 今のユーザーのメールアドレス。いなければ null
  String? get currentEmail => _auth.currentUser?.email;

  /// 今のユーザーのログイン方法の ID（'password'・'google.com' など）
  List<String> get providerIds =>
      _auth.currentUser?.providerData.map((p) => p.providerId).toList() ??
      const [];

  /// 新しいアドレスに確認のメールを送る（verifyBeforeUpdateEmail）。
  /// アドレスは前後の空白を除く。ユーザーがいなければ StateError。
  /// FirebaseAuthException（requires-recent-login など）はそのまま投げる
  Future<void> startEmailChange(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('ログインしていません');
    await user.verifyBeforeUpdateEmail(newEmail.trim());
  }

  /// パスワードで再認証する。いまのアドレスと渡したパスワードで資格情報を作る
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) throw StateError('ログインしていません');
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  /// ユーザーを読み直し、いまのメールアドレスを返す。
  /// ログインが無効になっていれば FirebaseAuthException を投げる
  Future<String?> reloadCurrentEmail() async {
    final before = _auth.currentUser;
    if (before == null) return null;
    await before.reload();
    return _auth.currentUser?.email;
  }

  Future<void> signOut() => _auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  // 確認メール・再設定メールを日本語で送る
  FirebaseAuth.instance.setLanguageCode('ja');
  return AuthRepository(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);
