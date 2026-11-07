import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/oshi.dart';
import '../../providers/favorite_oshi_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import 'group_members_sheet.dart';
import 'oshi_list_tile.dart';

/// 推しページの「最推し」（見出しと白い箱。Fc 3.2）。
/// 最推しがいない（フォロー中でない・読み込み中を含む）ときは何も出さない。
/// グループなら、箱を押すとメンバーの一覧を出す
class FavoriteOshiCard extends ConsumerWidget {
  const FavoriteOshiCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oshi = ref.watch(favoriteOshiProvider);
    if (oshi == null) return const SizedBox.shrink();
    final isGroup = oshi.kind == OshiKind.group;
    final groupNames = groupNamesOf(
      oshi,
      groupNamesById(ref.watch(allOshisProvider).value ?? const []),
    );

    return Column(
      key: const Key('favorite_oshi_card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HakoSectionHeader('最推し'),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isGroup ? () => showGroupMembersSheet(context, oshi) : null,
          child: HakoBox(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                const Icon(Icons.star, size: 36, color: BrandColors.hall2),
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
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          HakoTagChip(oshi.kind.label),
                          HakoTagChip(oshi.genre.label),
                          if (groupNames.isNotEmpty)
                            HakoTagChip('所属：${groupNames.join('・')}'),
                          if (isGroup)
                            const HakoTagChip('メンバーを見る ›', link: true),
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