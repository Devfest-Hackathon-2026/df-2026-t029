import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/goods.dart';
import '../../models/live.dart';
import '../../models/oshi.dart';
import '../../models/trade_post.dart';
import '../../providers/goods_providers.dart';
import '../../providers/live_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../providers/photo_providers.dart';
import '../../providers/trade_post_providers.dart';
import '../../providers/profile_providers.dart';
import '../common/photo_items.dart';
import '../live_form/date_time_field.dart';
import 'trade_post_draft.dart';
import 'trade_sets_section.dart';

/// 投稿の作成・編集画面。[postId] があれば編集、なければ新規作成
class TradePostFormPage extends ConsumerStatefulWidget {
  const TradePostFormPage({super.key, this.postId});

  final String? postId;

  @override
  ConsumerState<TradePostFormPage> createState() => _TradePostFormPageState();
}

class _TradePostFormPageState extends ConsumerState<TradePostFormPage> {
  TradePostDraft? _draft;

  /// 編集前の値（編集のときだけ）
  TradePost? _base;
  List<String> _errors = const [];
  bool _saving = false;

  /// 写真を選んでいる最中（G-7）
  bool _picking = false;

  bool get _isEdit => widget.postId != null;
  String get _title => _isEdit ? '投稿を編集' : '交換・売買の投稿を作る';

  /// 検索用キーの数を数えるための、譲の品目のグッズ。
  /// 読めなかったときは空（キーはリポジトリが保存時に作り直す）
  Future<Map<String, Goods>> _goodsForKeys(TradePostDraft draft) async {
    if (draft.gives.isEmpty) return const {};
    final scope = goodsScopeFor(
      groupIds: draft.groupIds,
      oshiIds: draft.oshiIds,
      all: ref.read(allOshisProvider).value ?? const [],
    );
    try {
      final list = await ref.read(goodsInScopeProvider(scope).future);
      return {
        for (final g in list)
          if (g.id != null) g.id!: g,
      };
    } catch (_) {
      return const {};
    }
  }

  /// 写真を選んで [target]（投稿全体またはセットの写真）の最後に足す。
  /// 選べる枚数は、投稿全体とセットの合計の残り（G-7 仕様書 6.2）
  Future<void> _addPhotos(List<PhotoItem> target) async {
    final draft = _draft;
    if (draft == null || _saving || _picking) return;
    setState(() => _picking = true);
    final added = await pickNewPhotos(
      context,
      remaining: TradePost.maxImages - draft.photoCount,
    );
    if (!mounted) return;
    setState(() {
      target.addAll(added);
      _picking = false;
    });
  }

