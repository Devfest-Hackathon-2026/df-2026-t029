// 紹介ページ（/welcome）。ログインしていない人が最初に見るページ（案C 改）。
//
// 構成: ヘッダー → 最初の画面（見出し・掲示板）→ PROBLEM 01 → FLOW → PROBLEM 02
//       → SOLUTION → 6つのハコ → FAQ → CTA
// 画面の移動:
//   「おしあしを始める」→ /login?mode=signup、右上の「ログイン」→ /login
// 区画の部品は welcome_story.dart・welcome_features.dart、共通の部品は welcome_layout.dart。
// 動き（アニメーション）は無い。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/brand_colors.dart';
import '../../theme/hako_widgets.dart';
import 'welcome_features.dart';
import 'welcome_layout.dart';
import 'welcome_story.dart';

/// 紹介ページ
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('welcome_page'),
      backgroundColor: BrandColors.paper,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(),
              _Hero(),
              WelcomeProblemSection(),
              WelcomeFlowSection(),
              WelcomeGoodsProblemSection(),
              WelcomeSolutionBand(),
              WelcomeTileGrid(),
              WelcomeFaqSection(),
              _Cta(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    // 枠（最大幅 960）の外。画面の左端・右端に付ける（左右の余白だけ幅に合わせる）
    final width = MediaQuery.sizeOf(context).width;
    final gutter = WelcomeBreakpoints.isPhone(width) ? 18.0 : 24.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 狭い画面・大きい文字では、はみ出さないよう縮める
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'おしあし',
                style: welcomeJp(
                  size: 30,
                  weight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          HakoPill(
            key: const Key('welcome_login_button'),
            label: 'ログイン',
            fontSize: 16,
            onPressed: () => context.go('/login'),
          ),
        ],
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

// 架空の名前。実在の名前に変えない。札の文字は墨（コントラストのため）
const _boardRows = [
  _BoardRow('11.20', '入金', BrandColors.hall4, '「ひかりの夜」東京公演'),
  _BoardRow('11.24', '申込', BrandColors.hall1, '「ミナト・ツアー」大阪'),
  _BoardRow('11.30', '当落', BrandColors.hall3, '「ひかりの夜」追加公演'),
];

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final h1Size = welcomeClamp(width, min: 40, vw: 8, max: 68);
    final h1Style = welcomeJp(
      size: h1Size,
      weight: FontWeight.w700,
      height: 1.2,
      letterSpacing: h1Size * 0.01,
    );
    return WelcomeWrap(
      child: Padding(
        padding: const EdgeInsets.only(top: 56, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Column(
                key: const Key('welcome_h1'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('推し活の予定を、', style: h1Style),
                  WelcomeMark(
                    text: 'もう逃さない。',
                    style: h1Style,
                    color: BrandColors.hall3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Text(
                '推し活の締切をひとつの掲示板にまとめて、次にやることを、ひと目で確認できるアプリです。',
                key: const Key('welcome_lead'),
                style: welcomeJp(size: 17),
              ),
            ),
            const SizedBox(height: 32),
            const _Board(),
          ],
        ),
      ),
    );
  }
}

/// 掲示板（締切の表示例）。例の表なので、読み上げには中身を出さない
class _Board extends StatelessWidget {
  const _Board();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '締切の表示例',
      excludeSemantics: true,
      child: Container(
        key: const Key('welcome_board'),
        color: BrandColors.ink,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: WelcomeColors.rule)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'NEXT 締切',
                    style: welcomeEn(
                      size: 13,
                      color: BrandColors.hall3,
                      letterSpacing: 1.56,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '直近の締切（表示例）',
                      style: welcomeJp(
                        size: 10.83,
                        color: WelcomeColors.muted,
                        letterSpacing: 0.43,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < _boardRows.length; i++)
              _BoardLine(
                row: _boardRows[i],
                isLast: i == _boardRows.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _BoardLine extends StatelessWidget {
  const _BoardLine({required this.row, required this.isLast});

  final _BoardRow row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: BrandColors.boardRow)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 52,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                row.date,
                style: welcomeEn(
                  size: 16,
                  weight: FontWeight.w700,
                  color: BrandColors.surface,
                  letterSpacing: 0.64,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 2),
            color: row.color,
            alignment: Alignment.center,
            child: Text(
              row.label,
              style: welcomeJp(size: 12, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              row.text,
              style: welcomeJp(size: 15, color: BrandColors.surface),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「始める」の区画（黒い帯）
class _Cta extends StatelessWidget {
  const _Cta();

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return WelcomeBand(
      color: BrandColors.ink,
      padding: EdgeInsets.fromLTRB(0, 40, 0, 56 + safeBottom),
      child: WelcomeWrap(
        child: Column(
          key: const Key('welcome_cta'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'まずは、推しをひとり。',
                style: welcomeJp(
                  size: welcomeClamp(
                    MediaQuery.sizeOf(context).width,
                    min: 22,
                    vw: 4,
                    max: 30,
                  ),
                  weight: FontWeight.w700,
                  height: 1.4,
                  color: BrandColors.surface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '新規登録して、推しをフォローするところから始めましょう。',
              style: welcomeJp(size: 15, color: BrandColors.onInkSub),
            ),
            const SizedBox(height: 24),
            const _StartButton(),
            const SizedBox(height: 16),
            Text(
              '新規登録・ログインの画面に進みます。',
              key: const Key('welcome_cta_note'),
              style: welcomeJp(size: 13, color: WelcomeColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「おしあしを始める」ボタン。黄の地・赤の硬い影。フォーカス中は青の枠が内側に出る
class _StartButton extends StatefulWidget {
  const _StartButton();

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final labelSize = WelcomeBreakpoints.isPhone(width) ? 21.0 : 26.0;
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: BrandColors.hall1,
            offset: Offset(6, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: _focused
              ? Border.all(color: BrandColors.hall5, width: 4)
              : null,
        ),
        child: Material(
          color: BrandColors.hall3,
          child: Semantics(
            button: true,
            child: InkWell(
              key: const Key('welcome_start_button'),
              splashColor: BrandColors.ink.withValues(alpha: 0.1),
              highlightColor: BrandColors.ink.withValues(alpha: 0.1),
              onFocusChange: (focused) => setState(() => _focused = focused),
              onTap: () => context.go('/login?mode=signup'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'おしあしを始める',
                        style: welcomeJp(
                          size: labelSize,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ExcludeSemantics(
                      child: Text(
                        '→',
                        style: welcomeJp(size: 32, weight: FontWeight.w700),
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
