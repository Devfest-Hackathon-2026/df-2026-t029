import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 紹介ページ（ログインしていない人が最初に見るページ）。
/// W-1 では仮の画面で、W-2 で本体を作る
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('おしあし', style: theme.textTheme.displaySmall),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('welcome_start_button'),
                onPressed: () => context.go('/login'),
                child: const Text('始める'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}