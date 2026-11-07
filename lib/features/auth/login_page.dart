import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/auth_repository.dart';
import '../../theme/brand_colors.dart';
import '../../theme/google_logo.dart';
import '../../theme/hako_fonts.dart';
import '../../theme/hako_widgets.dart';
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
    final smallStyle = HakoFonts.jp(size: 12, height: 1.7);
    return AuthShell(
      key: const Key('login_page'),
      showBack: true,
      heading: _isSignUp ? 'はじめまして。\n入口はこちら。' : 'おかえりなさい。\n入口はこちら。',
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: HakoTab(
                    key: const Key('login_mode_signin'),
                    label: 'ログイン',
                    selected: !_isSignUp,
                    onPressed: busy
                        ? null
                        : () => _changeMode(LoginMode.signIn),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: HakoTab(
                    key: const Key('login_mode_signup'),
                    label: '新規登録',
                    selected: _isSignUp,
                    onPressed: busy
                        ? null
                        : () => _changeMode(LoginMode.signUp),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              key: const Key('login_google_button'),
              onPressed: busy ? null : _google,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.white,
                foregroundColor: BrandColors.googleText,
                side: const BorderSide(color: BrandColors.googleBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: _busy == _Busy.google
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: BrandColors.googleText,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const GoogleLogo(size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Google で続ける',
                            style: HakoFonts.googleButton(),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Divider(
                    color: BrandColors.ink,
                    thickness: 2,
                    height: 2,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'またはメールで',
                    style: HakoFonts.jp(size: 13, height: 1.4),
                  ),
                ),
                const Expanded(
                  child: Divider(
                    color: BrandColors.ink,
                    thickness: 2,
                    height: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            hakoFieldLabel('メールアドレス'),
            TextFormField(
              key: const Key('login_email_field'),
              controller: _email,
              enabled: !busy,
              style: hakoInputTextStyle(),
              cursorColor: BrandColors.ink,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: hakoInputDecoration(),
              validator: validateEmail,
            ),
            hakoFieldLabel('パスワード'),
            TextFormField(
              key: const Key('login_password_field'),
              controller: _password,
              enabled: !busy,
              style: hakoInputTextStyle(),
              cursorColor: BrandColors.ink,
              obscureText: _obscure,
              autofillHints: [
                _isSignUp ? AutofillHints.newPassword : AutofillHints.password,
              ],
              textInputAction: _isSignUp
                  ? TextInputAction.next
                  : TextInputAction.done,
              onFieldSubmitted: _isSignUp ? null : (_) => _submit(),
              decoration: hakoInputDecoration(
                helperText: _isSignUp ? '$minPasswordLength文字以上' : null,
                suffixIcon: IconButton(
                  key: const Key('login_password_toggle'),
                  tooltip: _obscure ? 'パスワードを表示' : 'パスワードを隠す',
                  color: BrandColors.ink,
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => validatePassword(v, isSignUp: _isSignUp),
            ),
            if (_isSignUp) ...[
              hakoFieldLabel('パスワード（確認）'),
              TextFormField(
                key: const Key('login_password_confirm_field'),
                controller: _confirm,
                enabled: !busy,
                style: hakoInputTextStyle(),
                cursorColor: BrandColors.ink,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: hakoInputDecoration(),
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
            HakoPrimaryButton(
              key: const Key('login_submit_button'),
              label: _isSignUp ? '登録して確認メールを送る' : 'ログイン',
              busy: _busy == _Busy.submit,
              onPressed: busy ? null : _submit,
            ),
            if (!_isSignUp) ...[
              const SizedBox(height: 16),
              authLinkButton(
                key: const Key('login_forgot_password_button'),
                label: 'パスワードを忘れた方',
                onPressed: busy ? null : _forgotPassword,
              ),
            ],
            const SizedBox(height: 22),
            if (_isSignUp)
              Text('登録すると確認メールが届きます。メールのリンクを開くと使えるようになります。', style: smallStyle),
            Text(
              'Google カレンダーへの追加は、使うときに Google アカウントの許可を求めます。',
              style: smallStyle,
            ),
            const SizedBox(height: 8),
            const AuthRecaptchaNotice(),
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
      backgroundColor: BrandColors.paper,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: BrandColors.ink, width: 2),
      ),
      title: Text(
        'パスワードの再設定',
        style: HakoFonts.jp(size: 22, weight: FontWeight.w700, height: 1.4),
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                hakoFieldLabel('メールアドレス'),
                TextFormField(
                  key: const Key('reset_email_field'),
                  controller: _email,
                  style: hakoInputTextStyle(),
                  cursorColor: BrandColors.ink,
                  enabled: !_busy && !_sent,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _send(),
                  decoration: hakoInputDecoration(),
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
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 44),
            foregroundColor: BrandColors.ink,
          ),
          child: Text(
            '閉じる',
            style: HakoFonts.jp(size: 14, height: 1.4).copyWith(
              decoration: TextDecoration.underline,
              decorationColor: BrandColors.ink,
            ),
          ),
        ),
        if (!_sent)
          FilledButton(
            key: const Key('reset_send_button'),
            onPressed: _busy ? null : _send,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: BrandColors.ink,
              disabledBackgroundColor: BrandColors.ink,
              foregroundColor: BrandColors.hall3,
              disabledForegroundColor: BrandColors.hall3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: BrandColors.hall3,
                    ),
                  )
                : Text(
                    '再設定のメールを送る',
                    style: HakoFonts.jp(
                      size: 14,
                      weight: FontWeight.w700,
                      color: BrandColors.hall3,
                      height: 1.4,
                    ),
                  ),
          ),
      ],
    );
  }
}
