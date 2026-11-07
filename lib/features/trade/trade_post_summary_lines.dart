import 'package:flutter/material.dart';

import '../../models/trade_post.dart';
import '../live_form/date_time_field.dart';
import 'trade_post_summary.dart';

/// 投稿の要約の行（タグ、譲、求、受け渡し方法、更新日時）。
/// 自分の投稿の一覧と掲示板で共通に使う
class TradePostSummaryLines extends StatelessWidget {
  const TradePostSummaryLines({
    super.key,
    required this.post,
    this.showHandover = false,
  });

  final TradePost post;

  /// 受け渡し方法の行を出すか（掲示板で出す）
  final bool showHandover;

  @override
  Widget build(BuildContext context) {
    final gives = giveSummary(post);
    final wants = wantSummary(post);
    final updatedAt = post.updatedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tagLine(post)),
        if (gives.isNotEmpty) Text('譲：$gives'),
        if (wants.isNotEmpty) Text('求：$wants'),
        if (post.isTextOnly) const Text('品目なし（自動のマッチングの対象外）'),
        if (showHandover)
          Text('受け渡し：${post.handover.map((h) => h.label).join('・')}'),
        const SizedBox(height: 4),
        Text(
          updatedAt == null ? '保存中…' : '更新：${formatDateTime(updatedAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
