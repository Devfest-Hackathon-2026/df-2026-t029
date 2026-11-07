import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/auth_repository.dart';

/// この幅以上なら左に縦のタブ、未満なら下に横のタブを出す（紹介ページと同じ基準）
const kShellWideBreakpoint = 720.0;

/// タブ1つ分（ラベル、アイコン、選択中のアイコン、押したときの移動先）
typedef _Tab = (String label, IconData icon, IconData selectedIcon, String path);

const _tabs = <_Tab>[
  ('ホーム', Icons.home_outlined, Icons.home, '/'),
  ('推し', Icons.favorite_outline, Icons.favorite, '/oshi'),
  ('ライブ一覧', Icons.event_note_outlined, Icons.event_note, '/lives'),
  ('グッズ交換', Icons.swap_horiz, Icons.swap_horiz, '/trade'),
  ('メモリー', Icons.photo_album_outlined, Icons.photo_album, '/memories'),
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
    void onSelect(int i) => context.go(_tabs[i].$4);
    final wide = MediaQuery.sizeOf(context).width >= kShellWideBreakpoint;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              key: const Key('shell_rail'),
              selectedIndex: index,
              onDestinationSelected: onSelect,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (label, icon, selectedIcon, _) in _tabs)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selectedIcon),
                    label: Text(label),
                  ),
              ],
              // アカウントのボタンは、タブの一番下に置く
              trailing: const Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: _AccountButton(),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        key: const Key('shell_bottom_bar'),
        selectedIndex: index,
        onDestinationSelected: onSelect,
        destinations: [
          for (final (label, icon, selectedIcon, _) in _tabs)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selectedIcon),
              label: label,
            ),
        ],
      ),
    );
  }
}

/// アカウントのボタン（プロフィール・ログアウト）
class _AccountButton extends ConsumerWidget {
  const _AccountButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      key: const Key('shell_account_button'),
      tooltip: 'アカウント',
      icon: const Icon(Icons.account_circle, size: 32),
      onSelected: (value) {
        switch (value) {
          case 'profile':
            context.push('/profile');
          case 'logout':
            ref.read(authRepositoryProvider).signOut();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person),
            title: Text('プロフィール'),
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout),
            title: Text('ログアウト'),
          ),
        ),
      ],
    );
  }
}