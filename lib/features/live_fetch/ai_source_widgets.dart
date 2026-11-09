import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import '../../models/live.dart';
import '../live/official_url_link.dart' show urlLauncherProvider;

/// 「Google で検索」のチップ（add_L 5.2）。
/// 押すと、その語の Google 検索を外部のブラウザで開く。語が無ければ何も出さない
class GoogleSearchChips extends ConsumerWidget {
  const GoogleSearchChips({super.key, required this.queries});

  final List<String> queries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (queries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Google で検索',
          style: HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.5),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final q in queries)
              ActionChip(
                avatar: const Icon(Icons.search, size: 16),
                label: Text(q),
                onPressed: () => ref.read(urlLauncherProvider)(
                  Uri.https('www.google.com', '/search', {'q': q}),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// AI が登録したことを示す小さな札（add_L 5.3）。公演・受付の行では「AI」
class AiSourceBadge extends StatelessWidget {
  const AiSourceBadge({super.key, this.label = 'AI'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: BrandColors.sub),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 14, color: BrandColors.ink),
          const SizedBox(width: 4),
          Text(
            label,
            style: HakoFonts.jp(size: 11, weight: FontWeight.w700, height: 1.3),
          ),
        ],
      ),
    );
  }
}

/// 出典として開いてよい URL か（http・https で、ホストがあり、userinfo が無い）
Uri? _sourceUri(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
  return uri.scheme == 'https' || uri.scheme == 'http' ? uri : null;
}

/// ライブ詳細の「AI が公式サイトから登録」（add_L 5.3）。
/// 札 → 出典（1つ目の URL のドメイン）→ Google で検索 → 注意書き
class AiSourceSection extends ConsumerWidget {
  const AiSourceSection({super.key, required this.live});

  final Live live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.5);
    final color = Theme.of(context).colorScheme.primary;
    final source = live.sourceUrls.map(_sourceUri).nonNulls.firstOrNull;

    return Column(
      key: const Key('live_detail_ai_source'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AiSourceBadge(label: 'AI が公式サイトから登録'),
        if (source != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              key: const Key('live_detail_ai_source_link'),
              onTap: () => ref.read(urlLauncherProvider)(source),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('出典：', style: muted),
                  Icon(Icons.open_in_new, size: 14, color: color),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      source.host,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        decoration: TextDecoration.underline,
                        decorationColor: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (live.searchQueries.isNotEmpty) ...[
          const SizedBox(height: 6),
          GoogleSearchChips(queries: live.searchQueries),
        ],
        const SizedBox(height: 4),
        Text('内容が違うときは編集で直せます。正しい情報は公式サイトでご確認ください', style: muted),
      ],
    );
  }
}