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
      // 開く先（add_S 3.4）。data.path があればそこ、無ければライブ詳細
      final path = message.data['path'];
      final liveId = message.data['liveId'];
      final target = path is String && path.startsWith('/')
          ? path
          : (liveId is String && liveId.isNotEmpty ? '/lives/$liveId' : null);
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
          action: target != null
              ? SnackBarAction(
                  label: '開く',
                  onPressed: () => ref.read(routerProvider).go(target),
                )
              : null,
        ),
      );
    });
    return child;
  }
}