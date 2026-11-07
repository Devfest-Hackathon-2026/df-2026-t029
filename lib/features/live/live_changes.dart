import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/history_entry.dart';
import '../../providers/live_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../repositories/live_repository.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/live_diff.dart';
import '../live_form/date_time_field.dart';
import 'deadline_format.dart';

/// 変更1件の説明（例：「申込期限 11/20(金) 23:59 → 11/18(水) 23:59」）。
/// 項目名・値の形は data の関数（historyFieldLabel・formatHistoryValue）を使う
String describeLiveChange(
  LiveChange change, {
  String Function(String id)? nameOf,
}) => switch (change) {
  FieldEdited(:final entry) =>
    '${historyFieldLabel(entry.target.collection, entry.field)} '
        '${formatHistoryValue(entry.field, entry.before, present: entry.hasBefore, nameOf: nameOf)}'
        ' → '
        '${formatHistoryValue(entry.field, entry.after, present: entry.hasAfter, nameOf: nameOf)}',
  DocAdded(:final target) =>
    target.collection == HistoryCollection.performances
        ? '公演が追加されました'
        : '受付が追加されました',
};

/// 日時の表示（未確定なら「たった今」）
String _whenText(DateTime? at, DateTime now) =>
    at == null ? 'たった今' : elapsedLabel(at, now);

/// 「変更あり」の印と、直近の変更の1行（計画書 3.6。色だけに頼らず文字で示す）
class ChangedMark extends StatelessWidget {
  const ChangedMark({
    super.key,
    required this.change,
    required this.now,
    this.nameOf,
  });

  final LiveChange change;
  final DateTime now;
  final String Function(String id)? nameOf;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('live_detail_changed_${change.target.docId}'),
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 後から追加された公演・受付は「追加」、項目の変更は「変更あり」
          HakoTagChip(change is DocAdded ? '追加' : '変更あり'),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${describeLiveChange(change, nameOf: nameOf)}'
              '（${_whenText(change.at, now)}）',
              style: HakoFonts.jp(
                size: 12,
                color: BrandColors.sub,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ライブ詳細の下の「変更履歴」（ライブ・公演・受付の変更を新しい順に）
class LiveHistorySection extends ConsumerStatefulWidget {
  const LiveHistorySection({
    super.key,
    required this.liveId,
    required this.titleOf,
  });

  final String liveId;

  /// 変更の対象の見出し（例：「公演 2026/11/23(月) 18:00 東京ドーム」）
  final String Function(HistoryTarget target) titleOf;

  @override
  ConsumerState<LiveHistorySection> createState() => _LiveHistorySectionState();
}

class _LiveHistorySectionState extends ConsumerState<LiveHistorySection> {
  /// 最初に出す件数（「すべて表示」で全件）
  static const _initialCount = 10;

  bool _showAll = false;

  /// 元に戻している履歴の ID（二重送信の防止）
  final Set<String> _reverting = {};

  Future<void> _revert(
    HistoryEntry entry,
    String Function(String) nameOf,
  ) async {
    if (_reverting.contains(entry.id)) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      _showSnack('ログインし直してから、もう一度お試しください');
      return;
    }
    final label = historyFieldLabel(entry.target.collection, entry.field);
    final before = formatHistoryValue(
      entry.field,
      entry.before,
      present: entry.hasBefore,
      nameOf: nameOf,
    );
    // ダイアログを開く前に印を付け、素早い2回目の押下でダイアログを重ねない
    setState(() => _reverting.add(entry.id));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この変更を元に戻しますか'),
        content: Text(
          '${widget.titleOf(entry.target)}の$labelを「$before」に戻します。'
          '戻した操作も変更履歴に残ります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            key: const Key('live_detail_history_revert_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('元に戻す'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok != true) {
      setState(() => _reverting.remove(entry.id));
      return;
    }
    String? error;
    try {
      await ref.read(liveRepositoryProvider).revert(entry, uid: uid);
    } on LiveConflictException catch (e) {
      debugPrint('元に戻す操作の競合: $e');
      error = 'その後に別の変更があります。最新の内容を確かめてください';
    } catch (e) {
      debugPrint('元に戻す操作に失敗: $e');
      error = '元に戻せませんでした。通信状況を確かめて、もう一度お試しください';
    }
    if (!mounted) return;
    setState(() => _reverting.remove(entry.id));
    _showSnack(error ?? '元に戻しました');
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final changes = ref.watch(liveChangesProvider(widget.liveId));
    final now = ref.watch(nowProvider);
    final uid = ref.watch(currentUidProvider);
    final oshis = ref.watch(allOshisProvider).value ?? const [];
    final names = {for (final o in oshis) o.id: o.name};
    String nameOf(String id) => names[id] ?? id;

    return Column(
      key: const Key('live_detail_history'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HakoSectionHeader('変更履歴'),
        switch (changes) {
          AsyncError() => Padding(
            key: const Key('live_detail_history_error'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Expanded(child: Text('変更履歴を読み込めませんでした')),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(liveChangesProvider(widget.liveId)),
                  child: const Text('もう一度読み込む'),
                ),
              ],
            ),
          ),
          AsyncValue(value: final list?) when list.isEmpty => const Padding(
            key: Key('live_detail_history_empty'),
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('変更はまだありません'),
          ),
          AsyncValue(value: final list?) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in _showAll ? list : list.take(_initialCount))
                _HistoryTile(
                  change: c,
                  title: widget.titleOf(c.target),
                  description: describeLiveChange(c, nameOf: nameOf),
                  whoText: switch (c) {
                    FieldEdited(:final entry) =>
                      entry.changedBy == uid ? 'あなた' : 'ほかのユーザー',
                    DocAdded() => null,
                  },
                  whenText: c.at == null
                      ? 'たった今'
                      : '${formatDateTime(c.at!)}（${elapsedLabel(c.at!, now)}）',
                  reverting: switch (c) {
                    FieldEdited(:final entry) => _reverting.contains(entry.id),
                    DocAdded() => false,
                  },
                  onRevert: switch (c) {
                    FieldEdited(:final entry) when canRevert(entry) =>
                      () => _revert(entry, nameOf),
                    _ => null,
                  },
                ),
              if (!_showAll && list.length > _initialCount)
                TextButton(
                  key: const Key('live_detail_history_show_all'),
                  onPressed: () => setState(() => _showAll = true),
                  child: Text('すべて表示（${list.length}件）'),
                ),
            ],
          ),
          _ => const Padding(
            key: Key('live_detail_history_loading'),
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.change,
    required this.title,
    required this.description,
    required this.whoText,
    required this.whenText,
    required this.reverting,
    required this.onRevert,
  });

  final LiveChange change;
  final String title;
  final String description;
  final String? whoText;
  final String whenText;
  final bool reverting;
  final VoidCallback? onRevert;

  String get _id => switch (change) {
    FieldEdited(:final entry) => entry.id,
    DocAdded(:final target) => 'added_${target.docId}',
  };

  @override
  Widget build(BuildContext context) {
    final onRevert = this.onRevert;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: BrandColors.rowLine, width: 1.5),
        ),
      ),
      child: ListTile(
        key: Key('live_detail_history_entry_$_id'),
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          change is DocAdded ? Icons.add_circle_outline : Icons.edit_outlined,
        ),
        title: Text(title),
        subtitle: Text(
          [
            description,
            [?whoText, whenText].join('・'),
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: onRevert == null
            ? null
            : reverting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                key: Key('live_detail_history_revert_$_id'),
                onPressed: onRevert,
                child: const Text('元に戻す'),
              ),
      ),
    );
  }
}
