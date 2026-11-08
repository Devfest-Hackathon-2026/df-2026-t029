import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/oshi.dart';
import '../../providers/favorite_oshi_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import 'follow_actions.dart';
import 'oshi_list_tile.dart';
import 'oshi_color_sheet.dart';
// import 'group_members_sheet.dart';
import 'group_members_panel.dart';
import 'oshi_menu.dart';

/// 推しページに出す、フォロー中の推しの一覧。
/// グループ／個人の絞り込み（Fc 3.1）と、最推しの星（Fc 3.2）を持つ。
///
/// スクロールする親（ListView など）の中に置く前提で、自分ではスクロールしない。
class FollowingOshiList extends ConsumerStatefulWidget {
  const FollowingOshiList({super.key});

  @override
  ConsumerState<FollowingOshiList> createState() => _FollowingOshiListState();
}

class _FollowingOshiListState extends ConsumerState<FollowingOshiList> {
  /// 解除・最推しの処理中の推し（OshiSummary.key。== は全項目比較なので使わない）
  final Set<String> _busy = {};

  /// 絞り込み（null ならすべて）。覚えておかない（Fc 3.1）
  OshiKind? _kind;

  /// その場で開いているグループ（OshiSummary.key）。覚えておかない（Fc 4.1）
  final Set<String> _expanded = {};

  void _showError(String error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _unfollow(OshiSummary oshi) async {
    if (_busy.contains(oshi.key)) return;
    setState(() => _busy.add(oshi.key));
    final error = await runFollowAction(ref, oshi, follow: false);
    // State.context を使うので、State の mounted で確認する
    if (!mounted) return;
    setState(() => _busy.remove(oshi.key));
    if (error != null) _showError(error);
  }

  /// 最推しにする・外す（Fc 3.2）
  Future<void> _toggleFavorite(OshiSummary oshi, {required bool favorite}) async {
    if (_busy.contains(oshi.key)) return;
    setState(() => _busy.add(oshi.key));
    final error = await runFavoriteAction(ref, oshi, favorite: favorite);
    if (!mounted) return;
    setState(() => _busy.remove(oshi.key));
    if (error != null) _showError(error);
  }

  Widget _errorView() {
    return Padding(
      key: const Key('home_following_error'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Text('フォロー中の推しを読み込めませんでした', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('home_following_retry_button'),
            onPressed: () {
              ref.invalidate(allOshisProvider);
              ref.invalidate(followStateProvider);
            },
            child: const Text('もう一度読み込む'),
          ),
        ],
      ),
    );
  }

