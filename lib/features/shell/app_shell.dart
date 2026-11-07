import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';

/// この幅以上なら左に縦のタブ、未満なら下に横のタブを出す（紹介ページと同じ基準）
const kShellWideBreakpoint = kHakoWideBreakpoint;

/// PC の幅のとき、中身をこの幅までにする（第2段階の画面用。
/// 第1段階の画面は HakoPageScaffold が 640 にする）
const kShellMaxContentWidth = 960.0;

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
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  /// 今のパス（クエリを除く）
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
                                    label: _tabs[i].$1,
                                    icon: _tabs[i].$2,
                                    selected: i == index,
                                    hue: hue,
                                    onTap: () => onSelect(i),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // アカウントのボタンは、タブの一番下に置く
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: AccountMenuButton(
                        key: Key('shell_account_button'),
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
            height: 72,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _ShellItem(
                      label: _tabs[i].$1,
                      icon: _tabs[i].$2,
                      selected: i == index,
                      hue: hue,
                      onTap: () => onSelect(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return HakoHue(color: hue, child: content);
  }
}

/// タブ1つ分（アイコンの後ろに 56×30 のピル。選択中はページの色）
class _ShellItem extends StatelessWidget {
  const _ShellItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.hue,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color hue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? hue : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? BrandColors.ink : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(icon, size: 24, color: BrandColors.ink),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: HakoFonts.jp(
                size: 11,
                weight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
