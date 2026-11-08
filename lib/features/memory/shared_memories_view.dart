import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/oshi.dart';
import '../../models/public_memory.dart';
import '../../providers/oshi_providers.dart';
import '../../providers/public_memory_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../common/storage_image.dart';
import '../common/user_avatar.dart';

/// 公演の日付だけ（例：2026年11月8日）
String _dateOnly(DateTime d) {
  final t = d.toLocal();
  return '${t.year}年${t.month}月${t.day}日';
}

/// メモリーの画面の「みんなのメモリー」タブ（add_K 6.1）。
/// 推しを選び（最初は「フォロー中すべて」）、公開メモリーを新しい順に並べる
class SharedMemoriesView extends ConsumerStatefulWidget {
  const SharedMemoriesView({super.key});

  @override
  ConsumerState<SharedMemoriesView> createState() => _SharedMemoriesViewState();
}

class _SharedMemoriesViewState extends ConsumerState<SharedMemoriesView> {
  /// 選んだ推しのキー（OshiSummary.key）。null なら「フォロー中すべて」。覚えない
  String? _selectedKey;

  /// この幅以上なら2列にする（Fc 5.2 と同じ）
  static const double _twoColumnWidth = 900;

  @override
  Widget build(BuildContext context) {
    final following = ref.watch(followingOshisProvider);
    final pad = HakoPageScaffold.padding(context);
    final muted = HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.6);

    return switch (following) {
      AsyncError() => Center(
        key: const Key('shared_memories_following_error'),
        child: Text('フォロー中の推しを読み込めませんでした', style: muted),
      ),
      AsyncValue(value: final list?) when list.isEmpty => Center(
        key: const Key('shared_memories_no_following'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '推しをフォローすると、同じ推しのファンのメモリーが見られます',
                textAlign: TextAlign.center,
                style: muted,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('shared_memories_search_oshi'),
                onPressed: () => context.push('/oshi/search'),
                icon: const Icon(Icons.search),
                label: const Text('推しを探す'),
              ),
            ],
          ),
        ),
      ),
      AsyncValue(value: final list?) => _content(list, pad, muted),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _content(List<OshiSummary> oshis, EdgeInsets pad, TextStyle muted) {
    // 選んでいた推しのフォローを外したら「フォロー中すべて」に戻す（Fc-5x と同じ）
    final key = oshis.any((o) => o.key == _selectedKey) ? _selectedKey : null;
    final feed = ref.watch(sharedMemoriesFeedProvider(key));
    final uid = ref.watch(currentUidProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad.left, 12, pad.right, 8),
          child: _OshiDropdown(
            oshis: oshis,
            selectedKey: key,
            onChanged: (k) => setState(() => _selectedKey = k),
          ),
        ),
        Expanded(
          child: switch (feed) {
            AsyncError() => Center(
              key: const Key('shared_memories_error'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('メモリーを読み込めませんでした', style: muted),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(publicMemoriesForProvider),
                    child: const Text('もう一度読み込む'),
                  ),
                ],
              ),
            ),
            AsyncValue(value: final items?) when items.isEmpty => Center(
              key: const Key('shared_memories_empty'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'まだ公開されたメモリーはありません。\n'
                  '自分のメモリーの編集で「公開する」を選ぶと、ここに出ます',
                  textAlign: TextAlign.center,
                  style: muted,
                ),
              ),
            ),
            AsyncValue(value: final items?) => LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= _twoColumnWidth ? 2 : 1;
                final rows = <List<PublicMemory>>[
                  for (var i = 0; i < items.length; i += columns)
                    items.sublist(
                      i,
                      i + columns > items.length ? items.length : i + columns,
                    ),
                ];
                return ListView.builder(
                  key: const Key('shared_memories_list'),
                  padding: EdgeInsets.fromLTRB(
                    pad.left,
                    0,
                    pad.right,
                    pad.bottom,
                  ),
                  itemCount: rows.length,
                  itemBuilder: (context, r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var c = 0; c < columns; c++) ...[
                          if (c > 0) const SizedBox(width: 12),
                          Expanded(
                            child: c < rows[r].length
                                ? SharedMemoryCard(
                                    memory: rows[r][c],
                                    isMine: rows[r][c].uid == uid,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ],
    );
  }
}

/// 推しの選択（掲示板の推しの選択と同じ形。「フォロー中すべて」と、フォロー中の推し）
class _OshiDropdown extends StatelessWidget {
  const _OshiDropdown({
    required this.oshis,
    required this.selectedKey,
    required this.onChanged,
  });

  /// 「フォロー中すべて」を表す値（推しのキーと重ならない）
  static const String _allKey = '';

  final List<OshiSummary> oshis;
  final String? selectedKey;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandColors.ink, width: 2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const Key('shared_memories_oshi'),
          isExpanded: true,
          value: selectedKey ?? _allKey,
          items: [
            const DropdownMenuItem(value: _allKey, child: Text('フォロー中すべて')),
            for (final o in oshis)
              DropdownMenuItem(
                value: o.key,
                child: Text('${o.name}（${o.kind.label}）'),
              ),
          ],
          onChanged: (k) => onChanged(k == null || k == _allKey ? null : k),
        ),
      ),
    );
  }
}

/// 公開メモリーのカード（add_K 6.2）。
/// 名前と公演の日付 → 表紙の写真 → ライブ名・会場 → 感想の最初の3行
class SharedMemoryCard extends StatelessWidget {
  const SharedMemoryCard({
    super.key,
    required this.memory,
    required this.isMine,
  });

  final PublicMemory memory;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = memory;
    final impression = m.impression;

    return Card(
      key: Key('shared_memory_card_${m.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/shared-memories/${m.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 名前の行：アイコン・名前（自分）／右端に公演の日付
              Row(
                children: [
                  UserAvatar(uid: m.uid, name: m.displayName),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            m.displayName,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
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
                  ),
                  const SizedBox(width: 8),
                  Text(_dateOnly(m.startAt), style: theme.textTheme.bodySmall),
                ],
              ),
              // 2. 表紙の写真
              if (m.images.isNotEmpty) ...[
                const SizedBox(height: 10),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: StorageImage(path: m.images.first),
                  ),
                ),
              ],
              // 3. ライブ名・会場
              const SizedBox(height: 10),
              Text(
                m.liveTitle,
                style: HakoFonts.jp(
                  size: 15,
                  weight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              if (m.venue.isNotEmpty)
                Text(
                  m.venue,
                  style: HakoFonts.jp(
                    size: 12,
                    color: BrandColors.sub,
                    height: 1.5,
                  ),
                ),
              // 4. 感想の最初の3行
              if (impression != null) ...[
                const SizedBox(height: 6),
                Text(
                  impression,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}