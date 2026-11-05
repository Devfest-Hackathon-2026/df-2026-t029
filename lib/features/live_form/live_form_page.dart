import 'package:flutter/material.dart';

import 'date_time_field.dart';
import 'live_draft.dart';

/// ライブ情報の確認・修正画面（空で開けば手入力の登録画面になる）
class LiveFormPage extends StatefulWidget {
  const LiveFormPage({super.key, this.initial});

  final LiveDraft? initial;

  @override
  State<LiveFormPage> createState() => _LiveFormPageState();
}

class _LiveFormPageState extends State<LiveFormPage> {
  late final LiveDraft _draft = widget.initial ?? LiveDraft();

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
        ],
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