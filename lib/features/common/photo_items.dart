import 'package:flutter/material.dart';

import '../../repositories/photo_repository.dart';
import '../../utils/photo_picker.dart';
import 'storage_image.dart';

/// 編集中の写真1枚（メモリー・グッズ交換で共通。G-7 仕様書 5.1）
sealed class PhotoItem {
  const PhotoItem();
}

/// 保存済みの写真（Storage のパス）
class SavedPhoto extends PhotoItem {
  const SavedPhoto(this.path);

  final String path;
}

/// 新しく選んだ写真（保存するときにアップロードする）
class NewPhoto extends PhotoItem {
  const NewPhoto(this.photo);

  final PickedPhoto photo;
}

/// 保存済みのパスから、編集用の写真の並びを作る
List<PhotoItem> savedPhotoItems(List<String> paths) => [
  for (final path in paths) SavedPhoto(path),
];

/// 写真を選び、知らせ（外した写真・上限・読み込みの失敗）を SnackBar で出して、
/// 新しい写真の一覧を返す。何も選ばなければ空
Future<List<NewPhoto>> pickNewPhotos(
  BuildContext context, {
  required int remaining,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  void show(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
  PhotoPickResult result;
  try {
    result = await pickPhotos(remaining: remaining);
  } catch (e) {
    debugPrint('写真の読み込みに失敗: $e');
    show('写真を読み込めませんでした');
    return const [];
  }
  if (photoPickMessage(result) case final message?) show(message);
  return [for (final photo in result.photos) NewPhoto(photo)];
}

/// [items] の新しい写真を [dir] の下にアップロードし、写真 → パスの Map を返す。
/// 失敗したら、この呼び出しでアップロードした分を消して例外を投げ直す
Future<Map<NewPhoto, String>> uploadNewPhotos(
  PhotoRepository repo,
  String dir,
  Iterable<PhotoItem> items,
) async {
  final uploaded = <NewPhoto, String>{};
  try {
    for (final item in items) {
      if (item is NewPhoto) {
        uploaded[item] = await repo.upload(dir, item.photo);
      }
    }
  } catch (_) {
    await repo.deleteAll(uploaded.values);
    rethrow;
  }
  return uploaded;
}

/// 写真の並びを、Storage のパスの並びにする（新しい写真は [uploaded] のパス）
List<String> photoPathsOf(
  List<PhotoItem> items,
  Map<NewPhoto, String> uploaded,
) => [
  for (final item in items)
    switch (item) {
      SavedPhoto(:final path) => path,
      NewPhoto() => uploaded[item]!,
    },
];

/// 写真の欄：見出し・サムネイルの並び・「写真を追加」
class PhotoEditSection extends StatelessWidget {
  const PhotoEditSection({
    super.key,
    required this.title,
    required this.photos,
    required this.canAdd,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
    this.addButtonKey,
  });

  final String title;
  final List<PhotoItem> photos;

  /// 「写真を追加」を押せるか（枚数の上限・処理中を呼び出し側で判定する）
  final bool canAdd;

  /// 「×」で外せるか（処理中は false）
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final Key? addButtonKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (photos.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, item) in photos.indexed)
                PhotoThumb(
                  key: ObjectKey(item),
                  item: item,
                  onRemove: enabled ? () => onRemove(i) : null,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: addButtonKey,
            onPressed: canAdd ? onAdd : null,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('写真を追加'),
          ),
        ),
      ],
    );
  }
}

/// サムネイル1枚（96×96、角丸 8、右上に「×」）
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({super.key, required this.item, required this.onRemove});

  final PhotoItem item;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: switch (item) {
                SavedPhoto(:final path) => StorageImage(path: path),
                NewPhoto(:final photo) => Image.memory(
                  photo.bytes,
                  fit: BoxFit.cover,
                ),
              },
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              tooltip: '外す',
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: scheme.surface.withValues(alpha: 0.85),
                foregroundColor: scheme.onSurface,
              ),
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}