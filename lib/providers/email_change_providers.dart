import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';
import '../utils/auth_error_message.dart';
import '../utils/email_change.dart';

enum EmailChangeStep { input, waiting, done }

const _genericError = 'うまくいきませんでした。もう一度お試しください。';
const _notYetError = 'まだ確認できていません。メールのリンクを開いてから、もう一度押してください。';

/// ログインが無効になったときのコード（4.7）
const _sessionEndedCodes = {
  'user-token-expired',
  'invalid-user-token',
  'user-not-found',
};

class EmailChangeState {
  const EmailChangeState({
    this.step = EmailChangeStep.input,
    this.newEmail = '',
    this.sentTo = '',
    this.error,
    this.needsPassword = false,
    this.busy = false,
    this.resendLeft = 0,
    this.sessionEnded = false,
  });

  final EmailChangeStep step;
  final String newEmail;
  final String sentTo;

  /// エラーの行の文。null なら出さない
  final String? error;

  /// true の間、パスワード欄を出す（4.6）
  final bool needsPassword;

  /// 送信・確認の最中（ボタンを押せなくする）
  final bool busy;

  /// 再送まで残りの秒数
  final int resendLeft;

  /// 4.7。done のとき、別の形を出す
  final bool sessionEnded;

  /// error は null に戻せるよう、clearError で消す
  EmailChangeState copyWith({
    EmailChangeStep? step,
    String? newEmail,
    String? sentTo,
    String? error,
    bool clearError = false,
    bool? needsPassword,
    bool? busy,
    int? resendLeft,
    bool? sessionEnded,
  }) {
    return EmailChangeState(
      step: step ?? this.step,
      newEmail: newEmail ?? this.newEmail,
      sentTo: sentTo ?? this.sentTo,
      error: clearError ? null : (error ?? this.error),
      needsPassword: needsPassword ?? this.needsPassword,
      busy: busy ?? this.busy,
      resendLeft: resendLeft ?? this.resendLeft,
      sessionEnded: sessionEnded ?? this.sessionEnded,
    );
  }
}

/// 自動の確認の間隔（5 秒）と、再送の待ち（60 秒）。テストで短くするために差し替えられる
class EmailChangeTiming {
  const EmailChangeTiming({
    this.pollInterval = const Duration(seconds: 5),
    this.resendCooldown = 60,
  });
  final Duration pollInterval;
  final int resendCooldown;
}

final emailChangeTimingProvider = Provider<EmailChangeTiming>(
  (ref) => const EmailChangeTiming(),
);

