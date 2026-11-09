import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/live_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/deadline.dart';
import '../calendar/calendar_add_sheet.dart';
import '../live/live_list_entries.dart' show PerformerNames;
import 'home_section_header.dart';

/// 「今日」「昨日」「◯日前」（端末の日付で数える）
String _ago(DateTime at, DateTime now) {
  final a = at.toLocal();
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(a.year, a.month, a.day))
      .inDays;
  if (days <= 0) return '今日';
  if (days == 1) return '昨日';
  return '$days日前';
}

/// 推しの新しいライブ（Ff 5.3）：フォロー中の推しに最近登録された、
/// まだ自分のライブ一覧に無いライブ。「参戦する」でその場で追加できる。
/// 1件も無ければ何も出さない
class HomeNewOshiLives extends ConsumerStatefulWidget {
  const HomeNewOshiLives({super.key});

  @override
  ConsumerState<HomeNewOshiLives> createState() => _HomeNewOshiLivesState();
}

class _HomeNewOshiLivesState extends ConsumerState<HomeNewOshiLives> {
  /// 追加の処理中のライブ ID
  final Set<String> _busy = {};

  /// 自分のライブ一覧に追加する（推しの今後のライブの追加と同じ。続けてカレンダーにも入れられる）
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
    if (added) await addLiveToCalendar(context, ref, liveId);
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(newOshiLivesProvider).value ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    final all = ref.watch(allOshisProvider).value;
    final names = all == null ? null : PerformerNames(all);
    final now = ref.watch(nowProvider);

    return Column(
      key: const Key('home_new_oshi_lives'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: '推しの新しいライブ',
          onSeeAll: () => context.go('/lives'),
        ),
        const HakoHint('フォロー中の推しに、新しく登録されたライブです。'),
        for (final e in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _NewLiveCard(
              entry: e,
              performers: names?.of(e.live) ?? const [],
              now: now,
              busy: _busy.contains(e.live.id),
              onAdd: () => _add(e.live.id!),
            ),
          ),
      ],
    );
  }
}

/// 1件のカード：日付の札・札（自動登録／新しく登録）と◯日前・ライブ名・出演者・時刻と会場・「参戦する」
class _NewLiveCard extends StatelessWidget {
  const _NewLiveCard({
    required this.entry,
    required this.performers,
    required this.now,
    required this.busy,
    required this.onAdd,
  });

  final LiveListEntry entry;
  final List<String> performers;
  final DateTime now;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final live = entry.live;
    final next = entry.nextStartAt!;
    final perf = entry.nextPerformance;
    final time = perf?.startTimeUnknown == true
        ? '時間未定'
        : '${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}';
    final venue = perf?.venue ?? '';
    final sub = HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.5);

    return InkWell(
      key: Key('home_new_oshi_live_${live.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/lives/${live.id}'),
      child: HakoBox(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HakoDateBadge(date: next),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      HakoTagChip(live.isAi ? '公式サイトから自動登録' : '新しく登録'),
                      if (live.createdAt case final at?)
                        Text(_ago(at, now), style: sub),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    live.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HakoFonts.jp(
                      size: 15,
                      weight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                  if (performers.isNotEmpty)
                    Text(
                      performers.join('、'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sub,
                    ),
                  Text(
                    venue.isEmpty ? time : '$time ・ $venue',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: sub,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: Key('home_new_oshi_live_add_${live.id}'),
              onPressed: busy ? null : onAdd,
              child: Text(busy ? '追加中…' : '参戦する'),
            ),
          ],
        ),
      ),
    );
  }
}