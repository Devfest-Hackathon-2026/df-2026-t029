import '../models/application.dart';
import '../models/expense.dart';
import '../models/live.dart';
import '../models/reception.dart';
import '../models/trip.dart';

/// 出費がどこから来たか
enum ExpenseSource {
  /// 当選・入金済の受付（自動）
  ticket,

  /// 遠征メモ（自動）
  trip,

  /// 手入力
  manual,
}

/// 費用管理に出す出費1件（H-1）
class ExpenseItem {
  const ExpenseItem({
    required this.source,
    required this.sourceId,
    required this.category,
    required this.title,
    required this.amount,
    required this.date,
    this.liveTitle,
    this.liveId,
    this.detail,
    this.amountUnset = false,
  });

  final ExpenseSource source;

  /// 元の ID（チケットは受付の ID、遠征は公演の ID、手入力は出費の ID）
  final String sourceId;
  final ExpenseCategory category;
  final String title;

  /// 金額（円）
  final int amount;

  /// どの月の出費かを決める日
  final DateTime date;
  final String? liveTitle;

  /// ライブの ID（推しごとの集計に使う。add_O 3.4）。ライブに結び付かなければ null
  final String? liveId;

  /// 補足（例：「S席 × 2枚」「新幹線・宿あり」）
  final String? detail;

  /// 受付に料金が無く、金額がわからないチケット
  final bool amountUnset;
}

/// 1か月分のまとめ
class MonthSummary {
  const MonthSummary({
    required this.year,
    required this.month,
    required this.items,
    required this.total,
    required this.byCategory,
  });

  final int year;
  final int month;

  /// その月の出費（日付の新しい順）
  final List<ExpenseItem> items;
  final int total;

  /// 種類ごとの合計（すべての種類を [ExpenseCategory.values] の順に持つ。無ければ 0）
  final Map<ExpenseCategory, int> byCategory;
}

/// 出費を全件作る（仕様書 4.1）。
///
/// - チケット：申込状況が当選・入金済の受付。金額はチケット代の設定があればそれ、
///   なければ受付の料金の最初の席種 × 1枚（料金が無ければ 0 円で「金額未設定」）。
///   日は入金期限 → 当落発表 → 申込期限
/// - 遠征：交通費か宿代が入っている遠征メモ。金額はその合計、日は開演日
/// - 手入力：入力したとおり
List<ExpenseItem> buildExpenseItems({
  required List<Reception> receptions,
  required Map<String, Application> applications,
  required List<Live> lives,
  required Map<String, TicketCost> ticketCosts,
  required Map<String, Trip> trips,
  required List<Expense> expenses,
}) {
  final titles = {
    for (final l in lives)
      if (l.id != null) l.id!: l.title,
  };
  final items = <ExpenseItem>[];

  for (final r in receptions) {
    final id = r.id;
    if (id == null) continue;
    final status = applications[id]?.status;
    if (status != ApplicationStatus.won && status != ApplicationStatus.paid) {
      continue;
    }
    final cost = ticketCosts[id];
    final first = r.prices.firstOrNull;
    final (amount, detail, unset) = switch ((cost, first)) {
      (final c?, _) => (c.amount, '${c.seat} × ${c.count}枚', false),
      (null, final p?) => (p.amount, '${p.seat} × 1枚', false),
      (null, null) => (0, null, true),
    };
    items.add(
      ExpenseItem(
        source: ExpenseSource.ticket,
        sourceId: id,
        category: ExpenseCategory.ticket,
        title: r.name,
        amount: amount,
        date: r.paymentDeadline ?? r.resultAt ?? r.applyEndAt,
        liveTitle: titles[r.liveId],
        liveId: r.liveId,
        detail: detail,
        amountUnset: unset,
      ),
    );
  }

  for (final t in trips.values) {
    if (!t.hasCost) continue;
    final parts = [
      if (t.transport != null) t.transport!.label,
      if (t.hasHotel) '宿あり',
    ];
    items.add(
      ExpenseItem(
        source: ExpenseSource.trip,
        sourceId: t.performanceId,
        category: ExpenseCategory.travel,
        // 種類の「遠征」と重ならないように、会場名だけにする
        title: t.venue,
        amount: t.totalCost,
        date: t.startAt,
        liveTitle: t.liveTitle,
        liveId: t.liveId.isEmpty ? null : t.liveId,
        detail: parts.isEmpty ? null : parts.join('・'),
      ),
    );
  }

  for (final e in expenses) {
    if (e.id == null) continue;
    items.add(
      ExpenseItem(
        source: ExpenseSource.manual,
        sourceId: e.id!,
        category: e.category,
        title: e.title,
        amount: e.amount,
        date: e.date,
        liveTitle: e.liveTitle,
        liveId: e.liveId,
      ),
    );
  }
  return items;
}

/// [year] 年 [month] 月の出費をまとめる（日付の新しい順）
MonthSummary summarizeMonth(List<ExpenseItem> items, int year, int month) {
  final inMonth = [
    for (final i in items)
      if (i.date.year == year && i.date.month == month) i,
  ]..sort((a, b) => b.date.compareTo(a.date));
  final byCategory = {for (final c in ExpenseCategory.values) c: 0};
  var total = 0;
  for (final i in inMonth) {
    byCategory[i.category] = byCategory[i.category]! + i.amount;
    total += i.amount;
  }
  return MonthSummary(
    year: year,
    month: month,
    items: inMonth,
    total: total,
    byCategory: byCategory,
  );
}