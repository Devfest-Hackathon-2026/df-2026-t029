import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/live_memory.dart';
import '../../../providers/memory_providers.dart';
import '../../../providers/memory_ticket_providers.dart';
import '../../../providers/share_providers.dart';
import '../../../theme/brand_colors.dart';
import '../../../theme/hako_app_widgets.dart';
import '../../../theme/hako_fonts.dart';
import '../../../utils/share_ticket.dart';
import '../../photos/photos_sheet.dart';
import '../memory_form_page.dart' show parseSetlist;
import '../ticket/inline_editor.dart' show TicketField;
import '../ticket/ticket_widgets.dart';
import 'share_edit_sheet.dart';
import 'share_providers_ui.dart';
import 'share_ticket_view.dart';

/// 経路のクエリ（`?target=x|ig`）を投稿先にする。無い・知らない値は X
ShareTarget shareTargetFromQuery(String? value) =>
    value == 'ig' ? ShareTarget.instagram : ShareTarget.x;

/// 「まとめて編集して投稿」の画面（`/memories/:performanceId/share?target=x|ig`）。
/// 画面を開くたび、投稿先は [initialTarget]（既定は X）・画像の形は1つめに戻る。
class MemoryShareScreen extends ConsumerStatefulWidget {
  const MemoryShareScreen({
    super.key,
    required this.performanceId,
    this.initialTarget = ShareTarget.x,
  });

  final String performanceId;
  final ShareTarget initialTarget;

  @override
  ConsumerState<MemoryShareScreen> createState() => _MemoryShareScreenState();
}

class _MemoryShareScreenState extends ConsumerState<MemoryShareScreen> {
  final _captureKey = GlobalKey();
  final _captionCtl = TextEditingController();

  /// 編集シートで入力中の内容（プレビューだけに反映する。保存は「決定」のとき）
  String? _draftSetlist;
  String? _draftImpression;

  bool _busy = false;

  /// 「画像の形・デザイン・背景色を変える」を開いているか（一覧から外れても覚える）
  bool _lookOpen = false;

  @override
  void initState() {
    super.initState();
    // 記録の読み込みが終わるまで誰も watch しないと、autoDispose の状態が捨てられて
    // 投稿先の指定が消える。画面が開いている間は生かしておく
    ref.listenManual(shareProvider(widget.performanceId), (_, _) {});
    if (widget.initialTarget != ShareTarget.x) {
      // initState の中では状態を変えられないので、描き終わったあとに切り替える
      scheduleMicrotask(() {
        if (!mounted) return;
        _notifier.selectTarget(widget.initialTarget);
      });
    }
  }

  @override
  void dispose() {
    _captionCtl.dispose();
    super.dispose();
  }

  ShareNotifier get _notifier =>
      ref.read(shareProvider(widget.performanceId).notifier);

  ShareContent _withDrafts(ShareContent base) {
    if (_draftSetlist == null && _draftImpression == null) return base;
    final impression = _draftImpression?.trim();
    return ShareContent(
      title: base.title,
      startAt: base.startAt,
      venue: base.venue,
      artist: base.artist,
      setlist: _draftSetlist == null
          ? base.setlist
          : parseSetlist(_draftSetlist!),
      impression: _draftImpression == null
          ? base.impression
          : (impression == null || impression.isEmpty ? null : impression),
      performerNames: base.performerNames,
      photoCount: base.photoCount,
    );
  }

