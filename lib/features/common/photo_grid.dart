import 'package:flutter/material.dart';

import 'storage_image.dart';

/// 写真のグリッド（1行3枚、正方形）。押すと大きく表示する（G-7 仕様書 5.2）
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key, required this.paths, this.maxWidth = 480});

  /// Storage のパス
  final List<String> paths;

  /// PC の広い画面で写真が大きくなりすぎないように
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: GridView.count(
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
                          builder: (_) =>
                              PhotoViewer(paths: paths, initialIndex: i),
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
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.paths, required this.initialIndex});

  final List<String> paths;
  final int initialIndex;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
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