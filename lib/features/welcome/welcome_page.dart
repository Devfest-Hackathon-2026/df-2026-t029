import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 紹介ページの文言（あとで直しやすいよう、ここにまとめる）
abstract final class _Copy {
  static const appName = 'おしあし';
  static const catchCopy = '推し活の予定を、ひとつに。';
  static const lead = 'ライブの日程も、申込・入金の締切も。スクショ1枚から、まとめて管理できます。';
  static const featuresTitle = 'できること';
  static const stepsTitle = '使い方';
  static const closing = '推し活の予定を、もう逃さない。';
  static const start = '始める';
}

/// 主な機能（アイコン、見出し、説明）
const _features = <(IconData, String, String)>[
  (
    Icons.document_scanner,
    'スクショから読み取り',
    '告知画像やチケットサイトのスクショから、日程・申込期限・入金期限を自動で読み取ります。',
  ),
  (
    Icons.groups,
    'みんなで共有',
    '同じ推しのファンが登録したライブ情報を、そのまま使えます。自分で入力しなくても大丈夫。',
  ),
  (
    Icons.event_available,
    'カレンダーと締切',
    '公演や期限を Google カレンダーに追加。ホームでは、次の締切をすぐに確認できます。',
  ),
];

/// 使い方（見出し、説明）
const _steps = <(String, String)>[
  ('推しをフォロー', '応援している推しを探して、フォローします。'),
  ('ライブを追加', 'スクショを読み取るか、みんなが登録したライブから選びます。'),
  ('締切を逃さない', 'カレンダーに入れて、申込・入金の期限を忘れずに。'),
];

/// 紹介ページ（ログインしていない人が最初に見るページ）
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  /// これ以上の幅なら、機能と使い方を横に3列で並べる
  static const _wideBreakpoint = 720.0;

  /// 内容の最大幅（広い画面では中央に寄せる）
  static const _maxContentWidth = 960.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideBreakpoint;
            return SingleChildScrollView(
              key: const Key('welcome_page'),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Hero(),
                        const SizedBox(height: 56),
                        _Section(
                          title: _Copy.featuresTitle,
                          wide: wide,
                          children: [
                            for (final (icon, title, body) in _features)
                              _InfoCard(
                                leading: _FeatureIcon(icon),
                                title: title,
                                body: body,
                              ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        _Section(
                          title: _Copy.stepsTitle,
                          wide: wide,
                          children: [
                            for (final (i, (title, body)) in _steps.indexed)
                              _InfoCard(
                                leading: _StepNumber(i + 1),
                                title: title,
                                body: body,
                              ),
                          ],
                        ),
                        const SizedBox(height: 56),
                        const _Closing(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// ① 見出し：アプリ名・キャッチコピー・説明・「始める」
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          _Copy.appName,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _Copy.catchCopy,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _Copy.lead,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 28),
        const _StartButton(key: Key('welcome_start_button')),
      ],
    );
  }
}

/// ② ③ 見出しと、3つのカード（広い画面では横、狭い画面では縦に並べる）
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.wide,
    required this.children,
  });

  final String title;
  final bool wide;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: child),
              ],
            ],
          )
        else
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            child,
          ],
      ],
    );
  }
}

/// 機能・使い方のカード
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.leading,
    required this.title,
    required this.body,
  });

  final Widget leading;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(body, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// 機能のアイコン
class _FeatureIcon extends StatelessWidget {
  const _FeatureIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary);
}

/// 使い方の番号
class _StepNumber extends StatelessWidget {
  const _StepNumber(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 16,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      child: Text('$number'),
    );
  }
}

/// ④ 締め：ひとこと・もう一度「始める」
class _Closing extends StatelessWidget {
  const _Closing();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          _Copy.closing,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const _StartButton(key: Key('welcome_start_button_bottom')),
      ],
    );
  }
}

/// 「始める」ボタン（ログイン画面へ）
class _StartButton extends StatelessWidget {
  const _StartButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => context.go('/login'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      ),
      child: const Text(_Copy.start),
    );
  }
}