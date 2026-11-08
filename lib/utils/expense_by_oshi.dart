import '../models/live.dart';
import '../models/oshi.dart';
import 'expense_summary.dart';

/// 推し1人（1グループ）の出費の合計
typedef OshiExpense = ({OshiSummary oshi, int amount});

/// 推しごとの推し活費（add_O 3.4）
class ExpenseByOshi {
  const ExpenseByOshi({required this.byOshi, required this.unassigned});

  /// フォロー中の推しごとの合計（多い順。0 円の推しは入れない）
  final List<OshiExpense> byOshi;

  /// ライブに結び付かない・フォロー中の推しのいないライブの出費の合計
  final int unassigned;

  bool get isEmpty => byOshi.isEmpty && unassigned == 0;
}

/// [items]（ふつうは1か月分）を推しごとに振り分ける。
/// 複数の推しのライブの出費は、それぞれの推しに入れる
ExpenseByOshi summarizeByOshi(
  List<ExpenseItem> items,
  List<Live> lives,
  List<OshiSummary> following,
) {
  final livesById = {for (final l in lives) ?l.id: l};
  final totals = <OshiSummary, int>{};
  var unassigned = 0;
  for (final item in items) {
    final live = livesById[item.liveId];
    final hits = live == null
        ? const <OshiSummary>[]
        : [
            for (final o in following)
              if (o.kind == OshiKind.person
                  ? live.oshiIds.contains(o.id)
                  : live.groupIds.contains(o.id))
                o,
          ];
    if (hits.isEmpty) {
      unassigned += item.amount;
      continue;
    }
    for (final o in hits) {
      totals[o] = (totals[o] ?? 0) + item.amount;
    }
  }
  final byOshi = [
    for (final e in totals.entries)
      if (e.value > 0) (oshi: e.key, amount: e.value),
  ]..sort((a, b) => b.amount.compareTo(a.amount));
  return ExpenseByOshi(byOshi: byOshi, unassigned: unassigned);
}