import 'package:flutter/material.dart';

/// カードを横に並べる一覧。PC でも続きがわかるよう、スクロールバーを常に出す
class HomeHorizontalList extends StatefulWidget {
  const HomeHorizontalList({
    super.key,
    required this.height,
    required this.itemWidth,
    required this.children,
  });

  /// カードの高さ
  final double height;

  /// カード1枚の幅
  final double itemWidth;
  final List<Widget> children;

  @override
  State<HomeHorizontalList> createState() => _HomeHorizontalListState();
}

class _HomeHorizontalListState extends State<HomeHorizontalList> {
  // スクロールバーと一覧で同じものを使う（ホームの縦のスクロールと区別するため）
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 下はスクロールバーの分の余白
      height: widget.height + 16,
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: ListView.separated(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: widget.children.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) =>
              SizedBox(width: widget.itemWidth, child: widget.children[i]),
        ),
      ),
    );
  }
}