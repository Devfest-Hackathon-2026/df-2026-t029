import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/live_fetch_repository.dart';

/// ライブ情報の自動取得のリポジトリ（add_L 5.1）。テストでは `overrideWithValue` で差し替える
final liveFetchRepositoryProvider = Provider<LiveFetchRepository>(
  (ref) => FunctionsLiveFetchRepository(
    FirebaseFunctions.instanceFor(region: 'asia-northeast1'),
  ),
);