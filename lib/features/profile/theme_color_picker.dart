import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/oshi_providers.dart';
import '../../providers/profile_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';

/// テーマカラーの色見本（メンバーカラーでよく使われる色）
const kThemeColorPresets = <(String, Color)>[
  ('レッド', Color(0xFFE8452C)),
  ('ピンク', Color(0xFFF07BAE)),
  ('オレンジ', Color(0xFFFF9F1C)),
  ('イエロー', Color(0xFFF2D21B)),
  ('オリーブ', Color(0xFF8DB33A)),
  ('グリーン', Color(0xFF2DBE7E)),
  ('スカイブルー', Color(0xFF3FB6F0)),
  ('ブルー', Color(0xFF4A9BEF)),
  ('ネイビー', Color(0xFF283593)),
  ('パープル', Color(0xFF8E24AA)),
  ('ホワイト', Color(0xFFFFFFFF)),
  ('ブラック', Color(0xFF121212)),
];

/// テーマカラーの選択（押すとすぐ保存し、アプリ全体の色が変わる）
class ThemeColorPicker extends ConsumerStatefulWidget {
  const ThemeColorPicker({super.key});

  @override
  ConsumerState<ThemeColorPicker> createState() => _ThemeColorPickerState();
}

class _ThemeColorPickerState extends ConsumerState<ThemeColorPicker> {
  bool _saving = false;

  /// [color] が null なら、初期の色に戻す
  Future<void> _select(Color? color) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .saveThemeColor(uid, color?.toARGB32());
    } catch (e) {
      debugPrint('テーマカラーの保存に失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('テーマカラーを保存できませんでした')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(myProfileProvider).value?.themeColor;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'テーマカラー',
            style: HakoFonts.jp(size: 16, weight: FontWeight.w700, height: 1.4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'アプリ全体の色になります。推しのメンバーカラーなどを選べます。',
          style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.6),
        ),
        const SizedBox(height: 12),
        Wrap(
          // 各見本は輪の分（外側 6px）を含む 56px なので、間は 0
          children: [
            for (final (name, color) in kThemeColorPresets)
              _ColorSwatch(
                name: name,
                color: color,
                selected: current == color.toARGB32(),
                onTap: _saving ? null : () => _select(color),
              ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('theme_color_reset'),
          onPressed: _saving || current == null ? null : () => _select(null),
          icon: const Icon(Icons.restart_alt, size: 18),
          label: const Text('初期の色に戻す'),
        ),
        const SizedBox(height: 12),
        // 飾りなので読み上げない
        ExcludeSemantics(
          child: HakoBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'この色が使われる場所',
                  style: HakoFonts.jp(
                    size: 12,
                    color: BrandColors.sub,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IgnorePointer(
                      child: FilledButton(
                        onPressed: () {},
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                        ),
                        child: const Text('追加'),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: BrandColors.ink, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          '星宮ルナ',
                          style: HakoFonts.jp(
                            size: 14,
                            weight: FontWeight.w700,
                            color: scheme.onPrimaryContainer,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Switch(value: true, onChanged: (_) {}),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 色見本の丸いボタン（選択中はチェックを付ける）
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final checkColor = onThemeColor(color);
    return Tooltip(
      message: name,
      child: Semantics(
        label: name,
        button: true,
        selected: selected,
        child: InkWell(
          key: Key('theme_color_${color.toARGB32().toRadixString(16)}'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            // 選んでいるときは、外側に 3px の墨の輪（間 3）
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: selected
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: BrandColors.ink, width: 3),
                  )
                : null,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: BrandColors.ink, width: 2),
              ),
              child: selected
                  ? Icon(Icons.check, color: checkColor, size: 22)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
