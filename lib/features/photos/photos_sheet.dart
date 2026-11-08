import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/live_memory.dart';
import '../../providers/live_providers.dart';
import '../../providers/memory_ticket_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../providers/photo_pick_providers.dart';
import '../../services/google_photos_service.dart';
import '../../services/photo_pick_ai.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/photo_picker.dart';
import '../common/photo_items.dart';
import '../common/storage_image.dart';
import '../memory/ticket/ticket_widgets.dart';
import 'google_photos_consent.dart';

/// PC の幅（720 以上）のとき、シートの最大幅
const double kPhotosSheetMaxWidth = 640;

const double _wideBreakpoint = 720;

/// 「写真を直す」シート（4.3）を下から開く。記録の画面・投稿の画面のどちらからも使う。
/// 「決定」で保存して閉じる。「とじる」・暗幕・Esc は、変更を捨てて閉じる（保存中は閉じられない）
Future<void> showPhotosSheet(
  BuildContext context, {
  required LiveMemory memory,
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
      maxWidth: wide ? kPhotosSheetMaxWidth : double.infinity,
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
      child: Focus(autofocus: true, child: PhotosSheetBody(memory: memory)),
    ),
  );
}

/// 公演のライブの出演者名（先頭1つ）。引けなければ null
final _artistNameProvider = Provider.autoDispose.family<String?, String>((
  ref,
  liveId,
) {
  final live = ref.watch(liveProvider(liveId)).value;
  final all = ref.watch(allOshisProvider).value;
  if (live == null || all == null) return null;
  final ids = live.groupIds.isNotEmpty ? live.groupIds : live.oshiIds;
  for (final id in ids) {
    for (final o in all) {
      if (o.id == id) return o.name;
    }
  }
  return null;
});

/// シートの中身
class PhotosSheetBody extends ConsumerStatefulWidget {
  const PhotosSheetBody({super.key, required this.memory});

  final LiveMemory memory;

  @override
  ConsumerState<PhotosSheetBody> createState() => _PhotosSheetBodyState();
}

class _PhotosSheetBodyState extends ConsumerState<PhotosSheetBody> {
  /// 記録の写真の並び（保存済み・端末から足した写真）。1枚目が表紙
  late final List<PhotoItem> _items = savedPhotoItems(widget.memory.images);

  /// 「決定」の保存中・端末の写真を選んでいる間・「Googleフォトを開く」を押したあと
  bool _saving = false;
  bool _picking = false;
  bool _opened = false;

  /// 画面に出すエラー（Google フォト側は state の error、ここは保存・取り込みの失敗）
  String? _localError;

  /// 選ばなかった写真の一覧を開いているか
  bool _showSkipped = false;

  int get _remainingSlots => maxPhotosPerItem - _items.length;

  PhotoPickNotifier get _notifier => ref.read(photoPickProvider.notifier);

  PhotoPickRequestInfo _info() => PhotoPickRequestInfo(
    title: widget.memory.liveTitle,
    startAt: widget.memory.startAt,
    venue: widget.memory.venue,
    artist: ref.read(_artistNameProvider(widget.memory.liveId)),
  );

  /// 「Googleフォトとつなぐ」「選び直す」。最初のときだけ同意のダイアログを出す。
  /// 認可のポップアップは、ボタンを押した処理の最初（await の前）に呼ぶ
  void _connect() {
    if (_saving || _picking) return;
    if (ref.read(photoPickProvider).busy) return;
    setState(() {
      _localError = null;
      _opened = false;
      _showSkipped = false;
    });
    if (ref.read(googlePhotosConsentedProvider)) {
      _begin();
      return;
    }
    showGooglePhotosConsent(context, onConsent: _begin);
  }

  void _begin() {
    // 同意の印は、このタブのメモリーの中だけ（保存しない）
    ref.read(googlePhotosConsentedProvider.notifier).markConsented();
    _notifier.begin(info: _info(), remainingSlots: _remainingSlots);
  }

  /// 「Googleフォトを開く」。pickerUri を新しいタブで開いてから、選び終わるのを待つ
  void _openPicker(PickerSession session) {
    final uri = session.pickerUri;
    launchUrl(
      uri.replace(path: '${uri.path}/autoclose'),
      webOnlyWindowName: '_blank',
    );
    setState(() => _opened = true);
    _notifier.waitForSelection();
  }

  void _cancelPick() {
    _notifier.cancel();
    setState(() => _opened = false);
  }

