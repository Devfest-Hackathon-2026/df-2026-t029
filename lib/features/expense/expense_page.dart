import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/expense.dart';
import '../../providers/expense_providers.dart';
import '../../providers/live_providers.dart';
import '../../utils/expense_summary.dart';
import '../common/empty_state.dart';
import '../live_form/live_draft_to_models.dart' show formatYen;
import '../travel/trip_sheet.dart';
import 'expense_sheets.dart';

/// 種類ごとの棒の色の濃さ（テーマの色を透かして分ける）
const _categoryAlpha = {
  ExpenseCategory.ticket: 1.0,
  ExpenseCategory.travel: 0.7,
  ExpenseCategory.goods: 0.45,
  ExpenseCategory.other: 0.25,
};

/// 種類ごとのアイコン
const _categoryIcon = {
  ExpenseCategory.ticket: Icons.confirmation_number,
  ExpenseCategory.travel: Icons.train,
  ExpenseCategory.goods: Icons.shopping_bag,
  ExpenseCategory.other: Icons.receipt_long,
};

/// 費用管理の画面（/expenses。H-2）
class ExpensePage extends ConsumerStatefulWidget {
  const ExpensePage({super.key});

  @override
  ConsumerState<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends ConsumerState<ExpensePage> {
  /// 表示している月（1日）
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  /// 出費の行を押したときに、出どころに合わせたシートを開く
  void _open(ExpenseItem item) {
    switch (item.source) {
      case ExpenseSource.ticket:
        final r = ref
            .read(myReceptionsProvider)
            .value
            ?.where((r) => r.id == item.sourceId)
            .firstOrNull;
        if (r != null) {
          showTicketCostSheet(
            context,
            reception: r,
            current: ref.read(myTicketCostsProvider).value?[item.sourceId],
          );
        }
      case ExpenseSource.trip:
        final p = ref
            .read(myPerformancesProvider)
            .value
            ?.where((p) => p.id == item.sourceId)
            .firstOrNull;
        if (p != null) {
          showTripSheet(
            context,
            performance: p,
            liveTitle: item.liveTitle ?? '',
          );
        }
      case ExpenseSource.manual:
        final e = ref
            .read(myExpensesProvider)
            .value
            ?.where((e) => e.id == item.sourceId)
            .firstOrNull;
        if (e != null) showManualExpenseSheet(context, existing: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(expenseItemsProvider);
    final budget = ref.watch(myBudgetProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('推し活費')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('expense_add_fab'),
        onPressed: () => showManualExpenseSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('出費を追加'),
      ),
      body: SafeArea(
        child: switch (items) {
          AsyncError() => const Center(
            key: Key('expense_error'),
            child: Text('出費を読み込めませんでした'),
          ),
          AsyncValue(value: final list?) => _content(
            summarizeMonth(list, _month.year, _month.month),
            budget,
          ),
          _ => const Center(
            key: Key('expense_loading'),
            child: CircularProgressIndicator(),
          ),
        },
      ),
    );
  }

  Widget _content(MonthSummary summary, int? budget) {
    return ListView(
      key: const Key('expense_list'),
      // 右下のボタンで最後の行が隠れないようにする
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        _MonthSwitcher(
          year: summary.year,
          month: summary.month,
          onPrev: () => _shift(-1),
          onNext: () => _shift(1),
        ),
        const SizedBox(height: 8),
        _TotalCard(total: summary.total, budget: budget),
        const SizedBox(height: 16),
        _CategoryBars(byCategory: summary.byCategory),
        const SizedBox(height: 8),
        const Divider(),
        if (summary.items.isEmpty)
          const EmptyState(
            key: Key('expense_empty'),
            icon: Icons.savings,
            title: 'この月の出費はまだありません',
          )
        else
          for (final item in summary.items)
            _ExpenseTile(item: item, onTap: () => _open(item)),
      ],
    );
  }
}

/// 月の切り替え（‹ 2026年11月 ›）
class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.year,
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final int year;
  final int month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: const Key('expense_prev_month'),
          tooltip: '前の月',
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          '$year年$month月',
          key: const Key('expense_month_label'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          key: const Key('expense_next_month'),
          tooltip: '次の月',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// 合計と予算（予算に対する割合の棒。超えたら error の色）
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.budget});

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

    return Card(
      key: const Key('expense_total_card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '¥${formatYen(total)}',
                  key: const Key('expense_total'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: over ? scheme.error : null,
                  ),
                ),
                if (b != null) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '/ 予算 ¥${formatYen(b)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ],
            ),
            if (ratio != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  key: const Key('expense_budget_bar'),
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('expense_budget_button'),
                onPressed: () => showBudgetSheet(context, current: b),
                child: Text(b == null ? '予算を決める' : '予算を変える'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 種類ごとの合計の横棒（いちばん大きい種類が幅いっぱい）
class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.byCategory});

  final Map<ExpenseCategory, int> byCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final max = byCategory.values.fold(0, (a, b) => a > b ? a : b);

    return Column(
      key: const Key('expense_category_bars'),
      children: [
        for (final c in ExpenseCategory.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(c.label, style: theme.textTheme.bodyMedium),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: max == 0 ? 0 : byCategory[c]! / max,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(
                            alpha: _categoryAlpha[c],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 88,
                  child: Text(
                    '¥${formatYen(byCategory[c]!)}',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 出費の1行
class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.item, required this.onTap});

  final ExpenseItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sub = [
      '${item.date.month}/${item.date.day}',
      ?item.liveTitle,
      ?item.detail,
    ].join('・');

    return ListTile(
      key: Key('expense_item_${item.source.name}_${item.sourceId}'),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: scheme.primary.withValues(alpha: 0.12),
        foregroundColor: scheme.primary,
        child: Icon(_categoryIcon[item.category], size: 20),
      ),
      title: Text(
        '${item.category.label}　${item.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(
        item.amountUnset ? '金額未設定' : '¥${formatYen(item.amount)}',
        style: item.amountUnset
            ? theme.textTheme.bodySmall?.copyWith(color: scheme.error)
            : theme.textTheme.titleSmall,
      ),
    );
  }
}