import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/oshi.dart';
import '../../models/trade_post.dart';
import '../../providers/oshi_providers.dart';
import '../common/photo_items.dart';
import 'trade_item_picker_sheet.dart';
import 'trade_post_draft.dart';

/// 譲セットの一覧と追加ボタン
class GiveSetsSection extends ConsumerWidget {
  const GiveSetsSection({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.canAddPhoto,
    required this.photosEnabled,
    required this.onAddPhotos,
  });

  final TradePostDraft draft;
  final VoidCallback onChanged;

  /// 「写真を追加」を押せるか（合計の上限・処理中は呼び出し側で判定する）
  final bool canAddPhoto;

  /// 写真を外せるか（保存中は false）
  final bool photosEnabled;

  /// セットに写真を足す（写真を選ぶ処理は作成・編集画面が行う）
  final ValueChanged<GiveSetDraft> onAddPhotos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allOshisProvider).value ?? const <OshiSummary>[];
    final hasTarget = draft.groupIds.isNotEmpty || draft.oshiIds.isNotEmpty;

    Future<void> pick(GiveSetDraft set) async {
      final result = await showTradeItemPickerSheet(
        context,
        scope: goodsScopeFor(
          groupIds: draft.groupIds,
          oshiIds: draft.oshiIds,
          all: all,
        ),
        allowWholeGoods: false,
        selectedKeys: set.selectedKeys,
        maxCount: TradePostDraft.maxItemsPerSet,
      );
      if (result == null) return;
      set.replaceItems(
        giveItemsFromKeys(result.keys, result.goodsById),
        result.goodsById.keys.toSet(),
      );
      onChanged();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, set) in draft.gives.indexed)
          _SetCard(
            key: ObjectKey(set),
            keyPrefix: 'trade_give_$i',
            title: '譲セット${i + 1}',
            labels: [for (final item in set.items) item.label],
            onRemoveLabel: (j) {
              set.items.removeAt(j);
              onChanged();
            },
            pickCount: set.pickCount,
            onPickCountChanged: (v) => set.pickCount = v,
            note: set.note,
            onNoteChanged: (v) => set.note = v,
            onRemove: () {
              draft.gives.remove(set);
              onChanged();
            },
            actions: [
              OutlinedButton.icon(
                key: Key('trade_give_${i}_pick'),
                onPressed: hasTarget ? () => pick(set) : null,
                icon: const Icon(Icons.checklist),
                label: const Text('品目を選ぶ'),
              ),
            ],
            // セットの写真（G-7）
            footer: PhotoEditSection(
              title: 'このセットの写真',
              photos: set.photos,
              canAdd: canAddPhoto,
              enabled: photosEnabled,
              onAdd: () => onAddPhotos(set),
              onRemove: (k) {
                set.photos.removeAt(k);
                onChanged();
              },
              addButtonKey: Key('trade_give_${i}_add_photo'),
            ),
          ),
        _AddSetButton(
          buttonKey: const Key('trade_give_add'),
          label: '譲セットを追加',
          enabled: draft.gives.length < TradePostDraft.maxSets,
          onPressed: () {
            draft.gives.add(GiveSetDraft());
            onChanged();
          },
        ),
      ],
    );
  }
}

