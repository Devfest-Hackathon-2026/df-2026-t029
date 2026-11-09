import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/trip.dart';
import '../../providers/live_providers.dart';
import '../../providers/trip_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/deadline.dart';
import '../../utils/travel_links.dart';
import '../../utils/trip_plans.dart';
import '../common/empty_state.dart';
import '../live_form/live_draft_to_models.dart' show formatYen;
import 'trip_sheet.dart';
import 'weather_line.dart';

/// 遠征の一覧（/trips。add_E 6章）。これからの遠征（カード）と、これまでの遠征（行）。
/// PC で本文の幅が広いときは、カードを2列に並べる
class TripListPage extends ConsumerWidget {
  const TripListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(tripPlansProvider);
    final now = ref.watch(nowProvider);
    return HakoPageScaffold(
      title: '遠征',
      showBack: true,
      backFallback: '/',
      maxContentWidth: 1080,
      body: SafeArea(
        child: switch (plans) {
          AsyncData(:final value) when value.isEmpty => const EmptyState(
            key: Key('trip_list_empty'),
            icon: Icons.luggage_outlined,
            title: '自分のライブ一覧にライブを追加すると、遠征の予定がここに並びます',
          ),
          AsyncData(:final value) => _TripListView(plans: value, now: now),
          AsyncError() => const HakoEmpty('遠征を読み込めませんでした'),
          _ => const Center(
            key: Key('trip_list_loading'),
            child: CircularProgressIndicator(),
          ),
        },
      ),
    );
  }
}

class _TripListView extends StatelessWidget {
  const _TripListView({required this.plans, required this.now});

  final TripPlans plans;
  final DateTime now;

  /// 本文の幅がこれ以上なら、カードを2列にする（Fc 5.2 と同じ）
  static const double _twoColumnWidth = 900;
  static const double _gap = 16;

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pad = HakoPageScaffold.padding(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - pad.horizontal;
        final cardWidth = width >= _twoColumnWidth
            ? ((width - _gap) / 2).floorToDouble()
            : width;
        return ListView(
          key: const Key('trip_list'),
          padding: pad,
          children: [
            const HakoSectionHeader('これからの遠征'),
            if (plans.upcoming.isEmpty)
              _note('これからの遠征はありません')
            else
              Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: [
                  for (final item in plans.upcoming)
                    SizedBox(
                      width: cardWidth,
                      child: _UpcomingTripCard(item: item, now: now),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            const HakoSectionHeader('これまでの遠征'),
            if (plans.past.isEmpty)
              _note('これまでの遠征の記録はありません')
            else
              for (final trip in plans.past) _PastTripRow(trip: trip),
          ],
        );
      },
    );
  }
}

/// 例：18:00
String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// これからの遠征のカード（日付・ライブ名・開演と会場・天気・遠征メモ・リンク）
class _UpcomingTripCard extends StatelessWidget {
  const _UpcomingTripCard({required this.item, required this.now});

  final UpcomingTrip item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = item.performance;
    final trip = item.trip;
    final days = localDayOf(p.startAt).difference(localDayOf(now)).inDays;
    final place = [
      p.venue,
      if (p.prefecture case final pref? when pref.isNotEmpty) '（$pref）',
    ].join();
    final sub = HakoFonts.jp(size: 12, color: BrandColors.sub, height: 1.5);
    void open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

    return Card(
      key: Key('trip_list_upcoming_${p.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/lives/${p.liveId}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HakoDateBadge(date: p.startAt),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 7日以内なら日数を強調する
                        if (days <= 7)
                          HakoCountBadge(days <= 0 ? '今日' : 'あと$days日'),
                        Text(
                          item.liveTitle,
                          style: HakoFonts.jp(
                            size: 14,
                            weight: FontWeight.w700,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text('${_hm(p.startAt)} 開演 ・ $place', style: sub),
                      ],
                    ),
                  ),
                ],
              ),
              // 公演の日の天気予報（今日から9日後まで。add_E 5章）
              WeatherLine(performance: p, now: now),
              const SizedBox(height: 6),
              if (trip == null)
                Text('遠征メモはまだありません', style: sub)
              else
                ..._tripDetails(trip),
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final link in travelLinksOf(p))
                    TextButton.icon(
                      key: Key('trip_list_link_${p.id}_${link.label}'),
                      onPressed: () => open(link.uri),
                      icon: Icon(link.icon, size: 18),
                      label: Text(link.label),
                    ),
                  TextButton.icon(
                    key: Key('trip_list_trip_button_${p.id}'),
                    onPressed: () => showTripSheet(
                      context,
                      performance: p,
                      liveTitle: item.liveTitle,
                    ),
                    icon: const Icon(Icons.luggage, size: 18),
                    label: Text(trip == null ? '遠征メモを作る' : '遠征メモ'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 遠征メモの中身（交通と時刻・宿とチェックイン・現地メモ・費用）
  List<Widget> _tripDetails(Trip trip) {
    final move = [
      if (trip.transport case final t?) t.label,
      if (trip.departAt case final d?) '行き ${formatShortDateTime(d)} 発',
      if (trip.returnAt case final d?) '帰り ${formatShortDateTime(d)} 発',
    ];
    final hotel = [
      if (trip.hotelName case final n? when n.isNotEmpty)
        n
      else if (trip.hasHotel)
        '宿あり',
      if (trip.checkInAt case final d?) 'チェックイン ${formatShortDateTime(d)}',
    ];
    final cost = [
      if (trip.transportCost case final c?) '交通費 ¥${formatYen(c)}',
      if (trip.hotelCost case final c?) '宿代 ¥${formatYen(c)}',
      if (trip.hasCost) '計 ¥${formatYen(trip.totalCost)}',
    ];
    return [
      if (move.isNotEmpty)
        _IconLine(icon: Icons.directions_transit, text: move.join(' ／ ')),
      if (hotel.isNotEmpty)
        _IconLine(icon: Icons.hotel_outlined, text: hotel.join(' ／ ')),
      if (trip.localNote case final note? when note.isNotEmpty)
        _IconLine(icon: Icons.sticky_note_2_outlined, text: note, maxLines: 3),
      if (cost.isNotEmpty)
        _IconLine(icon: Icons.payments_outlined, text: cost.join(' ／ ')),
    ];
  }
}

/// アイコン付きの行（遠征メモの中身）
class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text, this.maxLines = 2});

  final IconData icon;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: BrandColors.ink),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: HakoFonts.jp(
                size: 12,
                color: BrandColors.ink,
                height: 1.5,
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// これまでの遠征の1行（ライブ名・日付・会場・交通と宿と費用）
class _PastTripRow extends StatelessWidget {
  const _PastTripRow({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return HakoRow(
      key: Key('trip_list_past_${trip.performanceId}'),
      icon: Icons.luggage_outlined,
      title: trip.liveTitle,
      subs: [
        '${formatShortDateTime(trip.startAt)} 開演',
        if (trip.venue.isNotEmpty) trip.venue,
        tripSummary(trip),
      ],
      onTap: trip.liveId.isEmpty
          ? null
          : () => context.push('/lives/${trip.liveId}'),
    );
  }
}
