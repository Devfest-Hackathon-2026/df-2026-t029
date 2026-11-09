import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/live_memory.dart';
import '../../providers/live_providers.dart';
import '../../providers/memory_providers.dart';
import '../../providers/memory_ticket_providers.dart';
import '../../providers/photo_pick_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../../providers/oshi_providers.dart';
import '../../utils/memory_ticket.dart';
import '../../utils/youtube_search.dart';
import '../live/official_url_link.dart' show urlLauncherProvider;
import '../photos/photos_sheet.dart';
import 'ticket/inline_editor.dart';
import 'ticket/memory_progress.dart';
import 'ticket/ticket_card.dart';
import 'ticket/ticket_widgets.dart';

/// 記録の画面（/memories/:performanceId）。チケット風で、座席・セトリ・感想・写真を
/// タップしてその場で直せる（計画書 4.2）。作成・削除・公開の設定はフォーム（編集）で行う
class MemoryDetailPage extends ConsumerWidget {
  const MemoryDetailPage({super.key, required this.performanceId});

  final String performanceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = ref.watch(memoryProvider(performanceId));
    final now = ref.watch(nowProvider);
    final m = memory.value;
    final attended = m != null && m.isAttended(now);
    return HakoPageScaffold(
      title: '記録',
      showBack: true,
      backFallback: '/memories',
      // 参戦済みの記録だけ、下に「まとめて編集して投稿」を固定する
      bottomBar: attended
          ? HakoSaveBar(
              child: TicketButton(
                key: const Key('memory_share_button'),
                label: 'まとめて編集して投稿',
                icon: Icons.ios_share,
                kind: TicketButtonKind.dark,
                wide: true,
                onPressed: () => context.push('/memories/$performanceId/share'),
              ),
            )
          : null,
      body: SafeArea(
        child: switch (memory) {
          AsyncError() => const HakoEmpty(
            '記録を読み込めませんでした',
            key: Key('memory_detail_error'),
          ),
          AsyncData(value: final m?) => _DetailView(
            memory: m,
            attended: attended,
            onEdit: () => context.go('/memories/$performanceId/edit'),
          ),
          AsyncData() => const HakoEmpty(
            'この記録は見つかりませんでした',
            key: Key('memory_detail_not_found'),
          ),
          _ => const Center(
            key: Key('memory_detail_loading'),
            child: CircularProgressIndicator(),
          ),
        },
      ),
    );
  }
}

class _DetailView extends ConsumerStatefulWidget {
  const _DetailView({
    required this.memory,
    required this.attended,
    required this.onEdit,
  });

  final LiveMemory memory;
  final bool attended;
  final VoidCallback onEdit;

