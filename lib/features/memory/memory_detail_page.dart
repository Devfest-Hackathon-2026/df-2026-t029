import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/live_memory.dart';
import '../../providers/live_providers.dart';
import '../../providers/memory_providers.dart';
import '../live_form/date_time_field.dart';

/// 記録の詳細（/memories/:performanceId）
class MemoryDetailPage extends ConsumerWidget {
  const MemoryDetailPage({super.key, required this.performanceId});

  final String performanceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = ref.watch(memoryProvider(performanceId));
    final now = ref.watch(nowProvider);
    final found = memory.value != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('記録'),
        actions: [
          if (found)
            IconButton(
              key: const Key('memory_detail_edit_button'),
              tooltip: '編集',
              onPressed: () => context.go('/memories/$performanceId/edit'),
              icon: const Icon(Icons.edit),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (memory) {
          AsyncError() => const Center(
            key: Key('memory_detail_error'),
            child: Text('記録を読み込めませんでした'),
          ),
          AsyncData(value: final m?) => _DetailView(memory: m, now: now),
          AsyncData() => const Center(
            key: Key('memory_detail_not_found'),
            child: Text('この記録は見つかりませんでした'),
          ),
          _ => const Center(
            key: Key('memory_detail_loading'),
            child: CircularProgressIndicator(),
          ),
        },
      ),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({required this.memory, required this.now});

  final LiveMemory memory;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = memory;
    final attended = m.isAttended(now);
    final seat = m.seat;
    final impression = m.impression;
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);

    return ListView(
      key: const Key('memory_detail'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(m.liveTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('${formatDateTime(m.startAt)} 開演'),
        Text(m.venue),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            key: const Key('memory_detail_state'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: attended
                  ? theme.colorScheme.secondaryContainer
                  : theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              attended ? '参戦済み' : '参戦予定',
              style: theme.textTheme.labelSmall,
            ),
          ),
        ),
        // TODO(M-5): 写真
        _Section(
          title: '座席',
          child: Text(
            seat ?? '未入力',
            key: const Key('memory_detail_seat'),
            style: seat == null ? muted : null,
          ),
        ),
        _Section(
          title: 'セトリ',
          child: m.setlist.isEmpty
              ? Text('未入力', style: muted)
              : Column(
                  key: const Key('memory_detail_setlist'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, song) in m.setlist.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('${i + 1}. $song'),
                      ),
                  ],
                ),
        ),
        _Section(
          title: '感想',
          child: Text(
            impression ?? '未入力',
            key: const Key('memory_detail_impression'),
            style: impression == null ? muted : null,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}