import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/live_repository.dart';

/// ライブのリポジトリ。テストでは `overrideWithValue` で差し替える
final liveRepositoryProvider = Provider<LiveRepository>(
  (ref) => FirestoreLiveRepository(FirebaseFirestore.instance),
);