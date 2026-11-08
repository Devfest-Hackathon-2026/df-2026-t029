import 'package:flutter/material.dart';

import '../../../theme/brand_colors.dart';
import '../../../theme/hako_fonts.dart';
import '../memory_form_page.dart'
    show
        maxImpressionLength,
        maxSeatLength,
        maxSetlistSongs,
        maxSongLength,
        parseSetlist;
import 'ticket_widgets.dart';

/// 編集カードで直す項目
enum TicketField { seat, setlist, impression }

extension TicketFieldText on TicketField {
  /// 「座席」「セトリ」「感想」
  String get label => switch (this) {
    TicketField.seat => '座席',
    TicketField.setlist => 'セトリ',
    TicketField.impression => '感想',
  };
}

/// 入力の検査。問題があれば赤い文を返す（無ければ null）。
/// 上限は memory_form_page.dart の定数と同じ
String? validateTicketField(TicketField field, String text) {
  switch (field) {
    case TicketField.seat:
      if (text.trim().length > maxSeatLength) {
        return '座席は$maxSeatLength文字までです';
      }
    case TicketField.setlist:
      final songs = parseSetlist(text);
      if (songs.length > maxSetlistSongs) {
        return 'セトリは$maxSetlistSongs曲までです';
      }
      if (songs.any((s) => s.length > maxSongLength)) {
        return '曲名は1曲$maxSongLength文字までです';
      }
    case TicketField.impression:
      if (text.trim().length > maxImpressionLength) {
        return '感想は$maxImpressionLength文字までです';
      }
  }
  return null;
}

/// その場の編集カード（4.2 の `#inlineEdit`）。開いたら入力欄にフォーカスし、
/// 画面をカードまでスクロールする。「決定」で [onSave] を呼ぶ（保存中は押せない）。
/// 入力中の文字は、カードが閉じるときに捨てる
class InlineEditorCard extends StatefulWidget {
  const InlineEditorCard({
    super.key,
    required this.field,
    required this.initialText,
    required this.onSave,
  });

  final TicketField field;
  final String initialText;

  /// 保存する。成功したら true（呼び出し側がカードを閉じる）。失敗したら false で、
  /// カードは開いたまま入力も残る（SnackBar は呼び出し側が出す）
  final Future<bool> Function(String text) onSave;

  @override
  State<InlineEditorCard> createState() => _InlineEditorCardState();
}

class _InlineEditorCardState extends State<InlineEditorCard> {
  late final _controller = TextEditingController(text: widget.initialText);
  final _focus = FocusNode();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      Scrollable.ensureVisible(
        context,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await widget.onSave(_controller.text);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final error = validateTicketField(field, _controller.text);
    final multiline = field != TicketField.seat;
    final hint = switch (field) {
      TicketField.seat => '例）アリーナ C3ブロック 8列 21番 / 自由席',
      TicketField.setlist => '例）\n1. 曲名\n2. 曲名',
      TicketField.impression => '思い出したときに、少しずつでも大丈夫です。',
    };
    final help = switch (field) {
      TicketField.seat => null,
      TicketField.setlist => '覚えている曲から、1行に1曲ずつ書けます。',
      TicketField.impression => 'いちばん心に残ったこと、うれしかったこと、MCの話など。',
    };
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: BrandColors.ink, width: 2),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: BrandColors.ink, offset: Offset(4, 4)),
        ],
      ),
      child: Container(
        key: const Key('memory_inline_editor'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BrandColors.ink, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                '${field.label}を書く',
                style: HakoFonts.jp(
                  size: 15,
                  weight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
            if (help != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  help,
                  style: HakoFonts.jp(
                    size: 12.5,
                    color: BrandColors.sub,
                    height: 1.6,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('memory_inline_input'),
              controller: _controller,
              focusNode: _focus,
              enabled: !_saving,
              minLines: multiline ? 5 : 1,
              maxLines: multiline ? null : 1,
              keyboardType: multiline
                  ? TextInputType.multiline
                  : TextInputType.text,
              onChanged: (_) => setState(() {}),
              style: HakoFonts.jp(size: 16, height: 1.6),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: HakoFonts.jp(
                  size: 15,
                  color: BrandColors.sub,
                  height: 1.6,
                ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                  borderSide: const BorderSide(
                    color: BrandColors.ink,
                    width: 3,
                  ),
                ),
                disabledBorder: border,
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  error,
                  key: const Key('memory_inline_error'),
                  style: HakoFonts.jp(
                    size: 12.5,
                    color: BrandColors.errorText,
                    height: 1.5,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TicketButton(
                key: const Key('memory_inline_save'),
                label: '決定',
                icon: Icons.check,
                kind: TicketButtonKind.green,
                onPressed: (_saving || error != null) ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
