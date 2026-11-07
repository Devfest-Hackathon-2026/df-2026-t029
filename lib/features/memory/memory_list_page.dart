import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/live_memory.dart';
import '../../providers/memory_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/memory_album.dart';
import '../live_form/date_time_field.dart';
import '../common/empty_state.dart';

import 'memory_album_card.dart';

/// メモリー一覧（/memories）。参戦予定と参戦済み（アルバム）を縦に並べる
class MemoryListPage extends ConsumerWidget {
  const MemoryListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = ref.watch(memoryAlbumProvider);
    return HakoPageScaffold(
      title: 'メモリー',
      body: SafeArea(
        child: switch (album) {
          AsyncError() => _Message(
            key: const Key('memory_list_error'),
            text: '記録を読み込めませんでした',
            action: OutlinedButton(
              key: const Key('memory_list_retry_button'),
              onPressed: () => ref.invalidate(myMemoriesProvider),
              child: const Text('もう一度読み込む'),
            ),
          ),
          AsyncData(value: MemoryAlbum(upcoming: [], attended: [])) =>
            const EmptyState(
              key: Key('memory_list_empty'),
              icon: Icons.photo_album_outlined,
              title: '参戦したライブを記録すると、ここに並びます',
              message: 'ライブの詳細の公演から「記録する」で残せます',
            ),
          AsyncData(:final value) => _AlbumView(album: value),
          _ => const Center(
            key: Key('memory_list_loading'),
            child: CircularProgressIndicator(),
          ),
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: HakoFonts.jp(
                size: 13,
                color: BrandColors.sub,
                height: 1.6,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}

class _AlbumView extends StatelessWidget {
  const _AlbumView({required this.album});

  final MemoryAlbum album;

  @override
  Widget build(BuildContext context) {
    final pad = HakoPageScaffold.padding(context);
    Widget header(String text) => SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: pad.left),
      sliver: SliverToBoxAdapter(child: HakoSectionHeader(text)),
    );
    Widget none(String text) => SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: pad.left, vertical: 8),
      sliver: SliverToBoxAdapter(
        child: Text(
          text,
          style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.6),
        ),
      ),
    );

    return CustomScrollView(
      key: const Key('memory_list'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(top: pad.top - 22 < 0 ? 0 : pad.top - 22),
        ),
        header('参戦予定'),
        if (album.upcoming.isEmpty)
          none('参戦予定の記録はありません')
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pad.left),
            sliver: SliverList.list(
              children: [
                for (final m in album.upcoming) _UpcomingTile(memory: m),
              ],
            ),
          ),
        header('参戦済み'),
        if (album.attended.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(
              key: Key('memory_list_attended_empty'),
              icon: Icons.photo_album_outlined,
              title: '参戦したライブを記録すると、ここに並びます',
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad.left, 8, pad.right, pad.bottom),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 190,
                // 文字を大きくしても下にはみ出さないよう、文字の分だけ高さを伸ばす
                mainAxisExtent:
                    150 + MediaQuery.textScalerOf(context).scale(80),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: album.attended.length,
              itemBuilder: (context, i) {
                final m = album.attended[i];
                return MemoryAlbumCard(
                  key: Key('memory_list_attended_${m.performanceId}'),
                  memory: m,
                  onTap: () => context.go('/memories/${m.performanceId}'),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// 参戦予定の1行
class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.memory});

  final LiveMemory memory;

  @override
  Widget build(BuildContext context) {
    final seat = memory.seat;
    return HakoRow(
      key: Key('memory_list_upcoming_${memory.performanceId}'),
      icon: Icons.calendar_today_outlined,
      title: memory.liveTitle,
      subs: [
        '${formatDateTime(memory.startAt)} 開演',
        memory.venue,
        if (seat != null) '座席：$seat',
      ],
      onTap: () => context.go('/memories/${memory.performanceId}'),
    );
  }
}
