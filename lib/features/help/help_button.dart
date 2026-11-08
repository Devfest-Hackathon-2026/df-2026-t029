import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/help_providers.dart';
import '../../theme/brand_colors.dart';
import 'help_scope.dart';
import 'help_sheet.dart';

/// 「?」ボタン。HakoHelpScope の topic が null なら何も出さない。
/// 押すと吹き出しを消してからシートを開く。開いている間は見た目を反転する。
class HelpButton extends ConsumerStatefulWidget {
  const HelpButton({super.key, this.foreground = BrandColors.ink});

  /// 閉じているときの枠とアイコンの色
  final Color foreground;

  @override
  ConsumerState<HelpButton> createState() => _HelpButtonState();
}

class _HelpButtonState extends ConsumerState<HelpButton> {
  bool _open = false;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    final topic = HakoHelpScope.maybeOf(context)?.topic;
    if (topic == null || _open) return;
    ref.read(helpCoachVisibleProvider.notifier).dismiss();
    setState(() => _open = true);
    await showHelpSheet(context, topic);
    if (!mounted) return;
    setState(() => _open = false);
    // 閉じたら「?」にフォーカスを戻す
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scope = HakoHelpScope.maybeOf(context);
    if (scope == null || scope.topic == null) return const SizedBox.shrink();
    const label = 'この画面でできることを見る';
    final bg = _open ? BrandColors.ink : BrandColors.surface;
    final fg = _open ? Colors.white : widget.foreground;
    return CompositedTransformTarget(
      link: scope.link,
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          toggled: _open,
          label: label,
          child: InkWell(
            key: const Key('help_button'),
            focusNode: _focusNode,
            onTap: _onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: bg,
                    shape: BoxShape.circle,
                    border: Border.all(color: BrandColors.ink, width: 2),
                  ),
                  child: ExcludeSemantics(
                    child: Icon(Icons.help_outline, size: 22, color: fg),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
