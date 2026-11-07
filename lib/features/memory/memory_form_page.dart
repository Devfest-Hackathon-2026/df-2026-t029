import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/live_memory.dart';
import '../../providers/live_providers.dart';
import '../../providers/memory_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../providers/photo_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/photo_picker.dart';
import '../common/photo_items.dart';
import '../live_form/date_time_field.dart';

/// セトリの曲数の上限
const maxSetlistSongs = 100;

/// 座席・曲名1つの文字数の上限
const maxSeatLength = 100;
const maxSongLength = 100;

/// 感想の文字数の上限
const maxImpressionLength = 2000;

/// 記録の作成・編集
/// （作成: /lives/:liveId/memory/:performanceId、編集: /memories/:performanceId/edit）。
/// 記録があれば編集、無ければ [liveId] のライブの公演から作る
class MemoryFormPage extends ConsumerWidget {
  const MemoryFormPage({super.key, required this.performanceId, this.liveId});

  final String performanceId;

  /// 作成のときだけ使う（編集では null）
  final String? liveId;

  /// 編集・作成のもとになる記録。見つからなければ null
  AsyncValue<({LiveMemory memory, bool isNew})?> _baseOf(WidgetRef ref) {
    final existing = ref.watch(memoryProvider(performanceId));
    if (existing case AsyncError(:final error, :final stackTrace)) {
      return AsyncError(error, stackTrace);
    }
    if (!existing.hasValue) return const AsyncLoading();
    if (existing.value case final memory?) {
      return AsyncData((memory: memory, isNew: false));
    }
    final liveId = this.liveId;
    if (liveId == null) return const AsyncData(null);
    final live = ref.watch(liveProvider(liveId));
    final performances = ref.watch(performancesOfLiveProvider(liveId));
    for (final AsyncValue<Object?> v in [live, performances]) {
      if (v case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
    }
    if (!live.hasValue || !performances.hasValue) return const AsyncLoading();
    final liveValue = live.value;
    final performance = performances.requireValue
        .where((p) => p.id == performanceId)
        .firstOrNull;
    if (liveValue == null || performance == null) return const AsyncData(null);
    return AsyncData((
      memory: LiveMemory.fromPerformance(liveValue, performance),
      isNew: true,
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (_baseOf(ref)) {
      AsyncError() => const _MessagePage(
        key: Key('memory_form_error'),
        text: '記録を読み込めませんでした',
      ),
      AsyncData(value: final base?) => _MemoryForm(
        memory: base.memory,
        isNew: base.isNew,
      ),
      AsyncData() => const _MessagePage(
        key: Key('memory_form_not_found'),
        text: 'この公演は見つかりませんでした',
      ),
      _ => const HakoPageScaffold(
        key: Key('memory_form_loading'),
        title: '記録',
        showBack: true,
        backFallback: '/lives',
        body: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _MessagePage extends StatelessWidget {
  const _MessagePage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return HakoPageScaffold(
      title: '記録',
      showBack: true,
      backFallback: '/lives',
      body: HakoEmpty(text),
    );
  }
}

/// セトリの入力（1行1曲）を曲名の一覧にする。前後の空白を除き、空行は捨てる
List<String> parseSetlist(String text) => [
  for (final line in text.split('\n'))
    if (line.trim() case final song when song.isNotEmpty) song,
];

/// 前後の空白を除き、空なら null
String? _nullIfBlank(String text) {
  final t = text.trim();
  return t.isEmpty ? null : t;
}

class _MemoryForm extends ConsumerStatefulWidget {
  const _MemoryForm({required this.memory, required this.isNew});

  final LiveMemory memory;
  final bool isNew;

  @override
  ConsumerState<_MemoryForm> createState() => _MemoryFormState();
}

class _MemoryFormState extends ConsumerState<_MemoryForm> {
  final _formKey = GlobalKey<FormState>();
  late final _seat = TextEditingController(text: widget.memory.seat ?? '');
  late final _setlist = TextEditingController(
    text: widget.memory.setlist.join('\n'),
  );
  late final _impression = TextEditingController(
    text: widget.memory.impression ?? '',
  );

  /// 写真の並び（最初はもとの images）。1枚目が表紙
  late final List<PhotoItem> _photos = savedPhotoItems(widget.memory.images);

  /// 保存・削除・写真の読み込みの処理中（二重送信の防止）
  bool _busy = false;

  @override
  void dispose() {
    _seat.dispose();
    _setlist.dispose();
    _impression.dispose();
    super.dispose();
  }

  String? _validateSetlist(String? value) {
    final songs = parseSetlist(value ?? '');
    if (songs.length > maxSetlistSongs) {
      return 'セトリは$maxSetlistSongs曲までです';
    }
    if (songs.any((s) => s.length > maxSongLength)) {
      return '曲名は1曲$maxSongLength文字までです';
    }
    return null;
  }

  void _showMessage(ScaffoldMessengerState messenger, String text) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// 写真を選んで並びの最後に足す（まだアップロードしない）
  Future<void> _addPhotos() async {
    if (_busy) return;
    setState(() => _busy = true);
    final added = await pickNewPhotos(
      context,
      remaining: maxPhotosPerItem - _photos.length,
    );
    if (!mounted) return;
    setState(() {
      _photos.addAll(added);
      _busy = false;
    });
  }

  /// 保存（M-5 仕様書 3.3）。新しい写真をアップロード → 記録を保存 → 外した写真を消す
  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final original = widget.memory;
    final isNew = widget.isNew;
    final repo = ref.read(memoryRepositoryProvider);
    final photoRepo = ref.read(photoRepositoryProvider);
    // 保存すると記録の購読が変わり、この画面が作り直されることがあるため先に取っておく
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);

    // 1. 新しい写真をアップロードする（失敗したら、上げた分は消えている）
    Map<NewPhoto, String> uploaded;
    try {
      uploaded = await uploadNewPhotos(
        photoRepo,
        'users/$uid/memories/${original.performanceId}',
        _photos,
      );
    } catch (e) {
      debugPrint('写真のアップロードに失敗: $e');
      if (mounted) setState(() => _busy = false);
      _showMessage(messenger, '写真を保存できませんでした。もう一度お試しください');
      return;
    }
    final images = photoPathsOf(_photos, uploaded);

    // 2. 記録を保存する
    final memory = original.copyWithContent(
      seat: _nullIfBlank(_seat.text),
      setlist: parseSetlist(_setlist.text),
      impression: _nullIfBlank(_impression.text),
      images: images,
    );
    try {
      if (isNew) {
        await repo.create(uid, memory);
      } else {
        await repo.update(uid, memory);
      }
    } catch (e) {
      debugPrint('記録の保存に失敗: $e');
      await photoRepo.deleteAll(uploaded.values);
      if (mounted) setState(() => _busy = false);
      _showMessage(messenger, '記録を保存できませんでした。もう一度お試しください');
      return;
    }

    // 3. 外した写真を消す（失敗しても無視。待たずに戻る）
    unawaited(
      photoRepo.deleteAll(original.images.where((p) => !images.contains(p))),
    );

    // 作成はライブの詳細へ、編集は記録の詳細へ戻る
    router.go(
      isNew ? '/lives/${memory.liveId}' : '/memories/${memory.performanceId}',
    );
  }

  Future<void> _delete() async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('記録を削除しますか？'),
        content: const Text('座席・セトリ・感想・写真も消え、元には戻せません'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            key: const Key('memory_form_delete_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final memory = widget.memory;
    final repo = ref.read(memoryRepositoryProvider);
    final photoRepo = ref.read(photoRepositoryProvider);
    // 削除すると記録が無くなり、この画面が「見つかりません」に替わるため先に取っておく
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await repo.delete(uid, memory.performanceId);
    } catch (e) {
      debugPrint('記録の削除に失敗: $e');
      if (mounted) setState(() => _busy = false);
      _showMessage(messenger, '記録を削除できませんでした。もう一度お試しください');
      return;
    }
    // 保存済みの写真を消す（失敗しても無視。待たずに戻る）
    unawaited(photoRepo.deleteAll(memory.images));
    router.go('/memories');
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.memory;
    final subStyle = HakoFonts.jp(
      size: 13,
      color: BrandColors.sub,
      height: 1.5,
    );
    return HakoPageScaffold(
      title: widget.isNew ? '記録する' : '記録を編集',
      showBack: true,
      backFallback: widget.isNew ? '/lives' : '/memories',
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: HakoPageScaffold.padding(context),
            children: [
              if (!widget.isNew)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    key: const Key('memory_form_delete_button'),
                    tooltip: '削除',
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              Text(
                m.liveTitle,
                style: HakoFonts.jp(
                  size: 20,
                  weight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text('${formatDateTime(m.startAt)} 開演', style: subStyle),
              Text(m.venue, style: subStyle),
              const SizedBox(height: 18),
              TextFormField(
                key: const Key('memory_form_seat'),
                controller: _seat,
                maxLength: maxSeatLength,
                decoration: const InputDecoration(
                  labelText: '座席',
                  hintText: '例：アリーナ B3ブロック 12列 34番',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('memory_form_setlist'),
                controller: _setlist,
                minLines: 5,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                validator: _validateSetlist,
                decoration: const InputDecoration(
                  labelText: 'セトリ',
                  hintText: '1行に1曲ずつ書いてください',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('memory_form_impression'),
                controller: _impression,
                minLines: 5,
                maxLines: null,
                maxLength: maxImpressionLength,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: '感想',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              PhotoEditSection(
                title: '写真（${_photos.length}/$maxPhotosPerItem）',
                photos: _photos,
                canAdd: !_busy && _photos.length < maxPhotosPerItem,
                enabled: !_busy,
                onAdd: _addPhotos,
                onRemove: (i) => setState(() => _photos.removeAt(i)),
                addButtonKey: const Key('memory_form_add_photo'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('memory_form_save_button'),
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
