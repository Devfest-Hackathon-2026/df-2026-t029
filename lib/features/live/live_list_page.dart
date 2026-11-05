import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/oshi_providers.dart';
import '../live_form/date_time_field.dart';
import '../../utils/deadline.dart';
import 'live_list_entries.dart' show PerformerNames;
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

/// フォロー中の推しのライブ一覧（/lives）
class LiveListPage extends ConsumerWidget {
  const LiveListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(liveListRowsProvider);
    // 下の switch と同じ順（エラーを先に見る）で、0件の表示かどうかを決める
    final isEmpty = !rows.hasError && (rows.value?.isEmpty ?? false);

    return Scaffold(
      appBar: AppBar(title: const Text('ライブ一覧')),
      // 0件のときだけ、ホームと同じ右下の「ライブを登録」を出す
      floatingActionButton: isEmpty
          ? FloatingActionButton.extended(
              key: const Key('live_list_register_fab'),
              onPressed: () => context.push('/register'),
              icon: const Icon(Icons.add),
              label: const Text('ライブを登録'),
            )
          : null,
      body: SafeArea(
        child: switch (rows) {
          AsyncError() => _ErrorView(
            onRetry: () {
              ref.invalidate(allOshisProvider);
              ref.invalidate(followStateProvider);
              ref.invalidate(livesProvider);
              ref.invalidate(performancesProvider);
            },
          ),
          AsyncValue(value: final r?) when r.isEmpty => const _EmptyView(),
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('live_list_empty'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'フォロー中の推しのライブはまだありません。\n'
              '推しをフォローするか、ライブを登録してみましょう',
              textAlign: TextAlign.center,
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
    final upcoming = rows.where((r) => !r.entry.isEnded);
    final ended = rows.where((r) => r.entry.isEnded).toList();
    return ListView(
      key: const Key('live_list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final r in upcoming) _LiveTile(row: r),
        if (ended.isNotEmpty) ...[
          Padding(
            key: const Key('live_list_finished_header'),
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text('終了', style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final r in ended) _LiveTile(row: r),
        ],
      ],
    );
  }
}

class _LiveTile extends StatelessWidget {
  const _LiveTile({required this.row});

  final LiveListRow row;

  String _dateLine() {
    final e = row.entry;
    final count = e.performances.length;
    if (e.isEnded) {
      return '終了（最終公演 ${formatDateTime(e.performances.last.startAt)}）';
    }
    final next = e.nextStartAt;
    if (next == null) return '公演の日程は未登録です';
    final rest = count > 1 ? '（全$count公演）' : '';
    return '次の公演 ${formatDateTime(next)}$rest';
  }

  @override
  Widget build(BuildContext context) {
    final live = row.entry.live;
    final performers = row.performerNames.join('、');
    return ListTile(
      key: Key('live_list_tile_${live.id}'),
      leading: Icon(row.entry.isEnded ? Icons.event_available : Icons.event),
      title: Text(live.title),
      subtitle: Text(
        [if (performers.isNotEmpty) performers, _dateLine()].join('\n'),
      ),
      isThreeLine: performers.isNotEmpty,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/lives/${live.id}'),
    );
  }
}
