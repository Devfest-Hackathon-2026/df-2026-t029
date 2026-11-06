import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/live.dart';
import '../../models/oshi.dart';
import '../../models/trade_post.dart';
import '../../providers/live_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../providers/trade_post_providers.dart';
import '../live_form/date_time_field.dart';
import 'trade_post_draft.dart';

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

  bool get _isEdit => widget.postId != null;
  String get _title => _isEdit ? '投稿を編集' : '交換・売買の投稿を作る';

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    final errors = draft.validate();
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
    try {
      final repository = ref.read(tradePostRepositoryProvider);
      final base = _base;
      if (base == null) {
        await repository.create(
          draft.toPost(),
          uid: uid,
          displayName: anonymousDisplayName,
        );
      } else {
        await repository.update(draft.toPost(base: base));
        ref.invalidate(tradePostByIdProvider(base.id!));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_isEdit ? '投稿を更新しました' : '投稿しました')));
      context.pop();
    } catch (e) {
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
    _draft ??= TradePostDraft();
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

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('投稿者名は「$anonymousDisplayName」と表示されます'),
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
              onPressed: _saving ? null : _save,
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
    final performances = ref.watch(performancesProvider);
    final lives = ref.watch(livesProvider).value ?? const <Live>[];
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
        if (candidates.isEmpty) {
          return const Text('対象の推しの今後の公演はまだ登録されていません');
        }
        final titles = {for (final l in lives) l.id: l.title};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
