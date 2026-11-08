import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/trade_post_providers.dart';
import '../../utils/trade_match.dart';
import '../live_form/date_time_field.dart';
import '../common/user_avatar.dart';
import 'trade_post_summary.dart';
import 'trade_post_thumb.dart';

/// マッチ（交換トップの「マッチ」タブ）。
/// 相互マッチ → 片方マッチの順に、一致した品目を中心に出す。
/// 下に引っ張るか「更新」ボタンで読み直す（タブを開くたびには読み直さない）
class TradeMatchView extends ConsumerWidget {
  const TradeMatchView({super.key});

  /// 他の人の新しい投稿を拾うため、候補の検索からやり直す
  static Future<void> refresh(WidgetRef ref) async {
    ref.invalidate(matchCandidatesProvider);
    await ref.read(tradeMatchesProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(myOpenWantKeysProvider);
    final matches = ref.watch(tradeMatchesProvider);

    // 求を入れた募集中の投稿がなければ、探しようがないので案内を出す
    if (keys.value?.isEmpty ?? false) {
      return const _Message(
        key: Key('trade_match_no_wants'),
        text:
            '求（欲しいもの）の品目を選んだ募集中の投稿があると、'
            'その求に合う譲を出している投稿をここに表示します',
      );
    }

    return RefreshIndicator(
      onRefresh: () => refresh(ref),
      child: matches.when(
        // 読み直している間は、前の一覧を出したままにする（when の既定）
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _scrollable([
          _refreshRow(context, ref, loading: false),
          Text('マッチを読み込めませんでした: $e'),
        ]),
        data: (list) {
          final mutual = [
            for (final m in list)
              if (m.isMutual) m,
          ];
          final oneSided = [
            for (final m in list)
              if (!m.isMutual) m,
          ];
          return _scrollable([
            _refreshRow(context, ref, loading: matches.isLoading),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  key: Key('trade_match_empty'),
                  child: Text('今はマッチする投稿はありません'),
                ),
              ),
            if (mutual.isNotEmpty) ...[
              _heading(context, '相互マッチ（${mutual.length}件）'),
              for (final m in mutual) _MatchCard(match: m),
            ],
            if (oneSided.isNotEmpty) ...[
              _heading(context, '片方マッチ（${oneSided.length}件）'),
              for (final m in oneSided) _MatchCard(match: m),
            ],
          ]);
        },
      ),
    );
  }

  /// 引っ張って更新できるよう、中身が少なくてもスクロールできるようにする
  Widget _scrollable(List<Widget> children) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    // 右下のボタンで最後の投稿が隠れないようにする
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
    children: children,
  );

  Widget _refreshRow(
    BuildContext context,
    WidgetRef ref, {
    required bool loading,
  }) => Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      key: const Key('trade_match_refresh'),
      onPressed: loading ? null : () => refresh(ref),
      icon: const Icon(Icons.refresh),
      label: Text(loading ? '読み込み中…' : '更新'),
    ),
  );

  Widget _heading(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

/// マッチ1件（相手の投稿）。詳細画面は G-5-1 で作るため、まだタップできない
class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final TradeMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final theirs = match.theirs;
    final best = match.best;
    final updatedAt = theirs.updatedAt;
    final receive = summarizeLabels([for (final i in best.theyGive) i.label]);
    final give = summarizeLabels([for (final i in best.iGive) i.label]);

    return Card(
      key: Key('trade_match_${theirs.id}'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          // いちばん合う自分の投稿を、返信に添付しておく
          Uri(
            path: '/trade/${theirs.id}',
            queryParameters: {'attach': best.mine.id},
          ).toString(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          // 相手の投稿に写真があれば右に1枚目を出す（G-7）
          child: TradePostWithThumb(
            post: theirs,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UserAvatar(uid: theirs.uid, name: theirs.displayName),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        theirs.displayName,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(match.isMutual ? '相互' : '片方'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                Text(
                  receive.isEmpty
                      ? 'もらえるもの：あなたの求に合う品目があります'
                      : 'もらえるもの：$receive',
                ),
                if (match.isMutual)
                  Text(
                    give.isEmpty ? '出せるもの：相手の求に合う品目があります' : '出せるもの：$give',
                  ),
                if (match.pairs.length > 1)
                  Text('合うあなたの投稿：${match.pairs.length}件'),
                Text(tagLine(theirs)),
                Text('受け渡し：${theirs.handover.map((h) => h.label).join('・')}'),
                const SizedBox(height: 4),
                Text(
                  updatedAt == null
                      ? '保存中…'
                      : '更新：${formatDateTime(updatedAt)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}