import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event_weather.dart';
import '../models/performance.dart';
import '../repositories/weather_repository.dart';
import '../utils/travel_links.dart';
import 'oshi_providers.dart';

/// 天気のリポジトリ。テストでは `overrideWithValue` で差し替える
final weatherRepositoryProvider = Provider<WeatherRepository>(
  (ref) => FunctionsWeatherRepository(
    FirebaseFunctions.instanceFor(region: 'asia-northeast1'),
  ),
);

/// 天気を調べる条件（都道府県と、日本時間の日付 `YYYY-MM-DD`）
typedef WeatherQuery = ({String prefecture, String date});

/// 公演の天気を調べる条件。予報がある範囲（今日から9日後まで）で、
/// オンラインでなく都道府県があるときだけ返す（add_E 5.3）
WeatherQuery? weatherQueryOf(Performance p, DateTime now) {
  final pref = p.prefecture;
  if (pref == null || pref.isEmpty || isOnlineVenue(p)) return null;
  final start = DateTime(p.startAt.year, p.startAt.month, p.startAt.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = start.difference(today).inDays;
  if (days < 0 || days > 9) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  return (
    prefecture: pref,
    date: '${start.year}-${two(start.month)}-${two(start.day)}',
  );
}

/// 公演の日の天気。未ログインなら null。
/// 同じ条件は1回だけ呼ぶ（autoDispose にしない）。失敗しても取り直さない
final eventWeatherProvider = FutureProvider.family<EventWeather?, WeatherQuery>(
  (ref, q) {
    if (ref.watch(currentUidProvider) == null) return null;
    return ref
        .watch(weatherRepositoryProvider)
        .fetch(prefecture: q.prefecture, date: q.date);
  },
  retry: (_, _) => null,
);
