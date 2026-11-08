import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/oshi_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../live_form/date_time_field.dart';
import '../../utils/deadline.dart';
import 'live_list_entries.dart' show PerformerNames;
import 'live_timeline.dart';
import 'oshi_upcoming_lives_section.dart';
import '../../providers/live_providers.dart';

/// ライブ一覧の1行と、その出演者名
typedef LiveListRow = ({LiveListEntry entry, List<String> performerNames});

/// ライブ一覧の中身（並び順と「終了」の判定は data の [liveListProvider]）。
/// ライブ・公演・推しのどれかがエラーならエラー、どれかが読み込み中なら読み込み中
final liveListRowsProvider = Provider<AsyncValue<List<LiveListRow>>>((ref) {
  final entries = ref.watch(liveListProvider);
  final oshis = ref.watch(allOshisProvider);
  for (final AsyncValue<Object?> v in [entries, oshis]) {
    if (v case AsyncError(:final error, :final stackTrace)) {
      return AsyncError(error, stackTrace);
    }
  }
  final entriesValue = entries.value;
  final oshisValue = oshis.value;
  if (entriesValue == null || oshisValue == null) return const AsyncLoading();
  final names = PerformerNames(oshisValue);
  return AsyncData([
    for (final e in entriesValue) (entry: e, performerNames: names.of(e.live)),
  ]);
});

/// 自分のライブ一覧（/lives）。
/// 今後のライブ（タイムライン）→「ライブを追加」→（Fd-2：推しの今後のライブ）→ 終了（Fd 3.1）
class LiveListPage extends ConsumerWidget {
  const LiveListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(liveListRowsProvider);

    return HakoPageScaffold(
      title: 'ライブ一覧',
      body: SafeArea(
        child: switch (rows) {
          AsyncError() => _ErrorView(
            onRetry: () {
              ref.invalidate(allOshisProvider);
              ref.invalidate(myLiveIdsProvider);
              ref.invalidate(myLivesProvider);
              ref.invalidate(myPerformancesProvider);
            },
          ),
          AsyncValue(value: final r?) => _ListView(rows: r),
          _ => const Center(
            key: Key('live_list_loading'),
            child: CircularProgressIndicator(),
          ),
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('live_list_error'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ライブを読み込めませんでした', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('live_list_retry_button'),
              onPressed: onRetry,
              child: const Text('もう一度読み込む'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView({required this.rows});

  final List<LiveListRow> rows;

  @override
  Widget build(BuildContext context) {
    final upcoming = rows.where((r) => !r.entry.isEnded).toList();
    final ended = rows.where((r) => r.entry.isEnded).toList();
    return ListView(
      key: const Key('live_list'),
      padding: HakoPageScaffold.padding(context),
      children: [
        // 自分の今後のライブ（Fd 3.2）
        const HakoSectionHeader(
          '今後のライブ',
          key: Key('live_list_upcoming_header'),
        ),
        if (upcoming.isEmpty)
          Padding(
            key: const Key('live_list_upcoming_empty'),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '今後のライブはまだありません',
              style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.5),
            ),
          )
        else
          for (var i = 0; i < upcoming.length; i++)
            LiveTimelineItem(
              entry: upcoming[i].entry,
              performers: upcoming[i].performerNames,
              isFirst: i == 0,
              isLast: i == upcoming.length - 1,
              // いちばん近い今後のライブだけ丸を塗る
              filled: i == 0,
            ),
        // 区画の右下に「ライブを追加」（FAB の置き換え。Fd 3.1）
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const Key('live_list_add_button'),
              onPressed: () => context.push('/lives/add'),
              icon: const Icon(Icons.add),
              label: const Text('ライブを追加'),
            ),
          ),
        ),
        // フォロー中の推しごとの今後のライブ（Fd 3.3）
        const OshiUpcomingLivesList(),
        if (ended.isNotEmpty) ...[
          const HakoSectionHeader('終了', key: Key('live_list_finished_header')),
          for (final r in ended) _LiveTile(row: r),
        ],
      ],
    );
  }
}

/// 終了したライブの1行
class _LiveTile extends StatelessWidget {
  const _LiveTile({required this.row});

  final LiveListRow row;

  String _dateLine() {
    final e = row.entry;
    if (e.isEnded) {
      return '終了（最終公演 ${formatDateTime(e.performances.last.startAt)}）';
    }
    return upcomingDateLine(e);
  }

  @override
  Widget build(BuildContext context) {
    final live = row.entry.live;
    final performers = row.performerNames.join('、');
    return HakoRow(
      key: Key('live_list_tile_${live.id}'),
      icon: row.entry.isEnded
          ? Icons.event_available_outlined
          : Icons.calendar_today_outlined,
      title: live.title,
      subs: [if (performers.isNotEmpty) performers, _dateLine()],
      onTap: () => context.push('/lives/${live.id}'),
    );
  }
}