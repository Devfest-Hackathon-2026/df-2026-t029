import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/login_page.dart';
import 'features/home/home_page.dart';
import 'features/live/live_detail_page.dart';
import 'features/live/live_list_page.dart';
import 'features/scan/scan_page.dart';
import 'features/live_form/live_draft.dart';
import 'features/live_form/live_form_page.dart';
import 'features/live_merge/live_edit_page.dart';
import 'features/oshi/oshi_request_page.dart';
import 'features/oshi/oshi_search_page.dart';
import 'features/calendar/calendar_test_page.dart';
import 'features/goods/goods_search_page.dart';
import 'features/goods/goods_form_page.dart';
import 'features/trade/trade_top_page.dart';
import 'features/trade/trade_post_form_page.dart';

import 'repositories/auth_repository.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _AuthRefresh(auth.authStateChanges());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = auth.currentUser != null;
      final atLogin = state.matchedLocation == '/login';
      if (!loggedIn) return atLogin ? null : '/login';
      if (atLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
        // ホームの下に置き、go で移動してもホームへ戻れるようにする
        routes: [
          GoRoute(
            path: 'oshi/search',
            builder: (context, state) => OshiSearchPage(
              initialQuery: state.uri.queryParameters['q'] ?? '',
            ),
          ),
          GoRoute(
            path: 'oshi/request',
            builder: (context, state) => OshiRequestPage(
              initialName: state.uri.queryParameters['name'] ?? '',
            ),
          ),
          GoRoute(
            path: 'lives',
            builder: (context, state) => const LiveListPage(),
            routes: [
              GoRoute(
                path: ':liveId',
                builder: (context, state) => LiveDetailPage(
                  liveId: state.pathParameters['liveId']!,
                ),
                routes: [
                  // ライブの編集（Step4・計画書 3.7）
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => LiveEditPage(
                      liveId: state.pathParameters['liveId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/register', builder: (context, state) => const ScanPage()),
      GoRoute(
        path: '/live-form',
        builder: (context, state) => LiveFormPage(initial: state.extra as LiveDraft?),
      ),
      GoRoute(
        path: '/calendar-test',
        builder: (context, state) => const CalendarTestPage(),
      ),
      GoRoute(path: '/goods', builder: (context, state) => const GoodsSearchPage()),
      GoRoute(path: '/goods/new', builder: (context, state) => const GoodsFormPage()),
      GoRoute(
        path: '/goods/:id/edit',
        builder: (context, state) => GoodsFormPage(goodsId: state.pathParameters['id']),
      ),
      // 交換トップ。?tab=board / match / mine で開くタブを指定する
      GoRoute(
        path: '/trade',
        builder: (context, state) => TradeTopPage(
          initialTab: TradeTab.fromQuery(state.uri.queryParameters['tab']),
        ),
      ),
      // G-3-2・G-2-6 で作った掲示板・自分の投稿の URL は、交換トップのタブへ移す
      GoRoute(path: '/trade/board', redirect: (_, _) => '/trade?tab=board'),
      GoRoute(path: '/trade/mine', redirect: (_, _) => '/trade?tab=mine'),
      GoRoute(
        path: '/trade/new',
        builder: (context, state) => const TradePostFormPage(),
      ),
      GoRoute(
        path: '/trade/:id/edit',
        builder: (context, state) =>
            TradePostFormPage(postId: state.pathParameters['id']),
      ),
    ],
  );
});

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'おしあし',
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// ログイン状態が変わったら、ルーターに再判定させる
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<User?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
