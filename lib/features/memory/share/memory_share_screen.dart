import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/live_memory.dart';
import '../../../providers/memory_providers.dart';
import '../../../providers/memory_ticket_providers.dart';
import '../../../providers/share_providers.dart';
import '../../../theme/brand_colors.dart';
import '../../../theme/hako_app_widgets.dart';
import '../../../theme/hako_fonts.dart';
import '../../../utils/share_ticket.dart';
import '../../common/storage_image.dart';
import '../../photos/photos_sheet.dart';
import '../memory_form_page.dart' show parseSetlist;
import '../ticket/ticket_widgets.dart';
import 'share_panels.dart';
import 'share_providers_ui.dart';
import 'share_ticket_view.dart';

/// 経路のクエリ（`?target=x|ig`）を投稿先にする。無い・知らない値は X
ShareTarget shareTargetFromQuery(String? value) =>
    value == 'ig' ? ShareTarget.instagram : ShareTarget.x;

/// プレビューの高さの上限（4.2）
const double _previewMaxWidth = 420;

/// スクロールで縮む固定部分（プレビュー 100% → 50%）。
/// 高さは [minE]〜[maxE]。ピン留めなので、縮んでもスクロールの長さは変わらない
class _ShareHeaderDelegate extends SliverPersistentHeaderDelegate {
  _ShareHeaderDelegate({
    required this.minE,
    required this.maxE,
    required this.builder,
  });

  final double minE, maxE;
  final Widget Function(BuildContext context, double extent) builder;

  @override
  double get minExtent => minE;

  @override
  double get maxExtent => maxE;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => builder(context, math.max(minE, maxE - shrinkOffset));

  // 中身（内容・設定）が変わるたびに作り直す
  @override
  bool shouldRebuild(covariant _ShareHeaderDelegate oldDelegate) => true;
}

