import '../../models/live.dart';
import '../../models/performance.dart';
import '../../models/reception.dart';
import 'live_draft.dart';

/// 保存前に検査する長さ・個数の上限（計画書 3.1。ルールと同じ値）。
///
/// 文字数は `String.length`（UTF-16 単位。ルールの `size()` と同じ）で、
/// 前後の空白を除いた後の値で数える。
abstract final class LiveLimits {
  static const int maxTitleLength = 100;
  static const int maxVenueLength = 100;
  static const int maxPrefectureLength = 10;
  static const int maxReceptionNameLength = 50;
  static const int maxSeatLength = 50;
  static const int maxPricesPerReception = 10;
  static const int minAmount = 0;
  static const int maxAmount = 1000000;
  static const int minPerformances = 1;
  static const int maxPerformances = 50;
  static const int maxReceptions = 30;
  static const int maxUrlLength = 200;

  /// 出演グループ（groupIds）と個人名義の出演者（oshiIds）の、それぞれの上限
  static const int maxPerformersPerKind = 20;
}

/// 保存用のモデル（[LiveDraftToModels.toModels] の結果）
typedef LiveModels = ({
  Live live,
  List<Performance> performances,
  List<Reception> receptions,
});

extension LiveDraftToModels on LiveDraft {
  /// 長さ・個数の上限（[LiveLimits]）と URL の形を検査する。
  /// 問題があれば日本語のエラー文の一覧を返す（空なら保存できる）。
  ///
  /// `validate()`（必須項目の検査）とは別に呼ぶ。公演が0件のときも
  /// ここでエラーにする（計画書 3.1）。
  List<String> checkLimits() {
    final errors = <String>[];

    if (_len(title) > LiveLimits.maxTitleLength) {
      errors.add('ライブ名は${LiveLimits.maxTitleLength}文字以内で入力してください');
    }
    if (groupIds.length > LiveLimits.maxPerformersPerKind) {
      errors.add('出演グループは${LiveLimits.maxPerformersPerKind}件まで選べます');
    }
    if (oshiIds.length > LiveLimits.maxPerformersPerKind) {
      errors.add('個人の出演者は${LiveLimits.maxPerformersPerKind}人まで選べます');
    }
    final url = officialUrl.trim();
    if (url.isNotEmpty) {
      if (!_isHttpsUrl(url)) {
        errors.add('公式 URL は https:// で始まる URL を入力してください');
      } else if (url.length > LiveLimits.maxUrlLength) {
        errors.add('公式 URL は${LiveLimits.maxUrlLength}文字以内で入力してください');
      }
    }

    if (performances.length < LiveLimits.minPerformances) {
      errors.add('公演を${LiveLimits.minPerformances}件以上入力してください');
    } else if (performances.length > LiveLimits.maxPerformances) {
      errors.add('公演は${LiveLimits.maxPerformances}件までです');
    }
    for (final (i, p) in performances.indexed) {
      final label = '公演${i + 1}';
      if (_len(p.venue) > LiveLimits.maxVenueLength) {
        errors.add('$label：会場名は${LiveLimits.maxVenueLength}文字以内で入力してください');
      }
      if (_len(p.prefecture) > LiveLimits.maxPrefectureLength) {
        errors.add(
          '$label：都道府県は${LiveLimits.maxPrefectureLength}文字以内で入力してください',
        );
      }
    }

    if (receptions.length > LiveLimits.maxReceptions) {
      errors.add('受付は${LiveLimits.maxReceptions}件までです');
    }
    for (final (i, r) in receptions.indexed) {
      final label = '受付${i + 1}';
      if (_len(r.name) > LiveLimits.maxReceptionNameLength) {
        errors.add(
          '$label：表示名は${LiveLimits.maxReceptionNameLength}文字以内で入力してください',
        );
      }
      if (r.prices.length > LiveLimits.maxPricesPerReception) {
        errors.add('$label：席種は${LiveLimits.maxPricesPerReception}個までです');
      }
      if (r.prices.any((p) => _len(p.seat) > LiveLimits.maxSeatLength)) {
        errors.add('$label：席種は${LiveLimits.maxSeatLength}文字以内で入力してください');
      }
      if (r.prices.any(
        (p) =>
            p.amount != null &&
            (p.amount! < LiveLimits.minAmount ||
                p.amount! > LiveLimits.maxAmount),
      )) {
        errors.add(
          '$label：料金は${LiveLimits.minAmount}〜${formatYen(LiveLimits.maxAmount)}円で入力してください',
        );
      }
    }
    return errors;
  }

  /// 入力済みの LiveDraft を保存用のモデルに変える。
  /// `validate()` と [checkLimits] の両方が空のときだけ呼ぶ（そうでなければ
  /// `StateError`）。
  ///
  /// - 文字列は前後の空白を除く。空の任意項目（officialUrl・prefecture）は null
  /// - 席種と金額が空の料金行は、validate() で弾かれている前提
  /// - id・liveId は null、groupIds・oshiIds は Live にだけ入れる
  ///   （公演・受付への複製はリポジトリの create が行う）
  LiveModels toModels() {
    final errors = [...validate(), ...checkLimits()];
    if (errors.isNotEmpty) {
      throw StateError('保存できない入力があります: ${errors.join('、')}');
    }
    return (
      live: Live(
        title: title.trim(),
        groupIds: List.unmodifiable(groupIds),
        oshiIds: List.unmodifiable(oshiIds),
        officialUrl: _nullIfEmpty(officialUrl),
      ),
      performances: [
        for (final p in performances)
          Performance(
            startAt: p.startAt!,
            openAt: p.openAt,
            venue: p.venue.trim(),
            prefecture: _nullIfEmpty(p.prefecture),
          ),
      ],
      receptions: [
        for (final r in receptions)
          Reception(
            type: r.type,
            name: r.name.trim(),
            applyStartAt: r.applyStartAt,
            applyEndAt: r.applyEndAt!,
            resultAt: r.resultAt,
            paymentDeadline: r.paymentDeadline,
            prices: [
              for (final p in r.prices)
                Price(seat: p.seat.trim(), amount: p.amount!),
            ],
            winnersOnly: r.winnersOnly,
          ),
      ],
    );
  }
}

/// 前後の空白を除いた文字数（UTF-16 単位。ルールの `size()` と同じ）
int _len(String s) => s.trim().length;

String? _nullIfEmpty(String s) {
  final t = s.trim();
  return t.isEmpty ? null : t;
}

/// ルールの `^https://\S+$` と同じ形か（空白を含まず、ホスト名がある）
bool _isHttpsUrl(String url) {
  if (!url.startsWith('https://') || url.contains(RegExp(r'\s'))) {
    return false;
  }
  final uri = Uri.tryParse(url);
  return uri != null && uri.host.isNotEmpty;
}

/// 金額を3桁ごとのカンマ区切りにする（9800 → "9,800"、1000000 → "1,000,000"）。
/// 「円」は付けない。負の数は "-1,000" のようになる
String formatYen(int amount) => amount.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);
