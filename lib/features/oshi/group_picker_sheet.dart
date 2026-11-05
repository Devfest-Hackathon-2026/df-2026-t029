import 'package:flutter/material.dart';

import '../../models/oshi.dart';
import '../../utils/oshi_search.dart';

/// 承認済みのグループから所属グループを選ぶシート。
///
/// 「決定」を押したら選んだ ID の一覧を返す。閉じただけなら null。
Future<List<String>?> showGroupPickerSheet(
  BuildContext context, {
  required List<OshiSummary> all,
  required List<String> selectedIds,
  required int maxCount,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _GroupPickerSheet(
      groups: [
        for (final o in all)
          if (o.kind == OshiKind.group && o.isApproved) o,
      ],
      selectedIds: selectedIds,
      maxCount: maxCount,
    ),
  );
}

class _GroupPickerSheet extends StatefulWidget {
  const _GroupPickerSheet({
    required this.groups,
    required this.selectedIds,
    required this.maxCount,
  });

  final List<OshiSummary> groups;
  final List<String> selectedIds;
  final int maxCount;

  @override
  State<_GroupPickerSheet> createState() => _GroupPickerSheetState();
}

class _GroupPickerSheetState extends State<_GroupPickerSheet> {
  // 入力中は text を書き換えない
  final _controller = TextEditingController();
  String _query = '';

  /// 選んだ順を保つ
  late final List<String> _selected = [...widget.selectedIds];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < widget.maxCount) {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = searchOshis(widget.groups, _query);
    final isFull = _selected.length >= widget.maxCount;

    return Padding(
      // キーボードで隠れないようにする
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '所属グループを選ぶ（${_selected.length}/${widget.maxCount}）',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton(
                    key: const Key('oshi_group_picker_done_button'),
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('決定'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('oshi_group_picker_field'),
                controller: _controller,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'グループ名で探す',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      key: Key('oshi_group_picker_empty'),
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          '公開されているグループが見つかりません。\n'
                          'グループが未登録なら、先にグループを申請してください',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final g = results[i];
                        final checked = _selected.contains(g.id);
                        return CheckboxListTile(
                          key: ValueKey('oshi_group_picker_item_${g.id}'),
                          value: checked,
                          title: Text(g.name),
                          onChanged: checked || !isFull
                              ? (_) => _toggle(g.id)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
