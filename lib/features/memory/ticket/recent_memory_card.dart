import 'package:flutter/material.dart';

import '../../../models/live_memory.dart';
import '../../../theme/brand_colors.dart';
import '../../../theme/hako_app_widgets.dart';
import '../../../theme/hako_fonts.dart';
import '../../../utils/memory_ticket.dart';
import '../../common/storage_image.dart';
import '../../live_form/date_time_field.dart';
import 'memory_progress.dart';

/// メモリー一覧の「新しい記録」の大きいカード（計画書 4.9。見本の `.draft`）。
/// 上に写真4枚の帯（無ければ緑の地）、下に札・ライブ名・日時と会場・進み具合
class RecentMemoryCard extends StatelessWidget {
  const RecentMemoryCard({
    super.key,
    required this.memory,
    required this.onTap,
  });

  final LiveMemory memory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = memory;
    final photos = m.images.take(4).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: BrandColors.ink, offset: Offset(4, 4)),
          ],
        ),
        child: Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: BrandColors.ink, width: 2),
          ),
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 64,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: BrandColors.ink, width: 2),
                    ),
                  ),
                  child: photos.isEmpty
                      ? ColoredBox(
                          color: BrandColors.hall4Soft,
                          child: Center(
                            child: Text(
                              '写真は、これから入れます',
                              style: HakoFonts.jp(
                                size: 13,
                                weight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            for (var i = 0; i < 4; i++)
                              Expanded(
                                child: i < photos.length
                                    ? ClipRect(
                                        child: StorageImage(path: photos[i]),
                                      )
                                    : const ColoredBox(
                                        color: Color(0xFFD8D2BF),
                                        child: SizedBox.expand(),
                                      ),
                              ),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const HakoTagChip('参戦済み'),
                      const SizedBox(height: 6),
                      Text(
                        m.liveTitle,
                        style: HakoFonts.jp(
                          size: 15,
                          weight: FontWeight.w700,
                          height: 1.45,
                        ),
                      ),
                      Text(
                        '${formatDateTime(m.startAt)} ・ ${m.venue}',
                        style: HakoFonts.jp(
                          size: 13,
                          color: BrandColors.sub,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      MemoryProgressBar(done: memoryProgress(m)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'チケットを開いて、セトリと感想を書く',
                              style: HakoFonts.jp(
                                size: 13,
                                weight: FontWeight.w700,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
