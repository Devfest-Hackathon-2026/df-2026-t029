import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/email_change_providers.dart';
import '../../repositories/auth_repository.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/email_change.dart';

/// PC の幅（720 以上）のとき、シートの最大幅
const double kEmailSheetMaxWidth = 640;

const double _wideBreakpoint = 720;

/// 4.3 のシートを開く。閉じたら完了する。
Future<void> showEmailChangeSheet(BuildContext context) {
  final media = MediaQuery.of(context);
  final wide = media.size.width >= _wideBreakpoint;
  final reveal = ProviderScope.containerOf(context)
      .read(emailRevealProvider.notifier);
  final container = ProviderScope.containerOf(context);
  // 開くたびに「かくす」に戻す
  void resetReveal() {
    if (container.read(emailRevealProvider)) reveal.toggle();
  }

  resetReveal();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: BrandColors.ink.withValues(alpha: 0.45),
    constraints: BoxConstraints(
      maxWidth: wide ? kEmailSheetMaxWidth : double.infinity,
      maxHeight: media.size.height * 0.9,
    ),
    sheetAnimationStyle: media.disableAnimations
        ? AnimationStyle.noAnimation
        : null,
    builder: (sheetContext) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(sheetContext).maybePop(),
      },
      child: const EmailChangeSheetBody(),
    ),
  ).whenComplete(resetReveal);
}

/// シートの中身
class EmailChangeSheetBody extends ConsumerStatefulWidget {
  const EmailChangeSheetBody({super.key});

  @override
  ConsumerState<EmailChangeSheetBody> createState() =>
      _EmailChangeSheetBodyState();
}

class _EmailChangeSheetBodyState extends ConsumerState<EmailChangeSheetBody> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _submit() {
    ref
        .read(emailChangeProvider.notifier)
        .submit(
          newEmail: _email.text,
          password: _password.text.isEmpty ? null : _password.text,
        );
  }

  void _finish() {
    final messenger = ScaffoldMessenger.of(context);
    ref.read(currentEmailProvider.notifier).refresh();
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('メールアドレスを変更しました')));
  }

  Future<void> _toLogin() async {
    final nav = Navigator.of(context);
    await ref.read(authRepositoryProvider).signOut();
    if (!mounted) return;
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(emailChangeProvider);
    ref.listen(emailChangeProvider, (prev, next) {
      // 送れたら、パスワードの入力は残さない
      if (prev?.step == EmailChangeStep.input &&
          next.step != EmailChangeStep.input) {
        _password.clear();
      }
      // 変更が済んだら、行の伏せ字を新しいアドレスに変える
      if (prev?.step != EmailChangeStep.done &&
          next.step == EmailChangeStep.done &&
          !next.sessionEnded) {
        ref.read(currentEmailProvider.notifier).refresh();
      }
    });
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final stepNo = switch (s.step) {
      EmailChangeStep.input => 1,
      EmailChangeStep.waiting => 2,
      EmailChangeStep.done => 3,
    };

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'メールアドレスを変更',
      child: DecoratedBox(
        key: const Key('email_sheet'),
        decoration: const BoxDecoration(
          color: BrandColors.paper,
          border: Border(
            top: BorderSide(color: BrandColors.ink, width: 2),
            left: BorderSide(color: BrandColors.ink, width: 2),
            right: BorderSide(color: BrandColors.ink, width: 2),
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: BrandColors.ink.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'メールアドレスを変更',
                        style: HakoFonts.jp(
                          size: 18,
                          weight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('email_sheet_close'),
                    tooltip: '閉じる',
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _Stepper(step: stepNo),
              const SizedBox(height: 18),
              switch (s.step) {
                EmailChangeStep.input => _InputStep(
                  state: s,
                  email: _email,
                  password: _password,
                  emailFocus: _emailFocus,
                  onSubmit: _submit,
                  onChanged: () =>
                      ref.read(emailChangeProvider.notifier).clearError(),
                ),
                EmailChangeStep.waiting => _WaitingStep(state: s),
                EmailChangeStep.done => _DoneStep(
                  state: s,
                  onFinish: _finish,
                  onToLogin: _toLogin,
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- ステッパー

class _Stepper extends StatelessWidget {
  const _Stepper({required this.step});

  final int step;

  static const _labels = ['入力', '確認', '完了'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (var i = 0; i < 3; i++) {
      final n = i + 1;
      final done = n < step;
      final on = n == step;
      children.add(
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: BrandColors.ink, width: 2),
            color: done
                ? BrandColors.ink
                : (on ? theme.primaryContainer : Colors.white),
          ),
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '$n',
                  style: HakoFonts.jp(
                    size: 13,
                    weight: FontWeight.w700,
                    height: 1.2,
                    color: on ? theme.onPrimaryContainer : BrandColors.ink,
                  ),
                ),
        ),
      );
      children.add(const SizedBox(width: 6));
      children.add(
        Text(
          _labels[i],
          style: HakoFonts.jp(
            size: 13,
            weight: FontWeight.w700,
            height: 1.4,
            color: on ? BrandColors.ink : BrandColors.sub,
          ),
        ),
      );
      if (i < 2) {
        children.add(const SizedBox(width: 6));
        children.add(
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minWidth: 12),
              height: 2,
              color: BrandColors.ink.withValues(alpha: 0.35),
            ),
          ),
        );
        children.add(const SizedBox(width: 6));
      }
    }
    return Semantics(
      label: 'ステップ $step / 3',
      excludeSemantics: true,
      child: Row(key: const Key('email_sheet_stepper'), children: children),
    );
  }
}

