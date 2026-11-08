import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/profile_providers.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../../providers/oshi_providers.dart';
import '../common/user_avatar.dart';
import '../live/upcoming_deadlines_section.dart';

import 'home_section_header.dart';
import 'home_recent_memories.dart';
import 'home_upcoming_lives.dart';
import 'home_new_trades.dart';
import 'home_expense_summary.dart';
import 'home_next_trip.dart';
import 'home_oshi_days.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;

    return HakoPageScaffold(
      title: 'おしあし',
      showDesktopTitle: false,
      body: SafeArea(
        child: ListView(
          key: const Key('home_page'),
          padding: HakoPageScaffold.padding(context),
          children: [
            _Greeting(
              uid: ref.watch(currentUidProvider),
              name: profile?.displayName ?? 'ゲスト',
            ),
            // 推しの記念日（add_O 3.3）
            const HomeOshiDays(),
            const HomeSectionHeader(title: '次の締切'),
            const UpcomingDeadlinesSection(),
            const HomeUpcomingLives(),
            // 次の遠征（add_E 6章）
            const HomeNextTrip(),
            const HomeNewTrades(),
            // 今月の推し活費（H-3）
            const HomeExpenseSummary(),
            const HomeRecentMemories(),
          ],
        ),
      ),
    );
  }
}

/// ① あいさつ（左にアイコン。add_I 3.3）と「行きたいライブを追加」
class _Greeting extends StatelessWidget {
  const _Greeting({required this.uid, required this.name});

  final String? uid;
  final String name;

  @override
  Widget build(BuildContext context) {
    final uid = this.uid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (uid != null) ...[
              UserAvatar(uid: uid, name: name, size: 48),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                'こんにちは、$nameさん',
                key: const Key('home_greeting'),
                style: HakoFonts.jp(
                  size: 24,
                  weight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('home_add_live_button'),
          onPressed: () => context.push('/lives/add'),
          icon: const Icon(Icons.add),
          label: const Text('行きたいライブを追加'),
        ),
      ],
    );
  }
}