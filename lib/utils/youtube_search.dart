import '../models/live.dart';
import '../models/oshi.dart';

/// セトリの曲の YouTube 検索の URL（add_P 5.4）。語は「推しの名前 曲名」
Uri youtubeSearchUri(String song, {String? artist}) => Uri.https(
  'www.youtube.com',
  '/results',
  {
    'search_query': [
      if (artist != null && artist.isNotEmpty) artist,
      song.trim(),
    ].join(' '),
  },
);

/// ライブの出演者のうち、最初の推しの名前（グループ → 個人の順）。分からなければ null
String? performerNameOf(Live? live, List<OshiSummary> all) {
  if (live == null) return null;
  for (final id in live.groupIds) {
    final o = all
        .where((o) => o.kind == OshiKind.group && o.id == id)
        .firstOrNull;
    if (o != null) return o.name;
  }
  for (final id in live.oshiIds) {
    final o = all
        .where((o) => o.kind == OshiKind.person && o.id == id)
        .firstOrNull;
    if (o != null) return o.name;
  }
  return null;
}