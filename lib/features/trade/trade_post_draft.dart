import '../../models/oshi.dart';
import '../../models/performance.dart';
import '../../models/trade_post.dart';

/// 投稿者の表示名。ハンドルネームの仕組みができるまでは、全員この名前で投稿する
/// （セキュリティルールで1文字以上が必須のため、空欄にはしない）
const String anonymousDisplayName = '匿名';

/// 作成・編集画面で入力中の投稿（G-2-4 の項目。譲・求のセットは G-2-5）
class TradePostDraft {
  TradePostDraft({
    List<String>? groupIds,
    List<String>? oshiIds,
    Set<TradeTag>? tags,
    this.priceType,
    Set<HandoverMethod>? handover,
    List<String>? performanceIds,
    this.xAccount = '',
    this.note = '',
  }) : groupIds = groupIds ?? [],
       oshiIds = oshiIds ?? [],
       tags = tags ?? {},
       handover = handover ?? {},
       performanceIds = performanceIds ?? [];

  /// 保存済みの投稿から、編集用に作る
  factory TradePostDraft.fromPost(TradePost p) => TradePostDraft(
    groupIds: [...p.groupIds],
    oshiIds: [...p.oshiIds],
    tags: {...p.tags},
    priceType: p.priceType,
    handover: {...p.handover},
    performanceIds: [...p.performanceIds],
    xAccount: p.xAccount ?? '',
    note: p.note ?? '',
  );

  // 上限はセキュリティルールと同じ
  static const int maxTargets = 20; // groupIds・oshiIds のそれぞれ
  static const int maxPerformances = 20;
  static const int maxNoteLength = 1000;

  final List<String> groupIds;
  final List<String> oshiIds;
  final Set<TradeTag> tags;
  PriceType? priceType;
  final Set<HandoverMethod> handover;

  /// 手渡しの公演の ID（選んだ順）
  final List<String> performanceIds;

  /// 入力のまま（先頭の @ や前後の空白は [cleanedXAccount] で除く）
  String xAccount;
  String note;

  bool get hasPrice =>
      tags.contains(TradeTag.sell) || tags.contains(TradeTag.buy);
  bool get isHand => handover.contains(HandoverMethod.hand);

  /// 推しを選んでいるか
  bool isTarget(OshiSummary o) => switch (o.kind) {
    OshiKind.group => groupIds.contains(o.id),
    OshiKind.person => oshiIds.contains(o.id),
  };

  /// 推しの選択を切り替える。上限を超えるときは何もせず false を返す
  bool toggleTarget(OshiSummary o) {
    final list = o.kind == OshiKind.group ? groupIds : oshiIds;
    if (list.remove(o.id)) return true;
    if (list.length >= maxTargets) return false;
    list.add(o.id);
    return true;
  }

  /// 公演の選択を切り替える。上限を超えるときは何もせず false を返す
  bool togglePerformance(String id) {
    if (performanceIds.remove(id)) return true;
    if (performanceIds.length >= maxPerformances) return false;
    performanceIds.add(id);
    return true;
  }

  String? get cleanedXAccount {
    final x = xAccount.trim().replaceFirst(RegExp('^[@＠]'), '');
    return x.isEmpty ? null : x;
  }

  String? get cleanedNote {
    final n = note.trim();
    return n.isEmpty ? null : n;
  }

  /// 入力を検査し、エラー文の一覧を返す（空なら保存できる）
  List<String> validate() {
    final errors = <String>[];
    if (groupIds.isEmpty && oshiIds.isEmpty) {
      errors.add('対象の推しを1つ以上選んでください');
    }
    if (tags.isEmpty) {
      errors.add('取引のタグを1つ以上選んでください');
    }
    if (hasPrice && priceType == null) {
      errors.add('譲渡・買取希望の価格（定価／定価以下）を選んでください');
    }
    if (handover.isEmpty) {
      errors.add('受け渡し方法を1つ以上選んでください');
    }
    final x = cleanedXAccount;
    if (x != null && !RegExp(r'^[A-Za-z0-9_]{1,15}$').hasMatch(x)) {
      errors.add('X アカウントは英数字と _ の15文字以内で入力してください（@ は不要）');
    }
    if ((cleanedNote?.length ?? 0) > maxNoteLength) {
      errors.add('備考は$maxNoteLength文字以内で入力してください');
    }
    return errors;
  }

  /// 保存用のモデルに変換する（[validate] の結果が空のときだけ呼ぶ）。
  ///
  /// 編集のときは [base] を渡す。ID・譲・求・写真は [base] のまま引き継ぐ。
  /// 価格の区分は譲渡・買取希望のときだけ、公演は手渡しのときだけ残す
  TradePost toPost({TradePost? base}) => TradePost(
    id: base?.id,
    groupIds: [...groupIds],
    oshiIds: [...oshiIds],
    // 表示の順をそろえる
    tags: [
      for (final t in TradeTag.values)
        if (tags.contains(t)) t,
    ],
    priceType: hasPrice ? priceType : null,
    gives: base?.gives ?? const [],
    wants: base?.wants ?? const [],
    handover: [
      for (final h in HandoverMethod.values)
        if (handover.contains(h)) h,
    ],
    performanceIds: isHand ? [...performanceIds] : const [],
    xAccount: cleanedXAccount,
    note: cleanedNote,
    images: base?.images ?? const [],
  );
}

/// 手渡しの公演の候補（開演の早い順）。
///
/// 対象の推しの、開演が [now] 以降の公演。個人なら本人名義の公演と、
/// 所属グループの公演を含む。[selectedIds] にある公演は、過去でも残す
/// （編集時に、選んでいた公演が黙って消えないようにする）。
List<Performance> handoverPerformanceCandidates({
  required List<Performance> performances,
  required List<String> groupIds,
  required List<String> oshiIds,
  required List<OshiSummary> all,
  required DateTime now,
  List<String> selectedIds = const [],
}) {
  final groups = {
    ...groupIds,
    for (final o in all)
      if (o.kind == OshiKind.person && oshiIds.contains(o.id)) ...o.groupIds,
  };
  final result = [
    for (final p in performances)
      if (p.id != null &&
          (selectedIds.contains(p.id) ||
              (!p.startAt.isBefore(now) &&
                  (p.groupIds.any(groups.contains) ||
                      p.oshiIds.any(oshiIds.contains)))))
        p,
  ]..sort((a, b) => a.startAt.compareTo(b.startAt));
  return result;
}
