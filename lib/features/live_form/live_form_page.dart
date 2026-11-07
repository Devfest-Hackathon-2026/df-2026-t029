import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'date_time_field.dart';
import 'live_draft.dart';
import 'live_draft_to_models.dart';

import '../../models/reception.dart';
import '../../models/oshi.dart';
import '../../providers/live_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../repositories/live_repository.dart';
import '../../services/calendar_events.dart';
import '../../utils/live_match.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../calendar/calendar_add_sheet.dart';
import '../live_merge/live_candidates_sheet.dart';
import '../live_merge/merge_review_page.dart';
import 'performer_picker_sheet.dart';

/// ライブ情報の確認・修正画面（空で開けば手入力の登録画面になる）
class LiveFormPage extends ConsumerStatefulWidget {
  const LiveFormPage({super.key, this.initial, this.editSeed, this.editBase});

  final LiveDraft? initial;

  /// 編集中のライブ（Step4・計画書 3.7）。指定があれば、保存で照合を飛ばし、
  /// [editBase] との差分の確認へ進む
  final LiveEditSeed? editSeed;
  final ExistingLive? editBase;

  @override
  ConsumerState<LiveFormPage> createState() => _LiveFormPageState();
}

class _LiveFormPageState extends ConsumerState<LiveFormPage> {
  late final LiveDraft _draft = widget.initial ?? LiveDraft();

  /// 自動で対応付けられなかった、読み取った出演者名
  List<String> _unmatched = [];
  bool _autoMatched = false;

  /// 保存中（ボタンを押せなくし、二重保存を防ぐ）
  bool _saving = false;

