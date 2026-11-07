// ログイン画面・メールの確認画面で共通に使う部品（紹介ページの「締め」と同じ世界観）。

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/brand_colors.dart';
import '../live/official_url_link.dart' show urlLauncherProvider;

/// 夜 → 紫のグラデーション背景に、ピンクの光・アプリ名・カードを並べる土台
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.card,
    this.showBack = false,
    this.footer,
  });

  /// カードの中身
  final Widget card;

  /// 戻るボタン（`/welcome` へ）を出すか
  final bool showBack;

  /// カードの下に置くもの（reCAPTCHA の文言など）
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final nameSize = (width * 0.11).clamp(44.0, 64.0);
    return Scaffold(
      backgroundColor: BrandColors.night,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [BrandColors.night, BrandColors.violet],
          ),
        ),
        child: DecoratedBox(
          // 上のほうに、ステージの照明のようなピンクの光
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 0.9,
              colors: [Color(0x40FF4FA3), Color(0x00FF4FA3)],
            ),
          ),
          child: SafeArea(
            child: SizedBox.expand(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 48,
                          child: showBack
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: IconButton(
                                    key: const Key('login_back_button'),
                                    icon: const Icon(Icons.arrow_back),
                                    color: BrandColors.text,
                                    tooltip: '戻る',
                                    // URL を直接開いた場合もあるため、戻る履歴に頼らず紹介ページへ移す
                                    onPressed: () => context.go('/welcome'),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'おしあし',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: BrandColors.text,
                            fontSize: nameSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: nameSize * 0.06,
                            height: 1.15,
                            shadows: const [
                              Shadow(color: Color(0xD9FF4FA3), blurRadius: 18),
                              Shadow(color: Color(0x80FF4FA3), blurRadius: 46),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '推し活の予定を、ひとつに。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: BrandColors.subText,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 28),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: BrandColors.paper,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: card,
                          ),
                        ),
                        if (footer != null) ...[
                          const SizedBox(height: 20),
                          Center(child: footer),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ピンク → 紫のグラデーションの丸いボタン（紹介ページの「始める」と同じ）。
/// [onPressed] が null のときは押せない。[busy] のときは、くるくるを出す
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          gradient: const LinearGradient(
            colors: [BrandColors.pink, BrandColors.purple],
          ),
          boxShadow: enabled
              ? const [BoxShadow(color: Color(0x66FF4FA3), blurRadius: 20)]
              : null,
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: BrandColors.text,
            disabledForegroundColor: BrandColors.text,
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: busy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: BrandColors.text,
                  ),
                )
              : Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

/// カードの中に出す、エラー（赤系）の帯
class AuthMessageBanner extends StatelessWidget {
  const AuthMessageBanner({
    super.key,
    required this.message,
    this.isError = true,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFB3261E) : const Color(0xFF1B6E3C);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: color, fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// reCAPTCHA のバッジを隠す代わりに出す、Google の規約で求められる文言（暗い背景用の色）
class AuthRecaptchaNotice extends ConsumerStatefulWidget {
  const AuthRecaptchaNotice({super.key});

  @override
  ConsumerState<AuthRecaptchaNotice> createState() =>
      _AuthRecaptchaNoticeState();
}

class _AuthRecaptchaNoticeState extends ConsumerState<AuthRecaptchaNotice> {
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
    const base = TextStyle(color: Color(0x99FFFFFF), fontSize: 11, height: 1.7);
    final link = base.copyWith(
      color: const Color(0xDDFFFFFF),
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xDDFFFFFF),
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
