import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/oshi.dart';
import '../../utils/oshi_search.dart';
import '../../utils/text_normalizer.dart';
import '../../providers/oshi_providers.dart';
import 'group_picker_sheet.dart';

/// 推しの追加申請画面（/oshi/request?name=...&group=...）
///
/// 入力中に既存の推しを候補として出す。同じ種別に正規化後の名前・別名が
/// 完全に一致する推しがあれば、申請ボタンを押せなくする（計画書 3.2）。
class OshiRequestPage extends ConsumerStatefulWidget {
  const OshiRequestPage({
    super.key,
    this.initialName = '',
    this.initialGroupId,
  });

  /// 検索欄の文字列（名前の初期値）
  final String initialName;

  /// グループのメンバーの一覧から開いたときの、そのグループの ID。
  /// あれば、種別を個人にし、所属グループに入れておく
  final String? initialGroupId;

  @override
  ConsumerState<OshiRequestPage> createState() => _OshiRequestPageState();
}

class _OshiRequestPageState extends ConsumerState<OshiRequestPage> {
  /// 「もしかして」に出す件数の上限
  static const _maxSimilar = 5;

  // 初期値は作成時に1回だけ入れる。入力中は text を書き換えない
  // （Web の日本語変換が壊れるため）
  late final _nameController = TextEditingController(text: widget.initialName);

  /// 別名の欄。行の Key には [_AliasEntry.id]（消しても変わらない番号）を使い、
  /// 途中の行を消したときにフォーカスや変換中の文字が隣の欄へ移らないようにする
  final List<_AliasEntry> _aliases = [];
  int _nextAliasId = 0;

  /// メンバーの欄（グループのときだけ使う。最初から1つ出しておく）。
  /// 行の Key の考え方は別名と同じ
  final List<_AliasEntry> _members = [_AliasEntry(0, TextEditingController())];
  int _nextMemberId = 1;

  final _agencyController = TextEditingController();
  final _urlController = TextEditingController();
  final _xController = TextEditingController();

  // ファンはふつう個人（推しメン）を申請するので、個人を初期値にする
  OshiKind _kind = OshiKind.person;
  OshiGenre? _genre;
  // メンバーの一覧から開いたときは、そのグループを所属に入れておく
  late List<String> _groupIds = [
    if (widget.initialGroupId case final id? when id.isNotEmpty) id,
  ];

