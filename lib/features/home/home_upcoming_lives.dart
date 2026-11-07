import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/live_providers.dart';
import '../../utils/deadline.dart';
import '../live_form/date_time_field.dart';
import 'home_horizontal_list.dart';
import 'home_section_header.dart';

/// ホームに出すライブの最大数
const _maxLives = 10;

/// ③ 今後のライブ（自分のライブ一覧のうち、終わっていないものを次の公演の近い順に）
class HomeUpcomingLives extends ConsumerWidget {
  const HomeUpcomingLives({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lives = ref.watch(liveListProvider);
    final now = ref.watch(nowProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: '今後のライブ',
          onSeeAll: () => context.go('/lives'),
        ),
        const SizedBox(height: 8),
        switch (lives) {
          AsyncValue(value: final list?) => _content(list, now),
          AsyncError() => const HomeSectionMessage('読み込めませんでした'),
          _ => const HomeSectionLoading(),
        },
      ],
    );
  }

  Widget _content(List<LiveListEntry> list, DateTime now) {
    final upcoming = [
      for (final e in list)
        if (!e.isEnded && e.nextStartAt != null) e,
    ]..sort((a, b) => a.nextStartAt!.compareTo(b.nextStartAt!));
    if (upcoming.isEmpty) {
      return const HomeSectionMessage('行きたいライブを追加すると、ここに出ます');
    }
    return HomeHorizontalList(
      key: const Key('home_upcoming_lives'),
      height: 150,
      itemWidth: 220,
      children: [
        for (final e in upcoming.take(_maxLives))
          _UpcomingLiveCard(entry: e, now: now),
      ],
    );
  }
}

/// 今日から公演日までの日数（日付で数える。今日なら 0）
int _daysUntil(DateTime now, DateTime at) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  return day.difference(today).inDays;
}

/// 今後のライブのカード
class _UpcomingLiveCard extends StatelessWidget {
  const _UpcomingLiveCard({required this.entry, required this.now});

  final LiveListEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = entry.nextStartAt!;
    final venue = entry.performances
            .where((p) => p.startAt == next)
            .firstOrNull
            ?.venue ??
        '';
    final days = _daysUntil(now, next);
    return Card(
      key: Key('home_upcoming_live_${entry.live.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/lives/${entry.live.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 7日以内なら日数を強調する
              if (days <= 7) ...[
                _DaysBadge(days: days),
                const SizedBox(height: 6),
              ],
              Text(
                entry.live.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              _IconText(icon: Icons.event, text: formatDateTime(next)),
              const SizedBox(height: 2),
              _IconText(icon: Icons.place, text: venue),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「あと◯日」「今日」の印
class _DaysBadge extends StatelessWidget {
  const _DaysBadge({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          days <= 0 ? '今日' : 'あと$days日',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}

/// アイコン付きの1行（はみ出しは省略）
class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}