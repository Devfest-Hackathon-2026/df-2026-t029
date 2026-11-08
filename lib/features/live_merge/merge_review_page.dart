import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/history_entry.dart';
import '../../models/performance.dart';
import '../../models/reception.dart';
import '../../providers/live_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../repositories/live_repository.dart';
import '../../utils/live_diff.dart';
import '../../theme/hako_app_widgets.dart';
import '../live/live_detail_page.dart' show receptionTypeLabels;
import '../live_form/date_time_field.dart';
import '../live_form/live_draft_to_models.dart';

/// 差分の確認画面に渡すもの（既存のライブ一式と入力）
class MergeReviewRequest {
  const MergeReviewRequest({
    required this.base,
    required this.input,
    this.performanceIds,
    this.receptionIds,
    this.editing = false,
  });

  /// 差分を作る既存のライブ一式（同時更新のときは読み直したものに替える）
  final ExistingLive base;
  final LiveModels input;

  /// 編集（3.7）のとき、入力の公演・受付が既存のどの ID から来たか
  final List<String?>? performanceIds;
  final List<String?>? receptionIds;

  /// 編集（3.7）なら true。空にした任意項目を「消す変更」にする
  final bool editing;

  MergeReviewRequest withBase(ExistingLive newBase) => MergeReviewRequest(
    base: newBase,
    input: input,
    performanceIds: performanceIds,
    receptionIds: receptionIds,
    editing: editing,
  );

  LiveMergePlan diff() => diffLive(
    base,
    input,
    performanceIds: performanceIds,
    receptionIds: receptionIds,
    editing: editing,
  );
}

/// 差分の確認画面の結果（Navigator.pop で返す。戻るで閉じたら null）
sealed class MergeReviewResult {
  const MergeReviewResult();
}

/// 反映した（カレンダー追加シート用に、追加・変更したものを持つ）
final class MergeApplied extends MergeReviewResult {
  const MergeApplied(this.saved);

  final SavedLive saved;
}

/// 読み直したら、反映する変更が無くなった
final class MergeNothingToApply extends MergeReviewResult {
  const MergeNothingToApply(this.liveId);

  final String liveId;
}

/// 差分の確認画面を開く（全画面）
Future<MergeReviewResult?> showMergeReview(
  BuildContext context,
  MergeReviewRequest request,
) => Navigator.of(context).push<MergeReviewResult>(
  // PC で横に伸びすぎないように 960 で中央に置く（Fe 3.5）
  MaterialPageRoute(
    builder: (context) => HakoCenteredPage(child: MergeReviewPage(request: request)),
  ),
);

/// 差分の確認画面（計画書 6章）
class MergeReviewPage extends ConsumerStatefulWidget {
  const MergeReviewPage({super.key, required this.request});

  final MergeReviewRequest request;

  @override
  ConsumerState<MergeReviewPage> createState() => _MergeReviewPageState();
}

class _MergeReviewPageState extends ConsumerState<MergeReviewPage> {
  late MergeReviewRequest _request = widget.request;

  /// 手動の対応付けをする前の計画
  late LiveMergePlan _original = _request.diff();

  /// 手動の対応付け（追加のキー → 既存の ID）。取り消しは、残りを
  /// [_original] からかけ直して作る
  final List<({String addedKey, String existingId})> _pairs = [];

  late LiveMergePlan _plan = _original;

  /// ユーザーがチェックを外した行のキー
  final Set<String> _unselected = {};

  /// 反映中（ボタンを押せなくし、二重送信を防ぐ）
  bool _applying = false;

  int get _selectedCount =>
      _plan.selectableKeys.where((k) => !_unselected.contains(k)).length;

  void _rebuildPlan() {
    var plan = _original;
    for (final p in _pairs) {
      plan = pairManually(plan, addedKey: p.addedKey, existingId: p.existingId);
    }
    _plan = plan;
    // 無くなった行のチェックの状態は捨てる（新しく出た行は既定でオン）
    _unselected.retainAll(_plan.selectableKeys);
  }

  void _toggle(String key, bool checked) => setState(() {
    if (checked) {
      _unselected.remove(key);
    } else {
      _unselected.add(key);
    }
  });

