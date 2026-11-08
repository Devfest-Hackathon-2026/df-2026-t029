import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/oshi.dart';
import '../../providers/oshi_color_providers.dart';
import '../../providers/oshi_emoji_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import '../profile/theme_color_picker.dart';

/// 絵文字の候補（add_I 3.1）
const kOshiEmojiPresets = [
  '🌙', '⭐', '🌸', '🎀', '💜', '💙', '💚', '💛', '🧡', '❤️', '🐬', '🐰', //
  '🐱', '🦊', '🐻', '🍓', '🍒', '🔥', '🌈', '✨', '👑', '🎤', '🎸', '🫶',
];

/// 推しの色と絵文字を選ぶシート（Fc 5.3・add_I 3.1）。選ぶとすぐ保存して閉じる
Future<void> showOshiColorSheet(BuildContext context, OshiSummary oshi) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    useRootNavigator: true,
    isScrollControlled: true,
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
  final _emojiInput = TextEditingController();
  bool _saving = false;

  String get _key => oshiColorKey(widget.oshi.kind, widget.oshi.id);

  @override
  void dispose() {
    _emojiInput.dispose();
    super.dispose();
  }

  /// 保存して閉じる。失敗したら知らせて、シートは開いたままにする
  Future<void> _run(
    Future<void> Function(String uid) save,
    String failure,
  ) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || _saving) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await save(uid);
      navigator.pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  Future<void> _saveColor(Color? color) => _run(
    (uid) => ref
        .read(oshiColorRepositoryProvider)
        .setColor(uid, _key, color?.toARGB32()),
    '色を保存できませんでした。もう一度お試しください',
  );

  Future<void> _saveEmoji(String? emoji) => _run(
    (uid) => ref.read(oshiEmojiRepositoryProvider).setEmoji(uid, _key, emoji),
    '絵文字を保存できませんでした。もう一度お試しください',
  );

  /// 入力欄の絵文字を決める
  void _submitInput() {
    final emoji = normalizeOshiEmoji(_emojiInput.text);
    if (emoji == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('絵文字を1文字入れてください')));
      return;
    }
    _saveEmoji(emoji);
  }

  @override
  Widget build(BuildContext context) {
    final oshi = widget.oshi;
    final colors = ref.watch(oshiColorsProvider).value ?? const {};
    final own = colors[_key];
    final emojis = ref.watch(oshiEmojisProvider).value ?? const {};
    final ownEmoji = emojis[_key];
    final heading = HakoFonts.jp(size: 14, weight: FontWeight.w700, height: 1.5);
    final note = HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.5);

    Widget swatch({
      required String label,
      required Color? color,
      required bool selected,
    }) {
      return Tooltip(
        message: label,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _saving ? null : () => _saveColor(color),
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

    Widget emojiChip({required String? emoji, required bool selected}) {
      return Tooltip(
        message: emoji ?? '絵文字なし',
        child: InkWell(
          key: Key('oshi_emoji_${emoji ?? 'none'}'),
          customBorder: const CircleBorder(),
          onTap: _saving ? null : () => _saveEmoji(emoji),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? BrandColors.ink.withValues(alpha: 0.12)
                  : BrandColors.surface,
              border: Border.all(color: BrandColors.ink, width: selected ? 3 : 2),
            ),
            child: emoji == null
                ? const Icon(Icons.block, color: BrandColors.sub)
                : Text(emoji, style: const TextStyle(fontSize: 22, height: 1)),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      key: Key('oshi_color_sheet_${oshi.id}'),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${oshi.name}の色と絵文字',
            style: HakoFonts.jp(size: 16, weight: FontWeight.w700, height: 1.5),
          ),
          const SizedBox(height: 12),
          // 色（Fc 5.3）
          Text('色', style: heading),
          Text(
            oshi.kind == OshiKind.person
                ? '色を選ばないと、所属グループの色を使います'
                : '色を選ばないメンバーは、この色になります',
            style: note,
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 24),
          // 絵文字（add_I 3.1）
          Text('絵文字', style: heading),
          Text('札の中に出ます（グループの絵文字はメンバーに引き継ぎません）', style: note),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              emojiChip(emoji: null, selected: ownEmoji == null),
              for (final e in kOshiEmojiPresets)
                emojiChip(emoji: e, selected: ownEmoji == e),
              // 並びに無い絵文字を決めているときは、それも出す
              if (ownEmoji != null && !kOshiEmojiPresets.contains(ownEmoji))
                emojiChip(emoji: ownEmoji, selected: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  key: const Key('oshi_emoji_input'),
                  controller: _emojiInput,
                  decoration: const InputDecoration(
                    labelText: 'ほかの絵文字',
                    hintText: '例：🦄',
                  ),
                  onSubmitted: (_) => _submitInput(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                key: const Key('oshi_emoji_submit'),
                onPressed: _saving ? null : _submitInput,
                child: const Text('決定'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}