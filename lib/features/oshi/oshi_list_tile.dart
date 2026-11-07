import 'package:flutter/material.dart';

import '../../models/oshi.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';

/// グループの ID → グループ名（個人の行に「所属：◯◯」を出すのに使う）
Map<String, String> groupNamesById(List<OshiSummary> all) => {
  for (final o in all)
    if (o.kind == OshiKind.group) o.id: o.name,
};

/// 個人の所属グループの名前（見つからない ID は除く）
List<String> groupNamesOf(OshiSummary oshi, Map<String, String> names) => [
  for (final id in oshi.groupIds) ?names[id],
];

/// 検索結果・フォロー一覧・メンバー一覧の1行
///
/// 種別ラベル・申請中バッジ・フォロー／解除ボタンを出す。
/// 申請中の推しはフォローボタンを押せない。
/// [onTap] があれば行を押せる（グループの行で、メンバーの一覧を出すのに使う）。
/// [onToggleFavorite] があれば、フォローのボタンの左に最推しの星を出す（Fc 3.2）。
class OshiListTile extends StatelessWidget {
  const OshiListTile({
    super.key,
    required this.oshi,
    required this.isFollowing,
    required this.isBusy,
    required this.onFollow,
    required this.onUnfollow,
    this.onTap,
    this.groupNames = const [],
    this.isFavorite = false,
    this.onToggleFavorite,
    this.membersExpanded,
  });

  final OshiSummary oshi;
  final bool isFollowing;

  /// フォロー・解除の処理中なら true（ボタンを押せなくする）
  final bool isBusy;
  final VoidCallback onFollow;
  final VoidCallback onUnfollow;

  /// 行を押したときの動き（グループの行だけに渡す）
  final VoidCallback? onTap;

  /// 所属グループの名前（個人の行だけ）。「所属：◯◯」のラベルで出す
  final List<String> groupNames;

  /// 最推しか（[onToggleFavorite] があるときだけ使う）
  final bool isFavorite;

  /// 星を押したとき。null なら星を出さない（フォロー中の一覧だけで渡す）
  final VoidCallback? onToggleFavorite;

  /// グループの行をその場で開く形のとき、開いているか（Fc 4.1）。
  /// null なら今までどおり「メンバーを見る ›」（シートで開く）
  final bool? membersExpanded;

  String get _keySuffix => '${oshi.kind.name}_${oshi.id}';

  @override
  Widget build(BuildContext context) {
    final isPending = !oshi.isApproved;
    final isGroup = oshi.kind == OshiKind.group;

    return InkWell(
      key: ValueKey('oshi_tile_$_keySuffix'),
      onTap: onTap,
      overlayColor: WidgetStatePropertyAll(
        BrandColors.ink.withValues(alpha: 0.10),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: BrandColors.rowLine, width: 1.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isGroup ? Icons.group_outlined : Icons.person_outline,
                size: 28,
                color: BrandColors.ink,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    oshi.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HakoFonts.jp(size: 16, height: 1.5),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      HakoTagChip(oshi.kind.label),
                      HakoTagChip(oshi.genre.label),
                      if (groupNames.isNotEmpty)
                        HakoTagChip(
                          '所属：${groupNames.join('・')}',
                          key: ValueKey('oshi_affiliation_$_keySuffix'),
                        ),
                      if (isPending)
                        HakoTagChip(
                          '申請中',
                          key: ValueKey('oshi_pending_badge_$_keySuffix'),
                          link: true,
                        ),
                      if (onTap != null)
                        HakoTagChip(
                          switch (membersExpanded) {
                            true => 'メンバー ▲',
                            false => 'メンバー ▼',
                            null => 'メンバーを見る ›',
                          },
                          key: ValueKey('oshi_members_label_$_keySuffix'),
                          link: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            if (onToggleFavorite != null) ...[
              IconButton(
                key: ValueKey('oshi_favorite_button_$_keySuffix'),
                tooltip: isFavorite ? '最推しを外す' : '最推しにする',
                onPressed: isBusy ? null : onToggleFavorite,
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite ? BrandColors.hall2 : BrandColors.ink,
                ),
              ),
              const SizedBox(width: 4),
            ],
            _buildButton(isPending),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(bool isPending) {
    // フォロー中を先に判定する。フォロー後に申請中へ戻された推しでも解除できるように
    if (isFollowing) {
      return OutlinedButton(
        key: ValueKey('oshi_unfollow_button_$_keySuffix'),
        onPressed: isBusy ? null : onUnfollow,
        child: const Text('フォロー中'),
      );
    }
    if (isPending) {
      return OutlinedButton(
        key: ValueKey('oshi_follow_button_$_keySuffix'),
        onPressed: null,
        child: const Text('申請中'),
      );
    }
    return FilledButton(
      key: ValueKey('oshi_follow_button_$_keySuffix'),
      onPressed: isBusy ? null : onFollow,
      child: const Text('フォロー'),
    );
  }
}