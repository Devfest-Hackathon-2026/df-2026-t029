// 同じライブの候補探し（計画書 3.1）。Firestore に依存しない純粋関数。
import 'package:flutter/foundation.dart';

import '../features/live_form/live_draft_to_models.dart';
import '../models/performance.dart';
import '../repositories/live_repository.dart';
import 'live_diff.dart';
import 'text_normalizer.dart';

/// 候補の強さ（計画書 3.1 の表）
enum MatchStrength {
  /// ほぼ確実（公式 URL が同じ／正規化したライブ名が同じ）
  sure,

  /// 可能性あり（名前の一方が他方を含み同じ日の公演がある／
  /// 同じ日・同じ会場の公演がある）
  possible,
}

/// 同じライブの候補1件
@immutable
class LiveCandidate {
  const LiveCandidate({
    required this.existing,
    required this.strength,
    required this.reasons,
  });

  final ExistingLive existing;
  final MatchStrength strength;

  /// 画面に出す理由（日本語。例: 「公式 URL が同じ」「ライブ名が同じ」
  /// 「11/23(月) に同じ会場の公演がある」）。1つ以上
  final List<String> reasons;
}

/// 入力 [input] と同じライブの候補を、強い順に最大 [limit] 件返す（計画書 3.1）。
///
/// - [existing] は `fetchCandidates` の結果（出演者が重なるライブ）
/// - ほぼ確実: 公式 URL が同じ（normalizeUrl）／正規化したライブ名が同じ
/// - 可能性あり: 正規化したライブ名の一方が他方を含み、かつ同じ日の公演がある／
///   同じ日・同じ会場（正規化した会場名）の公演がある
/// - 強さが同じなら、当てはまる理由が多い順 → 最初の公演が入力の最初の公演に
///   近い順 → ID の順
/// - 公演の日付は日本時間の日で比べる
/// - 当てはまらないライブは含めない（候補が無ければ空のリスト）。
///   同じ ID のライブが2回あっても1件にする
List<LiveCandidate> findLiveCandidates(
  LiveModels input,
  List<ExistingLive> existing, {
  int limit = 3,
}) {
  final inputUrl = normalizeUrl(input.live.officialUrl ?? '');
  final inputTitle = normalizeName(input.live.title);
  final inputFirst = _firstStart(input.performances);

  final scored = <({LiveCandidate c, Duration? distance, String id})>[];
  final seen = <String>{};
  for (final e in existing) {
    final id = e.live.id ?? '';
    if (!seen.add(id)) continue;

    final sure = <String>[];
    final possible = <String>[];
    final url = normalizeUrl(e.live.officialUrl ?? '');
    if (inputUrl.isNotEmpty && url == inputUrl) sure.add('公式 URL が同じ');
    final title = normalizeName(e.live.title);
    if (inputTitle.isNotEmpty && title == inputTitle) {
      sure.add('ライブ名が同じ');
    } else if (inputTitle.isNotEmpty &&
        title.isNotEmpty &&
        (title.contains(inputTitle) || inputTitle.contains(title))) {
      final day = _firstSameDay(input.performances, e.performances);
      if (day != null) {
        possible.add('ライブ名が似ていて、${_md(day)} に公演がある');
      }
    }
    final venueDay = _firstSameDayAndVenue(input.performances, e.performances);
    if (venueDay != null) {
      possible.add('${_md(venueDay.day)} に同じ会場（${venueDay.venue}）の公演がある');
    }
    if (sure.isEmpty && possible.isEmpty) continue;

    final eFirst = _firstStart(e.performances);
    scored.add((
      c: LiveCandidate(
        existing: e,
        strength: sure.isNotEmpty ? MatchStrength.sure : MatchStrength.possible,
        reasons: List.unmodifiable([...sure, ...possible]),
      ),
      distance: inputFirst == null || eFirst == null
          ? null
          : inputFirst.difference(eFirst).abs(),
      id: id,
    ));
  }

  scored.sort((a, b) {
    final s = a.c.strength.index.compareTo(b.c.strength.index);
    if (s != 0) return s;
    final r = b.c.reasons.length.compareTo(a.c.reasons.length);
    if (r != 0) return r;
    final da = a.distance, db = b.distance;
    if (da != null && db == null) return -1;
    if (da == null && db != null) return 1;
    if (da != null && db != null) {
      final d = da.compareTo(db);
      if (d != 0) return d;
    }
    return a.id.compareTo(b.id);
  });
  return [for (final s in scored.take(limit)) s.c];
}

DateTime? _firstStart(List<Performance> ps) {
  DateTime? first;
  for (final p in ps) {
    if (first == null || p.startAt.isBefore(first)) first = p.startAt;
  }
  return first;
}

/// 入力と既存で、日本時間の同じ日にある公演の最も早い日（無ければ null）
DateTime? _firstSameDay(List<Performance> input, List<Performance> existing) {
  final days = {for (final e in existing) jstDayOf(e.startAt)};
  final hits = [
    for (final p in input)
      if (days.contains(jstDayOf(p.startAt))) p.startAt,
  ]..sort();
  return hits.firstOrNull;
}

/// 入力と既存で、同じ日・同じ会場の公演の最も早いもの（無ければ null）
({DateTime day, String venue})? _firstSameDayAndVenue(
  List<Performance> input,
  List<Performance> existing,
) {
  ({DateTime day, String venue})? best;
  for (final p in input) {
    final venue = normalizeName(p.venue);
    if (venue.isEmpty) continue;
    for (final e in existing) {
      if (isSameJstDay(p.startAt, e.startAt) &&
          normalizeName(e.venue) == venue &&
          (best == null || p.startAt.isBefore(best.day))) {
        best = (day: p.startAt, venue: e.venue);
      }
    }
  }
  return best;
}

/// 日本時間の「11/23(月)」
String _md(DateTime t) {
  final j = t.toUtc().add(const Duration(hours: 9));
  const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
  return '${j.month}/${j.day}(${weekdays[j.weekday - 1]})';
}
