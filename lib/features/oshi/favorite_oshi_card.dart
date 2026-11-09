import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/favorite_oshi_providers.dart';
import '../../providers/oshi_providers.dart';
// import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../../models/oshi_days.dart';
import '../../providers/live_providers.dart';
import '../../providers/oshi_days_providers.dart';
import 'package:go_router/go_router.dart';

import 'oshi_detail_page.dart' show oshiPagePath;
import 'oshi_list_tile.dart';

/// 推しページの「最推し」（見出しと白い箱。Fc 3.2）。
/// 最推しがいない（フォロー中でない・読み込み中を含む）ときは何も出さない。
/// 箱を押すと推しのページ（add_P 5.2）
class FavoriteOshiCard extends ConsumerWidget {
  const FavoriteOshiCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oshi = ref.watch(favoriteOshiProvider);
    if (oshi == null) return const SizedBox.shrink();
    final groupNames = groupNamesOf(
      oshi,
      groupNamesById(ref.watch(allOshisProvider).value ?? const []),
    );
    // 推して◯日（add_O 3.2）
    final start = oshiStartDateOf(
      oshi,
      ref.watch(oshiDaysProvider).value ?? OshiDays.empty,
    );
    final dayCount = start == null
        ? null
        : oshiDayCount(start, ref.watch(nowProvider));

    return Column(
      key: const Key('favorite_oshi_card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HakoSectionHeader('最推し'),
        const HakoHint('いちばん応援している推しです。', key: Key('hint_oshi_favorite')),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push(oshiPagePath(oshi)),
          child: HakoBox(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                OshiKindBadge(oshi: oshi, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        oshi.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: HakoFonts.jp(
                          size: 20,
                          weight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      if (dayCount != null)
                        Text(
                          '推して$dayCount日',
                          key: const Key('favorite_oshi_day_count'),
                          style: HakoFonts.jp(
                            size: 14,
                            weight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          HakoTagChip(oshi.kind.label),
                          HakoTagChip(oshi.genre.label),
                          if (groupNames.isNotEmpty)
                            HakoTagChip('所属：${groupNames.join('・')}'),
                          const HakoTagChip('推しのページ ›', link: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
