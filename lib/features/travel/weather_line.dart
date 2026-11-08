import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/performance.dart';
import '../../providers/weather_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';

/// 天気の種類 → アイコン（Weather API の画像は使わない。add_E 5.3）
IconData weatherIconOf(String? type) {
  final t = type ?? '';
  if (t.contains('THUNDER')) return Icons.thunderstorm_outlined;
  if (t.contains('SNOW') || t.contains('SLEET') || t.contains('HAIL')) {
    return Icons.ac_unit;
  }
  if (t.contains('RAIN') || t.contains('SHOWER') || t.contains('DRIZZLE')) {
    return Icons.umbrella;
  }
  if (t == 'CLEAR' || t == 'MOSTLY_CLEAR') return Icons.wb_sunny_outlined;
  if (t == 'PARTLY_CLOUDY') return Icons.wb_cloudy_outlined;
  return Icons.cloud_outlined;
}

/// 公演の日の天気予報の1行（例：「天気予報 ☀ 晴れ 18℃ / 9℃ 降水 10%」）。
/// 予報の範囲の外・読み込み中・取れなかったときは何も出さない
/// （取得に失敗したときだけ「天気を取得できませんでした」）
class WeatherLine extends ConsumerWidget {
  const WeatherLine({super.key, required this.performance, required this.now});

  final Performance performance;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = weatherQueryOf(performance, now);
    if (q == null) return const SizedBox.shrink();
    final style = HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.5);
    return switch (ref.watch(eventWeatherProvider(q))) {
      AsyncData(value: final w?) when w.isAvailable => Padding(
        key: Key('weather_line_${performance.id}'),
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('天気予報 ', style: style),
            Icon(weatherIconOf(w.type), size: 16, color: BrandColors.ink),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                [
                  if (w.text case final t? when t.isNotEmpty) t,
                  if (w.maxC != null && w.minC != null)
                    '${w.maxC}℃ / ${w.minC}℃',
                  if (w.rainPercent case final r?) '降水 $r%',
                ].join('　'),
                style: style.copyWith(color: BrandColors.ink),
              ),
            ),
          ],
        ),
      ),
      AsyncError() => Text('天気を取得できませんでした', style: style),
      _ => const SizedBox.shrink(),
    };
  }
}