  Future<void> _apply() async {
    if (_applying || _selectedCount == 0) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      _showSnack('ログインし直してから、もう一度お試しください');
      return;
    }
    setState(() => _applying = true);
    final repo = ref.read(liveRepositoryProvider);
    try {
      final saved = await repo.applyMerge(
        withoutUnselected(_plan, _unselected),
        uid: uid,
      );
      if (!mounted) return;
      Navigator.of(context).pop(MergeApplied(saved));
    } on LiveConflictException catch (e) {
      debugPrint('反映の競合: $e');
      await _reloadAfterConflict(repo);
    } catch (e) {
      debugPrint('反映に失敗: $e');
      if (!mounted) return;
      setState(() => _applying = false);
      _showSnack('反映できませんでした。通信状況を確かめて、もう一度お試しください');
    }
  }

  /// ほかの人が先に更新した: 最新の内容を読み直し、差分を作り直す（入力は残す）
  Future<void> _reloadAfterConflict(LiveRepository repo) async {
    final liveId = _request.base.live.id!;
    ExistingLive? latest;
    try {
      latest = await repo.fetchExisting(liveId);
    } catch (e) {
      debugPrint('ライブの読み直しに失敗: $e');
    }
    if (!mounted) return;
    if (latest == null) {
      setState(() => _applying = false);
      _showSnack('ほかの人が先に更新しました。最新の内容を読み込めなかったので、もう一度お試しください');
      return;
    }
    final request = _request.withBase(latest);
    final original = request.diff();
    if (original.isEmpty) {
      Navigator.of(context).pop(MergeNothingToApply(liveId));
      return;
    }
    setState(() {
      _request = request;
      _original = original;
      _pairs.clear();
      _unselected.clear();
      _plan = original;
      _applying = false;
    });
    _showSnack('ほかの人が先に更新しました。最新の内容で確認し直してください');
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// 「追加」の公演・受付を、今回の入力に無い既存のものの変更として扱う
  Future<void> _pair(
    String addedKey,
    String addedTitle,
    bool isPerformance,
  ) async {
    // 選べるのは、同じ種類の「今回の入力に無い」既存のものだけ
    final choices = isPerformance
        ? [
            for (final p in _plan.existingOnlyPerformances)
              (id: p.id!, title: _performanceTitle(p)),
          ]
        : [
            for (final r in _plan.existingOnlyReceptions)
              (id: r.id!, title: _receptionTitle(r)),
          ];
    final existingId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          key: const Key('merge_review_pair_sheet'),
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                '「$addedTitle」を、どの${isPerformance ? '公演' : '受付'}の変更として扱いますか',
              ),
              subtitle: const Text('日程変更などで、自動で対応が付かなかったときに使います'),
            ),
            for (final c in choices)
              ListTile(
                key: Key('merge_review_pair_choice_${c.id}'),
                leading: const Icon(Icons.link),
                title: Text(c.title),
                onTap: () => Navigator.of(context).pop(c.id),
              ),
          ],
        ),
      ),
    );
    if (existingId == null || !mounted) return;
    setState(() {
      _pairs.add((addedKey: addedKey, existingId: existingId));
      _rebuildPlan();
    });
  }

  void _unpair(String existingId) => setState(() {
    _pairs.removeWhere((p) => p.existingId == existingId);
    _rebuildPlan();
  });

  bool _isPaired(String? existingId) =>
      _pairs.any((p) => p.existingId == existingId);

  @override
  Widget build(BuildContext context) {
    final oshis = ref.watch(allOshisProvider).value ?? const [];
    final names = {for (final o in oshis) o.id: o.name};
    String nameOf(String id) => names[id] ?? id;
    final plan = _plan;
    final count = _selectedCount;

    return Scaffold(
      appBar: AppBar(title: const Text('変更の確認')),
      body: ListView(
        key: const Key('merge_review_list'),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '「${plan.base.live.title}」に反映する変更を選んでください',
            key: const Key('merge_review_live_title'),
          ),
          const SizedBox(height: 4),
          Text(
            '登録済みの公演・受付は消えません。チェックを外した変更は反映しません。',
            style: Theme.of(context).textTheme.bodySmall,
          ),

          // ---- ライブ ----
          _SectionTitle('ライブ', key: const Key('merge_review_section_live')),
          // 編集で外そうとした出演者（ルールで減らせないので反映しない。3.8）
          if ([
                ...plan.ignoredPerformerRemovals.groupIds,
                ...plan.ignoredPerformerRemovals.oshiIds,
              ].map(nameOf).toList()
              case final kept when kept.isNotEmpty)
            Padding(
              key: const Key('merge_review_unremovable_performers'),
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('出演者は外せません（${kept.join('、')}はそのまま残ります）'),
                  ),
                ],
              ),
            ),
          if (plan.liveChanges.isEmpty)
            const _NoneText('変化なし')
          else
            Card(
              margin: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  for (final c in plan.liveChanges)
                    _FieldCheck(
                      change: c,
                      label: historyFieldLabel(
                        HistoryCollection.lives,
                        c.field,
                      ),
                      nameOf: nameOf,
                      checked: !_unselected.contains(c.key),
                      enabled: !_applying,
                      onChanged: (v) => _toggle(c.key, v),
                    ),
                ],
              ),
            ),

          // ---- 公演 ----
          _SectionTitle(
            '公演',
            key: const Key('merge_review_section_performance'),
          ),
          ..._docSection(
            collection: HistoryCollection.performances,
            added: [
              for (final a in plan.addedPerformances)
                (
                  key: a.key,
                  title: _performanceTitle(a.doc),
                  lines: _performanceLines(a.doc),
                ),
            ],
            changed: [
              for (final d in plan.changedPerformances)
                (
                  id: d.existing.id!,
                  title: _performanceTitle(d.existing),
                  changes: d.changes,
                ),
            ],
            unchanged: [
              for (final p in plan.unchangedPerformances)
                (id: p.id!, title: _performanceTitle(p)),
            ],
            existingOnly: [
              for (final p in plan.existingOnlyPerformances)
                (id: p.id!, title: _performanceTitle(p)),
            ],
            nameOf: nameOf,
          ),

          // ---- 受付 ----
          _SectionTitle('受付', key: const Key('merge_review_section_reception')),
          ..._docSection(
            collection: HistoryCollection.receptions,
            added: [
              for (final a in plan.addedReceptions)
                (
                  key: a.key,
                  title: _receptionTitle(a.doc),
                  lines: _receptionLines(a.doc),
                ),
            ],
            changed: [
              for (final d in plan.changedReceptions)
                (
                  id: d.existing.id!,
                  title: _receptionTitle(d.existing),
                  changes: d.changes,
                ),
            ],
            unchanged: [
              for (final r in plan.unchangedReceptions)
                (id: r.id!, title: _receptionTitle(r)),
            ],
            existingOnly: [
              for (final r in plan.existingOnlyReceptions)
                (id: r.id!, title: _receptionTitle(r)),
            ],
            nameOf: nameOf,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            key: const Key('merge_review_apply_button'),
            onPressed: _applying || count == 0 ? null : _apply,
            child: _applying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(count == 0 ? '反映する変更が選ばれていません' : '反映する（$count件）'),
          ),
        ),
      ),
    );
  }

  List<Widget> _docSection({
    required HistoryCollection collection,
    required List<({String key, String title, List<String> lines})> added,
    required List<({String id, String title, List<FieldChange> changes})>
    changed,
    required List<({String id, String title})> unchanged,
    required List<({String id, String title})> existingOnly,
    required String Function(String id) nameOf,
  }) {
    final section = collection == HistoryCollection.performances
        ? 'performance'
        : 'reception';
    final isPerformance = collection == HistoryCollection.performances;
    final canPair = existingOnly.isNotEmpty && !_applying;
    return [
      if (added.isEmpty &&
          changed.isEmpty &&
          unchanged.isEmpty &&
          existingOnly.isEmpty)
        const _NoneText('ありません'),

      // 追加（ドキュメントごとにチェック）
      for (final a in added)
        Card(
          key: Key('merge_review_row_${a.key}'),
          margin: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                key: Key('merge_review_check_${a.key}'),
                value: !_unselected.contains(a.key),
                onChanged: _applying ? null : (v) => _toggle(a.key, v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                // 色だけに頼らず、文字でも種類を示す
                title: Text('＋ 追加：${a.title}'),
                subtitle: a.lines.isEmpty ? null : Text(a.lines.join('\n')),
              ),
              if (canPair)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: Key('merge_review_pair_${a.key}'),
                    onPressed: () => _pair(a.key, a.title, isPerformance),
                    icon: const Icon(Icons.link),
                    label: const Text('登録済みのものの変更として扱う'),
                  ),
                ),
            ],
          ),
        ),

      // 変更（項目ごとにチェック）
      for (final d in changed)
        Card(
          key: Key('merge_review_row_${collection.name}/${d.id}'),
          margin: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text('変更：${d.title}'),
                trailing: _isPaired(d.id)
                    ? _unpairButton(collection, d.id)
                    : null,
              ),
              for (final c in d.changes)
                _FieldCheck(
                  change: c,
                  label: historyFieldLabel(collection, c.field),
                  nameOf: nameOf,
                  checked: !_unselected.contains(c.key),
                  enabled: !_applying,
                  onChanged: (v) => _toggle(c.key, v),
                ),
            ],
          ),
        ),

      // 今回の入力に無い（消さない。情報として表示）
      for (final e in existingOnly)
        ListTile(
          key: Key('merge_review_row_${collection.name}/${e.id}'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline),
          title: Text(e.title),
          // 編集で行を消しても削除はしない（削除は Step4 の範囲外）
          subtitle: Text(
            _request.editing
                ? '入力から消しましたが、削除はされません（そのまま残ります）'
                : '今回の入力に無い（消さずに残します）',
          ),
        ),

      // 変化なし（折りたたむ）
      if (unchanged.isNotEmpty)
        ExpansionTile(
          key: Key('merge_review_unchanged_$section'),
          tilePadding: EdgeInsets.zero,
          title: Text('変化なし（${unchanged.length}件）'),
          children: [
            for (final u in unchanged)
              ListTile(
                key: Key('merge_review_row_${collection.name}/${u.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check),
                title: Text(u.title),
                trailing: _isPaired(u.id)
                    ? _unpairButton(collection, u.id)
                    : null,
              ),
          ],
        ),
    ];
  }

  Widget _unpairButton(HistoryCollection collection, String existingId) =>
      TextButton(
        key: Key('merge_review_unpair_${collection.name}/$existingId'),
        onPressed: _applying ? null : () => _unpair(existingId),
        child: const Text('対応付けを取り消す'),
      );
}

