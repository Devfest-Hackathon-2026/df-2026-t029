import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/goods.dart';
import '../../models/oshi.dart';
import '../../providers/goods_providers.dart';
import '../../utils/goods_search.dart';
import 'trade_post_draft.dart';

/// 品目を選ぶシートの結果
class PickedGoodsResult {
  const PickedGoodsResult({required this.keys, required this.goodsById});

  /// 選んだもの。[itemKey]（品目）か [wholeGoodsKey]（グッズの全種類）の形。
  /// 選んだ順
  final List<String> keys;

  /// シートに出したグッズ（ID → グッズ）。ここにないグッズの選択は、
  /// シートでは選び直せないので、呼び出し側で残す
  final Map<String, Goods> goodsById;
}

/// 対象の推しのグッズから、品目を選ぶシート。
///
/// [allowWholeGoods] が true なら「全種類（どれでも）」も選べる（求のとき）。
/// [selectedKeys] は選択済みのキー（[itemKey]・[wholeGoodsKey] の形）。
/// 「決定」を押したら結果を返す。閉じただけなら null。
Future<PickedGoodsResult?> showTradeItemPickerSheet(
  BuildContext context, {
  required GoodsScope scope,
  required bool allowWholeGoods,
  required List<String> selectedKeys,
  required int maxCount,
}) {
  return showModalBottomSheet<PickedGoodsResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _TradeItemPickerSheet(
      scope: scope,
      allowWholeGoods: allowWholeGoods,
      selectedKeys: selectedKeys,
      maxCount: maxCount,
    ),
  );
}

class _TradeItemPickerSheet extends ConsumerStatefulWidget {
  const _TradeItemPickerSheet({
    required this.scope,
    required this.allowWholeGoods,
    required this.selectedKeys,
    required this.maxCount,
  });

  final GoodsScope scope;
  final bool allowWholeGoods;
  final List<String> selectedKeys;
  final int maxCount;

  @override
  ConsumerState<_TradeItemPickerSheet> createState() =>
      _TradeItemPickerSheetState();
}

class _TradeItemPickerSheetState extends ConsumerState<_TradeItemPickerSheet> {
  String _query = '';

  /// 選んだ順を保つ
  late final List<String> _selected = [...widget.selectedKeys];

  void _toggle(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else if (_selected.length < widget.maxCount) {
        _selected.add(key);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('1つのセットで選べるのは${widget.maxCount}個までです')),
        );
      }
    });
  }

  Future<void> _openGoodsPage() async {
    await context.push('/goods');
    // 登録・編集したグッズを読み直す
    ref.invalidate(goodsInScopeProvider(widget.scope));
  }

  @override
  Widget build(BuildContext context) {
    final goods = ref.watch(goodsInScopeProvider(widget.scope));
    final loaded = goods.value;

    return Padding(
      // キーボードで隠れないようにする
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                key: const Key('trade_picker_query'),
                decoration: const InputDecoration(
                  labelText: 'グッズ名で絞り込む',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: goods.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('グッズを読み込めませんでした: $e')),
                data: (all) {
                  final results = searchGoods(all, _query);
                  if (results.isEmpty) {
                    return const Center(
                      child: Text('グッズが見つかりません。下のボタンから登録できます'),
                    );
                  }
                  return ListView(
                    children: [for (final g in results) _goodsTile(g)],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  TextButton.icon(
                    key: const Key('trade_picker_register'),
                    onPressed: _openGoodsPage,
                    icon: const Icon(Icons.add),
                    label: const Text('グッズを登録する'),
                  ),
                  const Spacer(),
                  Text('${_selected.length} / ${widget.maxCount}'),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('trade_picker_done'),
                    onPressed: loaded == null
                        ? null
                        : () => Navigator.of(context).pop(
                            PickedGoodsResult(
                              keys: [..._selected],
                              goodsById: {
                                for (final g in loaded)
                                  if (g.id != null) g.id!: g,
                              },
                            ),
                          ),
                    child: const Text('決定'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goodsTile(Goods g) {
    final id = g.id!;
    final count = _selected
        .where((k) => k == wholeGoodsKey(id) || k.startsWith('item:$id#'))
        .length;
    return ExpansionTile(
      key: Key('trade_picker_goods_$id'),
      title: Text(g.name),
      subtitle: Text(
        count == 0 ? g.category.label : '${g.category.label}　$count個選択中',
      ),
      initiallyExpanded: count > 0,
      children: [
        if (widget.allowWholeGoods)
          CheckboxListTile(
            key: Key('trade_picker_whole_$id'),
            value: _selected.contains(wholeGoodsKey(id)),
            onChanged: (_) => _toggle(wholeGoodsKey(id)),
            title: const Text('全種類（どれでも）'),
          ),
        for (final v in g.variants)
          CheckboxListTile(
            key: Key('trade_picker_item_${id}_${v.id}'),
            value: _selected.contains(itemKey(id, v.id)),
            onChanged: (_) => _toggle(itemKey(id, v.id)),
            title: Text(v.name),
          ),
      ],
    );
  }
}

/// 求の「メンバー指定」で、メンバーを選ぶシート。
/// 「決定」を押したら選んだメンバーを返す。閉じただけなら null。
Future<List<OshiSummary>?> showMemberPickerSheet(
  BuildContext context, {
  required List<OshiSummary> candidates,
  required List<String> selectedIds,
  required int maxCount,
}) {
  return showModalBottomSheet<List<OshiSummary>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _MemberPickerSheet(
      candidates: candidates,
      selectedIds: selectedIds,
      maxCount: maxCount,
    ),
  );
}

class _MemberPickerSheet extends StatefulWidget {
  const _MemberPickerSheet({
    required this.candidates,
    required this.selectedIds,
    required this.maxCount,
  });

  final List<OshiSummary> candidates;
  final List<String> selectedIds;
  final int maxCount;

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
  late final Set<String> _selected = {...widget.selectedIds};

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: Column(
        children: [
          Expanded(
            child: widget.candidates.isEmpty
                ? const Center(child: Text('対象の推しのメンバーが登録されていません'))
                : ListView(
                    children: [
                      for (final m in widget.candidates)
                        CheckboxListTile(
                          key: Key('trade_member_${m.id}'),
                          value: _selected.contains(m.id),
                          title: Text(m.name),
                          onChanged: (on) => setState(() {
                            if (on != true) {
                              _selected.remove(m.id);
                            } else if (_selected.length < widget.maxCount) {
                              _selected.add(m.id);
                            }
                          }),
                        ),
                    ],
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('trade_member_done'),
                onPressed: () => Navigator.of(context).pop([
                  for (final m in widget.candidates)
                    if (_selected.contains(m.id)) m,
                ]),
                child: const Text('決定'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
