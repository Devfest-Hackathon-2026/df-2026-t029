import 'package:flutter/material.dart';

import '../../../models/live_memory.dart';
import '../../../theme/brand_colors.dart';
import '../../../theme/hako_app_widgets.dart';
import '../../../theme/hako_fonts.dart';
import '../../common/storage_image.dart';
import '../../live_form/date_time_field.dart';
import 'ticket_widgets.dart';

/// 記録のチケット（4.2）。写真の欄・本文・ミシン目・半券。
/// 写真の欄の全体と、座席の「直す」がボタン
class MemoryTicketCard extends StatelessWidget {
  const MemoryTicketCard({
    super.key,
    required this.memory,
    required this.attended,
    required this.photosConnected,
    required this.onEditPhotos,
    required this.onEditSeat,
    this.seatEditing = false,
  });

  final LiveMemory memory;
  final bool attended;

  /// Google フォトにつないでいるか（写真が0枚のときのボタンの文言が変わる）
  final bool photosConnected;
  final VoidCallback onEditPhotos;
  final VoidCallback onEditSeat;

  /// 座席の編集カードが開いているか（読み上げ用）
  final bool seatEditing;

  @override
  Widget build(BuildContext context) {
    final m = memory;
    final seat = m.seat;
    final muted = HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.6);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: BrandColors.ink, offset: Offset(5, 5)),
        ],
      ),
      child: Container(
        key: const Key('memory_ticket'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BrandColors.ink, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PhotosArea(
              paths: m.images,
              connected: photosConnected,
              onTap: onEditPhotos,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      HakoTagChip(
                        attended ? '参戦済み' : '参戦予定',
                        key: const Key('memory_detail_state'),
                      ),
                      if (m.isPublic)
                        HakoTagChip(
                          m.publicSeat ? '公開中（座席も）' : '公開中',
                          key: const Key('memory_detail_public'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    m.liveTitle,
                    style: HakoFonts.jp(
                      size: 19,
                      weight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _MetaLine(
                    icon: Icons.calendar_today_outlined,
                    text: '${formatDateTime(m.startAt)} 開演',
                    style: muted,
                  ),
                  _MetaLine(
                    icon: Icons.place_outlined,
                    text: m.venue,
                    style: muted,
                  ),
                ],
              ),
            ),
            const _Perforation(),
            ColoredBox(
              color: BrandColors.hall4Soft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SEAT / 座席',
                            style: HakoFonts.jp(
                              size: 11,
                              weight: FontWeight.w700,
                              height: 1.4,
                              letterSpacing: 0.88,
                            ),
                          ),
                          Text(
                            seat ?? '未入力',
                            key: const Key('memory_detail_seat'),
                            style: HakoFonts.jp(
                              size: 17,
                              weight: FontWeight.w700,
                              height: 1.4,
                              color: seat == null
                                  ? BrandColors.sub
                                  : BrandColors.ink,
                            ),
                          ),
                          if (seat != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '参戦予定に登録した座席です。違っていれば書き換えられます。',
                                key: const Key('memory_ticket_seat_note'),
                                style: HakoFonts.jp(
                                  size: 12,
                                  color: BrandColors.sub,
                                  height: 1.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      button: true,
                      label: '座席を直す',
                      onTap: onEditSeat,
                      excludeSemantics: true,
                      child: TicketButton(
                        key: const Key('memory_ticket_seat_edit'),
                        label: '直す',
                        icon: Icons.edit_outlined,
                        small: true,
                        onPressed: onEditSeat,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
    required this.style,
  });

  final IconData icon;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: ExcludeSemantics(
            child: Icon(icon, size: 14, color: BrandColors.sub),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

/// ミシン目。破線と、左右の端の半円の切り欠き
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 6,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: DashedLinePainter()),
            ),
            for (final left in [true, false])
              Positioned(
                left: left ? -14 : null,
                right: left ? null : -14,
                top: 3 - 12,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: BrandColors.paper,
                    shape: BoxShape.circle,
                    border: Border.all(color: BrandColors.ink, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 写真の欄。写真があるときは「写真を直す」ボタン、0枚のときは全体がボタン
class _PhotosArea extends StatelessWidget {
  const _PhotosArea({
    required this.paths,
    required this.connected,
    required this.onTap,
  });

  final List<String> paths;
  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final top = paths.take(4).toList();
    final Widget content;
    if (top.isEmpty) {
      content = Container(
        height: 120,
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: BrandColors.hall4Soft,
          border: Border(bottom: BorderSide(color: BrandColors.ink, width: 2)),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '写真はまだありません',
              style: HakoFonts.jp(
                size: 14,
                weight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            // 全体がボタンなので、ここは見た目だけ
            DecoratedBox(
              decoration: BoxDecoration(
                color: BrandColors.hall4,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: BrandColors.ink, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_camera_outlined, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        connected ? '写真を追加' : 'Googleフォトとつなぐ',
                        style: HakoFonts.jp(
                          size: 13,
                          weight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      Widget cell(int i) => StorageImage(path: top[i]);
      const gap = SizedBox(width: 2, height: 2);
      final Widget grid;
      switch (top.length) {
        case 1:
          grid = cell(0);
        case 2:
          grid = Row(
            children: [
              Expanded(child: cell(0)),
              gap,
              Expanded(child: cell(1)),
            ],
          );
        case 3:
          grid = Row(
            children: [
              Expanded(flex: 2, child: cell(0)),
              gap,
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: cell(1)),
                    gap,
                    Expanded(child: cell(2)),
                  ],
                ),
              ),
            ],
          );
        default:
          grid = Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: cell(0)),
                    gap,
                    Expanded(child: cell(1)),
                  ],
                ),
              ),
              gap,
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: cell(2)),
                    gap,
                    Expanded(child: cell(3)),
                  ],
                ),
              ),
            ],
          );
      }
      final more = paths.length - 4;
      content = Container(
        height: 210,
        decoration: const BoxDecoration(
          color: BrandColors.ink,
          border: Border(bottom: BorderSide(color: BrandColors.ink, width: 2)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            grid,
            if (more > 0)
              Positioned(
                right: 8,
                bottom: 8,
                child: DecoratedBox(
                  key: const Key('memory_ticket_photos_more'),
                  decoration: BoxDecoration(
                    color: BrandColors.ink.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      '＋$more',
                      style: HakoFonts.jp(
                        size: 13,
                        weight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Semantics(
                button: true,
                label: '写真を直す',
                excludeSemantics: true,
                onTap: onTap,
                child: Material(
                  color: Colors.white,
                  shape: const StadiumBorder(
                    side: BorderSide(color: BrandColors.ink, width: 2),
                  ),
                  child: InkWell(
                    key: const Key('memory_ticket_photos'),
                    customBorder: const StadiumBorder(),
                    onTap: onTap,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_outlined, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '写真を直す',
                              style: HakoFonts.jp(
                                size: 13,
                                weight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (top.isNotEmpty) {
      return Container(
        key: const Key('memory_detail_photos'),
        constraints: const BoxConstraints(minHeight: 44),
        child: content,
      );
    }
    return Semantics(
      button: true,
      label: '写真を直す',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        key: const Key('memory_ticket_photos'),
        onTap: onTap,
        child: Container(
          key: const Key('memory_detail_photos'),
          constraints: const BoxConstraints(minHeight: 44),
          child: content,
        ),
      ),
    );
  }
}

/// セトリ・感想の枠（破線。入っていれば実線）。全体がボタン
class TicketBlankFrame extends StatelessWidget {
  const TicketBlankFrame({
    super.key,
    required this.title,
    required this.hint,
    required this.filled,
    required this.onTap,
    this.body,
  });

  /// 「セトリ」「感想」
  final String title;

  /// 空のときのヒント
  final String hint;
  final bool filled;
  final VoidCallback onTap;

  /// 入っているときの中身
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    final head = filled
        ? Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: HakoFonts.jp(
                    size: 14,
                    weight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BrandColors.ink, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_outlined, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '直す',
                        style: HakoFonts.jp(
                          size: 12,
                          weight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        : Row(
            children: [
              const Icon(Icons.edit_outlined, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$titleを書く',
                  style: HakoFonts.jp(
                    size: 14,
                    weight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          );
    final inner = Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: filled ? Border.all(color: BrandColors.ink, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          head,
          const SizedBox(height: 4),
          if (filled)
            ?body
          else
            Text(
              hint,
              style: HakoFonts.jp(
                size: 13,
                color: BrandColors.sub,
                height: 1.6,
              ),
            ),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: '$titleを直す',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: filled
            ? inner
            : CustomPaint(
                foregroundPainter: const DashedBorderPainter(),
                child: inner,
              ),
      ),
    );
  }
}
