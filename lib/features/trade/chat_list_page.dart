import '../../theme/hako_app_widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/trade_chat.dart';
import '../../providers/oshi_providers.dart';
import '../../providers/trade_post_providers.dart';
import '../live_form/date_time_field.dart';
import '../common/user_avatar.dart';

/// チャットの一覧（最後のメッセージの新しい順）。押すとチャット画面を開く
class ChatListPage extends ConsumerWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(myChatsProvider);
    final uid = ref.watch(currentUidProvider) ?? '';
    return HakoPageScaffold(
      title: 'チャット',
      showBack: true,
      backFallback: '/trade',
      body: SafeArea(
        child: chats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('チャットを読み込めませんでした: $e')),
          data: (list) => list.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'まだチャットはありません。\n'
                      '投稿への返信が承認されると、ここにチャットができます',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _ChatTile(chat: list[i], me: uid),
                ),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.me});

  final TradeChat chat;
  final String me;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = chat.isUnreadFor(me);
    final at = chat.lastMessage == null ? chat.createdAt : chat.lastMessageAt;
    final summary = chat.postSummary;
    return ListTile(
      key: Key('chat_tile_${chat.id}'),
      onTap: () => context.push('/chats/${chat.id}'),
      leading: Badge(
        isLabelVisible: unread,
        smallSize: 10,
        child: UserAvatar(
          uid: chat.otherUid(me),
          name: chat.otherName(me),
          size: 36,
        ),
      ),
      title: Text(
        summary == null ? chat.otherName(me) : '${chat.otherName(me)}　$summary',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: unread ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      // スマホの幅でもはみ出さないよう、日時と状態は2行目に置く
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chat.lastMessage ?? 'まだメッセージはありません',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            [
              if (at != null) formatDateTime(at),
              if (chat.status == ChatStatus.closed) ChatStatus.closed.label,
            ].join('・'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
