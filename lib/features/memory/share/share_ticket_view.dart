import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../theme/brand_colors.dart' show onThemeColor;
import '../../../theme/hako_fonts.dart';
import '../../../utils/share_ticket.dart';
import 'share_fit.dart';

/// シェア画像の背景色（見本の `BGS`。0:きいろ 1:みどり 2:ピンク 3:くろ）
const shareBackgrounds = [
  Color(0xFFF5D31A), // きいろ
  Color(0xFF2DBE7E), // みどり
  Color(0xFFF27CB1), // ピンク
  Color(0xFFE5484D), // 赤
  Color(0xFF3B82F6), // 青
  Color(0xFFF97316), // オレンジ
  Color(0xFF8B5CF6), // 紫
];

/// 背景色の名前（[shareBackgrounds] と同じ並び）
const shareBackgroundNames = ['きいろ', 'みどり', 'ピンク', '赤', '青', 'オレンジ', '紫'];

const _ink = Color(0xFF111111);
const _paper = Color(0xFFFFF9EA);
const _gray = Color(0xFF555555);
const _hover = Color(0xFF1D4ED8);

/// シェア画像（チケットのデザイン）。プレビュー・ホームのミニのカード・
/// 保存する画像で共通。**座席の引数は無い**（座席は SNS に出さない）。
///
/// 大きさは親の幅いっぱい（比率は [target] と `config.formatIndex` で決まる）。
/// 文字・余白は幅の 1%（`unit = width / 100`）を単位にした割合で決め、
/// 端末の文字の拡大には影響されない。外側の枠線・影は付けない（呼び出し側で付ける）。
class ShareTicketView extends StatefulWidget {
  const ShareTicketView({
    super.key,
    required this.content,
    required this.config,
    required this.target,
    required this.photoBytes,
    this.hints = false,
    this.mini = false,
    this.onTapPart,
    this.onFit,
  });

  final ShareContent content;
  final ShareConfig config;
  final ShareTarget target;

  /// 表紙から順。描く前に読み込み済みのもの（先頭4枚まで使う）
  final List<Uint8List> photoBytes;

  /// チケットのデザインで、自動で絞った結果を知らせる（プレビューだけが渡す）。
  /// 同じ値が続くときは呼ばない。呼ぶのは描いたあと
  final ValueChanged<ShareFit>? onFit;

  /// 空の枠（+ セトリを書く…）とタップの枠線を出す（プレビューだけ）
  final bool hints;

  /// ホームのカード用（[hints] は無視する）
  final bool mini;

  /// photo・setlist・memo の部分をタップしたとき（[hints] のときだけ）
  final void Function(SharePart part)? onTapPart;

  @override
  State<ShareTicketView> createState() => _ShareTicketViewState();
}

class _ShareTicketViewState extends State<ShareTicketView> {
  ShareFit? _lastFit;

