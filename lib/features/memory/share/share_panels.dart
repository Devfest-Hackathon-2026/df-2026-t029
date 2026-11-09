import 'package:flutter/material.dart';

import '../../../theme/brand_colors.dart';
import '../../../theme/hako_fonts.dart';
import '../../../utils/share_ticket.dart';
import '../memory_form_page.dart' show maxImpressionLength;
import '../ticket/inline_editor.dart' show TicketField, validateTicketField;
import '../ticket/ticket_widgets.dart';
import 'share_ticket_view.dart';

// ---------------------------------------------------------------------------
// 共通の小さな部品
// ---------------------------------------------------------------------------

/// タブの中の見出し（見本の `.sec-title`）
class ShareSectionTitle extends StatelessWidget {
  const ShareSectionTitle(this.text, {super.key, this.top = 20});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: HakoFonts.jp(size: 16, weight: FontWeight.w700, height: 1.4),
        ),
      ),
    );
  }
}

/// 情報アイコン＋小さな説明の文（見本の `.help`）
class ShareHelp extends StatelessWidget {
  const ShareHelp({
    super.key,
    required this.children,
    this.icon = Icons.info_outline,
  });

  /// 文だけのとき
  ShareHelp.text(String text, {Key? key, IconData icon = Icons.info_outline})
    : this(
        key: key,
        icon: icon,
        children: [TextSpan(text: text)],
      );

  final List<InlineSpan> children;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: BrandColors.sub),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(children: children),
            style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.6),
          ),
        ),
      ],
    );
  }
}

const TextStyle _bold = TextStyle(fontWeight: FontWeight.w700);

