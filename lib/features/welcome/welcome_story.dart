// 紹介ページの物語の区画（PROBLEM 01・FLOW・PROBLEM 02・SOLUTION の黒い帯）。
// 文言は計画書 4.10 のとおり。

import 'package:flutter/material.dart';

import '../../theme/brand_colors.dart';
import 'welcome_layout.dart';

/// 困りごとのカード1枚分の文言
class _ProblemText {
  const _ProblemText(this.title, this.body);

  final String title;
  final String body;
}

const _problems1 = [
  _ProblemText('「申込期限、いつだっけ？」', '公式サイト、SNS、メール。告知があちこちにあって、期限を見落としてしまう。'),
  _ProblemText(
    '「当選したのに、入金を忘れた」',
    '当落発表のあとには入金期限があります。過ぎてしまうと、せっかくの当選が無効になることも。',
  ),
  _ProblemText('「ライブが増えて、整理できない」', '追いかける推しが増えるほど、日程も期限も増えて、頭の中だけでは管理しきれない。'),
];

const _problems2 = [
  _ProblemText(
    '「推しのグッズ、手に入らなかった」',
    '欲しかったグッズが売り切れていた、買いに行けなかった。ライブまでに何とか手に入れたい。',
  ),
  _ProblemText('「誰かとグッズを交換したい」', '自分が持っているグッズと、欲しいグッズを交換できたら。そう思っても、きっかけがない。'),
  _ProblemText(
    '「持っている人が、見つからない」',
    'お目当てのグッズを持っている人を、SNSの投稿から探し回るのは大変で、時間もかかる。',
  ),
];

/// 困りごとのカード（地は白・枠 2px・硬い影 5px）
class _ProblemCard extends StatelessWidget {
  const _ProblemCard({
    super.key,
    required this.text,
    required this.shadowColor,
  });

  final _ProblemText text;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BrandColors.surface,
        border: Border.all(color: BrandColors.ink, width: 2),
        boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(5, 5))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text.title,
              style: welcomeJp(size: 19, weight: FontWeight.w700, height: 1.5),
            ),
            const SizedBox(height: 10),
            Text(text.body, style: welcomeJp(size: 14.5)),
          ],
        ),
      ),
    );
  }
}

/// 困りごとの区画（見出し＋カード3枚）
class _ProblemBlock extends StatelessWidget {
  const _ProblemBlock({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.topPadding,
    required this.items,
    required this.shadowColor,
    required this.keyPrefix,
  });

  final String eyebrow;
  final String title;
  final String body;
  final double topPadding;
  final List<_ProblemText> items;
  final Color shadowColor;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = WelcomeBreakpoints.isStacked(width) ? 1 : 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WelcomeSectionTitle(
          eyebrow: eyebrow,
          title: title,
          body: body,
          topPadding: topPadding,
        ),
        WelcomeWrap(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 56),
            child: WelcomeGrid(
              columns: columns,
              gap: 16,
              itemCount: items.length,
              itemBuilder: (context, i) => _ProblemCard(
                key: Key('${keyPrefix}_${i + 1}'),
                text: items[i],
                shadowColor: shadowColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// PROBLEM 01（見出し＋カード3枚。下 56 まで）
class WelcomeProblemSection extends StatelessWidget {
  const WelcomeProblemSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ProblemBlock(
      eyebrow: 'PROBLEM 01',
      title: 'こんな「うっかり」、ありませんか？',
      body: '推し活は楽しい分、気をつけることがたくさん。おしあしは、その「うっかり」を減らすためのアプリです。',
      topPadding: 56,
      items: _problems1,
      shadowColor: BrandColors.ink,
      keyPrefix: 'welcome_problem1',
    );
  }
}

/// PROBLEM 02（見出しの上 0・影は桃）
class WelcomeGoodsProblemSection extends StatelessWidget {
  const WelcomeGoodsProblemSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ProblemBlock(
      eyebrow: 'PROBLEM 02',
      title: 'ライブ本番の前に、こんなことありませんか？',
      body: 'チケットが取れても、推し活の悩みはまだあります。ライブの日が近づくほど気になるのが、グッズのこと。',
      topPadding: 0,
      items: _problems2,
      shadowColor: BrandColors.hall6,
      keyPrefix: 'welcome_problem2',
    );
  }
}

class _Term {
  const _Term(this.tag, this.color, this.title, this.body);

