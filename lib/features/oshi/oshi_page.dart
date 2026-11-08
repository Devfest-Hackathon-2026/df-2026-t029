import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import 'favorite_oshi_card.dart';
import 'following_oshi_list.dart';

/// 推しの画面（タブの「推し」）：推しを探す・最推し・フォロー中の推し
class OshiPage extends StatelessWidget {
  const OshiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return HakoPageScaffold(
      title: '推し',
      barColor: BrandColors.paper,
      underlineColor: BrandColors.hall1,
      body: SafeArea(
        child: ListView(
          padding: HakoPageScaffold.padding(context),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const Key('oshi_search_button'),
                onPressed: () => context.push('/oshi/search'),
                style: FilledButton.styleFrom(
                  backgroundColor: BrandColors.ink,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.search),
                label: const Text('推しを探す'),
              ),
            ),
            // 最推し（いないときは何も出ない。Fc 3.2）
            const FavoriteOshiCard(),
            const HakoSectionHeader('フォロー中の推し'),
            const FollowingOshiList(),
          ],
        ),
      ),
    );
  }
}