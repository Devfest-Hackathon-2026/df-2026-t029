import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/goods.dart';
import '../../models/live.dart';
import '../../models/oshi.dart';
import '../../models/performance.dart';
import '../../models/trade_post.dart';
import '../../providers/goods_providers.dart';
import '../../providers/live_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../utils/trade_board.dart';
import '../live_form/date_time_field.dart';
import 'trade_post_draft.dart';

/// 掲示板の絞り込みの条件を選ぶシート。
/// 「適用」を押したら条件を返す。閉じただけなら null。
Future<BoardFilter?> showBoardFilterSheet(
  BuildContext context, {
  required OshiSummary target,
  required BoardFilter initial,
}) {
  return showModalBottomSheet<BoardFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _BoardFilterSheet(target: target, initial: initial),
  );
}

/// 公演の表示名（例：ツアー2026 2026/11/20(金) 18:00 会場）
String performanceLabel(Performance p, Map<String?, String> liveTitles) =>
    '${liveTitles[p.liveId] ?? '（ライブ名不明）'} '
    '${formatDateTime(p.startAt)} ${p.venue}';

class _BoardFilterSheet extends ConsumerStatefulWidget {
  const _BoardFilterSheet({required this.target, required this.initial});

  final OshiSummary target;
  final BoardFilter initial;

  @override
  ConsumerState<_BoardFilterSheet> createState() => _BoardFilterSheetState();
}

class _BoardFilterSheetState extends ConsumerState<_BoardFilterSheet> {
  late String? _goodsId = widget.initial.goodsId;
  late String? _goodsName = widget.initial.goodsName;
  late BoardSide _side = widget.initial.side;
  late final Set<TradeTag> _tags = {...widget.initial.tags};
  late String? _performanceId = widget.initial.performanceId;
  late String? _performanceLabel = widget.initial.performanceLabel;

  bool get _isGroup => widget.target.kind == OshiKind.group;
  List<String> get _groupIds => _isGroup ? [widget.target.id] : const [];
  List<String> get _oshiIds => _isGroup ? const [] : [widget.target.id];

  BoardFilter get _result => BoardFilter(
    goodsId: _goodsId,
    goodsName: _goodsName,
    side: _side,
    tags: {..._tags},
    performanceId: _performanceId,
    performanceLabel: _performanceLabel,
  );

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allOshisProvider).value ?? const <OshiSummary>[];
    final goods = ref.watch(
      goodsInScopeProvider(
        goodsScopeFor(groupIds: _groupIds, oshiIds: _oshiIds, all: all),
      ),
    );
    final theme = Theme.of(context);
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('絞り込み', style: theme.textTheme.titleMedium),
                heading('グッズ'),
                goods.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('グッズを読み込めませんでした: $e'),
                  data: (list) => _goodsDropdown(list),
                ),
                heading(_goodsId == null ? '譲・求があるか' : 'そのグッズを含むのは'),
                SegmentedButton<BoardSide>(
                  key: const Key('board_filter_side'),
                  segments: [
                    for (final s in BoardSide.values)
                      ButtonSegment(value: s, label: Text(s.label)),
                  ],
                  selected: {_side},
                  onSelectionChanged: (v) => setState(() => _side = v.first),
                ),
                heading('タグ（選んだもののどれかを含む）'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in TradeTag.values)
                      FilterChip(
                        key: Key('board_filter_tag_${t.name}'),
                        label: Text(t.label),
                        selected: _tags.contains(t),
                        onSelected: (on) =>
                            setState(() => on ? _tags.add(t) : _tags.remove(t)),
                      ),
                  ],
                ),
                heading('手渡しの公演'),
                _performanceDropdown(all),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                TextButton(
                  key: const Key('board_filter_clear'),
                  onPressed: () => Navigator.of(context).pop(BoardFilter.none),
                  child: const Text('条件をすべて外す'),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('board_filter_apply'),
                  onPressed: () => Navigator.of(context).pop(_result),
                  child: const Text('適用'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _goodsDropdown(List<Goods> list) {
    final ids = {for (final g in list) g.id};
    return DropdownButton<String?>(
      key: const Key('board_filter_goods'),
      isExpanded: true,
      value: ids.contains(_goodsId) ? _goodsId : null,
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('指定なし')),
        for (final g in list)
          DropdownMenuItem<String?>(value: g.id, child: Text(g.name)),
      ],
      onChanged: (id) => setState(() {
        _goodsId = id;
        _goodsName = list.where((g) => g.id == id).firstOrNull?.name;
      }),
    );
  }

  Widget _performanceDropdown(List<OshiSummary> all) {
    final performances = ref.watch(performancesProvider);
    final lives = ref.watch(livesProvider).value ?? const <Live>[];
    final now = ref.watch(nowProvider);
    return performances.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('公演を読み込めませんでした: $e'),
      data: (list) {
        final candidates = handoverPerformanceCandidates(
          performances: list,
          groupIds: _groupIds,
          oshiIds: _oshiIds,
          all: all,
          now: now,
        );
        final titles = {for (final l in lives) l.id: l.title};
        final ids = {for (final p in candidates) p.id};
        return DropdownButton<String?>(
          key: const Key('board_filter_performance'),
          isExpanded: true,
          value: ids.contains(_performanceId) ? _performanceId : null,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('指定なし')),
            for (final p in candidates)
              DropdownMenuItem<String?>(
                value: p.id,
                child: Text(
                  performanceLabel(p, titles),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (id) => setState(() {
            _performanceId = id;
            final p = candidates.where((p) => p.id == id).firstOrNull;
            _performanceLabel = p == null ? null : performanceLabel(p, titles);
          }),
        );
      },
    );
  }
}