  final String tag;
  final Color color;
  final String title;
  final String body;
}

const _terms = [
  _Term(
    '申込',
    BrandColors.hall1,
    '申し込む',
    'チケットの抽選などに申し込める期間。この期限を過ぎると、そもそも参加できません。',
  ),
  _Term('当落', BrandColors.hall3, '結果を待つ', '当選か落選かが発表される日。発表の時間も、ライブごとに違います。'),
  _Term(
    '入金',
    BrandColors.hall4,
    '支払う',
    '当選したあと、チケット代を支払う期限。ここを過ぎると、当選が取り消されることがあります。',
  ),
];

/// 期限の流れの区画1つ（札・小見出し・説明）
class _TermCell extends StatelessWidget {
  const _TermCell({
    super.key,
    required this.term,
    required this.index,
    required this.stacked,
  });

  final _Term term;
  final int index;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    const line = BorderSide(color: BrandColors.ink, width: 2);
    final hasDivider = index < _terms.length - 1;
    final border = !hasDivider
        ? null
        : (stacked ? const Border(bottom: line) : const Border(right: line));
    // 矢印は次の区画（2つ目・3つ目）の側に置く。前の区画の地に隠れない
    final arrow = index == 0
        ? null
        : (stacked
              ? const Positioned(
                  left: 24,
                  top: -17,
                  width: 32,
                  height: 32,
                  child: _ArrowCircle(label: '↓'),
                )
              : const Positioned(
                  left: -17,
                  top: 0,
                  bottom: 0,
                  width: 32,
                  child: Center(child: _ArrowCircle(label: '→')),
                ));
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(border: border),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: term.color,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  child: Text(
                    term.tag,
                    style: welcomeJp(size: 13, weight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  term.title,
                  style: welcomeJp(size: 20, weight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(term.body, style: welcomeJp(size: 14.5)),
              ],
            ),
          ),
        ),
        ?arrow,
      ],
    );
  }
}

class _ArrowCircle extends StatelessWidget {
  const _ArrowCircle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: BrandColors.ink,
          shape: BoxShape.circle,
        ),
        child: Text(
          label,
          style: welcomeJp(
            size: 16,
            weight: FontWeight.w700,
            color: BrandColors.hall3,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// FLOW（見出しの上 0）
class WelcomeFlowSection extends StatelessWidget {
  const WelcomeFlowSection({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final stacked = WelcomeBreakpoints.isStacked(width);
    final cells = [
      for (var i = 0; i < _terms.length; i++)
        _TermCell(
          key: Key('welcome_term_${i + 1}'),
          term: _terms[i],
          index: i,
          stacked: stacked,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WelcomeSectionTitle(
          eyebrow: 'FLOW',
          title: 'チケットの期限は、この順番で管理していきます',
          body: 'はじめての方も安心。申込・当落・入金、それぞれの意味から説明します。',
          topPadding: 0,
        ),
        WelcomeWrap(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 56),
            child: DecoratedBox(
              key: const Key('welcome_flow'),
              decoration: BoxDecoration(
                color: BrandColors.surface,
                border: Border.all(color: BrandColors.ink, width: 2),
              ),
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: cells,
                    )
                  : IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [for (final c in cells) Expanded(child: c)],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// SOLUTION の黒い帯
class WelcomeSolutionBand extends StatelessWidget {
  const WelcomeSolutionBand({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final size = welcomeClamp(width, min: 26, vw: 4.6, max: 38);
    final headStyle = welcomeJp(
      size: size,
      weight: FontWeight.w700,
      color: BrandColors.surface,
      height: 1.4,
    );
    return WelcomeBand(
      key: const Key('welcome_solution'),
      color: BrandColors.ink,
      padding: const EdgeInsets.only(top: 44, bottom: 36),
      child: WelcomeWrap(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Text(
                'SOLUTION',
                style: welcomeEn(
                  size: 12,
                  color: BrandColors.hall3,
                  letterSpacing: 1.92,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Semantics(
              header: true,
              child: Text.rich(
                TextSpan(
                  style: headStyle,
                  children: [
                    const TextSpan(text: 'そんなお悩みを、'),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: WelcomeMark(
                        text: 'おしあし',
                        style: headStyle,
                        color: BrandColors.hall1,
                      ),
                    ),
                    const TextSpan(text: 'が解決します。'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'おしあしでできる、6つのこと。',
              style: welcomeJp(size: 16, color: BrandColors.onInkSub),
            ),
          ],
        ),
      ),
    );
  }
}
