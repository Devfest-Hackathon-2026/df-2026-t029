import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/application.dart';
import '../../models/history_entry.dart';
import '../../models/live.dart';
import '../../models/oshi.dart';
import '../../models/performance.dart';
import '../../models/reception.dart';
import '../../providers/oshi_providers.dart';
import '../../providers/trip_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/deadline.dart';
import '../../utils/travel_links.dart';
import '../live_form/date_time_field.dart';
import '../live_form/live_draft_to_models.dart' show formatYen;
import '../calendar/calendar_add_sheet.dart';
import '../travel/trip_sheet.dart';
import '../travel/weather_line.dart';
import 'deadline_format.dart';
import 'live_changes.dart';
import 'live_list_entries.dart';
import 'official_url_link.dart';
import '../../providers/live_providers.dart';
import '../../providers/memory_providers.dart';

/// 受付種別の表示名
const receptionTypeLabels = {
  ReceptionType.fc: 'FC先行',
  ReceptionType.general: '一般',
  ReceptionType.upgrade: 'アプグレ',
  ReceptionType.other: 'その他',
};

/// ライブ詳細の中身
class LiveDetail {
  const LiveDetail({
    required this.live,
    required this.performances,
    required this.receptions,
    required this.oshis,
    required this.applications,
    this.hiddenReceptionCount = 0,
  });

  /// 見つからない・読めないときは null
  final Live? live;

  /// 開演が早い順
  final List<Performance> performances;

  /// 申込期限が早い順
  final List<Reception> receptions;
  final List<OshiSummary> oshis;

  /// 自分の申込状況（receptionId → 申込状況。無ければ未申込）
  final Map<String, Application> applications;

  /// 当選すると表示される受付（当選者のみ）で、今は隠している件数
  final int hiddenReceptionCount;
}

/// ライブ詳細の中身。どれかがエラーならエラー、どれかが読み込み中なら読み込み中
final liveDetailProvider = Provider.autoDispose
    .family<AsyncValue<LiveDetail>, String>((ref, liveId) {
      final live = ref.watch(liveProvider(liveId));
      final performances = ref.watch(performancesOfLiveProvider(liveId));
      final receptions = ref.watch(visibleReceptionsOfLiveProvider(liveId));
      final oshis = ref.watch(allOshisProvider);
      final applications = ref.watch(applicationsProvider);
      for (final AsyncValue<Object?> v in [
        live,
        performances,
        receptions,
        oshis,
        applications,
      ]) {
        if (v case AsyncError(:final error, :final stackTrace)) {
          return AsyncError(error, stackTrace);
        }
      }
      final performancesValue = performances.value;
      final receptionsValue = receptions.value;
      final oshisValue = oshis.value;
      final applicationsValue = applications.value;
      if (!live.hasValue ||
          performancesValue == null ||
          receptionsValue == null ||
          oshisValue == null ||
          applicationsValue == null) {
        return const AsyncLoading();
      }
      return AsyncData(
        LiveDetail(
          live: live.value,
          performances: [...performancesValue]
            ..sort((a, b) => a.startAt.compareTo(b.startAt)),
          receptions: [...receptionsValue.visible]
            ..sort((a, b) => a.applyEndAt.compareTo(b.applyEndAt)),
          oshis: oshisValue,
          applications: applicationsValue,
          hiddenReceptionCount: receptionsValue.hiddenCount,
        ),
      );
    });

/// ライブ詳細（/lives/:liveId）
class LiveDetailPage extends ConsumerStatefulWidget {
  const LiveDetailPage({super.key, required this.liveId});

  final String liveId;

  @override
  ConsumerState<LiveDetailPage> createState() => _LiveDetailPageState();
}

class _LiveDetailPageState extends ConsumerState<LiveDetailPage> {
  /// 申込状況を変更中の受付の ID（二重送信の防止）
  final Set<String> _busy = {};

  /// 自分のライブ一覧への追加・解除の処理中（二重送信の防止）
  bool _togglingMine = false;

