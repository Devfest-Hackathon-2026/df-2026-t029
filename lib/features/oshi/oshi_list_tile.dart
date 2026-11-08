import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/oshi.dart';
import '../../providers/oshi_color_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../../providers/oshi_emoji_providers.dart';
import '../../providers/oshi_image_providers.dart';
import '../common/storage_image.dart';

/// グループの ID → グループ名（個人の行に「所属：◯◯」を出すのに使う）
Map<String, String> groupNamesById(List<OshiSummary> all) => {
  for (final o in all)
    if (o.kind == OshiKind.group) o.id: o.name,
};

/// 個人の所属グループの名前（見つからない ID は除く）
List<String> groupNamesOf(OshiSummary oshi, Map<String, String> names) => [
  for (final id in oshi.groupIds) ?names[id],
];

/// 推しの種別の札（Fc 4.3・5.3・add_I 3.1・3.1b）。
/// グループは墨の丸に白（色があれば枠をその色にする）、
/// 個人は白の丸に墨の枠（色があれば地をその色にする）。
/// 中身は 画像 → 絵文字 → 人・グループのアイコン の順に優先する
class OshiKindBadge extends ConsumerWidget {
  const OshiKindBadge({super.key, required this.oshi, this.size = 36});

  final OshiSummary oshi;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolveOshiColor(
      oshi,
      ref.watch(oshiColorsProvider).value ?? const {},
    );
    final emoji = resolveOshiEmoji(
      oshi,
      ref.watch(oshiEmojisProvider).value ?? const {},
    );
    final image = resolveOshiImage(
      oshi,
      ref.watch(oshiImagesProvider).value ?? const {},
    );
    final isGroup = oshi.kind == OshiKind.group;
    final background = isGroup ? BrandColors.ink : (color ?? BrandColors.surface);
    final border = Border.all(
      color: isGroup ? (color ?? BrandColors.ink) : BrandColors.ink,
      width: isGroup && color != null ? 3 : 2,
    );

    // 画像は丸く切り抜き、枠は画像の上に描く
    if (image != null) {
      return Semantics(
        label: oshi.kind.label,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: background),
          foregroundDecoration: BoxDecoration(
            shape: BoxShape.circle,
            border: border,
          ),
          child: ClipOval(child: StorageImage(path: image)),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        border: border,
      ),
      child: emoji != null
          ? Text(
              emoji,
              semanticsLabel: '${oshi.kind.label} $emoji',
              style: TextStyle(fontSize: size * 0.5, height: 1),
            )
          : Icon(
              isGroup ? Icons.groups : Icons.person,
              size: size * 0.56,
              color: isGroup
                  ? BrandColors.surface
                  : (color == null ? BrandColors.ink : onThemeColor(color)),
              semanticLabel: oshi.kind.label,
            ),
    );
  }
}

/// 検索結果・フォロー一覧・メンバー一覧の1行
///
/// 種別の札・申請中バッジ・フォロー／解除ボタンを出す。
/// 申請中の推しはフォローボタンを押せない。
/// [onTap] があれば行を押せる（グループの行で、メンバーを出すのに使う）。
/// [onToggleFavorite] があれば、フォローのボタンの左に最推しの星を出す（Fc 3.2）。
/// [onBadgeTap] があれば、札を押せる（色を選ぶ。Fc 5.3）。
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
    this.highlight = false,
    this.onBadgeTap,
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

  /// 名前を太字にする（推しを探すで、ヒットしたメンバー。Fc 4.3）
  final bool highlight;

  /// 札を押したとき（色を選ぶ。フォロー中の一覧だけで渡す。Fc 5.3）
  final VoidCallback? onBadgeTap;

  String get _keySuffix => '${oshi.kind.name}_${oshi.id}';

  @override
  Widget build(BuildContext context) {
    final isPending = !oshi.isApproved;
    final badge = OshiKindBadge(oshi: oshi);

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
            if (onBadgeTap == null)
              badge
            else
              Tooltip(
                message: '色・絵文字・記念日',
                child: InkWell(
                  key: ValueKey('oshi_color_button_$_keySuffix'),
                  customBorder: const CircleBorder(),
                  onTap: onBadgeTap,
                  child: badge,
                ),
              ),
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
                      size: 16,
                      height: 1.5,
                      weight: highlight ? FontWeight.w700 : FontWeight.w400,
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