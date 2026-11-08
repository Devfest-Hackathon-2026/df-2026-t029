import '../models/live.dart';
import '../models/performance.dart';
import '../models/trip.dart';
import 'deadline.dart';
import 'travel_links.dart';

/// これからの遠征の1件（公演・ライブ名・遠征メモ。add_E 6章）
typedef UpcomingTrip = ({Performance performance, String liveTitle, Trip? trip});

/// 遠征の一覧（これからの遠征・これまでの遠征。add_E 6章）
class TripPlans {
  const TripPlans({required this.upcoming, required this.past});

  /// 自分のライブ一覧の公演のうち、オンライン以外で開演が今日以降（開演の早い順）。
  /// 遠征メモが無い公演も入る
  final List<UpcomingTrip> upcoming;

  /// 遠征メモがある公演のうち、開演が今日より前（新しい順）
  final List<Trip> past;

  bool get isEmpty => upcoming.isEmpty && past.isEmpty;
}

/// 遠征の一覧を作る（日付は端末の日付で比べる。今日の公演は開演後も「これから」）
TripPlans buildTripPlans(
  List<Live> lives,
  List<Performance> performances,
  Map<String, Trip> trips,
  DateTime now,
) {
  final today = localDayOf(now);
  // ID の無いライブ（保存前）は入れない
  final titles = {for (final l in lives) ?l.id: l.title};
  final upcoming = <UpcomingTrip>[
    for (final p in performances)
      if (p.id != null &&
          !isOnlineVenue(p) &&
          !localDayOf(p.startAt).isBefore(today))
        (
          performance: p,
          liveTitle: titles[p.liveId] ?? trips[p.id]?.liveTitle ?? '',
          trip: trips[p.id],
        ),
  ]..sort((a, b) => a.performance.startAt.compareTo(b.performance.startAt));
  final past = [
    for (final t in trips.values)
      if (localDayOf(t.startAt).isBefore(today)) t,
  ]..sort((a, b) => b.startAt.compareTo(a.startAt));
  return TripPlans(upcoming: upcoming, past: past);
}