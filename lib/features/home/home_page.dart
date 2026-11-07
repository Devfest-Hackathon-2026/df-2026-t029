import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/profile_providers.dart';
import '../../repositories/auth_repository.dart';
import '../live/upcoming_deadlines_section.dart';
import '../shell/app_shell.dart' show kShellWideBreakpoint;

import 'home_section_header.dart';
import 'home_recent_memories.dart';
import 'home_upcoming_lives.dart';
import 'home_new_trades.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    // PC の幅では、アカウントのボタンが左下のタブにあるので AppBar には出さない
    final wide = MediaQuery.sizeOf(context).width >= kShellWideBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('おしあし'),
        actions: wide
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.account_circle),
                  tooltip: 'プロフィール',
                  onPressed: () => context.push('/profile'),
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'ログアウト',
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                ),
              ],
      ),
      body: SafeArea(
        child: ListView(
          key: const Key('home_page'),
          padding: const EdgeInsets.all(16),
          children: [
            _Greeting(name: profile?.displayName ?? 'ゲスト'),
            const SizedBox(height: 24),
            const HomeSectionHeader(title: '次の締切'),
            const SizedBox(height: 8),
            const UpcomingDeadlinesSection(),
            const SizedBox(height: 24),
            const HomeUpcomingLives(),
            const SizedBox(height: 24),
            const HomeNewTrades(),
            const SizedBox(height: 24),
            const HomeRecentMemories(),
          ],
        ),
      ),
    );
  }
}

/// ① あいさつと「行きたいライブを追加」（幅が狭いときはボタンを下に回す）
class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Text(
          'こんにちは、$nameさん',
          key: const Key('home_greeting'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        FilledButton.icon(
          key: const Key('home_add_live_button'),
          onPressed: () => context.push('/lives/add'),
          icon: const Icon(Icons.add),
          label: const Text('行きたいライブを追加'),
        ),
      ],
    );
  }
}