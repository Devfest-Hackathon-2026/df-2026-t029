import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/live_providers.dart';
import '../../providers/trip_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../travel/trip_sheet.dart';
import '../travel/weather_line.dart';
import 'home_section_header.dart';

/// 次の遠征（add_E 6章）。これからの遠征の最初の1件を出し、「すべて見る」で /trips。
/// これからの遠征が無い（読み込み中・エラーも）ときは区画ごと出さない
class HomeNextTrip extends ConsumerWidget {
  const HomeNextTrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(tripPlansProvider).value?.upcoming.firstOrNull;
    if (next == null) return const SizedBox.shrink();
    final now = ref.watch(nowProvider);
    final p = next.performance;
    final trip = next.trip;
    final time =
        '${p.startAt.hour.toString().padLeft(2, '0')}:${p.startAt.minute.toString().padLeft(2, '0')}';
    final sub = HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: '次の遠征',
          onSeeAll: () => context.go('/trips'),
        ),
        Card(
          key: const Key('home_next_trip'),
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go('/trips'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HakoDateBadge(date: p.startAt),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          next.liveTitle,
                          style: HakoFonts.jp(
                            size: 13,
                            weight: FontWeight.w700,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$time 開演 ・ ${p.venue}',
                          style: sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        WeatherLine(performance: p, now: now),
                        Text(
                          trip == null ? '遠征メモはまだありません' : tripSummary(trip),
                          style: trip == null
                              ? sub
                              : sub.copyWith(
                                  color: BrandColors.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}