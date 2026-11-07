import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/profile_providers.dart';
import '../../repositories/auth_repository.dart';
import '../live/upcoming_deadlines_section.dart';
import '../oshi/following_oshi_list.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final user = ref.watch(authStateProvider).value;
    final profile = ref.watch(myProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('おしあし'),
        actions: [
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
          padding: const EdgeInsets.all(16),
          children: [
            Text('ようこそ、${profile?.displayName ?? 'ゲスト'} さん'),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const Key('home_search_button'),
                onPressed: () => context.push('/oshi/search'),
                icon: const Icon(Icons.search),
                label: const Text('推しを探す'),
              ),
            ),
            const SizedBox(height: 8),
            // ライブの登録は右下のボタン（登録方法を選ぶ画面）にまとめる
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('home_live_list_button'),
                onPressed: () => context.push('/lives'),
                icon: const Icon(Icons.event_note),
                label: const Text('ライブ一覧'),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('home_trade_button'),
                onPressed: () => context.push('/trade'),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('グッズ交換'),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('home_memory_button'),
                onPressed: () => context.push('/memories'),
                icon: const Icon(Icons.photo_album),
                label: const Text('メモリー'),
              ),
            ),
            const SizedBox(height: 24),
            Text('次の締切', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const UpcomingDeadlinesSection(),
            const SizedBox(height: 24),
            Text('フォロー中の推し', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const FollowingOshiList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('home_add_live_fab'),
        onPressed: () => context.push('/lives/add'),
        icon: const Icon(Icons.add),
        label: const Text('ライブを追加する'),
      ),
    );
  }
}
