import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/oshi.dart';
import '../../providers/oshi_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/oshi_search.dart';
import '../../providers/favorite_oshi_providers.dart';
import 'follow_actions.dart';
import 'oshi_list_tile.dart';
import 'oshi_menu.dart';

/// グループのメンバー（Fc 4.1）。承認済み（名前順）→ 申請中（名前順）。
/// 申請中のグループは、メンバーも申請中なので、申請中も含めて返す
List<OshiSummary> groupMembersOf(OshiSummary group, List<OshiSummary> all) {
  final allMembers = [
    for (final o in all)
      if (o.kind == OshiKind.person && o.groupIds.contains(group.id)) o,
  ];
  // searchOshis は空の検索語だと承認済みだけを返すので、申請中は自分で並べる
  final pending = [
    for (final o in allMembers)
      if (!o.isApproved) o,
  ]..sort((a, b) => a.name.compareTo(b.name));
  return [...searchOshis(allMembers, ''), ...pending];
}

/// このグループのメンバーを申請する画面のパス（このグループを所属に選んだ状態）
String memberRequestPath(OshiSummary group) => Uri(
  path: '/oshi/request',
  queryParameters: {'group': group.id},
).toString();

/// 「メンバー全員をフォロー（n人）」のボタン（Fc 4.2）。
/// 対象は、承認済みで、まだフォローしていないメンバー。
/// 0人なら「全員フォロー中」で押せない。承認済みのメンバーがいなければ何も出さない
class FollowAllMembersButton extends ConsumerStatefulWidget {
  const FollowAllMembersButton({super.key, required this.group});

  final OshiSummary group;

  @override
  ConsumerState<FollowAllMembersButton> createState() =>
      _FollowAllMembersButtonState();
}

class _FollowAllMembersButtonState
    extends ConsumerState<FollowAllMembersButton> {
  bool _running = false;

  /// 1回の書き込みでまとめてフォローする（Ff 2.2）。
  /// フォロー状態の購読が1回で変わるので、メンバーの行も一度に切り替わる
  Future<void> _followAll(List<OshiSummary> targets) async {
    if (_running) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _running = true);
    final message = await runFollowManyAction(ref, targets);
    if (!mounted) return;
    setState(() => _running = false);
    if (message == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allOshisProvider).value ?? const <OshiSummary>[];
    final followAsync = ref.watch(followStateProvider);
    final following = followAsync.value ?? FollowState.empty;
    final approved = [
      for (final m in groupMembersOf(widget.group, all))
        if (m.isApproved) m,
    ];
    if (approved.isEmpty) return const SizedBox.shrink();
    final targets = [
      for (final m in approved)
        if (!following.isFollowing(m)) m,
    ];
    final key = Key('group_follow_all_${widget.group.id}');
    if (targets.isEmpty) {
      return OutlinedButton.icon(
        key: key,
        onPressed: null,
        icon: const Icon(Icons.check, size: 18),
        label: const Text('全員フォロー中'),
      );
    }
    return FilledButton.icon(
      key: key,
      onPressed: _running || !followAsync.hasValue
          ? null
          : () => _followAll(targets),
      icon: const Icon(Icons.group_add_outlined, size: 18),
      label: Text(
        _running ? 'フォローしています…' : 'メンバーをまとめてフォロー（${targets.length}人）',
      ),
    );
  }
}

/// グループの行の下に開く、メンバーの一覧（Fc 4.1・Fd 5.2）。
/// 左に字下げし、左端に墨の縦線を引く。
/// 上から：全員フォロー（[showFollowAllButton]）→ メンバーの行 → 「メンバーを申請する」。
/// [withActions] なら、メンバーの行に ☆ と ⋮ を出す（推しページのフォロー中の一覧）
class GroupMembersPanel extends ConsumerStatefulWidget {
  const GroupMembersPanel({
    super.key,
    required this.group,
    this.highlightKeys = const {},
    this.showFollowAllButton = true,
    this.withActions = false,
  });

