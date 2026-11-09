import '../../theme/brand_colors.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/live.dart';
import '../../models/oshi.dart';
import '../../models/performance.dart';
import '../../models/trade_post.dart';
import '../../providers/live_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../providers/trade_post_providers.dart';
import '../live/official_url_link.dart';
import '../live_form/date_time_field.dart';
import '../common/photo_grid.dart';
import '../common/user_avatar.dart';
import 'trade_post_summary.dart';
import 'trade_replies_section.dart';

/// X のユーザー名のページ。ユーザー名として正しくなければ null（リンクにしない）
Uri? xProfileUri(String? account) {
  if (account == null || !RegExp(r'^[A-Za-z0-9_]{1,15}$').hasMatch(account)) {
    return null;
  }
  return Uri.https('x.com', '/$account');
}

/// 投稿の詳細（内容、X へのリンク、返信）
class TradePostDetailPage extends ConsumerWidget {
  const TradePostDetailPage({
    super.key,
    required this.postId,
    this.initialAttachId,
  });

  final String postId;

  /// 返信に最初から添付しておく自分の投稿（マッチから開いたとき）
  final String? initialAttachId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(tradePostByIdProvider(postId));
    final uid = ref.watch(currentUidProvider);
    final p = post.value;
    final isMine = p != null && p.uid == uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('投稿の詳細'),
        actions: [
          if (isMine && p.status != TradePostStatus.hidden)
            IconButton(
              key: const Key('trade_detail_edit'),
              tooltip: '編集',
              icon: const Icon(Icons.edit),
              onPressed: () => context.push('/trade/$postId/edit'),
            ),
        ],
      ),
      body: SafeArea(
        child: post.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _message(
            e is FirebaseException && e.code == 'permission-denied'
                ? 'この投稿は表示できません（運営により非表示にされた可能性があります）'
                : '投稿を読み込めませんでした: $e',
          ),
          data: (p) => p == null
              ? _message('投稿が見つかりません')
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(tradePostByIdProvider(postId).future),
                  child: _PostBody(
                    post: p,
                    isMine: isMine,
                    initialAttachId: initialAttachId,
                  ),
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

/// 投稿の詳細（内容、X へのリンク、返信）
class _PostBody extends ConsumerWidget {
  const _PostBody({
    required this.post,
    required this.isMine,
    this.initialAttachId,
  });

  final TradePost post;
  final bool isMine;
  final String? initialAttachId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final all = ref.watch(allOshisProvider).value ?? const <OshiSummary>[];
    final targets = targetNames(post, all);
    final updatedAt = post.updatedAt;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(text, style: theme.textTheme.titleMedium),
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (post.status != TradePostStatus.open)
          Container(
            key: const Key('trade_detail_status_banner'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BrandColors.tonal,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BrandColors.ink, width: 1.5),
            ),
            child: Text(
              post.status == TradePostStatus.hidden
                  ? 'この投稿は運営により非表示にされています'
                  : 'この投稿は募集終了です',
              style: const TextStyle(color: BrandColors.ink),
            ),
          ),
        Row(
          children: [
            UserAvatar(uid: post.uid, name: post.displayName),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                post.displayName,
                style: theme.textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isMine) ...[
              const SizedBox(width: 8),
              const Chip(
                label: Text('自分'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
        if (targets.isNotEmpty) Text('対象：$targets'),
        Text(tagLine(post)),
        Text(
          updatedAt == null ? '保存中…' : '更新：${formatDateTime(updatedAt)}',
          style: theme.textTheme.bodySmall,
        ),
        if (post.isTextOnly) ...[
          const SizedBox(height: 8),
          const Text('品目なし（自動のマッチングの対象外）'),
        ],
        // 投稿全体の写真（G-7 仕様書 6.3）
        if (post.images.isNotEmpty) ...[
          heading('写真'),
          PhotoGrid(key: const Key('trade_detail_photos'), paths: post.images),
        ],
        if (post.gives.isNotEmpty) ...[
          heading('譲（出せるもの）'),
          for (final (i, s) in post.gives.indexed)
            _SetCard(
              key: Key('trade_detail_give_$i'),
              title: '譲セット${i + 1}',
              pickCount: s.pickCount,
              labels: [for (final it in s.items) it.label],
              note: s.note,
              images: s.images,
            ),
        ],
        if (post.wants.isNotEmpty) ...[
          heading('求（欲しいもの）'),
          for (final (i, s) in post.wants.indexed)
            _SetCard(
              key: Key('trade_detail_want_$i'),
              title: '求セット${i + 1}',
              pickCount: s.pickCount,
              labels: [
                for (final t in s.targets)
                  t.type == WantType.member ? '${t.label}（メンバー指定）' : t.label,
              ],
              note: s.note,
            ),
        ],
        heading('受け渡し'),
        Text(post.handover.map((h) => h.label).join('・')),
        if (post.handover.contains(HandoverMethod.hand) &&
            post.performanceIds.isNotEmpty)
          _Performances(ids: post.performanceIds),
        heading('連絡先'),
        _XLink(account: post.xAccount),
        if (post.note case final note?) ...[
          heading('備考'),
          SelectableText(note, key: const Key('trade_detail_note')),
        ],
        heading('返信'),
        TradeRepliesSection(post: post, initialAttachId: initialAttachId),
      ],
    );
  }
}

/// セット1つ（「この中から N 個」、品目、写真、備考）
class _SetCard extends StatelessWidget {
  const _SetCard({
    super.key,
    required this.title,
    required this.pickCount,
    required this.labels,
    required this.note,
    this.images = const [],
  });

  final String title;
  final int? pickCount;
  final List<String> labels;
  final String? note;

  /// セットの写真（譲セットだけ。G-7）
  final List<String> images;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pickCount == null ? title : '$title（この中から$pickCount個）',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final l in labels) Text('・$l'),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 8),
              PhotoGrid(paths: images, maxWidth: 360),
            ],
            if (note case final n?) ...[
              const SizedBox(height: 4),
              Text('備考：$n', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// 手渡しの公演（自分のライブ一覧の公演から名前を引く。Step4.5 で差し替え）
class _Performances extends ConsumerWidget {
  const _Performances({required this.ids});

  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performances =
        ref.watch(myPerformancesProvider).value ?? const <Performance>[];
    final lives = ref.watch(myLivesProvider).value ?? const <Live>[];
    final byId = {for (final p in performances) p.id: p};
    final titles = {for (final l in lives) l.id: l.title};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        const Text('手渡しできる公演：'),
        for (final id in ids)
          if (byId[id] case final p?)
            Text(
              '・${titles[p.liveId] ?? '（ライブ名不明）'} '
              '${formatDateTime(p.startAt)} ${p.venue}',
            )
          else
            const Text('・（公演の情報を表示できません）'),
      ],
    );
  }
}

/// X アカウントへのリンク（新しいタブで開く）
class _XLink extends ConsumerStatefulWidget {
  const _XLink({required this.account});

  final String? account;

  @override
  ConsumerState<_XLink> createState() => _XLinkState();
}

class _XLinkState extends ConsumerState<_XLink> {
  /// 開く処理の途中（連打でタブが複数開かないようにする）
  bool _opening = false;

  Future<void> _open(Uri uri) async {
    if (_opening) return;
    _opening = true;
    var opened = false;
    try {
      opened = await ref.read(urlLauncherProvider)(uri);
    } catch (e) {
      debugPrint('X を開けませんでした: $e');
    } finally {
      _opening = false;
    }
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('X を開けませんでした')));
  }

  @override
  Widget build(BuildContext context) {
    final uri = xProfileUri(widget.account);
    if (uri == null) {
      return const Text(
        'X アカウントは登録されていません。返信で連絡できます',
        key: Key('trade_detail_no_x'),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('trade_detail_x'),
        onPressed: () => _open(uri),
        icon: const Icon(Icons.open_in_new),
        label: Text('X：@${widget.account}'),
      ),
    );
  }
}