// ---------------------------------------------------------------- 共通の部品

class _RevealButton extends ConsumerWidget {
  const _RevealButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(emailRevealProvider);
    return Semantics(
      button: true,
      toggled: shown,
      excludeSemantics: true,
      label: shown ? 'メールアドレスをかくす' : 'メールアドレスを表示',
      onTap: () => ref.read(emailRevealProvider.notifier).toggle(),
      child: InkWell(
        onTap: () => ref.read(emailRevealProvider.notifier).toggle(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  shown
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  shown ? 'かくす' : '表示',
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
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m == null) return const SizedBox.shrink(key: Key('email_error'));
    return Semantics(
      liveRegion: true,
      child: Padding(
        key: const Key('email_error'),
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.error_outline,
                size: 18,
                color: BrandColors.errorText,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                m,
                style: HakoFonts.jp(
                  size: 13,
                  weight: FontWeight.w700,
                  height: 1.55,
                  color: BrandColors.errorText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainButton extends StatelessWidget {
  const _MainButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            disabledBackgroundColor: scheme.primaryContainer,
            disabledForegroundColor: scheme.onPrimaryContainer,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: BrandColors.ink, width: 2),
            ),
          ),
          child: Text(
            label,
            style: HakoFonts.jp(
              size: 15,
              weight: FontWeight.w700,
              height: 1.4,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: BrandColors.ink,
        disabledForegroundColor: BrandColors.ink.withValues(alpha: 0.5),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: HakoFonts.jp(
          size: 14,
          weight: FontWeight.w700,
          height: 1.4,
          color: enabled
              ? BrandColors.ink
              : BrandColors.ink.withValues(alpha: 0.5),
        ).copyWith(decoration: enabled ? TextDecoration.underline : null),
      ),
    );
  }
}

/// 見本の入力欄（枠 2px の墨・角丸 12・白）。エラーのときは輪が出る
class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.label,
    required this.controller,
    required this.hasError,
    required this.enabled,
    this.focusNode,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool hasError;
  final bool enabled;
  final FocusNode? focusNode;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool autofocus;
  final VoidCallback? onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final color = hasError ? BrandColors.errorText : BrandColors.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          label,
          style: HakoFonts.jp(size: 13, weight: FontWeight.w700, height: 1.4),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
            boxShadow: hasError
                ? const [
                    BoxShadow(color: Colors.white, spreadRadius: 2),
                    BoxShadow(color: BrandColors.errorText, spreadRadius: 4),
                  ]
                : null,
          ),
          child: Semantics(
            label: label,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autofocus: autofocus,
              obscureText: obscure,
              keyboardType: keyboardType,
              autofillHints: autofillHints,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              style: HakoFonts.jp(size: 17, height: 1.4),
              cursorColor: BrandColors.ink,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: HakoFonts.jp(
                  size: 17,
                  height: 1.4,
                  color: BrandColors.sub.withValues(alpha: 0.7),
                ),
              ),
              onChanged: (_) => onChanged?.call(),
              onSubmitted: (_) => onSubmitted?.call(),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- ステップ1

class _InputStep extends ConsumerWidget {
  const _InputStep({
    required this.state,
    required this.email,
    required this.password,
    required this.emailFocus,
    required this.onSubmit,
    required this.onChanged,
  });

