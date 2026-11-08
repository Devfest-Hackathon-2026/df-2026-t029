// 紹介ページ（/welcome）。ログインしていない人が最初に見るページ（案6「ハコ色」）。
//
// 構成: 色の帯 → ヘッダー → 最初の画面 → 6つのハコ → 「始める」の区画 → 色の帯
// 画面の移動:
//   「始める」→ /login?mode=signup、右上の「ログイン」→ /login
// 書体・色・部品は lib/theme/（HakoFonts・BrandColors・hako_widgets.dart）を使う。

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import '../../theme/hako_widgets.dart';

/// 紹介ページ
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return HakoPage(
      key: const Key('welcome_page'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          const _Hero(),
          const _HallGrid(),
          const _Cta(),
        ],
      ),
    );
  }
}

/// 広い画面で横幅を使う枠。左右の余白は、幅に応じて 20（〜599）・40（〜899）・64（900〜）。
/// 中身は maxWidth（既定 1100）までで、中央に置く
class _Wide extends StatelessWidget {
  const _Wide({required this.child, this.maxWidth = 1100});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = width >= 900 ? 64.0 : (width >= 600 ? 40.0 : 20.0);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return _Wide(
      maxWidth: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 狭い画面・大きい文字では、はみ出さないよう縮める
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'おしあし',
                  style: HakoFonts.jp(
                    size: 32,
                    weight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            HakoPill(
              key: const Key('welcome_login_button'),
              label: 'ログイン',
              fontSize: 18,
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 掲示板の1行
class _BoardRow {
  const _BoardRow(this.date, this.label, this.color, this.text);
  final String date;
  final String label;
  final Color color;
  final String text;
}

// 架空の名前。実在の名前に変えない
const _boardRows = [
  _BoardRow('11.20', '入金', BrandColors.hall4, '「ひかりの夜」東京公演'),
  _BoardRow('11.24', '申込', BrandColors.hall1, '「ミナト・ツアー」大阪'),
  _BoardRow('11.30', '当落', BrandColors.hall3, '「ひかりの夜」追加公演'),
];

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final h1Size = wide ? 56.0 : 40.0;
    final h1 = HakoFonts.jp(
      size: h1Size,
      weight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.8,
    );
    return _Wide(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 28, 0, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('推し活の予定を、', style: h1),
                  // 蛍光ペン: 文字の幅＋左右 2px、高さ 0.34em、行の下端から 5px 上
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: -2,
                        right: -2,
                        bottom: 5,
                        height: h1Size * 0.34,
                        child: const ColoredBox(color: BrandColors.hall3),
                      ),
                      Text('もう逃さない。', style: h1),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 560 : 330),
              child: Text(
                '申込、当落、入金。ばらばらの締切を、ひとつの掲示板にまとめます。',
                style: HakoFonts.jp(size: wide ? 17 : 15),
              ),
            ),
            const SizedBox(height: 28),
            Semantics(
              label: '締切の表示例',
              excludeSemantics: true,
              child: Container(
                key: const Key('welcome_board'),
                width: double.infinity,
                color: BrandColors.ink,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(bottom: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: BrandColors.boardRule),
                        ),
                      ),
                      child: Text(
                        "TODAY'S 締切",
                        style: HakoFonts.en(
                          size: 12,
                          color: BrandColors.hall3,
                          height: 1.4,
                          letterSpacing: 12 * 0.14,
                        ),
                      ),
                    ),
                    for (var i = 0; i < _boardRows.length; i++)
                      _BoardRowView(
                        row: _boardRows[i],
                        last: i == _boardRows.length - 1,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardRowView extends StatelessWidget {
  const _BoardRowView({required this.row, required this.last});

  final _BoardRow row;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: BrandColors.boardRow)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 62,
            child: Text(
              row.date,
              style: HakoFonts.en(
                size: 15,
                weight: FontWeight.w700,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 54,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: row.color,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              row.label,
              style: HakoFonts.jp(
                size: 12,
                weight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              row.text,
              style: HakoFonts.jp(size: 14, color: Colors.white, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 6つのハコの内容
class _HallData {
  const _HallData({
    required this.color,
    required this.top,
    required this.bottom,
    required this.title,
    required this.titleSize,
    required this.description,
    required this.enLabel,
  });
  final Color color;
  final double top;
  final double bottom;
  final String title;
  final double titleSize;
  final String description;
  final String enLabel;
}

const _halls = [
  _HallData(
    color: BrandColors.hall1,
    top: 40,
    bottom: 44,
    title: '推しをフォロー',
    titleSize: 30,
    description: '推しを探してフォロー。見つからなければ追加を申請できます。',
    enLabel: 'FOLLOW',
  ),
  _HallData(
    color: BrandColors.hall2,
    top: 26,
    bottom: 28,
    title: 'スクショから読み取り',
    titleSize: 30,
    description: '告知画像やチケットサイトのスクショから、日程・申込期限・入金期限を AI が読み取ります。',
    enLabel: 'SCAN',
  ),
  _HallData(
    color: BrandColors.hall3,
    top: 26,
    bottom: 40,
    title: '次の締切が、ひと目で',
    titleSize: 34,
    description: '申込 → 当落 → 入金。次にやることの期限が分かります。',
    enLabel: 'DUE',
  ),
  _HallData(
    color: BrandColors.hall4,
    top: 26,
    bottom: 28,
    title: 'みんなで共有',
    titleSize: 30,
    description: '同じ推しのファンが登録したライブを、自分の一覧に追加できます。',
    enLabel: 'SHARE',
  ),
  _HallData(
    color: BrandColors.hall5,
    top: 20,
    bottom: 20,
    title: 'Google カレンダーに追加',
    titleSize: 26,
    description: '',
    enLabel: 'CALENDAR',
  ),
  _HallData(
    color: BrandColors.hall6,
    top: 26,
    bottom: 40,
    title: 'グッズ交換',
    titleSize: 30,
    description: '「譲」「求」を登録すると、交換できる相手が見つかります。',
    enLabel: 'TRADE',
  ),
];

/// 6つのハコの並び。幅 600 以上は3列（2行）、600 未満は1列。
/// 隙間なしで敷き詰め、同じ行のハコは高さをそろえる。全幅を使う（HakoContent で包まない）
class _HallGrid extends StatelessWidget {
  const _HallGrid();

  static int columnsFor(double width) {
    return width >= 600 ? 3 : 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(constraints.maxWidth);
        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _halls.length; i++)
                _Hall(
                  index: i,
                  width: constraints.maxWidth,
                  singleColumn: true,
                ),
            ],
          );
        }
        // 各ハコの幅を決まった値（SizedBox）にしてから IntrinsicHeight で高さをそろえる。
        // Expanded のままだと、IntrinsicHeight が実際より広い幅で折り返しを測り、あふれることがある
        final cellWidth = constraints.maxWidth / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var start = 0; start < _halls.length; start += columns)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = start; i < start + columns; i++)
                      SizedBox(
                        width: cellWidth,
                        child: _Hall(index: i, width: cellWidth),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Hall extends StatelessWidget {
  const _Hall({
    required this.index,
    required this.width,
    this.singleColumn = false,
  });

  final int index;

  /// このハコの幅（説明文の幅を決めるのに使う）
  final double width;

  /// 1列で並べているか
  final bool singleColumn;

  @override
  Widget build(BuildContext context) {
    final data = _halls[index];
    final n = (index + 1).toString().padLeft(2, '0');
    final labelStyle = HakoFonts.en(
      size: 12,
      height: 1.4,
      letterSpacing: 12 * 0.14,
    );
    return Container(
      key: Key('welcome_hall_${index + 1}'),
      color: data.color,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned(
            right: 16,
            bottom: 6,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Text(
                  n,
                  style: HakoFonts.en(
                    size: 84,
                    weight: FontWeight.w900,
                    color: BrandColors.ink.withValues(alpha: 0.18),
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, data.top, 20, data.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  // 狭いハコでは、右の英単語が次の行に折り返す
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 2,
                    children: [
                      Text('HALL $n', style: labelStyle),
                      Text(data.enLabel, style: labelStyle),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    top: 10,
                    bottom: data.description.isEmpty ? 0 : 6,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      data.title,
                      style: HakoFonts.jp(
                        size: data.titleSize,
                        weight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
                if (data.description.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      // 1列のときだけ 300 までに絞る。複数列では、幅 300 に絞ると
                      // IntrinsicHeight が折り返しの行数を読み違えてあふれる（幅 1280・文字 1.3 倍で確認）ので、ハコの幅いっぱいにする
                      width: singleColumn
                          ? math.min(300, width - 40)
                          : width - 40,
                      child: Text(
                        data.description,
                        style: HakoFonts.jp(size: 15),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 「始める」の区画
class _Cta extends StatelessWidget {
  const _Cta();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BrandColors.ink,
      padding: const EdgeInsets.fromLTRB(0, 40, 0, 36),
      child: _Wide(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '6つのハコ、まとめて入場。',
              key: const Key('welcome_cta_note'),
              style: HakoFonts.jp(size: 14, color: BrandColors.onInkSub),
            ),
            const SizedBox(height: 14),
            const _StartButton(),
          ],
        ),
      ),
    );
  }
}

/// 「始める」ボタン。硬い影つき。2.4秒で1周、左上へ 2px 動いてもどる。
/// 端末の「動きを減らす」がオンなら止める
class _StartButton extends StatefulWidget {
  const _StartButton();

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );
  bool _focused = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      // 往復で 2.4 秒（行きと帰りが 1.2 秒ずつ）
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Transform.translate(
        offset: Offset(-2 * _curve.value, -2 * _curve.value),
        child: child,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: BrandColors.hall3,
          borderRadius: BorderRadius.circular(4),
          // 大きさが変わらないよう、常に 4px の枠を持ち、フォーカス中だけ青にする
          border: Border.all(
            color: _focused ? BrandColors.hall5 : Colors.transparent,
            width: 4,
          ),
          boxShadow: const [
            BoxShadow(color: BrandColors.hall1, offset: Offset(6, 6)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('welcome_start_button'),
            borderRadius: BorderRadius.circular(4),
            splashColor: BrandColors.ink.withValues(alpha: 0.1),
            highlightColor: BrandColors.ink.withValues(alpha: 0.1),
            onFocusChange: (value) => setState(() => _focused = value),
            onTap: () => context.go('/login?mode=signup'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 76),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '始める',
                      style: HakoFonts.jp(
                        size: 34,
                        weight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    ExcludeSemantics(
                      child: Text(
                        '→',
                        style: HakoFonts.jp(
                          size: 34,
                          weight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
