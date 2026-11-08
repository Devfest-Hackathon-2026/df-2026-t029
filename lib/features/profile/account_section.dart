import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/email_change_providers.dart';
import '../../repositories/auth_repository.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/email_change.dart';
import 'email_change_sheet.dart';

/// 4.2 の「アカウント」の区画。登録方法が other・メールアドレスが無いときは何も出さない
class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(currentEmailProvider);
    if (email == null || email.isEmpty) return const SizedBox.shrink();
    final kind = accountKindOf(ref.read(authRepositoryProvider).providerIds);
    if (kind == AccountKind.other) return const SizedBox.shrink();

    return Column(
      key: const Key('profile_account_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        Semantics(
          header: true,
          child: Text(
            'アカウント',
            style: HakoFonts.jp(size: 18, weight: FontWeight.w700, height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        if (kind == AccountKind.email)
          _EmailRow(email: email)
        else
          _GoogleRow(email: email),
      ],
    );
  }
}

class _EmailRow extends StatelessWidget {
  const _EmailRow({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'メールアドレス、伏せて表示中',
          excludeSemantics: true,
          onTap: () => showEmailChangeSheet(context),
          child: InkWell(
            key: const Key('profile_email_row'),
            onTap: () => showEmailChangeSheet(context),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: BrandColors.rowLine, width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'メールアドレス',
                          style: HakoFonts.jp(
                            size: 16,
                            weight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          maskEmail(email),
                          style: HakoFonts.jp(
                            size: 13,
                            color: BrandColors.sub,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ),
        ),
        Text(
          'ログインに使うメールアドレスです。タップして変更できます。',
          style: HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.6),
        ),
      ],
    );
  }
}

/// Google 登録の人の行（押せない。表示／かくすだけ）
class _GoogleRow extends ConsumerWidget {
  const _GoogleRow({required this.email});

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reveal = ref.watch(emailRevealProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('profile_google_row'),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: BrandColors.rowLine, width: 1.5),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user_outlined, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Googleアカウントでログイン中',
                      style: HakoFonts.jp(
                        size: 16,
                        weight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Semantics(
                      label: reveal ? email : 'メールアドレス、伏せて表示中',
                      excludeSemantics: true,
                      child: Text(
                        reveal ? email : maskEmail(email),
                        style: HakoFonts.jp(
                          size: 13,
                          color: BrandColors.sub,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                toggled: reveal,
                excludeSemantics: true,
                label: reveal ? 'メールアドレスをかくす' : 'メールアドレスを表示',
                onTap: () => ref.read(emailRevealProvider.notifier).toggle(),
                child: InkWell(
                  key: const Key('email_reveal_button'),
                  onTap: () => ref.read(emailRevealProvider.notifier).toggle(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            reveal
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            reveal ? 'かくす' : '表示',
                            style: HakoFonts.jp(
                              size: 13,
                              weight: FontWeight.w700,
                              height: 1.4,
                            ).copyWith(decoration: TextDecoration.underline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          'メールアドレスは、Googleアカウント側で管理されています。変更するには、Googleアカウントの設定から行ってください。',
          style: HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.6),
        ),
      ],
    );
  }
}
