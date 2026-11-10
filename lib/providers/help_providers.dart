import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/local_flags.dart';

const _helpCoachKey = 'help_coach_dismissed';

/// 初回の吹き出しを出すか。true の間、ホームで出る。
/// 閉じたことは、このブラウザに覚える（localStorage）。覚え方はここだけで決まる。
class HelpCoachNotifier extends Notifier<bool> {
  @override
  bool build() => readLocalFlag(_helpCoachKey) != '1';

  void dismiss() {
    writeLocalFlag(_helpCoachKey, '1');
    state = false;
  }
}

final helpCoachVisibleProvider = NotifierProvider<HelpCoachNotifier, bool>(
  HelpCoachNotifier.new,
);