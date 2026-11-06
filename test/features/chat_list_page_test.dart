// チャットの一覧（/chats。G-5-4）と、交換トップのチャットボタンのウィジェットテスト
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/trade/chat_list_page.dart';
import 'package:oshiashi/features/trade/trade_top_page.dart';
import 'package:oshiashi/models/trade_chat.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/providers/trade_post_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';

import 'live_test_helpers.dart';
import 'oshi_test_helpers.dart';
import 'trade_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

TradeChat chat(
  String id, {
  String? lastMessage,
  int hour = 12,
  Map<String, DateTime> lastReadAt = const {},
  ChatStatus status = ChatStatus.open,
  String? postSummary = 'アクスタ（A）',
}) => TradeChat(
  id: id,
  postId: 'p',
  replyId: 'r',
  memberUids: const ['me', 'other'],
  memberNames: const {'me': '匿名', 'other': '相手'},
  postSummary: postSummary,
  lastMessage: lastMessage,
  lastMessageAt: DateTime(2026, 11, 6, hour),
  lastReadAt: lastReadAt,
  status: status,
  createdAt: DateTime(2026, 11, 6, 9),
);

Future<void> pump(
  WidgetTester tester,
  FakeTradeChatRepository chatRepo, {
  String location = '/chats',
}) async {
  usePhoneSize(tester);
  final postRepo = FakeTradePostRepository()..mineInitial = const [];
  addTearDown(postRepo.mine.close);
  addTearDown(chatRepo.chats.close);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/chats', builder: (_, _) => const ChatListPage()),
      GoRoute(
        path: '/chats/:id',
        builder: (_, s) => Text('route:chat:${s.pathParameters['id']}'),
      ),
      GoRoute(path: '/trade', builder: (_, _) => const TradeTopPage()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('me'),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        oshiRepositoryProvider.overrideWithValue(FakeOshiRepository(const [])),
        followRepositoryProvider.overrideWithValue(FakeFollowRepository()),
        liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
        nowProvider.overrideWithValue(DateTime(2026, 11, 6, 12)),
        tradePostRepositoryProvider.overrideWithValue(postRepo),
        tradeChatRepositoryProvider.overrideWithValue(chatRepo),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('チャットがなければ案内を出す', (tester) async {
    await pump(tester, FakeTradeChatRepository()..chatsInitial = const []);
    expect(find.textContaining('まだチャットはありません'), findsOneWidget);
  });

  testWidgets('相手・投稿の要約・最後のメッセージ・取引終了を出す', (tester) async {
    await pump(
      tester,
      FakeTradeChatRepository()
        ..chatsInitial = [
          chat('a', lastMessage: 'よろしくお願いします'),
          chat('b', status: ChatStatus.closed, postSummary: null),
        ],
    );
    expect(find.text('相手　アクスタ（A）'), findsOneWidget);
    expect(find.text('よろしくお願いします'), findsOneWidget);
    expect(find.text('まだメッセージはありません'), findsOneWidget);
    // メッセージがまだなければ、チャットを作った日時を出す
    expect(find.text('2026/11/6(金) 09:00・取引終了'), findsOneWidget);
    expect(find.text('相手'), findsOneWidget);
  });

  testWidgets('押すとチャット画面を開く', (tester) async {
    await pump(tester, FakeTradeChatRepository()..chatsInitial = [chat('a')]);
    await tester.tap(_key('chat_tile_a'));
    await tester.pumpAndSettle();
    expect(find.text('route:chat:a'), findsOneWidget);
  });

  testWidgets('未読のチャットは印を付ける', (tester) async {
    await pump(
      tester,
      FakeTradeChatRepository()
        ..chatsInitial = [
          chat('unread', lastMessage: '新着'),
          chat(
            'read',
            lastMessage: '既読',
            lastReadAt: {'me': DateTime(2026, 11, 6, 13)},
          ),
        ],
    );
    Badge badgeOf(String id) => tester.widget<Badge>(
      find.descendant(of: _key('chat_tile_$id'), matching: find.byType(Badge)),
    );
    expect(badgeOf('unread').isLabelVisible, isTrue);
    expect(badgeOf('read').isLabelVisible, isFalse);
  });

  testWidgets('交換トップのボタンに未読の件数を出し、一覧へ行ける', (tester) async {
    await pump(
      tester,
      FakeTradeChatRepository()
        ..chatsInitial = [
          chat('a', lastMessage: '1'),
          chat('b', lastMessage: '2'),
          chat('c'),
        ],
      location: '/trade',
    );
    final badge = tester.widget<Badge>(
      find.descendant(
        of: _key('trade_chats_button'),
        matching: find.byType(Badge),
      ),
    );
    expect(badge.isLabelVisible, isTrue);
    expect((badge.label as Text?)?.data, '2');

    await tester.tap(_key('trade_chats_button'));
    await tester.pumpAndSettle();
    expect(find.text('チャット'), findsOneWidget);
  });
}
