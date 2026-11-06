import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'my_trade_posts_view.dart';
import 'trade_board_view.dart';

/// 交換トップのタブ
enum TradeTab {
  board('掲示板'),
  match('マッチ'),
  mine('自分の投稿');

  const TradeTab(this.label);

  final String label;

  /// ルートの `?tab=` の値から。知らない値なら掲示板
  static TradeTab fromQuery(String? value) =>
      TradeTab.values.asNameMap()[value] ?? TradeTab.board;
}

/// 交換トップ（掲示板／マッチ／自分の投稿を上のタブで切り替える）
class TradeTopPage extends StatelessWidget {
  const TradeTopPage({super.key, this.initialTab = TradeTab.board});

  final TradeTab initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: TradeTab.values.length,
      initialIndex: initialTab.index,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('グッズ交換'),
          bottom: TabBar(
            tabs: [
              for (final t in TradeTab.values)
                Tab(key: Key('trade_tab_${t.name}'), text: t.label),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('trade_new_button'),
          onPressed: () => context.push('/trade/new'),
          icon: const Icon(Icons.add),
          label: const Text('投稿を作る'),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [
              TradeBoardView(),
              _MatchPlaceholder(),
              MyTradePostsView(),
            ],
          ),
        ),
      ),
    );
  }
}

/// マッチのタブ（G-4 で作る）
class _MatchPlaceholder extends StatelessWidget {
  const _MatchPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'マッチは準備中です。\n自分の求と相手の譲が合う投稿を、ここに自動で表示する予定です',
          key: Key('trade_match_placeholder'),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
