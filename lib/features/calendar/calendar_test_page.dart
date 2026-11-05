import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/google_calendar_service.dart';

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