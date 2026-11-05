import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'date_time_field.dart';
import 'live_draft.dart';

import '../../models/reception.dart';
import '../../models/oshi.dart';
import '../../providers/oshi_providers.dart';
import '../../providers/live_providers.dart';
import '../../services/calendar_events.dart';
import '../calendar/calendar_add_sheet.dart';

import 'performer_picker_sheet.dart';

/// ライブ情報の確認・修正画面（空で開けば手入力の登録画面になる）
class LiveFormPage extends ConsumerStatefulWidget {
  const LiveFormPage({super.key, this.initial});

  final LiveDraft? initial;

  @override
  ConsumerState<LiveFormPage> createState() => _LiveFormPageState();
}

class _LiveFormPageState extends ConsumerState<LiveFormPage> {
  late final LiveDraft _draft = widget.initial ?? LiveDraft();
  
  /// 自動で対応付けられなかった、読み取った出演者名
  List<String> _unmatched = [];
  bool _autoMatched = false;
  bool _saving = false;

  Future<void> _pickPerformer({String initialQuery = '', String? resolving}) async {
    final picked =
        await showPerformerPicker(context, initialQuery: initialQuery);
    if (picked == null || !mounted) return;
    setState(() {
      _draft.addPerformer(picked);
      if (resolving != null) _unmatched.remove(resolving);
    });
  }

  Future<void> _save() async {
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

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      final (live, performances, receptions) = _draft.toModels();
      final saved = await ref.read(liveRepositoryProvider).create(
            live: live,
            performances: performances,
            receptions: receptions,
            uid: uid,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('保存しました')));

      final events = buildCalendarEvents(
        live: saved.live,
        performances: saved.performances,
        receptions: saved.receptions,
      );
      if (events.isNotEmpty) {
        final added = await showCalendarAddSheet(context, events);
        if (!mounted) return;
        if (added) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Google カレンダーに追加しました')));
        }
      }
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存に失敗しました：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 推しの一覧が読み込まれたら、読み取った出演者名を1回だけ自動で対応付ける
    final all = ref.watch(allOshisProvider).value;
    if (!_autoMatched && all != null) {
      _autoMatched = true;
      _unmatched = _draft.autoMatchPerformers(all);
    }

    final titleStyle = Theme.of(context).textTheme.titleLarge;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'ライブ情報の入力' : 'ライブ情報の確認'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('ライブ', style: titleStyle),
          
          const SizedBox(height: 8),
          Text('出演者', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in _draft.selectedPerformers)
                InputChip(
                  avatar: Icon(
                    o.kind == OshiKind.group ? Icons.groups : Icons.person,
                    size: 18,
                  ),
                  label: Text(o.name),
                  onDeleted: () =>
                      setState(() => _draft.selectedPerformers.remove(o)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('出演者を追加'),
                onPressed: () => _pickPerformer(),
              ),
            ],
          ),
          for (final name in _unmatched)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline),
              title: Text('読み取った名前「$name」'),
              subtitle: const Text('一致する推しが見つかりませんでした'),
              trailing: TextButton(
                onPressed: () =>
                    _pickPerformer(initialQuery: name, resolving: name),
                child: const Text('検索して選ぶ'),
              ),
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
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
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