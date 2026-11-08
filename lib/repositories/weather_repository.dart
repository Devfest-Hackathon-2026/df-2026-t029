import 'package:cloud_functions/cloud_functions.dart';

import '../models/event_weather.dart';

/// 公演の日の天気（add_E 5.3）
abstract class WeatherRepository {
  /// [prefecture] の [date]（`YYYY-MM-DD`、日本時間）の天気
  Future<EventWeather> fetch({
    required String prefecture,
    required String date,
  });
}

/// Cloud Functions（getEventWeather）版の [WeatherRepository]
class FunctionsWeatherRepository implements WeatherRepository {
  FunctionsWeatherRepository(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<EventWeather> fetch({
    required String prefecture,
    required String date,
  }) async {
    final result = await _functions
        .httpsCallable('getEventWeather')
        .call<Map<Object?, Object?>>({'prefecture': prefecture, 'date': date});
    return EventWeather.fromMap(result.data);
  }
}