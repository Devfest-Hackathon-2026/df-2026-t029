import 'package:flutter/material.dart';

import '../models/performance.dart';

/// 行く場所がない公演（オンライン配信など）か。会場名で判定する
bool isOnlineVenue(Performance p) =>
    p.venue.contains('オンライン') || p.venue.contains('配信');

/// Google マップで探すときの場所（会場名と都道府県）
String _placeOf(Performance p) => [
  p.venue,
  if (p.prefecture case final pref? when pref.isNotEmpty) pref,
].join(' ');

/// Google マップで探すときの場所（会場名と都道府県）。add_M の地図でも使う
String placeOf(Performance p) => _placeOf(p);

/// 会場までの行き方（Google マップの経路。電車などの公共交通機関。
/// add_E 4章）。オンラインなら null
Uri? directionsUri(Performance p) => isOnlineVenue(p)
    ? null
    : Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': _placeOf(p),
        'travelmode': 'transit',
      });

/// 会場の周辺を Google マップで探す（[what] は「ホテル」など）。
/// オンラインなら null
Uri? _nearbyUri(Performance p, String what) => isOnlineVenue(p)
    ? null
    : Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${_placeOf(p)} 周辺 $what',
      });

/// 会場の周辺の宿（Google マップの検索。料金・予約先もここから見られる）
Uri? hotelsUri(Performance p) => _nearbyUri(p, 'ホテル');

/// 会場の周辺のコインロッカー（add_E 4章）
Uri? lockersUri(Performance p) => _nearbyUri(p, 'コインロッカー');

/// 会場の周辺のごはん（add_E 4章）
Uri? foodUri(Performance p) => _nearbyUri(p, 'ごはん');

/// 遠征のリンク1つ（ボタンの名前・アイコン・開く先）
typedef TravelLink = ({String label, IconData icon, Uri uri});

/// 公演の遠征のリンクを並べる（行き方・周辺の宿・周辺のロッカー・
/// 周辺のごはん。どれも Google マップ。add_E 4章）。オンラインなら空
List<TravelLink> travelLinksOf(Performance p) => [
  if (directionsUri(p) case final u?)
    (label: '行き方', icon: Icons.directions, uri: u),
  if (hotelsUri(p) case final u?)
    (label: '周辺の宿', icon: Icons.hotel, uri: u),
  if (lockersUri(p) case final u?)
    (label: '周辺のロッカー', icon: Icons.luggage_outlined, uri: u),
  if (foodUri(p) case final u?)
    (label: '周辺のごはん', icon: Icons.restaurant, uri: u),
];