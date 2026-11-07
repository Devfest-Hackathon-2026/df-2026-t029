import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/live_memory.dart';
import '../../providers/live_providers.dart';
import '../../providers/memory_providers.dart';
import '../live_form/date_time_field.dart';
import '../common/storage_image.dart';

/// 記録の詳細（/memories/:performanceId）
class MemoryDetailPage extends ConsumerWidget {
  const MemoryDetailPage({super.key, required this.performanceId});

  final String performanceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = ref.watch(memoryProvider(performanceId));
    final now = ref.watch(nowProvider);
    final found = memory.value != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('記録'),
        actions: [
          if (found)
            IconButton(
              key: const Key('memory_detail_edit_button'),
              tooltip: '編集',
              onPressed: () => context.go('/memories/$performanceId/edit'),
              icon: const Icon(Icons.edit),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (memory) {
          AsyncError() => const Center(
            key: Key('memory_detail_error'),
            child: Text('記録を読み込めませんでした'),
          ),
          AsyncData(value: final m?) => _DetailView(memory: m, now: now),
          AsyncData() => const Center(
            key: Key('memory_detail_not_found'),
            child: Text('この記録は見つかりませんでした'),
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

class _DetailView extends StatelessWidget {
  const _DetailView({required this.memory, required this.now});

  final LiveMemory memory;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = memory;
    final attended = m.isAttended(now);
    final seat = m.seat;
    final impression = m.impression;
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);

    return ListView(
      key: const Key('memory_detail'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(m.liveTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('${formatDateTime(m.startAt)} 開演'),
        Text(m.venue),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            key: const Key('memory_detail_state'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: attended
                  ? theme.colorScheme.secondaryContainer
                  : theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              attended ? '参戦済み' : '参戦予定',
              style: theme.textTheme.labelSmall,
            ),
          ),
        ),
        // 写真は、あるときだけ出す（仕様書 6.3）
        if (m.images.isNotEmpty)
          _Section(
            title: '写真',
            child: _PhotoGrid(paths: m.images),
          ),
        _Section(
          title: '座席',
          child: Text(
            seat ?? '未入力',
            key: const Key('memory_detail_seat'),
            style: seat == null ? muted : null,
          ),
        ),
        _Section(
          title: 'セトリ',
          child: m.setlist.isEmpty
              ? Text('未入力', style: muted)
              : Column(
                  key: const Key('memory_detail_setlist'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, song) in m.setlist.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('${i + 1}. $song'),
                      ),
                  ],
                ),
        ),
        _Section(
          title: '感想',
          child: Text(
            impression ?? '未入力',
            key: const Key('memory_detail_impression'),
            style: impression == null ? muted : null,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// 写真のグリッド（1行3枚、正方形）。押すと大きく表示する（仕様書 6.3）
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      // PC の広い画面で写真が大きくなりすぎないように
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: GridView.count(
          key: const Key('memory_detail_photos'),
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final (i, path) in paths.indexed)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    StorageImage(path: path),
                    Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => _PhotoViewer(
                            paths: paths,
                            initialIndex: i,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 写真を画面いっぱいに表示する。拡大でき、左右に送れる
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.paths, required this.initialIndex});

  final List<String> paths;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int index) => _controller.animateToPage(
    index,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    // 写真を見る画面なので、テーマの色ではなく黒地に白で表示する
    const fg = Colors.white;
    final count = widget.paths.length;
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: count,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              maxScale: 4,
              child: StorageImage(path: widget.paths[i], fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              tooltip: '閉じる',
              color: fg,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
          if (count > 1) ...[
            if (_index > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    tooltip: '前の写真',
                    color: fg,
                    onPressed: () => _go(_index - 1),
                    icon: const Icon(Icons.chevron_left, size: 36),
                  ),
                ),
              ),
            if (_index < count - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    tooltip: '次の写真',
                    color: fg,
                    onPressed: () => _go(_index + 1),
                    icon: const Icon(Icons.chevron_right, size: 36),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Text(
                '${_index + 1} / $count',
                textAlign: TextAlign.center,
                style: const TextStyle(color: fg),
              ),
            ),
          ],
        ],
      ),
    );
  }
}