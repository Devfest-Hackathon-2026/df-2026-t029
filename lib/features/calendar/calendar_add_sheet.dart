import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/live_providers.dart';
import '../../services/calendar_events.dart';
import '../../services/google_calendar_service.dart';
import '../live_form/date_time_field.dart';

/// 予定を選んで Google カレンダーに追加するシート。追加したら true を返す
Future<bool> showCalendarAddSheet(
  BuildContext context,
  List<CalendarEvent> events, {
  String? liveId,
}) async {
  final added = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CalendarAddSheet(events: events, liveId: liveId),
  );
  return added ?? false;
}

class _CalendarAddSheet extends ConsumerStatefulWidget {
  const _CalendarAddSheet({required this.events, this.liveId});

  final List<CalendarEvent> events;

  /// 予定のライブの ID。当選者のみの受付の予定を出すかどうかの判定に使う。
  /// 無いときは、当選者のみの予定は出さない
  final String? liveId;

  @override
  ConsumerState<_CalendarAddSheet> createState() => _CalendarAddSheetState();
}

class _CalendarAddSheetState extends ConsumerState<_CalendarAddSheet> {
  CalendarPreset _preset = CalendarPreset.compact;
  late Set<String> _selected = _selectionFor(_preset);
  bool _adding = false;
  String? _error;

  /// 出す予定。当選者のみの受付の予定は、当選者にだけ出す
  /// （申込状況が読み込み中・エラーのあいだは出さない）
  List<CalendarEvent> get _events {
    final liveId = widget.liveId;
    final isWinner =
        liveId != null &&
        (ref.watch(winnerLiveIdsProvider).value?.contains(liveId) ?? false);
    return [
      for (final e in widget.events)
        if (!e.winnersOnly || isWinner) e,
    ];
  }

  /// プリセットに含まれる種類の予定を選ぶ（当選者のみが対象の受付は外す）
  Set<String> _selectionFor(CalendarPreset preset) => {
        for (final e in widget.events)
          if (preset.kinds.contains(e.kind) && !e.winnersOnly) e.eventId,
      };

  /// 一覧に出す日時（期限は締切の時刻、それ以外は開始の時刻）
  DateTime _displayAt(CalendarEvent e) =>
      e.kind == CalendarEventKind.applyEnd || e.kind == CalendarEventKind.payment
          ? e.end
          : e.start;

  Future<void> _add() async {
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      await ref.read(googleCalendarServiceProvider).upsertEvents([
        for (final e in _events)
          if (_selected.contains(e.eventId)) e,
      ]);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _adding = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Google カレンダーにも追加しますか？',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SegmentedButton<CalendarPreset>(
                segments: [
                  for (final p in CalendarPreset.values)
                    ButtonSegment(value: p, label: Text(p.label)),
                ],
                selected: {_preset},
                onSelectionChanged: _adding
                    ? null
                    : (s) => setState(() {
                          _preset = s.first;
                          _selected = _selectionFor(_preset);
                        }),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (final e in _events)
                      CheckboxListTile(
                        value: _selected.contains(e.eventId),
                        onChanged: _adding
                            ? null
                            : (v) => setState(() {
                                  if (v ?? false) {
                                    _selected.add(e.eventId);
                                  } else {
                                    _selected.remove(e.eventId);
                                  }
                                }),
                        title: Text(e.title),
                        subtitle: Text([
                          formatDateTime(_displayAt(e)),
                          if (e.winnersOnly) '当選者のみ対象',
                        ].join('　')),
                      ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _adding
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('追加しない'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _adding || _selected.isEmpty ? null : _add,
                      child: _adding
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('${_selected.length}件を追加'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}