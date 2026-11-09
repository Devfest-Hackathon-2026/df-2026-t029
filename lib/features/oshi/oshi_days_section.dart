import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/oshi.dart';
import '../../models/oshi_days.dart';
import '../../providers/live_providers.dart';
import '../../providers/oshi_color_providers.dart';
import '../../providers/oshi_days_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../repositories/oshi_days_repository.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';

/// 推しのシートの「記念日」（推し始めた日・誕生日／結成日。add_O 3.1）。
/// 選んだらすぐ保存する（シートは閉じない）
class OshiDaysSection extends ConsumerStatefulWidget {
  const OshiDaysSection({super.key, required this.oshi});

  final OshiSummary oshi;

  @override
  ConsumerState<OshiDaysSection> createState() => _OshiDaysSectionState();
}

class _OshiDaysSectionState extends ConsumerState<OshiDaysSection> {
  /// 誕生日の月・日（片方だけ選んだ途中の状態も持つ）
  int? _month;
  int? _day;
  bool _loaded = false;
  bool _saving = false;

  String get _key => oshiColorKey(widget.oshi.kind, widget.oshi.id);

  Future<void> _run(
    Future<void> Function(OshiDaysRepository repo, String uid) save,
  ) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || _saving) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await save(ref.read(oshiDaysRepositoryProvider), uid);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('記念日を保存できませんでした。もう一度お試しください')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickStart(DateTime? current) async {
    final now = ref.read(nowProvider);
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? today,
      firstDate: DateTime(1950),
      lastDate: today,
      helpText: '推し始めた日',
    );
    if (picked == null || !mounted) return;
    await _run((repo, uid) => repo.setStartDate(uid, _key, picked));
  }

  /// 月か日を変える。両方そろったら保存する
  void _changeBirthday({int? month, int? day}) {
    final m = month ?? _month;
    var d = day ?? _day;
    if (m != null && d != null && d > maxDayOfMonth(m)) d = maxDayOfMonth(m);
    setState(() {
      _month = m;
      _day = d;
    });
    if (m != null && d != null) {
      final md = (month: m, day: d);
      _run((repo, uid) => repo.setBirthday(uid, _key, md));
    }
  }

  void _clearBirthday() {
    setState(() {
      _month = null;
      _day = null;
    });
    _run((repo, uid) => repo.setBirthday(uid, _key, null));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(oshiDaysProvider);
    final days = async.value ?? OshiDays.empty;
    // 保存してある誕生日を、最初の1回だけ選択欄に入れる
    if (!_loaded && async.hasValue) {
      final b = days.birthdays[_key];
      _month = b?.month;
      _day = b?.day;
      _loaded = true;
    }
    final start = days.startDates[_key];
    final count = start == null
        ? null
        : oshiDayCount(start, ref.watch(nowProvider));
    final birthdayLabel = widget.oshi.kind == OshiKind.group ? '結成日' : '誕生日';
    final heading = HakoFonts.jp(
      size: 14,
      weight: FontWeight.w700,
      height: 1.5,
    );
    final note = HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.5);
    final label = HakoFonts.jp(size: 13, height: 1.5);
    final dayItems = maxDayOfMonth(_month ?? 1);

    return Column(
      key: Key('oshi_days_section_${widget.oshi.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('記念日', style: heading),
        Text('ホームでお祝いします（フォロー中の推しだけ）', style: note),
        const SizedBox(height: 8),
        // 推し始めた日
        Row(
          children: [
            SizedBox(width: 96, child: Text('推し始めた日', style: label)),
            Expanded(
              child: Text(
                start == null
                    ? '未設定'
                    : '${start.year}/${start.month}/${start.day}'
                          '${count == null ? '' : '（推して$count日）'}',
                style: label,
              ),
            ),
            TextButton(
              key: const Key('oshi_days_start_pick'),
              onPressed: _saving ? null : () => _pickStart(start),
              child: Text(start == null ? '選ぶ' : '変える'),
            ),
            if (start != null)
              TextButton(
                key: const Key('oshi_days_start_clear'),
                onPressed: _saving
                    ? null
                    : () => _run(
                        (repo, uid) => repo.setStartDate(uid, _key, null),
                      ),
                child: const Text('外す'),
              ),
          ],
        ),
        // 誕生日（グループは結成日）
        Row(
          children: [
            SizedBox(width: 96, child: Text(birthdayLabel, style: label)),
            DropdownButton<int>(
              key: const Key('oshi_days_birthday_month'),
              value: _month,
              hint: const Text('月'),
              items: [
                for (var i = 1; i <= 12; i++)
                  DropdownMenuItem(value: i, child: Text('$i月')),
              ],
              onChanged: _saving ? null : (v) => _changeBirthday(month: v),
            ),
            const SizedBox(width: 8),
            DropdownButton<int>(
              key: const Key('oshi_days_birthday_day'),
              value: _day,
              hint: const Text('日'),
              items: [
                for (var i = 1; i <= dayItems; i++)
                  DropdownMenuItem(value: i, child: Text('$i日')),
              ],
              onChanged: _saving ? null : (v) => _changeBirthday(day: v),
            ),
            const Spacer(),
            if (_month != null || _day != null)
              TextButton(
                key: const Key('oshi_days_birthday_clear'),
                onPressed: _saving ? null : _clearBirthday,
                child: const Text('外す'),
              ),
          ],
        ),
      ],
    );
  }
}
