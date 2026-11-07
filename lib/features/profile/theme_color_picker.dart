import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/oshi_providers.dart';
import '../../providers/profile_providers.dart';

/// テーマカラーの色見本（メンバーカラーでよく使われる色）
const kThemeColorPresets = <(String, Color)>[
  ('赤', Color(0xFFE53935)),
  ('ピンク', Color(0xFFEC407A)),
  ('オレンジ', Color(0xFFFB8C00)),
  ('黄', Color(0xFFFDD835)),
  ('黄緑', Color(0xFF7CB342)),
  ('緑', Color(0xFF43A047)),
  ('水色', Color(0xFF29B6F6)),
  ('青', Color(0xFF1E88E5)),
  ('紺', Color(0xFF283593)),
  ('紫', Color(0xFF8E24AA)),
  ('白', Color(0xFFFFFFFF)),
  ('黒', Color(0xFF212121)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テーマカラーを保存できませんでした')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = ref.watch(myProfileProvider).value?.themeColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('テーマカラー', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'アプリ全体の色になります。推しのメンバーカラーなどを選べます。',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
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
        TextButton.icon(
          key: const Key('theme_color_reset'),
          onPressed: _saving || current == null ? null : () => _select(null),
          icon: const Icon(Icons.restart_alt),
          label: const Text('初期の色に戻す'),
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
    final scheme = Theme.of(context).colorScheme;
    // 色見本の上のチェックは、色の明るさに合わせて白か黒にする
    final checkColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black;
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outline,
                width: selected ? 3 : 1,
              ),
            ),
            child: selected ? Icon(Icons.check, color: checkColor) : null,
          ),
        ),
      ),
    );
  }
}