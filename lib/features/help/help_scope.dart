import 'package:flutter/widgets.dart';

import 'help_topic.dart';

/// 中の画面に「今の話題」と、吹き出しが指す先の印を渡す（HakoHue と同じ作り）
class HakoHelpScope extends InheritedWidget {
  const HakoHelpScope({
    super.key,
    required this.topic,
    required this.link,
    required super.child,
  });

  /// null なら「?」を出さない
  final HelpTopic? topic;

  /// 「?」ボタンが CompositedTransformTarget に渡す印
  final LayerLink link;

  static HakoHelpScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HakoHelpScope>();

  @override
  bool updateShouldNotify(HakoHelpScope oldWidget) =>
      topic != oldWidget.topic || link != oldWidget.link;
}
