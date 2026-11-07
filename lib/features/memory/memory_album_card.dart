import 'package:flutter/material.dart';

import '../../models/live_memory.dart';
import '../common/storage_image.dart';
import '../live_form/date_time_field.dart';

/// 参戦済みの記録のカード（メモリー一覧・ホームで使う）
class MemoryAlbumCard extends StatelessWidget {
  const MemoryAlbumCard({super.key, required this.memory, required this.onTap});

  final LiveMemory memory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 写真があれば1枚目を表紙にする。無ければ色付きの枠（仕様書 6.4）
            Expanded(
              child: memory.images.isEmpty
                  ? ColoredBox(
                      color: theme.colorScheme.secondaryContainer,
                      child: Icon(
                        Icons.music_note,
                        size: 48,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    )
                  : StorageImage(path: memory.images.first),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory.liveTitle,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDateTime(memory.startAt),
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    memory.venue,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}