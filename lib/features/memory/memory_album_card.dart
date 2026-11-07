import 'package:flutter/material.dart';

import '../../models/live_memory.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import '../live_form/date_time_field.dart';

/// 参戦済みの記録のカード（メモリー一覧・ホームで使う）
class MemoryAlbumCard extends StatelessWidget {
  const MemoryAlbumCard({super.key, required this.memory, required this.onTap});

  final LiveMemory memory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.45);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TODO(M-5): images があれば1枚目を表紙にする
            Container(
              height: 88,
              decoration: const BoxDecoration(
                color: BrandColors.hall4,
                border: Border(
                  bottom: BorderSide(color: BrandColors.ink, width: 1.5),
                ),
              ),
              child: const ExcludeSemantics(
                child: Icon(
                  Icons.music_note_outlined,
                  size: 32,
                  color: BrandColors.ink,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory.liveTitle,
                      style: HakoFonts.jp(
                        size: 12,
                        weight: FontWeight.w700,
                        height: 1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(formatDateTime(memory.startAt), style: sub),
                    Text(
                      memory.venue,
                      style: sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
