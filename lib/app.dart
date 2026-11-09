import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/gestures.dart';

import 'features/auth/login_page.dart';
import 'features/auth/verify_email_page.dart';
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
import 'features/memory/share/memory_share_screen.dart';
import 'features/photos/photos_test_page.dart';
import 'features/welcome/welcome_page.dart';
import 'features/oshi/oshi_page.dart';
import 'features/shell/app_shell.dart';
import 'features/expense/expense_page.dart';
import 'features/common/foreground_notification_listener.dart';
import 'features/travel/trip_list_page.dart';
import 'features/memory/shared_memory_detail_page.dart';

import 'repositories/auth_repository.dart';

import 'providers/profile_providers.dart';
import 'providers/theme_providers.dart';

import 'theme/app_theme.dart';
import 'theme/hako_app_widgets.dart';

import 'utils/auth_redirect.dart';

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
      final user = auth.currentUser;
      // プロフィール未作成かどうか。読み込み中・エラーのときは判定しない
      final profile = ref.read(myProfileProvider);
      final needsProfile = profile is AsyncData && profile.value == null;
      return decideRedirect(
        location: state.matchedLocation,
        loggedIn: user != null,
        needsEmailVerification:
            user != null && auth.currentUserNeedsEmailVerification,
        needsProfile: needsProfile,
      );
    },
    routes: [
      // タブを出さない画面（紹介・ログイン・メールの確認・プロフィール・接続テスト）
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(
          initialMode: state.uri.queryParameters['mode'] == 'signup'
              ? LoginMode.signUp
              : LoginMode.signIn,
        ),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/calendar-test',
        builder: (context, state) => const CalendarTestPage(),
      ),
      // Google フォトの接続テスト（G0。本番の導線には出さない）
      GoRoute(
        path: '/photos-test',
        builder: (context, state) => const PhotosTestPage(),
      ),
      // ログイン後の画面は、タブの付いた外枠の中に出す（D-2）
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomePage(),
            // ホームの下に置き、go で移動してもホームへ戻れるようにする
            routes: [
              // 推し（タブの「推し」）: 推しを探す・追加申請はこの下
              GoRoute(
                path: 'oshi',
                builder: (context, state) => const OshiPage(),
                routes: [
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => OshiSearchPage(
                      initialQuery: state.uri.queryParameters['q'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: 'request',
                    builder: (context, state) => OshiRequestPage(
                      initialName: state.uri.queryParameters['name'] ?? '',
                      // グループのメンバーの一覧から開いたときは、そのグループの ID
                      initialGroupId: state.uri.queryParameters['group'],
                    ),
                  ),
                ],
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
                    builder: (context, state) =>
                        LiveDetailPage(liveId: state.pathParameters['liveId']!),
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
                      // 投稿をまとめて編集（メモリーの統合）。?target=x|ig で投稿先を選んで開く
                      GoRoute(
                        path: 'share',
                        builder: (context, state) => MemoryShareScreen(
                          performanceId: state.pathParameters['performanceId']!,
                          initialTarget: shareTargetFromQuery(
                            state.uri.queryParameters['target'],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // 費用管理（H-3）。ホームの下に置き、戻るとホームへ戻る
              GoRoute(
                path: 'expenses',
                builder: (context, state) => const ExpensePage(),
              ),
              // 遠征の一覧（add_E 6章）。ホームの下に置き、戻るとホームへ戻る
              GoRoute(
                path: 'trips',
                builder: (context, state) => const TripListPage(),
              ),
              // みんなのメモリーの詳細（add_K 6.3）。ホームの下に置き、戻るとメモリーへ戻る
              GoRoute(
                path: 'shared-memories/:id',
                builder: (context, state) =>
                    SharedMemoryDetailPage(id: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) => const ScanPage(),
          ),
          GoRoute(
            path: '/live-form',
            builder: (context, state) =>
                LiveFormPage(initial: state.extra as LiveDraft?),
          ),
          GoRoute(
            path: '/goods',
            builder: (context, state) => const GoodsSearchPage(),
          ),
          GoRoute(
            path: '/goods/new',
            builder: (context, state) => const GoodsFormPage(),
          ),
          GoRoute(
            path: '/goods/:id/edit',
            builder: (context, state) =>
                GoodsFormPage(goodsId: state.pathParameters['id']),
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
            // PC で横に伸びすぎないように 960 で中央に置く（Fe 3.5）
            builder: (context, state) => HakoCenteredPage(
              child: ChatPage(chatId: state.pathParameters['id']!),
            ),
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
            // PC で横に伸びすぎないように 960 で中央に置く（Fe 3.5）
            builder: (context, state) => HakoCenteredPage(
              child: TradePostDetailPage(
                postId: state.pathParameters['id']!,
                initialAttachId: state.uri.queryParameters['attach'],
              ),
            ),
          ),
        ],
      ),
    ],
  );
});

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'おしあし',
      theme: buildAppTheme(ref.watch(themeSeedColorProvider)),
      scrollBehavior: const _AppScrollBehavior(),
      routerConfig: ref.watch(routerProvider),
      // アプリを開いているときに届いた通知を SnackBar で出す（Step6）
      builder: (context, child) =>
          ForegroundNotificationListener(child: child!),
    );
  }
}

/// マウスのドラッグでもスクロールできるようにする（Web で横の一覧を動かすため）
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
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
