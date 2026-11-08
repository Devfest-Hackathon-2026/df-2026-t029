import 'package:flutter/material.dart';
import '../../models/performance.dart';

/// 日時の入力欄（タップで日付→時刻の順に選ぶ。× で未設定に戻す）
class DateTimeField extends StatelessWidget {
  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.initialDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  /// 未設定のときに最初に開く日付（省略すると今日。add_E 3章）
  final DateTime? initialDate;

  Future<void> _pick(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: value ?? initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: value != null
          ? TimeOfDay.fromDateTime(value!)
          : const TimeOfDay(hour: 18, minute: 0),
    );
    if (time == null) return;
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: v == null
              ? const Icon(Icons.calendar_today_outlined)
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(v == null ? '未設定' : formatDateTime(v)),
      ),
    );
  }
}

/// 例：2026/11/23(月) 18:00
String formatDateTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
  return '${d.year}/${d.month}/${d.day}(${weekdays[d.weekday - 1]}) '
      '${two(d.hour)}:${two(d.minute)}';
}


/// 日付だけ（例：2026/11/23(月)）
String formatDateOnly(DateTime d) {
  const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
  return '${d.year}/${d.month}/${d.day}(${weekdays[d.weekday - 1]})';
}

/// 公演の開演。時間未定なら「2026/11/23(月) 時間未定」（add_L L-4c-2）
String formatPerformanceStart(Performance p) => p.startTimeUnknown
    ? '${formatDateOnly(p.startAt)} 時間未定'
    : formatDateTime(p.startAt);