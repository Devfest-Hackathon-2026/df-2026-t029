import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/oshi.dart';
import '../../providers/favorite_oshi_providers.dart';
import '../../providers/live_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../repositories/live_repository.dart' show FollowTargets;
import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/deadline.dart';
import '../calendar/calendar_add_sheet.dart';
import '../oshi/oshi_list_tile.dart' show OshiKindBadge;
import 'live_list_entries.dart' show PerformerNames;
import 'live_timeline.dart';

/// 1つの区画に最初に出す件数（Fd 3.3）
const _initialCount = 5;

/// ライブ一覧の下の、フォロー中の推しごとの「◯◯の今後のライブ」（Fd 3.3）。
/// 最推しがいれば先頭、ほかはフォロー中の推しの順
class OshiUpcomingLivesList extends ConsumerWidget {
  const OshiUpcomingLivesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(followingOshisProvider);
    final favoriteKey = ref.watch(favoriteOshiKeyProvider).value;
    final muted = HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.5);

    return switch (following) {
      AsyncError() => Padding(
        key: const Key('oshi_upcoming_error'),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('フォロー中の推しを読み込めませんでした', style: muted),
      ),
      AsyncValue(value: final list?) when list.isEmpty => Padding(
        key: const Key('oshi_upcoming_no_following'),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('推しをフォローすると、推しの今後のライブがここに出ます', style: muted),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('oshi_upcoming_search_button'),
              onPressed: () => context.push('/oshi/search'),
              icon: const Icon(Icons.search),
              label: const Text('推しを探す'),
            ),
          ],
        ),
      ),
      AsyncValue(value: final list?) => Column(
        key: const Key('oshi_upcoming_list'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final o in [
            ...list.where((o) => o.key == favoriteKey),
            ...list.where((o) => o.key != favoriteKey),
          ])
            OshiUpcomingLivesSection(
              key: ValueKey('oshi_upcoming_${o.key}'),
              oshi: o,
            ),
        ],
      ),
      _ => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

/// 推し1つ分の「◯◯の今後のライブ」（Fd 3.3）。
/// 個人の区画には所属グループのライブも入る（「ライブを追加する」画面と同じ）
class OshiUpcomingLivesSection extends ConsumerStatefulWidget {
  const OshiUpcomingLivesSection({super.key, required this.oshi});

  final OshiSummary oshi;

  @override
  ConsumerState<OshiUpcomingLivesSection> createState() =>
      _OshiUpcomingLivesSectionState();
}

class _OshiUpcomingLivesSectionState
    extends ConsumerState<OshiUpcomingLivesSection> {
  /// 「すべて見る」を押したか（覚えない）
  bool _showAll = false;

  /// 追加の処理中のライブ ID
  final Set<String> _busy = {};

  ({FollowTargets targets, String query}) get _args =>
      (targets: FollowTargets.fromFollowing([widget.oshi]), query: '');

  Future<void> _add(String liveId) async {
    if (_busy.contains(liveId)) return;
    setState(() => _busy.add(liveId));
    var added = false;
    try {
      final uid = ref.read(currentUidProvider);
      if (uid == null) throw StateError('ログインしていません');
      await ref.read(myLiveRepositoryProvider).add(uid, liveId);
      added = true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('ライブ一覧に追加できませんでした。もう一度お試しください')),
          );
      }
    }
    if (!mounted) return;
    setState(() => _busy.remove(liveId));
    // 「ライブを追加する」画面と同じく、続けて Google カレンダーにも入れられるようにする
    if (added) await addLiveToCalendar(context, ref, liveId);
  }

  void _retry() {
    final args = _args;
    ref.invalidate(searchLivesSourceProvider(args.targets));
    ref.invalidate(searchPerformancesSourceProvider(args.targets));
    ref.invalidate(liveSearchProvider(args));
  }

  @override
  Widget build(BuildContext context) {
    final oshi = widget.oshi;
    final result = ref.watch(liveSearchProvider(_args));
    final added = ref.watch(myLiveIdsProvider).value ?? const <String>{};
    final all = ref.watch(allOshisProvider).value;
    final names = all == null ? null : PerformerNames(all);
    final muted = HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 見出し：推しの札 ＋「◯◯の今後のライブ」
        Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 4),
          child: Row(
            children: [
              OshiKindBadge(oshi: oshi, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    '${oshi.name}の今後のライブ',
                    style: HakoFonts.jp(
                      size: 15,
                      weight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        switch (result) {
          AsyncError() => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text('ライブを読み込めませんでした', style: muted)),
                TextButton(
                  key: Key('oshi_upcoming_retry_${oshi.key}'),
                  onPressed: _retry,
                  child: const Text('もう一度読み込む'),
                ),
              ],
            ),
          ),
          AsyncValue(value: final r?) => _buildLives(
            r.where((e) => !e.isEnded).toList(),
            added,
            names,
            muted,
          ),
          _ => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }

  Widget _buildLives(
    List<LiveListEntry> upcoming,
    Set<String> added,
    PerformerNames? names,
    TextStyle muted,
  ) {
    if (upcoming.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('今後のライブは登録されていません', style: muted),
      );
    }
    final shown = _showAll ? upcoming : upcoming.take(_initialCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++)
          LiveTimelineItem(
            entry: shown[i],
            performers: names?.of(shown[i].live) ?? const [],
            isFirst: i == 0,
            isLast: i == shown.length - 1,
            trailing: _trailing(shown[i].live.id!, added),
          ),
        if (!_showAll && upcoming.length > _initialCount)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: Key('oshi_upcoming_show_all_${widget.oshi.key}'),
              onPressed: () => setState(() => _showAll = true),
              child: Text('すべて見る（${upcoming.length}件）'),
            ),
          ),
      ],
    );
  }

  /// 右端：自分の一覧にあれば「追加済」（押せない）、なければ「追加する！」
  Widget _trailing(String liveId, Set<String> added) {
    if (added.contains(liveId)) {
      return Row(
        key: Key('oshi_upcoming_added_$liveId'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 16, color: BrandColors.sub),
          const SizedBox(width: 4),
          Text(
            '追加済',
            style: HakoFonts.jp(
              size: 13,
              weight: FontWeight.w700,
              color: BrandColors.sub,
              height: 1.3,
            ),
          ),
        ],
      );
    }
    return FilledButton(
      key: Key('oshi_upcoming_add_$liveId'),
      onPressed: _busy.contains(liveId) ? null : () => _add(liveId),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: const Text('追加する！'),
    );
  }
}