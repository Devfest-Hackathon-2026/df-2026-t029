import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/auth_repository.dart';
import '../oshi/following_oshi_list.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('おしあし'),
        actions: [
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
            Text('ようこそ、${user?.displayName ?? 'ゲスト'} さん'),
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
            const SizedBox(height: 24),
            Text('フォロー中の推し', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const FollowingOshiList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/register'),
        icon: const Icon(Icons.add),
        label: const Text('ライブを登録'),
      ),
    );
  }
}