  Future<void> _toggleMine(bool isIn) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || _togglingMine) return;
    if (isIn) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ライブ一覧から外しますか？'),
          content: const Text('申込状況は残ります。もう一度追加すると元に戻ります'),
          actions: [
            TextButton(
              key: const Key('live_detail_remove_cancel'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('やめる'),
            ),
            FilledButton(
              key: const Key('live_detail_remove_confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('外す'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _togglingMine = true);
    String? error;
    try {
      final repo = ref.read(myLiveRepositoryProvider);
      if (isIn) {
        await repo.remove(uid, widget.liveId);
      } else {
        await repo.add(uid, widget.liveId);
      }
    } catch (e) {
      debugPrint('ライブ一覧の更新に失敗: $e');
      error = 'ライブ一覧を更新できませんでした。もう一度お試しください';
    }
    if (!mounted) return;
    setState(() => _togglingMine = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _setStatus(
    Reception reception,
    ApplicationStatus? status,
  ) async {
    final id = reception.id;
    final uid = ref.read(currentUidProvider);
    if (id == null || uid == null || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    String? error;
    try {
      await ref
          .read(applicationRepositoryProvider)
          .setStatus(uid, reception, status);
    } catch (e) {
      debugPrint('申込状況の変更に失敗: $e');
      error = '申込状況を変更できませんでした。もう一度お試しください';
    }
    // State.context を使うので、State の mounted で確認する
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveId = widget.liveId;
    final detail = ref.watch(liveDetailProvider(liveId));
    final now = ref.watch(nowProvider);
    // 「変更あり」の印（読めなくても詳細は出す）
    final recent = ref.watch(recentChangesProvider(liveId)).value ?? const {};
    // 記録のある公演の ID（読み込み中・エラーのときは null で、ボタンを出さない）
    final memoryIds = ref.watch(myMemoriesProvider).value?.keys.toSet();
    // 自分のライブ一覧に入っているか（読み込み中は null）
    final inMine = ref.watch(isInMyLivesProvider(liveId)).value;

    return HakoPageScaffold(
      title: 'ライブ詳細',
      showBack: true,
      backFallback: '/lives',
      body: SafeArea(
        child: switch (detail) {
          AsyncError() => _Message(
            key: const Key('live_detail_error'),
            text: 'ライブを読み込めませんでした',
            action: OutlinedButton(
              key: const Key('live_detail_retry_button'),
              onPressed: () {
                ref.invalidate(liveProvider(liveId));
                ref.invalidate(performancesOfLiveProvider(liveId));
                ref.invalidate(receptionsOfLiveProvider(liveId));
                ref.invalidate(allOshisProvider);
                ref.invalidate(applicationsProvider);
              },
              child: const Text('もう一度読み込む'),
            ),
          ),
          AsyncValue(value: LiveDetail(live: null)) => const _Message(
            key: Key('live_detail_not_found'),
            text: 'このライブは見つかりませんでした',
          ),
          AsyncValue(value: final d?) => _DetailView(
            detail: d,
            now: now,
            busy: _busy,
            onChangeStatus: _setStatus,
            recent: recent,
            memoryIds: memoryIds,
            inMine: inMine,
            togglingMine: _togglingMine,
            onToggleMine: () => _toggleMine(inMine ?? false),
            onAddToCalendar: () => addLiveToCalendar(context, ref, liveId),
          ),
          _ => const Center(
            key: Key('live_detail_loading'),
            child: CircularProgressIndicator(),
          ),
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: HakoFonts.jp(
                size: 13,
                color: BrandColors.sub,
                height: 1.6,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({
    required this.detail,
    required this.now,
    required this.busy,
    required this.onChangeStatus,
    required this.recent,
    required this.memoryIds,
    required this.inMine,
    required this.togglingMine,
    required this.onToggleMine,
    required this.onAddToCalendar,
  });

  /// 記録のある公演の ID。読み込み中なら null
  final Set<String>? memoryIds;

  /// 自分のライブ一覧に入っているか（null は読み込み中）
  final bool? inMine;
  final bool togglingMine;
  final VoidCallback onToggleMine;

  /// Google カレンダーに追加する（F-4）
  final VoidCallback onAddToCalendar;

  final LiveDetail detail;
  final DateTime now;
  final Set<String> busy;
  final void Function(Reception, ApplicationStatus?) onChangeStatus;

  /// 7日以内に変わったドキュメント → 直近の変更（data の判定の結果）
  final Map<HistoryTarget, LiveChange> recent;

  String _nameOf(String id) {
    for (final o in detail.oshis) {
      if (o.id == id) return o.name;
    }
    return id;
  }

  /// 変更履歴の見出し
  String _titleOf(HistoryTarget target) {
    switch (target.collection) {
      case HistoryCollection.lives:
        return 'ライブ';
      case HistoryCollection.performances:
        for (final p in detail.performances) {
          if (p.id == target.docId) {
            return '公演 ${formatDateTime(p.startAt)} ${p.venue}';
          }
        }
        return '公演';
      case HistoryCollection.receptions:
        for (final r in detail.receptions) {
          if (r.id == target.docId) return '受付「${r.name}」';
        }
        return '受付';
    }
  }

  Widget? _markOf(HistoryCollection collection, String? id) {
    final change = id == null ? null : recent[HistoryTarget(collection, id)];
    if (change == null) return null;
    return ChangedMark(change: change, now: now, nameOf: _nameOf);
  }

  @override
  Widget build(BuildContext context) {
    final live = detail.live!;
    final theme = Theme.of(context);
    final performers = performerNamesOf(live, detail.oshis);
    final url = live.officialUrl;

    return ListView(
      key: const Key('live_detail'),
      padding: HakoPageScaffold.padding(context),
      children: [
        Text(
          live.title,
          key: const Key('live_detail_title'),
          style: HakoFonts.jp(size: 20, weight: FontWeight.w700, height: 1.4),
        ),
        ?_markOf(HistoryCollection.lives, live.id),
        if (performers.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            performers.join('、'),
            key: const Key('live_detail_performers'),
            style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.5),
          ),
        ],
        if (url != null && url.isNotEmpty) ...[
          const SizedBox(height: 4),
          OfficialUrlLink(key: const Key('live_detail_official_url'), url: url),
        ],
        const SizedBox(height: 12),
        // 操作のボタンは横に並べ、狭い幅では折り返す
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (inMine != null)
              inMine!
                  ? OutlinedButton.icon(
                      key: const Key('live_detail_remove_mine_button'),
                      onPressed: togglingMine ? null : onToggleMine,
                      icon: const Icon(Icons.check),
                      label: const Text('ライブ一覧から外す'),
                    )
                  : FilledButton.icon(
                      key: const Key('live_detail_add_mine_button'),
                      onPressed: togglingMine ? null : onToggleMine,
                      icon: const Icon(Icons.add),
                      label: const Text('ライブ一覧に追加'),
                    ),
            OutlinedButton.icon(
              key: const Key('live_detail_edit_button'),
              onPressed: () => context.go('/lives/${live.id}/edit'),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('このライブを編集'),
            ),
            OutlinedButton.icon(
              key: const Key('live_detail_calendar_button'),
              onPressed: onAddToCalendar,
              icon: const Icon(Icons.calendar_today_outlined),
              label: const Text('Google カレンダーに追加'),
            ),
          ],
        ),
        const HakoSectionHeader('公演'),
        if (detail.performances.isEmpty)
          const Padding(
            key: Key('live_detail_performances_empty'),
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('公演はまだ登録されていません'),
          ),
        for (final p in detail.performances) ...[
          _PerformanceTile(
            p: p,
            now: now,
            liveId: live.id!,
            liveTitle: live.title,
            hasMemory: memoryIds?.contains(p.id),
          ),
          ?_markOf(HistoryCollection.performances, p.id),
        ],
        const HakoSectionHeader('受付'),
        if (detail.receptions.isEmpty && detail.hiddenReceptionCount == 0)
          const Padding(
            key: Key('live_detail_receptions_empty'),
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('受付はまだ登録されていません'),
          ),
        for (final r in detail.receptions)
          _ReceptionCard(
            r: r,
            now: now,
            status: detail.applications[r.id]?.status,
            busy: busy.contains(r.id),
            onChangeStatus: (s) => onChangeStatus(r, s),
            inMine: inMine,
            mark: _markOf(HistoryCollection.receptions, r.id),
          ),
        if (detail.hiddenReceptionCount > 0)
          Padding(
            key: const Key('live_detail_hidden_receptions'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '当選すると表示される受付が${detail.hiddenReceptionCount}件あります',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        LiveHistorySection(liveId: live.id!, titleOf: _titleOf),
      ],
    );
  }
}

class _PerformanceTile extends ConsumerWidget {
  const _PerformanceTile({
    required this.p,
    required this.now,
    required this.liveId,
    required this.liveTitle,
    required this.hasMemory,
  });

  final Performance p;
  final DateTime now;
  final String liveId;

  /// ライブ名（遠征メモに複製する）
  final String liveTitle;

  /// 記録があれば true。記録の読み込み中なら null（ボタンを出さない）
  final bool? hasMemory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final openAt = p.openAt;
    final place = [
      p.venue,
      if (p.prefecture case final pref? when pref.isNotEmpty) '（$pref）',
    ].join();
    // 一覧（buildLiveList）と同じく、端末の日付で判定する
    final day = performanceDayOf(p.startAt, now);
    final finished = day == PerformanceDay.past;
    final dayLabel = switch (day) {
      PerformanceDay.past => '（終了）',
      PerformanceDay.today => '（本日）',
      PerformanceDay.future => '',
    };
    final id = p.id;
    final has = hasMemory;
    // 遠征サポート（E-1）：これから行く公演だけ、行き方と周辺の宿を出す
    final directions = finished ? null : directionsUri(p);
    final hotels = finished ? null : hotelsUri(p);
    // 残りのリンクは「その他」にまとめる（add_E 4章）
    final others = finished
        ? const <TravelLink>[]
        : [
            for (final link in travelLinksOf(p))
              if (link.label != '行き方' && link.label != '周辺の宿') link,
          ];
    // 遠征メモ（E-2）：オンライン以外の公演に出す（終わった後に記録する人もいるので、終了後も出す）
    final canTrip = id != null && !isOnlineVenue(p);
    final trip = id == null ? null : ref.watch(myTripsProvider).value?[id];

    void open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: BrandColors.rowLine, width: 1.5),
        ),
      ),
      child: ListTile(
        key: Key('live_detail_performance_${p.id}'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.calendar_today_outlined, size: 28),
        title: Text(
          '${formatDateTime(p.startAt)} 開演$dayLabel',
          style: HakoFonts.jp(
            size: 15,
            color: finished ? BrandColors.sub : BrandColors.ink,
            height: 1.5,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (openAt != null) '${formatDateTime(openAt)} 開場',
                place,
              ].join('\n'),
              style: HakoFonts.jp(
                size: 13,
                color: BrandColors.sub,
                height: 1.5,
              ),
            ),
            // 公演の日の天気予報（今日から9日後まで。add_E 5章）
            if (!finished) WeatherLine(performance: p, now: now),
            if (trip != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  tripSummary(trip),
                  key: Key('live_detail_trip_summary_$id'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // 行き・帰り・チェックインの時刻（add_E 3章）
              if (tripTimesLine(trip) case final times?)
                Text(
                  times,
                  key: Key('live_detail_trip_times_$id'),
                  style: HakoFonts.jp(
                    size: 12,
                    color: BrandColors.sub,
                    height: 1.5,
                  ),
                ),
            ],
            if (directions != null ||
                hotels != null ||
                canTrip ||
                others.isNotEmpty)
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (directions != null)
                    TextButton.icon(
                      key: Key('live_detail_directions_button_${p.id}'),
                      onPressed: () => open(directions),
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('行き方'),
                    ),
                  if (hotels != null)
                    TextButton.icon(
                      key: Key('live_detail_hotels_button_${p.id}'),
                      onPressed: () => open(hotels),
                      icon: const Icon(Icons.hotel, size: 18),
                      label: const Text('周辺の宿'),
                    ),
                  if (canTrip)
                    TextButton.icon(
                      key: Key('live_detail_trip_button_${p.id}'),
                      onPressed: () => showTripSheet(
                        context,
                        performance: p,
                        liveTitle: liveTitle,
                      ),
                      icon: const Icon(Icons.luggage, size: 18),
                      label: const Text('遠征メモ'),
                    ),
                  if (others.isNotEmpty)
                    PopupMenuButton<TravelLink>(
                      key: Key('live_detail_travel_more_${p.id}'),
                      tooltip: 'その他の遠征のリンク',
                      onSelected: (link) => open(link.uri),
                      itemBuilder: (context) => [
                        for (final link in others)
                          PopupMenuItem(
                            value: link,
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(link.icon, size: 20),
                              title: Text(link.label),
                            ),
                          ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.more_horiz,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'その他 ▼',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
        trailing: id == null || has == null
            ? null
            : TextButton(
                key: Key('live_detail_memory_button_$id'),
                onPressed: () => has
                    ? context.push('/memories/$id')
                    : context.go('/lives/$liveId/memory/$id'),
                child: Text(
                  has ? '記録を見る' : '記録する',
                  style:
                      HakoFonts.jp(
                        size: 13,
                        weight: FontWeight.w700,
                        height: 1.3,
                      ).copyWith(
                        decoration: TextDecoration.underline,
                        decorationColor: HakoHue.of(context),
                        decorationThickness: 2,
                      ),
                ),
              ),
      ),
    );
  }
}

class _ReceptionCard extends StatelessWidget {
  const _ReceptionCard({
    required this.r,
    required this.now,
    required this.status,
    required this.busy,
    required this.onChangeStatus,
    required this.inMine,
    this.mark,
  });

  final Reception r;

  /// 自分のライブ一覧に入っているか（null は読み込み中）
  final bool? inMine;

  /// 「変更あり」の印（無ければ null）
  final Widget? mark;
  final DateTime now;

  /// 自分の申込状況（null は未申込）
  final ApplicationStatus? status;

  /// 変更中なら true（選べなくする）
  final bool busy;
  final ValueChanged<ApplicationStatus?> onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final applyStartAt = r.applyStartAt;
    final resultAt = r.resultAt;
    final paymentDeadline = r.paymentDeadline;
    final next = nextDeadlineOf(r, status, now)?.kind;

    return HakoBox(
      key: Key('live_detail_reception_${r.id}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                r.name,
                style: HakoFonts.jp(
                  size: 14,
                  weight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              HakoTagChip(receptionTypeLabels[r.type] ?? 'その他'),
              if (r.winnersOnly)
                HakoTagChip(
                  '当選者のみ',
                  key: Key('live_detail_winners_only_${r.id}'),
                ),
            ],
          ),
          ?mark,
          const SizedBox(height: 8),
          if (applyStartAt != null)
            _DateRow(
              label: '申込開始',
              at: applyStartAt,
              note: applyStartAt.isAfter(now) ? '受付開始前' : null,
            ),
          _DateRow(
            label: '申込期限',
            at: r.applyEndAt,
            // 残り時間は、いまの「次にやること」の期限にだけ出す
            remaining: next == DeadlineKind.apply
                ? remainingLabel(r.applyEndAt, now)
                : null,
          ),
          if (resultAt != null)
            _DateRow(
              label: '当落発表',
              at: resultAt,
              note: resultAt.isBefore(now) ? '発表済み' : null,
            ),
          paymentDeadline == null
              ? const _TextRow(label: '入金期限', value: '未発表')
              : _DateRow(
                  label: '入金期限',
                  at: paymentDeadline,
                  remaining: next == DeadlineKind.payment
                      ? remainingLabel(paymentDeadline, now)
                      : null,
                ),
          if (r.prices.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final price in r.prices)
              _TextRow(label: price.seat, value: '${formatYen(price.amount)}円'),
          ],
          const Divider(height: 24),
          _NextAction(r: r, status: status, now: now),
          const SizedBox(height: 8),
          if (inMine == true)
            _StatusSelector(
              receptionId: r.id ?? '',
              status: status,
              busy: busy,
              onChanged: onChangeStatus,
            )
          else if (inMine == false)
            Text(
              'ライブ一覧に追加すると、申込状況を記録できます',
              key: Key('live_detail_add_hint_${r.id}'),
            ),
        ],
      ),
    );
  }
}

final _subStyle = HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.5);
final _bodyStyle = HakoFonts.jp(size: 13, height: 1.5);

class _TextRow extends StatelessWidget {
  const _TextRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 88, child: Text(label, style: _subStyle)),
          Expanded(child: Text(value, style: _bodyStyle)),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.at,
    this.remaining,
    this.note,
  });

  final String label;
  final DateTime at;
  final RemainingLabel? remaining;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rem = remaining;
    final urgent = rem?.isUrgent ?? false;
    final past = rem?.isPast ?? false;
    final extra = rem?.text ?? note;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 88, child: Text(label, style: _subStyle)),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatDateTime(at),
                    style: HakoFonts.jp(
                      size: 13,
                      color: past ? BrandColors.sub : BrandColors.ink,
                      height: 1.5,
                    ),
                  ),
                  if (extra != null) ...[
                    const TextSpan(text: '  '),
                    if (urgent)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: scheme.error,
                        ),
                      ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          // 過ぎた・発表済みは tonal、残り時間は黄
                          color: rem != null && !past
                              ? BrandColors.hall3
                              : BrandColors.tonal,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: BrandColors.ink,
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            extra,
                            style: HakoFonts.jp(
                              size: 11,
                              weight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 自分の申込状況から決まる「次にやること」
class _NextAction extends StatelessWidget {
  const _NextAction({required this.r, required this.status, required this.now});

  final Reception r;
  final ApplicationStatus? status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final deadline = nextDeadlineOf(r, status, now);
    final String text;
    var urgent = false;
    String? opens;
    if (deadline != null) {
      final d = describeNextDeadline(deadline, now);
      text = d.text;
      urgent = d.isUrgent;
      opens = d.opensText;
    } else {
      text = switch (status) {
        ApplicationStatus.applied => '当落発表の日時は未登録です',
        ApplicationStatus.won => '入金期限はまだ発表されていません',
        ApplicationStatus.paid => '入金済みです。やることはありません',
        ApplicationStatus.lost => '落選しました',
        null => '申込期限は未登録です',
      };
    }
    return Column(
      key: Key('live_detail_next_action_${r.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              urgent
                  ? Icons.warning_amber_rounded
                  : status == ApplicationStatus.paid
                  ? Icons.check
                  : Icons.flag_outlined,
              size: 18,
              color: urgent ? scheme.error : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: deadline == null
                  ? Text(text, style: _bodyStyle)
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: HakoStatusChip(
                        text,
                        kind: switch (deadline.kind) {
                          DeadlineKind.apply => HakoChipKind.apply,
                          DeadlineKind.result => HakoChipKind.draw,
                          DeadlineKind.payment => HakoChipKind.pay,
                        },
                      ),
                    ),
            ),
          ],
        ),
        if (opens != null)
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              opens,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// 申込状況を選ぶ部品（どの状態からどの状態へも変えられる）
class _StatusSelector extends StatelessWidget {
  const _StatusSelector({
    required this.receptionId,
    required this.status,
    required this.busy,
    required this.onChanged,
  });

  final String receptionId;
  final ApplicationStatus? status;
  final bool busy;
  final ValueChanged<ApplicationStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('申込状況', style: _subStyle),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButton<ApplicationStatus?>(
            key: Key('live_detail_status_$receptionId'),
            isExpanded: true,
            value: status,
            // 処理中は onChanged を null にして選べなくする
            onChanged: busy
                ? null
                : (v) {
                    if (v != status) onChanged(v);
                  },
            items: [
              const DropdownMenuItem<ApplicationStatus?>(
                value: null,
                child: Text(ApplicationStatus.notAppliedLabel),
              ),
              for (final s in ApplicationStatus.values)
                DropdownMenuItem<ApplicationStatus?>(
                  value: s,
                  child: Text(s.label),
                ),
            ],
          ),
        ),
        if (busy)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: SizedBox(
              key: Key('live_detail_status_busy_$receptionId'),
              width: 16,
              height: 16,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}