  /// 保存（G-7 仕様書 6.2）。新しい写真をアップロード → 投稿を保存 →
  /// 編集では、外した写真を消す
  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _saving || _picking) return;
    final errors = draft.validate(goodsById: await _goodsForKeys(draft));
    if (!mounted) return;
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() {
      _saving = true;
      _errors = const [];
    });
    final photoRepo = ref.read(photoRepositoryProvider);
    var uploaded = const <NewPhoto, String>{};
    var saved = false;
    try {
      // アップロードに失敗したら、上げた分は uploadNewPhotos が消している
      uploaded = await uploadNewPhotos(
        photoRepo,
        'tradePhotos/$uid',
        draft.allPhotos,
      );
      final repository = ref.read(tradePostRepositoryProvider);
      final base = _base;
      if (base == null) {
        await repository.create(
          draft.toPost(uploaded: uploaded),
          uid: uid,
          displayName: ref.read(myDisplayNameProvider),
        );
        saved = true;
      } else {
        final post = draft.toPost(base: base, uploaded: uploaded);
        await repository.update(post);
        saved = true;
        ref.invalidate(tradePostByIdProvider(base.id!));
        // 外した写真（消したセットの写真も含む）を消す。失敗しても無視・待たない
        final kept = {
          ...post.images,
          for (final s in post.gives) ...s.images,
        };
        unawaited(
          photoRepo.deleteAll([
            ...base.images,
            for (final s in base.gives) ...s.images,
          ].where((p) => !kept.contains(p))),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_isEdit ? '投稿を更新しました' : '投稿しました')));
      context.pop();
    } catch (e) {
      // 投稿の保存に失敗したときは、この保存でアップロードした写真を消す
      if (!saved) await photoRepo.deleteAll(uploaded.values);
      if (!mounted) return;
      setState(() => _errors = ['保存できませんでした: $e']);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit) {
      final post = ref.watch(tradePostByIdProvider(widget.postId!));
      return post.when(
        loading: () => _message(null),
        error: (e, _) => _message('投稿を読み込めませんでした: $e'),
        data: (p) {
          if (p == null) return _message('投稿が見つかりません');
          if (p.uid != ref.watch(currentUidProvider)) {
            return _message('自分の投稿だけ編集できます');
          }
          if (p.status == TradePostStatus.hidden) {
            return _message('この投稿は運営により非表示にされているため、編集できません');
          }
          _base ??= p;
          _draft ??= TradePostDraft.fromPost(p);
          return _form();
        },
      );
    }
    // 新規作成では、プロフィールの X アカウントを初期値にする（G-8）。
    // 掲示板で推しを選んでいれば、その推しを対象の推しとして選んでおく（Fa-4）
    if (_draft == null) {
      final draft = TradePostDraft(
        xAccount: ref.read(myProfileProvider).value?.xAccount ?? '',
      );
      final target = ref.read(boardTargetProvider);
      if (target != null) draft.toggleTarget(target);
      _draft = draft;
    }
    return _form();
  }

  /// 読み込み中（[text] が null）やエラーのときの画面
  Widget _message(String? text) => Scaffold(
    appBar: AppBar(title: Text(_title)),
    body: Center(
      child: text == null
          ? const CircularProgressIndicator()
          : Padding(padding: const EdgeInsets.all(16), child: Text(text)),
    ),
  );

  void _showLimit(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Widget _form() {
    final draft = _draft!;
    final theme = Theme.of(context);
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: Text(text, style: theme.textTheme.titleMedium),
    );
    // 写真（G-7）：合計の上限・処理中は追加できない。保存中は外せない
    final photosEnabled = !_saving && !_picking;
    final canAddPhoto =
        photosEnabled && draft.photoCount < TradePost.maxImages;

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('投稿者名は「${ref.watch(myDisplayNameProvider)}」と表示されます'),
            heading('対象の推し（必須・複数可）'),
            _TargetChips(
              draft: draft,
              onToggle: (o) => setState(() {
                if (!draft.toggleTarget(o)) {
                  _showLimit(
                    '対象の推しは、グループ・個人それぞれ'
                    '${TradePostDraft.maxTargets}個までです',
                  );
                }
              }),
            ),
            heading('取引のタグ（必須・複数可）'),
            Wrap(
              spacing: 8,
              children: [
                for (final t in TradeTag.values)
                  FilterChip(
                    key: Key('trade_tag_${t.name}'),
                    label: Text(t.label),
                    selected: draft.tags.contains(t),
                    onSelected: (on) => setState(
                      () => on ? draft.tags.add(t) : draft.tags.remove(t),
                    ),
                  ),
              ],
            ),
            if (draft.hasPrice) ...[
              heading('価格（必須）'),
              const Text('金額は入力しません。定価を超える価格は選べません。送料などは備考に書いてください'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in PriceType.values)
                    ChoiceChip(
                      key: Key('trade_price_${p.name}'),
                      label: Text(p.label),
                      selected: draft.priceType == p,
                      onSelected: (_) => setState(() => draft.priceType = p),
                    ),
                ],
              ),
            ],
            heading('受け渡し方法（必須・両方可）'),
            Wrap(
              spacing: 8,
              children: [
                for (final h in HandoverMethod.values)
                  FilterChip(
                    key: Key('trade_handover_${h.name}'),
                    label: Text(h.label),
                    selected: draft.handover.contains(h),
                    onSelected: (on) => setState(
                      () =>
                          on ? draft.handover.add(h) : draft.handover.remove(h),
                    ),
                  ),
              ],
            ),
            if (draft.isHand) ...[
              heading('手渡しの公演（任意・複数可）'),
              _PerformanceChips(
                draft: draft,
                onToggle: (id) => setState(() {
                  if (!draft.togglePerformance(id)) {
                    _showLimit('公演は${TradePostDraft.maxPerformances}個まで選べます');
                  }
                }),
              ),
            ],
            heading('譲（出せるもの）'),
            const Text('譲・求の片方だけでも、どちらもなくても投稿できます。品目を選ばない投稿は、自動のマッチングの対象外です'),
            GiveSetsSection(
              draft: draft,
              onChanged: () => setState(() {}),
              canAddPhoto: canAddPhoto,
              photosEnabled: photosEnabled,
              onAddPhotos: (set) => _addPhotos(set.photos),
            ),
            heading('求（欲しいもの）'),
            WantSetsSection(draft: draft, onChanged: () => setState(() {})),
            heading(
              '写真（投稿全体とセットで${draft.photoCount}/${TradePost.maxImages}枚）',
            ),
            const Text('譲の現物の写真は、各譲セットの中にも付けられます'),
            const SizedBox(height: 8),
            PhotoEditSection(
              title: '投稿全体の写真',
              photos: draft.photos,
              canAdd: canAddPhoto,
              enabled: photosEnabled,
              onAdd: () => _addPhotos(draft.photos),
              onRemove: (i) => setState(() => draft.photos.removeAt(i)),
              addButtonKey: const Key('trade_add_photo'),
            ),
            heading('連絡先・備考'),
            TextFormField(
              key: const Key('trade_x_account'),
              initialValue: draft.xAccount,
              decoration: const InputDecoration(
                labelText: 'X アカウント（任意）',
                prefixText: '@',
                hintText: 'oshiashi_fan',
              ),
              onChanged: (v) => draft.xAccount = v,
            ),
            TextFormField(
              key: const Key('trade_note'),
              initialValue: draft.note,
              decoration: const InputDecoration(
                labelText: '備考（任意）',
                hintText: '例：送料はご負担ください',
              ),
              minLines: 3,
              maxLines: 8,
              maxLength: TradePostDraft.maxNoteLength,
              onChanged: (v) => draft.note = v,
            ),
            const SizedBox(height: 16),
            for (final e in _errors)
              Text(e, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('trade_save_button'),
              onPressed: _saving || _picking ? null : _save,
              child: Text(_saving ? '保存中…' : (_isEdit ? '更新する' : '投稿する')),
            ),
          ],
        ),
      ),
    );
  }
}