/// 丸いチップ（押すと色が付いてチェックが出る）
class SharePillChip extends StatelessWidget {
  const SharePillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? BrandColors.hall4 : Colors.white,
            border: Border.all(color: BrandColors.ink, width: 2),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check, size: 16, color: BrandColors.ink),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: HakoFonts.jp(
                  size: 14,
                  weight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 背景色の丸（見た目 36px・押せる範囲 44px）
class ShareBgSwatch extends StatelessWidget {
  const ShareBgSwatch({
    super.key,
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = color.computeLuminance() < 0.3;
    return Semantics(
      button: true,
      toggled: selected,
      label: '背景 $name',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: BrandColors.ink, width: 2),
                boxShadow: selected
                    ? const [
                        BoxShadow(color: Colors.white, spreadRadius: 3),
                        BoxShadow(color: BrandColors.ink, spreadRadius: 5),
                      ]
                    : null,
              ),
              child: selected
                  ? Icon(
                      Icons.check,
                      size: 18,
                      color: dark ? Colors.white : BrandColors.ink,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

String _targetName(ShareTarget t) => t == ShareTarget.x ? 'X' : 'Instagram';

// ---------------------------------------------------------------------------
// タブ「のせる部分」
// ---------------------------------------------------------------------------

class SharePartsPanel extends StatelessWidget {
  const SharePartsPanel({
    super.key,
    required this.target,
    required this.config,
    required this.onToggle,
    required this.onFormat,
    required this.onDesign,
    required this.onBackground,
  });

  final ShareTarget target;
  final ShareConfig config;
  final void Function(SharePart part, ShareLayer layer) onToggle;
  final ValueChanged<int> onFormat;
  final ValueChanged<ShareDesign> onDesign;
  final ValueChanged<int> onBackground;

  static const _rows = [
    (SharePart.photo, '写真', 'photo', true, false),
    (SharePart.info, '日付・会場', 'info', true, true),
    (SharePart.setlist, 'セトリ', 'setlist', true, true),
    (SharePart.memo, '感想', 'memo', true, true),
    (SharePart.tags, 'ハッシュタグ', 'tags', false, true),
    (SharePart.mark, '「おしあし」マーク', 'mark', true, false),
  ];

  Widget _cell(
    SharePart part,
    String label,
    String name,
    ShareLayer layer,
    bool allowed,
  ) {
    if (!allowed) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: Text('—', style: TextStyle(color: BrandColors.sub)),
        ),
      );
    }
    final isImage = layer == ShareLayer.image;
    return Semantics(
      container: true,
      label: '$labelを${isImage ? '画像' : '文章'}にのせる',
      child: SizedBox(
        height: 48,
        child: Center(
          child: Switch(
            key: Key('share_part_${name}_${isImage ? 'image' : 'caption'}'),
            value: config.isOn(part, layer),
            activeTrackColor: BrandColors.hall4,
            activeThumbColor: BrandColors.ink,
            onChanged: (_) => onToggle(part, layer),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formats = shareFormats[target]!;
    const designs = [
      (ShareDesign.ticket, 'ticket', 'チケット'),
      (ShareDesign.photoMain, 'photo', '写真メイン'),
    ];
    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        t,
        style: HakoFonts.jp(size: 13, weight: FontWeight.w700, height: 1.4),
      ),
    );
    TextStyle head() => HakoFonts.jp(
      size: 13,
      weight: FontWeight.w700,
      color: BrandColors.sub,
      height: 1.4,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_targetName(target)}の画像と文章に、どの部分をのせるかを選びます。',
          style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.6),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: BrandColors.ink, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text('部分', style: head()),
                  ),
                  Center(child: Text('画像に', style: head())),
                  Center(child: Text('文章に', style: head())),
                ],
              ),
              for (final (part, name, key, image, caption) in _rows)
                TableRow(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: BrandColors.rowLine)),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        name,
                        style: HakoFonts.jp(
                          size: 14,
                          weight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                    _cell(part, name, key, ShareLayer.image, image),
                    _cell(part, name, key, ShareLayer.caption, caption),
                  ],
                ),
            ],
          ),
        ),
        const ShareSectionTitle('画像の見た目'),
        label('画像の形'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < formats.length; i++)
              SharePillChip(
                key: Key('share_format_$i'),
                label: formats[i].label,
                selected: config.formatIndex == i,
                onTap: () => onFormat(i),
              ),
          ],
        ),
        label('デザイン'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (design, name, text) in designs)
              SharePillChip(
                key: Key('share_design_$name'),
                label: text,
                selected: config.design == design,
                onTap: () => onDesign(design),
              ),
          ],
        ),
        label('背景'),
        Wrap(
          children: [
            for (var i = 0; i < shareBackgrounds.length; i++)
              ShareBgSwatch(
                key: Key('share_bg_$i'),
                name: shareBackgroundNames[i],
                color: shareBackgrounds[i],
                selected: config.backgroundIndex == i,
                onTap: () => onBackground(i),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// タブ「大きさ」
// ---------------------------------------------------------------------------

String shareSizeText(double v) {
  final pct = (v * 100).round();
  return pct == 100 ? 'ふつう' : '$pct%';
}

class ShareSizePanel extends StatelessWidget {
  const ShareSizePanel({
    super.key,
    required this.target,
    required this.config,
    required this.onChanged,
    required this.onReset,
  });

  final ShareTarget target;
  final ShareConfig config;
  final ValueChanged<ShareSizes> onChanged;
  final VoidCallback onReset;

  Widget _slider({
    required String sliderKey,
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onValue,
  }) {
    final text = shareSizeText(value);
    final percent = (value * 100).roundToDouble();
    final lo = (min * 100).roundToDouble();
    final hi = (max * 100).roundToDouble();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: HakoFonts.jp(
                    size: 14,
                    weight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: HakoFonts.jp(
                  size: 14,
                  weight: FontWeight.w700,
                  color: BrandColors.sub,
                  height: 1.4,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text('小', style: _sliderEnd()),
              Expanded(
                child: Semantics(
                  container: true,
                  label: label,
                  value: text,
                  child: Slider(
                    key: Key(sliderKey),
                    value: percent.clamp(lo, hi),
                    min: lo,
                    max: hi,
                    divisions: ((hi - lo) / 5).round(),
                    activeColor: BrandColors.ink,
                    inactiveColor: BrandColors.tonal2,
                    semanticFormatterCallback: (_) => text,
                    onChanged: (v) => onValue(v / 100),
                  ),
                ),
              ),
              Text('大', style: _sliderEnd()),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle _sliderEnd() => HakoFonts.jp(
    size: 12,
    weight: FontWeight.w700,
    color: BrandColors.sub,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    final sizes = config.sizes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_targetName(target)}の画像の中の、大きさを変えます。上のチケットを見ながら動かせます。',
          style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.6),
        ),
        if (config.design == ShareDesign.photoMain)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: ShareHelp(
              key: Key('share_size_photo_note'),
              children: [
                TextSpan(text: 'デザインが「写真メイン」のときは、写真は画像いっぱいに入ります。大きさは変えられません。'),
              ],
            ),
          )
        else
          _slider(
            sliderKey: 'share_size_photo',
            label: '写真の大きさ（チケットに占める広さ）',
            value: sizes.photo,
            min: ShareSizes.photoMin,
            max: ShareSizes.photoMax,
            onValue: (v) => onChanged(sizes.copyWith(photo: v)),
          ),
        _slider(
          sliderKey: 'share_size_info',
          label: '日付・会場の文字の大きさ',
          value: sizes.info,
          min: ShareSizes.textMin,
          max: ShareSizes.textMax,
          onValue: (v) => onChanged(sizes.copyWith(info: v)),
        ),
        _slider(
          sliderKey: 'share_size_setlist',
          label: 'セトリの文字の大きさ',
          value: sizes.setlist,
          min: ShareSizes.textMin,
          max: ShareSizes.textMax,
          onValue: (v) => onChanged(sizes.copyWith(setlist: v)),
        ),
        const SizedBox(height: 12),
        const ShareHelp(
          children: [
            TextSpan(
              text:
                  'セトリが長いときは、画像に入る曲数までを自動で表示します。'
                  '写真や文字を小さくすると、入る曲数が増えます。全曲は文章にのせられます。',
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TicketLinkButton(
            key: const Key('share_size_reset'),
            label: '大きさを、すべてふつうに戻す',
            onPressed: onReset,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// タブ「中身を直す」の写真
// ---------------------------------------------------------------------------

/// 「中身を直す」の写真のブロック。状態は持たない（操作は呼び出し側の関数で行う）
class SharePhotosBlock extends StatelessWidget {
  const SharePhotosBlock({
    super.key,
    required this.target,
    required this.recordImages,
    required this.selected,
    required this.touched,
    required this.onAdd,
    required this.onRemove,
    required this.onReset,
    required this.onEditRecord,
    required this.photoBuilder,
  });

  final ShareTarget target;

  /// 記録の写真（候補のもと）
  final List<String> recordImages;

  /// いま投稿に入れている写真（最大 [kShareMaxPhotos] 枚）
  final List<String> selected;

  /// 記録とは別に選んでいるか
  final bool touched;

  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final VoidCallback onReset;
  final VoidCallback onEditRecord;

  /// 写真1枚を描く（Storage のパス → 画像）。テストで差し替えやすくするため外から渡す
  final Widget Function(String path) photoBuilder;

  @override
  Widget build(BuildContext context) {
    final candidates = [
      for (final p in recordImages)
        if (!selected.contains(p)) p,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShareHelp(
          children: [
            TextSpan(
              text: '${_targetName(target)}に投稿する写真だけを選べます。',
              style: _bold,
            ),
            TextSpan(text: touched ? '記録とは別に選んでいます。' : 'いまは、記録の写真と同じです。'),
            const TextSpan(text: 'ここで外したり足したりしても、'),
            const TextSpan(text: '記録の写真は変わりません', style: _bold),
            const TextSpan(text: '。画像に入るのは$kShareMaxPhotos枚までです。'),
          ],
        ),
        if (touched)
          Align(
            alignment: Alignment.centerLeft,
            child: TicketLinkButton(
              key: const Key('share_photo_reset'),
              label: '記録と同じ写真に戻す',
              onPressed: onReset,
            ),
          ),
        const SizedBox(height: 8),
        if (recordImages.isEmpty)
          Text(
            '記録に写真がありません。「記録の写真を直す」から足せます。',
            style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.6),
          )
        else if (selected.isEmpty)
          Text(
            'この投稿には、写真を入れていません。下の候補から選べます。',
            style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.6),
          )
        else
          _Grid(
            children: [
              for (var i = 0; i < selected.length; i++)
                _SelectedTile(
                  index: i,
                  photo: photoBuilder(selected[i]),
                  onRemove: () => onRemove(selected[i]),
                ),
            ],
          ),
        if (candidates.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text.rich(
            const TextSpan(
              children: [
                TextSpan(text: 'ほかの候補', style: _bold),
                TextSpan(text: '（タップで追加）'),
              ],
            ),
            style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.6),
          ),
          const SizedBox(height: 6),
          _Grid(
            children: [
              for (var i = 0; i < candidates.length; i++)
                _CandidateTile(
                  index: i,
                  photo: photoBuilder(candidates[i]),
                  onAdd: () => onAdd(candidates[i]),
                ),
            ],
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TicketLinkButton(
            key: const Key('share_photo_edit_record'),
            label: '記録の写真を直す（Googleフォト・端末から追加）',
            onPressed: onEditRecord,
          ),
        ),
      ],
    );
  }
}

/// 1行に4つの正方形
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 8.0;
        final size = (c.maxWidth - gap * 3) / 4;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final w in children)
              SizedBox(width: size, height: size, child: w),
          ],
        );
      },
    );
  }
}