  /// 自動で絞った結果を、描いたあとに1回だけ知らせる（同じ値は重ねて呼ばない）
  void _report(ShareFit fit) {
    final cb = widget.onFit;
    if (cb == null || fit == _lastFit) return;
    _lastFit = fit;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.onFit == null) return;
      widget.onFit!(fit);
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    final config = widget.config;
    final target = widget.target;
    final hints = widget.hints;
    final mini = widget.mini;
    final onTapPart = widget.onTapPart;
    final photoBytes = widget.photoBytes;
    final formats = shareFormats[target]!;
    final format = formats[config.formatIndex.clamp(0, formats.length - 1)];
    final showHints = hints && !mini;
    return MediaQuery.withNoTextScaling(
      child: DefaultTextStyle(
        style: HakoFonts.jp(size: 12).copyWith(decoration: TextDecoration.none),
        child: Semantics(
          image: true,
          label: '投稿する画像のプレビュー',
          child: AspectRatio(
            aspectRatio: format.aspectW / format.aspectH,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final u = constraints.maxWidth / 100;
                return ClipRect(
                  child: _Shot(
                    u: u,
                    content: content,
                    config: config,
                    format: format,
                    photos: photoBytes.take(kShareMaxPhotos).toList(),
                    hints: showHints,
                    onTapPart: showHints ? onTapPart : null,
                    onFit: widget.onFit == null ? null : _report,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 描き終わっている [RepaintBoundary]（[boundaryKey]）を PNG にする。
/// [pixelRatio] は「保存する幅 ÷ 表示の幅」。写真は呼び出し前に
/// [precacheShareImages] で読み込んでおく
Future<Uint8List> captureShareImage(
  GlobalKey boundaryKey, {
  required double pixelRatio,
}) async {
  final boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) {
    throw StateError('画像にする部分が見つかりません');
  }
  // 描き終わるまで待つ（描き直しが残っていると、空白の画像になる）
  var tries = 0;
  while (boundary.debugNeedsPaint && tries < 20) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    tries++;
  }
  await WidgetsBinding.instance.endOfFrame;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('画像にできませんでした');
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// 写真のバイト列を、描く前に読み込んでおく（読み込み前に PNG にすると空白になる）。
/// 読み込めない写真があっても止めない
Future<void> precacheShareImages(
  BuildContext context,
  List<Uint8List> photos,
) async {
  for (final bytes in photos.take(kShareMaxPhotos)) {
    try {
      await precacheImage(MemoryImage(bytes), context);
    } catch (_) {
      // 読めない写真は、描くときに空の枠になる
    }
  }
}

// ---------------------------------------------------------------------------
// 本体
// ---------------------------------------------------------------------------

class _Shot extends StatelessWidget {
  const _Shot({
    required this.u,
    required this.content,
    required this.config,
    required this.format,
    required this.photos,
    required this.hints,
    required this.onTapPart,
    required this.onFit,
  });

  final double u;
  final ShareContent content;
  final ShareConfig config;
  final ShareFormat format;
  final List<Uint8List> photos;
  final bool hints;
  final void Function(SharePart part)? onTapPart;
  final ValueChanged<ShareFit>? onFit;

  bool get _wide => format.aspectW > format.aspectH;

  /// 縦長の形ごとの「写真の高さ」と「半券の高さ」（単位は u）
  (double, double) get _verticalRows {
    final ratio = format.aspectW / format.aspectH;
    if (ratio >= 0.9) return (25, 19); // 1:1
    if (ratio >= 0.7) return (30, 20); // 4:5
    return (54, 26); // 9:16
  }

  @override
  Widget build(BuildContext context) {
    final bg =
        shareBackgrounds[config.backgroundIndex.clamp(
          0,
          shareBackgrounds.length - 1,
        )];
    final sa = bg;
    final inset = (_wide ? 4 : 5) * u;
    final text = layoutShareText(content, format, design: config.design);
    final sizes = config.sizes;
    final parts = _Parts(
      u: u,
      wide: _wide,
      content: content,
      config: config,
      text: text,
      photos: photos,
      hints: hints,
      onTapPart: onTapPart,
      accent: sa,
      onFit: onFit,
    );
    if (config.design == ShareDesign.photoMain) return parts.photoMain();
    final Widget ticket;
    if (_wide) {
      final stubWidth = 25 * u * sizes.info;
      // 写真の欄の幅は、本文の行の幅の 34% × 写真の大きさ（のこりが本文）
      final heroFlex = (34 * sizes.photo * 1000).round();
      final bodyFlex = ((100 - 34 * sizes.photo) * 1000).round();
      ticket = _TicketFrame(
        u: u,
        wide: true,
        stubExtent: stubWidth,
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  parts.topBar(),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: heroFlex,
                          child: parts.hero(rightBorder: true),
                        ),
                        Expanded(flex: bodyFlex, child: parts.body()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: stubWidth, child: parts.stub()),
          ],
        ),
      );
    } else {
      final (heroH, stubH) = _verticalRows;
      ticket = _TicketFrame(
        u: u,
        wide: false,
        stubExtent: stubH * sizes.info * u,
        child: Column(
          children: [
            parts.topBar(),
            SizedBox(height: heroH * sizes.photo * u, child: parts.hero()),
            Expanded(child: parts.body()),
            SizedBox(height: stubH * sizes.info * u, child: parts.stub()),
          ],
        ),
      );
    }
    return ColoredBox(
      color: bg,
      child: Padding(padding: EdgeInsets.all(inset), child: ticket),
    );
  }
}

/// チケットの外形（角丸・半券の切り欠き・縁取り・影）
class _TicketFrame extends StatelessWidget {
  const _TicketFrame({
    required this.u,
    required this.wide,
    required this.stubExtent,
    required this.child,
  });

  final double u;
  final bool wide;
  final double stubExtent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final path = _ticketPath(constraints.biggest, u, wide, stubExtent);
        return CustomPaint(
          painter: _TicketPainter(path, u),
          child: ClipPath(clipper: _PathClipper(path), child: child),
        );
      },
    );
  }
}

