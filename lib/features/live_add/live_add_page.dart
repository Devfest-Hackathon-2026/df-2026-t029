import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/oshi.dart';
import '../../providers/live_providers.dart';
import '../../repositories/live_repository.dart' show FollowTargets;
import '../../providers/oshi_providers.dart';
import '../../utils/deadline.dart';
import '../calendar/calendar_add_sheet.dart';
import '../live/live_list_entries.dart' show PerformerNames;
import '../live_form/date_time_field.dart';
import '../live_form/performer_picker_sheet.dart';

/// ライブを追加する画面（/lives/add）。
/// 推しを選んで、その推しのライブを探し、自分のライブ一覧に追加する。
class LiveAddPage extends ConsumerStatefulWidget {
  const LiveAddPage({super.key});

  @override
  ConsumerState<LiveAddPage> createState() => _LiveAddPageState();
}

class _LiveAddPageState extends ConsumerState<LiveAddPage> {
  final _queryController = TextEditingController();

  /// 選んだ推しのキー（OshiSummary.key）。null なら先頭のフォロー中の推し
  String? _selectedKey;

  /// 「ほかの推しを探す」で選んだ推し（フォローしていないこともある）
  OshiSummary? _extra;

  /// 追加・解除の処理中のライブ ID
  final Set<String> _busy = {};

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _pickOther() async {
    final picked = await showPerformerPicker(context);
    if (picked == null || !mounted) return;
    setState(() {
      _extra = picked;
      _selectedKey = picked.key;
    });
  }

