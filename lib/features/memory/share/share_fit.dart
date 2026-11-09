import 'package:flutter/widgets.dart';

import '../../../theme/hako_fonts.dart';
import '../../../utils/share_ticket.dart';

/// シェア画像の文字の書式。単位 [u]（画像の幅の 1%）に対する [size] 倍の大きさ。
/// 描くときと、入る行数を測るときで同じ書式を使う（食い違うと、はみ出す・余る）
TextStyle shareJpStyle(
  double u,
  double size, {
  Color color = const Color(0xFF111111),
  double height = 1.35,
  double spacing = 0,
  bool bold = true,
}) {
  return HakoFonts.jp(
    size: size * u,
    weight: bold ? FontWeight.w700 : FontWeight.w400,
    color: color,
    height: height,
    letterSpacing: spacing * u,
  ).copyWith(decoration: TextDecoration.none);
}

/// 自動で絞った結果
class ShareFitResult {
  const ShareFitResult({
    required this.setCount,
    required this.memoLines,
    required this.fit,
  });

  /// 見せるセトリの曲数
  final int setCount;

  /// 感想の最大行数（0 なら感想の枠ごと出さない）
  final int memoLines;

  final ShareFit fit;
}

/// 本文の領域（[width]・[height]。単位は px。余白を引いたあと）に入るセトリ・感想を、
/// `TextPainter` で測って決める。
///
/// 絞る順（4.7）: ①感想の行数を 3→2→1 ②セトリを後ろから1行ずつ（最低1行）
/// ③それでも入らなければ感想の枠ごと出さない。
///
/// 文字の大きさ・余白は `share_ticket_view.dart` の `_Parts.body`・`_setBlock`・
/// `_memoBlock`・`_label` と同じ数値にしてある。
ShareFitResult computeShareFit({
  required double width,
  required double height,
  required double u,
  required bool wide,
  required ShareContent content,
  required ShareConfig config,
  required ShareImageText text,
}) {
  final total = content.setlist.length;
  final showSet =
      config.isOn(SharePart.setlist, ShareLayer.image) &&
      text.setShown.isNotEmpty;
  final showMemo =
      config.isOn(SharePart.memo, ShareLayer.image) &&
      text.memoShown.isNotEmpty;
  ShareFitResult result(int set, int lines) => ShareFitResult(
    setCount: set,
    memoLines: lines,
    fit: ShareFit(
      setShown: showSet ? set : 0,
      setTotal: total,
      memoDropped: showMemo && lines == 0,
    ),
  );
  final initialSet = showSet ? text.setShown.length : 0;
  if (width <= 0 || height <= 0 || u <= 0 || (!showSet && !showMemo)) {
    return result(initialSet, showMemo ? 3 : 0);
  }

  final fs = config.sizes.setlist;
  final titleSize = wide ? 3.3 : 4.6;
  final gap = (wide ? 1.2 : 2) * u;

  double textHeight(String s, TextStyle style, double w, {int? maxLines}) {
    final p = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '…',
    )..layout(maxWidth: w < 1 ? 1 : w);
    final h = p.height;
    p.dispose();
    return h;
  }

  double textWidth(String s, TextStyle style) {
    final p = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final w = p.width;
    p.dispose();
    return w;
  }

  final titleH = textHeight(
    content.title,
    shareJpStyle(u, titleSize, height: 1.35),
    width,
  );

  double labelH(String s) {
    final size = wide ? 1.8 : 2.3;
    return textHeight(
          s,
          shareJpStyle(
            u,
            size,
            color: const Color(0xFF555555),
            height: 1.3,
            spacing: size * 0.16,
          ),
          width,
        ) +
        0.4 * u +
        0.3 * u +
        1 * u;
  }

  // セトリ
  final rowStyle = shareJpStyle(u, (wide ? 2.6 : 3.3) * fs, height: 1.5);
  final songStyle = shareJpStyle(
    u,
    (wide ? 2.6 : 3.3) * fs,
    height: 1.5,
    bold: false,
  );
  final numW = textWidth('00', rowStyle);
  final songs = text.setShown;
  final setLabelH = showSet ? labelH('SET LIST') : 0.0;
  final twoColWidth = (width - 3 * u) / 2;
  List<double> rowHeights(double columnWidth) => [
    for (var i = 0; i < songs.length; i++)
      [
        textHeight('00', rowStyle, numW + 1),
        textHeight(
          songs[i],
          songStyle,
          columnWidth - numW - 1.4 * u,
          maxLines: 2,
        ),
      ].reduce((a, b) => a > b ? a : b),
  ];
  final oneCol = showSet ? rowHeights(width) : const <double>[];
  final twoCol = showSet ? rowHeights(twoColWidth) : const <double>[];

  double sum(List<double> v, int from, int to) {
    var s = 0.0;
    for (var i = from; i < to; i++) {
      s += v[i];
    }
    return s;
  }

  double setHeight(int n) {
    final two = n > 4 && !(wide && config.sizes.photo > 1.2);
    double list;
    if (two) {
      final half = (n + 1) ~/ 2;
      final a = sum(twoCol, 0, half);
      final b = sum(twoCol, half, n);
      list = a > b ? a : b;
    } else {
      list = sum(oneCol, 0, n);
    }
    var more = 0.0;
    if (total - n > 0) {
      more =
          0.6 * u +
          textHeight(
            'ほか${total - n}曲',
            shareJpStyle(
              u,
              (wide ? 2.2 : 2.8) * fs,
              color: const Color(0xFF555555),
              height: 1.4,
              bold: false,
            ),
            width,
          );
    }
    return setLabelH + list + more;
  }

  // 感想
  final memoLabelH = showMemo ? labelH('MEMO') : 0.0;
  final memoPadV = (wide ? 1.0 : 1.4) * u * 2;
  final memoPadH = (wide ? 1.6 : 2.0) * u * 2;
  final memoStyle = shareJpStyle(
    u,
    wide ? 2.5 : 3.2,
    height: 1.55,
    bold: false,
  );
  double memoHeight(int lines) {
    if (lines <= 0) return 0;
    return memoLabelH +
        memoPadV +
        textHeight(
          text.memoShown,
          memoStyle,
          width - memoPadH,
          maxLines: lines,
        );
  }

  double stack(int set, int lines) {
    var h = titleH;
    if (showSet) h += gap + setHeight(set);
    if (showMemo && lines > 0) h += gap + memoHeight(lines);
    return h;
  }

  bool fits(int set, int lines) => stack(set, lines) <= height + 0.5;

  var set = initialSet;
  var lines = showMemo ? 3 : 0;
  while (!fits(set, lines) && lines > 1) {
    lines--;
  }
  while (!fits(set, lines) && set > 1) {
    set--;
  }
  if (showMemo && !fits(set, lines)) lines = 0;
  return result(set, lines);
}