Path _ticketPath(Size s, double u, bool wide, double stub) {
  var path = Path()
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(2.2 * u)),
    );
  final r = (wide ? 3.0 : 3.4) * u;
  final holes = wide
      ? [Offset(s.width - stub, 0), Offset(s.width - stub, s.height)]
      : [Offset(0, s.height - stub), Offset(s.width, s.height - stub)];
  for (final h in holes) {
    path = Path.combine(
      PathOperation.difference,
      path,
      Path()..addOval(Rect.fromCircle(center: h, radius: r)),
    );
  }
  return path;
}

class _PathClipper extends CustomClipper<Path> {
  const _PathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PathClipper oldClipper) => oldClipper.path != path;
}

class _TicketPainter extends CustomPainter {
  const _TicketPainter(this.path, this.u);

  final Path path;
  final double u;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = u * 1.0; // 縁取り .5u（外側）を、中心線の太さ 1u で描く
    final shadow = Paint()..color = const Color(0x47000000);
    final shadowStroke = Paint()
      ..color = const Color(0x47000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = outline;
    final shifted = path.shift(Offset(0.9 * u, 1.3 * u));
    canvas.drawPath(shifted, shadow);
    canvas.drawPath(shifted, shadowStroke);
    canvas.drawPath(
      path,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = outline,
    );
    canvas.drawPath(path, Paint()..color = _paper);
  }

  @override
  bool shouldRepaint(_TicketPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.u != u;
}

// ---------------------------------------------------------------------------
// 各部分
// ---------------------------------------------------------------------------

class _Parts {
  const _Parts({
    required this.u,
    required this.wide,
    required this.content,
    required this.config,
    required this.text,
    required this.photos,
    required this.hints,
    required this.onTapPart,
    required this.accent,
    required this.onFit,
  });

  final double u;
  final bool wide;
  final ShareContent content;
  final ShareConfig config;
  final ShareImageText text;
  final List<Uint8List> photos;
  final bool hints;
  final void Function(SharePart part)? onTapPart;
  final Color accent;
  final ValueChanged<ShareFit>? onFit;

  bool _on(SharePart p) => config.isOn(p, ShareLayer.image);

  ShareSizes get _sizes => config.sizes;

  TextStyle _jp(
    double size, {
    Color color = _ink,
    double height = 1.35,
    double spacing = 0,
    bool bold = true,
  }) => shareJpStyle(
    u,
    size,
    color: color,
    height: height,
    spacing: spacing,
    bold: bold,
  );

