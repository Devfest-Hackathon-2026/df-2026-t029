import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
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