import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/performance.dart';
import '../../models/travel_settings.dart';
import '../../models/trip.dart';
import '../../providers/oshi_providers.dart';
import '../../providers/travel_settings_providers.dart';
import '../../providers/trip_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/maps_embed.dart';
import '../../utils/travel_links.dart';
import '../common/web_iframe.dart';
import '../live/official_url_link.dart' show UrlOpener, urlLauncherProvider;
import '../live_form/date_time_field.dart' show formatDateTime;

enum _Tab { venue, route }

/// 会場の地図と帰りの経路のシート（add_M 5.1）
Future<void> showVenueMapSheet(BuildContext context, Performance performance) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (_) => _VenueMapSheet(performance: performance),
  );
}

class _VenueMapSheet extends ConsumerStatefulWidget {
  const _VenueMapSheet({required this.performance});

  final Performance performance;

  @override
  ConsumerState<_VenueMapSheet> createState() => _VenueMapSheetState();
}

class _VenueMapSheetState extends ConsumerState<_VenueMapSheet> {
  _Tab _tab = _Tab.venue;

  /// 帰りの駅を入力中か（未登録のときは常に入力欄を出す）
  bool _editing = false;
  bool _saving = false;
  final _station = TextEditingController();

  @override
  void dispose() {
    _station.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || _saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final s = _station.text.trim();
    if (s.length > TravelSettings.maxStationLength) {
      messenger.showSnackBar(
        const SnackBar(content: Text('帰りの駅は50文字以内で入力してください')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(travelSettingsRepositoryProvider).setHomeStation(uid, s);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('保存できませんでした。もう一度お試しください')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.performance;
    final open = ref.read(urlLauncherProvider);
    final station = ref.watch(travelSettingsProvider).value?.homeStation;
    final trip = p.id == null ? null : ref.watch(myTripsProvider).value?[p.id];
    final small = HakoFonts.jp(size: 12.5, color: BrandColors.sub, height: 1.6);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        key: const Key('venue_map_sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            placeOf(p),
            style: HakoFonts.jp(size: 18, weight: FontWeight.w700, height: 1.4),
          ),
          const SizedBox(height: 12),
          SegmentedButton<_Tab>(
            key: const Key('venue_map_tabs'),
            segments: const [
              ButtonSegment(
                value: _Tab.venue,
                label: Text('会場'),
                icon: Icon(Icons.place_outlined),
              ),
              ButtonSegment(
                value: _Tab.route,
                label: Text('帰りの経路'),
                icon: Icon(Icons.train_outlined),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 12),
          if (_tab == _Tab.venue)
            ..._venue(p, open)
          else
            ..._route(p, station, trip, open, small),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('venue_map_close'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ),
        ],
      ),
    );
  }

  /// 「会場」：会場の地図と Google マップで開くボタン
  List<Widget> _venue(Performance p, UrlOpener open) {
    final embed = venueMapEmbedUrl(p);
    final uri = venueMapUri(p);
    return [
      if (embed != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: WebIframe(
            key: const Key('venue_map_embed'),
            src: embed,
            aspectRatio: 4 / 3,
            title: '会場の地図',
          ),
        ),
      if (uri != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('venue_map_open'),
            onPressed: () => open(uri),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Google マップで開く'),
          ),
        ),
    ];
  }

  /// 「帰りの経路」：帰りの駅・電車の経路・Google マップで終電を調べるボタン
  List<Widget> _route(
    Performance p,
    String? station,
    Trip? trip,
    UrlOpener open,
    TextStyle small,
  ) {
    final editing = _editing || station == null;
    final embed = homeRouteEmbedUrl(p, station);
    final uri = homeRouteUri(p, station);
    final returnAt = trip?.returnAt;
    return [
      if (editing)
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('venue_map_station_field'),
                controller: _station,
                maxLength: TravelSettings.maxStationLength,
                decoration: const InputDecoration(
                  labelText: '帰りの駅',
                  hintText: '例）東京駅',
                  counterText: '',
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('venue_map_station_save'),
              onPressed: _saving ? null : _save,
              child: const Text('保存'),
            ),
            if (station != null)
              TextButton(
                onPressed: () => setState(() => _editing = false),
                child: const Text('やめる'),
              ),
          ],
        )
      else
        Row(
          children: [
            Expanded(
              child: Text(
                '帰りの駅：$station',
                key: const Key('venue_map_station'),
                style: HakoFonts.jp(
                  size: 15,
                  weight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ),
            TextButton(
              key: const Key('venue_map_station_edit'),
              onPressed: () {
                _station.text = station;
                setState(() => _editing = true);
              },
              child: const Text('変更'),
            ),
          ],
        ),
      const SizedBox(height: 8),
      if (station == null)
        Text('帰りの駅を登録すると、会場からの電車の経路が出ます', style: small)
      else if (embed != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: WebIframe(
            key: const Key('venue_map_route_embed'),
            src: embed,
            aspectRatio: 4 / 3,
            title: '帰りの経路',
          ),
        ),
      // 遠征メモの帰りの出発（判定はしない。add_M 5.1）
      if (returnAt != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '遠征メモの帰りの出発：${formatDateTime(returnAt)}',
            key: const Key('venue_map_return_at'),
            style: HakoFonts.jp(size: 14, height: 1.5),
          ),
        ),
      if (uri != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('venue_map_route_open'),
            onPressed: () => open(uri),
            icon: const Icon(Icons.train, size: 18),
            label: const Text('Google マップで終電を調べる'),
          ),
        ),
      if (station != null)
        Text('出発の時刻（終演後）や終電は、Google マップで指定できます', style: small),
    ];
  }
}