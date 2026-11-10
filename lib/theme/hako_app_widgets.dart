import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/common/user_avatar.dart';
import '../features/help/help_button.dart';
import '../providers/help_providers.dart';
import '../providers/messaging_providers.dart';
import '../providers/oshi_providers.dart';
import '../providers/profile_providers.dart';
import 'brand_colors.dart';
import 'hako_fonts.dart';

/// ログイン後の画面（統合案 v4）の共通部品。

/// この幅以上なら PC の枠（左のタブ・本文の上にタイトル）にする
const double kHakoWideBreakpoint = 720;

/// 第1段階の画面の本文の最大幅（PC）
const double kHakoContentMaxWidth = 640;

/// HakoPageScaffold を使わない画面（投稿の詳細・チャットなど）の最大幅（Fe 3.5）
const double kHakoCenteredPageMaxWidth = 960;

/// HakoPageScaffold を使わない画面を、PC の幅で最大幅まで絞って中央に置く（Fe 3.5）
class HakoCenteredPage extends StatelessWidget {
  const HakoCenteredPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kHakoCenteredPageMaxWidth),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ページの色
// ---------------------------------------------------------------------------

/// 中の画面に「ページの色」（HTML の `--hc`）を渡す
class HakoHue extends InheritedWidget {
  const HakoHue({super.key, required this.color, required super.child});

  final Color color;

  /// 見つからなければ黄（ホームの色）
  static Color of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HakoHue>()?.color ??
        BrandColors.hall3;
  }

  @override
  bool updateShouldNotify(HakoHue oldWidget) => color != oldWidget.color;
}

/// パスからページの色を決める（`tabIndexFor` と同じ分け方）
Color hueForPath(String path) {
  bool under(String prefix) => path == prefix || path.startsWith('$prefix/');
  if (under('/oshi')) return BrandColors.hall1;
  if (under('/lives') || under('/register') || under('/live-form')) {
    return BrandColors.hall5;
  }
  if (under('/trade') || under('/chats') || under('/goods')) {
    return BrandColors.hall6;
  }
  if (under('/memories')) return BrandColors.hall4;
  return BrandColors.hall3;
}

// ---------------------------------------------------------------------------
// アカウントのメニュー
// ---------------------------------------------------------------------------

