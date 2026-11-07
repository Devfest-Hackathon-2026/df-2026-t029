import '../models/live.dart';
import '../models/performance.dart';
import 'deadline.dart';
import 'text_normalizer.dart';

/// 選んだ推しのライブを、ライブ名（正規化した部分一致）で絞り込み、
/// 一覧と同じ順（[buildLiveList]）に並べる。[query] が空（空白のみ含む）ならすべて。
/// [now] は引数で受け取る。
List<LiveListEntry> searchLives(
  List<Live> lives,
  List<Performance> performances,
  String query,
  DateTime now,
) {
  final q = normalizeName(query);
  final matched = q.isEmpty
      ? lives
      : [
          for (final l in lives)
            if (normalizeName(l.title).contains(q)) l,
        ];
  return buildLiveList(matched, performances, now);
}