  @override
  ConsumerState<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends ConsumerState<_DetailView> {
  /// 開いている編集カード（同時に1つだけ）
  TicketField? _editing;

  void _toggle(TicketField field) {
    // 別の枠を押すと、開いているものは閉じる（入力中の文字は捨てる）
    setState(() => _editing = _editing == field ? null : field);
  }

  /// 決定。成功したらカードを閉じる
  Future<bool> _save(TicketField field, String text) async {
    final m = widget.memory;
    final messenger = ScaffoldMessenger.of(context);
    final trimmed = text.trim();
    try {
      final result = await ref
          .read(memoryEditorProvider)
          .saveFields(
            m,
            seat: field == TicketField.seat
                ? (trimmed.isEmpty ? null : trimmed)
                : m.seat,
            setlist: field == TicketField.setlist
                ? [
                    for (final line in text.split('\n'))
                      if (line.trim().isNotEmpty) line.trim(),
                  ]
                : m.setlist,
            impression: field == TicketField.impression
                ? (trimmed.isEmpty ? null : trimmed)
                : m.impression,
          );
      if (!result.publicSynced) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('記録は保存しましたが、公開できませんでした。もう一度保存してください')),
          );
      }
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('保存できませんでした。もう一度お試しください')));
      return false;
    }
    if (mounted) setState(() => _editing = null);
    return true;
  }

  /// 公開の切り替え中（二重に押せなくする）
  bool _publishing = false;

  /// 公開・座席の公開を保存し、公開の写しを書き換える（add_K 5.1）
  Future<void> _setPublic({
    required bool isPublic,
    required bool publicSeat,
  }) async {
    if (_publishing) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _publishing = true);
    try {
      final result = await ref
          .read(memoryEditorProvider)
          .setPublic(widget.memory, isPublic: isPublic, publicSeat: publicSeat);
      if (!result.publicSynced) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('記録は保存しましたが、公開できませんでした。もう一度保存してください')),
          );
      }
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('保存できませんでした。もう一度お試しください')));
    }
    if (mounted) setState(() => _publishing = false);
  }

  void _openPhotos() {
    // 開いている編集カードは閉じる（入力中の文字は捨てる）
    if (_editing != null) setState(() => _editing = null);
    showPhotosSheet(context, memory: widget.memory);
  }

  Widget _editor(TicketField field, LiveMemory m) {
    final initial = switch (field) {
      TicketField.seat => m.seat ?? '',
      TicketField.setlist => m.setlist.join('\n'),
      TicketField.impression => m.impression ?? '',
    };
    return InlineEditorCard(
      // 項目ごとに作り直す（入力中の文字を持ち越さない）
      key: ValueKey('inline_${field.name}'),
      field: field,
      initialText: initial,
      onSave: (text) => _save(field, text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.memory;
    // セトリの曲の YouTube 検索に使う推しの名前（add_P 5.4）
    final artist = performerNameOf(
      ref.watch(liveProvider(m.liveId)).value,
      ref.watch(allOshisProvider).value ?? const [],
    );
    // つないだか（このタブで同意した）。写真が0枚のときのボタンの文言だけに使う
    final connected = ref.watch(googlePhotosConsentedProvider);
    final impression = m.impression;
    final infoStyle = HakoFonts.jp(
      size: 12.5,
      color: BrandColors.sub,
      height: 1.65,
    );

    return ListView(
      key: const Key('memory_detail'),
      padding: HakoPageScaffold.padding(context).copyWith(bottom: 32),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            key: const Key('memory_detail_edit_button'),
            onPressed: widget.onEdit,
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44)),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('編集'),
          ),
        ),
        const SizedBox(height: 8),
        MemoryTicketCard(
          memory: m,
          attended: widget.attended,
          photosConnected: connected,
          onEditPhotos: _openPhotos,
          onEditSeat: () => _toggle(TicketField.seat),
          seatEditing: _editing == TicketField.seat,
        ),
        if (_editing == TicketField.seat) ...[
          const SizedBox(height: 12),
          _editor(TicketField.seat, m),
        ],
        const SizedBox(height: 18),
        TicketBlankFrame(
          key: const Key('memory_ticket_setlist'),
          title: 'セトリ',
          hint: '公演のあとに、覚えている曲から書けます',
          filled: m.setlist.isNotEmpty,
          onTap: () => _toggle(TicketField.setlist),
          body: Column(
            key: const Key('memory_detail_setlist'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, song) in m.setlist.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${i + 1}. $song',
                          style: HakoFonts.jp(size: 14, height: 1.7),
                        ),
                      ),
                      // 曲を YouTube で探す（add_P 5.4）。枠を押したときの編集とは別
                      IconButton(
                        key: Key('memory_setlist_youtube_$i'),
                        tooltip: 'YouTube で探す',
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        onPressed: () => ref.read(urlLauncherProvider)(
                          youtubeSearchUri(song, artist: artist),
                        ),
                        icon: const Icon(Icons.smart_display_outlined),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_editing == TicketField.setlist) ...[
          const SizedBox(height: 12),
          _editor(TicketField.setlist, m),
        ],
        const SizedBox(height: 12),
        TicketBlankFrame(
          key: const Key('memory_ticket_impression'),
          title: '感想',
          hint: '心に残ったことを、自由に書いてください',
          filled: impression != null && impression.trim().isNotEmpty,
          onTap: () => _toggle(TicketField.impression),
          body: Text(
            impression ?? '',
            key: const Key('memory_detail_impression'),
            style: HakoFonts.jp(size: 14, height: 1.7),
          ),
        ),
        if (_editing == TicketField.impression) ...[
          const SizedBox(height: 12),
          _editor(TicketField.impression, m),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ExcludeSemantics(
              child: Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.info_outline, size: 16),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '座席は、この記録だけに表示されます。SNSの画像と文章には出ません。',
                key: const Key('memory_ticket_seat_info'),
                style: infoStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        MemoryProgressBar(
          key: const Key('memory_progress'),
          done: memoryProgress(m),
        ),
        // 公開の設定（文言は編集フォームと同じ）
        const HakoSectionHeader('公開'),
        SwitchListTile(
          key: const Key('memory_publish_switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('同じ推しのファンに公開する'),
          subtitle: Text(
            'フォロー中の推しが同じ人の「みんなのメモリー」に出ます',
            style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.5),
          ),
          value: m.isPublic,
          onChanged: _publishing
              ? null
              : (v) => _setPublic(isPublic: v, publicSeat: m.publicSeat),
        ),
        SwitchListTile(
          key: const Key('memory_publish_seat_switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('座席も公開する'),
          value: m.isPublic && m.publicSeat,
          onChanged: _publishing || !m.isPublic
              ? null
              : (v) => _setPublic(isPublic: true, publicSeat: v),
        ),
      ],
    );
  }
}
