import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/live_providers.dart';
import '../../utils/deadline.dart';
import 'deadline_format.dart';

/// ホームに出す「次の締切」の件数
const homeDeadlineLimit = 5;

/// ホームの「次の締切」（近い順に5件まで）
///
/// スクロールする親（ListView など）の中に置く前提で、自分ではスクロールしない。
class UpcomingDeadlinesSection extends ConsumerWidget {
  const UpcomingDeadlinesSection({super.key});

  void _retry(WidgetRef ref) {
    ref.invalidate(myLiveIdsProvider);
    ref.invalidate(myLivesProvider);
    ref.invalidate(myReceptionsProvider);
    ref.invalidate(applicationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myIds = ref.watch(myLiveIdsProvider);
    final deadlines = ref.watch(upcomingDeadlinesProvider);

    // 自分のライブ一覧の読み込みが先。0件なら締切は問い合わせない
    return switch ((myIds, deadlines)) {
      (AsyncError(), _) ||
      (_, AsyncError()) => _ErrorView(onRetry: () => _retry(ref)),
      (AsyncValue(value: final t?), _) when t.isEmpty => const _NoLiveView(),
      (AsyncValue(value: _?), AsyncValue(value: final list?))
          when list.isEmpty =>
        const Padding(
          key: Key('home_deadlines_empty'),
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('近い締切はありません', textAlign: TextAlign.center),
        ),
      (AsyncValue(value: _?), AsyncValue(value: final list?)) => _ListView(
        entries: list.take(homeDeadlineLimit).toList(),
      ),
      _ => const Padding(
        key: Key('home_deadlines_loading'),
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('home_deadlines_error'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Text('締切を読み込めませんでした', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('home_deadlines_retry_button'),
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
  const _ListView({required this.entries});

  final List<DeadlineEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    return Column(
      key: const Key('home_deadlines_list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in entries) _DeadlineTile(entry: e, now: now),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('home_deadlines_see_all_button'),
            onPressed: () => context.push('/lives'),
            child: const Text('すべて見る'),
          ),
        ),
      ],
    );
  }
}

class _DeadlineTile extends StatelessWidget {
  const _DeadlineTile({required this.entry, required this.now});

  final DeadlineEntry entry;
  final DateTime now;

  /// 締切の種類ごとのアイコン（急ぎでないときに出す）
  static IconData _kindIcon(DeadlineKind kind) => switch (kind) {
        DeadlineKind.apply => Icons.edit_calendar,
        DeadlineKind.result => Icons.campaign,
        DeadlineKind.payment => Icons.payments,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reception = entry.deadline.reception;
    final action = describeNextDeadline(entry.deadline, now);
    // 急ぎ：24時間以内（RemainingLabel の判定と同じ）
    final urgent = action.isUrgent;
    // 近い：7日以内（24時間より先）
    final soon =
        !urgent && entry.deadline.at.difference(now) <= const Duration(days: 7);
    final opens = action.opensText;

    final Widget remaining;
    if (urgent) {
      remaining = Text(
        action.text,
        style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold),
      );
    } else if (soon) {
      // 近い締切は、小さな印で囲んで目立たせる
      remaining = Align(
        alignment: Alignment.centerLeft,
        child: Container(
          key: Key('home_deadline_soon_${reception.id}'),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            action.text,
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else {
      remaining = Text(action.text);
    }

    return ListTile(
      key: Key('home_deadline_tile_${reception.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        urgent ? Icons.warning_amber_rounded : _kindIcon(entry.deadline.kind),
        color: urgent ? scheme.error : scheme.primary,
      ),
      title: Text(entry.live.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [reception.name, if (reception.winnersOnly) '【当選者のみ】'].join(' '),
          ),
          remaining,
          if (opens != null) Text(opens),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/lives/${entry.live.id}'),
    );
  }
}