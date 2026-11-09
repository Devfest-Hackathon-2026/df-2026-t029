import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// iframe を埋め込む（add_P 5.5）。Web 版
class WebIframe extends StatelessWidget {
  const WebIframe({
    super.key,
    required this.src,
    this.aspectRatio = 16 / 9,
    this.title = '',
  });

  final String src;
  final double aspectRatio;

  /// 読み上げ用の題名
  final String title;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: HtmlElementView.fromTagName(
        // src が変わったら作り直す
        key: ValueKey(src),
        tagName: 'iframe',
        onElementCreated: (element) {
          final iframe = element as web.HTMLIFrameElement;
          iframe
            ..src = src
            ..title = title
            ..allow = 'autoplay; encrypted-media; picture-in-picture; fullscreen'
            ..allowFullscreen = true;
          iframe.style
            ..border = 'none'
            ..width = '100%'
            ..height = '100%';
        },
      ),
    );
  }
}