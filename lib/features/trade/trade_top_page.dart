import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/trade_post_providers.dart';

import 'my_trade_posts_view.dart';
import 'trade_board_view.dart';
import 'trade_match_view.dart';

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
          actions: const [_ChatButton()],
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
            children: [TradeBoardView(), TradeMatchView(), MyTradePostsView()],
          ),
        ),
      ),
    );
  }
}

/// チャットの一覧へのボタン（未読があれば件数を出す）
class _ChatButton extends ConsumerWidget {
  const _ChatButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadChatCountProvider);
    return IconButton(
      key: const Key('trade_chats_button'),
      tooltip: 'チャット',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.chat),
      ),
      onPressed: () => context.push('/chats'),
    );
  }
}
