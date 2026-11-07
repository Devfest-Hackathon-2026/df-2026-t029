// ログイン画面・メールの確認画面で共通に使う部品（案6「ハコ色」）。

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import '../../theme/hako_widgets.dart';
import '../live/official_url_link.dart' show urlLauncherProvider;

/// ログイン画面・確認画面の土台。HakoPage の中に、ヘッダー（戻る・アプリ名）・見出し・本文を並べる
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.heading,
    required this.body,
    this.showBack = false,
  });

  /// 見出し（改行は \n）
  final String heading;

  /// 見出しの下に置くもの（reCAPTCHA の文言も、ログイン画面では末尾に置く）
  final Widget body;

  /// 戻るボタン（`/welcome` へ）を出すか
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final appName = Text(
      'おしあし',
      style: HakoFonts.jp(size: 22, weight: FontWeight.w700, height: 1.4),
    );
    return HakoPage(
      child: HakoContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 76,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: showBack
                      ? MainAxisAlignment.spaceBetween
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showBack)
                      HakoPill(
                        key: const Key('login_back_button'),
                        label: '← 戻る',
                        // URL を直接開いた場合もあるため、戻る履歴に頼らず紹介ページへ移す
                        onPressed: () => context.go('/welcome'),
                      ),
                    appName,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      heading,
                      style: HakoFonts.jp(
                        size: 30,
                        weight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                  body,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 画面の中に出す、エラー（赤）・成功（緑）の帯。左端に色のブロックを付ける
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
    final color = isError ? BrandColors.hall1 : BrandColors.hall4;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: BrandColors.ink, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(color: color, child: const SizedBox(width: 8)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    message,
                    style: HakoFonts.jp(size: 14, height: 1.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// reCAPTCHA のバッジを隠す代わりに出す、Google の規約で求められる文言（明るい背景用の色）
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
    final base = HakoFonts.jp(size: 12, height: 1.7);
    final link = base.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: BrandColors.ink,
    );
    return Text.rich(
      key: const Key('login_recaptcha_notice'),
      textAlign: TextAlign.start,
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

/// 下線つきの文字だけのボタン（「パスワードを忘れた方」など）。左そろえ・高さ 44 以上。
/// [key] はタップを受ける `TextButton` 自身に付く
Widget authLinkButton({
  Key? key,
  required String label,
  required VoidCallback? onPressed,
}) {
  return Align(
    alignment: Alignment.centerLeft,
    child: TextButton(
      key: key,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        foregroundColor: BrandColors.ink,
        disabledForegroundColor: BrandColors.ink.withValues(alpha: 0.5),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      child: Text(
        label,
        style: HakoFonts.jp(size: 14, height: 1.4).copyWith(
          decoration: TextDecoration.underline,
          decorationColor: onPressed == null
              ? BrandColors.ink.withValues(alpha: 0.5)
              : BrandColors.ink,
          color: onPressed == null
              ? BrandColors.ink.withValues(alpha: 0.5)
              : BrandColors.ink,
        ),
      ),
    ),
  );
}