/// 4.4 の流れ。シートを開くたびに新しく作る（autoDispose）。
/// パスワードは state に持たない（引数で受け取って、再認証に使うだけ）
class EmailChangeNotifier extends Notifier<EmailChangeState> {
  Timer? _pollTimer;
  Timer? _cooldownTimer;
  bool _disposed = false;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  EmailChangeState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _stopTimers();
    });
    return const EmailChangeState();
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
  }

  /// 例外から、エラーの行の文を作る。コード・中身は出さない
  String? _messageOf(Object e) {
    if (e is FirebaseAuthException) return emailChangeErrorMessage(e.code);
    return _genericError;
  }

  /// 「確認メールを送る」。検査 → （needsPassword なら再認証）→ startEmailChange
  Future<void> submit({required String newEmail, String? password}) async {
    if (state.busy) return;
    final trimmed = newEmail.trim();
    final invalid = validateNewEmail(trimmed, current: _repo.currentEmail);
    if (invalid != null) {
      state = state.copyWith(newEmail: newEmail, error: invalid);
      return;
    }
    state = state.copyWith(newEmail: newEmail, busy: true, clearError: true);
    try {
      if (state.needsPassword) {
        if (password == null || password.isEmpty) {
          state = state.copyWith(busy: false, error: 'パスワードが違います。');
          return;
        }
        await _repo.reauthenticateWithPassword(password);
      }
      await _repo.startEmailChange(trimmed);
    } catch (e) {
      if (_disposed) return;
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        // 文は出さず、パスワード欄を出す
        state = state.copyWith(busy: false, needsPassword: true);
        return;
      }
      state = state.copyWith(busy: false, error: _messageOf(e));
      return;
    }
    if (_disposed) return;
    state = state.copyWith(
      step: EmailChangeStep.waiting,
      sentTo: trimmed,
      busy: false,
      needsPassword: false,
      clearError: true,
    );
    _startCooldown();
    _startPolling();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    final total = ref.read(emailChangeTimingProvider).resendCooldown;
    state = state.copyWith(resendLeft: total);
    if (total <= 0) return;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = state.resendLeft - 1;
      if (left <= 0) {
        t.cancel();
        _cooldownTimer = null;
        state = state.copyWith(resendLeft: 0);
      } else {
        state = state.copyWith(resendLeft: left);
      }
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    final interval = ref.read(emailChangeTimingProvider).pollInterval;
    _pollTimer = Timer.periodic(interval, (_) => check(manual: false));
  }

  /// 状態を読み直す。manual は「リンクを開いたので確認する」ボタンから（結果を出す）。
  /// いまのアドレスが sentTo と同じ（大文字小文字は区別しない）なら done
  Future<void> check({required bool manual}) async {
    if (state.step != EmailChangeStep.waiting || state.busy) return;
    if (manual) state = state.copyWith(busy: true, clearError: true);
    try {
      final email = await _repo.reloadCurrentEmail();
      if (_disposed || state.step != EmailChangeStep.waiting) return;
      if (email != null && email.toLowerCase() == state.sentTo.toLowerCase()) {
        _stopTimers();
        state = state.copyWith(
          step: EmailChangeStep.done,
          busy: false,
          clearError: true,
        );
        return;
      }
      if (manual) state = state.copyWith(busy: false, error: _notYetError);
    } catch (e) {
      if (_disposed || state.step != EmailChangeStep.waiting) return;
      if (e is FirebaseAuthException && _sessionEndedCodes.contains(e.code)) {
        _stopTimers();
        state = state.copyWith(
          step: EmailChangeStep.done,
          sessionEnded: true,
          busy: false,
          clearError: true,
        );
        return;
      }
      // 自動の確認の失敗は黙る。手動のときだけ文を出す
      if (manual) state = state.copyWith(busy: false, error: _messageOf(e));
    }
  }

  /// 「確認メールを再送する」。待ちの間は何もしない
  Future<void> resend() async {
    if (state.step != EmailChangeStep.waiting) return;
    if (state.busy || state.resendLeft > 0) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _repo.startEmailChange(state.sentTo);
    } catch (e) {
      if (_disposed) return;
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        // 再認証が要る。入力に戻して、パスワード欄を出す
        _stopTimers();
        state = state.copyWith(
          step: EmailChangeStep.input,
          newEmail: state.sentTo,
          needsPassword: true,
          busy: false,
          resendLeft: 0,
        );
        return;
      }
      state = state.copyWith(busy: false, error: _messageOf(e));
      return;
    }
    if (_disposed) return;
    state = state.copyWith(busy: false);
    _startCooldown();
  }

  /// 「メールアドレスを入力し直す」。入力は残し、タイマーを止める
  void backToInput() {
    _stopTimers();
    state = state.copyWith(
      step: EmailChangeStep.input,
      newEmail: state.sentTo.isEmpty ? state.newEmail : state.sentTo,
      busy: false,
      resendLeft: 0,
      clearError: true,
    );
  }

  /// 入力を直し始めたとき、エラーの行を消す
  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }
}

final emailChangeProvider =
    NotifierProvider.autoDispose<EmailChangeNotifier, EmailChangeState>(
      EmailChangeNotifier.new,
    );

/// 画面に出す、いまのメールアドレス。完了のあと、行の伏せ字を更新するために使う
class CurrentEmailNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(authRepositoryProvider).currentEmail;

  void refresh() {
    state = ref.read(authRepositoryProvider).currentEmail;
  }
}

final currentEmailProvider = NotifierProvider<CurrentEmailNotifier, String?>(
  CurrentEmailNotifier.new,
);

/// 「表示／かくす」。true のとき、メールアドレスの全体を出す
class EmailRevealNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final emailRevealProvider = NotifierProvider<EmailRevealNotifier, bool>(
  EmailRevealNotifier.new,
);
