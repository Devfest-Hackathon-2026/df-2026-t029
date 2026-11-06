import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/auth_repository.dart';
import '../live/official_url_link.dart' show urlLauncherProvider;

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () async {
                try {
                  await ref.read(authRepositoryProvider).signInWithGoogle();
                } on FirebaseAuthException catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('ログインに失敗しました（${e.code}）')),
                  );
                }
              },
              child: const Text('Google でログイン'),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: _RecaptchaNotice(),
            ),
          ],
        ),
      ),
    );
  }
}

/// reCAPTCHA のバッジを隠す代わりに出す、Google の規約で求められる文言
class _RecaptchaNotice extends ConsumerStatefulWidget {
  const _RecaptchaNotice();

  @override
  ConsumerState<_RecaptchaNotice> createState() => _RecaptchaNoticeState();
}

class _RecaptchaNoticeState extends ConsumerState<_RecaptchaNotice> {
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => _open('https://policies.google.com/privacy');
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => _open('https://policies.google.com/terms');

  Future<void> _open(String url) =>
      ref.read(urlLauncherProvider)(Uri.parse(url));

  @override
  void dispose() {
    _privacy.dispose();
    _terms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall;
    final link = base?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    return Text.rich(
      key: const Key('login_recaptcha_notice'),
      textAlign: TextAlign.center,
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'このサイトは reCAPTCHA で保護されており、Google の'),
          TextSpan(text: 'プライバシーポリシー', style: link, recognizer: _privacy),
          const TextSpan(text: 'と'),
          TextSpan(text: '利用規約', style: link, recognizer: _terms),
          const TextSpan(text: 'が適用されます。'),
        ],
      ),
    );
  }
}
