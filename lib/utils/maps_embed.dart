import '../models/performance.dart';
import 'travel_links.dart';

/// Maps Embed API のキー（add_M 2.2）。`--dart-define=MAPS_EMBED_KEY=...` で渡す。
/// 空なら埋め込みを出さず、Google マップを開くボタンだけにする
const mapsEmbedKey = String.fromEnvironment('MAPS_EMBED_KEY');

bool get hasMapsEmbedKey => mapsEmbedKey.isNotEmpty;

/// 会場の地図（埋め込み）。キーが無い・オンラインなら null
String? venueMapEmbedUrl(Performance p) {
  if (!hasMapsEmbedKey || isOnlineVenue(p)) return null;
  return Uri.https('www.google.com', '/maps/embed/v1/place', {
    'key': mapsEmbedKey,
    'q': placeOf(p),
    'language': 'ja',
    'region': 'JP',
  }).toString();
}

/// 会場 → 帰りの駅の電車の経路（埋め込み）。キーが無い・オンライン・駅が空なら null
String? homeRouteEmbedUrl(Performance p, String? homeStation) {
  final s = homeStation?.trim() ?? '';
  if (!hasMapsEmbedKey || isOnlineVenue(p) || s.isEmpty) return null;
  return Uri.https('www.google.com', '/maps/embed/v1/directions', {
    'key': mapsEmbedKey,
    'origin': placeOf(p),
    'destination': s,
    'mode': 'transit',
    'language': 'ja',
    'region': 'JP',
  }).toString();
}

/// 会場 → 帰りの駅の電車の経路を Google マップで開く（時刻・終電はそこで指定）。
/// オンライン・駅が空なら null
Uri? homeRouteUri(Performance p, String? homeStation) {
  final s = homeStation?.trim() ?? '';
  if (isOnlineVenue(p) || s.isEmpty) return null;
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'origin': placeOf(p),
    'destination': s,
    'travelmode': 'transit',
  });
}

/// 会場を Google マップで開く（キーが無いときの代わり）。オンラインなら null
Uri? venueMapUri(Performance p) => isOnlineVenue(p)
    ? null
    : Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': placeOf(p),
      });