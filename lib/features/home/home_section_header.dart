import 'package:flutter/material.dart';

import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../../theme/brand_colors.dart';

/// ホームの区画の見出し（蛍光ペン付き）。onSeeAll を渡すと、右に「すべて見る」を出す
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({super.key, required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return HakoSectionHeader(
      title,
      trailingLabel: onSeeAll == null ? null : 'すべて見る',
      onTrailing: onSeeAll,
    );
  }
}

/// 区画の中に出す案内・エラーの文言
class HomeSectionMessage extends StatelessWidget {
  const HomeSectionMessage(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.6),
      ),
    );
  }
}

/// 区画の読み込み中
class HomeSectionLoading extends StatelessWidget {
  const HomeSectionLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
