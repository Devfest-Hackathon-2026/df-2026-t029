import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/login_page.dart';
import 'features/home/home_page.dart';
import 'features/scan/scan_page.dart';
import 'features/live_form/live_draft.dart';
import 'features/live_form/live_form_page.dart';
import 'features/oshi/oshi_request_page.dart';
import 'features/oshi/oshi_search_page.dart';
import 'features/calendar/calendar_test_page.dart';

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
        ],
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/scan', builder: (context, state) => const ScanPage()),
      GoRoute(
        path: '/live-form',
        builder: (context, state) => LiveFormPage(initial: state.extra as LiveDraft?),
      ),
      GoRoute(
        path: '/calendar-test',
        builder: (context, state) => const CalendarTestPage(),
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