String _performanceTitle(Performance p) =>
    '${formatDateTime(p.startAt)} ${p.venue}';

List<String> _performanceLines(Performance p) => [
  if (p.openAt != null) '開場：${formatDateTime(p.openAt!)}',
  if (p.prefecture != null) '都道府県：${p.prefecture}',
];

String _receptionTitle(Reception r) =>
    '${receptionTypeLabels[r.type]}「${r.name}」';

List<String> _receptionLines(Reception r) => [
  if (r.applyStartAt != null) '申込開始：${formatDateTime(r.applyStartAt!)}',
  '申込期限：${formatDateTime(r.applyEndAt)}',
  if (r.resultAt != null) '当落発表：${formatDateTime(r.resultAt!)}',
  if (r.paymentDeadline != null) '入金期限：${formatDateTime(r.paymentDeadline!)}',
  if (r.prices.isNotEmpty)
    '料金：${r.prices.map((p) => '${p.seat} ${formatYen(p.amount)}円').join('、')}',
  if (r.winnersOnly) '当選者のみが対象',
];

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _NoneText extends StatelessWidget {
  const _NoneText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text),
  );
}

/// 項目1つの変更（チェック付き。「項目名：変更前 → 変更後」）
class _FieldCheck extends StatelessWidget {
  const _FieldCheck({
    required this.change,
    required this.label,
    required this.nameOf,
    required this.checked,
    required this.enabled,
    required this.onChanged,
  });

  final FieldChange change;
  final String label;
  final String Function(String id) nameOf;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final before = formatHistoryValue(
      change.field,
      change.before,
      present: change.hasBefore,
      nameOf: nameOf,
    );
    final after = formatHistoryValue(
      change.field,
      change.after,
      present: change.hasAfter,
      nameOf: nameOf,
    );
    return CheckboxListTile(
      key: Key('merge_review_check_${change.key}'),
      value: checked,
      onChanged: enabled ? (v) => onChanged(v ?? false) : null,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(label),
      subtitle: Text('$before → $after'),
    );
  }
}
