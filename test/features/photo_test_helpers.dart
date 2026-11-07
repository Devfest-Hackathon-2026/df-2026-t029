import 'package:oshiashi/repositories/photo_repository.dart';
import 'package:oshiashi/utils/photo_picker.dart';

/// Storage に触れない偽の [PhotoRepository]（テストで `photoRepositoryProvider` を差し替える）
class FakePhotoRepository implements PhotoRepository {
  final uploaded = <String>[];
  final deleted = <String>[];

  @override
  Future<String> upload(String dir, PickedPhoto photo) async {
    final path = '$dir/fake_${uploaded.length}.${photo.extension}';
    uploaded.add(path);
    return path;
  }

  @override
  Future<void> delete(String path) async => deleted.add(path);

  @override
  Future<void> deleteAll(Iterable<String> paths) async => deleted.addAll(paths);

  @override
  Future<String> downloadUrl(String path) async => 'https://example.com/$path';
}
