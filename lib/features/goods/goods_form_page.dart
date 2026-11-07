import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/goods.dart';
import '../../models/oshi.dart';
import '../../providers/goods_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../utils/oshi_search.dart';
import 'goods_draft.dart';

/// グッズの登録・編集画面。[goodsId] があれば編集、なければ新規登録
class GoodsFormPage extends ConsumerStatefulWidget {
  const GoodsFormPage({super.key, this.goodsId});

  final String? goodsId;

  @override
  ConsumerState<GoodsFormPage> createState() => _GoodsFormPageState();
}

class _GoodsFormPageState extends ConsumerState<GoodsFormPage> {
  GoodsDraft? _draft;

  /// 編集前の値（編集のときだけ）
  Goods? _base;
  List<String> _errors = const [];
  bool _saving = false;

  bool get _isEdit => widget.goodsId != null;
  String get _title => _isEdit ? 'グッズを編集' : 'グッズを登録';

  Future<void> _save({OshiSummary? target}) async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _saving = true);
    try {
      final base = _base;
      final repository = ref.read(goodsRepositoryProvider);

      // 重複の確認に使う、同じ推しの既存のグッズ（編集中のグッズ自身は除く）
      final existing = base == null
          ? await ref.read(goodsForTargetProvider.future)
          : [
              for (final g in await repository.fetchFor(
                groupIds: base.groupIds,
                oshiIds: base.oshiIds,
              ))
                if (g.id != base.id) g,
            ];
      final errors = draft.validate(existing);
      if (errors.isNotEmpty) {
        setState(() => _errors = errors);
        return;
      }
      final uid = ref.read(currentUidProvider);
      if (uid == null) return;

      if (base == null) {
        await repository.create(draft.toGoods(target!), uid: uid);
      } else {
        await repository.update(
          before: base,
          after: draft.applyTo(base),
          uid: uid,
        );
        ref.invalidate(goodsByIdProvider(base.id!));
      }
      ref.invalidate(goodsForTargetProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'グッズを更新しました' : 'グッズを登録しました')),
      );
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
    final all = ref.watch(allOshisProvider).value ?? const <OshiSummary>[];

    // 編集：グッズを読み込んでから、編集前の値と入力欄を用意する
    if (_isEdit) {
      final goods = ref.watch(goodsByIdProvider(widget.goodsId!));
      return goods.when(
        loading: () => _message(null),
        error: (e, _) => _message('グッズを読み込めませんでした: $e'),
        data: (g) {
          if (g == null) return _message('グッズが見つかりません');
          _base ??= g;
          _draft ??= GoodsDraft.fromGoods(g);
          return _form(
            heading: '対象：${_namesOf(g, all)}',
            members: _membersOf(
              groupIds: g.groupIds,
              oshiIds: g.oshiIds,
              all: all,
            ),
            onSave: () => _save(),
          );
        },
      );
    }

    // 新規登録：検索画面で選んだ推しのグッズとして登録する
    final target = ref.watch(goodsTargetProvider);
    if (target == null) {
      return _message('グッズの検索画面で推しを選んでから開いてください');
    }
    _draft ??= GoodsDraft();
    final isGroup = target.kind == OshiKind.group;
    return _form(
      heading: '対象：${target.name}（${target.kind.label}）',
      members: _membersOf(
        groupIds: isGroup ? [target.id] : const [],
        oshiIds: isGroup ? const [] : [target.id],
        all: all,
      ),
      onSave: () => _save(target: target),
    );
  }

  /// 読み込み中（[text] が null）やエラーのときの画面
  Widget _message(String? text) => Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: Center(
          child: text == null ? const CircularProgressIndicator() : Text(text),
        ),
      );

  Widget _form({
    required String heading,
    required List<OshiSummary> members,
    required VoidCallback onSave,
  }) {
    final draft = _draft!;
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(heading),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: draft.name,
            decoration: const InputDecoration(
              labelText: 'グッズ名（必須）',
              hintText: '例：TOUR 2026 ランダムアクスタ',
            ),
            onChanged: (v) => draft.name = v,
          ),
          TextFormField(
            initialValue: draft.aliases,
            decoration: const InputDecoration(
              labelText: '別名',
              helperText: '「、」で区切って複数入力できます',
            ),
            onChanged: (v) => draft.aliases = v,
          ),
          const SizedBox(height: 12),
          DropdownButton<GoodsCategory>(
            isExpanded: true,
            value: draft.category,
            items: [
              for (final c in GoodsCategory.values)
                DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: (c) =>
                setState(() => draft.category = c ?? GoodsCategory.other),
          ),
          TextFormField(
            initialValue: draft.price,
            decoration:
                const InputDecoration(labelText: '定価', suffixText: '円'),
            keyboardType: TextInputType.number,
            onChanged: (v) => draft.price = v,
          ),
          TextFormField(
            initialValue: draft.officialUrl,
            decoration:
                const InputDecoration(labelText: '公式の販売ページ（https://〜）'),
            keyboardType: TextInputType.url,
            onChanged: (v) => draft.officialUrl = v,
          ),
          const SizedBox(height: 24),
          Text('種類', style: Theme.of(context).textTheme.titleMedium),
          Text(_isEdit
              ? '保存済みの種類は削除できません（名前とメンバーは変更できます）'
              : 'メンバー別・絵柄別などの区別です。なければ「通常」として登録します'),
          for (final v in draft.variants)
            _VariantRow(
              key: ObjectKey(v),
              variant: v,
              members: members,
              onChanged: () => setState(() {}),
              // 保存済みの種類は削除しない（DB 設計案 5章）
              onRemove: v.id == null
                  ? () => setState(() => draft.variants.remove(v))
                  : null,
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => draft.variants.add(VariantDraft())),
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
            onPressed: _saving ? null : onSave,
            child: Text(_saving ? '保存中…' : (_isEdit ? '更新する' : '登録する')),
          ),
        ],
      ),
    );
  }
}

/// グッズの対象の推しの名前（読み込めていないものは省く）
String _namesOf(Goods g, List<OshiSummary> all) => [
      for (final o in all)
        if ((o.kind == OshiKind.group && g.groupIds.contains(o.id)) ||
            (o.kind == OshiKind.person && g.oshiIds.contains(o.id)))
          o.name,
    ].join('、');

/// 種類に紐づけられるメンバー（承認済みの個人）。
/// [groupIds] のグループのメンバーと、[oshiIds] の本人・その所属グループのメンバー
List<OshiSummary> _membersOf({
  required List<String> groupIds,
  required List<String> oshiIds,
  required List<OshiSummary> all,
}) {
  final persons = all.where((o) => o.kind == OshiKind.person).toList();
  final groups = {
    ...groupIds,
    for (final p in persons)
      if (oshiIds.contains(p.id)) ...p.groupIds,
  };
  final members = persons
      .where((o) => oshiIds.contains(o.id) || o.groupIds.any(groups.contains))
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
    this.onRemove,
  });

  final VariantDraft variant;
  final List<OshiSummary> members;
  final VoidCallback onChanged;

  /// null なら削除ボタンを出さない（保存済みの種類）
  final VoidCallback? onRemove;

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
        if (onRemove != null)
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'この種類を削除',
            onPressed: onRemove,
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }
}