/// 人のアイコンのボタン＋メニュー（プロフィール・ログアウト）。
/// 外枠の左のタブと、[HakoAppBar] の両方で使う
class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({super.key, this.avatarSize = 28});

  /// 自分のアイコンの大きさ。左のタブでは 48（Fe 3.2）、スマホの上のバーは 28
  final double avatarSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final name = ref.watch(myProfileProvider).value?.displayName ?? '';
    return PopupMenuButton<String>(
      tooltip: 'アカウント',
      // 自分のアイコン（add_I 3.3）。未ログインのときは人のアイコン
      icon: uid == null
          ? Icon(Icons.person_outline, size: avatarSize)
          : UserAvatar(uid: uid, name: name, size: avatarSize),
      iconSize: avatarSize,
      constraints: const BoxConstraints(minWidth: 200),
      // 初回の吹き出しがメニューにかぶらないよう、開いたら消す
      onOpened: () => ref.read(helpCoachVisibleProvider.notifier).dismiss(),
      onSelected: (value) {
        switch (value) {
          case 'profile':
            context.push('/profile');
          case 'logout':
            signOutAndStopNotifications(ref);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('プロフィール'),
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: ListTile(leading: Icon(Icons.logout), title: Text('ログアウト')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ページの枠
// ---------------------------------------------------------------------------

void _goBack(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// スマホの上のバー（高さ 56・ページの色・下に 2px の墨の線）
class HakoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HakoAppBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.backFallback = '/',
    this.onBack,
    this.showAccount = true,
    this.color,
    this.foreground = BrandColors.ink,
  });

  final String title;
  final bool showBack;
  final String backFallback;

  /// 指定すると、戻るボタンで _goBack の代わりに呼ぶ
  final VoidCallback? onBack;
  final bool showAccount;

  /// 背景。省略するとページの色
  final Color? color;

  /// 文字・アイコンの色
  final Color foreground;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final bg = color ?? HakoHue.of(context);
    return AppBar(
      key: const Key('hako_app_bar'),
      toolbarHeight: 56,
      backgroundColor: bg,
      foregroundColor: foreground,
      automaticallyImplyLeading: false,
      shape: const Border(bottom: BorderSide(color: BrandColors.ink, width: 2)),
      leadingWidth: showBack ? 52 : 0,
      leading: showBack
          ? Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                key: const Key('hako_back'),
                tooltip: '戻る',
                icon: const Icon(Icons.chevron_left),
                color: foreground,
                onPressed: onBack ?? () => _goBack(context, backFallback),
              ),
            )
          : null,
      titleSpacing: showBack ? 4 : 16,
      title: Semantics(
        header: true,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HakoFonts.jp(size: 20, height: 1.3, color: foreground),
        ),
      ),
      actions: [
        // 5つのトップの画面だけ「?」が出る（HakoHelpScope の topic が null なら何も出ない）
        const HelpButton(),
        if (showAccount)
          IconTheme(
            data: IconThemeData(color: foreground),
            child: const AccountMenuButton(),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}

/// 第1段階の画面の枠。スマホは上のバー、PC は本文の上にタイトルを出す。
class HakoPageScaffold extends StatelessWidget {
  const HakoPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.showBack = false,
    this.backFallback = '/',
    this.onBack,
    this.showAccount = true,
    this.floatingActionButton,
    this.bottomBar,
    this.barColor,
    this.underlineColor,
    this.showDesktopTitle = true,
    this.maxContentWidth = kHakoContentMaxWidth,
  });

  final String title;
  final Widget body;
  final bool showBack;

  /// 戻れないときの移動先
  final String backFallback;

  /// 指定すると、戻るボタンで _goBack の代わりに呼ぶ（未保存の確認など）
  final VoidCallback? onBack;
  final bool showAccount;
  final Widget? floatingActionButton;

  /// 下に張り付く帯（[HakoSaveBar] など）
  final Widget? bottomBar;

  /// 上のバーの色。省略するとページの色（推しは paper、プロフィールはテーマカラー）
  final Color? barColor;

  /// PC のタイトルの蛍光ペンの色。省略するとページの色
  final Color? underlineColor;

  /// false のとき、PC の幅で本文の上のタイトル（と「戻る」）を出さない（ホーム）。
  /// スマホの上のバーは変わらない
  final bool showDesktopTitle;

  /// PC の幅での本文の最大幅。2列にする画面（メモリーなど）で広げる（Fc 5.2）
  final double maxContentWidth;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= kHakoWideBreakpoint;

  /// 本文の余白（画面の中の ListView が使う）
  static EdgeInsets padding(BuildContext context) => isWide(context)
      ? const EdgeInsets.fromLTRB(24, 24, 24, 48)
      : const EdgeInsets.fromLTRB(16, 8, 16, 24);

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    // プロフィールのようにバーの色を指定したとき、文字の色も合わせる
    final fg = barColor == null ? BrandColors.ink : onThemeColor(barColor!);

    if (!wide) {
      return Scaffold(
        appBar: HakoAppBar(
          title: title,
          showBack: showBack,
          backFallback: backFallback,
          onBack: onBack,
          showAccount: showAccount,
          color: barColor,
          foreground: fg,
        ),
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomBar,
      );
    }

    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showDesktopTitle)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showBack)
                        TextButton.icon(
                          key: const Key('hako_back'),
                          onPressed:
                              onBack ?? () => _goBack(context, backFallback),
                          icon: const Icon(Icons.chevron_left, size: 18),
                          label: const Text('戻る'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 32),
                            padding: const EdgeInsets.only(right: 10),
                          ),
                        ),
                      Semantics(
                        header: true,
                        child: HakoMarked(
                          title,
                          key: const Key('hako_page_title'),
                          style: HakoFonts.jp(
                            size: 22,
                            weight: FontWeight.w700,
                            height: 1.4,
                          ),
                          color: underlineColor,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
      floatingActionButton: floatingActionButton == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 12),
              child: floatingActionButton,
            ),
      bottomNavigationBar: bottomBar,
    );
  }
}

