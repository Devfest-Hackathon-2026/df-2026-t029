import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/photo_repository.dart';

/// 写真のリポジトリ。テストでは `overrideWithValue` で差し替える
final photoRepositoryProvider = Provider<PhotoRepository>(
  (ref) => FirebasePhotoRepository(FirebaseStorage.instance),
);

/// Storage のパス → ダウンロード URL（M-5 仕様書 5.3）。
/// autoDispose にせず、一度取った URL を覚えておく。
/// 消えた写真などで失敗したときは、取り直しを繰り返さない
final photoUrlProvider = FutureProvider.family<String, String>(
  (ref, path) => ref.watch(photoRepositoryProvider).downloadUrl(path),
  retry: (_, _) => null,
);