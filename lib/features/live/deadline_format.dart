import '../../utils/deadline.dart';
import '../live_form/date_time_field.dart';

/// 期限までの残り時間の表示（Firestore に依存しない純粋関数）
class RemainingLabel {
  const RemainingLabel({required this.text, required this.isUrgent});

  /// 例：「あと2日」「あと5時間」「あと30分」「あと1分未満」「期限切れ」
  final String text;

  /// 24時間以内（まだ過ぎていない）なら true。目立たせる
  final bool isUrgent;

  bool get isPast => text == expiredLabel;
}

const expiredLabel = '期限切れ';

/// [at] までの残りを返す。[at] が [now] 以前なら「期限切れ」。
/// ちょうど [now] も期限切れとする（lib/utils/deadline.dart の isExpired と同じ）。
RemainingLabel remainingLabel(DateTime at, DateTime now) {
  if (!at.isAfter(now)) {
    return const RemainingLabel(text: expiredLabel, isUrgent: false);
  }
  final d = at.difference(now);
  if (d >= const Duration(hours: 24)) {
    return RemainingLabel(text: 'あと${d.inDays}日', isUrgent: false);
  }
  if (d >= const Duration(hours: 1)) {
    return RemainingLabel(text: 'あと${d.inHours}時間', isUrgent: true);
  }
  if (d >= const Duration(minutes: 1)) {
    return RemainingLabel(text: 'あと${d.inMinutes}分', isUrgent: true);
  }
  return const RemainingLabel(text: 'あと1分未満', isUrgent: true);
}

/// 「次にやること」の1行（受付カードとホームの「次の締切」で使う）
class NextActionText {
  const NextActionText({
    required this.text,
    required this.isUrgent,
    required this.isExpired,
    this.opensText,
  });

  /// 例：「申込期限まであと2日」「当落発表 2026/11/20(金) 18:00」
  /// 「入金期限まであと5時間」「申込期限を過ぎました」
  final String text;

  /// 24時間以内（まだ過ぎていない）
  final bool isUrgent;

  final bool isExpired;

  /// 受付開始前のときだけ。例：「受付開始 2026/11/10(火) 10:00〜」
  final String? opensText;
}

/// [deadline]（data の nextDeadlineOf の結果）を文にする。
/// 当落発表は「まで」ではなく日時を出す（計画書 3.3 の表示例）
NextActionText describeNextDeadline(NextDeadline deadline, DateTime now) {
  final label = deadline.kind.label;
  final opensAt = deadline.opensAt;
  final opensText = opensAt == null ? null : '受付開始 ${formatDateTime(opensAt)}〜';
  if (deadline.isExpired) {
    final text = deadline.kind == DeadlineKind.result
        ? '当落発表 ${formatDateTime(deadline.at)}（発表済み）'
        : '$labelを過ぎました';
    return NextActionText(
      text: text,
      isUrgent: false,
      isExpired: true,
      opensText: opensText,
    );
  }
  final rem = remainingLabel(deadline.at, now);
  final text = deadline.kind == DeadlineKind.result
      ? '$label ${formatDateTime(deadline.at)}'
      : '$labelまで${rem.text}';
  return NextActionText(
    text: text,
    // 当落発表は自分がやることではないので、目立たせない
    isUrgent: deadline.kind != DeadlineKind.result && rem.isUrgent,
    isExpired: false,
    opensText: opensText,
  );
}

/// [at] から [now] までの経過の表示（例：「たった今」「30分前」「2時間前」「3日前」）。
/// 変更履歴と「変更あり」の1行で使う。[at] が [now] より後でも「たった今」
String elapsedLabel(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d < const Duration(minutes: 1)) return 'たった今';
  if (d < const Duration(hours: 1)) return '${d.inMinutes}分前';
  if (d < const Duration(hours: 24)) return '${d.inHours}時間前';
  return '${d.inDays}日前';
}