  /// 動きを減らす設定のとき、SnackBar を動かさない（4.10）
  AnimationStyle? _snackAnimation() => MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null;

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text)),
        snackBarAnimationStyle: _snackAnimation(),
      );
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 2600),
          content: Row(
            children: [
              const Icon(Icons.check, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
            ],
          ),
        ),
        snackBarAnimationStyle: _snackAnimation(),
      );
  }

  /// 投稿した印（失敗しても利用者の操作は止めない）
  void _markPosted(LiveMemory memory) {
    unawaited(ref.read(memoryEditorProvider).markPosted(memory));
  }

  // --- 編集 ---------------------------------------------------------------

  Future<void> _editText(LiveMemory memory, TicketField field) async {
    final initial = field == TicketField.setlist
        ? memory.setlist.join('\n')
        : (memory.impression ?? '');
    await showShareEditSheet(
      context,
      field: field,
      initialText: initial,
      onChanged: (text) => setState(() {
        if (field == TicketField.setlist) {
          _draftSetlist = text;
        } else {
          _draftImpression = text;
        }
      }),
      onSave: (text) => _saveText(memory, field, text),
    );
    if (!mounted) return;
    setState(() {
      _draftSetlist = null;
      _draftImpression = null;
    });
  }

  Future<bool> _saveText(
    LiveMemory memory,
    TicketField field,
    String text,
  ) async {
    try {
      // 座席は変えない。保存の窓口にそのまま渡し返すだけで、画面には出さない
      await ref
          .read(memoryEditorProvider)
          .saveFields(
            memory,
            seat: memory.seat,
            setlist: field == TicketField.setlist
                ? parseSetlist(text)
                : memory.setlist,
            impression: field == TicketField.impression
                ? text
                : memory.impression,
          );
      return true;
    } catch (_) {
      if (mounted) _snack('保存できませんでした。もう一度お試しください');
      return false;
    }
  }

  void _onTapPart(LiveMemory memory, SharePart part) {
    switch (part) {
      case SharePart.photo:
        unawaited(showPhotosSheet(context, memory: memory));
      case SharePart.setlist:
        unawaited(_editText(memory, TicketField.setlist));
      case SharePart.memo:
        unawaited(_editText(memory, TicketField.impression));
      default:
        break;
    }
  }

  // --- 動作 ---------------------------------------------------------------

  Future<bool> _saveImage(
    LiveMemory memory,
    ShareFormat format,
    ShareTarget target,
  ) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      final key = sharePhotoBytesKey(memory.images);
      final bytes = await ref.read(sharePhotoBytesProvider(key).future);
      if (!mounted) return false;
      await precacheShareImages(context, bytes);
      if (!mounted) return false;
      // 写真が読み込めた状態で描き直してから、画像にする
      setState(() {});
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return false;
      final png = await ref.read(shareCaptureProvider)(
        _captureKey,
        _captureRatio,
      );
      final name =
          'oshiashi_${memory.performanceId}_${target == ShareTarget.x ? 'x' : 'ig'}.png';
      await ref.read(shareImageSaverProvider)(png, name);
      if (!mounted) return false;
      _notifier.markImageSaved();
      _toast('画像を保存しました');
      _markPosted(memory);
      return true;
    } catch (_) {
      if (mounted) _snack('保存できませんでした。もう一度お試しください');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openX(LiveMemory memory, String caption) async {
    final url = Uri.parse(
      'https://x.com/intent/post?text=${Uri.encodeComponent(caption)}',
    );
    await _open(memory, url);
  }

  Future<void> _open(LiveMemory memory, Uri url) async {
    bool opened;
    try {
      opened = await ref.read(shareUrlOpenerProvider)(url);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    if (!opened) {
      _snack('ページを開けませんでした。もう一度お試しください');
      return;
    }
    _markPosted(memory);
  }

  Future<void> _copy(String caption) async {
    try {
      await ref.read(shareClipboardProvider)(caption);
      if (!mounted) return;
      _notifier.markCaptionCopied();
      _toast('文章をコピーしました');
    } catch (_) {
      if (mounted) _snack('コピーできませんでした。文章を長押ししてコピーしてください');
    }
  }

  /// 保存する画像の表示の幅（論理ピクセル）と倍率。保存する幅 = 表示の幅 × 倍率
  static const double _captureRatio = 2;

  // --- 画面 ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final id = widget.performanceId;
    final memoryAsync = ref.watch(memoryProvider(id));
    final contentAsync = ref.watch(shareContentProvider(id));
    final Widget body;
    final memory = memoryAsync.value;
    final base = contentAsync.value;
    if (memoryAsync.isLoading && memory == null) {
      body = const Center(
        key: Key('share_loading'),
        child: CircularProgressIndicator(),
      );
    } else if (memoryAsync.hasError && memory == null) {
      body = const HakoEmpty('記録を読み込めませんでした', key: Key('share_error'));
    } else if (memory == null || base == null) {
      body = const HakoEmpty('この記録は見つかりませんでした', key: Key('share_not_found'));
    } else {
      body = _buildContent(context, memory, base);
    }
    return HakoPageScaffold(
      title: '投稿をまとめて編集',
      showBack: true,
      backFallback: '/memories/$id',
      body: body,
    );
  }

  Widget _buildContent(
    BuildContext context,
    LiveMemory memory,
    ShareContent baseContent,
  ) {
    final id = widget.performanceId;
    final state = ref.watch(shareProvider(id));
    final target = state.target;
    final config = state.config;
    final formats = shareFormats[target]!;
    final format = formats[config.formatIndex.clamp(0, formats.length - 1)];
    final content = _withDrafts(baseContent);
    final photosKey = sharePhotoBytesKey(memory.images);
    final photos =
        ref.watch(sharePhotoBytesProvider(photosKey)).value ?? const [];
    final caption = currentCaption(state, content);

    // 自動で作り直した・戻したときだけ、欄の文字を入れ替える（入力中は触らない）
    if (_captionCtl.text != caption) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _captionCtl.text == caption) return;
        _captionCtl.value = TextEditingValue(
          text: caption,
          selection: TextSelection.collapsed(offset: caption.length),
        );
      });
    }

    final captureWidth = format.outWidth / _captureRatio;
    final layout = layoutShareText(content, format);

    final list = ListView(
      padding: HakoPageScaffold.padding(context),
      children: [
        _Tip(
          icon: Icons.edit_outlined,
          children: const [
            TextSpan(text: 'チケットの写真・セトリ・感想を'),
            TextSpan(
              text: 'タップ',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: 'すると、その場で直せます。'),
          ],
        ),
        const SizedBox(height: 10),
        _Preview(
          format: format,
          child: ShareTicketView(
            content: content,
            config: config,
            target: target,
            photoBytes: photos,
            hints: true,
            onTapPart: (part) => _onTapPart(memory, part),
          ),
        ),
        if (config.isOn(SharePart.setlist, ShareLayer.image) &&
            layout.setMore > 0)
          _Note('セトリは、画像には先頭${layout.setShown.length}曲まで入ります。全曲は文章にのせられます。'),
        if (config.isOn(SharePart.memo, ShareLayer.image) && layout.memoCut)
          _Note('感想は、画像には${format.maxMemoChars}文字までです。全文は文章にのせられます。'),
        const _Heading('画像にのせる部分'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _imageChip(memory, SharePart.photo, '写真', 'photo', pen: true),
            _imageChip(memory, SharePart.info, '日付・会場', 'info'),
            _imageChip(memory, SharePart.setlist, 'セトリ', 'setlist', pen: true),
            _imageChip(memory, SharePart.memo, '感想', 'memo', pen: true),
            _imageChip(memory, SharePart.mark, '「おしあし」マーク', 'mark'),
          ],
        ),
        const _Heading('文章にのせる部分'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _captionChip(SharePart.info, '日付・会場', 'info'),
            _captionChip(SharePart.setlist, 'セトリ', 'setlist'),
            _captionChip(SharePart.memo, '感想', 'memo'),
            _captionChip(SharePart.tags, 'ハッシュタグ', 'tags'),
          ],
        ),
        _look(state, formats),
        const _Heading('投稿の文章'),
        _captionField(state, target, caption),
        const _Heading('投稿する'),
        if (target == ShareTarget.x)
          _xActions(memory, format, target, caption)
        else
          _igActions(memory, format, target, caption, state),
      ],
    );

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              _Tabs(
                target: target,
                onSelect: (t) {
                  _notifier.selectTarget(t);
                },
              ),
              Expanded(child: list),
            ],
          ),
        ),
        // 保存する画像を描くための部分。画面の左の外に置く（見えない。
        // Offstage・Opacity 0 は描かれず、PNG にできないので使わない）。
        // 空の枠・タップの枠線は入れない
        Positioned(
          left: -(captureWidth + 100),
          top: 0,
          width: captureWidth,
          height: captureWidth * format.aspectH / format.aspectW,
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: RepaintBoundary(
                key: _captureKey,
                child: ShareTicketView(
                  content: content,
                  config: config,
                  target: target,
                  photoBytes: photos,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 折りたたみ「画像の形・デザイン・背景色を変える」（見本の `details.look`）
  Widget _look(ShareState state, List<ShareFormat> formats) {
    final config = state.config;
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
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: BrandColors.ink, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const Key('share_look'),
            initiallyExpanded: _lookOpen,
            onExpansionChanged: (open) => _lookOpen = open,
            expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
                ? AnimationStyle.noAnimation
                : null,
            minTileHeight: 48,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            shape: const Border(),
            collapsedShape: const Border(),
            leading: const Icon(Icons.palette_outlined, size: 20),
            title: Text(
              '画像の形・デザイン・背景色を変える',
              style: HakoFonts.jp(
                size: 14,
                weight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            children: [
              label('画像の形'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < formats.length; i++)
                    _PartChip(
                      key: Key('share_format_$i'),
                      label: formats[i].label,
                      selected: config.formatIndex == i,
                      onTap: () => ref
                          .read(shareProvider(widget.performanceId).notifier)
                          .setFormat(i),
                    ),
                ],
              ),
              label('デザイン'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (design, name, text) in designs)
                    _PartChip(
                      key: Key('share_design_$name'),
                      label: text,
                      selected: config.design == design,
                      onTap: () => ref
                          .read(shareProvider(widget.performanceId).notifier)
                          .setDesign(design),
                    ),
                ],
              ),
              label('背景'),
              Wrap(
                children: [
                  for (var i = 0; i < shareBackgrounds.length; i++)
                    _BgSwatch(
                      key: Key('share_bg_$i'),
                      name: shareBackgroundNames[i],
                      color: shareBackgrounds[i],
                      selected: config.backgroundIndex == i,
                      onTap: () => ref
                          .read(shareProvider(widget.performanceId).notifier)
                          .setBackground(i),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageChip(
    LiveMemory memory,
    SharePart part,
    String label,
    String name, {
    bool pen = false,
  }) {
    final state = ref.watch(shareProvider(widget.performanceId));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PartChip(
          key: Key('share_chip_img_$name'),
          label: label,
          selected: state.config.isOn(part, ShareLayer.image),
          onTap: () => _notifier.toggle(part, ShareLayer.image),
        ),
        if (pen)
          _PenButton(
            key: Key('share_chip_edit_${name == 'memo' ? 'memo' : name}'),
            label: '$labelを直す',
            onTap: () => _onTapPart(memory, part),
          ),
      ],
    );
  }

  Widget _captionChip(SharePart part, String label, String name) {
    final state = ref.watch(shareProvider(widget.performanceId));
    return _PartChip(
      key: Key('share_chip_cap_$name'),
      label: label,
      selected: state.config.isOn(part, ShareLayer.caption),
      onTap: () => _notifier.toggle(part, ShareLayer.caption),
    );
  }

  Widget _captionField(ShareState state, ShareTarget target, String caption) {
    final edited = state.captionOverride[target] != null;
    final tooLong = isCaptionTooLong(target, caption);
    final count = target == ShareTarget.x
        ? xWeightedLength(caption)
        : caption.length;
    final limit = captionLimit(target);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: BrandColors.ink, width: 2),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('share_caption'),
          controller: _captionCtl,
          minLines: 6,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          style: HakoFonts.jp(size: 14, height: 1.6),
          onChanged: (text) => _notifier.setCaption(text),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: border,
            enabledBorder: border,
            focusedBorder: border,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (edited)
              TicketLinkButton(
                key: const Key('share_caption_reset'),
                label: '自動で作った文章に戻す',
                onPressed: () {
                  _notifier.resetCaption();
                },
              )
            else
              Text(
                '手直しすると、のせる部分を変えても文章はそのままです。',
                style: HakoFonts.jp(
                  size: 12,
                  color: BrandColors.sub,
                  height: 1.6,
                ),
              ),
            Text(
              key: const Key('share_caption_count'),
              '$count / $limit${tooLong ? '（文字数が多すぎます）' : ''}',
              style: HakoFonts.jp(
                size: 13,
                weight: tooLong ? FontWeight.w700 : FontWeight.w400,
                color: tooLong ? BrandColors.errorText : BrandColors.sub,
                height: 1.6,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _xActions(
    LiveMemory memory,
    ShareFormat format,
    ShareTarget target,
    String caption,
  ) {
    final tooLong = isCaptionTooLong(target, caption);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TicketButton(
          key: const Key('share_post_x'),
          label: 'Xで投稿画面を開く',
          icon: Icons.open_in_new,
          kind: TicketButtonKind.dark,
          wide: true,
          onPressed: tooLong ? null : () => _openX(memory, caption),
        ),
        const SizedBox(height: 8),
        Text(
          '文章が入った状態でXの投稿画面が開きます。画像は「画像を保存」してから、投稿画面で追加してください。',
          style: HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.6),
        ),
        const SizedBox(height: 10),
        TicketButton(
          key: const Key('share_save_image'),
          label: '画像を保存',
          icon: Icons.download,
          wide: true,
          onPressed: _busy ? null : () => _saveImage(memory, format, target),
        ),
      ],
    );
  }

  Widget _igActions(
    LiveMemory memory,
    ShareFormat format,
    ShareTarget target,
    String caption,
    ShareState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Step(
          number: 1,
          done: state.imageSaved,
          child: TicketButton(
            key: const Key('share_save_image'),
            label: '画像を保存',
            icon: Icons.download,
            wide: true,
            onPressed: _busy ? null : () => _saveImage(memory, format, target),
          ),
        ),
        const SizedBox(height: 8),
        _Step(
          number: 2,
          done: state.captionCopied,
          child: TicketButton(
            key: const Key('share_copy_caption'),
            label: '文章をコピー',
            icon: Icons.copy,
            wide: true,
            onPressed: () => _copy(caption),
          ),
        ),
        const SizedBox(height: 8),
        _Step(
          number: 3,
          done: false,
          child: TicketButton(
            key: const Key('share_open_ig'),
            label: 'Instagramを開く',
            icon: Icons.open_in_new,
            kind: TicketButtonKind.dark,
            wide: true,
            onPressed: () =>
                _open(memory, Uri.parse('https://www.instagram.com/')),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Instagramは、文章を自動で入れられません。画像を保存し、文章をコピーしてから、Instagramの投稿画面で貼り付けてください。',
          style: HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.6),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 部品
// ---------------------------------------------------------------------------

class _Tabs extends StatelessWidget {
  const _Tabs({required this.target, required this.onSelect});

  final ShareTarget target;
  final ValueChanged<ShareTarget> onSelect;

  @override
  Widget build(BuildContext context) {
    final isX = target == ShareTarget.x;
    return Container(
      color: BrandColors.paper,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: '投稿先',
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    key: const Key('share_tab_x'),
                    selected: isX,
                    onTap: () => onSelect(ShareTarget.x),
                    icon: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isX ? Colors.white : BrandColors.ink,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'X',
                        style: HakoFonts.en(
                          size: 14,
                          weight: FontWeight.w700,
                          color: isX ? BrandColors.ink : Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                    label: 'X',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TabButton(
                    key: const Key('share_tab_ig'),
                    selected: !isX,
                    onTap: () => onSelect(ShareTarget.instagram),
                    icon: const Icon(Icons.photo_camera_outlined, size: 22),
                    label: 'Instagram',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'のせる内容は、XとInstagramで別々に決められます。いまは'),
                TextSpan(
                  text: isX ? 'X' : 'Instagram',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: 'の設定です。'),
              ],
            ),
            style: HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    super.key,
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.label,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : BrandColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? BrandColors.ink : Colors.white,
            border: Border.all(color: BrandColors.ink, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(color: fg),
                child: icon,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: HakoFonts.jp(
                      size: 15,
                      weight: FontWeight.w700,
                      color: fg,
                      height: 1.3,
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

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.children});

  final IconData icon;
  final List<InlineSpan> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: BrandColors.sub),
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

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _Tip(
        icon: Icons.info_outline,
        children: [TextSpan(text: text)],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
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

/// プレビューの枠（見本の `.cardwrap` と `.shot`）。縦長は高さの上限で幅を狭める
class _Preview extends StatelessWidget {
  const _Preview({required this.format, required this.child});

  final ShareFormat format;
  final Widget child;

  static const double _maxHeight = 460;

  @override
  Widget build(BuildContext context) {
    final ratio = format.aspectW / format.aspectH;
    return Container(
      key: const Key('share_preview'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE7E0CB),
        border: Border.all(color: BrandColors.ink, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ratio < 1 ? _maxHeight * ratio : double.infinity,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: BrandColors.ink, width: 2),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(color: Color(0xE6111111), offset: Offset(4, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// のせる部分の丸いチップ（押すと色が付いてチェックが出る）
class _PartChip extends StatelessWidget {
  const _PartChip({
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

class _PenButton extends StatelessWidget {
  const _PenButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.edit_outlined, size: 18),
        ),
      ),
    );
  }
}

/// Instagram の3ステップの1行（番号の丸は、済みになると色が付く）
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.done, required this.child});

  final int number;
  final bool done;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          label: done ? '$number 済み' : '$number',
          excludeSemantics: true,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? BrandColors.hall4 : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: BrandColors.ink, width: 2),
            ),
            child: done
                ? const Icon(Icons.check, size: 16)
                : Text(
                    '$number',
                    style: HakoFonts.en(size: 13, weight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }
}

/// 背景色の丸（見た目 36px・押せる範囲 44px）
class _BgSwatch extends StatelessWidget {
  const _BgSwatch({
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