  /// フォロー中が1件以上のときの中身（案内・絞り込み・一覧）
  Widget _listView(List<OshiSummary> list) {
    final names = groupNamesById(
      ref.watch(allOshisProvider).value ?? const <OshiSummary>[],
    );
    final favoriteKey = ref.watch(favoriteOshiKeyProvider);
    final hasFavorite = ref.watch(favoriteOshiProvider) != null;
    final groups = list.where((o) => o.kind == OshiKind.group).length;
    final persons = list.length - groups;
    final kind = _kind;
    // 「すべて」のとき、所属グループのどれかをフォローしている個人は
    // 単独の行にせず、そのグループの ▼ の中に出す（Fd 5.4）
    final followedGroupIds = {
      for (final o in list)
        if (o.kind == OshiKind.group) o.id,
    };
    final shown = switch (kind) {
      null => [
        for (final o in list)
          if (o.kind == OshiKind.group ||
              !o.groupIds.any(followedGroupIds.contains))
            o,
      ],
      _ => list.where((o) => o.kind == kind).toList(),
    };
    // グループ ID → そのグループのメンバーのうちフォロー中の人数（Fd 5.4）
    int followedMembersOf(OshiSummary group) => list
        .where(
          (o) => o.kind == OshiKind.person && o.groupIds.contains(group.id),
        )
        .length;

    return Column(
      key: const Key('home_following_list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 最推しがいないときだけ案内する（読み込み中は出さない）
        if (favoriteKey.hasValue && !hasFavorite)
          Padding(
            key: const Key('oshi_favorite_hint'),
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              '☆を押すと最推しに、丸い札を押すと色を選べます',
              style: HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.5),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _KindChip(
                key: const Key('oshi_filter_all'),
                label: 'すべて（${list.length}）',
                selected: kind == null,
                onTap: () => setState(() => _kind = null),
              ),
              _KindChip(
                key: const Key('oshi_filter_group'),
                label: 'グループ（$groups）',
                selected: kind == OshiKind.group,
                onTap: () => setState(() => _kind = OshiKind.group),
              ),
              _KindChip(
                key: const Key('oshi_filter_person'),
                label: '個人（$persons）',
                selected: kind == OshiKind.person,
                onTap: () => setState(() => _kind = OshiKind.person),
              ),
            ],
          ),
        ),
        if (shown.isEmpty)
          Padding(
            key: const Key('oshi_filter_empty'),
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              kind == OshiKind.group
                  ? 'フォロー中のグループはありません'
                  : 'フォロー中の個人はいません',
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final oshi in shown) ...[
            OshiListTile(
              oshi: oshi,
              isFollowing: true,
              isBusy: _busy.contains(oshi.key),
              onFollow: () {},
              onUnfollow: () => _unfollow(oshi),
              // グループの行を押すと、その場でメンバーを開く・閉じる（Fc 4.1）
              onTap: oshi.kind == OshiKind.group
                  ? () => setState(() {
                      if (!_expanded.remove(oshi.key)) _expanded.add(oshi.key);
                    })
                  : null,
              membersExpanded: oshi.kind == OshiKind.group
                  ? _expanded.contains(oshi.key)
                  : null,
              groupNames: groupNamesOf(oshi, names),
              isFavorite: favoriteKey.value == oshi.key,
              onToggleFavorite: () => _toggleFavorite(
                oshi,
                favorite: favoriteKey.value != oshi.key,
              ),
              // 札を押すと色を選ぶ（Fc 5.3）
              onBadgeTap: () => showOshiColorSheet(context, oshi),
              // まとめてフォローと ⋮（Fd 5.1・5.3）
              showFollowAll: oshi.kind == OshiKind.group,
              menu: oshiMenuItems(
                context,
                oshi,
                isFollowing: true,
                onUnfollow: () => _unfollow(oshi),
              ),
              // フォロー中のメンバーの人数（0人なら出さない。Fd 5.4）
              extraChips: [
                if (oshi.kind == OshiKind.group && followedMembersOf(oshi) > 0)
                  'フォロー中のメンバー ${followedMembersOf(oshi)}人',
              ],
            ),
            if (_expanded.contains(oshi.key))
              GroupMembersPanel(
                group: oshi,
                showFollowAllButton: false,
                withActions: true,
              ),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final following = ref.watch(followingOshisProvider);

    // 再読み込み中（前の値がある読み込み中）は、前の値を出したままにする
    return switch (following) {
      AsyncError() => _errorView(),
      AsyncValue(value: final list?) when list.isEmpty => const Padding(
        key: Key('home_following_empty'),
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'まだフォローしている推しはいません。\n「推しを探す」からフォローしてみましょう',
          textAlign: TextAlign.center,
        ),
      ),
      AsyncValue(value: final list?) => _listView(list),
      _ => const Padding(
        key: Key('home_following_loading'),
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

/// 絞り込みのチップ（Fc 3.1）。選んでいるものは墨の地に紙の文字、
/// 選んでいないものは白の地に墨の文字。枠は墨 2px の丸
class _KindChip extends StatelessWidget {
  const _KindChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? BrandColors.ink : BrandColors.surface,
        shape: const StadiumBorder(
          side: BorderSide(color: BrandColors.ink, width: 2),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              label,
              style: HakoFonts.jp(
                size: 13,
                weight: FontWeight.w700,
                height: 1.3,
                color: selected ? BrandColors.paper : BrandColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}