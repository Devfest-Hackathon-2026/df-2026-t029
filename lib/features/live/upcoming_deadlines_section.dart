import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/live_providers.dart';
import '../../utils/deadline.dart';
import '../../theme/hako_app_widgets.dart';
import 'deadline_format.dart';

/// ホームに出す「次の締切」「当落発表」の件数（それぞれ）
const homeDeadlineLimit = 5;

/// ホームの「次の締切」（申込・入金）または「当落発表」（近い順に5件まで）
///
/// スクロールする親（ListView など）の中に置く前提で、自分ではスクロールしない。
class UpcomingDeadlinesSection extends ConsumerWidget {
  const UpcomingDeadlinesSection({super.key, this.results = false});

  /// true のとき当落発表だけ、false のとき申込・入金だけを出す（Fe 3.3）
  final bool results;

  /// Key の頭（次の締切は今までの Key のまま）
  String get _keyPrefix => results ? 'home_results' : 'home_deadlines';

  void _retry(WidgetRef ref) {
    ref.invalidate(myLiveIdsProvider);
    ref.invalidate(myLivesProvider);
    ref.invalidate(myReceptionsProvider);
    ref.invalidate(applicationsProvider);
  }

  /// 種類で振り分けて、先頭から [homeDeadlineLimit] 件（Fe 3.3）
  List<DeadlineEntry> _pick(List<DeadlineEntry> list) => list
      .where((e) => (e.deadline.kind == DeadlineKind.result) == results)
      .take(homeDeadlineLimit)
      .toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myIds = ref.watch(myLiveIdsProvider);
    final deadlines = ref.watch(upcomingDeadlinesProvider);

    // 自分のライブ一覧の読み込みが先。0件なら締切は問い合わせない
    return switch ((myIds, deadlines)) {
      (AsyncError(), _) || (_, AsyncError()) => _ErrorView(
        keyPrefix: _keyPrefix,
        message: results ? '当落発表を読み込めませんでした' : '締切を読み込めませんでした',
        onRetry: () => _retry(ref),
      ),
      // 当落発表は追加のボタンを出さない（次の締切の区画と重ねないため）
      (AsyncValue(value: final t?), _) when t.isEmpty =>
        results
            ? const _EmptyView(
                key: Key('home_results_empty'),
                message: '当落発表の予定はありません',
              )
            : const _NoLiveView(),
      (AsyncValue(value: _?), AsyncValue(value: final list?)) => switch (_pick(
        list,
      )) {
        final entries when entries.isEmpty => _EmptyView(
          key: Key('${_keyPrefix}_empty'),
          message: results ? '当落発表の予定はありません' : '近い締切はありません',
        ),
        final entries => _ListView(entries: entries, results: results),
      },
      _ => Padding(
        key: Key('${_keyPrefix}_loading'),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.keyPrefix,
    required this.message,
    required this.onRetry,
  });

  final String keyPrefix;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('${keyPrefix}_error'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton(
            key: Key('${keyPrefix}_retry_button'),
            onPressed: onRetry,
            child: const Text('もう一度読み込む'),
          ),
        ],
      ),
    );
  }
}

class _NoLiveView extends StatelessWidget {
  const _NoLiveView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('home_deadlines_no_live'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Text('ライブを追加すると、締切がここに出ます', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('home_deadlines_add_button'),
            onPressed: () => context.push('/lives/add'),
            icon: const Icon(Icons.add),
            label: const Text('ライブを追加する'),
          ),
        ],
      ),
    );
  }
}

class _ListView extends ConsumerWidget {
  const _ListView({required this.entries, required this.results});

  final List<DeadlineEntry> entries;
  final bool results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final prefix = results ? 'home_results' : 'home_deadlines';
    return Column(
      key: Key('${prefix}_list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in entries)
          _DeadlineTile(entry: e, now: now, results: results),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: Key('${prefix}_see_all_button'),
            onPressed: () => context.push('/lives'),
            child: const Text('すべて見る'),
          ),
        ),
      ],
    );
  }
}

class _DeadlineTile extends StatelessWidget {
  const _DeadlineTile({
    required this.entry,
    required this.now,
    required this.results,
  });

  final DeadlineEntry entry;
  final DateTime now;
  final bool results;

  /// 締切の種類ごとのアイコン
  static IconData _kindIcon(DeadlineKind kind) => switch (kind) {
    DeadlineKind.apply => Icons.edit_calendar_outlined,
    DeadlineKind.result => Icons.campaign_outlined,
    DeadlineKind.payment => Icons.payments_outlined,
  };

  /// 締切の種類ごとのチップの色（申込＝赤・当落＝黄・入金＝緑）
  static HakoChipKind _chipKind(DeadlineKind kind) => switch (kind) {
    DeadlineKind.apply => HakoChipKind.apply,
    DeadlineKind.result => HakoChipKind.draw,
    DeadlineKind.payment => HakoChipKind.pay,
  };

  @override
  Widget build(BuildContext context) {
    final reception = entry.deadline.reception;
    final action = describeNextDeadline(entry.deadline, now);
    final opens = action.opensText;
    final soon =
        !action.isUrgent &&
        entry.deadline.at.difference(now) <= const Duration(days: 7);
    // 次の締切は今までの Key のまま（Fe 3.3）
    final prefix = results ? 'home_result' : 'home_deadline';

    return HakoRow(
      key: Key('${prefix}_tile_${reception.id}'),
      // 急ぎ（24時間以内）は、色だけでなく警告のアイコンでも示す
      icon: action.isUrgent
          ? Icons.warning_amber_rounded
          : _kindIcon(entry.deadline.kind),
      title: entry.live.title,
      subs: [
        [
          reception.name,
          if (reception.winnersOnly && !reception.name.contains('当選者のみ'))
            '【当選者のみ】',
        ].join(' '),
        ?opens,
      ],
      // 近い締切（7日以内）の目印キーは、チップに付けて残す
      chip: HakoStatusChip(
        action.text,
        key: soon ? Key('${prefix}_soon_${reception.id}') : null,
        kind: _chipKind(entry.deadline.kind),
      ),
      onTap: () => context.push('/lives/${entry.live.id}'),
    );
  }
}
