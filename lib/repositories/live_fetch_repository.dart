import 'package:cloud_functions/cloud_functions.dart';

import '../models/oshi.dart';

/// 取得の結果の状態（add_L 4.1）。知らない値は error 扱い
enum LiveFetchStatus { ok, noOfficialSite, blocked, skipped, unchanged }

/// 足した（または公演・受付を足した）ライブ
typedef LiveFetchAddedLive = ({String id, String title, bool isNew});

/// fetchOshiLives の結果（add_L 4.1）
class LiveFetchResult {
  const LiveFetchResult({
    required this.status,
    this.addedLives = 0,
    this.addedPerformances = 0,
    this.addedReceptions = 0,
    this.lives = const [],
    this.officialUrl,
    this.searchQueries = const [],
  });

  final LiveFetchStatus status;
  final int addedLives;
  final int addedPerformances;
  final int addedReceptions;
  final List<LiveFetchAddedLive> lives;
  final String? officialUrl;
  final List<String> searchQueries;

  /// 何か足したか
  bool get hasAdded => addedLives + addedPerformances + addedReceptions > 0;

  factory LiveFetchResult.fromMap(Map<Object?, Object?> map) {
    final added = map['added'] as Map<Object?, Object?>? ?? const {};
    int count(String key) => (added[key] as num?)?.toInt() ?? 0;
    return LiveFetchResult(
      status: LiveFetchStatus.values.asNameMap()[map['status']] ??
          LiveFetchStatus.skipped,
      addedLives: count('lives'),
      addedPerformances: count('performances'),
      addedReceptions: count('receptions'),
      lives: [
        for (final l in map['lives'] as List<Object?>? ?? const [])
          if (l is Map<Object?, Object?> && l['id'] is String)
            (
              id: l['id'] as String,
              title: l['title'] as String? ?? '',
              isNew: l['isNew'] == true,
            ),
      ],
      officialUrl: map['officialUrl'] as String?,
      searchQueries: [
        for (final q in map['searchQueries'] as List<Object?>? ?? const [])
          if (q is String) q,
      ],
    );
  }
}

/// ライブ情報の自動取得（add_L 5.1）
abstract class LiveFetchRepository {
  /// [kind]・[id] の推しの公式サイトからライブを探して登録する
  Future<LiveFetchResult> fetch(OshiKind kind, String id);
}

/// Cloud Functions（fetchOshiLives）版の [LiveFetchRepository]
class FunctionsLiveFetchRepository implements LiveFetchRepository {
  FunctionsLiveFetchRepository(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<LiveFetchResult> fetch(OshiKind kind, String id) async {
    final result = await _functions
        .httpsCallable(
          'fetchOshiLives',
          // Gemini の調査を待つので長め（add_L 5.1）
          options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
        )
        .call<Map<Object?, Object?>>({'kind': kind.name, 'id': id});
    return LiveFetchResult.fromMap(result.data);
  }
}