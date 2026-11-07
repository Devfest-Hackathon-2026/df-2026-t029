import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/live_memory.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../../providers/live_providers.dart';
import '../../providers/memory_providers.dart';
import '../common/photo_grid.dart';
import '../live_form/date_time_field.dart';

/// 記録の詳細（/memories/:performanceId）
class MemoryDetailPage extends ConsumerWidget {
  const MemoryDetailPage({super.key, required this.performanceId});

  final String performanceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = ref.watch(memoryProvider(performanceId));
    final now = ref.watch(nowProvider);
    return HakoPageScaffold(
      title: '記録',
      showBack: true,
      backFallback: '/memories',
      body: SafeArea(
        child: switch (memory) {
          AsyncError() => const HakoEmpty(
            '記録を読み込めませんでした',
            key: Key('memory_detail_error'),
          ),
          AsyncData(value: final m?) => _DetailView(
            memory: m,
            now: now,
            onEdit: () => context.go('/memories/$performanceId/edit'),
          ),
          AsyncData() => const HakoEmpty(
            'この記録は見つかりませんでした',
            key: Key('memory_detail_not_found'),
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
  const _DetailView({
    required this.memory,
    required this.now,
    required this.onEdit,
  });

  final LiveMemory memory;
  final VoidCallback onEdit;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final m = memory;
    final attended = m.isAttended(now);
    final seat = m.seat;
    final impression = m.impression;
    final muted = HakoFonts.jp(size: 15, color: BrandColors.sub, height: 1.6);

    return ListView(
      key: const Key('memory_detail'),
      padding: HakoPageScaffold.padding(context),
      children: [
        Text(
          m.liveTitle,
          style: HakoFonts.jp(size: 20, weight: FontWeight.w700, height: 1.4),
        ),
        const SizedBox(height: 4),
        Text(
          '${formatDateTime(m.startAt)} 開演',
          style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.5),
        ),
        Text(
          m.venue,
          style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            HakoTagChip(
              attended ? '参戦済み' : '参戦予定',
              key: const Key('memory_detail_state'),
            ),
            OutlinedButton.icon(
              key: const Key('memory_detail_edit_button'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('編集'),
            ),
          ],
        ),
        // 写真は、あるときだけ出す（M-5 仕様書 6.3）
        if (m.images.isNotEmpty)
          _Section(
            title: '写真',
            child: PhotoGrid(
              key: const Key('memory_detail_photos'),
              paths: m.images,
            ),
          ),
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
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [HakoSectionHeader(title), child],
      ),
    );
  }
}