/// 対象の推しの選択肢（フォロー中の推し＋選択済みの推し）
class _TargetChips extends ConsumerWidget {
  const _TargetChips({required this.draft, required this.onToggle});

  final TradePostDraft draft;
  final void Function(OshiSummary) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(followingOshisProvider);
    final all = ref.watch(allOshisProvider).value ?? const <OshiSummary>[];
    return following.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('フォロー中の推しを読み込めませんでした: $e'),
      data: (list) {
        final ids = {for (final o in list) o.id};
        // 編集時、フォローを外した推しも選択済みとして出す
        final options = [
          ...list,
          for (final o in all)
            if (!ids.contains(o.id) && draft.isTarget(o)) o,
        ];
        if (options.isEmpty) {
          return const Text('推しをフォローすると、ここで選べます');
        }
        return Wrap(
          spacing: 8,
          children: [
            for (final o in options)
              FilterChip(
                key: Key('trade_target_${o.id}'),
                label: Text(o.name),
                selected: draft.isTarget(o),
                onSelected: (_) => onToggle(o),
              ),
          ],
        );
      },
    );
  }
}

/// 手渡しの公演の選択肢
class _PerformanceChips extends ConsumerWidget {
  const _PerformanceChips({required this.draft, required this.onToggle});

  final TradePostDraft draft;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (draft.groupIds.isEmpty && draft.oshiIds.isEmpty) {
      return const Text('対象の推しを選ぶと、今後の公演から選べます');
    }
    final performances = ref.watch(myPerformancesProvider);
    final lives = ref.watch(myLivesProvider).value ?? const <Live>[];
    final all = ref.watch(allOshisProvider).value ?? const <OshiSummary>[];
    final now = ref.watch(nowProvider);
    return performances.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('公演を読み込めませんでした: $e'),
      data: (list) {
        final candidates = handoverPerformanceCandidates(
          performances: list,
          groupIds: draft.groupIds,
          oshiIds: draft.oshiIds,
          all: all,
          now: now,
          selectedIds: draft.performanceIds,
        );
        // 一覧から外したライブの公演が、選ばれたまま残っているもの
        final knownIds = {for (final p in list) p.id};
        final missing = [
          for (final id in draft.performanceIds)
            if (!knownIds.contains(id)) id,
        ];
        final titles = {for (final l in lives) l.id: l.title};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (missing.isNotEmpty)
              Row(
                key: const Key('trade_performance_missing'),
                children: [
                  Expanded(
                    child: Text('ライブ一覧に無い公演が${missing.length}件選ばれています'),
                  ),
                  TextButton(
                    key: const Key('trade_performance_missing_remove'),
                    onPressed: () {
                      for (final id in missing) {
                        onToggle(id);
                      }
                    },
                    child: const Text('外す'),
                  ),
                ],
              ),
            if (candidates.isEmpty) ...[
              const Text('この推しのライブを、ライブ一覧に追加すると選べます'),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('trade_performance_add_live_button'),
                  onPressed: () => context.push('/lives/add'),
                  icon: const Icon(Icons.add),
                  label: const Text('ライブを追加する'),
                ),
              ),
            ],
            for (final p in candidates)
              CheckboxListTile(
                key: Key('trade_performance_${p.id}'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: draft.performanceIds.contains(p.id),
                onChanged: (_) => onToggle(p.id!),
                title: Text(titles[p.liveId] ?? '（ライブ名不明）'),
                subtitle: Text('${formatDateTime(p.startAt)}　${p.venue}'),
              ),
          ],
        );
      },
    );
  }
}