/// 「まとめて編集して投稿」の画面（`/memories/:performanceId/share?target=x|ig`）。
/// 画面を開くたび、投稿先は [initialTarget]（既定は X）・画像の形は1つめ・
/// 選んでいるタブは「中身を直す」に戻る。
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

  // 入力欄・選んでいるタブは、タブの中ではなくこの State が持つ
  // （タブを切り替えても入力が消えない・フォーカスが外れないように）
  final _setlistCtl = TextEditingController();
  final _impressionCtl = TextEditingController();
  int _ptab = 0;

  /// 入力欄に記録の内容を入れたか（最初の1回だけ）
  bool _seeded = false;

  /// 保存済み（または読み込んだ）の内容。入力がこれと違えば「未保存の変更」
  String _savedSetlist = '';
  String _savedImpression = '';

  /// 自動で絞った結果（プレビューが知らせる）
  ShareFit? _fit;

  bool _busy = false;
  bool _saving = false;

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
    _setlistCtl.dispose();
    _impressionCtl.dispose();
    super.dispose();
  }

  ShareNotifier get _notifier =>
      ref.read(shareProvider(widget.performanceId).notifier);

  /// 記録の内容を入力欄に1回だけ入れる（入力中に書き換えない）
  void _seed(LiveMemory memory) {
    if (_seeded) return;
    _seeded = true;
    _savedSetlist = memory.setlist.join('\n');
    _savedImpression = (memory.impression ?? '').trim();
    _setlistCtl.text = _savedSetlist;
    _impressionCtl.text = _savedImpression;
  }

  bool get _dirty =>
      _seeded &&
      (parseSetlist(_setlistCtl.text).join('\n') != _savedSetlist ||
          _impressionCtl.text.trim() != _savedImpression);

  /// 入力欄の内容（下書き）を反映した、画像・文章に出す内容
  ShareContent _withDrafts(ShareContent base) {
    if (!_seeded) return base;
    final impression = _impressionCtl.text.trim();
    return ShareContent(
      title: base.title,
      startAt: base.startAt,
      venue: base.venue,
      artist: base.artist,
      setlist: parseSetlist(_setlistCtl.text),
      impression: impression.isEmpty ? null : impression,
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

  // --- 中身を直す -----------------------------------------------------------

  /// セトリと感想をまとめて記録に保存する。座席は変えない
  Future<void> _saveText(LiveMemory memory) async {
    if (_saving) return;
    setState(() => _saving = true);
    final setlist = parseSetlist(_setlistCtl.text);
    final impression = _impressionCtl.text;
    try {
      await ref
          .read(memoryEditorProvider)
          .saveFields(
            memory,
            seat: memory.seat,
            setlist: setlist,
            impression: impression,
          );
      if (!mounted) return;
      _savedSetlist = setlist.join('\n');
      _savedImpression = impression.trim();
      _toast('記録に保存しました');
    } catch (_) {
      if (mounted) _snack('保存できませんでした。もう一度お試しください');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addPhoto(String path, List<String> recordImages) {
    if (!_notifier.addSharePhoto(path, recordImages)) {
      _snack('画像に入る写真は、$kShareMaxPhotos枚までです');
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
      final paths = effectiveSharePhotos(
        ref.read(shareProvider(widget.performanceId)),
        memory.images,
      );
      final key = sharePhotoBytesKey(paths);
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
      _seed(memory);
      body = _buildContent(context, memory, base);
    }
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final leave = await _confirmLeave();
        if (leave) navigator.pop();
      },
      child: HakoPageScaffold(
        title: '投稿をまとめて編集',
        showBack: true,
        backFallback: '/memories/$id',
        onBack: _onBack,
        body: body,
      ),
    );
  }

  /// 上のバーの戻る。未保存の入力が無ければそのまま戻り、あれば確認する
  Future<void> _onBack() async {
    final id = widget.performanceId;
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    if (_dirty && !await _confirmLeave()) return;
    if (navigator.canPop()) {
      // PopScope を通さず、確認済みとして戻る
      navigator.pop();
    } else {
      router.go('/memories/$id');
    }
  }

  /// 保存していない入力があるまま戻るときの確認
  Future<bool> _confirmLeave() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('share_leave_dialog'),
        title: const Text('保存していない変更があります'),
        content: const Text('セトリ・感想の変更が、記録にまだ保存されていません。'),
        actions: [
          TextButton(
            key: const Key('share_leave_stay'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('とどまる'),
          ),
          TextButton(
            key: const Key('share_leave_ok'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('保存せずに戻る'),
          ),
        ],
      ),
    );
    return result ?? false;
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
    final photoPaths = effectiveSharePhotos(state, memory.images);
    final photosKey = sharePhotoBytesKey(photoPaths);
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
    final notes = shareImageNotes(
      content,
      config,
      format,
      config.design == ShareDesign.ticket ? _fit : null,
    );

    final panel = switch (_ptab) {
      0 => ShareContentPanel(
        photos: SharePhotosBlock(
          target: target,
          recordImages: memory.images,
          selected: photoPaths,
          touched: isSharePhotosTouched(state),
          onAdd: (p) => _addPhoto(p, memory.images),
          onRemove: (p) => _notifier.removeSharePhoto(p, memory.images),
          onReset: () {
            _notifier.resetSharePhotos();
            _toast('記録と同じ写真に戻しました');
          },
          onEditRecord: () =>
              unawaited(showPhotosSheet(context, memory: memory)),
          photoBuilder: (path) => StorageImage(path: path),
        ),
        setlistController: _setlistCtl,
        impressionController: _impressionCtl,
        onChanged: () => setState(() {}),
        canSave: _dirty,
        saving: _saving,
        onSave: () => _saveText(memory),
      ),
      1 => SharePartsPanel(
        target: target,
        config: config,
        onToggle: (p, l) => _notifier.toggle(p, l),
        onFormat: _notifier.setFormat,
        onDesign: _notifier.setDesign,
        onBackground: _notifier.setBackground,
      ),
      _ => ShareSizePanel(
        target: target,
        config: config,
        onChanged: _notifier.setSizes,
        onReset: () {
          _notifier.resetSizes();
          _toast('大きさをふつうに戻しました');
        },
      ),
    };

    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    // 幅は利用できる幅いっぱい（最大 420）。高さは形の比率で決まる。
    // 縦長で固定部分が大きくなりすぎないよう、高さは画面の 55%（キーボード中は 110）まで
    final previewHeightLimit = keyboardOpen ? 110.0 : media.size.height * 0.55;
    final ratio = format.aspectW / format.aspectH;
    final padding = HakoPageScaffold.padding(context);

    // プレビュー（枠の線を含む外側の大きさ）。スクロールで縮むときも、
    // 中は同じ大きさのまま FittedBox で拡大縮小する（自動で絞る結果が揺れない）
    Widget previewBox() => DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: BrandColors.ink, width: 2),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: Color(0xE6111111), offset: Offset(3, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: ShareTicketView(
          content: content,
          config: config,
          target: target,
          photoBytes: photos,
          onFit: (fit) {
            if (mounted && fit != _fit) setState(() => _fit = fit);
          },
        ),
      ),
    );

    final postEnd = Container(
      key: const Key('share_postend'),
      margin: const EdgeInsets.only(top: 28),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BrandColors.ink, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Heading('投稿の文章'),
          _captionField(state, target, caption),
          const _Heading('投稿する'),
          if (target == ShareTarget.x)
            _xActions(memory, format, target, caption)
          else
            _igActions(memory, format, target, caption, state),
        ],
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final outerW = math.min(
                _previewMaxWidth,
                math.min(constraints.maxWidth - 32, previewHeightLimit * ratio),
              );
              // 枠の線（左右・上下 2px ずつ）を含めた高さ
              final outerH = (outerW - 4) / ratio + 4;
              // 固定部分の、プレビュー以外の高さ（上 10・投稿先タブ 44・すき間 8・下 8・線 2）
              const chrome = 10.0 + 44 + 8 + 8 + 2;
              const panelTabsH = 48.0;
              final maxExtent = chrome + outerH + panelTabsH;
              final minExtent = chrome + outerH * 0.5 + panelTabsH;
              return CustomScrollView(
                key: ValueKey('share_panel_$_ptab'),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ShareHeaderDelegate(
                      minE: minExtent,
                      maxE: maxExtent,
                      builder: (context, extent) => Column(
                        children: [
                          SizedBox(
                            height: extent - panelTabsH,
                            child: Container(
                              key: const Key('share_fixed'),
                              decoration: const BoxDecoration(
                                color: BrandColors.paper,
                                border: Border(
                                  bottom: BorderSide(
                                    color: BrandColors.ink,
                                    width: 2,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _TargetTabs(
                                    target: target,
                                    onSelect: (t) {
                                      _notifier.selectTarget(t);
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    key: const Key('share_preview'),
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      child: SizedBox(
                                        width: outerW,
                                        child: previewBox(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _PanelTabs(
                            selected: _ptab,
                            onSelect: (i) => setState(() => _ptab = i),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      padding.left,
                      16,
                      padding.right,
                      padding.bottom,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 注意文は、プレビューが縮むと読めないので、パネルの先頭に置く
                          ShareNotes(notes: notes),
                          if (notes.isNotEmpty) const SizedBox(height: 12),
                          panel,
                          // 投稿の欄（どのタブでも一番下）
                          postEnd,
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
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

/// 投稿先のタブ（X／Instagram）
class _TargetTabs extends StatelessWidget {
  const _TargetTabs({required this.target, required this.onSelect});

  final ShareTarget target;
  final ValueChanged<ShareTarget> onSelect;

  @override
  Widget build(BuildContext context) {
    final isX = target == ShareTarget.x;
    return Semantics(
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
          height: 44,
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

/// タブの帯（中身を直す／のせる部分／大きさ）。高さ 48・下に太さ 2 の墨の線
class _PanelTabs extends StatelessWidget {
  const _PanelTabs({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  static const _tabs = [
    ('share_ptab_content', '中身を直す'),
    ('share_ptab_parts', 'のせる部分'),
    ('share_ptab_size', '大きさ'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: BrandColors.paper,
        border: Border(bottom: BorderSide(color: BrandColors.ink, width: 2)),
      ),
      child: Semantics(
        container: true,
        label: '編集のタブ',
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: selected == i,
                  label: _tabs[i].$2,
                  excludeSemantics: true,
                  child: InkWell(
                    key: Key(_tabs[i].$1),
                    onTap: () => onSelect(i),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: selected == i
                                ? BrandColors.hall4
                                : Colors.transparent,
                            width: 4,
                          ),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _tabs[i].$2,
                          maxLines: 1,
                          style: HakoFonts.jp(
                            size: 15,
                            weight: selected == i
                                ? FontWeight.w700
                                : FontWeight.w400,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
      padding: const EdgeInsets.only(top: 18, bottom: 8),
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
