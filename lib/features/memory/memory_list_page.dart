import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/live_memory.dart';
import '../../providers/memory_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/memory_album.dart';
import '../live_form/date_time_field.dart';
import '../common/empty_state.dart';

import '../../providers/live_providers.dart';
import '../../utils/memory_ticket.dart';
import 'memory_album_card.dart';
import 'ticket/recent_memory_card.dart';
import 'shared_memories_view.dart';

/// メモリー一覧（/memories）。「自分のメモリー」と「みんなのメモリー」のタブ（add_K 6.1）。
/// 自分のメモリーは、参戦予定と参戦済み（アルバム）を並べる。
/// PC で本文の幅が広いときは、左に参戦予定・右に参戦済みの2列にする（Fc 5.2）
class MemoryListPage extends StatelessWidget {
  const MemoryListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return HakoPageScaffold(
      title: 'メモリー',
      maxContentWidth: 1080,
      body: SafeArea(
        // 選んだタブは覚えない（最初は「自分のメモリー」）
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                key: const Key('memory_tabs'),
                labelColor: BrandColors.ink,
                unselectedLabelColor: BrandColors.sub,
                indicatorColor: BrandColors.ink,
                labelStyle: HakoFonts.jp(
                  size: 14,
                  weight: FontWeight.w700,
                  height: 1.3,
                ),
                tabs: const [
                  Tab(key: Key('memory_tab_mine'), text: '自分のメモリー'),
                  Tab(key: Key('memory_tab_shared'), text: 'みんなのメモリー'),
                ],
              ),
              const Expanded(
                child: TabBarView(children: [_MineTab(), SharedMemoriesView()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「自分のメモリー」タブ（今までのメモリー一覧の中身）
class _MineTab extends ConsumerWidget {
  const _MineTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = ref.watch(memoryAlbumProvider);
    return switch (album) {
      AsyncError() => _Message(
        key: const Key('memory_list_error'),
        text: '記録を読み込めませんでした',
        action: OutlinedButton(
          key: const Key('memory_list_retry_button'),
          onPressed: () => ref.invalidate(myMemoriesProvider),
          child: const Text('もう一度読み込む'),
        ),
      ),
      AsyncData(value: MemoryAlbum(upcoming: [], attended: [])) =>
        const EmptyState(
          key: Key('memory_list_empty'),
          icon: Icons.photo_album_outlined,
          title: '参戦したライブを記録すると、ここに並びます',
          message: 'ライブの詳細の公演から「記録する」で残せます',
        ),
      AsyncData(:final value) => _AlbumView(
        album: value,
        now: ref.watch(nowProvider),
      ),
      _ => const Center(
        key: Key('memory_list_loading'),
        child: CircularProgressIndicator(),
      ),
    };
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: HakoFonts.jp(
                size: 13,
                color: BrandColors.sub,
                height: 1.6,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}

class _AlbumView extends StatelessWidget {
  const _AlbumView({required this.album, required this.now});

  final MemoryAlbum album;
  final DateTime now;

  /// この幅以上なら2列にする（Fc 5.2）
  static const double _twoColumnWidth = 900;

  @override
  Widget build(BuildContext context) {
    final pad = HakoPageScaffold.padding(context);
    Widget header(String text) => SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: pad.left),
      sliver: SliverToBoxAdapter(child: HakoSectionHeader(text)),
    );
    Widget none(String text) => SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: pad.left, vertical: 8),
      sliver: SliverToBoxAdapter(
        child: Text(
          text,
          style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.6),
        ),
      ),
    );
    Widget hint(String text, String key) => SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: pad.left),
      sliver: SliverToBoxAdapter(child: HakoHint(text, key: Key(key))),
    );
    final top = SliverPadding(
      padding: EdgeInsets.only(top: pad.top - 22 < 0 ? 0 : pad.top - 22),
    );

    // 参戦予定（行）
    final upcoming = <Widget>[
      header('参戦予定'),
      hint('これから行くライブです。座席も確認できます。', 'hint_memory_next'),
      if (album.upcoming.isEmpty)
        none('参戦予定の記録はありません')
      else
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: pad.left),
          sliver: SliverList.list(
            children: [
              for (final m in album.upcoming) _UpcomingTile(memory: m),
            ],
          ),
        ),
    ];

    // 新しい記録（開演から7日以内で、投稿していないもの）は、先頭に大きいカードで出す
    final recent = recentUnpostedMemory(album.attended, now);
    final rest = [
      for (final m in album.attended)
        if (m.performanceId != recent?.performanceId) m,
    ];

    // 参戦済み（カードのグリッド）
    final attended = <Widget>[
      header('参戦済み'),
      // 参戦済みが0件のときだけ、「記録する」で記録が作られることを伝える（計画書 4.0）
      hint(
        album.attended.isEmpty
            ? '参戦が終わったライブは、「記録する」を押すと、チケット風の記録が作られます。'
            : '行ったライブの思い出です。',
        'hint_memory_done',
      ),
      if (album.attended.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyState(
            key: Key('memory_list_attended_empty'),
            icon: Icons.photo_album_outlined,
            title: '参戦したライブを記録すると、ここに並びます',
          ),
        )
      else ...[
        if (recent != null)
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pad.left),
            sliver: SliverToBoxAdapter(
              child: RecentMemoryCard(
                key: const Key('memory_list_recent_card'),
                memory: recent,
                onTap: () => context.go('/memories/${recent.performanceId}'),
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad.left, 8, pad.right, pad.bottom),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 190,
              // 文字を大きくしても下にはみ出さないよう、文字の分だけ高さを伸ばす
              mainAxisExtent: 150 + MediaQuery.textScalerOf(context).scale(80),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: rest.length,
            itemBuilder: (context, i) {
              final m = rest[i];
              return MemoryAlbumCard(
                key: Key('memory_list_attended_${m.performanceId}'),
                memory: m,
                onTap: () => context.go('/memories/${m.performanceId}'),
              );
            },
          ),
        ),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _twoColumnWidth) {
          return CustomScrollView(
            key: const Key('memory_list'),
            slivers: [top, ...upcoming, ...attended],
          );
        }
        // 左（2/5）に参戦予定、右（3/5）に参戦済み。左右は別にスクロールする
        return Row(
          key: const Key('memory_list'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: CustomScrollView(
                key: const Key('memory_list_upcoming_column'),
                slivers: [
                  top,
                  ...upcoming,
                  SliverPadding(padding: EdgeInsets.only(bottom: pad.bottom)),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: CustomScrollView(
                key: const Key('memory_list_attended_column'),
                slivers: [top, ...attended],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 参戦予定の1行
class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.memory});

  final LiveMemory memory;

  @override
  Widget build(BuildContext context) {
    final seat = memory.seat;
    return HakoRow(
      key: Key('memory_list_upcoming_${memory.performanceId}'),
      icon: Icons.calendar_today_outlined,
      title: memory.liveTitle,
      subs: [
        '${formatDateTime(memory.startAt)} 開演',
        memory.venue,
        if (seat != null) '座席：$seat',
      ],
      onTap: () => context.go('/memories/${memory.performanceId}'),
    );
  }
}
