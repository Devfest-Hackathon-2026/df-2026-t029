import 'package:flutter/material.dart';

import 'date_time_field.dart';
import 'live_draft.dart';

import '../../models/reception.dart';

/// ライブ情報の確認・修正画面（空で開けば手入力の登録画面になる）
class LiveFormPage extends StatefulWidget {
  const LiveFormPage({super.key, this.initial});

  final LiveDraft? initial;

  @override
  State<LiveFormPage> createState() => _LiveFormPageState();
}

class _LiveFormPageState extends State<LiveFormPage> {
  late final LiveDraft _draft = widget.initial ?? LiveDraft();

  void _save() {
    final errors = _draft.validate();
    if (errors.isNotEmpty) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('入力が足りない項目があります'),
          content: Text(errors.join('\n')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('入力チェック OK（保存処理は Step 3-5 で追加します）')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge;

    return Scaffold(
      appBar: AppBar(title: const Text('ライブ情報の確認')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('ライブ', style: titleStyle),
          TextFormField(
            initialValue: _draft.performers.join('、'),
            decoration: const InputDecoration(labelText: '出演者（「、」区切り）'),
            onChanged: (v) => _draft.performers = v
                .split('、')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList(),
          ),
          TextFormField(
            initialValue: _draft.title,
            decoration: const InputDecoration(labelText: 'ライブ名'),
            onChanged: (v) => _draft.title = v,
          ),
          TextFormField(
            initialValue: _draft.officialUrl,
            decoration: const InputDecoration(labelText: '公式ページの URL'),
            onChanged: (v) => _draft.officialUrl = v,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text('公演', style: titleStyle)),
              TextButton.icon(
                onPressed: () => setState(
                    () => _draft.performances.add(PerformanceDraft())),
                icon: const Icon(Icons.add),
                label: const Text('追加'),
              ),
            ],
          ),
          for (final p in _draft.performances)
            _PerformanceCard(
              key: ObjectKey(p),
              draft: p,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() => _draft.performances.remove(p)),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text('受付', style: titleStyle)),
              TextButton.icon(
                onPressed: () =>
                  setState(() => _draft.receptions.add(ReceptionDraft())),
                icon: const Icon(Icons.add),
                label: const Text('追加'),
              ),
            ],
          ),
          for (final r in _draft.receptions)
            _ReceptionCard(
              key: ObjectKey(r),
              draft: r,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() => _draft.receptions.remove(r)),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(onPressed: _save, child: const Text('保存'))
        ),
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final PerformanceDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DateTimeField(
              label: '開演日時',
              value: draft.startAt,
              onChanged: (v) {
                draft.startAt = v;
                onChanged();
              },
            ),
            DateTimeField(
              label: '開場日時',
              value: draft.openAt,
              onChanged: (v) {
                draft.openAt = v;
                onChanged();
              },
            ),
            TextFormField(
              initialValue: draft.venue,
              decoration: const InputDecoration(labelText: '会場名'),
              onChanged: (v) => draft.venue = v,
            ),
            TextFormField(
              initialValue: draft.prefecture,
              decoration: const InputDecoration(labelText: '都道府県'),
              onChanged: (v) => draft.prefecture = v,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('この公演を削除'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceptionCard extends StatelessWidget {
  const _ReceptionCard({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final ReceptionDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  static const _typeLabels = {
    ReceptionType.fc: 'FC先行',
    ReceptionType.general: '一般',
    ReceptionType.upgrade: 'アプグレ',
    ReceptionType.other: 'その他',
  };

  Widget _dateField(
    String label,
    DateTime? value,
    void Function(DateTime?) set,
  ) =>
      DateTimeField(
        label: label,
        value: value,
        onChanged: (v) {
          set(v);
          onChanged();
        },
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<ReceptionType>(
              initialValue: draft.type,
              decoration: const InputDecoration(labelText: '種別'),
              items: [
                for (final e in _typeLabels.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                if (v == null) return;
                draft.type = v;
                onChanged();
              },
            ),
            TextFormField(
              initialValue: draft.name,
              decoration: const InputDecoration(labelText: '表示名（例：FC1次先行）'),
              onChanged: (v) => draft.name = v,
            ),
            _dateField('申込開始', draft.applyStartAt,
                (v) => draft.applyStartAt = v),
            _dateField('申込期限', draft.applyEndAt, (v) => draft.applyEndAt = v),
            _dateField('当落発表', draft.resultAt, (v) => draft.resultAt = v),
            _dateField('入金期限', draft.paymentDeadline,
                (v) => draft.paymentDeadline = v),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('当選者のみが対象（アプグレなど）'),
              value: draft.winnersOnly,
              onChanged: (v) {
                draft.winnersOnly = v;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            Text('料金', style: Theme.of(context).textTheme.titleSmall),
            for (final price in draft.prices)
              Row(
                key: ObjectKey(price),
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: price.seat,
                      decoration: const InputDecoration(labelText: '席種'),
                      onChanged: (v) => price.seat = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: price.amount?.toString() ?? '',
                      decoration: const InputDecoration(
                        labelText: '金額',
                        suffixText: '円',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          price.amount = int.tryParse(v.replaceAll(',', '')),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: '料金を削除',
                    onPressed: () {
                      draft.prices.remove(price);
                      onChanged();
                    },
                  ),
                ],
              ),
            TextButton.icon(
              onPressed: () {
                draft.prices.add(PriceDraft());
                onChanged();
              },
              icon: const Icon(Icons.add),
              label: const Text('料金を追加'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('この受付を削除'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}