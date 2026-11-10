import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/messaging_providers.dart';
import '../../repositories/auth_repository.dart';
import '../../theme/hako_fonts.dart';
import '../../theme/hako_widgets.dart';
import '../../utils/auth_error_message.dart';
import 'auth_widgets.dart';

/// FirebaseAuthException 以外の例外のときの文言（例外の中身は出さない）
const _unknownError = 'うまくいきませんでした。もう一度お試しください。';

/// メールの確認待ち画面。確認が済むまで、アプリの他の画面には入れない。
/// 開いている間は 5 秒ごとに自動で確認し、別のタブでリンクを開いた場合も先へ進む
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  /// 自動で確認する間隔
  static const _pollInterval = Duration(seconds: 5);

  /// 確認メールを送り直したあと、次に押せるまでの秒数
  static const _resendCooldown = 60;

  Timer? _pollTimer;
  Timer? _cooldownTimer;
  bool _checking = false; // 確認の途中（重ねて確認しない）
  bool _manualChecking = false; // ボタンで確認している間（くるくるを出す）
  bool _resending = false;
  bool _signingOut = false;
  int _cooldownLeft = 0;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _check(manual: false));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _setMessage(String? message, {bool isError = false}) {
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }

  /// 最新の状態を読み直す。[manual] は「確認しました」ボタンから（結果を画面に出す）
  Future<void> _check({required bool manual}) async {
    if (_checking) return;
    _checking = true;
    // 自動の確認では、ボタンの見た目を変えない
    if (manual) setState(() => _manualChecking = true);
    try {
      final verified = await ref
          .read(authRepositoryProvider)
          .reloadEmailVerified();
      if (!mounted) return;
      if (verified) {
        _pollTimer?.cancel();
        // ルーターに振り分けをやり直させる（プロフィールの有無で /profile か /）
        context.go('/');
      } else if (manual) {
        _setMessage('まだ確認できていません。メールのリンクを開いてから、もう一度押してください。', isError: true);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (manual) _setMessage(authErrorMessage(e.code), isError: true);
    } catch (_) {
      // 自動の確認では何も出さない（5秒後にもう一度確かめる）。例外の中身は出さない
      if (!mounted) return;
      if (manual) _setMessage(_unknownError, isError: true);
    } finally {
      _checking = false;
      if (mounted && manual) setState(() => _manualChecking = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _cooldownLeft > 0) return;
    setState(() {
      _resending = true;
      _message = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendEmailVerification();
      if (!mounted) return;
      _setMessage('確認メールを送りました。');
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _setMessage(authErrorMessage(e.code), isError: true);
    } catch (_) {
      if (!mounted) return;
      _setMessage(_unknownError, isError: true);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownLeft = _resendCooldown);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_cooldownLeft <= 1) {
        timer.cancel();
        setState(() => _cooldownLeft = 0);
      } else {
        setState(() => _cooldownLeft--);
      }
    });
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      // ログアウトすると、ルーターが /welcome へ移す
      await signOutAndStopNotifications(ref);
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.read(authRepositoryProvider).currentUser?.email;
    final busy = _manualChecking || _resending || _signingOut;
    final bodyStyle = HakoFonts.jp(size: 15, height: 1.75);
    return AuthShell(
      key: const Key('verify_email_page'),
      heading: '確認メールを送りました',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          Text(
            email == null
                ? '届いたメールのリンクを開いてから、下のボタンを押してください。'
                : '$email に届いたメールのリンクを開いてから、下のボタンを押してください。',
            key: const Key('verify_description'),
            style: bodyStyle,
          ),
          const SizedBox(height: 6),
          Text('届かないときは、迷惑メールのフォルダも見てください。', style: bodyStyle),
          if (_message != null) ...[
            const SizedBox(height: 14),
            AuthMessageBanner(
              key: const Key('verify_message'),
              message: _message!,
              isError: _messageIsError,
            ),
          ],
          HakoPrimaryButton(
            key: const Key('verify_check_button'),
            label: '確認しました',
            busy: _manualChecking,
            onPressed: busy ? null : () => _check(manual: true),
          ),
          const SizedBox(height: 8),
          authLinkButton(
            key: const Key('verify_resend_button'),
            label: _cooldownLeft > 0
                ? '確認メールを送り直す（あと$_cooldownLeft秒）'
                : '確認メールを送り直す',
            onPressed: (busy || _cooldownLeft > 0) ? null : _resend,
          ),
          authLinkButton(
            key: const Key('verify_sign_out_button'),
            label: '別のアカウントでログインする',
            onPressed: busy ? null : _signOut,
          ),
        ],
      ),
    );
  }
}
