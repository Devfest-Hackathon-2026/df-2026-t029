import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/photo_providers.dart';

/// Storage の写真を表示する（M-5 仕様書 3.4・5.4）。
/// 親の大きさいっぱいに広がる。読み込み中は色付きの枠、失敗したらアイコン
class StorageImage extends ConsumerWidget {
  const StorageImage({super.key, required this.path, this.fit = BoxFit.cover});

  /// Storage のパス（`users/...`）
  final String path;

  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: const SizedBox.expand(),
    );
    final broken = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: SizedBox.expand(
        child: Icon(
          Icons.broken_image_outlined,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
    return switch (ref.watch(photoUrlProvider(path))) {
      AsyncData(:final value) => Image.network(
        value,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
        errorBuilder: (context, error, stackTrace) => broken,
      ),
      AsyncError() => broken,
      _ => placeholder,
    };
  }
}