Widget _frame(Widget child) => DecoratedBox(
  decoration: BoxDecoration(
    border: Border.all(color: BrandColors.ink, width: 2),
    borderRadius: BorderRadius.circular(8),
    color: BrandColors.tonal,
  ),
  child: ClipRRect(borderRadius: BorderRadius.circular(6), child: child),
);

class _SelectedTile extends StatelessWidget {
  const _SelectedTile({
    required this.index,
    required this.photo,
    required this.onRemove,
  });

  final int index;
  final Widget photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _frame(photo),
        Positioned(
          left: 4,
          bottom: 4,
          child: ExcludeSemantics(
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BrandColors.ink,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                '${index + 1}',
                style: HakoFonts.en(
                  size: 11,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Semantics(
            button: true,
            label: '${index + 1}枚目の写真を外す',
            excludeSemantics: true,
            child: InkWell(
              key: Key('share_photo_remove_$index'),
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: BrandColors.ink,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.index,
    required this.photo,
    required this.onAdd,
  });

  final int index;
  final Widget photo;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${index + 1}枚目の候補を追加',
      excludeSemantics: true,
      child: InkWell(
        key: Key('share_photo_add_$index'),
        onTap: onAdd,
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(opacity: 0.75, child: _frame(photo)),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: BrandColors.hall4,
                  shape: BoxShape.circle,
                  border: Border.all(color: BrandColors.ink, width: 2),
                ),
                child: const Icon(Icons.add, size: 16, color: BrandColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// タブ「中身を直す」
// ---------------------------------------------------------------------------

/// 「中身を直す」。入力欄の [TextEditingController] は画面の State が持つ
/// （タブを切り替えても入力が消えないように）
class ShareContentPanel extends StatelessWidget {
  const ShareContentPanel({
    super.key,
    required this.photos,
    required this.setlistController,
    required this.impressionController,
    required this.onChanged,
    required this.canSave,
    required this.saving,
    required this.onSave,
  });

  final Widget photos;
  final TextEditingController setlistController;
  final TextEditingController impressionController;

  /// 入力のたびに（プレビュー・文章を作り直す）
  final VoidCallback onChanged;

  /// 入力が記録と違うか
  final bool canSave;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: BrandColors.ink, width: 2),
    );
    InputDecoration deco(String hint) => InputDecoration(
      hintText: hint,
      hintMaxLines: 6,
      hintStyle: HakoFonts.jp(size: 14, color: BrandColors.sub, height: 1.6),
      filled: true,
      fillColor: Colors.white,
      border: border,
      enabledBorder: border,
      focusedBorder: border,
    );
    final setError = validateTicketField(
      TicketField.setlist,
      setlistController.text,
    );
    final memoError = validateTicketField(
      TicketField.impression,
      impressionController.text,
    );
    TextStyle err() => HakoFonts.jp(
      size: 13,
      weight: FontWeight.w700,
      color: BrandColors.errorText,
      height: 1.5,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ShareSectionTitle('写真', top: 2),
        photos,
        const ShareSectionTitle('セトリ'),
        TextField(
          key: const Key('share_setlist_input'),
          controller: setlistController,
          minLines: 6,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          style: HakoFonts.jp(size: 15, height: 1.6),
          onChanged: (_) => onChanged(),
          decoration: deco('覚えている曲から、1行に1曲ずつ書けます。\n例）\n1. 曲名\n2. 曲名'),
        ),
        if (setError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(setError, style: err()),
          ),
        const ShareSectionTitle('感想'),
        TextField(
          key: const Key('share_memo_input'),
          controller: impressionController,
          minLines: 4,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          style: HakoFonts.jp(size: 15, height: 1.6),
          onChanged: (_) => onChanged(),
          decoration: deco(
            'いちばん心に残ったこと、うれしかったこと、MCの話など。\n思い出したときに、少しずつでも大丈夫です。',
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              key: const Key('share_memo_count'),
              '${impressionController.text.length}/$maxImpressionLength',
              style: HakoFonts.jp(
                size: 12,
                color: memoError == null
                    ? BrandColors.sub
                    : BrandColors.errorText,
                height: 1.5,
              ),
            ),
          ),
        ),
        if (memoError != null) Text(memoError, style: err()),
        const SizedBox(height: 12),
        TicketButton(
          key: const Key('share_text_save'),
          label: 'セトリと感想を記録に保存',
          kind: TicketButtonKind.green,
          wide: true,
          onPressed:
              (canSave && !saving && setError == null && memoError == null)
              ? onSave
              : null,
        ),
      ],
    );
  }
}

/// 注意文の枠（プレビューの下）。無いときは何も出さない
class ShareNotes extends StatelessWidget {
  const ShareNotes({super.key, required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        key: const Key('share_notes'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final n in notes) ShareHelp.text(n)],
      ),
    );
  }
}
