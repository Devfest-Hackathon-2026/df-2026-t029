import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import 'help_topic.dart';

/// PC の幅（720 以上）のとき、シートの最大幅
const double kHelpSheetMaxWidth = 640;

const double _wideBreakpoint = 720;

/// 4.3 のシートを下から開く。閉じたら完了する。
Future<void> showHelpSheet(BuildContext context, HelpTopic topic) {
  final media = MediaQuery.of(context);
  final wide = media.size.width >= _wideBreakpoint;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: BrandColors.ink.withValues(alpha: 0.45),
    constraints: BoxConstraints(
      maxWidth: wide ? kHelpSheetMaxWidth : double.infinity,
      maxHeight: media.size.height * 0.82,
    ),
    sheetAnimationStyle: media.disableAnimations
        ? AnimationStyle.noAnimation
        : null,
    builder: (sheetContext) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(sheetContext).maybePop(),
      },
      child: Focus(autofocus: true, child: HelpSheetBody(topic: topic)),
    ),
  );
}

/// シートの中身
class HelpSheetBody extends StatelessWidget {
  const HelpSheetBody({super.key, required this.topic});

  final HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    final items = topic.items;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: '${topic.label}の使い方',
      child: DecoratedBox(
        key: const Key('help_sheet'),
        decoration: const BoxDecoration(
          color: BrandColors.paper,
          border: Border(
            top: BorderSide(color: BrandColors.ink, width: 2),
            left: BorderSide(color: BrandColors.ink, width: 2),
            right: BorderSide(color: BrandColors.ink, width: 2),
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: BrandColors.ink.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 22,
                      decoration: BoxDecoration(
                        color: topic.hue,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: BrandColors.ink, width: 2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${topic.label}の使い方',
                        style: HakoFonts.jp(
                          size: 18,
                          weight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'この画面でできること',
                style: HakoFonts.jp(
                  size: 13,
                  color: BrandColors.sub,
                  height: 1.5,
                ),
              ),
              if (topic.legend != HelpLegend.none) ...[
                const SizedBox(height: 10),
                _Legend(legend: topic.legend),
              ],
              const SizedBox(height: 16),
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _ItemCard(
                  key: Key('help_sheet_item_$i'),
                  number: i + 1,
                  item: items[i],
                  hue: topic.hue,
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton(
                  key: const Key('help_sheet_close'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: BrandColors.ink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(
                      side: BorderSide(color: BrandColors.ink, width: 2),
                    ),
                  ),
                  child: Text(
                    'とじる',
                    style: HakoFonts.jp(
                      size: 15,
                      weight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.number,
    required this.item,
    required this.hue,
  });

  final int number;
  final HelpItem item;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandColors.ink, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hue,
                shape: BoxShape.circle,
                border: Border.all(color: BrandColors.ink, width: 2),
              ),
              child: Text(
                '$number',
                style: HakoFonts.jp(
                  size: 14,
                  weight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              container: true,
              label: '$number. ${item.title}。${item.body}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: HakoFonts.jp(
                      size: 15,
                      weight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    style: HakoFonts.jp(
                      size: 14,
                      color: BrandColors.sub,
                      height: 1.65,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 凡例（ホームの締切の色、グッズ交換の「譲」「求」）
class _Legend extends StatelessWidget {
  const _Legend({required this.legend});

  final HelpLegend legend;

  @override
  Widget build(BuildContext context) {
    final body = switch (legend) {
      HelpLegend.deadlines => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: const [
          _Tag('申込期限', BrandColors.hall1),
          _Tag('入金期限', BrandColors.hall4),
          _Tag('当落発表', BrandColors.hall3),
        ],
      ),
      HelpLegend.giveWant => Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const _Tag('譲', BrandColors.hall6Soft),
          _LegendText('手放せるグッズ'),
          const _Tag('求', BrandColors.hall3),
          _LegendText('ほしいグッズ'),
        ],
      ),
      HelpLegend.none => const SizedBox.shrink(),
    };
    return KeyedSubtree(key: const Key('help_sheet_legend'), child: body);
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BrandColors.ink, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: HakoFonts.jp(size: 12, weight: FontWeight.w700, height: 1.5),
        ),
      ),
    );
  }
}

class _LegendText extends StatelessWidget {
  const _LegendText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: HakoFonts.jp(size: 13, height: 1.5));
}
