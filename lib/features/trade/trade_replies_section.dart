import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/trade_post.dart';
import '../../models/trade_reply.dart';
import '../../providers/oshi_providers.dart';
import '../../providers/trade_post_providers.dart';
import '../../repositories/trade_chat_repository.dart';
import '../live_form/date_time_field.dart';
import 'trade_post_summary.dart';

/// 投稿の返信の一覧と入力欄（詳細画面の下に置く）。
///
/// 返信は書いた順に一列で並べる（スレッドにはしない）。募集中の投稿には
/// ログイン済みなら誰でも書ける。投稿者以外は、自分の募集中の投稿を1つ添付できる
class TradeRepliesSection extends ConsumerWidget {
  const TradeRepliesSection({
    super.key,
    required this.post,
    this.initialAttachId,
  });

  final TradePost post;

  /// 最初から添付に選んでおく自分の投稿（マッチから開いたとき）
  final String? initialAttachId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replies = ref.watch(tradeRepliesProvider(post.id!));
    final uid = ref.watch(currentUidProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        replies.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('返信を読み込めませんでした: $e'),
          data: (list) => list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('まだ返信はありません'),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in list)
                      _ReplyTile(
                        post: post,
                        reply: r,
                        isMine: r.uid == uid,
                        isPoster: post.uid == uid,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        if (post.status == TradePostStatus.open)
          _ReplyInput(
            post: post,
            isPoster: post.uid == uid,
            initialAttachId: initialAttachId,
          )
        else
          const Text('募集中ではないため、返信できません', key: Key('trade_reply_closed')),
      ],
    );
  }
}

/// 返信1件
class _ReplyTile extends ConsumerWidget {
  const _ReplyTile({
    required this.post,
    required this.reply,
    required this.isMine,
    required this.isPoster,
  });

  final TradePost post;
  final TradeReply reply;
  final bool isMine;

  /// 見ている人が投稿者か（承認できるのは投稿者だけ）
  final bool isPoster;

  String get postId => post.id!;

