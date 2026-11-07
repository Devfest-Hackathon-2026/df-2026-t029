import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/memory_providers.dart';
import '../memory/memory_album_card.dart';
import 'home_horizontal_list.dart';
import 'home_section_header.dart';

/// ホームに出す記録の最大数
const _maxMemories = 10;

/// ⑤ 最近の思い出（参戦済みの記録を新しい順に）
class HomeRecentMemories extends ConsumerWidget {
  const HomeRecentMemories({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = ref.watch(memoryAlbumProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: '最近の思い出',
          onSeeAll: () => context.go('/memories'),
        ),
        switch (album) {
          AsyncValue(value: final a?) when a.attended.isEmpty =>
            const HomeSectionMessage('参戦したライブを記録すると、ここに出ます'),
          AsyncValue(value: final a?) => HomeHorizontalList(
            key: const Key('home_recent_memories'),
            height: 220,
            itemWidth: 180,
            children: [
              for (final m in a.attended.take(_maxMemories))
                MemoryAlbumCard(
                  key: Key('home_recent_memory_${m.performanceId}'),
                  memory: m,
                  onTap: () => context.push('/memories/${m.performanceId}'),
                ),
            ],
          ),
          AsyncError() => const HomeSectionMessage('読み込めませんでした'),
          _ => const HomeSectionLoading(),
        },
      ],
    );
  }
}
