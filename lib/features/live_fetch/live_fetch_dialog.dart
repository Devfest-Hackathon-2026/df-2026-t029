import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/oshi.dart';
import '../../providers/live_fetch_providers.dart';
import '../../repositories/live_fetch_repository.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../live/official_url_link.dart';
import 'ai_source_widgets.dart';

/// 公式サイトからライブを探せる推しか（add_L 5.1・L-4d）：
/// 承認済みで、デモ用（demo-）でなく、グループに入っている個人でない
bool canFetchLives(OshiSummary oshi) =>
    oshi.isApproved &&
    !oshi.id.startsWith('demo-') &&
    !(oshi.kind == OshiKind.person && oshi.groupIds.isNotEmpty);

/// 「公式サイトからライブを探す」（add_L 5.1）。取得中は閉じられない
Future<void> showLiveFetchDialog(BuildContext context, OshiSummary oshi) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LiveFetchDialog(oshi: oshi),
    );

class LiveFetchDialog extends ConsumerStatefulWidget {
  const LiveFetchDialog({super.key, required this.oshi});

  final OshiSummary oshi;

  @override
  ConsumerState<LiveFetchDialog> createState() => _LiveFetchDialogState();
}

class _LiveFetchDialogState extends ConsumerState<LiveFetchDialog> {
  late final Future<LiveFetchResult> _future = ref
      .read(liveFetchRepositoryProvider)
      .fetch(widget.oshi.kind, widget.oshi.id);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LiveFetchResult>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _loading();
        }
        if (snap.hasError) return _done(_errorMessage(snap.error), null);
        return _done(null, snap.requireData);
      },
    );
  }

  Widget _loading() => AlertDialog(
    key: const Key('live_fetch_loading'),
    title: const Text('公式サイトからライブを探しています'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          '${widget.oshi.name}の公式サイトを Gemini が調べています。1分ほどかかります',
          textAlign: TextAlign.center,
          style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.5),
        ),
      ],
    ),
  );

  String _errorMessage(Object? error) =>
      error is FirebaseFunctionsException && error.code == 'resource-exhausted'
      ? '少し時間をおいてからもう一度お試しください'
      : '取得できませんでした';

  /// 結果の文（add_L 5.2）
  String _messageOf(LiveFetchResult r) => switch (r.status) {
    LiveFetchStatus.ok || LiveFetchStatus.unchanged when r.hasAdded =>
      'ライブ ${r.addedLives}件・公演 ${r.addedPerformances}件・'
          '受付 ${r.addedReceptions}件を登録しました',
    LiveFetchStatus.ok || LiveFetchStatus.unchanged => '新しいライブは見つかりませんでした',
    LiveFetchStatus.noOfficialSite => '公式サイトが見つかりませんでした',
    LiveFetchStatus.blocked => 'この公式サイトは自動での取得が許可されていないため、取得しませんでした',
    LiveFetchStatus.skipped => 'この推しは対象外です',
  };

  Widget _done(String? error, LiveFetchResult? r) {
    final router = GoRouter.of(context);
    final officialUrl = r?.officialUrl;
    return AlertDialog(
      key: const Key('live_fetch_result'),
      title: Text('${widget.oshi.name}のライブ情報'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error ?? _messageOf(r!),
              style: HakoFonts.jp(size: 14, height: 1.5),
            ),
            if (r != null && r.lives.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final l in r.lives)
                ListTile(
                  key: Key('live_fetch_live_${l.id}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.title),
                  trailing: HakoTagChip(l.isNew ? '新規' : '公演・受付を追加'),
                  onTap: () {
                    Navigator.of(context).pop();
                    router.push('/lives/${l.id}');
                  },
                ),
            ],
            if (officialUrl != null && officialUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '公式サイト',
                style: HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.5),
              ),
              OfficialUrlLink(url: officialUrl),
            ],
            if (r != null && r.searchQueries.isNotEmpty) ...[
              const SizedBox(height: 12),
              GoogleSearchChips(queries: r.searchQueries),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('live_fetch_close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}