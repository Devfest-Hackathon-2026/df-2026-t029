import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/trade_chat.dart';
import '../../models/trade_message.dart';
import '../../models/trade_reply.dart';
import '../../providers/oshi_providers.dart';
import '../../providers/trade_post_providers.dart';
import '../live_form/date_time_field.dart';
import 'trade_post_summary.dart';

/// 個人チャット（承認した返信をきっかけにした1対1のやり取り）。
///
/// 先頭にきっかけの投稿と返信を出し、メッセージを古い順に並べる（リアルタイム）。
/// 開いたときと、新着を見たときに既読にする。取引終了なら送信できない
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  /// 既読の書き込みを送った、最後のメッセージの日時（同じものを何度も送らない）
  DateTime? _markedFor;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      tradeChatProvider(widget.chatId),
      (_, next) => _markReadIfNeeded(next.value),
      fireImmediately: true,
    );
  }

  /// 未読があれば既読にする（失敗しても画面は使えるので、知らせない）
  void _markReadIfNeeded(TradeChat? chat) {
    final uid = ref.read(currentUidProvider);
    if (chat == null || uid == null || !chat.isUnreadFor(uid)) return;
    if (_markedFor == chat.lastMessageAt) return;
    _markedFor = chat.lastMessageAt;
    ref
        .read(tradeChatRepositoryProvider)
        .markRead(widget.chatId, uid)
        .catchError((Object e) => debugPrint('既読にできませんでした: $e'));
  }

  Future<void> _setStatus(ChatStatus status) async {
    if (status == ChatStatus.closed) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('取引終了にしますか？'),
          content: const Text('メッセージを送れなくなります。どちらからでも再開できます'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('chat_close_confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('取引終了にする'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    try {
      await ref
          .read(tradeChatRepositoryProvider)
          .setStatus(widget.chatId, status);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('変更できませんでした: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(tradeChatProvider(widget.chatId));
    final uid = ref.watch(currentUidProvider) ?? '';
    final c = chat.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(c == null ? 'チャット' : c.otherName(uid)),
        actions: [
          if (c != null)
            PopupMenuButton<ChatStatus>(
              key: const Key('chat_menu'),
              tooltip: '操作',
              onSelected: _setStatus,
              itemBuilder: (context) => [
                if (c.status == ChatStatus.open)
                  const PopupMenuItem(
                    value: ChatStatus.closed,
                    child: Text('取引終了にする'),
                  )
                else
                  const PopupMenuItem(
                    value: ChatStatus.open,
                    child: Text('取引を再開する'),
                  ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: chat.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _message(
            e is FirebaseException && e.code == 'permission-denied'
                ? 'このチャットは表示できません'
                : 'チャットを読み込めませんでした: $e',
          ),
          data: (c) => c == null
              ? _message('チャットが見つかりません')
              : Column(
                  children: [
                    Expanded(
                      child: _Messages(chat: c, me: uid),
                    ),
                    const Divider(height: 1),
                    if (c.status == ChatStatus.open)
                      _MessageInput(chatId: c.id)
                    else
                      const Padding(
                        key: Key('chat_closed'),
                        padding: EdgeInsets.all(16),
                        child: Text('取引終了のため、メッセージを送れません。右上のメニューから再開できます'),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

/// メッセージの一覧（先頭にきっかけの投稿と返信）
class _Messages extends ConsumerWidget {
  const _Messages({required this.chat, required this.me});

  final TradeChat chat;
  final String me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(tradeMessagesProvider(chat.id));
    return messages.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('メッセージを読み込めませんでした: $e')),
      data: (list) {
        // reverse にして、新しいメッセージが下に来たときに下端に付いたままにする
        final reversed = list.reversed.toList();
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.all(12),
          itemCount: reversed.length + 1,
          itemBuilder: (context, i) {
            if (i == reversed.length) return _Origin(chat: chat);
            final m = reversed[i];
            return _Bubble(message: m, isMine: m.uid == me);
          },
        );
      },
    );
  }
}

/// きっかけの投稿と、承認した返信
class _Origin extends ConsumerWidget {
  const _Origin({required this.chat});

  final TradeChat chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final post = ref.watch(tradePostByIdProvider(chat.postId)).value;
    final replies =
        ref.watch(tradeRepliesProvider(chat.postId)).value ??
        const <TradeReply>[];
    final reply = replies.where((r) => r.id == chat.replyId).firstOrNull;
    final gives = post == null ? '' : giveSummary(post);
    final wants = post == null ? '' : wantSummary(post);

    return Card(
      key: const Key('chat_origin'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('きっかけの投稿', style: theme.textTheme.titleSmall),
            if (post == null)
              Text(chat.postSummary ?? '（投稿を読み込めません）')
            else ...[
              if (gives.isNotEmpty) Text('譲：$gives'),
              if (wants.isNotEmpty) Text('求：$wants'),
              if (gives.isEmpty && wants.isEmpty) const Text('品目なしの投稿'),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('chat_origin_post'),
                onPressed: () => context.push('/trade/${chat.postId}'),
                child: const Text('投稿の詳細を見る'),
              ),
            ),
            if (reply != null) ...[
              const Divider(),
              Text('承認した返信', style: theme.textTheme.titleSmall),
              Text(reply.text),
            ],
          ],
        ),
      ),
    );
  }
}

/// メッセージ1件（自分は右、相手は左）
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMine});

  final TradeMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final at = message.createdAt;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        child: Container(
          key: Key('chat_message_${message.id}'),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMine
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              SelectableText(message.text),
              Text(
                at == null ? '送信中…' : formatDateTime(at),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// メッセージの入力欄
class _MessageInput extends ConsumerStatefulWidget {
  const _MessageInput({required this.chatId});

  final String chatId;

  @override
  ConsumerState<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<_MessageInput> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(tradeChatRepositoryProvider)
          .sendMessage(widget.chatId, uid: uid, text: text);
      if (!mounted) return;
      _controller.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('送信できませんでした: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('chat_input'),
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'メッセージを入力',
                counterText: '',
              ),
              minLines: 1,
              maxLines: 4,
              maxLength: TradeMessage.maxTextLength,
            ),
          ),
          IconButton(
            key: const Key('chat_send'),
            tooltip: '送信',
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
