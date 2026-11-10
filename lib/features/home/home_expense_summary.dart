import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/expense_providers.dart';
import '../../utils/expense_summary.dart';
import '../live_form/live_draft_to_models.dart' show formatYen;
import '../../theme/hako_app_widgets.dart';
import 'home_section_header.dart';

/// ホームの「今月の推し活費」（H-3）。今月の合計と予算に対する割合を出し、押すと費用管理へ
class HomeExpenseSummary extends ConsumerWidget {
  const HomeExpenseSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(expenseItemsProvider);
    final budget = ref.watch(myBudgetProvider).value;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: '今月の推し活費',
          onSeeAll: () => context.go('/expenses'),
        ),
        switch (items) {
          AsyncValue(value: final list?) => _Card(
            total: summarizeMonth(list, now.year, now.month).total,
            budget: budget,
          ),
          AsyncError() => const HomeSectionMessage('読み込めませんでした'),
          _ => const HomeSectionLoading(),
        },
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.total, required this.budget});

  final int total;
  final int? budget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = budget;
    final ratio = b == null || b == 0 ? null : total / b;
    final over = ratio != null && ratio > 1;
    final color = over ? scheme.error : scheme.primary;

    return InkWell(
      key: const Key('home_expense_summary'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go('/expenses'),
      child: HakoBox(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '¥${formatYen(total)}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: over ? scheme.error : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: b == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '/ 予算 ¥${formatYen(b)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
            if (ratio != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0, 1).toDouble(),
                  minHeight: 8,
                  color: color,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                over
                    ? '予算を ¥${formatYen(total - b!)} 超えています'
                    : '予算の ${(ratio * 100).round()}%',
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