  Future<void> _toggle(String liveId) async {
    if (_busy.contains(liveId)) return;
    setState(() => _busy.add(liveId));
    var added = false;
    try {
      final uid = ref.read(currentUidProvider);
      if (uid == null) throw StateError('ログインしていません');
      final repo = ref.read(myLiveRepositoryProvider);
      final ids = ref.read(myLiveIdsProvider).value ?? const <String>{};
      if (ids.contains(liveId)) {
        await repo.remove(uid, liveId);
      } else {
        await repo.add(uid, liveId);
        added = true;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('ライブ一覧を更新できませんでした。もう一度お試しください')),
          );
      }
    }
    if (!mounted) return;
    setState(() => _busy.remove(liveId));
    // 追加したら、続けて Google カレンダーにも入れられるようにする（F-4）
    if (added) await addLiveToCalendar(context, ref, liveId);
  }

  @override
  Widget build(BuildContext context) {
    final following = ref.watch(followingOshisProvider);
    final all = ref.watch(allOshisProvider);

    // 候補のチップ: フォロー中の推し + 「ほかの推し」で選んだ推し
    final chips = <OshiSummary>[
      ...?following.value,
      if (_extra != null &&
          !(following.value ?? const []).any((o) => o.key == _extra!.key))
        _extra!,
    ];
    final selectedKey = chips.any((o) => o.key == _selectedKey)
        ? _selectedKey
        : (chips.isEmpty ? null : chips.first.key);

    return Scaffold(
      appBar: AppBar(title: const Text('ライブを追加する')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('live_add_register_fab'),
        onPressed: () => context.push('/register'),
        icon: const Icon(Icons.add),
        label: const Text('ライブを登録する'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (following case AsyncError())
                    const Text(
                      'フォロー中の推しを読み込めませんでした',
                      key: Key('live_add_following_error'),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final o in chips)
                          ChoiceChip(
                            key: Key('live_add_oshi_chip_${o.key}'),
                            label: Text(o.name),
                            selected: o.key == selectedKey,
                            onSelected: (_) =>
                                setState(() => _selectedKey = o.key),
                          ),
                        TextButton.icon(
                          key: const Key('live_add_pick_other_button'),
                          onPressed: _pickOther,
                          icon: const Icon(Icons.search),
                          label: const Text('ほかの推しを探す'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('live_add_query_field'),
                    controller: _queryController,
                    decoration: const InputDecoration(
                      labelText: 'ライブ名（空でもOK）',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: selectedKey == null
                  ? (following.isLoading
                        ? const Center(
                            key: Key('live_add_loading'),
                            child: CircularProgressIndicator(),
                          )
                        : const _NoOshiView())
                  : _Results(
                      oshi: chips.firstWhere((o) => o.key == selectedKey),
                      query: _queryController.text,
                      busy: _busy,
                      onToggle: _toggle,
                      names: all.value == null
                          ? null
                          : PerformerNames(all.value!),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoOshiView extends StatelessWidget {
  const _NoOshiView();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('live_add_no_oshi'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '推しをフォローするか、「ほかの推しを探す」から推しを選んでください',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('live_add_search_oshi_button'),
              onPressed: () => context.push('/oshi/search'),
              child: const Text('推しを探す'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({
    required this.oshi,
    required this.query,
    required this.busy,
    required this.onToggle,
    required this.names,
  });

  final OshiSummary oshi;
  final String query;
  final Set<String> busy;
  final Future<void> Function(String liveId) onToggle;
  final PerformerNames? names;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (targets: FollowTargets.fromFollowing([oshi]), query: query);
    final result = ref.watch(liveSearchProvider(args));
    final added = ref.watch(myLiveIdsProvider).value ?? const <String>{};

    return switch (result) {
      AsyncError() => Center(
        key: const Key('live_add_error'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ライブを読み込めませんでした', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('live_add_retry_button'),
                onPressed: () {
                  ref.invalidate(searchLivesSourceProvider(args.targets));
                  ref.invalidate(
                    searchPerformancesSourceProvider(args.targets),
                  );
                  ref.invalidate(liveSearchProvider(args));
                },
                child: const Text('もう一度読み込む'),
              ),
            ],
          ),
        ),
      ),
      AsyncValue(value: final r?) when r.isEmpty => const Center(
        key: Key('live_add_empty'),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '見つかりませんでした。右下の「ライブを登録する」から登録できます',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      AsyncValue(value: final r?) => ListView(
        key: const Key('live_add_results'),
        // 右下のボタンに隠れないように余白をとる
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          for (final e in r)
            _ResultTile(
              entry: e,
              performers: names?.of(e.live) ?? const [],
              isAdded: added.contains(e.live.id),
              isBusy: busy.contains(e.live.id),
              onToggle: () => onToggle(e.live.id!),
            ),
        ],
      ),
      _ => const Center(
        key: Key('live_add_loading'),
        child: CircularProgressIndicator(),
      ),
    };
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.entry,
    required this.performers,
    required this.isAdded,
    required this.isBusy,
    required this.onToggle,
  });

  final LiveListEntry entry;
  final List<String> performers;
  final bool isAdded;
  final bool isBusy;
  final VoidCallback onToggle;

  String _dateLine() {
    final count = entry.performances.length;
    if (entry.isEnded) {
      return '終了（最終公演 ${formatDateTime(entry.performances.last.startAt)}）';
    }
    final next = entry.nextStartAt;
    if (next == null) return '公演の日程は未登録です';
    final venue = entry.performances
        .firstWhere(
          (p) => p.startAt == next,
          orElse: () => entry.performances.first,
        )
        .venue;
    final rest = count > 1 ? '（全$count公演）' : '';
    return '次の公演 ${formatDateTime(next)} $venue$rest';
  }

  @override
  Widget build(BuildContext context) {
    final live = entry.live;
    final p = performers.join('、');
    return ListTile(
      key: Key('live_add_tile_${live.id}'),
      title: Text(live.title),
      subtitle: Text([if (p.isNotEmpty) p, _dateLine()].join('\n')),
      isThreeLine: p.isNotEmpty,
      trailing: isAdded
          ? OutlinedButton(
              key: Key('live_add_remove_button_${live.id}'),
              onPressed: isBusy ? null : onToggle,
              child: const Text('追加済み'),
            )
          : FilledButton(
              key: Key('live_add_add_button_${live.id}'),
              onPressed: isBusy ? null : onToggle,
              child: const Text('追加'),
            ),
      onTap: () => context.push('/lives/${live.id}'),
    );
  }
}
