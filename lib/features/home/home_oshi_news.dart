import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/oshi_news.dart';
import '../../providers/favorite_oshi_providers.dart';
import '../../providers/live_providers.dart';
import '../../providers/oshi_news_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../live/official_url_link.dart' show urlLauncherProvider;
import '../oshi/oshi_detail_page.dart' show oshiPagePath;

/// 「今日」「昨日」「◯日前」（端末の日付で数える）
String newsAgo(DateTime at, DateTime now) {
  final a = at.toLocal();
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(a.year, a.month, a.day))
      .inDays;
  if (days <= 0) return '今日';
  if (days == 1) return '昨日';
  return '$days日前';
}

/// ホームのお知らせ（add_P 5.3）：最推しと所属グループの新着（14日以内・最大5件）。
/// 最推しがいない・新着が無いときは何も出さない
class HomeOshiNews extends ConsumerWidget {
  const HomeOshiNews({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oshi = ref.watch(favoriteOshiProvider);
    final news = ref.watch(favoriteOshiNewsProvider);
    if (oshi == null || news.isEmpty) return const SizedBox.shrink();
    final now = ref.watch(nowProvider);

    return Column(
      key: const Key('home_oshi_news'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HakoSectionHeader(
          'お知らせ',
          trailingLabel: '推しのページ',
          onTrailing: () => context.push(oshiPagePath(oshi)),
        ),
        for (final n in news) _NewsRow(news: n, now: now),
      ],
    );
  }
}

/// お知らせの1行：アイコン・札・推しの名前と日・タイトル
class _NewsRow extends ConsumerWidget {
  const _NewsRow({required this.news, required this.now});

  final OshiNews news;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideo = news.type == OshiNewsType.youtube;
    return InkWell(
      key: Key('home_oshi_news_${news.id}'),
      onTap: () {
        if (isVideo) {
          ref.read(urlLauncherProvider)(Uri.parse(news.videoUrl!));
        } else {
          context.push('/lives/${news.liveId}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: BrandColors.rowLine)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isVideo
                  ? Icons.smart_display_outlined
                  : Icons.confirmation_number_outlined,
              size: 26,
              color: BrandColors.ink,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      HakoTagChip(news.type.label),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${news.oshiName}・${newsAgo(news.publishedAt, now)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HakoFonts.jp(
                            size: 12,
                            color: BrandColors.sub,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    news.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HakoFonts.jp(size: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}