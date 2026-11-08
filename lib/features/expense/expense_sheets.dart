import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/expense.dart';
import '../../models/live.dart';
import '../../models/reception.dart';
import '../../providers/expense_providers.dart';
import '../../providers/live_providers.dart';
import '../../providers/oshi_providers.dart';
import '../live_form/live_draft_to_models.dart' show formatYen;

/// 下から出すシートの共通の開き方（外枠ごと暗くし、キーボードで隠れないようにする）
Future<void> _showSheet(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

/// 金額の欄の共通の飾り
InputDecoration _yenDecoration(String label) => InputDecoration(
  labelText: label,
  prefixText: '¥ ',
  border: const OutlineInputBorder(),
);

final _digitsOnly = [FilteringTextInputFormatter.digitsOnly];

// ---------------------------------------------------------------
// 手入力の出費（追加・編集・削除）
// ---------------------------------------------------------------

/// 手入力の出費のシート。[existing] があれば編集（削除もできる）
Future<void> showManualExpenseSheet(
  BuildContext context, {
  Expense? existing,
}) => _showSheet(context, _ManualExpenseForm(existing: existing));

class _ManualExpenseForm extends ConsumerStatefulWidget {
  const _ManualExpenseForm({this.existing});

  final Expense? existing;

  @override
  ConsumerState<_ManualExpenseForm> createState() => _ManualExpenseFormState();
}

class _ManualExpenseFormState extends ConsumerState<_ManualExpenseForm> {
  late ExpenseCategory _category =
      widget.existing?.category ?? ExpenseCategory.goods;
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _amount = TextEditingController(
    text: widget.existing?.amount.toString() ?? '',
  );
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  late String? _liveId = widget.existing?.liveId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save(List<Live> lives) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final title = _title.text.trim();
    final amount = int.tryParse(_amount.text.trim());
    if (title.isEmpty) {
      setState(() => _error = '内容を入力してください');
      return;
    }
    if (amount == null || amount < 1 || amount > Expense.maxAmount) {
      setState(() => _error = '金額は1〜${formatYen(Expense.maxAmount)}円で入力してください');
      return;
    }
    final live = lives.where((l) => l.id == _liveId).firstOrNull;
    final expense = Expense(
      id: widget.existing?.id,
      category: _category,
      title: title,
      amount: amount,
      date: _date,
      liveId: live?.id,
      liveTitle: live?.title,
      createdAt: widget.existing?.createdAt,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(expenseRepositoryProvider);
      if (expense.id == null) {
        await repo.addExpense(uid, expense);
      } else {
        await repo.updateExpense(uid, expense);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存できませんでした: $e';
        });
      }
    }
  }

  Future<void> _delete() async {
    final uid = ref.read(currentUidProvider);
    final id = widget.existing?.id;
    if (uid == null || id == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(expenseRepositoryProvider).deleteExpense(uid, id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '削除できませんでした: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lives = ref.watch(myLivesProvider).value ?? const <Live>[];
    // 選んでいたライブが一覧から外れていたら、「なし」として扱う
    final liveId = lives.any((l) => l.id == _liveId) ? _liveId : null;

    return Column(
      key: const Key('manual_expense_sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.existing == null ? '出費を追加' : '出費を編集',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            for (final c in ExpenseCategory.manual)
              ChoiceChip(
                key: Key('expense_category_${c.code}'),
                label: Text(c.label),
                selected: _category == c,
                onSelected: _saving
                    ? null
                    : (_) => setState(() => _category = c),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('expense_title_field'),
          controller: _title,
          enabled: !_saving,
          maxLength: Expense.maxTitleLength,
          decoration: const InputDecoration(
            labelText: '内容（例：TOUR グッズ、ペンライト）',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('expense_amount_field'),
          controller: _amount,
          enabled: !_saving,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
          decoration: _yenDecoration('金額'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('expense_date_button'),
          onPressed: _saving ? null : _pickDate,
          icon: const Icon(Icons.calendar_today),
          label: Text('日付：${_date.year}/${_date.month}/${_date.day}'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          key: const Key('expense_live_field'),
          initialValue: liveId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'ライブ（任意）',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('なし')),
            for (final l in lives)
              if (l.id != null)
                DropdownMenuItem<String?>(
                  value: l.id,
                  child: Text(l.title, overflow: TextOverflow.ellipsis),
                ),
          ],
          onChanged: _saving ? null : (v) => setState(() => _liveId = v),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('expense_save_button'),
          onPressed: _saving ? null : () => _save(lives),
          child: Text(_saving ? '保存中…' : '保存'),
        ),
        if (widget.existing != null) ...[
          const SizedBox(height: 8),
          TextButton(
            key: const Key('expense_delete_button'),
            onPressed: _saving ? null : _delete,
            child: const Text('この出費を削除'),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------
// チケット代（席種と枚数）
// ---------------------------------------------------------------

/// チケット代のシート。[current] は今の設定（無ければ、最初の席種 × 1枚で開く）
Future<void> showTicketCostSheet(
  BuildContext context, {
  required Reception reception,
  TicketCost? current,
}) => _showSheet(
  context,
  _TicketCostForm(reception: reception, current: current),
);

class _TicketCostForm extends ConsumerStatefulWidget {
  const _TicketCostForm({required this.reception, this.current});

  final Reception reception;
  final TicketCost? current;

  @override
  ConsumerState<_TicketCostForm> createState() => _TicketCostFormState();
}

class _TicketCostFormState extends ConsumerState<_TicketCostForm> {
  List<Price> get _prices => widget.reception.prices;

  /// 選んだ席種（受付の料金の番号）。料金が無い受付では使わない
  late int _priceIndex = () {
    final i = _prices.indexWhere((p) => p.seat == widget.current?.seat);
    return i < 0 ? 0 : i;
  }();

  /// 料金が無い受付のときだけ使う欄
  late final _seat = TextEditingController(text: widget.current?.seat ?? '');
  late final _unitPrice = TextEditingController(
    text: widget.current?.unitPrice.toString() ?? '',
  );

  late int _count = widget.current?.count ?? 1;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _seat.dispose();
    _unitPrice.dispose();
    super.dispose();
  }

  /// 今の入力での (席種, 1枚の料金)。料金が読めなければ null
  (String, int)? get _selected {
    if (_prices.isNotEmpty) {
      final p = _prices[_priceIndex];
      return (p.seat, p.amount);
    }
    final price = int.tryParse(_unitPrice.text.trim());
    if (price == null || price > Expense.maxAmount) return null;
    final seat = _seat.text.trim();
    return (seat.isEmpty ? 'チケット' : seat, price);
  }

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    final id = widget.reception.id;
    final selected = _selected;
    if (uid == null || id == null) return;
    if (selected == null) {
      setState(() => _error = '1枚の料金を入力してください');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(expenseRepositoryProvider)
          .saveTicketCost(
            uid,
            TicketCost(
              receptionId: id,
              seat: selected.$1,
              unitPrice: selected.$2,
              count: _count,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存できませんでした: $e';
        });
      }
    }
  }

  Future<void> _reset() async {
    final uid = ref.read(currentUidProvider);
    final id = widget.reception.id;
    if (uid == null || id == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(expenseRepositoryProvider).deleteTicketCost(uid, id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '元に戻せませんでした: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selected;
    final total = selected == null ? null : selected.$2 * _count;

    return Column(
      key: const Key('ticket_cost_sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('チケット代', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(widget.reception.name, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        if (_prices.isNotEmpty)
          DropdownButtonFormField<int>(
            key: const Key('ticket_cost_seat_field'),
            initialValue: _priceIndex,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '席種',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final (i, p) in _prices.indexed)
                DropdownMenuItem(
                  value: i,
                  child: Text('${p.seat}　¥${formatYen(p.amount)}'),
                ),
            ],
            onChanged: _saving
                ? null
                : (i) => setState(() => _priceIndex = i ?? 0),
          )
        else ...[
          TextField(
            key: const Key('ticket_cost_seat_text_field'),
            controller: _seat,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: '席種（任意）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('ticket_cost_price_field'),
            controller: _unitPrice,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            inputFormatters: _digitsOnly,
            decoration: _yenDecoration('1枚の料金'),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: const Key('ticket_cost_count_field'),
          initialValue: _count,
          decoration: const InputDecoration(
            labelText: '枚数',
            border: OutlineInputBorder(),
          ),
          items: [
            for (var n = 1; n <= TicketCost.maxCount; n++)
              DropdownMenuItem(value: n, child: Text('$n枚')),
          ],
          onChanged: _saving ? null : (n) => setState(() => _count = n ?? 1),
        ),
        const SizedBox(height: 12),
        Text(
          total == null ? '合計：—' : '合計：¥${formatYen(total)}',
          style: theme.textTheme.titleMedium,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('ticket_cost_save_button'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中…' : '保存'),
        ),
        if (widget.current != null) ...[
          const SizedBox(height: 8),
          TextButton(
            key: const Key('ticket_cost_reset_button'),
            onPressed: _saving ? null : _reset,
            child: const Text('最初の席種 × 1枚に戻す'),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------
// 予算
// ---------------------------------------------------------------

/// 1か月の予算のシート。[current] は今の予算（未設定なら null）
Future<void> showBudgetSheet(BuildContext context, {int? current}) =>
    _showSheet(context, _BudgetForm(current: current));

class _BudgetForm extends ConsumerStatefulWidget {
  const _BudgetForm({this.current});

  final int? current;

  @override
  ConsumerState<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends ConsumerState<_BudgetForm> {
  late final _amount = TextEditingController(
    text: widget.current?.toString() ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save(int? monthly) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(expenseRepositoryProvider).saveBudget(uid, monthly);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存できませんでした: $e';
        });
      }
    }
  }

  void _submit() {
    final value = int.tryParse(_amount.text.trim());
    if (value == null || value < 1 || value > Expense.maxAmount * 10) {
      setState(() => _error = '予算を入力してください');
      return;
    }
    _save(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('budget_sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('1か月の予算', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          key: const Key('budget_amount_field'),
          controller: _amount,
          enabled: !_saving,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
          decoration: _yenDecoration('予算'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('budget_save_button'),
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? '保存中…' : '保存'),
        ),
        if (widget.current != null) ...[
          const SizedBox(height: 8),
          TextButton(
            key: const Key('budget_clear_button'),
            onPressed: _saving ? null : () => _save(null),
            child: const Text('予算を消す'),
          ),
        ],
      ],
    );
  }
}
