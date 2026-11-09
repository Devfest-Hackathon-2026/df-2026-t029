import 'package:flutter/material.dart';

import '../../../theme/brand_colors.dart';
import '../../../theme/hako_fonts.dart';

/// 進み具合「n/4 入力済み」とバー（見本の `.prog`）。n は 0〜4
class MemoryProgressBar extends StatelessWidget {
  const MemoryProgressBar({super.key, required this.done});

  final int done;

  @override
  Widget build(BuildContext context) {
    final n = done.clamp(0, 4);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: '記録の完成度 $n/4',
      excludeSemantics: true,
      child: Row(
        children: [
          Text(
            '$n/4 入力済み',
            style: HakoFonts.jp(size: 13, weight: FontWeight.w700, height: 1.4),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: BrandColors.ink, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  duration: reduce
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  widthFactor: n * 0.25,
                  heightFactor: 1,
                  child: const ColoredBox(color: BrandColors.hall4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