  /// 上の帯（黒地・「LIVE TICKET」・「参戦済み」）
  Widget topBar() {
    final fs = wide ? 2.0 : 2.6;
    return Container(
      color: _ink,
      padding: EdgeInsets.symmetric(
        vertical: (wide ? 1.0 : 1.6) * u,
        horizontal: (wide ? 3.0 : 3.4) * u,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'LIVE TICKET',
            maxLines: 1,
            style: HakoFonts.en(
              size: fs * u,
              weight: FontWeight.w700,
              color: Colors.white,
              height: 1.3,
              letterSpacing: fs * 0.14 * u,
            ).copyWith(decoration: TextDecoration.none),
          ),
          Transform.rotate(
            angle: -3 * math.pi / 180,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 1.4 * u),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 0.4 * u),
                borderRadius: BorderRadius.circular(1 * u),
              ),
              child: Text(
                '参戦済み',
                maxLines: 1,
                style: _jp(
                  fs,
                  color: Colors.white,
                  height: 1.3,
                  spacing: fs * 0.05,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 写真の欄（1・2・3枚・0枚）
  Widget hero({bool rightBorder = false}) {
    final shown = _on(SharePart.photo)
        ? photos.take(kShareMaxPhotos).toList()
        : const <Uint8List>[];
    final Widget inner;
    if (shown.isEmpty) {
      inner = _emptyHero();
    } else {
      Widget img(int i) => Image.memory(
        shown[i],
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            const ColoredBox(color: Color(0xFFD8D2BF)),
      );
      final gap = SizedBox(width: 0.5 * u, height: 0.5 * u);
      inner = switch (shown.length) {
        1 => img(0),
        2 => Row(
          children: [
            Expanded(child: img(0)),
            gap,
            Expanded(child: img(1)),
          ],
        ),
        3 => Row(
          children: [
            Expanded(flex: 2, child: img(0)),
            gap,
            Expanded(
              child: Column(
                children: [
                  Expanded(child: img(1)),
                  gap,
                  Expanded(child: img(2)),
                ],
              ),
            ),
          ],
        ),
        // 4枚は 2×2（同じ大きさ）
        _ => Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: img(0)),
                  gap,
                  Expanded(child: img(1)),
                ],
              ),
            ),
            gap,
            Expanded(
              child: Row(
                children: [
                  Expanded(child: img(2)),
                  gap,
                  Expanded(child: img(3)),
                ],
              ),
            ),
          ],
        ),
      };
    }
    return _part(
      SharePart.photo,
      Container(
        decoration: BoxDecoration(
          color: _ink,
          border: Border(
            bottom: rightBorder
                ? BorderSide.none
                : BorderSide(color: _ink, width: 0.5 * u),
            right: rightBorder
                ? BorderSide(color: _ink, width: 0.5 * u)
                : BorderSide.none,
          ),
        ),
        child: inner,
      ),
    );
  }

  Widget _emptyHero() {
    final label = (content.artist != null && content.artist!.trim().isNotEmpty)
        ? content.artist!.trim()
        : content.title.characters.take(10).toString();
    return CustomPaint(
      painter: _StripePainter(accent, u),
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              margin: EdgeInsets.symmetric(horizontal: 2 * u),
              padding: EdgeInsets.symmetric(horizontal: 2 * u),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _ink, width: 0.5 * u),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _jp(5.4, height: 1.4),
              ),
            ),
            SizedBox(height: 1 * u),
            Text(
              hints ? '写真を選ぶ' : 'LIVE',
              style: _jp(2.8, height: 1.3, spacing: 0.56),
            ),
          ],
        ),
      ),
    );
  }

  /// 本文（ライブ名・セトリ・感想）
  Widget body() {
    final titleSize = wide ? 3.3 : 4.6;
    final hasSet = content.setlist.isNotEmpty;
    final hasMemo = (content.impression ?? '').trim().isNotEmpty;
    final showSet = _on(SharePart.setlist) && (hasSet || hints);
    final showMemo = _on(SharePart.memo) && (hasMemo || hints);
    final padH = (wide ? 2.4 : 3.4) * u;
    final padV = (wide ? 1.8 : 2.4) * u;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 入るかを測って、セトリの曲数・感想の行数を決める（空の枠は絞らない）
          ShareFitResult? fit;
          if (constraints.hasBoundedHeight &&
              !(hints && (!hasSet || !hasMemo))) {
            fit = computeShareFit(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              u: u,
              wide: wide,
              content: content,
              config: config,
              text: text,
            );
            onFit?.call(fit.fit);
          }
          final setCount = fit?.setCount ?? text.setShown.length;
          final memoLines = fit?.memoLines ?? 3;
          final memoVisible = showMemo && (!hasMemo || memoLines > 0);
          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(content.title, style: _jp(titleSize, height: 1.35)),
                  if (showSet) ...[
                    SizedBox(height: (wide ? 1.2 : 2) * u),
                    _part(
                      SharePart.setlist,
                      hasSet
                          ? _setBlock(setCount)
                          : _emptyBlock('SET LIST', '+ セトリを書く'),
                    ),
                  ],
                  if (memoVisible) ...[
                    SizedBox(height: (wide ? 1.2 : 2) * u),
                    _part(
                      SharePart.memo,
                      hasMemo
                          ? _memoBlock(memoLines)
                          : _emptyBlock('MEMO', '+ 感想を書く'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _label(String s) {
    return Container(
      margin: EdgeInsets.only(bottom: 1 * u),
      padding: EdgeInsets.only(bottom: 0.4 * u),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _ink, width: 0.3 * u),
        ),
      ),
      child: Text(
        s,
        style: _jp(
          wide ? 1.8 : 2.3,
          color: _gray,
          height: 1.3,
          spacing: (wide ? 1.8 : 2.3) * 0.16,
        ),
      ),
    );
  }

  Widget _setBlock(int count) {
    final fs = (wide ? 2.6 : 3.3) * _sizes.setlist;
    final shown = text.setShown.take(count).toList();
    final more = content.setlist.length - shown.length;
    // 2列に分ける（5行以上）。横長で写真が 120% を超えるときは1列
    final twoCols = shown.length > 4 && !(wide && _sizes.photo > 1.2);
    Widget row(int i) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (i + 1).toString().padLeft(2, '0'),
          style: _jp(fs, color: _gray, height: 1.5),
        ),
        SizedBox(width: 1.4 * u),
        Expanded(
          child: Text(
            shown[i],
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _jp(fs, height: 1.5, bold: false),
          ),
        ),
      ],
    );
    final Widget list;
    if (twoCols) {
      final half = (shown.length + 1) ~/ 2;
      list = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(children: [for (var i = 0; i < half; i++) row(i)]),
          ),
          SizedBox(width: 3 * u),
          Expanded(
            child: Column(
              children: [for (var i = half; i < shown.length; i++) row(i)],
            ),
          ),
        ],
      );
    } else {
      list = Column(children: [for (var i = 0; i < shown.length; i++) row(i)]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label('SET LIST'),
        list,
        if (more > 0)
          Padding(
            padding: EdgeInsets.only(top: 0.6 * u),
            child: Text(
              'ほか$more曲',
              style: _jp(
                (wide ? 2.2 : 2.8) * _sizes.setlist,
                color: _gray,
                height: 1.4,
                bold: false,
              ),
            ),
          ),
      ],
    );
  }

  Widget _memoBlock(int lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label('MEMO'),
        CustomPaint(
          painter: _DashedRRectPainter(_ink, 0.4 * u, 1.4 * u),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: (wide ? 1.0 : 1.4) * u,
              horizontal: (wide ? 1.6 : 2.0) * u,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1.4 * u),
            ),
            child: Text(
              text.memoShown,
              maxLines: lines,
              overflow: TextOverflow.ellipsis,
              style: _jp(wide ? 2.5 : 3.2, height: 1.55, bold: false),
            ),
          ),
        ),
      ],
    );
  }

  /// 空の枠（プレビューだけ）
  Widget _emptyBlock(String label, String hint) {
    return CustomPaint(
      painter: _DashedRRectPainter(_ink, 0.4 * u, 1.4 * u),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 1.4 * u, horizontal: 2 * u),
        decoration: BoxDecoration(
          color: const Color(0xB3FFFFFF),
          borderRadius: BorderRadius.circular(1.4 * u),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _label(label),
            Text(hint, style: _jp(3.2, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _photoImage(Uint8List bytes) => Image.memory(
    bytes,
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    gaplessPlayback: true,
    errorBuilder: (context, error, stackTrace) =>
        const ColoredBox(color: Color(0xFFD8D2BF)),
  );

  Widget _markChip() => Container(
    padding: EdgeInsets.symmetric(horizontal: 1.6 * u, vertical: 0.4 * u),
    decoration: BoxDecoration(
      color: _ink,
      borderRadius: BorderRadius.circular(1 * u),
    ),
    child: Text(
      'おしあし',
      maxLines: 1,
      style: _jp(2.6, color: Colors.white, height: 1.3),
    ),
  );

  /// 「日付・会場」の1行（写真メイン・コラージュ）
  String get _infoLine =>
      '${formatShareDate(content.startAt)}・${content.venue}';

  List<String> _extras() {
    final out = <String>[];
    if (_on(SharePart.setlist) && content.setlist.isNotEmpty) {
      out.add(
        'SET: ${text.setShown.join(' / ')}'
        '${text.setMore > 0 ? ' ほか${text.setMore}曲' : ''}',
      );
    }
    if (_on(SharePart.memo) && (content.impression ?? '').trim().isNotEmpty) {
      out.add(text.memoShown);
    }
    return out;
  }

  /// デザイン「写真メイン」（見本の `.dz1`）
  Widget photoMain() {
    final cover = _on(SharePart.photo) && photos.isNotEmpty
        ? photos.first
        : null;
    final extras = _extras();
    final setOn = extras.isNotEmpty && extras.first.startsWith('SET: ');
    Widget ex(String t, SharePart part) => _part(
      part,
      Container(
        margin: EdgeInsets.only(top: 2 * u),
        padding: EdgeInsets.symmetric(
          horizontal: (wide ? 2.0 : 2.4) * u,
          vertical: (wide ? 1.0 : 1.4) * u,
        ),
        decoration: BoxDecoration(
          color: const Color(0x2EFFFFFF),
          borderRadius: BorderRadius.circular(2 * u),
        ),
        child: Text(
          t,
          style: _jp(
            (wide ? 2.6 : 3.3) * _sizes.setlist,
            color: Colors.white,
            height: 1.55,
            bold: false,
          ),
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _part(
            SharePart.photo,
            cover == null
                ? const ColoredBox(color: Color(0xFF2B1D63))
                : _photoImage(cover),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xE0000000)],
                  stops: [0.3, 1.0],
                ),
              ),
            ),
          ),
        ),
        if (_on(SharePart.mark))
          Positioned(top: 3 * u, right: 3 * u, child: _markChip()),
        Positioned(
          left: 5 * u,
          right: 5 * u,
          bottom: (wide ? 3 : 5) * u,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                content.title,
                style: _jp(wide ? 4 : 6, color: Colors.white),
              ),
              if (config.isOn(SharePart.info, ShareLayer.image))
                Padding(
                  padding: EdgeInsets.only(top: 1.4 * u),
                  child: Text(
                    _infoLine,
                    style: _jp(
                      (wide ? 2.8 : 3.6) * _sizes.info,
                      color: Colors.white,
                      height: 1.4,
                      bold: false,
                    ),
                  ),
                ),
              for (var i = 0; i < extras.length; i++)
                ex(
                  extras[i],
                  (setOn && i == 0) ? SharePart.setlist : SharePart.memo,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 半券（日付・会場・バーコード風の縞・「おしあし」マーク）
  Widget stub() {
    // 背景色の上に直接乗る文字・線は、背景の明るさで黒か白を選ぶ
    final fg = onThemeColor(accent);
    final info = config.isOn(SharePart.info, ShareLayer.image);
    final mark = _on(SharePart.mark);
    final date = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatShareDate(content.startAt),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HakoFonts.en(
            size: (wide ? 4.6 : 6.4) * _sizes.info * u,
            weight: FontWeight.w700,
            color: fg,
            height: 1.0,
          ).copyWith(decoration: TextDecoration.none),
        ),
        SizedBox(height: 1 * u),
        Text(
          content.venue,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _jp((wide ? 2.3 : 2.7) * _sizes.info, color: fg, height: 1.3),
        ),
      ],
    );
    final markWidget = Container(
      padding: EdgeInsets.symmetric(horizontal: 1.6 * u, vertical: 0.4 * u),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(1 * u),
      ),
      child: Text(
        'おしあし',
        maxLines: 1,
        style: _jp(wide ? 2.0 : 2.6, color: Colors.white, height: 1.3),
      ),
    );
    if (wide) {
      return CustomPaint(
        foregroundPainter: _DashedLinePainter(
          fg,
          0.5 * u,
          vertical: true,
          atStart: true,
        ),
        child: Container(
          color: accent,
          padding: EdgeInsets.symmetric(horizontal: 2.6 * u, vertical: 2 * u),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (info) ...[date, SizedBox(height: 1.6 * u)],
              SizedBox(
                width: double.infinity,
                height: 6 * u,
                child: CustomPaint(painter: _BarsPainter(u, fg)),
              ),
              if (mark) ...[SizedBox(height: 1.6 * u), markWidget],
            ],
          ),
        ),
      );
    }
    return CustomPaint(
      foregroundPainter: _DashedLinePainter(
        fg,
        0.5 * u,
        vertical: false,
        atStart: true,
      ),
      child: Container(
        color: accent,
        padding: EdgeInsets.fromLTRB(3.4 * u, 0.5 * u, 3.4 * u, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (info)
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: date),
              )
            else
              const Spacer(),
            if (info) SizedBox(width: 2.4 * u),
            Center(
              child: FractionallySizedBox(
                heightFactor: 0.55,
                child: SizedBox(
                  width: 20 * u,
                  child: CustomPaint(painter: _BarsPainter(u, fg)),
                ),
              ),
            ),
            if (mark) ...[
              SizedBox(width: 2.4 * u),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 2 * u),
                  child: markWidget,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _part(SharePart part, Widget child) {
    if (!hints || onTapPart == null) return child;
    final (key, label) = switch (part) {
      SharePart.photo => (const Key('share_part_photo'), '写真を直す'),
      SharePart.setlist => (const Key('share_part_setlist'), 'セトリを直す'),
      _ => (const Key('share_part_memo'), '感想を直す'),
    };
    return _TapPart(
      tapKey: key,
      label: label,
      u: u,
      onTap: () => onTapPart!(part),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// タップできる部分（ホバー・フォーカスで青の破線の枠）
// ---------------------------------------------------------------------------

class _TapPart extends StatefulWidget {
  const _TapPart({
    required this.tapKey,
    required this.label,
    required this.u,
    required this.onTap,
    required this.child,
  });

  final Key tapKey;
  final String label;
  final double u;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_TapPart> createState() => _TapPartState();
}

class _TapPartState extends State<_TapPart> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _focused;
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          key: widget.tapKey,
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: CustomPaint(
            foregroundPainter: active
                ? _DashedRRectPainter(
                    _hover,
                    0.7 * widget.u,
                    0,
                    inset: 0.35 * widget.u,
                    dashFactor: 2,
                  )
                : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 描画
// ---------------------------------------------------------------------------

/// 破線の角丸の枠
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter(
    this.color,
    this.width,
    this.radius, {
    this.inset = 0,
    this.dashFactor = 3,
  });

  final Color color;
  final double width;
  final double radius;
  final double inset;
  final double dashFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    if (rect.width <= 0 || rect.height <= 0) return;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final dash = width * dashFactor;
    final gap = width * 2;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color ||
      old.width != width ||
      old.radius != radius ||
      old.inset != inset;
}

/// 半券の境目の破線（上、または左）
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(
    this.color,
    this.width, {
    required this.vertical,
    required this.atStart,
  });

  final Color color;
  final double width;
  final bool vertical;
  final bool atStart;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    final dash = width * 3;
    final gap = width * 2;
    final length = vertical ? size.height : size.width;
    var d = 0.0;
    while (d < length) {
      final end = math.min(d + dash, length);
      if (vertical) {
        canvas.drawLine(Offset(width / 2, d), Offset(width / 2, end), paint);
      } else {
        canvas.drawLine(Offset(d, width / 2), Offset(end, width / 2), paint);
      }
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) =>
      old.color != color || old.width != width || old.vertical != vertical;
}

/// バーコード風の縞（3.6u ごとの繰り返し）
class _BarsPainter extends CustomPainter {
  const _BarsPainter(this.u, this.color);

  final double u;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const bars = [(0.0, 0.5), (1.0, 2.0), (2.4, 2.7)];
    final period = 3.6 * u;
    for (var x = 0.0; x < size.width; x += period) {
      for (final (a, b) in bars) {
        final left = x + a * u;
        if (left >= size.width) continue;
        canvas.drawRect(
          Rect.fromLTRB(left, 0, math.min(x + b * u, size.width), size.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.u != u || old.color != color;
}

/// 写真が0枚のときの、背景色のしま模様
class _StripePainter extends CustomPainter {
  const _StripePainter(this.color, this.u);

  final Color color;
  final double u;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 4);
    final reach = size.width + size.height;
    final light = Paint()..color = const Color(0x73FFFFFF);
    for (var x = -reach; x < reach; x += 4 * u) {
      canvas.drawRect(
        Rect.fromLTRB(x + 2 * u, -reach, x + 4 * u, reach),
        light,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.color != color || old.u != u;
}
