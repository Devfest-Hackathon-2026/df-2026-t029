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
import '../live_fetch/live_fetch_dialog.dart';
import 'live_list_entries.dart' show PerformerNames;
import 'merged_live.dart';
import 'live_timeline.dart';

/// 1つの区画に最初に出す件数（Fd 3.3）
const _initialCount = 5;

/// 推しの今後のライブの区画（Ff-9）：グループに入っているメンバーは、所属グループ
/// （groupIds の1つ目）の区画にまとめる。グループをフォローしていなくても区画を作る。
/// 最推し（または最推しのメンバーを含む区画）が先頭、ほかはフォロー中の推しの順
List<({OshiSummary oshi, List<OshiSummary> members})> oshiSectionsOf(
  List<OshiSummary> following,
  List<OshiSummary> all,
  String? favoriteKey,
) {
  final groupsById = {
    for (final o in all)
      if (o.kind == OshiKind.group) o.id: o,
  };
  final sections = <String, ({OshiSummary oshi, List<OshiSummary> members})>{};
  for (final o in following) {
    if (o.kind == OshiKind.person && o.groupIds.isNotEmpty) {
      final g = groupsById[o.groupIds.first];
      if (g != null) {
        sections
            .putIfAbsent(g.key, () => (oshi: g, members: <OshiSummary>[]))
            .members
            .add(o);
        continue;
      }
    }
    sections.putIfAbsent(o.key, () => (oshi: o, members: <OshiSummary>[]));
  }
  final list = sections.values.toList();
  bool hasFavorite(({OshiSummary oshi, List<OshiSummary> members}) s) =>
      s.oshi.key == favoriteKey || s.members.any((m) => m.key == favoriteKey);
  return [...list.where(hasFavorite), ...list.where((s) => !hasFavorite(s))];
}

/// 「フォロー中のメンバー：A・B ほかn人」
String _membersLine(List<OshiSummary> members) {
  final names = [for (final m in members) m.name];
  final head = names.take(2).join('・');
  return names.length > 2
      ? 'フォロー中のメンバー：$head ほか${names.length - 2}人'
      : 'フォロー中のメンバー：$head';
}

/// ライブ一覧の下の、フォロー中の推しごとの「◯◯の今後のライブ」（Fd 3.3）。
/// 最推しがいれば先頭、ほかはフォロー中の推しの順
class OshiUpcomingLivesList extends ConsumerWidget {
  const OshiUpcomingLivesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(followingOshisProvider);
    final favoriteKey = ref.watch(favoriteOshiKeyProvider).value;
    final all = ref.watch(allOshisProvider).value ?? const <OshiSummary>[];
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
          // メンバーはグループの区画にまとめる（Ff-9）
          for (final s in oshiSectionsOf(list, all, favoriteKey))
            OshiUpcomingLivesSection(
              key: ValueKey('oshi_upcoming_${s.oshi.key}'),
              oshi: s.oshi,
              members: s.members,
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
  const OshiUpcomingLivesSection({
    super.key,
    required this.oshi,
    this.members = const [],
  });

  final OshiSummary oshi;

  /// この区画にまとめたメンバー（グループの区画のとき。Ff-9）
  final List<OshiSummary> members;

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
      (
        targets: FollowTargets.fromFollowing([widget.oshi, ...widget.members]),
        query: '',
      );

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
              if (canFetchLives(oshi))
                TextButton.icon(
                  key: Key('oshi_upcoming_fetch_${oshi.key}'),
                  onPressed: () => showLiveFetchDialog(context, oshi),
                  icon: const Icon(Icons.travel_explore, size: 18),
                  label: const Text('公式サイトから探す'),
                ),
            ],
          ),
        ),
        // まとめたメンバー（Ff-9）
        if (widget.members.isNotEmpty)
          Padding(
            key: Key('oshi_upcoming_members_${oshi.key}'),
            padding: const EdgeInsets.only(left: 36, bottom: 4),
            child: Text(_membersLine(widget.members), style: muted),
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
    // 同じライブは1件にまとめる（Ff-10）
    final merged = mergeSameLives(upcoming, names);
    final shown = _showAll ? merged : merged.take(_initialCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++)
          LiveTimelineItem(
            entry: shown[i].entry,
            performers: shown[i].performers,
            isFirst: i == 0,
            isLast: i == shown.length - 1,
            trailing: _trailing(shown[i], added),
          ),
        if (!_showAll && merged.length > _initialCount)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: Key('oshi_upcoming_show_all_${widget.oshi.key}'),
              onPressed: () => setState(() => _showAll = true),
              child: Text('すべて見る（${merged.length}件）'),
            ),
          ),
      ],
    );
  }

  /// 右端：まとめたどれかが自分の一覧にあれば「追加済」（押せない）、なければ「追加する！」
  /// （代表の1件を入れる。Ff-10）
  Widget _trailing(MergedLive m, Set<String> added) {
    final liveId = m.entry.live.id!;
    if (m.containsAny(added)) {
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
