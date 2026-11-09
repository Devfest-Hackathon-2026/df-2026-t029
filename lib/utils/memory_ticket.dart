import '../models/live_memory.dart';

/// 開演から何日以内の記録を「新しい記録」とするか（4.9）
const recentMemoryDays = 7;

/// Gemini が選ぶ写真の最大枚数・候補の最大枚数・縮小版の長辺（4.5・5.3）
const maxAiPicks = 4;
const maxPickCandidates = 30;
const pickThumbSide = 768;

bool _hasText(String? s) => s != null && s.trim().isNotEmpty;

/// 記録の進み具合 0〜4。写真が1枚以上・座席・セトリ・感想のうち入っている数
/// （座席・感想は前後の空白を除いて空なら入っていない）
int memoryProgress(LiveMemory m) {
  var n = 0;
  if (m.images.isNotEmpty) n++;
  if (_hasText(m.seat)) n++;
  if (m.setlist.isNotEmpty) n++;
  if (_hasText(m.impression)) n++;
  return n;
}

/// 「新しい記録」。参戦済み（startAt が now 以前）・開演から [recentMemoryDays] 日以内・
/// postedAt が無い記録のうち、startAt が最も新しい1件。無ければ null。
/// ちょうど [recentMemoryDays] 日前の開演は含む
LiveMemory? recentUnpostedMemory(Iterable<LiveMemory> memories, DateTime now) {
  final oldest = now.subtract(const Duration(days: recentMemoryDays));
  LiveMemory? best;
  for (final m in memories) {
    if (m.postedAt != null) continue;
    if (m.startAt.isAfter(now)) continue;
    if (m.startAt.isBefore(oldest)) continue;
    if (best == null || m.startAt.isAfter(best.startAt)) best = m;
  }
  return best;
}
