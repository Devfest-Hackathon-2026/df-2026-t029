import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/trade_post_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../help/help_button.dart';
import '../help/help_coach.dart';
import '../help/help_scope.dart';
import '../help/help_topic.dart';

/// この幅以上なら左に縦のタブ、未満なら下に横のタブを出す（紹介ページと同じ基準）
const kShellWideBreakpoint = kHakoWideBreakpoint;

/// PC の幅のとき、中身をこの幅までにする（第2段階の画面用。
/// 第1段階の画面は HakoPageScaffold が 640 にする）
const kShellMaxContentWidth = 960.0;

/// 下のタブの高さ
const kShellBottomBarHeight = 80.0;

/// タブ1つ分（ラベル、アイコン、押したときの移動先）
typedef _Tab = (String label, IconData icon, String path);

const _tabs = <_Tab>[
  ('ホーム', Icons.home_outlined, '/'),
  ('推し', Icons.favorite_outline, '/oshi'),
  ('ライブ一覧', Icons.list_alt_outlined, '/lives'),
  ('グッズ交換', Icons.swap_horiz, '/trade'),
  ('メモリー', Icons.collections_bookmark_outlined, '/memories'),
];

/// 今のパスから、選択中のタブの番号を決める（詳細画面でも、その機能のタブにする）
int tabIndexFor(String path) {
  bool under(String prefix) => path == prefix || path.startsWith('$prefix/');
  if (under('/oshi')) return 1;
  if (under('/lives') || under('/register') || under('/live-form')) return 2;
  if (under('/trade') || under('/chats') || under('/goods')) return 3;
  if (under('/memories')) return 4;
  return 0;
}

/// ログイン後の画面の外枠。PC の幅では左に、スマホの幅では下にタブを出す
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  /// 今のパス（クエリを除く）
  final String location;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// 「?」ボタンと、初回の吹き出しをつなぐ印
  final _helpLink = LayerLink();

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final child = widget.child;
    final index = tabIndexFor(location);
    void onSelect(int i) => context.go(_tabs[i].$3);
    final wide = MediaQuery.sizeOf(context).width >= kShellWideBreakpoint;
    final hue = hueForPath(location);
    final scheme = Theme.of(context).colorScheme;

    final Widget content;
    if (wide) {
      content = Scaffold(
        body: Row(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                color: BrandColors.paper,
                border: Border(
                  right: BorderSide(color: BrandColors.ink, width: 2),
                ),
              ),
              child: SizedBox(
                key: const Key('shell_rail'),
                width: 82,
                child: Column(
                  children: [
                    // タブの一番上にアプリ名の札を出す（ロゴの画像は使わない）
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 16),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: BrandColors.ink, width: 2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Text(
                            'おしあし',
                            key: const Key('shell_app_name'),
                            style: HakoFonts.jp(
                              size: 13,
                              weight: FontWeight.w700,
                              color: scheme.onPrimaryContainer,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 高さが足りないときは、項目の部分だけがスクロールする
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (var i = 0; i < _tabs.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: SizedBox(
                                  width: 76,
                                  child: _ShellItem(
                                    index: i,
                                    selected: i == index,
                                    onTap: () => onSelect(i),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // 「?」はアカウントのボタンの上に置く
                    const HelpButton(),
                    // アカウントのボタンは、タブの一番下に置く（タブの丸より少し大きく。Fe 3.2）
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: AccountMenuButton(
                        key: Key('shell_account_button'),
                        avatarSize: 48,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 中身は最大幅を決めて中央に寄せる（横に広がりすぎないように）
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: kShellMaxContentWidth,
                  ),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      content = Scaffold(
        body: child,
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            color: BrandColors.paper,
            border: Border(top: BorderSide(color: BrandColors.ink, width: 2)),
          ),
          child: SizedBox(
            key: const Key('shell_bottom_bar'),
            height: kShellBottomBarHeight,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _ShellItem(
                      index: i,
                      selected: i == index,
                      onTap: () => onSelect(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return HakoHue(
      color: hue,
      child: HakoHelpScope(
        topic: helpTopicForPath(location),
        link: _helpLink,
        child: Stack(
          children: [
            Positioned.fill(child: content),
            HelpCoach(wide: wide),
          ],
        ),
      ),
    );
  }
}

/// タブごとの色（濃い色, 淡い色）。順番は [_tabs] と同じ
const _tabColors = <(Color, Color)>[
  (BrandColors.hall3, BrandColors.hall3Soft),
  (BrandColors.hall1, BrandColors.hall1Soft),
  (BrandColors.hall5, BrandColors.hall5Soft),
  (BrandColors.hall6, BrandColors.hall6Soft),
  (BrandColors.hall4, BrandColors.hall4Soft),
];

/// タブ1つ分（丸いアイコン＋ラベル。選択中は濃い色で、上に浮く）
class _ShellItem extends ConsumerWidget {
  const _ShellItem({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (label, icon, _) = _tabs[index];
    final (hall, soft) = _tabColors[index];
    // 未読の数字はグッズ交換のタブだけ
    final unread = index == 3 ? ref.watch(unreadChatCountProvider) : 0;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 150);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        key: Key('shell_tab_$index'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: duration,
                transform: Matrix4.translationValues(0, selected ? -6 : 0, 0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: duration,
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? hall : soft,
                        shape: BoxShape.circle,
                        border: Border.all(color: BrandColors.ink, width: 2),
                        boxShadow: selected
                            ? const [
                                BoxShadow(
                                  color: BrandColors.ink,
                                  offset: Offset(0, 3),
                                ),
                              ]
                            : const [],
                      ),
                      child: ExcludeSemantics(
                        child: Icon(icon, size: 24, color: BrandColors.ink),
                      ),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Semantics(
                          label: '未読$unread件',
                          child: ExcludeSemantics(
                            child: Container(
                              key: const Key('shell_unread_dot'),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD93025),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: BrandColors.paper,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                style: HakoFonts.jp(
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: duration,
                transform: Matrix4.translationValues(0, selected ? -4 : 0, 0),
                child: ExcludeSemantics(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: HakoFonts.jp(
                      size: 12,
                      weight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