  final EmailChangeState state;
  final TextEditingController email;
  final TextEditingController password;
  final FocusNode emailFocus;
  final VoidCallback onSubmit;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentEmailProvider) ?? '';
    final reveal = ref.watch(emailRevealProvider);
    final shown = reveal ? current : maskEmail(current);
    final hasError = state.error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '新しいメールアドレスに、確認のメールを送ります。メールのリンクを開くと、変更が終わります。それまでは、いまのメールアドレスのままです。',
          style: HakoFonts.jp(size: 15, height: 1.7),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'いまのメールアドレス',
                    style: HakoFonts.jp(
                      size: 13,
                      color: BrandColors.sub,
                      height: 1.4,
                    ),
                  ),
                  Semantics(
                    label: reveal ? current : 'メールアドレス、伏せて表示中',
                    excludeSemantics: true,
                    child: Text(
                      shown,
                      style: HakoFonts.jp(
                        size: 15,
                        weight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const _RevealButton(key: Key('email_sheet_reveal_button')),
          ],
        ),
        const SizedBox(height: 6),
        ListenableBuilder(
          listenable: Listenable.merge([email, password]),
          builder: (context, _) {
            final canSend = !state.busy && email.text.trim().isNotEmpty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Field(
                  key: const Key('email_new_field'),
                  label: '新しいメールアドレス',
                  controller: email,
                  focusNode: emailFocus,
                  hasError: hasError,
                  enabled: !state.busy,
                  autofocus: true,
                  hint: 'example@mail.com',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  onChanged: onChanged,
                  onSubmitted: canSend ? onSubmit : null,
                ),
                if (state.needsPassword) ...[
                  const SizedBox(height: 16),
                  Text(
                    '安全のため、パスワードをもう一度入力してください。',
                    style: HakoFonts.jp(
                      size: 13,
                      weight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                  _Field(
                    key: const Key('email_password_field'),
                    label: 'パスワード',
                    controller: password,
                    hasError: hasError,
                    enabled: !state.busy,
                    obscure: true,
                    autofillHints: const [AutofillHints.password],
                    onChanged: onChanged,
                    onSubmitted: canSend ? onSubmit : null,
                  ),
                ],
                _ErrorRow(message: state.error),
                _MainButton(
                  key: const Key('email_send_button'),
                  label: state.busy ? '送信中…' : '確認メールを送る',
                  onPressed: canSend ? onSubmit : null,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- ステップ2

class _WaitingStep extends ConsumerWidget {
  const _WaitingStep({required this.state});

  final EmailChangeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(emailChangeProvider.notifier);
    final waiting = state.resendLeft > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: state.sentTo,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: ' に、確認のメールを送りました。メールのリンクを開いてください。'),
            ],
          ),
          style: HakoFonts.jp(size: 15, height: 1.7),
        ),
        const SizedBox(height: 6),
        Text(
          'リンクを開くと、この画面は自動で次に進みます。メールが届かないときは、迷惑メールフォルダもご確認ください。このシートを閉じても、リンクを開けば変更されます。',
          style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.7),
        ),
        _ErrorRow(message: state.error),
        _MainButton(
          key: const Key('email_check_button'),
          label: 'リンクを開いたので確認する',
          onPressed: state.busy ? null : () => notifier.check(manual: true),
        ),
        const SizedBox(height: 8),
        Center(
          child: _LinkButton(
            key: const Key('email_resend_button'),
            label: waiting
                ? '確認メールを再送する（あと${state.resendLeft}秒）'
                : '確認メールを再送する',
            onPressed: (waiting || state.busy)
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await notifier.resend();
                    if (!context.mounted) return;
                    // 送れたとき（待ちが始まったとき）だけ知らせる
                    if (ref.read(emailChangeProvider).resendLeft > 0) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('確認メールを再送しました')),
                      );
                    }
                  },
          ),
        ),
        Center(
          child: _LinkButton(
            key: const Key('email_back_button'),
            label: 'メールアドレスを入力し直す',
            onPressed: notifier.backToInput,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- ステップ3

class _DoneStep extends StatelessWidget {
  const _DoneStep({
    required this.state,
    required this.onFinish,
    required this.onToLogin,
  });

  final EmailChangeState state;
  final VoidCallback onFinish;
  final VoidCallback onToLogin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ended = state.sessionEnded;
    final bodyStyle = HakoFonts.jp(
      size: 14,
      color: BrandColors.sub,
      height: 1.7,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer,
              border: Border.all(color: BrandColors.ink, width: 2),
            ),
            child: Icon(
              Icons.check,
              size: 38,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          liveRegion: true,
          child: Text(
            ended ? 'ログインの有効期限が切れました' : 'メールアドレスを変更しました',
            textAlign: TextAlign.center,
            style: HakoFonts.jp(size: 20, weight: FontWeight.w700, height: 1.4),
          ),
        ),
        const SizedBox(height: 8),
        if (ended)
          Text(
            'メールのリンクを開いた場合は、新しいメールアドレスでログインし直してください。',
            textAlign: TextAlign.center,
            style: bodyStyle,
          )
        else ...[
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '次回から、'),
                TextSpan(
                  text: state.sentTo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: BrandColors.ink,
                  ),
                ),
                const TextSpan(text: ' でログインします。'),
              ],
            ),
            textAlign: TextAlign.center,
            style: bodyStyle,
          ),
          Text(
            'これまでのメールアドレスにも、変更のお知らせが届きます。心当たりがない場合は、ログイン画面の『パスワードを忘れた方』から、パスワードを変え直してください。',
            textAlign: TextAlign.center,
            style: bodyStyle,
          ),
        ],
        _MainButton(
          key: const Key('email_done_button'),
          label: ended ? 'ログイン画面へ' : 'プロフィールに戻る',
          onPressed: ended ? onToLogin : onFinish,
        ),
      ],
    );
  }
}
