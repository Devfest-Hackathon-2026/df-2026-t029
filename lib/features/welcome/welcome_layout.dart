// 紹介ページ（/welcome）だけで使う、幅の区切り・色・書体の近道・共通の部品。
// 共有の土台（lib/theme/**）は読むだけで、足りないものはここに作る。

import 'package:flutter/material.dart';

import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';

/// 幅の区切り（CSS の @media (max-width: …) と同じ。MediaQuery の幅で決める）
abstract final class WelcomeBreakpoints {
  /// 以下: ハコ 2 列・困りごと／期限の流れは 1 列
  static const double tablet = 760;

  /// 以下: ハコ 1 列・左右の余白 18・ボタンの文字 21
  static const double phone = 520;

  /// 困りごと・期限の流れを縦に積むか
  static bool isStacked(double width) => width <= tablet;

  static bool isPhone(double width) => width <= phone;

  static int tileColumns(double width) =>
      width <= phone ? 1 : (width <= tablet ? 2 : 3);
}

/// 紹介ページの中だけで使う色（BrandColors に無いもの）
abstract final class WelcomeColors {
  /// 見出しの上の英字（紙の上。コントラスト 4.94:1）
  static const eyebrow = Color(0xFF6B6B6B);

  /// 掲示板の見出しの下線
  static const rule = Color(0xFF444444);

  /// 黒い区画の小さな補足
  static const muted = Color(0xFFAAAAAA);
}

/// CSS の clamp(min, vw, max)
double welcomeClamp(
  double width, {
  required double min,
  required double vw,
  required double max,
}) => (width * vw / 100).clamp(min, max).toDouble();

/// HakoFonts.jp を、行の高さの既定 1.7 で呼ぶ（HTML の body の line-height）
TextStyle welcomeJp({
  required double size,
  FontWeight weight = FontWeight.w400,
  Color color = BrandColors.ink,
  double height = 1.7,
  double letterSpacing = 0,
}) => HakoFonts.jp(
  size: size,
  weight: weight,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
);

/// HakoFonts.en を、行の高さの既定 1.7 で呼ぶ
TextStyle welcomeEn({
  required double size,
  FontWeight weight = FontWeight.w800,
  Color color = BrandColors.ink,
  double height = 1.7,
  double letterSpacing = 0,
}) => HakoFonts.en(
  size: size,
  weight: weight,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
);

/// .wrap: 最大幅 960（左右の余白込み）・中央・左右の余白 24（幅 520 以下は 18）
class WelcomeWrap extends StatelessWidget {
  const WelcomeWrap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = WelcomeBreakpoints.isPhone(width) ? 18.0 : 24.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          // 幅いっぱいに広げる（左寄せの子が中央にずれないように）
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

/// 区画の見出し（英字・見出し・説明）。見出しは Semantics(header: true)。
/// 上下の余白は 4.5 の表の値を呼ぶ側が渡す
class WelcomeSectionTitle extends StatelessWidget {
  const WelcomeSectionTitle({
    super.key,
    required this.eyebrow,
    required this.title,
    this.body,
    this.topPadding = 56,
    this.bottomPadding = 20,
  });

  final String eyebrow;
  final String title;
  final String? body;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = welcomeClamp(width, min: 26, vw: 4.4, max: 36);
    return WelcomeWrap(
      child: Padding(
        padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Text(
                eyebrow,
                style: welcomeEn(
                  size: 12,
                  color: WelcomeColors.eyebrow,
                  letterSpacing: 1.92,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Semantics(
              header: true,
              child: Text(
                title,
                style: welcomeJp(
                  size: titleSize,
                  weight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 672),
                child: Text(body!, style: welcomeJp(size: 16)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 蛍光ペン（4.2）。style の fontSize・height から帯の位置を決める
class WelcomeMark extends StatelessWidget {
  const WelcomeMark({
    super.key,
    required this.text,
    required this.style,
    required this.color,
  });

  final String text;

  /// fontSize・height を持つこと
  final TextStyle style;

  /// 帯の色
  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 16;
    final lineHeight = style.height ?? 1.0;
    final bottom = (lineHeight - 1.0) / 2 * size;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: bottom,
          height: size * 0.2,
          child: ExcludeSemantics(child: ColoredBox(color: color)),
        ),
        Padding(
          padding: EdgeInsets.only(right: size * 0.15),
          child: Text(text, style: style),
        ),
      ],
    );
  }
}

/// 同じ行の高さをそろえる格子（4.3）。セルは決まった幅の SizedBox（Expanded にしない）
class WelcomeGrid extends StatelessWidget {
  const WelcomeGrid({
    super.key,
    required this.columns,
    required this.itemCount,
    required this.itemBuilder,
    this.gap = 0,
  });

  final int columns;
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// 列の間・行の間
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = columns < 1 ? 1 : columns;
        final cellWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
        final rows = <Widget>[];
        for (var start = 0; start < itemCount; start += cols) {
          final cells = <Widget>[];
          for (var i = 0; i < cols; i++) {
            final index = start + i;
            if (i > 0) cells.add(SizedBox(width: gap));
            cells.add(
              SizedBox(
                width: cellWidth,
                child: index < itemCount
                    ? itemBuilder(context, index)
                    : const SizedBox.shrink(),
              ),
            );
          }
          if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cells,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

/// 色つきの全幅の帯（黒い帯）。中身は呼ぶ側が WelcomeWrap で包む
class WelcomeBand extends StatelessWidget {
  const WelcomeBand({
    super.key,
    required this.color,
    required this.padding,
    required this.child,
  });

  final Color color;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Padding(padding: padding, child: child),
    );
  }
}
