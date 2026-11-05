import '../models/application.dart';
import '../models/live.dart';
import '../models/performance.dart';
import '../models/reception.dart';

/// 次の締切の種類（計画書 3.3）
enum DeadlineKind {
  /// 未申込 → 申込期限（applyEndAt）
  apply('申込期限'),

  /// 申込済 → 当落発表（resultAt）
  result('当落発表'),

  /// 当選 → 入金期限（paymentDeadline）
  payment('入金期限');

  const DeadlineKind(this.label);

  final String label;
}

/// 受付1件の「次にやること」と期限
class NextDeadline {
  const NextDeadline({
    required this.kind,
    required this.at,
    required this.reception,
    this.opensAt,
    this.isExpired = false,
  });

  final DeadlineKind kind;

  /// 期限の日時
  final DateTime at;

  final Reception reception;

  /// 受付開始前のときだけ入る（[kind] が apply で、applyStartAt が now より後）。
  /// 画面で「受付開始 11/10(火) 10:00〜」を添えるのに使う
  final DateTime? opensAt;

  /// 期限を過ぎているか（now >= at）。過ぎたものは [upcomingDeadlines] に出ない
  final bool isExpired;
}

/// 受付1件の次の締切（計画書 3.3 の表）。
///
/// - 未申込（null）→ applyEndAt、申込済 → resultAt、当選 → paymentDeadline
/// - 落選・入金済、または該当の日時が無いときは null
/// - 期限を過ぎていても null にせず、[NextDeadline.isExpired] を true にして返す
///   （ライブ詳細で「期限切れ」と出すため）。期限ちょうど（now == at）は期限切れ
/// - winnersOnly の受付も対象にする（当選者だけに絞るのは Step7）
NextDeadline? nextDeadlineOf(
  Reception reception,
  ApplicationStatus? status,
  DateTime now,
) {
  final (DeadlineKind kind, DateTime? at) = switch (status) {
    null => (DeadlineKind.apply, reception.applyEndAt),
    ApplicationStatus.applied => (DeadlineKind.result, reception.resultAt),
    ApplicationStatus.won => (DeadlineKind.payment, reception.paymentDeadline),
    // 落選・入金済は、もうやることがない
    ApplicationStatus.lost ||
    ApplicationStatus.paid => (DeadlineKind.apply, null),
  };
  if (at == null) return null;
  final start = reception.applyStartAt;
  return NextDeadline(
    kind: kind,
    at: at,
    reception: reception,
    opensAt: kind == DeadlineKind.apply && start != null && start.isAfter(now)
        ? start
        : null,
    isExpired: !now.isBefore(at),
  );
}

/// フォロー中の受付の次の締切を、近い順に並べる（期限切れは除く）。
///
/// [applications] は receptionId → 申込状況（無ければ未申込）。
/// 期限が同じときは受付の ID の順。件数は絞らない（ホームでは画面が5件に絞る）。
List<NextDeadline> upcomingDeadlines(
  List<Reception> receptions,
  Map<String, Application> applications,
  DateTime now,
) {
  final result = <NextDeadline>[
    for (final r in receptions)
      if (nextDeadlineOf(r, _statusOf(r, applications), now) case final d?
          when !d.isExpired)
        d,
  ];
  result.sort((a, b) {
    final byTime = a.at.compareTo(b.at);
    if (byTime != 0) return byTime;
    return (a.reception.id ?? '').compareTo(b.reception.id ?? '');
  });
  return result;
}

ApplicationStatus? _statusOf(
  Reception reception,
  Map<String, Application> applications,
) {
  final id = reception.id;
  return id == null ? null : applications[id]?.status;
}

/// ライブ一覧の1行
class LiveListEntry {
  const LiveListEntry({
    required this.live,
    required this.performances,
    required this.nextStartAt,
    required this.isEnded,
  });

  final Live live;

  /// そのライブの公演（開演日時の順）
  final List<Performance> performances;

  /// 今日（端末の日付）以降で最も早い公演の開演日時。終了していれば null
  final DateTime? nextStartAt;

  /// すべての公演の日付が今日より前（公演が0件のライブも「終了」扱いにせず、
  /// 一覧の最後に置く）
  final bool isEnded;
}

/// ライブ一覧を並べる（計画書 3.5）。
///
/// 次の公演日が近い順 → 公演が0件のライブ → 終了したライブ（最後の公演が新しい順）。
/// 公演は日単位で判定する（当日の公演は、開演後も「終了」にしない）。
/// [performances] に別のライブの公演が混ざっていてもよい（liveId で振り分ける）。
List<LiveListEntry> buildLiveList(
  List<Live> lives,
  List<Performance> performances,
  DateTime now,
) {
  final today = localDayOf(now);
  final byLive = <String, List<Performance>>{};
  for (final p in performances) {
    final liveId = p.liveId;
    if (liveId != null) (byLive[liveId] ??= []).add(p);
  }

  final entries = <LiveListEntry>[];
  final seen = <String>{};
  for (final live in lives) {
    final id = live.id;
    if (id != null && !seen.add(id)) continue; // 同じライブは1行だけ
    final ps = [...?byLive[id]]..sort((a, b) => a.startAt.compareTo(b.startAt));
    DateTime? next;
    for (final p in ps) {
      if (!localDayOf(p.startAt).isBefore(today)) {
        next = p.startAt;
        break;
      }
    }
    entries.add(
      LiveListEntry(
        live: live,
        performances: List.unmodifiable(ps),
        nextStartAt: next,
        isEnded: ps.isNotEmpty && next == null,
      ),
    );
  }

  int group(LiveListEntry e) => e.nextStartAt != null
      ? 0
      : e.isEnded
      ? 2
      : 1;
  entries.sort((a, b) {
    final byGroup = group(a).compareTo(group(b));
    if (byGroup != 0) return byGroup;
    final int byTime;
    switch (group(a)) {
      case 0:
        byTime = a.nextStartAt!.compareTo(b.nextStartAt!);
      case 2:
        byTime = b.performances.last.startAt.compareTo(
          a.performances.last.startAt,
        );
      default:
        byTime = 0;
    }
    if (byTime != 0) return byTime;
    final byTitle = a.live.title.compareTo(b.live.title);
    if (byTitle != 0) return byTitle;
    return (a.live.id ?? '').compareTo(b.live.id ?? '');
  });
  return entries;
}

/// 端末の時刻（日本時間を前提とする）での、その日の0時
DateTime localDayOf(DateTime t) {
  final local = t.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// 公演の日が、今日から見ていつか（端末の日付で比べる）
enum PerformanceDay { past, today, future }

/// 公演の日付を判定する（[buildLiveList] の「終了」と同じ日単位の判定）。
/// 当日の公演は、開演した後も [PerformanceDay.today]
PerformanceDay performanceDayOf(DateTime startAt, DateTime now) {
  final day = localDayOf(startAt);
  final today = localDayOf(now);
  if (day.isBefore(today)) return PerformanceDay.past;
  if (day.isAfter(today)) return PerformanceDay.future;
  return PerformanceDay.today;
}

/// ホームの「次の締切」の1行（締切と、そのライブ）
class DeadlineEntry {
  const DeadlineEntry({required this.deadline, required this.live});

  final NextDeadline deadline;
  final Live live;
}
