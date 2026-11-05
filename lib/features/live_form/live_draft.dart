import '../../models/converters.dart';
import '../../models/reception.dart';
import '../../models/oshi.dart';
import '../../utils/oshi_search.dart';
import '../../models/live.dart';
import '../../models/performance.dart';

/// 確認・修正画面で編集する、保存前のライブ情報
class LiveDraft {
  LiveDraft({
    this.title = '',
    this.officialUrl = '',
    List<String>? performers,
    List<OshiSummary>? selectedPerformers,
    List<PerformanceDraft>? performances,
    List<ReceptionDraft>? receptions,
  })  : performers = performers ?? [],
        selectedPerformers = selectedPerformers ?? [],
        performances = performances ?? [],
        receptions = receptions ?? [];

  String title;
  String officialUrl;

  /// 読み取った出演者名（対応付けの手がかり。保存はしない）
  final List<String> performers;

  /// 選んだ出演者（保存するのはこちら）
  final List<OshiSummary> selectedPerformers;

  final List<PerformanceDraft> performances;
  final List<ReceptionDraft> receptions;

  /// 出演グループの ID（lives.groupIds）
  List<String> get groupIds => [
        for (final o in selectedPerformers)
          if (o.kind == OshiKind.group) o.id,
      ];

  /// 個人名義で出演する推しの ID（lives.oshiIds）
  List<String> get oshiIds => [
        for (final o in selectedPerformers)
          if (o.kind == OshiKind.person) o.id,
      ];

  /// 出演者を追加する（すでに選んでいれば何もしない）
  void addPerformer(OshiSummary oshi) {
    if (selectedPerformers.every((o) => o.key != oshi.key)) {
      selectedPerformers.add(oshi);
    }
  }

  /// 読み取った出演者名と完全一致する承認済みの推しを、自動で選ぶ。
  /// 候補が1件に絞れなかった名前を返す。
  List<String> autoMatchPerformers(List<OshiSummary> all) {
    final unmatched = <String>[];
    for (final name in performers) {
      final candidates = [
        for (final kind in OshiKind.values)
          ...findExactDuplicates(all, kind: kind, name: name),
      ].where((o) => o.isApproved).toList();
      if (candidates.length == 1) {
        addPerformer(candidates.single);
      } else {
        unmatched.add(name);
      }
    }
    return unmatched;
  }

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
    if (selectedPerformers.isEmpty) errors.add('出演者を選んでください');
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

  /// 保存用のモデルに変換する（[validate] の結果が空のときだけ呼ぶ）
  (Live, List<Performance>, List<Reception>) toModels() {
    String? orNull(String s) => s.trim().isEmpty ? null : s.trim();

    return (
      Live(
        title: title.trim(),
        groupIds: groupIds,
        oshiIds: oshiIds,
        officialUrl: orNull(officialUrl),
      ),
      [
        for (final p in performances)
          Performance(
            startAt: p.startAt!,
            openAt: p.openAt,
            venue: p.venue.trim(),
            prefecture: orNull(p.prefecture),
          ),
      ],
      [
        for (final r in receptions)
          Reception(
            type: r.type,
            name: r.name.trim(),
            applyStartAt: r.applyStartAt,
            applyEndAt: r.applyEndAt!,
            resultAt: r.resultAt,
            paymentDeadline: r.paymentDeadline,
            prices: [
              for (final price in r.prices)
                Price(seat: price.seat.trim(), amount: price.amount!),
            ],
            winnersOnly: r.winnersOnly,
          ),
      ],
    );
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