  /// 申請ボタンを一度押したら、各項目のエラーを出す
  bool _showErrors = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    for (final a in _aliases) {
      a.controller.dispose();
    }
    for (final m in _members) {
      m.controller.dispose();
    }
    _agencyController.dispose();
    _urlController.dispose();
    _xController.dispose();
    super.dispose();
  }

  OshiRequest get _request => OshiRequest(
    kind: _kind,
    name: _nameController.text,
    // ジャンル未選択は validate の対象外なので、ここでは仮に other を入れる
    genre: _genre ?? OshiGenre.other,
    aliases: [for (final a in _aliases) a.controller.text],
    agency: _agencyController.text,
    officialUrl: _urlController.text,
    officialX: _xController.text,
    groupIds: _kind == OshiKind.person ? _groupIds : const [],
  );

  void _rebuild() => setState(() {});

  void _addAlias() {
    if (_aliases.length >= OshiRequest.maxAliases) return;
    setState(
      () => _aliases.add(_AliasEntry(_nextAliasId++, TextEditingController())),
    );
  }

  void _removeAlias(_AliasEntry entry) {
    _aliases.remove(entry);
    final c = entry.controller;
    setState(() {});
    // 次のフレームで破棄する（このフレームではまだ TextField が参照している）
    WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
  }

  Future<void> _pickGroups(List<OshiSummary> all) async {
    final picked = await showGroupPickerSheet(
      context,
      all: all,
      selectedIds: _groupIds,
      maxCount: OshiRequest.maxGroupIds,
    );
    if (picked == null || !mounted) return;
    setState(() => _groupIds = picked);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// メンバーの欄に入っている名前（空の欄も含む）
  List<String> get _memberTexts => [
    for (final m in _members) m.controller.text,
  ];

  /// メンバーの欄のエラー（グループのときだけ）。問題がなければ null
  String? get _memberError => _kind == OshiKind.group
      ? validateMemberNames(cleanMemberNames(_memberTexts))
      : null;

  void _addMember() {
    if (_members.length >= maxRequestMembers) return;
    setState(
      () => _members.add(_AliasEntry(_nextMemberId++, TextEditingController())),
    );
  }

  void _removeMember(_AliasEntry entry) {
    _members.remove(entry);
    final c = entry.controller;
    setState(() {});
    // 次のフレームで破棄する（このフレームではまだ TextField が参照している）
    WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _showErrors = true);
    final request = _request;
    if (_genre == null ||
        request.validate().isNotEmpty ||
        _memberError != null) {
      _showSnackBar('入力内容を確かめてください');
      return;
    }
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      _showSnackBar('ログインし直してください');
      return;
    }

    setState(() => _submitting = true);
    try {
      final repository = ref.read(oshiRepositoryProvider);
      if (_kind == OshiKind.group) {
        // グループは、メンバーと一緒に作る（Fb-3）
        await repository.requestGroupWithMembers(
          request,
          _memberTexts,
          uid: uid,
        );
      } else {
        await repository.request(request, uid: uid);
      }
      // State.context を使うので、State の mounted で確認する
      if (!mounted) return;
      _showSnackBar('申請しました。運営の承認後に公開されます');
      final location = Uri(
        path: '/oshi/search',
        queryParameters: {'q': request.trimmedName},
      ).toString();
      context.go(location);
    } on OshiDuplicateException catch (e) {
      if (!mounted) return;
      final names = e.duplicates.map((d) => d.name).join('、');
      _showSnackBar('同じ名前の推しが既にあります（$names）');
    } on OshiRequestException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.messages.join('\n'));
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('申請できませんでした。通信状況を確かめて、もう一度お試しください');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(allOshisProvider);
    final all = allAsync.value ?? const <OshiSummary>[];
    final request = _request;
    final errors = _showErrors
        ? request.validate()
        : const <OshiRequestField, String>{};
    final genreError = _showErrors && _genre == null ? 'ジャンルを選んでください' : null;

    final exact = findExactDuplicates(
      all,
      kind: _kind,
      name: request.name,
      aliases: request.aliases,
    );
    // == は全項目比較なので、同じ推しかどうかは key で判定する（契約 v1.1）
    final exactKeys = {for (final o in exact) o.key};
    final similar = normalizeName(request.name).isEmpty
        ? const <OshiSummary>[]
        : searchOshis(
            all,
            request.name,
          ).where((o) => !exactKeys.contains(o.key)).take(_maxSimilar).toList();

    final canSubmit = !_submitting && allAsync.hasValue && exact.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('推しの追加申請')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('運営が確認して承認すると、みんなに公開されます。'),
            const SizedBox(height: 16),
            _SectionLabel('種別'),
            SegmentedButton<OshiKind>(
              key: const Key('oshi_request_kind'),
              segments: const [
                ButtonSegment(value: OshiKind.person, label: Text('個人')),
                ButtonSegment(value: OshiKind.group, label: Text('グループ')),
              ],
              selected: {_kind},
              onSelectionChanged: _submitting
                  ? null
                  : (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('oshi_request_name_field'),
              controller: _nameController,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: '名前（必須）',
                helperText: '${OshiRequest.maxNameLength}文字まで（絵文字は2文字と数えます）',
                errorText: errors[OshiRequestField.name],
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _rebuild(),
            ),
            if (allAsync.hasError) ...[
              const SizedBox(height: 8),
              const Text(
                '既存の推しを読み込めませんでした。少し待ってから、もう一度開いてください',
                key: Key('oshi_request_load_error'),
              ),
            ],
            if (exact.isNotEmpty) ...[
              const SizedBox(height: 12),
              _CandidateCard(
                key: const Key('oshi_request_exact_card'),
                title: '同じ名前の${_kind.label}が既にあります',
                message: '申請せずに、こちらをフォローしてください。',
                candidates: exact,
                highlight: true,
                actionLabel: '推しを探すで見る',
                onAction: () => context.go(
                  Uri(
                    path: '/oshi/search',
                    queryParameters: {'q': exact.first.name},
                  ).toString(),
                ),
              ),
            ] else if (similar.isNotEmpty) ...[
              const SizedBox(height: 12),
              _CandidateCard(
                key: const Key('oshi_request_similar_card'),
                title: 'もしかして',
                message: '違う推しなら、このまま申請できます。',
                candidates: similar,
              ),
            ],
            const SizedBox(height: 16),
            _SectionLabel('別名・略称（${OshiRequest.maxAliases}個まで）'),
            for (final (i, alias) in _aliases.indexed)
              Padding(
                key: ValueKey('oshi_request_alias_row_${alias.id}'),
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: Key('oshi_request_alias_field_${alias.id}'),
                        controller: alias.controller,
                        enabled: !_submitting,
                        decoration: InputDecoration(
                          labelText: '別名 ${i + 1}',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => _rebuild(),
                      ),
                    ),
                    IconButton(
                      key: Key('oshi_request_remove_alias_button_${alias.id}'),
                      tooltip: 'この別名を消す',
                      icon: const Icon(Icons.close),
                      onPressed: _submitting ? null : () => _removeAlias(alias),
                    ),
                  ],
                ),
              ),
            if (errors[OshiRequestField.aliases] case final message?)
              _ErrorText(message),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('oshi_request_add_alias_button'),
                onPressed:
                    _submitting || _aliases.length >= OshiRequest.maxAliases
                    ? null
                    : _addAlias,
                icon: const Icon(Icons.add),
                label: const Text('別名を追加'),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<OshiGenre>(
              key: const Key('oshi_request_genre_field'),
              initialValue: _genre,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'ジャンル（必須）',
                errorText: genreError,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final g in OshiGenre.values)
                  DropdownMenuItem(value: g, child: Text(g.label)),
              ],
              onChanged: _submitting ? null : (g) => setState(() => _genre = g),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('oshi_request_agency_field'),
              controller: _agencyController,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: '事務所',
                errorText: errors[OshiRequestField.agency],
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _rebuild(),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('oshi_request_url_field'),
              controller: _urlController,
              enabled: !_submitting,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: '公式サイト',
                hintText: 'https://',
                errorText: errors[OshiRequestField.officialUrl],
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _rebuild(),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('oshi_request_x_field'),
              controller: _xController,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: '公式 X アカウント',
                prefixText: '@ ',
                helperText: '英数字と _ の15文字まで',
                errorText: errors[OshiRequestField.officialX],
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _rebuild(),
            ),
                        if (_kind == OshiKind.person) ...[
              const SizedBox(height: 16),
              _SectionLabel('所属グループ（${OshiRequest.maxGroupIds}個まで）'),
              _SelectedGroups(
                all: all,
                groupIds: _groupIds,
                enabled: !_submitting,
                onRemove: (id) =>
                    setState(() => _groupIds = [..._groupIds]..remove(id)),
              ),
              if (errors[OshiRequestField.groupIds] case final message?)
                _ErrorText(message),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('oshi_request_groups_button'),
                  onPressed: _submitting || !allAsync.hasValue
                      ? null
                      : () => _pickGroups(all),
                  icon: const Icon(Icons.group_add),
                  label: const Text('所属グループを選ぶ'),
                ),
              ),
            ],
            // グループは、メンバーを1人以上入れて申請する（Fb-3）
            if (_kind == OshiKind.group) ...[
              const SizedBox(height: 16),
              _SectionLabel('メンバー（必須・$maxRequestMembers人まで）'),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('メンバーも申請中として一緒に作られ、グループと一緒に承認されます。'),
              ),
              for (final (i, member) in _members.indexed)
                Padding(
                  key: ValueKey('oshi_request_member_row_${member.id}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: Key('oshi_request_member_field_${member.id}'),
                          controller: member.controller,
                          enabled: !_submitting,
                          decoration: InputDecoration(
                            labelText: 'メンバー ${i + 1}',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => _rebuild(),
                        ),
                      ),
                      IconButton(
                        key: Key(
                          'oshi_request_remove_member_button_${member.id}',
                        ),
                        tooltip: 'このメンバーを消す',
                        icon: const Icon(Icons.close),
                        // 欄は1つは残す
                        onPressed: _submitting || _members.length <= 1
                            ? null
                            : () => _removeMember(member),
                      ),
                    ],
                  ),
                ),
              if (_showErrors && _memberError != null)
                _ErrorText(_memberError!),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('oshi_request_add_member_button'),
                  onPressed:
                      _submitting || _members.length >= maxRequestMembers
                      ? null
                      : _addMember,
                  icon: const Icon(Icons.person_add),
                  label: const Text('メンバーを追加'),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('oshi_request_submit_button'),
              onPressed: canSubmit ? _submit : null,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('申請する'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 別名の欄1つ分
class _AliasEntry {
  _AliasEntry(this.id, this.controller);

  /// 追加した順の番号（0 から）。消しても詰めない
  final int id;
  final TextEditingController controller;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

/// 既存の推しの候補（完全一致・もしかして）
class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    super.key,
    required this.title,
    required this.message,
    required this.candidates,
    this.highlight = false,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final List<OshiSummary> candidates;
  final bool highlight;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: highlight ? scheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(message),
            const SizedBox(height: 8),
            for (final o in candidates)
              Padding(
                key: ValueKey('oshi_request_candidate_${o.kind.name}_${o.id}'),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '・${o.name}（${o.kind.label}${o.isApproved ? '' : '・申請中'}）',
                ),
              ),
            if (actionLabel != null && onAction != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('oshi_request_go_search_button'),
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedGroups extends StatelessWidget {
  const _SelectedGroups({
    required this.all,
    required this.groupIds,
    required this.enabled,
    required this.onRemove,
  });

  final List<OshiSummary> all;
  final List<String> groupIds;
  final bool enabled;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (groupIds.isEmpty) {
      return const Text('ソロの場合は選ばなくてかまいません');
    }
    final names = {
      for (final o in all)
        if (o.kind == OshiKind.group) o.id: o.name,
    };
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final id in groupIds)
          InputChip(
            key: ValueKey('oshi_request_group_chip_$id'),
            label: Text(names[id] ?? '（見つからないグループ）'),
            onDeleted: enabled ? () => onRemove(id) : null,
          ),
      ],
    );
  }
}
