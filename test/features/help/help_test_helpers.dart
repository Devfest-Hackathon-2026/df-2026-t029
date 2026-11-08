import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/help/help_button.dart';
import 'package:oshiashi/features/help/help_scope.dart';
import 'package:oshiashi/features/help/help_topic.dart';

Finder key(String k) => find.byKey(Key(k));

void useSize(WidgetTester tester, Size size, {double textScale = 1.0}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// 「?」ボタンだけを置いた最小の画面。[topic] が null なら「?」は出ない
Future<void> pumpHelpButton(
  WidgetTester tester, {
  HelpTopic? topic = HelpTopic.home,
  bool withScope = true,
}) async {
  final link = LayerLink();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: withScope
                ? HakoHelpScope(
                    topic: topic,
                    link: link,
                    child: const HelpButton(),
                  )
                : const HelpButton(),
          ),
        ),
      ),
    ),
  );
}
