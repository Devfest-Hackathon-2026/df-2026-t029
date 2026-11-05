import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/oshi.dart';
import '../../providers/oshi_providers.dart';
import '../../utils/oshi_search.dart';

/// 出演者（承認済みの推し・グループ）を検索して1件選ぶ。選ばなければ null
Future<OshiSummary?> showPerformerPicker(
  BuildContext context, {
  String initialQuery = '',
}) {
  return showModalBottomSheet<OshiSummary>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PerformerPickerSheet(initialQuery: initialQuery),
  );
}

class _PerformerPickerSheet extends ConsumerStatefulWidget {
  const _PerformerPickerSheet({required this.initialQuery});

  final String initialQuery;

  @override
  ConsumerState<_PerformerPickerSheet> createState() =>
      _PerformerPickerSheetState();
}

class _PerformerPickerSheetState extends ConsumerState<_PerformerPickerSheet> {
  late String _query = widget.initialQuery;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allOshisProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            children: [
              TextFormField(
                initialValue: _query,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '推し・グループを検索',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: switch (all) {
                  AsyncData(:final value) => _buildList(value),
                  AsyncError(:final error) =>
                    Center(child: Text('読み込みに失敗しました：$error')),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<OshiSummary> all) {
    final results =
        searchOshis(all, _query).where((o) => o.isApproved).toList();
    if (results.isEmpty) {
      return const Center(
        child: Text('見つかりません。未登録の場合は、推しの追加申請をしてください'),
      );
    }
    return ListView(
      children: [
        for (final o in results)
          ListTile(
            leading:
                Icon(o.kind == OshiKind.group ? Icons.groups : Icons.person),
            title: Text(o.name),
            subtitle: Text(o.kind.label),
            onTap: () => Navigator.of(context).pop(o),
          ),
      ],
    );
  }
}