// ---------------------------------------------------------------------------
// 見出し・行
// ---------------------------------------------------------------------------

/// 文字＋蛍光ペン（文字の大きさの 0.38 倍の帯を、行の下端に敷く）
class HakoMarked extends StatelessWidget {
  const HakoMarked(this.text, {super.key, required this.style, this.color});

  final String text;
  final TextStyle style;

  /// 蛍光ペンの色。省略するとページの色
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final hue = color ?? HakoHue.of(context);
    final size = style.fontSize ?? 15;
    final lineHeight = size * (style.height ?? 1.4);
    final cut = (1 - (size * 0.38) / lineHeight).clamp(0.0, 1.0);
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      heightFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.transparent, hue, hue],
            stops: [0, cut, cut, 1],
          ),
        ),
        child: Text(text, style: style),
      ),
    );
  }
}

/// 見出し（15・700・蛍光ペン）＋右に「すべて見る」などのリンク
class HakoSectionHeader extends StatelessWidget {
  const HakoSectionHeader(
    this.title, {
    super.key,
    this.trailingLabel,
    this.onTrailing,
  });

  final String title;
  final String? trailingLabel;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: HakoMarked(
                title,
                style: HakoFonts.jp(
                  size: 15,
                  weight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (trailingLabel != null)
            TextButton(
              onPressed: onTrailing,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Text(
                trailingLabel!,
                style: HakoFonts.jp(
                  size: 13,
                  weight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 一覧の行（アイコン・タイトル・補足・チップ・右に ›）
class HakoRow extends StatelessWidget {
  const HakoRow({
    super.key,
    required this.icon,
    required this.title,
    this.subs = const [],
    this.chip,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final List<String> subs;

  /// タイトルの下に出すチップ（[HakoStatusChip] など）
  final Widget? chip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      overlayColor: WidgetStatePropertyAll(
        BrandColors.ink.withValues(alpha: 0.10),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: BrandColors.rowLine, width: 1.5),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 24, color: BrandColors.ink),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: HakoFonts.jp(size: 15, height: 1.5)),
                    for (final s in subs)
                      Text(
                        s,
                        style: HakoFonts.jp(
                          size: 12,
                          color: BrandColors.sub,
                          height: 1.5,
                        ),
                      ),
                    ?chip,
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const Center(
                child: Icon(Icons.chevron_right, color: BrandColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// チップ・札
// ---------------------------------------------------------------------------

/// 意味の色（申込＝赤・当落＝黄・入金＝緑・ふつう＝tonal）
enum HakoChipKind { apply, draw, pay, plain }

Color _chipColor(HakoChipKind kind) => switch (kind) {
  HakoChipKind.apply => BrandColors.hall1,
  HakoChipKind.draw => BrandColors.hall3,
  HakoChipKind.pay => BrandColors.hall4,
  HakoChipKind.plain => BrandColors.tonal,
};

/// 意味のチップ（12・700・枠 2px）。上に 4px の余白を持つ
class HakoStatusChip extends StatelessWidget {
  const HakoStatusChip(this.label, {super.key, this.kind = HakoChipKind.plain});

  final String label;
  final HakoChipKind kind;

  /// テスト用: 背景色
  Color get color => _chipColor(kind);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: 1,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: BrandColors.ink, width: 2),
          ),
          child: Padding(
            // 読みやすい大きさにする（Ff 3章）
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text(
              label,
              style: HakoFonts.jp(
                size: 13,
                weight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 小さいチップ（13・400。リンクは tonal2。Ff 3章で 11 から大きくした）
class HakoTagChip extends StatelessWidget {
  const HakoTagChip(this.label, {super.key, this.link = false});

  final String label;
  final bool link;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: link ? BrandColors.tonal2 : BrandColors.tonal,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BrandColors.ink, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(label, style: HakoFonts.jp(size: 13, height: 1.3)),
      ),
    );
  }
}

/// 日付の札（月・数字・曜日）。装飾なので読み上げない
class HakoDateBadge extends StatelessWidget {
  const HakoDateBadge({super.key, required this.date});

  final DateTime date;

  static const _weekdays = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  Widget build(BuildContext context) {
    final small = HakoFonts.jp(size: 10, height: 1.15);
    return ExcludeSemantics(
      child: Container(
        width: 48,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HakoHue.of(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BrandColors.ink, width: 2),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${date.month}月', style: small),
              Text('${date.day}', style: HakoFonts.num(size: 20)),
              Text(_weekdays[date.weekday - 1], style: small),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「あと5日」の札（背景 ink・文字はページの色）
class HakoCountBadge extends StatelessWidget {
  const HakoCountBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: BrandColors.ink,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          child: Text(
            label,
            style: HakoFonts.jp(
              size: 11,
              weight: FontWeight.w700,
              color: HakoHue.of(context),
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 箱・帯・影・空
// ---------------------------------------------------------------------------

/// 白い箱（枠 1.5px・角丸 12）。外側の上下に 10
class HakoBox extends StatelessWidget {
  const HakoBox({super.key, required this.child, this.padding});

  final Widget child;

  /// 省略すると 上 10・左右 14・下 4
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: padding ?? const EdgeInsets.fromLTRB(14, 10, 14, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.ink, width: 1.5),
        ),
        child: child,
      ),
    );
  }
}

/// 保存の帯（下に張り付く。上に 2px の墨の線）
class HakoSaveBar extends StatelessWidget {
  const HakoSaveBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('hako_save_bar'),
      decoration: const BoxDecoration(
        color: BrandColors.paper,
        border: Border(top: BorderSide(color: BrandColors.ink, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

/// 子の下に、3px ずらした墨の影（ぼかし 0）をつける
class HakoHardShadow extends StatelessWidget {
  const HakoHardShadow({super.key, required this.child, this.radius = 14});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: BrandColors.ink, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}

/// 空の表示（中央・13・sub）
class HakoEmpty extends StatelessWidget {
  const HakoEmpty(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 16),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: HakoFonts.jp(size: 13, color: BrandColors.sub, height: 1.6),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ヘルプ（案C）の部品
// ---------------------------------------------------------------------------

/// 電球の行（短い補足。13・sub・行の高さ 1.6。上に 8）
class HakoHint extends StatelessWidget {
  const HakoHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: BrandColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: HakoFonts.jp(
                size: 13,
                color: BrandColors.sub,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 譲・求・もらえる・出せる
enum HakoGiveWantKind { give, want, receive, offer }

/// 「譲」「求」などのラベル＋本文
class HakoGiveWantLine extends StatelessWidget {
  const HakoGiveWantLine({super.key, required this.kind, required this.text});

  final HakoGiveWantKind kind;
  final String text;

  String get _label => switch (kind) {
    HakoGiveWantKind.give => '譲',
    HakoGiveWantKind.want => '求',
    HakoGiveWantKind.receive => 'もらえる',
    HakoGiveWantKind.offer => '出せる',
  };

  String get _semanticsLabel => switch (kind) {
    HakoGiveWantKind.give => '譲（手放せるグッズ）',
    HakoGiveWantKind.want => '求（ほしいグッズ）',
    _ => _label,
  };

  /// 「譲」「もらえる」＝淡い桃、「求」「出せる」＝淡い黄
  Color get color => switch (kind) {
    HakoGiveWantKind.give || HakoGiveWantKind.receive => BrandColors.hall6Soft,
    HakoGiveWantKind.want || HakoGiveWantKind.offer => BrandColors.hall3Soft,
  };

  @override
  Widget build(BuildContext context) {
    final long =
        kind == HakoGiveWantKind.receive || kind == HakoGiveWantKind.offer;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: _semanticsLabel,
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Container(
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              padding: EdgeInsets.symmetric(horizontal: long ? 7 : 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: BrandColors.ink, width: 2),
              ),
              child: Text(
                _label,
                style: HakoFonts.jp(
                  size: 12,
                  weight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: HakoFonts.jp(size: 15, height: 1.55)),
        ),
      ],
    );
  }
}
