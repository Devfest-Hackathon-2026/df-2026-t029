import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/oshi.dart';
import 'group_members_panel.dart' show memberRequestPath;
import 'oshi_color_sheet.dart';
import 'oshi_list_tile.dart' show OshiMenuItem;

/// 推しの行の ⋮ のメニュー（Fd 5.3）。今ある操作だけを入れる。
/// 色・絵文字・記念日（いつも）→ メンバーを申請する（承認済みのグループ）→
/// フォローを外す（フォロー中）
List<OshiMenuItem> oshiMenuItems(
  BuildContext context,
  OshiSummary oshi, {
  required bool isFollowing,
  required VoidCallback onUnfollow,
}) => [
  (
    label: '色・絵文字・記念日',
    icon: Icons.palette_outlined,
    onSelected: () => showOshiColorSheet(context, oshi),
  ),
  if (oshi.kind == OshiKind.group && oshi.isApproved)
    (
      label: 'メンバーを申請する',
      icon: Icons.person_add_outlined,
      onSelected: () => context.push(memberRequestPath(oshi)),
    ),
  if (isFollowing)
    (
      label: 'フォローを外す',
      icon: Icons.person_remove_outlined,
      onSelected: onUnfollow,
    ),
];