import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/login_page.dart';
import 'features/home/home_page.dart';
import 'features/live/live_detail_page.dart';
import 'features/live/live_list_page.dart';
import 'features/live_add/live_add_page.dart';
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
import 'features/trade/chat_list_page.dart';
import 'features/trade/chat_page.dart';
import 'features/trade/trade_post_detail_page.dart';
import 'features/trade/trade_post_form_page.dart';
import 'features/profile/profile_page.dart';
import 'features/memory/memory_form_page.dart';
import 'features/memory/memory_detail_page.dart';
import 'features/memory/memory_list_page.dart';
import 'features/welcome/welcome_page.dart';

import 'repositories/auth_repository.dart';

import 'providers/profile_providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _AuthRefresh(auth.authStateChanges());
  ref.onDispose(refresh.dispose);

  // プロフィールが作られたら、ルーターに再判定させる（G-8-3）
  final profileRefresh = ValueNotifier<int>(0);
  ref.listen(myProfileProvider, (_, _) => profileRefresh.value++);
  ref.onDispose(profileRefresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: Listenable.merge([refresh, profileRefresh]),
    redirect: (context, state) {
      final loggedIn = auth.currentUser != null;
      // ログインしていなくても見られるページ（紹介ページとログイン画面）
      final location = state.matchedLocation;
      final isPublic = location == '/welcome' || location == '/login';
      if (!loggedIn) return isPublic ? null : '/welcome';

      // プロフィール未作成なら作成画面へ。読み込み中・エラーのときは判定しない
      final profile = ref.read(myProfileProvider);
      final needsProfile = profile is AsyncData && profile.value == null;
      if (needsProfile) {
        return location == '/profile' ? null : '/profile';
      }
      if (isPublic) return '/';
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
              // :liveId より前に置く（後ろだと add がライブ ID になる）
              GoRoute(
                path: 'add',
                builder: (context, state) => const LiveAddPage(),
              ),
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
                  GoRoute(
                    path: 'memory/:performanceId',
                    builder: (context, state) => MemoryFormPage(
                      performanceId: state.pathParameters['performanceId']!,
                      liveId: state.pathParameters['liveId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // メモリー（M-4）: 一覧 → 記録の詳細 → 編集
          GoRoute(
            path: 'memories',
            builder: (context, state) => const MemoryListPage(),
            routes: [
              GoRoute(
                path: ':performanceId',
                builder: (context, state) => MemoryDetailPage(
                  performanceId: state.pathParameters['performanceId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => MemoryFormPage(
                      performanceId: state.pathParameters['performanceId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/welcome', builder: (context, state) => const WelcomePage()),
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
        path: '/chats',
        builder: (context, state) => const ChatListPage(),
      ),
      GoRoute(
        path: '/chats/:id',
        builder: (context, state) =>
            ChatPage(chatId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trade/new',
        builder: (context, state) => const TradePostFormPage(),
      ),
      GoRoute(
        path: '/trade/:id/edit',
        builder: (context, state) =>
            TradePostFormPage(postId: state.pathParameters['id']),
      ),
      // /trade/new・/trade/board・/trade/mine より後に置く（先に書いたルートが優先される）
      GoRoute(
        path: '/trade/:id',
        // ?attach= は、返信に最初から添付しておく自分の投稿（マッチから開いたとき）
        builder: (context, state) => TradePostDetailPage(
          postId: state.pathParameters['id']!,
          initialAttachId: state.uri.queryParameters['attach'],
        ),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
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
