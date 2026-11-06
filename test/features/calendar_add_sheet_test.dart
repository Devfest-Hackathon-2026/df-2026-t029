import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/calendar/calendar_add_sheet.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/services/calendar_events.dart';

CalendarEvent ev(String id, String title, {bool winnersOnly = false}) =>
    CalendarEvent(
      sourceId: id,
      kind: CalendarEventKind.applyEnd,
      title: title,
      start: DateTime(2026, 11, 10, 12),
      end: DateTime(2026, 11, 10, 12, 30),
      winnersOnly: winnersOnly,
    );

Future<void> openSheet(
  WidgetTester tester, {
  required AsyncValue<Set<String>> winners,
  String? liveId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [winnerLiveIdsProvider.overrideWithValue(winners)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCalendarAddSheet(context, [
              ev('a', '通常の締切'),
              ev('b', '当選者のみの締切', winnersOnly: true),
            ], liveId: liveId),
            child: const Text('開く'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('開く'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('当選しているライブなら、当選者のみの予定も出る', (tester) async {
    await openSheet(tester, winners: const AsyncData({'l1'}), liveId: 'l1');
    expect(find.text('通常の締切'), findsOneWidget);
    expect(find.text('当選者のみの締切'), findsOneWidget);
  });

  testWidgets('当選していないライブでは、当選者のみの予定は出ない', (tester) async {
    await openSheet(tester, winners: const AsyncData({'l2'}), liveId: 'l1');
    expect(find.text('通常の締切'), findsOneWidget);
    expect(find.text('当選者のみの締切'), findsNothing);
  });

  testWidgets('liveId が無ければ、当選者のみの予定は出ない', (tester) async {
    await openSheet(tester, winners: const AsyncData({'l1'}));
    expect(find.text('当選者のみの締切'), findsNothing);
  });

  testWidgets('当選者のみの予定には「当選者のみ対象」のラベルが付く', (tester) async {
    await openSheet(tester, winners: const AsyncData({'l1'}), liveId: 'l1');
    expect(find.textContaining('当選者のみ対象'), findsOneWidget);
  });

  testWidgets('申込状況が読み込み中・エラーのあいだは出さない', (tester) async {
    await openSheet(tester, winners: const AsyncLoading(), liveId: 'l1');
    expect(find.text('当選者のみの締切'), findsNothing);
  });
}
