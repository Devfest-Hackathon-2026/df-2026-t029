import '../../models/converters.dart';
import '../../models/reception.dart';

/// 確認・修正画面で編集する、保存前のライブ情報
class LiveDraft {
  LiveDraft({
    this.title = '',
    this.officialUrl = '',
    List<String>? performers,
    List<PerformanceDraft>? performances,
    List<ReceptionDraft>? receptions,
  })  : performers = performers ?? [],
        performances = performances ?? [],
        receptions = receptions ?? [];

  String title;
  String officialUrl;
  List<String> performers; // 出演者名（推しの ID との対応付けは Step 4）
  final List<PerformanceDraft> performances;
  final List<ReceptionDraft> receptions;

  /// Gemini の抽出結果（JSON）から作る
  factory LiveDraft.fromGemini(Map<String, dynamic> json) => LiveDraft(
        title: json['liveTitle'] as String? ?? '',
        officialUrl: json['officialUrl'] as String? ?? '',
        performers: toStringList(json['performers']),
        performances: [
          for (final p in json['performances'] as List? ?? const [])
            PerformanceDraft.fromGemini(p as Map<String, dynamic>),
        ],
        receptions: [
          for (final r in json['receptions'] as List? ?? const [])
            ReceptionDraft.fromGemini(r as Map<String, dynamic>),
        ],
      );
}

class PerformanceDraft {
  PerformanceDraft({
    this.startAt,
    this.openAt,
    this.venue = '',
    this.prefecture = '',
  });

  DateTime? startAt;
  DateTime? openAt;
  String venue;
  String prefecture;

  factory PerformanceDraft.fromGemini(Map<String, dynamic> json) =>
      PerformanceDraft(
        startAt: _parseDateTime(json['startAt']),
        openAt: _parseDateTime(json['openAt']),
        venue: json['venue'] as String? ?? '',
        prefecture: json['prefecture'] as String? ?? '',
      );
}

class ReceptionDraft {
  ReceptionDraft({
    this.type = ReceptionType.other,
    this.name = '',
    this.applyStartAt,
    this.applyEndAt,
    this.resultAt,
    this.paymentDeadline,
    List<Price>? prices,
    this.winnersOnly = false,
  }) : prices = prices ?? [];

  ReceptionType type;
  String name;
  DateTime? applyStartAt;
  DateTime? applyEndAt;
  DateTime? resultAt;
  DateTime? paymentDeadline;
  final List<Price> prices;
  bool winnersOnly;

  factory ReceptionDraft.fromGemini(Map<String, dynamic> json) =>
      ReceptionDraft(
        type: ReceptionType.values.asNameMap()[json['type']] ??
            ReceptionType.other,
        name: json['name'] as String? ?? '',
        applyStartAt: _parseDateTime(json['applyStartAt']),
        applyEndAt: _parseDateTime(json['applyEndAt']),
        resultAt: _parseDateTime(json['resultAt']),
        paymentDeadline: _parseDateTime(json['paymentDeadline']),
        prices: [
          for (final p in json['prices'] as List? ?? const [])
            Price.fromMap(p as Map<String, dynamic>),
        ],
        winnersOnly: json['winnersOnly'] as bool? ?? false,
      );
}

/// ISO 8601 の文字列を、ブラウザの時刻（日本時間）の DateTime にする
DateTime? _parseDateTime(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;