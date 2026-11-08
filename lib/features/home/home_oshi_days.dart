import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/oshi_days.dart';
import '../../providers/live_providers.dart';
import '../../providers/oshi_days_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/oshi_anniversary.dart';
import '../oshi/oshi_list_tile.dart';
import 'home_section_header.dart';

/// これからの記念日を出す最大の件数
const _maxUpcoming = 3;

/// 記念日の名前（例：「星宮ルナの誕生日」「空野カナタを推して300日」）
String oshiEventTitle(OshiEvent e) {
  final name = e.oshi.name;
  return switch (e.kind) {
    OshiEventKind.birthday => '$nameの誕生日',
    OshiEventKind.formation => '$nameの結成記念日',
    OshiEventKind.years => '$nameを推して${e.count}年',
    OshiEventKind.days => '$nameを推して${e.count}日',
  };
}

/// 推しの記念日（add_O 3.3）。今日の記念日を黄色の箱で、7日以内のものを行で出す。
/// どちらも無ければ区画ごと出さない
class HomeOshiDays extends ConsumerWidget {
  const HomeOshiDays({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(followingOshisProvider).value ?? const [];
    final days = ref.watch(oshiDaysProvider).value ?? OshiDays.empty;
    final events = oshiEventsWithin(following, days, ref.watch(nowProvider));
    if (events.isEmpty) return const SizedBox.shrink();
    final today = [
      for (final e in events)
        if (e.daysAway == 0) e,
    ];
    final upcoming = [
      for (final e in events)
        if (e.daysAway > 0) e,
    ].take(_maxUpcoming).toList();

    return Column(
      key: const Key('home_oshi_days'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HomeSectionHeader(title: '推しの記念日'),
        for (final e in today) _TodayBox(event: e),
        for (final e in upcoming) _UpcomingRow(event: e),
      ],
    );
  }
}

/// 今日の記念日（黄色の箱）
class _TodayBox extends StatelessWidget {
  const _TodayBox({required this.event});

  final OshiEvent event;

  @override
  Widget build(BuildContext context) {
    final name = event.oshi.name;
    final text = switch (event.kind) {
      OshiEventKind.birthday => '今日は$nameの誕生日！',
      OshiEventKind.formation => '今日は$nameの結成記念日！',
      _ => '${oshiEventTitle(event)}！',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        key: Key('home_oshi_day_today_${event.oshi.id}_${event.kind.name}'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BrandColors.hall3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.ink, width: 2),
        ),
        child: Row(
          children: [
            OshiKindBadge(oshi: event.oshi, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: HakoFonts.jp(size: 16, weight: FontWeight.w700, height: 1.4),
              ),
            ),
            const Text('🎉', style: TextStyle(fontSize: 22)),
          ],
        ),
      ),
    );
  }
}

/// これからの記念日の1行（例：「あと3日：空野カナタの誕生日（11/11）」）
class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.event});

  final OshiEvent event;

  @override
  Widget build(BuildContext context) {
    final date = event.date;
    return Padding(
      key: Key('home_oshi_day_upcoming_${event.oshi.id}_${event.kind.name}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          OshiKindBadge(oshi: event.oshi, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'あと${event.daysAway}日：${oshiEventTitle(event)}'
              '（${date.month}/${date.day}）',
              style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}