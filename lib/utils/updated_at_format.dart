/// 更新日時の表示（「更新 」は呼び出し側で付ける）。
/// withTime: true → '11/9(月) 09:00'、false → '11/9(月)'。
/// now の年と同じなら年を省略。違う年は '2025/12/31(水) 09:00'。
String formatUpdatedAt(DateTime d, {DateTime? now, bool withTime = true}) {
  String two(int n) => n.toString().padLeft(2, '0');
  const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
  final base = now ?? DateTime.now();
  final year = d.year == base.year ? '' : '${d.year}/';
  final date = '$year${d.month}/${d.day}(${weekdays[d.weekday - 1]})';
  return withTime ? '$date ${two(d.hour)}:${two(d.minute)}' : date;
}
