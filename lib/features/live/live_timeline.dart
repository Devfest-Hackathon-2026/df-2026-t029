import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/deadline.dart';
import '../live_form/date_time_field.dart';

/// 今後のライブの日付の行（例：次の公演 11/20 18:00（全2公演））
String upcomingDateLine(LiveListEntry e) {
  final next = e.nextStartAt;
  if (next == null) return '公演の日程は未登録です';
  final count = e.performances.length;
  final rest = count > 1 ? '（全$count公演）' : '';
  final p = e.nextPerformance;
  return '次の公演 ${p != null ? formatPerformanceStart(p) : formatDateTime(next)}$rest';
}

/// ライブ一覧のタイムラインの1行（Fd 3.2）。
/// 左に縦の線（墨 2px）と丸印（直径 12）。[filled] なら丸を墨で塗る。
/// 線は最初の丸から最後の丸までつなぐ（[isFirst]・[isLast]）。
/// [trailing] は右端に置く部品（推しの今後のライブの「追加済」「追加する！」）
class LiveTimelineItem extends StatelessWidget {
  const LiveTimelineItem({
    super.key,
    required this.entry,
    required this.performers,
    this.isFirst = false,
    this.isLast = false,
    this.filled = false,
    this.trailing,
  });

  final LiveListEntry entry;
  final List<String> performers;
  final bool isFirst;
  final bool isLast;
  final bool filled;
  final Widget? trailing;

  /// 丸の中心の高さ（ライブ名の1行目にそろえる）
  static const double _dotTop = 19;
  static const double _dotSize = 12;
  static const double _railWidth = 24;

  @override
  Widget build(BuildContext context) {
    final live = entry.live;
    final p = performers.join('、');
    final sub = HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.5);

    return InkWell(
      key: Key('live_timeline_item_${live.id}'),
      onTap: () => context.push('/lives/${live.id}'),
      overlayColor: WidgetStatePropertyAll(
        BrandColors.ink.withValues(alpha: 0.10),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _railWidth,
              child: Stack(
                children: [
                  // 縦の線：最初の行は丸から下、最後の行は丸まで
                  if (!(isFirst && isLast))
                    Positioned(
                      left: (_railWidth - 2) / 2,
                      width: 2,
                      top: isFirst ? _dotTop : 0,
                      bottom: isLast ? null : 0,
                      height: isLast ? _dotTop : null,
                      child: const ColoredBox(color: BrandColors.ink),
                    ),
                  Positioned(
                    left: (_railWidth - _dotSize) / 2,
                    top: _dotTop - _dotSize / 2,
                    child: Container(
                      width: _dotSize,
                      height: _dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? BrandColors.ink : BrandColors.surface,
                        border: Border.all(color: BrandColors.ink, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      live.title,
                      style: HakoFonts.jp(size: 15, height: 1.5),
                    ),
                    if (p.isNotEmpty) Text(p, style: sub),
                    Text(upcomingDateLine(entry), style: sub),
                  ],
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              Center(child: trailing),
            ],
          ],
        ),
      ),
    );
  }
}
