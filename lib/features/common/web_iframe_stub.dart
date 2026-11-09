import 'package:flutter/material.dart';

import '../../theme/brand_colors.dart';

/// iframe を埋め込む（add_P 5.5）。Web 以外（テスト）では灰色の箱
class WebIframe extends StatelessWidget {
  const WebIframe({
    super.key,
    required this.src,
    this.aspectRatio = 16 / 9,
    this.title = '',
  });

  final String src;
  final double aspectRatio;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ColoredBox(color: BrandColors.paper),
    );
  }
}