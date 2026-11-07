import '../models/performance.dart';

/// 行く場所がない公演（オンライン配信など）か。会場名で判定する
bool isOnlineVenue(Performance p) =>
    p.venue.contains('オンライン') || p.venue.contains('配信');

/// Google マップで探すときの場所（会場名と都道府県）
String _placeOf(Performance p) => [
  p.venue,
  if (p.prefecture case final pref? when pref.isNotEmpty) pref,
].join(' ');

/// 会場までの行き方（Google マップの経路）。オンラインなら null
Uri? directionsUri(Performance p) => isOnlineVenue(p)
    ? null
    : Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': _placeOf(p),
      });

/// 会場の周辺の宿（Google マップの検索）。オンラインなら null
Uri? hotelsUri(Performance p) => isOnlineVenue(p)
    ? null
    : Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${_placeOf(p)} 周辺 ホテル',
      });