/// 求セットの一覧と追加ボタン
class WantSetsSection extends ConsumerWidget {
  const WantSetsSection({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final TradePostDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allOshisProvider).value ?? const <OshiSummary>[];
    final hasTarget = draft.groupIds.isNotEmpty || draft.oshiIds.isNotEmpty;

    Future<void> pickGoods(WantSetDraft set) async {
      final result = await showTradeItemPickerSheet(
        context,
        scope: goodsScopeFor(
          groupIds: draft.groupIds,
          oshiIds: draft.oshiIds,
          all: all,
        ),
        allowWholeGoods: true,
        selectedKeys: set.selectedKeys,
        maxCount: TradePostDraft.maxItemsPerSet - set.memberIds.length,
      );
      if (result == null) return;
      set.replaceGoodsTargets(
        wantTargetsFromKeys(result.keys, result.goodsById),
        result.goodsById.keys.toSet(),
      );
      onChanged();
    }

    Future<void> pickMembers(WantSetDraft set) async {
      final candidates = memberCandidates(
        groupIds: draft.groupIds,
        oshiIds: draft.oshiIds,
        all: all,
      );
      final picked = await showMemberPickerSheet(
        context,
        candidates: candidates,
        selectedIds: set.memberIds,
        maxCount:
            TradePostDraft.maxItemsPerSet -
            (set.targets.length - set.memberIds.length),
      );
      if (picked == null) return;
      set.replaceMembers(picked, {for (final m in candidates) m.id});
      onChanged();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, set) in draft.wants.indexed)
          _SetCard(
            key: ObjectKey(set),
            keyPrefix: 'trade_want_$i',
            title: '求セット${i + 1}',
            labels: [
              for (final t in set.targets)
                t.type == WantType.member ? '${t.label}（メンバー指定）' : t.label,
            ],
            onRemoveLabel: (j) {
              set.targets.removeAt(j);
              onChanged();
            },
            pickCount: set.pickCount,
            onPickCountChanged: (v) => set.pickCount = v,
            note: set.note,
            onNoteChanged: (v) => set.note = v,
            onRemove: () {
              draft.wants.remove(set);
              onChanged();
            },
            actions: [
              OutlinedButton.icon(
                key: Key('trade_want_${i}_pick'),
                onPressed: hasTarget ? () => pickGoods(set) : null,
                icon: const Icon(Icons.checklist),
                label: const Text('品目・グッズを選ぶ'),
              ),
              OutlinedButton.icon(
                key: Key('trade_want_${i}_members'),
                onPressed: hasTarget ? () => pickMembers(set) : null,
                icon: const Icon(Icons.person),
                label: const Text('メンバーを選ぶ'),
              ),
            ],
          ),
        _AddSetButton(
          buttonKey: const Key('trade_want_add'),
          label: '求セットを追加',
          enabled: draft.wants.length < TradePostDraft.maxSets,
          onPressed: () {
            draft.wants.add(WantSetDraft());
            onChanged();
          },
        ),
      ],
    );
  }
}

class _AddSetButton extends StatelessWidget {
  const _AddSetButton({
    required this.buttonKey,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      key: buttonKey,
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.add),
      label: Text(enabled ? label : '$label（${TradePostDraft.maxSets}個まで）'),
    ),
  );
}

/// セット1つ分（品目のチップ、選ぶボタン、選べる数、備考）
class _SetCard extends StatelessWidget {
  const _SetCard({
    super.key,
    required this.keyPrefix,
    required this.title,
    required this.labels,
    required this.onRemoveLabel,
    required this.pickCount,
    required this.onPickCountChanged,
    required this.note,
    required this.onNoteChanged,
    required this.onRemove,
    required this.actions,
    this.footer,
  });

  final String keyPrefix;
  final String title;
  final List<String> labels;
  final void Function(int index) onRemoveLabel;
  final String pickCount;
  final ValueChanged<String> onPickCountChanged;
  final String note;
  final ValueChanged<String> onNoteChanged;
  final VoidCallback onRemove;
  final List<Widget> actions;

  /// 備考の下に置くもの（譲セットの写真）
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: Key('${keyPrefix}_remove'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'このセットを削除',
                  onPressed: onRemove,
                ),
              ],
            ),
            if (labels.isEmpty)
              const Text('まだ選んでいません')
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final (j, label) in labels.indexed)
                    InputChip(
                      label: Text(label),
                      onDeleted: () => onRemoveLabel(j),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: actions),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  TextFormField(
                    key: Key('${keyPrefix}_pick_count'),
                    initialValue: pickCount,
                    decoration: const InputDecoration(
                      labelText: '選べる数（任意）',
                      helperText: '「この中から N 個」の N。空欄なら指定なし',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: onPickCountChanged,
                  ),
                  TextFormField(
                    key: Key('${keyPrefix}_note'),
                    initialValue: note,
                    decoration: const InputDecoration(labelText: 'セットの備考（任意）'),
                    onChanged: onNoteChanged,
                  ),
                ],
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(top: 12, right: 8),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}