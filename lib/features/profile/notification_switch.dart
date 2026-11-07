import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/messaging_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../repositories/messaging_repository.dart';

/// リマインド通知のオン・オフ（Step6 仕様書 3.5・5.5）
class NotificationSwitch extends ConsumerStatefulWidget {
  const NotificationSwitch({super.key});

  @override
  ConsumerState<NotificationSwitch> createState() => _NotificationSwitchState();
}

class _NotificationSwitchState extends ConsumerState<NotificationSwitch> {
  bool _busy = false;

  Future<void> _toggle(bool on) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _busy = true);
    final repo = ref.read(messagingRepositoryProvider);
    String message;
    try {
      if (on) {
        message = switch (await repo.enable(uid)) {
          NotificationEnableResult.enabled => 'リマインド通知をオンにしました',
          NotificationEnableResult.denied => 'ブラウザの設定で通知が拒否されています',
          NotificationEnableResult.notConfigured => '通知の設定がされていません',
        };
      } else {
        await repo.disable(uid);
        message = 'リマインド通知をオフにしました';
      }
    } catch (e) {
      message = '通知の設定に失敗しました：$e';
    }
    ref.invalidate(notificationEnabledProvider);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(notificationEnabledProvider);
    return SwitchListTile(
      key: const Key('profile_notification_switch'),
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.notifications_active_outlined),
      title: const Text('リマインド通知'),
      subtitle: const Text('申込期限・当落発表・入金期限の1日前と3時間前に、このブラウザへ通知します'),
      value: enabled.value ?? false,
      onChanged: _busy || enabled.isLoading ? null : _toggle,
    );
  }
}