  Future<void> _pickPerformer({
    String initialQuery = '',
    String? resolving,
  }) async {
    final picked = await showPerformerPicker(
      context,
      initialQuery: initialQuery,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _draft.addPerformer(picked);
      if (resolving != null) _unmatched.remove(resolving);
    });
  }

  Future<void> _save() async {
    // setState が反映される前の2回目のタップでも、2回保存しない
    if (_saving) return;
    // 公演0件・長さ・個数の上限は checkLimits() が日本語で返す
    final errors = [..._draft.validate(), ..._draft.checkLimits()];
    if (errors.isNotEmpty) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('入力が足りない項目があります'),
          content: Text(errors.join('\n')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ログインし直してから、もう一度保存してください')));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(liveRepositoryProvider);
    final m = _draft.toModels();

    // 編集: 照合は飛ばし、そのライブとの差分の確認へ（計画書 3.7）
    final editSeed = widget.editSeed;
    final editBase = widget.editBase;
    if (editSeed != null && editBase != null) {
      final ids = editSeed.idsInOrder();
      await _mergeInto(
        MergeReviewRequest(
          base: editBase,
          input: m,
          performanceIds: ids.performanceIds,
          receptionIds: ids.receptionIds,
          editing: true,
        ),
      );
      return;
    }

    // 同じライブが登録済みか照合する（Step4・計画書 3.1）
    final List<LiveCandidate> candidates;
    try {
      candidates = await fetchLiveCandidates(repo, m);
    } catch (e) {
      debugPrint('ライブの照合に失敗: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('登録済みのライブを確認できませんでした。通信状況を確かめて、もう一度お試しください'),
          ),
        );
      return;
    }
    if (!mounted) return;
    if (candidates.isNotEmpty) {
      final choice = await showLiveCandidatesSheet(context, candidates);
      if (!mounted) return;
      switch (choice) {
        case null:
          // 閉じたら何もしない（入力は残す）
          setState(() => _saving = false);
          return;
        case UseExistingLive(:final existing):
          await _mergeInto(MergeReviewRequest(base: existing, input: m));
          return;
        case CreateNewLive():
          break;
      }
    }

    final SavedLive saved;
    try {
      saved = await repo.create(
        live: m.live,
        performances: m.performances,
        receptions: m.receptions,
        uid: uid,
      );
    } catch (e) {
      debugPrint('ライブの保存に失敗: $e');
      // State.context を使うので、State の mounted で確認する
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('保存できませんでした。通信状況を確かめて、もう一度お試しください')),
        );
      return;
    }
    if (!mounted) return;
    await _afterSaved(saved, '保存しました');
  }

  /// 既存のライブとの差分を確認して反映する（Step4・計画書 3.2・3.3）
  Future<void> _mergeInto(MergeReviewRequest request) async {
    final liveId = request.base.live.id!;
    final plan = request.diff();
    if (plan.isEmpty) {
      // 出演者を外そうとしただけなら、外れないことを名前つきで知らせる
      final removals = plan.ignoredPerformerRemovals;
      final names = {
        for (final o
            in ref.read(allOshisProvider).value ?? const <OshiSummary>[])
          o.id: o.name,
      };
      _goAlreadyRegistered(
        liveId,
        keptPerformers: [
          for (final id in [...removals.groupIds, ...removals.oshiIds])
            names[id] ?? id,
        ],
      );
      return;
    }
    final result = await showMergeReview(context, request);
    if (!mounted) return;
    switch (result) {
      case null:
        // 戻るで閉じたら何もしない（入力は残す）
        setState(() => _saving = false);
      case MergeNothingToApply(:final liveId):
        _goAlreadyRegistered(liveId);
      case MergeApplied(:final saved):
        await _afterSaved(saved, '反映しました');
    }
  }

  /// 変更も追加も無い: 書き込まずに、そのライブの詳細へ移る
  void _goAlreadyRegistered(
    String liveId, {
    List<String> keptPerformers = const [],
  }) {
    // 編集で何も変えなかったときは「変更はありません」。出演者を外そうと
    // しただけのときは、外れないことを知らせる（ルールで減らせないため）
    final message = widget.editSeed == null
        ? 'すでに登録済みです'
        : keptPerformers.isNotEmpty
        ? '出演者は外せません（${keptPerformers.join('、')}はそのまま残ります）'
        : '変更はありません';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    context.go('/lives/$liveId');
  }

  /// 保存・反映の後: カレンダー追加シートを出し、ライブ詳細へ移る
  Future<void> _afterSaved(SavedLive saved, String message) async {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

    // 保存後に、予定を選んで Google カレンダーへ追加できるようにする（Step5）
    final events = buildCalendarEvents(
      live: saved.live,
      performances: saved.performances,
      receptions: saved.receptions,
    );
    if (events.isNotEmpty) {
      final added = await showCalendarAddSheet(
        context,
        events,
        liveId: saved.live.id,
      );
      if (!mounted) return;
      if (added) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Google カレンダーに追加しました')));
      }
    }
    if (!mounted) return;
    // go で移動し、フォームを履歴から外す（戻るで同じ内容を再保存しない）
    context.go('/lives/${saved.live.id}');
  }

  @override
  Widget build(BuildContext context) {
    // 推しの一覧が読み込まれたら、読み取った出演者名を1回だけ自動で対応付ける
    final all = ref.watch(allOshisProvider).value;
    if (!_autoMatched && all != null) {
      _autoMatched = true;
      _unmatched = _draft.autoMatchPerformers(all);
    }

    final titleStyle = HakoFonts.jp(
      size: 16,
      weight: FontWeight.w700,
      height: 1.4,
    );
    final subStyle = HakoFonts.jp(size: 12, color: BrandColors.sub);

    return HakoPageScaffold(
      title: widget.editSeed != null
          ? 'ライブ情報の編集'
          : widget.initial == null
          ? 'ライブ情報の入力'
          : 'ライブ情報の確認',
      showBack: true,
      backFallback: widget.editSeed != null ? '/lives' : '/register',
      body: ListView(
        padding: HakoPageScaffold.padding(context),
        children: [
          HakoMarked('ライブ', style: titleStyle),

          const SizedBox(height: 8),
          Text('出演者', style: subStyle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in _draft.selectedPerformers)
                InputChip(
                  backgroundColor: Colors.white,
                  avatar: Icon(
                    o.kind == OshiKind.group ? Icons.groups : Icons.person,
                    size: 18,
                  ),
                  label: Text(o.name),
                  onDeleted: () =>
                      setState(() => _draft.selectedPerformers.remove(o)),
                ),
              ActionChip(
                backgroundColor: BrandColors.tonal,
                labelStyle: HakoFonts.jp(size: 13, weight: FontWeight.w700),
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('出演者を追加'),
                onPressed: () => _pickPerformer(),
              ),
            ],
          ),
          for (final name in _unmatched)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline),
              title: Text('読み取った名前「$name」'),
              subtitle: const Text('一致する推しが見つかりませんでした'),
              trailing: TextButton(
                onPressed: () =>
                    _pickPerformer(initialQuery: name, resolving: name),
                child: const Text('検索して選ぶ'),
              ),
            ),

          TextFormField(
            initialValue: _draft.title,
            decoration: const InputDecoration(labelText: 'ライブ名'),
            onChanged: (v) => _draft.title = v,
          ),
          TextFormField(
            initialValue: _draft.officialUrl,
            decoration: const InputDecoration(labelText: '公式ページの URL'),
            onChanged: (v) => _draft.officialUrl = v,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: HakoMarked('公演', style: titleStyle)),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _draft.performances.add(PerformanceDraft())),
                icon: const Icon(Icons.add),
                label: const Text('追加'),
              ),
            ],
          ),
          for (final p in _draft.performances)
            _PerformanceCard(
              key: ObjectKey(p),
              draft: p,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() => _draft.performances.remove(p)),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: HakoMarked('受付', style: titleStyle)),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _draft.receptions.add(ReceptionDraft())),
                icon: const Icon(Icons.add),
                label: const Text('追加'),
              ),
            ],
          ),
          for (final r in _draft.receptions)
            _ReceptionCard(
              key: ObjectKey(r),
              draft: r,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() => _draft.receptions.remove(r)),
            ),
        ],
      ),
      bottomBar: HakoSaveBar(
        child: FilledButton(
          key: const Key('live_form_save_button'),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final PerformanceDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return HakoBox(
      child: Column(
        children: [
          DateTimeField(
            label: '開演日時',
            value: draft.startAt,
            onChanged: (v) {
              draft.startAt = v;
              onChanged();
            },
          ),
          DateTimeField(
            label: '開場日時',
            value: draft.openAt,
            onChanged: (v) {
              draft.openAt = v;
              onChanged();
            },
          ),
          TextFormField(
            initialValue: draft.venue,
            decoration: const InputDecoration(labelText: '会場名'),
            onChanged: (v) => draft.venue = v,
          ),
          TextFormField(
            initialValue: draft.prefecture,
            decoration: const InputDecoration(labelText: '都道府県'),
            onChanged: (v) => draft.prefecture = v,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              label: const Text('この公演を削除'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceptionCard extends StatelessWidget {
  const _ReceptionCard({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final ReceptionDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  static const _typeLabels = {
    ReceptionType.fc: 'FC先行',
    ReceptionType.general: '一般',
    ReceptionType.upgrade: 'アプグレ',
    ReceptionType.other: 'その他',
  };

  Widget _dateField(
    String label,
    DateTime? value,
    void Function(DateTime?) set,
  ) => DateTimeField(
    label: label,
    value: value,
    onChanged: (v) {
      set(v);
      onChanged();
    },
  );

  @override
  Widget build(BuildContext context) {
    return HakoBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<ReceptionType>(
            initialValue: draft.type,
            decoration: const InputDecoration(labelText: '種別'),
            items: [
              for (final e in _typeLabels.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) {
              if (v == null) return;
              draft.type = v;
              onChanged();
            },
          ),
          TextFormField(
            initialValue: draft.name,
            decoration: const InputDecoration(labelText: '表示名（例：FC1次先行）'),
            onChanged: (v) => draft.name = v,
          ),
          _dateField('申込開始', draft.applyStartAt, (v) => draft.applyStartAt = v),
          _dateField('申込期限', draft.applyEndAt, (v) => draft.applyEndAt = v),
          _dateField('当落発表', draft.resultAt, (v) => draft.resultAt = v),
          _dateField(
            '入金期限',
            draft.paymentDeadline,
            (v) => draft.paymentDeadline = v,
          ),
          // HakoBox の白い背景に隠れないよう、ListTile を Material で包む
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('当選者のみが対象（アプグレなど）'),
              value: draft.winnersOnly,
              onChanged: (v) {
                draft.winnersOnly = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(height: 8),
          Text('料金', style: HakoFonts.jp(size: 12, color: BrandColors.sub)),
          for (final price in draft.prices)
            Row(
              key: ObjectKey(price),
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: price.seat,
                    decoration: const InputDecoration(labelText: '席種'),
                    onChanged: (v) => price.seat = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: price.amount?.toString() ?? '',
                    decoration: const InputDecoration(
                      labelText: '金額',
                      suffixText: '円',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        price.amount = int.tryParse(v.replaceAll(',', '')),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: '料金を削除',
                  onPressed: () {
                    draft.prices.remove(price);
                    onChanged();
                  },
                ),
              ],
            ),
          TextButton.icon(
            onPressed: () {
              draft.prices.add(PriceDraft());
              onChanged();
            },
            icon: const Icon(Icons.add),
            label: const Text('料金を追加'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              label: const Text('この受付を削除'),
            ),
          ),
        ],
      ),
    );
  }
}
