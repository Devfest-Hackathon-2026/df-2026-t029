import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/oshi.dart';
import '../../models/trade_post.dart';
import '../../providers/oshi_providers.dart';
import '../../providers/trade_post_providers.dart';
import 'trade_post_summary.dart';
import 'trade_post_summary_lines.dart';
import 'trade_post_thumb.dart';

/// 自分の投稿の一覧（更新日時の新しい順。交換トップの「自分の投稿」タブ）。
/// 編集・募集終了・再開ができる
class MyTradePostsView extends ConsumerWidget {
  const MyTradePostsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(myTradePostsProvider);
    final all = ref.watch(allOshisProvider).value ?? const <OshiSummary>[];

    return posts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('投稿を読み込めませんでした: $e')),
      data: (list) => ListView(
        // 右下のボタンで最後の投稿が隠れないようにする
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          Text('投稿者名：${ref.watch(myDisplayNameProvider)}'),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(child: Text('まだ投稿がありません')),
            )
          else
            for (final p in list) _PostCard(post: p, all: all),
        ],
      ),
    );
  }
}

class _PostCard extends ConsumerStatefulWidget {
  const _PostCard({required this.post, required this.all});

  final TradePost post;
  final List<OshiSummary> all;

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  bool _busy = false;

  Future<void> _setStatus(TradePostStatus status) async {
    final post = widget.post;
    if (status == TradePostStatus.closed) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('募集を終了しますか？'),
          content: const Text('掲示板とマッチに表示されなくなります。あとで再開できます'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('my_trade_close_confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('募集終了にする'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(tradePostRepositoryProvider).setStatus(post.id!, status);
      ref.invalidate(tradePostByIdProvider(post.id!));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == TradePostStatus.closed ? '募集を終了しました' : '募集を再開しました',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('変更できませんでした: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final theme = Theme.of(context);
    final isOpen = post.status == TradePostStatus.open;
    final isHidden = post.status == TradePostStatus.hidden;
    final targets = targetNames(post, widget.all);

    return Opacity(
      // 募集終了・非表示は薄く表示する
      opacity: isOpen ? 1 : 0.6,
      child: Card(
        key: Key('my_trade_post_${post.id}'),
        margin: const EdgeInsets.symmetric(vertical: 6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/trade/${post.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text(post.status.label),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        targets.isEmpty ? '（対象の推し）' : targets,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isHidden)
                      const SizedBox(height: 48)
                    else
                      PopupMenuButton<String>(
                        key: Key('my_trade_menu_${post.id}'),
                        enabled: !_busy,
                        tooltip: '操作',
                        onSelected: (v) => switch (v) {
                          'edit' => context.push('/trade/${post.id}/edit'),
                          'close' => _setStatus(TradePostStatus.closed),
                          _ => _setStatus(TradePostStatus.open),
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('編集')),
                          if (isOpen)
                            const PopupMenuItem(
                              value: 'close',
                              child: Text('募集終了'),
                            )
                          else
                            const PopupMenuItem(
                              value: 'open',
                              child: Text('再開'),
                            ),
                        ],
                      ),
                  ],
                ),
                // 写真があれば右に1枚目を出す（G-7）
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TradePostWithThumb(
                    post: post,
                    child: TradePostSummaryLines(post: post),
                  ),
                ),
                if (isHidden)
                  Text(
                    '運営により非表示にされています。編集・再開はできません',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
