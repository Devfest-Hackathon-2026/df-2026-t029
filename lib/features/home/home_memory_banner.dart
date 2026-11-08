import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/live_providers.dart';
import '../../providers/memory_providers.dart';
import '../../providers/memory_ticket_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/memory_ticket.dart';
import '../../utils/share_ticket.dart';
import '../memory/share/share_providers_ui.dart';
import '../memory/share/share_ticket_view.dart';
import '../memory/ticket/ticket_widgets.dart';

/// 「新しい記録」の performanceId。開演から 7 日以内で、投稿していない参戦済みの記録。
/// 読み込み中・エラー・無いときは null（ホームには何も出さない）
final recentMemoryIdProvider = Provider.autoDispose<String?>((ref) {
  final now = ref.watch(nowProvider);
  final memories = ref.watch(myMemoriesProvider).value;
  if (memories == null) return null;
  return recentUnpostedMemory(memories.values, now)?.performanceId;
});

/// ホームの「ライブお疲れさまでした！」カード（計画書 4.9。見本の `.banner`）。
/// 出すのは「新しい記録」があるときだけ。読み込み中・記録なし・エラーは何も出さない
class HomeMemoryBanner extends ConsumerWidget {
  const HomeMemoryBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(recentMemoryIdProvider);
    if (id == null) return const SizedBox.shrink();
    final content = ref.watch(shareContentProvider(id)).value;
    if (content == null) return const SizedBox.shrink();
    final images = ref.watch(memoryProvider(id)).value?.images ?? const [];
    final bytes =
        ref.watch(sharePhotoBytesProvider(sharePhotoBytesKey(images))).value ??
        const [];
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: BrandColors.ink, offset: Offset(4, 4)),
          ],
        ),
        child: Container(
          key: const Key('home_memory_banner'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BrandColors.ink, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFE7E0CB),
                  border: Border(
                    bottom: BorderSide(color: BrandColors.ink, width: 2),
                  ),
                ),
                child: Center(
                  child: SizedBox(
                    width: 190,
                    // 見本どおり、投稿先は Instagram の形で見せる
                    child: ShareTicketView(
                      content: content,
                      config: ShareConfig.defaults(ShareTarget.instagram),
                      target: ShareTarget.instagram,
                      photoBytes: bytes,
                      mini: true,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const ExcludeSemantics(
                          child: Icon(Icons.auto_awesome, size: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ライブお疲れさまでした！',
                            style: HakoFonts.jp(
                              size: 15,
                              weight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: content.title,
                            style: HakoFonts.jp(
                              size: 13,
                              weight: FontWeight.w700,
                              color: BrandColors.sub,
                              height: 1.65,
                            ),
                          ),
                          TextSpan(
                            text: 'の記録と、投稿用のチケットができています。そのままでも、まとめて直してからでも投稿できます。',
                            style: HakoFonts.jp(
                              size: 13,
                              color: BrandColors.sub,
                              height: 1.65,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TicketButton(
                            key: const Key('home_memory_banner_x'),
                            label: 'Xに投稿',
                            kind: TicketButtonKind.dark,
                            small: true,
                            wide: true,
                            onPressed: () =>
                                context.push('/memories/$id/share?target=x'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TicketButton(
                            key: const Key('home_memory_banner_ig'),
                            label: 'Instagram',
                            icon: Icons.photo_camera_outlined,
                            small: true,
                            wide: true,
                            onPressed: () =>
                                context.push('/memories/$id/share?target=ig'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    TicketLinkButton(
                      key: const Key('home_memory_banner_open'),
                      label: '記録を見る・セトリと感想を書く',
                      onPressed: () => context.push('/memories/$id'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
