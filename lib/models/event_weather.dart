/// 公演の日の天気（Cloud Functions の getEventWeather の結果。add_E 5.2）
class EventWeather {
  const EventWeather({
    required this.status,
    this.type,
    this.text,
    this.maxC,
    this.minC,
    this.rainPercent,
  });

  /// `ok`・`outOfRange`（10日より先・過去）・`unknownPlace`（都道府県が分からない）
  final String status;

  /// 天気の種類（`CLEAR`・`CLOUDY`・`RAIN` など）
  final String? type;

  /// 天気の説明（日本語）
  final String? text;
  final int? maxC;
  final int? minC;

  /// 昼の降水確率（%）
  final int? rainPercent;

  bool get isAvailable => status == 'ok';

  factory EventWeather.fromMap(Map<Object?, Object?> map) {
    int? toInt(Object? v) => (v as num?)?.toInt();
    return EventWeather(
      status: map['status'] as String? ?? 'unknownPlace',
      type: map['type'] as String?,
      text: map['text'] as String?,
      maxC: toInt(map['maxC']),
      minC: toInt(map['minC']),
      rainPercent: toInt(map['rainPercent']),
    );
  }
}