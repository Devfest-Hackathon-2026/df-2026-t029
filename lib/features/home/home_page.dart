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
import '../shell/app_shell.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  /// 本文の幅がこれ以上なら2列（Fe 3.4。メモリー一覧と同じ基準）
  static const double _twoColumnWidth = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final padding = HakoPageScaffold.padding(context);

    // 区画の一覧は1か所にまとめる（Fe 3.4）。左の列（広い）と右の列（狭い）
    const left = <Widget>[
      _DeadlinesBlock(),
      HomeUpcomingLives(),
      HomeNewTrades(),
      HomeRecentMemories(),
    ];
    const right = <Widget>[
      // 当落発表（Fe 3.3）
      _DeadlinesBlock(results: true),
      // 次の遠征（add_E 6章）
      HomeNextTrip(),
      // 今月の推し活費（H-3）
      HomeExpenseSummary(),
    ];
    // 1列のときの順：次の締切 → 当落発表 → 今後のライブ → 次の遠征 → 新しい交換 → 推し活費 → 思い出
    final single = <Widget>[
      left[0],
      right[0],
      left[1],
      right[1],
      left[2],
      right[2],
      left[3],
    ];

    return HakoPageScaffold(
      title: 'おしあし',
      showDesktopTitle: false,
      maxContentWidth: kShellMaxContentWidth,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns =
                HakoPageScaffold.isWide(context) &&
                constraints.maxWidth - padding.horizontal >= _twoColumnWidth;
            return ListView(
              key: const Key('home_page'),
              padding: padding,
              children: [
                _Greeting(
                  uid: ref.watch(currentUidProvider),
                  name: profile?.displayName ?? 'ゲスト',
                ),
                // 推しの記念日（add_O 3.3）
                const HomeOshiDays(),
                if (twoColumns)
                  Row(
                    key: const Key('home_two_columns'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: left,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: right,
                        ),
                      ),
                    ],
                  )
                else
                  ...single,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 見出しと「次の締切」または「当落発表」（Fe 3.3・3.4）
class _DeadlinesBlock extends StatelessWidget {
  const _DeadlinesBlock({this.results = false});

  final bool results;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(title: results ? '当落発表' : '次の締切'),
        UpcomingDeadlinesSection(results: results),
      ],
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