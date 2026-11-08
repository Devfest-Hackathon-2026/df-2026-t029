import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/help_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import 'help_scope.dart';
import 'help_topic.dart';

/// 初回の吹き出し（4.4）。条件を満たさないときは何も描かない。
/// AppShell が、画面の上に重ねて置く。
class HelpCoach extends ConsumerWidget {
  const HelpCoach({super.key, required this.wide});

  /// 幅 720 以上（「?」が左のタブの下にあるとき）
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = HakoHelpScope.maybeOf(context);
    final visible = ref.watch(helpCoachVisibleProvider);
    if (scope == null || scope.topic != HelpTopic.home || !visible) {
      return const SizedBox.shrink();
    }
    final text = wide
        ? 'はじめての方へ。左下の「?」から、使い方を見られます。'
        : 'はじめての方へ。画面右上の「?」から、使い方を見られます。';

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BrandColors.ink,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: HakoFonts.jp(size: 13, color: Colors.white, height: 1.55),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              key: const Key('help_coach_ok'),
              onTap: () =>
                  ref.read(helpCoachVisibleProvider.notifier).dismiss(),
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                child: Center(
                  widthFactor: 1,
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'わかった',
                      style: HakoFonts.jp(
                        size: 13,
                        weight: FontWeight.w700,
                        color: BrandColors.ink,
                        height: 1.2,
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

    final Widget body;
    final Alignment targetAnchor;
    final Alignment followerAnchor;
    final Offset offset;
    if (wide) {
      // 「?」の右に出す。三角は左を向く
      body = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CustomPaint(size: const Size(8, 16), painter: _TrianglePainter(true)),
          bubble,
        ],
      );
      targetAnchor = Alignment.centerRight;
      followerAnchor = Alignment.centerLeft;
      // 円の端から三角の先まで 12（ボタンの余白 4 + 8）
      offset = const Offset(8, 0);
    } else {
      // 「?」の下に出す。三角は「?」の真下を指す
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 60),
            child: CustomPaint(
              size: const Size(16, 8),
              painter: _TrianglePainter(false),
            ),
          ),
          bubble,
        ],
      );
      targetAnchor = Alignment.bottomLeft;
      followerAnchor = Alignment.topRight;
      // 「?」の中心（ボタンの左から 22）の右 68
      offset = const Offset(22 + 68, 4);
    }

    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: scope.link,
        showWhenUnlinked: false,
        targetAnchor: targetAnchor,
        followerAnchor: followerAnchor,
        offset: offset,
        child: Semantics(
          key: const Key('help_coach'),
          liveRegion: true,
          container: true,
          child: Material(type: MaterialType.transparency, child: body),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.pointLeft);

  final bool pointLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointLeft) {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height / 2)
        ..lineTo(size.width, size.height);
    } else {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = BrandColors.ink);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.pointLeft != pointLeft;
}
