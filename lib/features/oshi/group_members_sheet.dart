import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/oshi.dart';
import '../../providers/oshi_providers.dart';
import 'follow_actions.dart';
import 'group_members_panel.dart';
import 'oshi_list_tile.dart';

/// グループのメンバーの一覧を出すシート。メンバーをその場でフォローできる
/// （最推しの箱から開く。フォロー中の一覧・推しを探すは、その場で開く形。Fc 4.1）
Future<void> showGroupMembersSheet(BuildContext context, OshiSummary group) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // 外枠（左のタブ）ごと暗くする
    useRootNavigator: true,
    builder: (_) => _GroupMembersSheet(group: group),
  );
}

class _GroupMembersSheet extends ConsumerStatefulWidget {
  const _GroupMembersSheet({required this.group});

  final OshiSummary group;

  @override
  ConsumerState<_GroupMembersSheet> createState() => _GroupMembersSheetState();
}

class _GroupMembersSheetState extends ConsumerState<_GroupMembersSheet> {
  /// フォロー・解除の処理中の推し（OshiSummary.key）
  final Set<String> _busy = {};

  Future<void> _toggleFollow(OshiSummary oshi, {required bool follow}) async {
    if (_busy.contains(oshi.key)) return;
    setState(() => _busy.add(oshi.key));
    final error = await runFollowAction(ref, oshi, follow: follow);
    if (!mounted) return;
    setState(() => _busy.remove(oshi.key));
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  /// シートを閉じて、このグループを所属に選んだ申請画面を開く
  void _openMemberRequest() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(memberRequestPath(widget.group));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = widget.group;
    final all = ref.watch(allOshisProvider).value ?? const <OshiSummary>[];
    final followAsync = ref.watch(followStateProvider);
    final following = followAsync.value ?? FollowState.empty;
    final names = groupNamesById(all);
    final members = groupMembersOf(group, all);

    return Padding(
      key: Key('group_members_sheet_${group.id}'),
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(group.name, style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'メンバー ${members.length}人',
              style: theme.textTheme.bodySmall,
            ),
          ),
          // メンバー全員をフォロー（Fc 4.2）
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FollowAllMembersButton(group: group),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: members.isEmpty
                ? const Padding(
                    key: Key('group_members_empty'),
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'まだメンバーが登録されていません',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    key: const Key('group_members_list'),
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final m = members[i];
                      return OshiListTile(
                        oshi: m,
                        isFollowing: following.isFollowing(m),
                        isBusy: !followAsync.hasValue || _busy.contains(m.key),
                        onFollow: () => _toggleFollow(m, follow: true),
                        onUnfollow: () => _toggleFollow(m, follow: false),
                        groupNames: groupNamesOf(m, names),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: group.isApproved
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('group_members_request_button'),
                      onPressed: _openMemberRequest,
                      icon: const Icon(Icons.person_add),
                      label: const Text('メンバーを申請する'),
                    ),
                  )
                : const Text(
                    '申請中のグループです。承認されるとメンバーを申請できます',
                    key: Key('group_members_pending'),
                  ),
          ),
        ],
      ),
    );
  }
}
