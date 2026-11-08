import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/performance.dart';
import '../../models/trip.dart';
import '../../providers/oshi_providers.dart';
import '../../providers/trip_providers.dart';
import '../live_form/date_time_field.dart';
import '../live_form/live_draft_to_models.dart' show formatYen;

/// 遠征メモの1行の要約（例：「遠征：新幹線・宿あり　計 ¥32,000」）
String tripSummary(Trip trip) {
  final parts = [
    if (trip.transport != null) trip.transport!.label,
    if (trip.hasHotel) '宿あり',
  ];
  final head = parts.isEmpty ? '遠征メモあり' : '遠征：${parts.join('・')}';
  return trip.hasCost ? '$head　計 ¥${formatYen(trip.totalCost)}' : head;
}

/// 例：11/9(月) 8:30
String formatShortDateTime(DateTime d) {
  const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
  final minute = d.minute.toString().padLeft(2, '0');
  return '${d.month}/${d.day}(${weekdays[d.weekday - 1]}) ${d.hour}:$minute';
}

/// 遠征メモの時刻の1行（add_E 3章）。
/// 例：「行き 11/9(月) 8:30 発 ／ 帰り 11/9(月) 22:10 発 ／ チェックイン 11/9(月) 15:00」。
/// 時刻が1つも無ければ null
String? tripTimesLine(Trip trip) {
  final parts = [
    if (trip.departAt case final d?) '行き ${formatShortDateTime(d)} 発',
    if (trip.returnAt case final d?) '帰り ${formatShortDateTime(d)} 発',
    if (trip.checkInAt case final d?) 'チェックイン ${formatShortDateTime(d)}',
  ];
  return parts.isEmpty ? null : parts.join(' ／ ');
}

/// 遠征メモの入力シート（E-2・add_E 3章）。記録があれば、その値を入れて開く
Future<void> showTripSheet(
  BuildContext context, {
  required Performance performance,
  required String liveTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (_) => _TripSheet(performance: performance, liveTitle: liveTitle),
  );
}

class _TripSheet extends ConsumerStatefulWidget {
  const _TripSheet({required this.performance, required this.liveTitle});

  final Performance performance;
  final String liveTitle;

  @override
  ConsumerState<_TripSheet> createState() => _TripSheetState();
}

class _TripSheetState extends ConsumerState<_TripSheet> {
  /// 開いたときの記録（無ければ null）
  late final Trip? _existing =
      ref.read(myTripsProvider).value?[widget.performance.id];

  late TravelTransport? _transport = _existing?.transport;
  late DateTime? _departAt = _existing?.departAt;
  late DateTime? _returnAt = _existing?.returnAt;
  late DateTime? _checkInAt = _existing?.checkInAt;
  late final _transportCost = TextEditingController(
    text: _existing?.transportCost?.toString() ?? '',
  );
  late final _hotelName = TextEditingController(
    text: _existing?.hotelName ?? '',
  );
  late final _hotelCost = TextEditingController(
    text: _existing?.hotelCost?.toString() ?? '',
  );
  late final _localNote = TextEditingController(
    text: _existing?.localNote ?? '',
  );
  late final _note = TextEditingController(text: _existing?.note ?? '');

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _transportCost.dispose();
    _hotelName.dispose();
    _hotelCost.dispose();
    _localNote.dispose();
    _note.dispose();
    super.dispose();
  }

  /// 金額の欄を読む。空なら null、上限を超えたら例外
  int? _cost(TextEditingController c, String label) {
    final text = c.text.trim();
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    if (value == null || value < 0 || value > Trip.maxCost) {
      throw FormatException('$labelは0〜${formatYen(Trip.maxCost)}円で入力してください');
    }
    return value;
  }

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    final p = widget.performance;
    if (uid == null || p.id == null || p.liveId == null) return;
    final Trip trip;
    try {
      trip = Trip(
        performanceId: p.id!,
        liveId: p.liveId!,
        liveTitle: widget.liveTitle,
        startAt: p.startAt,
        venue: p.venue,
        transport: _transport,
        departAt: _departAt,
        returnAt: _returnAt,
        transportCost: _cost(_transportCost, '交通費'),
        hotelName: _hotelName.text.trim(),
        checkInAt: _checkInAt,
        hotelCost: _cost(_hotelCost, '宿代'),
        localNote: _localNote.text.trim(),
        note: _note.text.trim(),
        createdAt: _existing?.createdAt,
      );
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(tripRepositoryProvider).save(uid, trip);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存できませんでした: $e';
        });
      }
    }
  }

  Future<void> _delete() async {
    final uid = ref.read(currentUidProvider);
    final id = widget.performance.id;
    if (uid == null || id == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(tripRepositoryProvider).delete(uid, id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '削除できませんでした: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.performance;
    // 金額は数字だけ入力できるようにする
    final digitsOnly = [FilteringTextInputFormatter.digitsOnly];
    // 日時を最初に選ぶときは、公演の日を開く
    final day = DateTime(p.startAt.year, p.startAt.month, p.startAt.day);

    return Padding(
      key: const Key('trip_sheet'),
      // キーボードで欄が隠れないようにする
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('遠征メモ', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${widget.liveTitle}\n${p.venue}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text('交通手段', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in TravelTransport.values)
                  ChoiceChip(
                    key: Key('trip_transport_${t.code}'),
                    label: Text(t.label),
                    selected: _transport == t,
                    // もう一度押すと選択を外す
                    onSelected: _saving
                        ? null
                        : (on) => setState(() => _transport = on ? t : null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DateTimeField(
              key: const Key('trip_depart_field'),
              label: '行きの出発',
              value: _departAt,
              initialDate: day,
              onChanged: (v) => setState(() => _departAt = v),
            ),
            const SizedBox(height: 8),
            DateTimeField(
              key: const Key('trip_return_field'),
              label: '帰りの出発（終電など）',
              value: _returnAt,
              initialDate: day,
              onChanged: (v) => setState(() => _returnAt = v),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('trip_transport_cost_field'),
              controller: _transportCost,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: digitsOnly,
              decoration: const InputDecoration(
                labelText: '交通費（往復の合計）',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('trip_hotel_name_field'),
              controller: _hotelName,
              enabled: !_saving,
              maxLength: Trip.maxHotelNameLength,
              decoration: const InputDecoration(
                labelText: '宿の名前',
                border: OutlineInputBorder(),
              ),
            ),
            DateTimeField(
              key: const Key('trip_check_in_field'),
              label: 'チェックイン',
              value: _checkInAt,
              initialDate: day,
              onChanged: (v) => setState(() => _checkInAt = v),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('trip_hotel_cost_field'),
              controller: _hotelCost,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: digitsOnly,
              decoration: const InputDecoration(
                labelText: '宿代',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('trip_local_note_field'),
              controller: _localNote,
              enabled: !_saving,
              maxLength: Trip.maxLocalNoteLength,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '現地メモ（コインロッカー・食事・グッズ列の時間など）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('trip_note_field'),
              controller: _note,
              enabled: !_saving,
              maxLength: Trip.maxNoteLength,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'メモ（集合時間、持ち物など）',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('trip_save_button'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存'),
            ),
            if (_existing != null) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('trip_delete_button'),
                onPressed: _saving ? null : _delete,
                child: const Text('この遠征メモを削除'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}