  /// 返信を承認し、返信した人とのチャットを作る。
  /// その人とのチャットがすでにあれば、承認しない（既存のチャットを使う）
  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この人と個人チャットを開きますか？'),
        content: const Text(
          '返信を承認すると、2人だけのチャットができ、この投稿の募集も終了します'
          '（自分の投稿のタブから再開できます）。承認は取り消せません',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('trade_reply_approve_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('承認する'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final repo = ref.read(tradeChatRepositoryProvider);
    final chatId = chatIdFor(postId, reply.uid);
    String message;
    try {
      if (await repo.exists(chatId)) {
        message = 'この人とのチャットはすでにあるので、それを開きます';
      } else {
        await repo.approveReply(post: post, reply: reply);
        message = '承認して、チャットを作りました（募集を終了しました）';
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('承認できませんでした: $e')));
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    await context.push('/chats/$chatId');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('返信を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('trade_reply_delete_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(tradeReplyRepositoryProvider).delete(postId, reply.id!);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('削除できませんでした: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final createdAt = reply.createdAt;
    return Card(
      key: Key('trade_reply_${reply.id}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    reply.displayName,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 6),
                  const Chip(
                    label: Text('自分'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                if (reply.approved) ...[
                  const SizedBox(width: 6),
                  const Chip(
                    label: Text('承認済み'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                const Spacer(),
                // 削除は書いた本人だけ、承認前に限る
                if (isMine && !reply.approved)
                  IconButton(
                    key: Key('trade_reply_delete_${reply.id}'),
                    tooltip: '削除',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, ref),
                  )
                else
                  const SizedBox(height: 48),
              ],
            ),
            SelectableText(reply.text),
            if (reply.linkedPostId case final id?) _LinkedPost(postId: id),
            // 承認済みなら、投稿者と返信した人にだけチャットへの入口を出す
            if (reply.approved && (isPoster || isMine))
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: OutlinedButton.icon(
                  key: Key('trade_reply_chat_${reply.id}'),
                  onPressed: () =>
                      context.push('/chats/${chatIdFor(postId, reply.uid)}'),
                  icon: const Icon(Icons.chat),
                  label: const Text('チャットを開く'),
                ),
              ),
            // 承認できるのは投稿者だけで、自分の返信は承認できない
            if (isPoster && !isMine && !reply.approved)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: FilledButton.tonalIcon(
                  key: Key('trade_reply_approve_${reply.id}'),
                  onPressed: () => _approve(context, ref),
                  icon: const Icon(Icons.chat),
                  label: const Text('承認してチャットを開く'),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              createdAt == null ? '送信中…' : formatDateTime(createdAt),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// 返信に添付された投稿（押すとその投稿の詳細を開く）
class _LinkedPost extends ConsumerWidget {
  const _LinkedPost({required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(tradePostByIdProvider(postId));
    final theme = Theme.of(context);
    final text = post.when(
      loading: () => '添付の投稿を読み込み中…',
      error: (_, _) => '添付の投稿は表示できません',
      data: (p) {
        if (p == null) return '添付の投稿は見つかりません';
        final gives = giveSummary(p);
        final wants = wantSummary(p);
        return [
          '添付の投稿',
          if (gives.isNotEmpty) '譲：$gives',
          if (wants.isNotEmpty) '求：$wants',
          if (p.status != TradePostStatus.open) '（${p.status.label}）',
        ].join('\n');
      },
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 8),
      child: OutlinedButton(
        key: Key('trade_reply_linked_$postId'),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(8),
        ),
        onPressed: post.value == null
            ? null
            : () => context.push('/trade/$postId'),
        child: Text(text, style: theme.textTheme.bodySmall),
      ),
    );
  }
}

/// 返信の入力欄（本文と、自分の投稿の添付）
class _ReplyInput extends ConsumerStatefulWidget {
  const _ReplyInput({
    required this.post,
    required this.isPoster,
    this.initialAttachId,
  });

  final TradePost post;

  /// 投稿者本人か（自分の投稿への添付は意味がないので、添付の欄を出さない）
  final bool isPoster;
  final String? initialAttachId;

  @override
  ConsumerState<_ReplyInput> createState() => _ReplyInputState();
}

class _ReplyInputState extends ConsumerState<_ReplyInput> {
  final _controller = TextEditingController();
  late String? _attachId = widget.isPoster ? null : widget.initialAttachId;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '本文を入力してください');
      return;
    }
    if (text.length > TradeReply.maxTextLength) {
      setState(() => _error = '本文は${TradeReply.maxTextLength}文字以内で入力してください');
      return;
    }
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(tradeReplyRepositoryProvider)
          .create(
            widget.post.id!,
            uid: uid,
            displayName: ref.read(myDisplayNameProvider),
            text: text,
            linkedPostId: _attachId,
          );
      if (!mounted) return;
      _controller.clear();
      setState(() => _attachId = null);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e is FirebaseException && e.code == 'permission-denied'
            ? '返信できませんでした。投稿の募集が終了した可能性があります'
            : '返信できませんでした: $e',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('trade_reply_text'),
          controller: _controller,
          decoration: InputDecoration(
            labelText: '返信を書く',
            hintText: widget.isPoster ? '例：B はもう決まりました' : '例：交換をお願いできますか？',
          ),
          minLines: 2,
          maxLines: 6,
          maxLength: TradeReply.maxTextLength,
        ),
        if (!widget.isPoster) _attachPicker(),
        if (_error case final e?)
          Text(e, style: TextStyle(color: theme.colorScheme.error)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const Key('trade_reply_send'),
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send),
            label: Text(_sending ? '送信中…' : '返信する'),
          ),
        ),
      ],
    );
  }

  /// 添付する自分の投稿（募集中のもの。返信先の投稿は除く）
  Widget _attachPicker() {
    final mine = ref.watch(myTradePostsProvider).value ?? const <TradePost>[];
    final candidates = [
      for (final p in mine)
        if (p.status == TradePostStatus.open && p.id != widget.post.id) p,
    ];
    if (candidates.isEmpty) {
      return const Text('添付できる自分の募集中の投稿はありません');
    }
    final ids = {for (final p in candidates) p.id};
    String label(TradePost p) {
      final gives = giveSummary(p);
      final wants = wantSummary(p);
      return [
        if (gives.isNotEmpty) '譲：$gives',
        if (wants.isNotEmpty) '求：$wants',
      ].join('／').ifEmpty('品目なしの投稿');
    }

    return DropdownButton<String?>(
      key: const Key('trade_reply_attach'),
      isExpanded: true,
      value: ids.contains(_attachId) ? _attachId : null,
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('自分の投稿を添付しない'),
        ),
        for (final p in candidates)
          DropdownMenuItem<String?>(
            value: p.id,
            child: Text('添付：${label(p)}', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (id) => setState(() => _attachId = id),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
