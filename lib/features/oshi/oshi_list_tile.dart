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
import 'group_members_panel.dart' show FollowAllMembersButton;

/// グループの ID → グループ名（個人の行に「所属：◯◯」を出すのに使う）
Map<String, String> groupNamesById(List<OshiSummary> all) => {
  for (final o in all)
    if (o.kind == OshiKind.group) o.id: o.name,
};

/// 個人の所属グループの名前（見つからない ID は除く）
List<String> groupNamesOf(OshiSummary oshi, Map<String, String> names) => [
  for (final id in oshi.groupIds) ?names[id],
];

/// ⋮ のメニューの1項目（Fd 5.3）
typedef OshiMenuItem = ({String label, IconData icon, VoidCallback onSelected});

/// 行の幅がこれ未満なら、☆・ボタン類・⋮ を名前の下の行に並べる（Fd 5.1）。
/// 「メンバーをまとめてフォロー」がある行は横に長いので、広い幅でも下の行にする
const double _narrowTileWidth = 420;
const double _narrowTileWidthWithFollowAll = 760;

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
    final background = isGroup
        ? BrandColors.ink
        : (color ?? BrandColors.surface);
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

/// 検索結果・フォロー一覧・メンバー一覧の1行（Fd 5.1）
///
/// 左に札（グループで開閉できる形なら、その下に ▼／▲）。
/// 名前の上にジャンルのチップ、下に所属・申請中のチップ。
/// 右に ☆（[onToggleFavorite] があるとき）・フォローのボタン・
/// メンバーをまとめてフォロー（[showFollowAll] のグループ）・⋮（[menu] が空でないとき）。
/// 行の幅が 560 未満なら、右のものは名前の下の行に右寄せで並べる。
/// 申請中の推しはフォローボタンを押せない。
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
    this.showFollowAll = false,
    this.menu = const [],
    this.extraChips = const [],
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

  /// 星を押したとき。null なら星を出さない
  final VoidCallback? onToggleFavorite;

  /// グループの行をその場で開く形のとき、開いているか（Fc 4.1）。
  /// null なら今までどおり「メンバーを見る ›」（シートで開く）
  final bool? membersExpanded;

  /// 名前を太字にする（推しを探すで、ヒットしたメンバー。Fc 4.3）
  final bool highlight;

  /// 札を押したとき（色を選ぶ。フォロー中の一覧だけで渡す。Fc 5.3）
  final VoidCallback? onBadgeTap;

  /// グループの行に「メンバーをまとめてフォロー」を出すか（Fd 5.1）
  final bool showFollowAll;

  /// ⋮ のメニュー。空なら ⋮ を出さない（Fd 5.3）
  final List<OshiMenuItem> menu;

  /// 名前の下に足すチップの文言（フォロー中のメンバーの人数など。Fd 5.4）
  final List<String> extraChips;

  String get _keySuffix => '${oshi.kind.name}_${oshi.id}';

  @override
  Widget build(BuildContext context) {
    final isPending = !oshi.isApproved;
    final badge = OshiKindBadge(oshi: oshi);
    final canToggle =
        oshi.kind == OshiKind.group && onTap != null && membersExpanded != null;

    // 左：札（押せるなら色のシート）＋ グループなら ▼／▲
    final left = Column(
      mainAxisSize: MainAxisSize.min,
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
        // 開閉のボタン：直径 40 の丸（薄い地・墨 2px の枠）に大きな矢印（Fd 5.5）
        if (canToggle)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Tooltip(
              message: membersExpanded! ? 'メンバーを閉じる' : 'メンバーを開く',
              child: Material(
                color: BrandColors.tonal,
                shape: const CircleBorder(
                  side: BorderSide(color: BrandColors.ink, width: 2),
                ),
                child: InkWell(
                  key: ValueKey('oshi_members_toggle_$_keySuffix'),
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      membersExpanded! ? Icons.expand_less : Icons.expand_more,
                      size: 30,
                      color: BrandColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    // 名前の上下のチップ
    final lowerChips = <Widget>[
      if (groupNames.isNotEmpty)
        HakoTagChip(
          '所属：${groupNames.join('・')}',
          key: ValueKey('oshi_affiliation_$_keySuffix'),
        ),
      for (final c in extraChips) HakoTagChip(c),
      if (isPending)
        HakoTagChip(
          '申請中',
          key: ValueKey('oshi_pending_badge_$_keySuffix'),
          link: true,
        ),
      // シートで開く形のグループだけ、今までどおりのチップ
      if (onTap != null && membersExpanded == null)
        HakoTagChip(
          'メンバーを見る ›',
          key: ValueKey('oshi_members_label_$_keySuffix'),
          link: true,
        ),
    ];
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HakoTagChip(oshi.genre.label, key: ValueKey('oshi_genre_$_keySuffix')),
        const SizedBox(height: 4),
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
        if (lowerChips.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 4, children: lowerChips),
        ],
      ],
    );

    // 右：☆・フォロー・まとめてフォロー・⋮
    final actions = <Widget>[
      if (onToggleFavorite != null)
        IconButton(
          key: ValueKey('oshi_favorite_button_$_keySuffix'),
          tooltip: isFavorite ? '最推しを外す' : '最推しにする',
          onPressed: isBusy ? null : onToggleFavorite,
          icon: Icon(
            isFavorite ? Icons.star : Icons.star_border,
            color: isFavorite ? BrandColors.hall2 : BrandColors.ink,
          ),
        ),
      _buildButton(isPending),
      if (showFollowAll && oshi.kind == OshiKind.group)
        FollowAllMembersButton(group: oshi),
      if (menu.isNotEmpty)
        PopupMenuButton<int>(
          key: ValueKey('oshi_menu_button_$_keySuffix'),
          tooltip: 'その他',
          icon: const Icon(Icons.more_vert, color: BrandColors.ink),
          onSelected: (i) => menu[i].onSelected(),
          itemBuilder: (_) => [
            for (var i = 0; i < menu.length; i++)
              PopupMenuItem<int>(
                value: i,
                child: Row(
                  children: [
                    Icon(menu[i].icon, size: 20, color: BrandColors.ink),
                    const SizedBox(width: 12),
                    Text(menu[i].label),
                  ],
                ),
              ),
          ],
        ),
    ];

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final threshold = showFollowAll && oshi.kind == OshiKind.group
                ? _narrowTileWidthWithFollowAll
                : _narrowTileWidth;
            final narrow = constraints.maxWidth < threshold;
            if (!narrow) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  left,
                  const SizedBox(width: 12),
                  Expanded(child: info),
                  const SizedBox(width: 14),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        actions[i],
                      ],
                    ],
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                left,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      info,
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: actions,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
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
