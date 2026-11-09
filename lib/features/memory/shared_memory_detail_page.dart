import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/public_memory.dart';
import '../../providers/oshi_providers.dart';
import '../../providers/public_memory_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../common/photo_grid.dart';
import '../common/user_avatar.dart';
import '../live_form/date_time_field.dart';

/// 公開メモリーの詳細（/shared-memories/:id。add_K 6.3）。読むだけ
class SharedMemoryDetailPage extends ConsumerWidget {
  const SharedMemoryDetailPage({super.key, required this.id});

  /// 公開メモリーの ID（uid_performanceId）
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = ref.watch(publicMemoryProvider(id));
    final uid = ref.watch(currentUidProvider);
    return HakoPageScaffold(
      title: 'みんなのメモリー',
      showBack: true,
      backFallback: '/memories',
      body: SafeArea(
        child: switch (memory) {
          AsyncError() => const HakoEmpty(
            'メモリーを読み込めませんでした',
            key: Key('shared_memory_error'),
          ),
          AsyncData(value: final m?) => _DetailView(
            memory: m,
            isMine: m.uid == uid,
          ),
          AsyncData() => const HakoEmpty(
            'このメモリーは公開されていません',
            key: Key('shared_memory_not_found'),
          ),
          _ => const Center(
            key: Key('shared_memory_loading'),
            child: CircularProgressIndicator(),
          ),
        },
      ),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({required this.memory, required this.isMine});

  final PublicMemory memory;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final m = memory;
    final seat = m.seat;
    final impression = m.impression;
    final sub = HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.5);

    return ListView(
      key: const Key('shared_memory_detail'),
      padding: HakoPageScaffold.padding(context),
      children: [
        // 名前の行
        Row(
          children: [
            UserAvatar(uid: m.uid, name: m.displayName),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                m.displayName,
                style: Theme.of(context).textTheme.titleSmall,
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
        const SizedBox(height: 12),
        // ライブ名（押すとライブ詳細）・日時・会場
        InkWell(
          key: const Key('shared_memory_live_link'),
          onTap: () => context.push('/lives/${m.liveId}'),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  m.liveTitle,
                  style: HakoFonts.jp(
                    size: 20,
                    weight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: BrandColors.ink),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text('${formatDateTime(m.startAt)} 開演', style: sub),
        if (m.venue.isNotEmpty) Text(m.venue, style: sub),
        // 座席（公開されているときだけ）
        if (seat != null) _Section(title: '座席', child: Text(seat)),
        // 写真（あるときだけ）
        if (m.images.isNotEmpty)
          _Section(
            title: '写真',
            child: PhotoGrid(
              key: const Key('shared_memory_photos'),
              paths: m.images,
            ),
          ),
        // セトリ（あるときだけ）
        if (m.setlist.isNotEmpty)
          _Section(
            title: 'セトリ',
            child: Column(
              key: const Key('shared_memory_setlist'),
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
        // 感想（あるときだけ）
        if (impression != null)
          _Section(
            title: '感想',
            child: Text(impression, key: const Key('shared_memory_impression')),
          ),
        // 自分の公開メモリーなら、自分の記録へ
        if (isMine)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('shared_memory_open_mine'),
                onPressed: () => context.go('/memories/${m.performanceId}'),
                icon: const Icon(Icons.photo_album_outlined),
                label: const Text('自分のメモリーを開く'),
              ),
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
