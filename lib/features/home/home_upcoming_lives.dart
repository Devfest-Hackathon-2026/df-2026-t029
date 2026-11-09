import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/live_providers.dart';
import '../../utils/deadline.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
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
          title: '今後参戦するライブ',
          onSeeAll: () => context.go('/lives'),
        ),
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
      height: 130,
      itemWidth: 224,
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

/// 今後のライブのカード（左に日付の札、右に「あと○日」とライブ名、下に時刻と会場）
class _UpcomingLiveCard extends StatelessWidget {
  const _UpcomingLiveCard({required this.entry, required this.now});

  final LiveListEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final next = entry.nextStartAt!;
    final venue =
        entry.performances.where((p) => p.startAt == next).firstOrNull?.venue ??
        '';
    final days = _daysUntil(now, next);
    final time = entry.nextPerformance?.startTimeUnknown == true
        ? '時間未定'
        : '${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}';
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HakoDateBadge(date: next),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 7日以内なら日数を強調する
                        if (days <= 7)
                          HakoCountBadge(days <= 0 ? '今日' : 'あと$days日'),
                        Text(
                          entry.live.title,
                          style: HakoFonts.jp(
                            size: 13,
                            weight: FontWeight.w700,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _IconText(
                icon: Icons.schedule,
                text: venue.isEmpty ? time : '$time ・ $venue',
              ),
            ],
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
    return Row(
      children: [
        Icon(icon, size: 16, color: BrandColors.ink),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
