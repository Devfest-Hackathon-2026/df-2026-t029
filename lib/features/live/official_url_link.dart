import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// URL を開く処理。開けたら true
typedef UrlOpener = Future<bool> Function(Uri uri);

/// URL を開く処理（新しいタブ）。テストでは `overrideWithValue` で差し替える
final urlLauncherProvider = Provider<UrlOpener>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// 開いてよい公式 URL なら Uri を返す。`https://` で始まり、ホストがあり、
/// userinfo（`@` の前の部分）が無いものだけ。
/// それ以外（壊れたデータなど）は null（リンクにせず、文字だけを出す）
Uri? officialLinkUri(String? url) {
  if (url == null || !url.startsWith('https://')) return null;
  // 空白を含むものは、Uri.tryParse が通しても URL として扱わない
  if (url.contains(RegExp(r'\s'))) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  // userinfo 付き（https://example.com@evil.example/）は、見た目と開く先が違うので
  // リンクにしない
  if (uri.userInfo.isNotEmpty) return null;
  return uri;
}

/// ライブ詳細の公式 URL。https の URL は押すと開くリンクにする
class OfficialUrlLink extends ConsumerStatefulWidget {
  const OfficialUrlLink({super.key, required this.url});

  final String url;

  @override
  ConsumerState<OfficialUrlLink> createState() => _OfficialUrlLinkState();
}

class _OfficialUrlLinkState extends ConsumerState<OfficialUrlLink> {
  /// 開く処理の途中（連打でタブが複数開かないように、その間のタップは無視する）
  bool _opening = false;

  Future<void> _open(Uri uri) async {
    if (_opening) return;
    _opening = true;
    var opened = false;
    try {
      opened = await ref.read(urlLauncherProvider)(uri);
    } catch (e) {
      debugPrint('公式サイトを開けませんでした: $e');
    } finally {
      _opening = false;
    }
    // State.context を使うので、State の mounted で確認する
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('公式サイトを開けませんでした')));
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    final color = Theme.of(context).colorScheme.primary;
    final uri = officialLinkUri(url);
    if (uri == null) {
      return Text(url, style: TextStyle(color: color));
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => _open(uri),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.open_in_new, size: 16, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  url,
                  semanticsLabel: '公式サイトを開く $url',
                  style: TextStyle(
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
    );
  }
}
