import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/trade_post.dart';
import '../../providers/trade_post_providers.dart';
import '../trade/trade_post_summary_lines.dart';
import 'home_section_header.dart';

/// ④ 新しい交換（フォロー中の推しの、ほかの人の募集中の投稿）
class HomeNewTrades extends ConsumerWidget {
  const HomeNewTrades({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(homeTradePostsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: '新しい交換',
          onSeeAll: () => context.go('/trade'),
        ),
        const SizedBox(height: 8),
        switch (posts) {
          AsyncValue(value: final list?) when list.isEmpty =>
            const HomeSectionMessage('フォロー中の推しの交換の投稿は、まだありません'),
          AsyncValue(value: final list?) => Column(
              key: const Key('home_new_trades'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, p) in list.indexed) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _TradeTile(post: p),
                ],
              ],
            ),
          AsyncError() => const HomeSectionMessage('読み込めませんでした'),
          _ => const HomeSectionLoading(),
        },
      ],
    );
  }
}

/// 投稿1件（投稿者名と、掲示板と同じ要約）
class _TradeTile extends StatelessWidget {
  const _TradeTile({required this.post});

  final TradePost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('home_new_trade_${post.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/trade/${post.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.displayName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              TradePostSummaryLines(post: post),
            ],
          ),
        ),
      ),
    );
  }
}