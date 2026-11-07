import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'following_oshi_list.dart';

/// 推しの画面（タブの「推し」）：推しを探す・フォロー中の推し
class OshiPage extends StatelessWidget {
  const OshiPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('推し'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const Key('oshi_search_button'),
                onPressed: () => context.push('/oshi/search'),
                icon: const Icon(Icons.search),
                label: const Text('推しを探す'),
              ),
            ),
            const SizedBox(height: 24),
            Text('フォロー中の推し', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const FollowingOshiList(),
          ],
        ),
      ),
    );
  }
}