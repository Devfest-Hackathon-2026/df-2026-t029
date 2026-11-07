import 'package:flutter/material.dart';

import '../../models/oshi.dart';

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

  String get _keySuffix => '${oshi.kind.name}_${oshi.id}';

  @override
  Widget build(BuildContext context) {
    final isPending = !oshi.isApproved;
    final isGroup = oshi.kind == OshiKind.group;

    return ListTile(
      key: ValueKey('oshi_tile_$_keySuffix'),
      onTap: onTap,
      leading: Icon(isGroup ? Icons.groups : Icons.person),
      title: Text(oshi.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _Label(text: oshi.kind.label),
            _Label(text: oshi.genre.label),
            if (groupNames.isNotEmpty)
              _Label(
                key: ValueKey('oshi_affiliation_$_keySuffix'),
                text: '所属：${groupNames.join('・')}',
              ),
            if (isPending)
              _Label(
                key: ValueKey('oshi_pending_badge_$_keySuffix'),
                text: '申請中',
                highlight: true,
              ),
            if (onTap != null)
              _Label(
                key: ValueKey('oshi_members_label_$_keySuffix'),
                text: 'メンバーを見る ›',
                highlight: true,
              ),
          ],
        ),
      ),
      trailing: _buildButton(isPending),
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

class _Label extends StatelessWidget {
  const _Label({super.key, required this.text, this.highlight = false});

  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 強調はテーマの色を薄く透かした背景（Da-4 の締切の印と同じ）
    final bg = highlight
        ? scheme.primary.withValues(alpha: 0.12)
        : scheme.surfaceContainer;
    final fg = highlight ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: fg)),
    );
  }
}