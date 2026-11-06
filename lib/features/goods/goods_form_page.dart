import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/goods.dart';
import '../../models/oshi.dart';
import '../../providers/goods_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../utils/oshi_search.dart';
import 'goods_draft.dart';

class GoodsFormPage extends ConsumerStatefulWidget {
  const GoodsFormPage({super.key});

  @override
  ConsumerState<GoodsFormPage> createState() => _GoodsFormPageState();
}

class _GoodsFormPageState extends ConsumerState<GoodsFormPage> {
  final _draft = GoodsDraft();
  List<String> _errors = const [];
  bool _saving = false;

  Future<void> _save(OshiSummary target) async {
    setState(() => _saving = true);
    try {
      final existing = await ref.read(goodsForTargetProvider.future);
      final errors = _draft.validate(existing);
      if (errors.isNotEmpty) {
        setState(() => _errors = errors);
        return;
      }
      final uid = ref.read(currentUidProvider);
      if (uid == null) return;

      await ref
          .read(goodsRepositoryProvider)
          .create(_draft.toGoods(target), uid: uid);
      ref.invalidate(goodsForTargetProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('グッズを登録しました')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errors = ['保存できませんでした: $e']);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = ref.watch(goodsTargetProvider);
    if (target == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('グッズを登録')),
        body: const Center(child: Text('グッズの検索画面で推しを選んでから開いてください')),
      );
    }
    final members =
        _membersOf(target, ref.watch(allOshisProvider).value ?? const []);

    return Scaffold(
      appBar: AppBar(title: const Text('グッズを登録')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('対象：${target.name}（${target.kind.label}）'),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'グッズ名（必須）',
              hintText: '例：TOUR 2026 ランダムアクスタ',
            ),
            onChanged: (v) => _draft.name = v,
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: '別名',
              helperText: '「、」で区切って複数入力できます',
            ),
            onChanged: (v) => _draft.aliases = v,
          ),
          const SizedBox(height: 12),
          DropdownButton<GoodsCategory>(
            isExpanded: true,
            value: _draft.category,
            items: [
              for (final c in GoodsCategory.values)
                DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: (c) =>
                setState(() => _draft.category = c ?? GoodsCategory.other),
          ),
          TextField(
            decoration:
                const InputDecoration(labelText: '定価', suffixText: '円'),
            keyboardType: TextInputType.number,
            onChanged: (v) => _draft.price = v,
          ),
          TextField(
            decoration:
                const InputDecoration(labelText: '公式の販売ページ（https://〜）'),
            keyboardType: TextInputType.url,
            onChanged: (v) => _draft.officialUrl = v,
          ),
          const SizedBox(height: 24),
          Text('種類', style: Theme.of(context).textTheme.titleMedium),
          const Text('メンバー別・絵柄別などの区別です。なければ「通常」として登録します'),
          for (final v in _draft.variants)
            _VariantRow(
              key: ObjectKey(v),
              variant: v,
              members: members,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() => _draft.variants.remove(v)),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => _draft.variants.add(VariantDraft())),
              icon: const Icon(Icons.add),
              label: const Text('種類を追加'),
            ),
          ),
          const SizedBox(height: 16),
          for (final e in _errors)
            Text(e,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving ? null : () => _save(target),
            child: Text(_saving ? '保存中…' : '登録する'),
          ),
        ],
      ),
    );
  }
}

/// 種類に紐づけられるメンバー（承認済みの個人）。
/// グループならそのメンバー、個人なら本人と、所属グループのメンバー
List<OshiSummary> _membersOf(OshiSummary target, List<OshiSummary> all) {
  final groupIds = target.kind == OshiKind.group
      ? {target.id}
      : target.groupIds.toSet();
  final members = all
      .where((o) =>
          o.kind == OshiKind.person &&
          (o.id == target.id || o.groupIds.any(groupIds.contains)))
      .toList();
  return searchOshis(members, ''); // 承認済みだけを名前順に
}

/// 種類の1行（名前とメンバー）
class _VariantRow extends StatelessWidget {
  const _VariantRow({
    super.key,
    required this.variant,
    required this.members,
    required this.onChanged,
    required this.onRemove,
  });

  final VariantDraft variant;
  final List<OshiSummary> members;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final memberIds = {for (final m in members) m.id};
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            initialValue: variant.name,
            decoration: const InputDecoration(labelText: '種類の名前'),
            onChanged: (v) => variant.name = v,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<String?>(
            isExpanded: true,
            value: memberIds.contains(variant.oshiId) ? variant.oshiId : null,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('メンバーなし'),
              ),
              for (final m in members)
                DropdownMenuItem<String?>(value: m.id, child: Text(m.name)),
            ],
            onChanged: (id) {
              variant.oshiId = id;
              onChanged();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'この種類を削除',
          onPressed: onRemove,
        ),
      ],
    );
  }
}