// 紹介ページの機能の区画（6つのハコ・FAQ）。文言は計画書 4.10 のとおり。

import 'package:flutter/material.dart';

import '../../theme/brand_colors.dart';
import 'welcome_layout.dart';

class _Tile {
  const _Tile(this.label, this.color, this.title, this.body);

  final String label;
  final Color color;
  final String title;
  final String body;
}

const _tiles = [
  _Tile(
    'FOLLOW',
    BrandColors.hall1,
    '推しをフォロー',
    '推しを探してフォロー。見つからなければ、追加を申請できます。',
  ),
  _Tile(
    'SCAN',
    BrandColors.hall2,
    'スクショで読み取り',
    '告知画像やチケットサイトのスクリーンショットから、日程・申込期限・入金期限をAIが読み取ります。',
  ),
  _Tile(
    'DUE',
    BrandColors.hall3,
    '次の締切が、ひと目で',
    '申込・当落・入金の期限を並べて表示。次にやることが分かります。',
  ),
  _Tile(
    'SHARE',
    BrandColors.hall4,
    'みんなで共有',
    '同じ推しのファンが登録したライブを、自分の一覧に追加できます。',
  ),
  _Tile(
    'CALENDAR',
    BrandColors.hall5,
    'Google カレンダーに追加',
    '登録した予定を、Google カレンダーにも追加できます。',
  ),
  _Tile(
    'TRADE',
    BrandColors.hall6,
    'グッズ交換',
    '手放したいグッズは「譲」、探しているグッズは「求」として登録。交換できる相手が見つかります。',
  ),
];

/// 6つのハコ（全幅・隙間なし）
class WelcomeTileGrid extends StatelessWidget {
  const WelcomeTileGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return WelcomeGrid(
      columns: WelcomeBreakpoints.tileColumns(width),
      itemCount: _tiles.length,
      itemBuilder: (context, i) => _TileCell(
        key: Key('welcome_hall_${i + 1}'),
        index: i,
        tile: _tiles[i],
      ),
    );
  }
}

class _TileCell extends StatelessWidget {
  const _TileCell({super.key, required this.index, required this.tile});

  final int index;
  final _Tile tile;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = !WelcomeBreakpoints.isStacked(width);
    final number = (index + 1).toString().padLeft(2, '0');
    final labelStyle = welcomeEn(
      size: 12,
      color: BrandColors.ink,
      letterSpacing: 1.68,
    );
    return ColoredBox(
      color: tile.color,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        fit: StackFit.passthrough,
        children: [
          // 大きな番号は題・説明より後ろに描く
          Positioned(
            right: 10,
            bottom: -14,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Text(
                  number,
                  style: welcomeEn(
                    size: wide ? 92 : 72,
                    weight: FontWeight.w900,
                    color: Colors.black.withValues(alpha: 0.12),
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: wide ? 260 : 0),
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 22, 22, wide ? 76 : 64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExcludeSemantics(
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text('HALL $number', style: labelStyle),
                        Text(tile.label, style: labelStyle),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    header: true,
                    child: Text(
                      tile.title,
                      style: welcomeJp(
                        size: welcomeClamp(width, min: 22, vw: 3, max: 28),
                        weight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(tile.body, style: welcomeJp(size: 14.5, height: 1.75)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Faq {
  const _Faq(this.question, this.answer);

  final String question;
  final String answer;
}

const _faqs = [
  _Faq(
    'スクショは、どんな画像を選べばいいですか？',
    '公演名・日程・申込期間・入金期限などが写っている、告知画像やチケットサイトの画面です。登録する前に、読み取り結果を必ず確認してください。',
  ),
  _Faq('フォローしたい推しが見つからないときは？', '追加の申請を送れます。'),
  _Faq(
    '「譲」「求」って何ですか？',
    'グッズ交換で使う、ファンの間の言葉です。手放したいグッズは「譲」、探しているグッズは「求」として登録します。',
  ),
  _Faq(
    'ほかのファンが登録したライブは、どう使えますか？',
    '同じ推しをフォローしているファンが登録したライブを、自分の一覧に追加できます。自分で入力する手間が省けます。',
  ),
];

/// FAQ（見出しの上 56・下 56）
class WelcomeFaqSection extends StatelessWidget {
  const WelcomeFaqSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('welcome_faq'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WelcomeSectionTitle(eyebrow: 'FAQ', title: 'よくある質問'),
        WelcomeWrap(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _faqs.length; i++)
                  _FaqItem(faq: _faqs[i], number: i + 1, first: i == 0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// FAQ の1項目（開閉は項目ごとに独立。動きは付けない）
class _FaqItem extends StatefulWidget {
  const _FaqItem({
    required this.faq,
    required this.number,
    required this.first,
  });

  final _Faq faq;
  final int number;
  final bool first;

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    const line = BorderSide(color: BrandColors.ink, width: 2);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: widget.first ? line : BorderSide.none,
          bottom: line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // キーは押せる部品自身（InkWell）に付ける
          Semantics(
            button: true,
            expanded: _open,
            child: InkWell(
              key: Key('welcome_faq_${widget.number}'),
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                // 開いているときは、答えとの間が 8 になるよう下の余白を減らす
                padding: EdgeInsets.only(top: 14, bottom: _open ? 8 : 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.faq.question,
                        style: welcomeJp(size: 16.5, weight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ExcludeSemantics(
                      child: Text(
                        _open ? '−' : '＋',
                        style: welcomeJp(
                          size: 22,
                          weight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 630),
                  child: Text(widget.faq.answer, style: welcomeJp(size: 15)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
