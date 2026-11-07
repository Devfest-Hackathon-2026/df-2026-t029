// 認証まわりのテスト用の偽物（パッケージは使わず、手で書く）
// 注意: テストのパスワードは架空の値にし、出力しないこと
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:oshiashi/repositories/auth_repository.dart';

FirebaseAuthException authError(String code) =>
    FirebaseAuthException(code: code);

/// 偽の AuthRepository（画面のテスト用）。呼ばれた引数を記録する。
/// [gate] を入れると、その Completer が終わるまで各メソッドが待つ（処理中の確認用）
class FakeAuthRepository implements AuthRepository {
  final List<({String email, String password})> signUps = [];
  final List<({String email, String password})> signIns = [];
  final List<String> resets = [];
  int googleSignIns = 0;
  int resends = 0;
  int reloads = 0;
  int signOuts = 0;

  /// 次の呼び出しで投げる例外（メソッド名 → 例外）。投げたら消える
  final Map<String, Object> errors = {};

  Completer<void>? gate;

  /// reloadEmailVerified の返り値
  bool verified = false;

  @override
  bool get currentUserNeedsEmailVerification => !verified;

  @override
  User? get currentUser => user;

  /// currentUser が返す User（確認画面でメールアドレスを出すため）
  User? user;

  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  Future<void> _run(String name) async {
    final g = gate;
    if (g != null) await g.future;
    final e = errors.remove(name);
    if (e != null) throw e;
  }

  @override
  Future<void> signInWithGoogle() async {
    googleSignIns++;
    await _run('google');
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    signUps.add((email: email, password: password));
    await _run('signUp');
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signIns.add((email: email, password: password));
    await _run('signIn');
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resets.add(email);
    await _run('reset');
  }

  @override
  Future<void> resendEmailVerification() async {
    resends++;
    await _run('resend');
  }

  @override
  Future<bool> reloadEmailVerified() async {
    reloads++;
    await _run('reload');
    return verified;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    await _run('signOut');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserInfo implements UserInfo {
  FakeUserInfo(this.providerId);

  @override
  final String providerId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCredential implements AuthCredential {
  FakeCredential(this.accessToken);

  @override
  final String? accessToken;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserCredential implements UserCredential {
  FakeUserCredential({this.user, this.credential});

  @override
  final User? user;

  @override
  final AuthCredential? credential;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 偽の User。呼ばれた回数と、ポップアップ系の動きを差し替えられる
class FakeUser implements User {
  FakeUser({
    this.uid = 'u1',
    this.email = 'a@example.com',
    this.emailVerified = false,
    List<String> providerIds = const ['password'],
  }) : providerData = [for (final p in providerIds) FakeUserInfo(p)];

  @override
  final String uid;

  @override
  final String? email;

  @override
  bool emailVerified;

  @override
  List<UserInfo> providerData;

  int reloads = 0;
  int verificationMails = 0;
  final List<bool> tokenRefreshes = [];
  final List<AuthProvider> linkCalls = [];
  final List<AuthProvider> reauthCalls = [];

  Object? verificationError;

  /// reload したときに起きること（例: 確認済みにする）
  void Function()? onReload;

  /// linkWithPopup・reauthenticateWithPopup の結果。例外を投げたいときは Error を入れる
  Future<UserCredential> Function(AuthProvider provider)? onLink;
  Future<UserCredential> Function(AuthProvider provider)? onReauth;

  @override
  Future<void> reload() async {
    reloads++;
    onReload?.call();
  }

  @override
  Future<void> sendEmailVerification([ActionCodeSettings? settings]) async {
    verificationMails++;
    final e = verificationError;
    if (e != null) throw e;
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    tokenRefreshes.add(forceRefresh);
    return 'token';
  }

  @override
  Future<UserCredential> linkWithPopup(AuthProvider provider) {
    linkCalls.add(provider);
    return onLink!(provider);
  }

  @override
  Future<UserCredential> reauthenticateWithPopup(AuthProvider provider) {
    reauthCalls.add(provider);
    return onReauth!(provider);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 偽の FirebaseAuth
class FakeFirebaseAuth implements FirebaseAuth {
  FakeFirebaseAuth([this.currentUser]);

  @override
  User? currentUser;

  final List<({String email, String password})> created = [];
  final List<({String email, String password})> signedIn = [];
  final List<String> resetMails = [];
  int popups = 0;
  int signOuts = 0;

  /// createUserWithEmailAndPassword が返す User
  FakeUser? userToCreate;
  Object? createError;
  Object? signInError;
  Object? resetError;

  @override
  Stream<User?> authStateChanges() => Stream.value(currentUser);

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    created.add((email: email, password: password));
    final e = createError;
    if (e != null) throw e;
    final user = userToCreate ?? FakeUser(email: email);
    currentUser = user;
    return FakeUserCredential(user: user);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signedIn.add((email: email, password: password));
    final e = signInError;
    if (e != null) throw e;
    return FakeUserCredential(user: currentUser);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    resetMails.add(email);
    final e = resetError;
    if (e != null) throw e;
  }

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) async {
    popups++;
    return FakeUserCredential(user: currentUser);
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    currentUser = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
