import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/live_memory.dart';
import '../../providers/memory_providers.dart';
import '../../utils/memory_album.dart';
import '../live_form/date_time_field.dart';

import 'memory_album_card.dart';

/// メモリー一覧（/memories）。参戦予定と参戦済み（アルバム）を縦に並べる
class MemoryListPage extends ConsumerWidget {
  const MemoryListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = ref.watch(memoryAlbumProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('メモリー'),
        automaticallyImplyLeading: false,
      ),
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
            const _Message(
              key: Key('memory_list_empty'),
              text: 'まだ記録がありません。\nライブの詳細の公演から「記録する」で残せます',
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
            Text(text, textAlign: TextAlign.center),
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
    final theme = Theme.of(context);
    Widget header(String text) => SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Text(text, style: theme.textTheme.titleMedium),
      ),
    );
    Widget none(String text) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverToBoxAdapter(child: Text(text)),
    );

    return CustomScrollView(
      key: const Key('memory_list'),
      slivers: [
        header('参戦予定'),
        if (album.upcoming.isEmpty)
          none('参戦予定の記録はありません')
        else
          SliverList.list(
            children: [
              for (final m in album.upcoming) _UpcomingTile(memory: m),
            ],
          ),
        header('参戦済み'),
        if (album.attended.isEmpty)
          none('参戦済みの記録はありません')
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisExtent: 240,
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
    return ListTile(
      key: Key('memory_list_upcoming_${memory.performanceId}'),
      leading: const Icon(Icons.event),
      title: Text(memory.liveTitle),
      subtitle: Text(
        [
          '${formatDateTime(memory.startAt)} 開演',
          memory.venue,
          if (seat != null) '座席：$seat',
        ].join('\n'),
      ),
      onTap: () => context.go('/memories/${memory.performanceId}'),
    );
  }
}

/// 参戦済みのカード（表紙・ライブ名・日付・会場）
// class _AlbumCard extends StatelessWidget {
//   const _AlbumCard({required this.memory});

//   final LiveMemory memory;

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     return Card(
//       key: Key('memory_list_attended_${memory.performanceId}'),
//       margin: EdgeInsets.zero,
//       clipBehavior: Clip.antiAlias,
//       child: InkWell(
//         onTap: () => context.go('/memories/${memory.performanceId}'),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             // TODO(M-5): images があれば1枚目を表紙にする
//             Expanded(
//               child: ColoredBox(
//                 color: theme.colorScheme.secondaryContainer,
//                 child: Icon(
//                   Icons.music_note,
//                   size: 48,
//                   color: theme.colorScheme.onSecondaryContainer,
//                 ),
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.all(8),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     memory.liveTitle,
//                     style: theme.textTheme.titleSmall,
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   const SizedBox(height: 2),
//                   Text(
//                     formatDateTime(memory.startAt),
//                     style: theme.textTheme.bodySmall,
//                   ),
//                   Text(
//                     memory.venue,
//                     style: theme.textTheme.bodySmall,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }