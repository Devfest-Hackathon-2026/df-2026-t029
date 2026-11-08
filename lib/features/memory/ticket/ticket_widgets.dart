import 'package:flutter/material.dart';

import '../../../theme/brand_colors.dart';
import '../../../theme/hako_fonts.dart';

/// AI の説明（紫）の色。共通の色には無いので、ここだけの定数にする（計画書 4.0）
const Color kAiSoft = Color(0xFFF3EAFF);
const Color kAiChip = Color(0xFFEADCFF);

/// 記録のチケットまわりのボタンの種類
enum TicketButtonKind {
  /// 緑（決定・つなぐ）
  green,

  /// 紙の色（枠だけ）
  out,

  /// 墨（まとめて編集して投稿・Xに投稿）
  dark,
}

/// 記録のチケット・写真のシートで使う丸いボタン（枠 2px・太さ 700）。
/// タップの範囲は 44px 以上
class TicketButton extends StatelessWidget {
  const TicketButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = TicketButtonKind.out,
    this.small = false,
    this.wide = false,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final TicketButtonKind kind;

  /// 小さいボタン（見た目の高さ 40。押せる範囲は 44）
  final bool small;

  /// 横幅いっぱいにする
  final bool wide;

  /// 開いたときにフォーカスを受ける（ダイアログの「つなぐ」）
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      TicketButtonKind.green => (BrandColors.hall4, BrandColors.ink),
      TicketButtonKind.out => (BrandColors.paper, BrandColors.ink),
      TicketButtonKind.dark => (BrandColors.ink, Colors.white),
    };
    final enabled = onPressed != null;
    final style = FilledButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      disabledBackgroundColor: bg.withValues(alpha: 0.45),
      disabledForegroundColor: fg.withValues(alpha: 0.6),
      minimumSize: Size(wide ? double.infinity : 64, small ? 44 : 48),
      padding: EdgeInsets.symmetric(horizontal: small ? 14 : 20),
      side: BorderSide(
        color: BrandColors.ink.withValues(alpha: enabled ? 1 : 0.45),
        width: 2,
      ),
      shape: const StadiumBorder(),
      tapTargetSize: MaterialTapTargetSize.padded,
      textStyle: HakoFonts.jp(
        size: small ? 13 : 15,
        weight: FontWeight.w700,
        height: 1.3,
      ),
    );
    final text = Text(label, textAlign: TextAlign.center);
    return icon == null
        ? FilledButton(
            onPressed: onPressed,
            style: style,
            autofocus: autofocus,
            child: text,
          )
        : FilledButton.icon(
            onPressed: onPressed,
            style: style,
            autofocus: autofocus,
            icon: Icon(icon, size: small ? 16 : 20),
            label: text,
          );
  }
}

/// 下線つきの文字のボタン（見本の `.linkbtn`）。タップの範囲は 44px 以上
class TicketLinkButton extends StatelessWidget {
  const TicketLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        textStyle: HakoFonts.jp(
          size: 13,
          weight: FontWeight.w700,
          height: 1.3,
        ).copyWith(decoration: TextDecoration.underline),
      ),
      child: Text(label),
    );
  }
}

/// 破線の枠（角丸）を描く。Flutter の標準には破線の枠が無いため
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    this.color = BrandColors.ink,
    this.width = 2,
    this.radius = 12,
    this.dash = 6,
    this.gap = 4,
  });

  final Color color;
  final double width;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final rect = Rect.fromLTWH(
      width / 2,
      width / 2,
      size.width - width,
      size.height - width,
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      color != old.color ||
      width != old.width ||
      radius != old.radius ||
      dash != old.dash ||
      gap != old.gap;
}

/// 横の破線（ミシン目）を描く
class DashedLinePainter extends CustomPainter {
  const DashedLinePainter({this.width = 2.5, this.dash = 6, this.gap = 4});

  final double width;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BrandColors.ink
      ..strokeWidth = width;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dash).clamp(0.0, size.width), y),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(DashedLinePainter old) =>
      width != old.width || dash != old.dash || gap != old.gap;
}
