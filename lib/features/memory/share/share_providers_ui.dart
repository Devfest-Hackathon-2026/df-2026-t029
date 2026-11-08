import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/photo_providers.dart';
import '../../../utils/file_download.dart';
import 'share_ticket_view.dart';

/// URL を新しいタブで開く。開けたら true。テストでは差し替える
final shareUrlOpenerProvider = Provider<Future<bool> Function(Uri url)>(
  (ref) =>
      (url) => launchUrl(url, webOnlyWindowName: '_blank'),
);

/// 画像（PNG）を保存する。テストでは差し替える
final shareImageSaverProvider =
    Provider<Future<void> Function(Uint8List bytes, String fileName)>(
      (ref) =>
          (bytes, fileName) => downloadBytes(bytes, fileName),
    );

/// 文章をクリップボードへ入れる。テストでは差し替える
final shareClipboardProvider = Provider<Future<void> Function(String text)>(
  (ref) =>
      (text) => Clipboard.setData(ClipboardData(text: text)),
);

/// 描き終わった部分を PNG にする（既定は [captureShareImage]）。テストでは差し替える
final shareCaptureProvider =
    Provider<
      Future<Uint8List> Function(GlobalKey boundaryKey, double pixelRatio)
    >(
      (ref) =>
          (key, pixelRatio) => captureShareImage(key, pixelRatio: pixelRatio),
    );

/// URL から画像のバイト列を取る。テストでは差し替える
final sharePhotoFetcherProvider =
    Provider<Future<Uint8List> Function(String url)>(
      (ref) => (url) async {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) {
          throw StateError('写真を取得できませんでした');
        }
        return response.bodyBytes;
      },
    );

/// [sharePhotoBytesProvider] のキー。写真の Storage のパス（表紙から先頭3枚）をつなげる
String sharePhotoBytesKey(Iterable<String> paths) => paths.take(3).join('|');

/// 記録の写真（表紙から先頭3枚）のバイト列。シェア画像（[ShareTicketView]）に渡す。
/// 取れなかった写真は飛ばす（空でも失敗にしない）。
/// 使い方: `ref.watch(sharePhotoBytesProvider(sharePhotoBytesKey(memory.images)))`
final sharePhotoBytesProvider = FutureProvider.autoDispose
    .family<List<Uint8List>, String>((ref, key) async {
      if (key.isEmpty) return const [];
      final fetch = ref.watch(sharePhotoFetcherProvider);
      final result = <Uint8List>[];
      for (final path in key.split('|')) {
        try {
          final url = await ref.watch(photoUrlProvider(path).future);
          result.add(await fetch(url));
        } catch (e) {
          debugPrint('写真を取得できませんでした');
        }
      }
      return result;
    });
