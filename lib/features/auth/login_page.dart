import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/auth_repository.dart';
import '../../theme/brand_colors.dart';
import '../../utils/auth_error_message.dart';
import '../../utils/auth_validators.dart';
import 'auth_widgets.dart';

/// ログイン画面の切り替え（ログイン／新規登録）
enum LoginMode { signIn, signUp }

/// FirebaseAuthException 以外の例外のときの文言（例外の中身は出さない）
const _unknownError = 'うまくいきませんでした。もう一度お試しください。';

/// 処理中の操作（押したボタンにだけ、くるくるを出す）
enum _Busy { google, submit }

/// ログイン画面。Google・メールアドレスのどちらでも入れる。
/// 成功すると、ルーターが自動で次の画面（確認画面・プロフィール・ホーム）へ移す
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.initialMode = LoginMode.signIn});

  final LoginMode initialMode;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late LoginMode _mode = widget.initialMode;
  bool _obscure = true;
  _Busy? _busy;
  String? _error;

  bool get _isSignUp => _mode == LoginMode.signUp;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _changeMode(LoginMode mode) {
    if (_busy != null || mode == _mode) return;
    setState(() {
      _mode = mode;
      _error = null;
      // 各欄の検査エラーを消す（入力した文字は残る）
      _formKey = GlobalKey<FormState>();
    });
  }

  /// 失敗を、カード内の帯に出す（ポップアップを閉じただけなら何も出さない）
  void _showError(FirebaseAuthException e) {
    setState(() => _error = authErrorMessage(e.code));
  }

  Future<void> _google() async {
    if (_busy != null) return;
    setState(() {
      _busy = _Busy.google;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(e);
    } catch (_) {
      // 例外の中身は出さない
      if (!mounted) return;
      setState(() => _error = _unknownError);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _submit() async {
    if (_busy != null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(authRepositoryProvider);
    final email = _email.text.trim();
    final password = _password.text;
    setState(() {
      _busy = _Busy.submit;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await repo.signUpWithEmail(email: email, password: password);
      } else {
        await repo.signInWithEmail(email: email, password: password);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(e);
    } catch (_) {
      // 例外の中身（パスワードを含みうる）は出さない
      if (!mounted) return;
      setState(() => _error = _unknownError);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _forgotPassword() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ResetPasswordDialog(initialEmail: _email.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busy != null;
    return AuthShell(
      key: const Key('login_page'),
      showBack: true,
      footer: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: const AuthRecaptchaNotice(),
      ),
      card: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<LoginMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: LoginMode.signIn,
                    label: Text('ログイン', key: Key('login_mode_signin')),
                  ),
                  ButtonSegment(
                    value: LoginMode.signUp,
                    label: Text('新規登録', key: Key('login_mode_signup')),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: busy ? null : (s) => _changeMode(s.first),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              key: const Key('login_google_button'),
              onPressed: busy ? null : _google,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: BrandColors.ink,
                side: const BorderSide(color: BrandColors.line, width: 1.5),
                shape: const StadiumBorder(),
              ),
              child: _busy == _Busy.google
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Google で続ける'),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: Divider(color: BrandColors.line)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'または メールアドレスで',
                    style: TextStyle(color: BrandColors.inkSub, fontSize: 12),
                  ),
                ),
                Expanded(child: Divider(color: BrandColors.line)),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('login_email_field'),
              controller: _email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                border: OutlineInputBorder(),
              ),
              validator: validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('login_password_field'),
              controller: _password,
              enabled: !busy,
              obscureText: _obscure,
              autofillHints: [
                _isSignUp ? AutofillHints.newPassword : AutofillHints.password,
              ],
              textInputAction: _isSignUp
                  ? TextInputAction.next
                  : TextInputAction.done,
              onFieldSubmitted: _isSignUp ? null : (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'パスワード',
                helperText: _isSignUp ? '$minPasswordLength文字以上' : null,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  key: const Key('login_password_toggle'),
                  tooltip: _obscure ? 'パスワードを表示' : 'パスワードを隠す',
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => validatePassword(v, isSignUp: _isSignUp),
            ),
            if (_isSignUp) ...[
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('login_password_confirm_field'),
                controller: _confirm,
                enabled: !busy,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'パスワード（確認）',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => validatePasswordConfirm(v, _password.text),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              AuthMessageBanner(
                key: const Key('login_error'),
                message: _error!,
              ),
            ],
            const SizedBox(height: 20),
            GradientButton(
              key: const Key('login_submit_button'),
              label: _isSignUp ? '登録して確認メールを送る' : 'ログイン',
              busy: _busy == _Busy.submit,
              onPressed: busy ? null : _submit,
            ),
            if (!_isSignUp)
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  key: const Key('login_forgot_password_button'),
                  onPressed: busy ? null : _forgotPassword,
                  child: const Text('パスワードを忘れた方'),
                ),
              ),
            const SizedBox(height: 8),
            if (_isSignUp)
              const Text(
                '登録すると確認メールが届きます。メールのリンクを開くと使えるようになります。',
                style: TextStyle(
                  color: BrandColors.inkSub,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            const Text(
              'Google カレンダーへの追加は、使うときに Google アカウントの許可を求めます。',
              style: TextStyle(
                color: BrandColors.inkSub,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// パスワードの再設定メールを送るダイアログ。
/// 登録の有無を他人に知らせないため、成功でも user-not-found でも同じ文言を出す
class _ResetPasswordDialog extends ConsumerStatefulWidget {
  const _ResetPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  ConsumerState<_ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  bool _busy = false;
  bool _sent = false;
  String? _error;

  static const _sentMessage = '入力したメールアドレスが登録されていれば、パスワードを再設定するメールを送りました。';

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(_email.text);
      if (!mounted) return;
      setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'user-not-found') {
        setState(() => _sent = true);
      } else {
        setState(() => _error = authErrorMessage(e.code));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = _unknownError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('パスワードの再設定'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('reset_email_field'),
                  controller: _email,
                  enabled: !_busy && !_sent,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    border: OutlineInputBorder(),
                  ),
                  validator: validateEmail,
                ),
                if (_sent) ...[
                  const SizedBox(height: 14),
                  const AuthMessageBanner(
                    key: Key('reset_sent_message'),
                    message: _sentMessage,
                    isError: false,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  AuthMessageBanner(
                    key: const Key('reset_error'),
                    message: _error!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('reset_close_button'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
        if (!_sent)
          FilledButton(
            key: const Key('reset_send_button'),
            onPressed: _busy ? null : _send,
            child: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('再設定のメールを送る'),
          ),
      ],
    );
  }
}
