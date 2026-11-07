import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/oshi.dart';
import '../../models/trade_post.dart';
import '../../providers/oshi_providers.dart';
import '../../providers/trade_post_providers.dart';
import '../../utils/trade_board.dart';
import 'board_filter_sheet.dart';
import 'trade_post_summary.dart';
import 'trade_post_summary_lines.dart';

/// 交換の掲示板（交換トップの「掲示板」タブ）。
/// 推しを選び、募集中の投稿を更新日時の新しい順に出す
class TradeBoardView extends ConsumerStatefulWidget {
  const TradeBoardView({super.key});

  @override
  ConsumerState<TradeBoardView> createState() => _TradeBoardViewState();
}

class _TradeBoardViewState extends ConsumerState<TradeBoardView>
    with AutomaticKeepAliveClientMixin {
  /// タブを切り替えても、読んだ件数とスクロール位置を残す
  @override
  bool get wantKeepAlive => true;

  /// 読む件数（「もっと見る」で増やす）
  int _limit = boardPageSize;

  /// 最後に読めた一覧。「もっと見る」で読み直している間に出しておく
  TradeBoard? _last;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final following = ref.watch(followingOshisProvider);
    final target = ref.watch(boardTargetProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: following.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('推しを読み込めませんでした: $e'),
            data: (oshis) => Row(
              children: [
                Expanded(
                  child: _OshiSelector(
                    oshis: oshis,
                    selected: target,
                    onChanged: (oshi) {
                      // 推しを変えたら、件数を最初に戻す
                      // （絞り込みの条件はプロバイダ側で外れる）
                      setState(() {
                        _limit = boardPageSize;
                        _last = null;
                      });
                      ref.read(boardTargetProvider.notifier).select(oshi);
                    },
                  ),
                ),
                if (target != null) _filterButton(target),
              ],
            ),
          ),
        ),
        if (target != null) _filterChips(),
        Expanded(child: _buildResults(target)),
      ],
    );
  }

  Widget _filterButton(OshiSummary target) {
    final count = ref.watch(boardFilterProvider).count;
    return IconButton(
      key: const Key('trade_board_filter'),
      tooltip: '絞り込み',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.filter_list),
      ),
      onPressed: () async {
        final result = await showBoardFilterSheet(
          context,
          target: target,
          initial: ref.read(boardFilterProvider),
        );
        if (result != null) ref.read(boardFilterProvider.notifier).set(result);
      },
    );
  }

  /// 指定している条件のチップ（× で外せる）
  Widget _filterChips() {
    final filter = ref.watch(boardFilterProvider);
    if (filter.isEmpty) return const SizedBox.shrink();
    final notifier = ref.read(boardFilterProvider.notifier);
    final goodsName = filter.goodsName ?? 'グッズ';
    final goods = filter.goodsId == null
        ? (filter.side == BoardSide.any ? null : '${filter.side.label}あり')
        : filter.side == BoardSide.any
        ? goodsName
        : '$goodsName（${filter.side.label}）';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (goods != null)
            InputChip(
              key: const Key('board_chip_goods'),
              label: Text(goods),
              onDeleted: () => notifier.set(filter.withoutGoods()),
            ),
          if (filter.tags.isNotEmpty)
            InputChip(
              key: const Key('board_chip_tags'),
              label: Text(
                [
                  for (final t in TradeTag.values)
                    if (filter.tags.contains(t)) t.label,
                ].join('・'),
              ),
              onDeleted: () => notifier.set(filter.withoutTags()),
            ),
          if (filter.performanceId != null)
            InputChip(
              key: const Key('board_chip_performance'),
              label: Text(
                '手渡し：${filter.performanceLabel ?? '公演'}',
                overflow: TextOverflow.ellipsis,
              ),
              onDeleted: () => notifier.set(filter.withoutPerformance()),
            ),
          TextButton(
            key: const Key('board_chip_clear'),
            onPressed: () => notifier.set(BoardFilter.none),
            child: const Text('条件をすべて外す'),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(OshiSummary? target) {
    if (target == null) {
      return const Center(child: Text('推しを選んでください'));
    }
    final board = ref.watch(
      tradeBoardProvider((kind: target.kind, id: target.id, limit: _limit)),
    );
    final all = ref.watch(allOshisProvider).value ?? const <OshiSummary>[];
    final uid = ref.watch(currentUidProvider);

    // 「もっと見る」で読み直している間は、前の一覧を出したままにする
    final loading = !board.hasValue && !board.hasError;
    if (board.hasValue) _last = board.value;
    final value = board.hasValue ? board.value : (loading ? _last : null);
    if (value == null) {
      return board.hasError
          ? Center(child: Text('投稿を読み込めませんでした: ${board.error}'))
          : const Center(child: CircularProgressIndicator());
    }
    if (value.posts.isEmpty) {
      return const Center(child: Text('募集中の投稿はまだありません'));
    }
    final filter = ref.watch(boardFilterProvider);
    final posts = value.posts.where(filter.matches).toList();
    return ListView(
      // 右下のボタンで最後の投稿が隠れないようにする
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        if (!filter.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              value.hasMore
                  ? '読み込んだ新しい${value.posts.length}件から絞り込んでいます。'
                        '古い投稿は「もっと見る」で読み込めます'
                  : '${value.posts.length}件から絞り込んでいます',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (posts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('条件に合う投稿はありません')),
          ),
        for (final p in posts)
          _BoardCard(post: p, all: all, isMine: p.uid == uid),
        if (value.hasMore)
          Center(
            child: TextButton(
              key: const Key('trade_board_more'),
              onPressed: loading
                  ? null
                  : () => setState(() => _limit += boardPageSize),
              child: Text(loading ? '読み込み中…' : 'もっと見る'),
            ),
          ),
      ],
    );
  }
}

/// フォロー中の推しから1つ選ぶ
class _OshiSelector extends StatelessWidget {
  const _OshiSelector({
    required this.oshis,
    required this.selected,
    required this.onChanged,
  });

  final List<OshiSummary> oshis;
  final OshiSummary? selected;
  final ValueChanged<OshiSummary?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (oshis.isEmpty) {
      return const Text('フォロー中の推しがいません。先に推しをフォローしてください');
    }
    // 承認などで中身が変わっても同じ推しとして扱えるよう、key で選ぶ
    final byKey = {for (final o in oshis) o.key: o};
    final selectedKey = byKey.containsKey(selected?.key) ? selected!.key : null;
    return DropdownButton<String>(
      key: const Key('trade_board_oshi'),
      isExpanded: true,
      value: selectedKey,
      hint: const Text('推しを選ぶ'),
      items: [
        for (final o in oshis)
          DropdownMenuItem(
            value: o.key,
            child: Text('${o.name}（${o.kind.label}）'),
          ),
      ],
      onChanged: (key) => onChanged(byKey[key]),
    );
  }
}

/// 掲示板の投稿1件（詳細画面は G-5-1 で作るため、まだタップできない）
class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.post,
    required this.all,
    required this.isMine,
  });

  final TradePost post;
  final List<OshiSummary> all;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targets = targetNames(post, all);
    return Card(
      key: Key('trade_board_post_${post.id}'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/trade/${post.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      post.displayName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 8),
                    const Chip(
                      label: Text('自分'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
              if (targets.isNotEmpty)
                Text(
                  targets,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 4),
              TradePostSummaryLines(post: post, showHandover: true),
            ],
          ),
        ),
      ),
    );
  }
}