  /// 「端末から写真を追加」
  Future<void> _addFromDevice() async {
    if (_saving || _picking) return;
    setState(() {
      _picking = true;
      _localError = null;
    });
    final added = await pickNewPhotos(context, remaining: _remainingSlots);
    if (!mounted) return;
    setState(() {
      _items.addAll(added);
      _picking = false;
    });
  }

  void _close() {
    if (_saving) return;
    _notifier.cancel();
    Navigator.of(context).pop();
  }

  /// 「決定」。Google フォトの写真は、ここで大きいサイズを取り直して保存する
  Future<void> _done() async {
    if (_saving) return;
    final pick = ref.read(photoPickProvider);
    if (pick.busy || _picking) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final editor = ref.read(memoryEditorProvider);
    setState(() {
      _saving = true;
      _localError = null;
    });
    final items = <PhotoItem>[..._items];
    if (pick.selected.isNotEmpty) {
      try {
        items.addAll(await _notifier.materializeSelected());
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _localError = '写真を取り込めませんでした。もう一度選び直してください';
        });
        return;
      }
    }
    try {
      final result = await editor.savePhotos(widget.memory, items);
      if (!result.publicSynced) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('記録は保存しましたが、公開できませんでした。もう一度保存してください')),
          );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _localError = '写真を保存できませんでした。もう一度お試しください';
      });
      return;
    }
    _notifier.cancel();
    if (navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final pick = ref.watch(photoPickProvider);
    final connected = ref.watch(googlePhotosConsentedProvider);
    final error = _localError ?? pick.error;
    final selectedCount = _items.length + pick.selected.length;
    final busy = pick.busy || _saving || _picking;

    final Widget body;
    if (pick.stage == PhotoPickStage.authorizing ||
        pick.stage == PhotoPickStage.fetching ||
        pick.stage == PhotoPickStage.analyzing) {
      body = _Loading(
        text: switch (pick.stage) {
          PhotoPickStage.authorizing => 'Googleフォトとつないでいます…',
          PhotoPickStage.fetching => '写真を取り込んでいます…',
          _ => 'いい写真を選んでいます…',
        },
        onCancel: _cancelPick,
      );
    } else if (pick.stage == PhotoPickStage.waitingPicker) {
      body = _WaitingPicker(
        opened: _opened,
        onOpen: pick.session == null ? null : () => _openPicker(pick.session!),
        onCancel: _cancelPick,
      );
    } else if (_items.isEmpty &&
        pick.selected.isEmpty &&
        pick.candidates.isEmpty &&
        !connected) {
      body = _ConnectBox(
        enabled: !busy,
        onConnect: _connect,
        onManual: _addFromDevice,
      );
    } else {
      body = _PhotosGrid(
        items: _items,
        pick: pick,
        enabled: !busy,
        showSkipped: _showSkipped,
        canAddMore: selectedCount < maxPhotosPerItem,
        onRemoveItem: (i) => setState(() => _items.removeAt(i)),
        onToggleCandidate: _notifier.toggle,
        onToggleSkipped: () => setState(() => _showSkipped = !_showSkipped),
        onReselect: _connect,
        onManual: _addFromDevice,
      );
    }

    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _notifier.cancel();
      },
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: '写真を直す',
        child: DecoratedBox(
          key: const Key('photo_sheet'),
          decoration: const BoxDecoration(
            color: BrandColors.paper,
            border: Border(
              top: BorderSide(color: BrandColors.ink, width: 2),
              left: BorderSide(color: BrandColors.ink, width: 2),
              right: BorderSide(color: BrandColors.ink, width: 2),
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: BrandColors.ink.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          '写真を直す',
                          style: HakoFonts.jp(
                            size: 18,
                            weight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('photo_sheet_close'),
                      tooltip: 'とじる',
                      onPressed: _saving ? null : _close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                body,
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      error,
                      key: const Key('photo_error'),
                      style: HakoFonts.jp(
                        size: 13,
                        color: BrandColors.errorText,
                        height: 1.6,
                      ),
                    ),
                  ),
                if (pick.aiFailed && error == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'AIが写真を選べなかったので、自分で選んでください。',
                      key: const Key('photo_ai_failed'),
                      style: HakoFonts.jp(size: 13, height: 1.6),
                    ),
                  ),
                const SizedBox(height: 14),
                TicketButton(
                  key: const Key('photo_sheet_done'),
                  label: _saving ? '保存しています…' : '決定',
                  icon: Icons.check,
                  kind: TicketButtonKind.green,
                  wide: true,
                  onPressed: busy ? null : _done,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 状態②: 処理中（認可・取り込み・Gemini）
class _Loading extends StatelessWidget {
  const _Loading({required this.text, required this.onCancel});

  final String text;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  text,
                  key: const Key('photo_stage_text'),
                  style: HakoFonts.jp(
                    size: 14,
                    weight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          TicketLinkButton(
            key: const Key('photo_cancel'),
            label: 'やめる',
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// 状態③: Google の選択画面の待ち
class _WaitingPicker extends StatelessWidget {
  const _WaitingPicker({
    required this.opened,
    required this.onOpen,
    required this.onCancel,
  });

  final bool opened;
  final VoidCallback? onOpen;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            'Googleフォトを開いて、公演の日に撮った写真を選び（最大30枚）、「完了」を押してください。',
            textAlign: TextAlign.center,
            style: HakoFonts.jp(size: 14, height: 1.7),
          ),
          const SizedBox(height: 12),
          if (opened)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    '選び終わるのを待っています…',
                    key: const Key('photo_stage_text'),
                    style: HakoFonts.jp(
                      size: 14,
                      weight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            )
          else
            TicketButton(
              key: const Key('photo_open_picker'),
              label: 'Googleフォトを開く',
              icon: Icons.open_in_new,
              kind: TicketButtonKind.green,
              small: true,
              onPressed: onOpen,
            ),
          TicketLinkButton(
            key: const Key('photo_cancel'),
            label: 'やめる',
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// 状態①: つないでいない、かつ写真が0枚
class _ConnectBox extends StatelessWidget {
  const _ConnectBox({
    required this.enabled,
    required this.onConnect,
    required this.onManual,
  });

  final bool enabled;
  final VoidCallback onConnect;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: const DashedBorderPainter(radius: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              'Googleフォトとつなぐと、おしあしが写真を選びます',
              textAlign: TextAlign.center,
              style: HakoFonts.jp(
                size: 15,
                weight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Googleフォトの画面で、公演の日に撮った写真をまとめて選ぶと、その中から、おしあしがいい写真を選びます。',
              textAlign: TextAlign.center,
              style: HakoFonts.jp(
                size: 13,
                color: BrandColors.sub,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 12),
            TicketButton(
              key: const Key('photo_connect_button'),
              label: 'Googleフォトとつなぐ',
              icon: Icons.photo_camera_outlined,
              kind: TicketButtonKind.green,
              small: true,
              onPressed: enabled ? onConnect : null,
            ),
            const SizedBox(height: 2),
            TicketLinkButton(
              key: const Key('photo_manual_add'),
              label: 'つながずに、写真を自分で追加する',
              onPressed: enabled ? onManual : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// 状態④: 写真がある（選んだ写真・ほかの候補・選ばなかった写真）
class _PhotosGrid extends StatelessWidget {
  const _PhotosGrid({
    required this.items,
    required this.pick,
    required this.enabled,
    required this.showSkipped,
    required this.canAddMore,
    required this.onRemoveItem,
    required this.onToggleCandidate,
    required this.onToggleSkipped,
    required this.onReselect,
    required this.onManual,
  });

  final List<PhotoItem> items;
  final PhotoPickState pick;
  final bool enabled;
  final bool showSkipped;
  final bool canAddMore;
  final ValueChanged<int> onRemoveItem;
  final ValueChanged<int> onToggleCandidate;
  final VoidCallback onToggleSkipped;
  final VoidCallback onReselect;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final candidates = pick.candidates;
    final selected = pick.selected;
    final aiPicked = [
      for (final c in candidates)
        if (c.judgement?.decision == PhotoDecision.pick) c,
    ];
    final others = [
      for (final (i, c) in candidates.indexed)
        if (!selected.contains(i) &&
            c.judgement?.decision != PhotoDecision.skip)
          i,
    ];
    final skipped = [
      for (final (i, c) in candidates.indexed)
        if (!selected.contains(i) &&
            c.judgement?.decision == PhotoDecision.skip)
          i,
    ];
    final hasAi =
        pick.stage == PhotoPickStage.done &&
        !pick.aiFailed &&
        aiPicked.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasAi)
          Container(
            key: const Key('photo_ai_note'),
            margin: const EdgeInsets.only(top: 6, bottom: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kAiSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BrandColors.ink, width: 2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'おしあしが選びました。',
                          style: HakoFonts.jp(
                            size: 13,
                            weight: FontWeight.w700,
                            height: 1.65,
                          ),
                        ),
                        TextSpan(
                          text:
                              'あなたが選んだ${candidates.length}枚の中から、よく写っている写真を${aiPicked.length}枚えらんでいます。入れ替えもできます。',
                          style: HakoFonts.jp(size: 13, height: 1.65),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        _Grid(
          children: [
            for (final (i, item) in items.indexed)
              _Cell(
                key: Key('photo_selected_$i'),
                image: switch (item) {
                  SavedPhoto(:final path) => StorageImage(path: path),
                  NewPhoto(:final photo) => Image.memory(
                    photo.bytes,
                    fit: BoxFit.cover,
                  ),
                },
                removeKey: Key('photo_remove_$i'),
                onRemove: enabled ? () => onRemoveItem(i) : null,
              ),
            for (final (j, ci) in selected.indexed)
              _Cell(
                key: Key('photo_selected_${items.length + j}'),
                image: Image.memory(candidates[ci].thumb, fit: BoxFit.cover),
                label: candidates[ci].judgement?.label,
                removeKey: Key('photo_remove_${items.length + j}'),
                onRemove: enabled ? () => onToggleCandidate(ci) : null,
              ),
          ],
        ),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'ほかの候補',
                  style: HakoFonts.jp(
                    size: 13,
                    weight: FontWeight.w700,
                    height: 1.65,
                  ),
                ),
                TextSpan(
                  text: '（タップで追加）',
                  style: HakoFonts.jp(
                    size: 13,
                    color: BrandColors.sub,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _Grid(
            children: [
              for (final ci in others)
                _Cell(
                  key: Key('photo_candidate_item_$ci'),
                  image: Image.memory(candidates[ci].thumb, fit: BoxFit.cover),
                  label: candidates[ci].judgement?.label,
                  faded: true,
                  addKey: Key('photo_candidate_$ci'),
                  onAdd: enabled && canAddMore
                      ? () => onToggleCandidate(ci)
                      : null,
                ),
            ],
          ),
        ],
        if (skipped.isNotEmpty) ...[
          TicketLinkButton(
            key: const Key('photo_skipped_toggle'),
            label: showSkipped
                ? '選ばなかった写真をとじる'
                : '選ばなかった写真（${skipped.length}枚）と理由を見る',
            onPressed: onToggleSkipped,
          ),
          if (showSkipped)
            for (final ci in skipped)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BrandColors.ink, width: 1.5),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Image.memory(
                          candidates[ci].thumb,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        skipReasonText(candidates[ci].judgement?.skipKind),
                        style: HakoFonts.jp(size: 13, height: 1.4),
                      ),
                    ),
                    TicketLinkButton(
                      key: Key('photo_skipped_restore_$ci'),
                      label: '戻す',
                      onPressed: enabled && canAddMore
                          ? () => onToggleCandidate(ci)
                          : null,
                    ),
                  ],
                ),
              ),
        ],
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            TicketButton(
              key: const Key('photo_reselect'),
              label: 'Googleフォトから選び直す',
              icon: Icons.photo_camera_outlined,
              small: true,
              onPressed: enabled ? onReselect : null,
            ),
            TicketButton(
              key: const Key('photo_manual_add'),
              label: '端末から写真を追加',
              icon: Icons.add_photo_alternate_outlined,
              small: true,
              onPressed: enabled && canAddMore ? onManual : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// 3列の正方形の格子（すき間 8）
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

/// 格子の1マス。選んだ写真は右上に「×」、ほかの候補は薄く、右上に緑の「＋」
class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.image,
    this.label,
    this.faded = false,
    this.removeKey,
    this.onRemove,
    this.addKey,
    this.onAdd,
  });

  final Widget image;
  final String? label;
  final bool faded;
  final Key? removeKey;
  final VoidCallback? onRemove;
  final Key? addKey;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Opacity(
      opacity: faded ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.ink, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (label != null && label.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: BrandColors.ink.withValues(alpha: 0.78),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HakoFonts.jp(
                        size: 11,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            if (removeKey != null || addKey != null)
              Positioned(
                top: 0,
                right: 0,
                // 見た目は 30px の円。押せる範囲は 44px
                child: Semantics(
                  button: true,
                  label: removeKey != null
                      ? '${label ?? '写真'}を外す'
                      : '${label ?? '写真'}を追加',
                  excludeSemantics: true,
                  onTap: removeKey != null ? onRemove : onAdd,
                  child: InkResponse(
                    key: removeKey ?? addKey,
                    onTap: removeKey != null ? onRemove : onAdd,
                    radius: 22,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4, right: 4),
                          child: removeKey != null
                              ? Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 16),
                                )
                              : Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: BrandColors.hall4,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: BrandColors.ink,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(Icons.add, size: 16),
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
