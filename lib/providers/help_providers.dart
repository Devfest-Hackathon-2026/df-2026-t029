import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 初回の吹き出しを出すか。true の間、ホームで出る。
/// アプリを開いている間だけ覚える（保存しない）。覚え方はここだけで決まる。
class HelpCoachNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void dismiss() => state = false;
}

final helpCoachVisibleProvider = NotifierProvider<HelpCoachNotifier, bool>(
  HelpCoachNotifier.new,
);
