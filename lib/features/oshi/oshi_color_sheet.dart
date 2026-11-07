import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/oshi.dart';
import '../../providers/oshi_color_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import '../profile/theme_color_picker.dart';

/// 推しの色を選ぶシート（Fc 5.3）。選ぶとすぐ保存して閉じる
Future<void> showOshiColorSheet(BuildContext context, OshiSummary oshi) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (_) => _OshiColorSheet(oshi: oshi),
  );
}

class _OshiColorSheet extends ConsumerStatefulWidget {
  const _OshiColorSheet({required this.oshi});

  final OshiSummary oshi;

  @override
  ConsumerState<_OshiColorSheet> createState() => _OshiColorSheetState();
}

class _OshiColorSheetState extends ConsumerState<_OshiColorSheet> {
  bool _saving = false;

  Future<void> _save(Color? color) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || _saving) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(oshiColorRepositoryProvider)
          .setColor(
            uid,
            oshiColorKey(widget.oshi.kind, widget.oshi.id),
            color?.toARGB32(),
          );
      navigator.pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('色を保存できませんでした。もう一度お試しください')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final oshi = widget.oshi;
    final colors = ref.watch(oshiColorsProvider).value ?? const {};
    final own = colors[oshiColorKey(oshi.kind, oshi.id)];

    Widget swatch({
      required String label,
      required Color? color,
      required bool selected,
    }) {
      return Tooltip(
        message: label,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _saving ? null : () => _save(color),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? BrandColors.surface,
              border: Border.all(color: BrandColors.ink, width: 2),
            ),
            child: selected
                ? Icon(
                    Icons.check,
                    color: color == null ? BrandColors.ink : onThemeColor(color),
                  )
                : (color == null
                      ? const Icon(Icons.block, color: BrandColors.sub)
                      : null),
          ),
        ),
      );
    }

    return Padding(
      key: Key('oshi_color_sheet_${oshi.id}'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${oshi.name}の色',
            style: HakoFonts.jp(size: 16, weight: FontWeight.w700, height: 1.5),
          ),
          const SizedBox(height: 4),
          Text(
            oshi.kind == OshiKind.person
                ? '色を選ばないと、所属グループの色を使います'
                : '色を選ばないメンバーは、この色になります',
            style: HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              swatch(label: '色なし', color: null, selected: own == null),
              for (final (name, color) in kThemeColorPresets)
                swatch(
                  label: name,
                  color: color,
                  selected: own == color.toARGB32(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}