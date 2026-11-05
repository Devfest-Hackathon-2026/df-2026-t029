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
  
  /// 保存前の入力チェック（問題があれば、その内容の一覧を返す）
  List<String> validate() {
    final errors = <String>[];
    if (performers.isEmpty) errors.add('出演者を入力してください');
    if (title.trim().isEmpty) errors.add('ライブ名を入力してください');
    for (final (i, p) in performances.indexed) {
      final label = '公演${i + 1}';
      if (p.startAt == null) errors.add('$label：開演日時を入力してください');
      if (p.venue.trim().isEmpty) errors.add('$label：会場名を入力してください');
    }
    for (final (i, r) in receptions.indexed) {
      final label = '受付${i + 1}';
      if (r.name.trim().isEmpty) errors.add('$label：表示名を入力してください');
      if (r.applyEndAt == null) errors.add('$label：申込期限を入力してください');
      if (r.prices.any((p) => p.seat.trim().isEmpty || p.amount == null)) {
        errors.add('$label：料金は席種と金額を両方入力してください');
      }
    }
    return errors;
  }
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
    List<PriceDraft>? prices,
    this.winnersOnly = false,
  }) : prices = prices ?? [];

  ReceptionType type;
  String name;
  DateTime? applyStartAt;
  DateTime? applyEndAt;
  DateTime? resultAt;
  DateTime? paymentDeadline;
  final List<PriceDraft> prices;
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
            PriceDraft(
              seat: (p as Map)['seat'] as String? ?? '',
              amount: (p['amount'] as num?)?.toInt(),
            ),
        ],
        winnersOnly: json['winnersOnly'] as bool? ?? false,
      );
}

class PriceDraft {
  PriceDraft({this.seat = '', this.amount});

  String seat;
  int? amount; // 円
}

/// ISO 8601 の文字列を、ブラウザの時刻（日本時間）の DateTime にする
DateTime? _parseDateTime(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;