import 'package:flutter/material.dart';

import '../../models/trade_post.dart';
import '../common/storage_image.dart';
import 'trade_post_summary.dart';

/// [child] の右に、投稿の1枚目の写真を 56×56 で出す（G-7 仕様書 6.4）。
/// 写真が無ければ [child] だけ
class TradePostWithThumb extends StatelessWidget {
  const TradePostWithThumb({
    super.key,
    required this.post,
    required this.child,
  });

  final TradePost post;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = firstPhotoOf(post);
    if (path == null) return child;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: child),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          height: 56,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: StorageImage(path: path),
          ),
        ),
      ],
    );
  }
}