  final OshiSummary group;

  /// 名前を太字にするメンバー（推しを探すでヒットしたもの。Fc 4.3）
  final Set<String> highlightKeys;

  /// 上に「メンバーをまとめてフォロー」を出すか。
  /// グループの行に出している推しページでは false（Fd 5.2）
  final bool showFollowAllButton;

  /// メンバーの行に ☆ と ⋮ を出すか（Fd 5.2）
  final bool withActions;

  @override
  ConsumerState<GroupMembersPanel> createState() => _GroupMembersPanelState();
}

class _GroupMembersPanelState extends ConsumerState<GroupMembersPanel> {
  /// フォロー・解除・最推しの処理中の推し（OshiSummary.key）
  final Set<String> _busy = {};

  void _showError(String error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _toggleFollow(OshiSummary oshi, {required bool follow}) async {
    if (_busy.contains(oshi.key)) return;
    setState(() => _busy.add(oshi.key));
    final error = await runFollowAction(ref, oshi, follow: follow);
    if (!mounted) return;
    setState(() => _busy.remove(oshi.key));
    if (error != null) _showError(error);
  }

  /// 最推しにする・外す（Fd 5.2）。フォローしていないメンバーを最推しにするときは、
  /// 先にフォローする（失敗したら最推しにしない）
  Future<void> _toggleFavorite(
    OshiSummary oshi, {
    required bool favorite,
    required bool isFollowing,
  }) async {
    if (_busy.contains(oshi.key)) return;
    setState(() => _busy.add(oshi.key));
    String? error;
    if (favorite && !isFollowing) {
      error = await runFollowAction(ref, oshi, follow: true);
    }
    error ??= await runFavoriteAction(ref, oshi, favorite: favorite);
    if (!mounted) return;
    setState(() => _busy.remove(oshi.key));
    if (error != null) _showError(error);
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final all = ref.watch(allOshisProvider).value ?? const <OshiSummary>[];
    final followAsync = ref.watch(followStateProvider);
    final following = followAsync.value ?? FollowState.empty;
    final favoriteKey = ref.watch(favoriteOshiKeyProvider).value;
    final names = groupNamesById(all);
    final members = groupMembersOf(group, all);
    final muted = HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.6);

    return Padding(
      key: Key('group_members_panel_${group.id}'),
      padding: const EdgeInsets.only(left: 28, bottom: 8),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: BrandColors.ink, width: 2)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12, top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showFollowAllButton)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FollowAllMembersButton(group: group),
                ),
              if (members.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('まだメンバーが登録されていません', style: muted),
                )
              else
                for (final m in members)
                  OshiListTile(
                    oshi: m,
                    isFollowing: following.isFollowing(m),
                    isBusy: !followAsync.hasValue || _busy.contains(m.key),
                    onFollow: () => _toggleFollow(m, follow: true),
                    onUnfollow: () => _toggleFollow(m, follow: false),
                    groupNames: groupNamesOf(m, names),
                    highlight: widget.highlightKeys.contains(m.key),
                    isFavorite: favoriteKey == m.key,
                    // 申請中のメンバーは最推しにできない（フォローできないため）
                    onToggleFavorite: widget.withActions && m.isApproved
                        ? () => _toggleFavorite(
                            m,
                            favorite: favoriteKey != m.key,
                            isFollowing: following.isFollowing(m),
                          )
                        : null,
                    menu: widget.withActions
                        ? oshiMenuItems(
                            context,
                            m,
                            isFollowing: following.isFollowing(m),
                            onUnfollow: () => _toggleFollow(m, follow: false),
                          )
                        : const [],
                  ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: group.isApproved
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: Key('group_members_request_${group.id}'),
                          onPressed: () =>
                              context.push(memberRequestPath(group)),
                          icon: const Icon(Icons.person_add),
                          label: const Text('メンバーを申請する'),
                        ),
                      )
                    : Text('申請中のグループです。承認されるとメンバーを申請できます', style: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}