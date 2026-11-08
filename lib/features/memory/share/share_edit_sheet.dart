import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/brand_colors.dart';
import '../../../theme/hako_fonts.dart';
import '../ticket/inline_editor.dart'
    show TicketField, TicketFieldText, validateTicketField;
import '../ticket/ticket_widgets.dart';

const double _sheetMaxWidth = 640;
const double _wideBreakpoint = 720;

/// セトリ・感想の編集シート（4.6）。入力のたびに [onChanged] を呼び（プレビュー用。
/// 保存はしない）、「決定」で [onSave] を呼ぶ。[onSave] が true なら閉じ、
/// false なら開いたまま入力も残す（SnackBar は呼び出し側が出す）。
/// 「とじる」・暗幕・Esc は、変更を捨てて閉じる（保存中は閉じられない）
Future<void> showShareEditSheet(
  BuildContext context, {
  required TicketField field,
  required String initialText,
  required ValueChanged<String> onChanged,
  required Future<bool> Function(String text) onSave,
}) {
  final media = MediaQuery.of(context);
  final wide = media.size.width >= _wideBreakpoint;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: BrandColors.ink.withValues(alpha: 0.45),
    constraints: BoxConstraints(
      maxWidth: wide ? _sheetMaxWidth : double.infinity,
      maxHeight: media.size.height * 0.92,
    ),
    sheetAnimationStyle: media.disableAnimations
        ? AnimationStyle.noAnimation
        : null,
    builder: (sheetContext) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(sheetContext).maybePop(),
      },
      child: _ShareEditBody(
        field: field,
        initialText: initialText,
        onChanged: onChanged,
        onSave: onSave,
      ),
    ),
  );
}

class _ShareEditBody extends StatefulWidget {
  const _ShareEditBody({
    required this.field,
    required this.initialText,
    required this.onChanged,
    required this.onSave,
  });

  final TicketField field;
  final String initialText;
  final ValueChanged<String> onChanged;
  final Future<bool> Function(String text) onSave;

  @override
  State<_ShareEditBody> createState() => _ShareEditBodyState();
}

class _ShareEditBodyState extends State<_ShareEditBody> {
  late final _controller = TextEditingController(text: widget.initialText);
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await widget.onSave(_controller.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.field.label;
    final error = validateTicketField(widget.field, _controller.text);
    final isSetlist = widget.field == TicketField.setlist;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: BrandColors.ink, width: 2),
    );
    return PopScope(
      canPop: !_saving,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: '$labelを直す',
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: DecoratedBox(
            key: const Key('share_edit_sheet'),
            decoration: const BoxDecoration(
              color: BrandColors.paper,
              border: Border(
                top: BorderSide(color: BrandColors.ink, width: 2),
                left: BorderSide(color: BrandColors.ink, width: 2),
                right: BorderSide(color: BrandColors.ink, width: 2),
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: BrandColors.ink.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      header: true,
                      child: Text(
                        '$labelを直す',
                        style: HakoFonts.jp(
                          size: 18,
                          weight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('share_edit_input'),
                      controller: _controller,
                      autofocus: true,
                      minLines: isSetlist ? 6 : 4,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: HakoFonts.jp(size: 15, height: 1.6),
                      onChanged: (text) {
                        setState(() {});
                        widget.onChanged(text);
                      },
                      decoration: InputDecoration(
                        hintText: isSetlist
                            ? '例）\n1. 曲名\n2. 曲名'
                            : '思い出したときに、少しずつでも大丈夫です。',
                        filled: true,
                        fillColor: Colors.white,
                        border: border,
                        enabledBorder: border,
                        focusedBorder: border,
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          error,
                          style: HakoFonts.jp(
                            size: 13,
                            weight: FontWeight.w700,
                            color: BrandColors.errorText,
                            height: 1.5,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        TicketButton(
                          label: 'とじる',
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                        TicketButton(
                          key: const Key('share_edit_done'),
                          label: '決定',
                          kind: TicketButtonKind.green,
                          onPressed: (_saving || error != null) ? null : _save,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
