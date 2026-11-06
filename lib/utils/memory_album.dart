import '../models/live_memory.dart';

/// メモリー一覧の中身
class MemoryAlbum {
  const MemoryAlbum({required this.upcoming, required this.attended});

  /// 参戦予定（公演日時の近い順）
  final List<LiveMemory> upcoming;

  /// 参戦済み（公演日時の新しい順）
  final List<LiveMemory> attended;
}

/// 記録を参戦予定・参戦済みに分けて並べる（[LiveMemory.isAttended] で判定する）
MemoryAlbum buildMemoryAlbum(Iterable<LiveMemory> memories, DateTime now) {
  final upcoming = <LiveMemory>[];
  final attended = <LiveMemory>[];
  for (final m in memories) {
    (m.isAttended(now) ? attended : upcoming).add(m);
  }
  upcoming.sort((a, b) => a.startAt.compareTo(b.startAt));
  attended.sort((a, b) => b.startAt.compareTo(a.startAt));
  return MemoryAlbum(upcoming: upcoming, attended: attended);
}