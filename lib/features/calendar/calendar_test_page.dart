import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/google_calendar_service.dart';
import '../../services/calendar_events.dart';

class CalendarTestPage extends ConsumerStatefulWidget {
  const CalendarTestPage({super.key});

  @override
  ConsumerState<CalendarTestPage> createState() => _CalendarTestPageState();
}

class _CalendarTestPageState extends ConsumerState<CalendarTestPage> {
  String _result = '';
  bool _loading = false;

  Future<void> _test() async {
    setState(() => _loading = true);
    try {
      final titles =
          await ref.read(googleCalendarServiceProvider).upcomingEventTitles();
      if (!mounted) return;
      setState(() => _result =
          titles.isEmpty ? 'これからの予定はありません' : titles.join('\n'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = 'エラー: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addTest() async {
    setState(() => _loading = true);
    try {
      final start = DateTime.now().add(const Duration(days: 1));
      await ref.read(googleCalendarServiceProvider).upsertEvents([
        CalendarEvent(
          sourceId: 'test',
          kind: CalendarEventKind.performance,
          title: '【公演】おしあし テスト予定',
          start: start,
          end: start.add(const Duration(hours: 3)),
          location: 'テスト会場',
          description: '接続テスト用の予定です。確認後に削除してください',
          reminderMinutes: const [1440, 180],
        ),
      ]);
      if (!mounted) return;
      setState(() => _result = 'テスト予定を追加しました（明日のこの時刻）');
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = 'エラー: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('カレンダー接続テスト')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton(
              onPressed: _loading ? null : _test,
              child: const Text('自分の予定を読む'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loading ? null : _addTest,
              child: const Text('テスト予定を追加'),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const CircularProgressIndicator()
            else
              SelectableText(_result),
          ],
        ),
      ),
    );
  }
}