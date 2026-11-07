import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/oshi.dart';
import '../../providers/oshi_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/oshi_search.dart';

/// 出演者（承認済みの推し・グループ）を検索して1件選ぶ。選ばなければ null
Future<OshiSummary?> showPerformerPicker(
  BuildContext context, {
  String initialQuery = '',
}) {
  return showModalBottomSheet<OshiSummary>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => _PerformerPickerSheet(initialQuery: initialQuery),
  );
}

OutlineInputBorder _searchBorder(double width) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(10),
  borderSide: BorderSide(color: BrandColors.ink, width: width),
);

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
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.82,
          child: Column(
            children: [
              TextFormField(
                initialValue: _query,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '推し・グループを検索',
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: _searchBorder(2),
                  enabledBorder: _searchBorder(2),
                  focusedBorder: _searchBorder(3),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: switch (all) {
                  AsyncData(:final value) => _buildList(value),
                  AsyncError(:final error) => HakoEmpty('読み込みに失敗しました：$error'),
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
    final results = searchOshis(
      all,
      _query,
    ).where((o) => o.isApproved).toList();
    if (results.isEmpty) {
      return const HakoEmpty('見つかりません。未登録の場合は、推しの追加申請をしてください');
    }
    return ListView(
      children: [
        for (final o in results)
          ListTile(
            minTileHeight: 52,
            leading: Icon(
              o.kind == OshiKind.group
                  ? Icons.group_outlined
                  : Icons.person_outline,
              size: 28,
            ),
            title: Text(o.name),
            subtitle: Text(
              o.kind.label,
              style: HakoFonts.jp(size: 12, color: BrandColors.sub),
            ),
            onTap: () => Navigator.of(context).pop(o),
          ),
      ],
    );
  }
}
