import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../providers/messaging_providers.dart';

/// アプリを開いているときに届いた通知を SnackBar で出す（Step6 仕様書 3.6・5.6）。
///
/// 前面のときはブラウザの通知が出ないため。「開く」でそのライブの詳細へ移る。
/// `MaterialApp.router` の `builder` で包む（ScaffoldMessenger より内側になる）。
class ForegroundNotificationListener extends ConsumerWidget {
  const ForegroundNotificationListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(foregroundMessageProvider, (_, next) {
      final message = next.value;
      if (message == null) return;
      final title = message.notification?.title ?? 'リマインド';
      final body = message.notification?.body;
      final liveId = message.data['liveId'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (body != null) Text(body),
            ],
          ),
          action: liveId is String && liveId.isNotEmpty
              ? SnackBarAction(
                  label: '開く',
                  onPressed: () =>
                      ref.read(routerProvider).go('/lives/$liveId'),
                )
              : null,
        ),
      );
    });
    return child;
  }
}