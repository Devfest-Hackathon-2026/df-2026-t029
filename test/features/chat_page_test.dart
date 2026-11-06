// チャット画面（/chats/:id。G-5-5）のウィジェットテスト
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/trade/chat_page.dart';
import 'package:oshiashi/models/trade_chat.dart';
import 'package:oshiashi/models/trade_message.dart';
import 'package:oshiashi/models/trade_post.dart';
import 'package:oshiashi/models/trade_reply.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/providers/trade_post_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';

import 'oshi_test_helpers.dart';
import 'trade_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

TradeChat chat({
  ChatStatus status = ChatStatus.open,
  String? lastMessage,
  DateTime? lastMessageAt,
  Map<String, DateTime> lastReadAt = const {},
}) => TradeChat(
  id: 'p1_other',
  postId: 'p1',
  replyId: 'r1',
  memberUids: const ['me', 'other'],
  memberNames: const {'me': '匿名', 'other': '相手さん'},
  postSummary: 'アクスタ（A）',
  lastMessage: lastMessage,
  lastMessageAt: lastMessageAt ?? DateTime(2026, 11, 6, 10),
  lastReadAt: lastReadAt,
  status: status,
);

Future<FakeTradeChatRepository> pumpChat(
  WidgetTester tester, {
  TradeChat? c,
  List<TradeMessage> messages = const [],
}) async {
  usePhoneSize(tester);
  final chatRepo = FakeTradeChatRepository();
  if (c != null) chatRepo.chatById[c.id] = c;
  chatRepo.messages['p1_other'] = [...messages];
  final postRepo = FakeTradePostRepository()
    ..posts['p1'] = const TradePost(
      id: 'p1',
      uid: 'me',
      tags: [TradeTag.trade],
      handover: [HandoverMethod.mail],
      gives: [
        GiveSet(
          items: [GiveItem(goodsId: 'a', variantId: 'v', label: 'アクスタ（A）')],
        ),
      ],
    );
  final replyRepo = FakeTradeReplyRepository({
    'p1': [
      TradeReply(
        id: 'r1',
        uid: 'other',
        displayName: '相手さん',
        text: '交換お願いします',
        approved: true,
        createdAt: DateTime(2026, 11, 6, 9),
      ),
    ],
  });
  final router = GoRouter(
    initialLocation: '/chats/p1_other',
    routes: [
      GoRoute(
        path: '/chats/:id',
        builder: (_, s) => ChatPage(chatId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trade/:id',
        builder: (_, s) => Text('route:post:${s.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('me'),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        tradePostRepositoryProvider.overrideWithValue(postRepo),
        tradeReplyRepositoryProvider.overrideWithValue(replyRepo),
        tradeChatRepositoryProvider.overrideWithValue(chatRepo),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return chatRepo;
}

TradeMessage msg(String id, String uid, String text, int hour) => TradeMessage(
  id: id,
  uid: uid,
  text: text,
  createdAt: DateTime(2026, 11, 6, hour),
);

void main() {
  testWidgets('相手の名前、きっかけの投稿と返信、メッセージを出す', (tester) async {
    await pumpChat(
      tester,
      c: chat(),
      messages: [msg('m1', 'other', 'はじめまして', 11), msg('m2', 'me', 'よろしく', 12)],
    );
    expect(find.text('相手さん'), findsOneWidget);
    expect(find.text('譲：アクスタ（A）'), findsOneWidget);
    expect(find.text('交換お願いします'), findsOneWidget);
    expect(find.text('はじめまして'), findsOneWidget);
    expect(find.text('よろしく'), findsOneWidget);

    // 自分のメッセージは右、相手は左
    final mine = tester.getCenter(_key('chat_message_m2')).dx;
    final theirs = tester.getCenter(_key('chat_message_m1')).dx;
    expect(mine, greaterThan(theirs));
  });

  testWidgets('きっかけの投稿から、投稿の詳細へ行ける', (tester) async {
    await pumpChat(tester, c: chat());
    await tester.tap(_key('chat_origin_post'));
    await tester.pumpAndSettle();
    expect(find.text('route:post:p1'), findsOneWidget);
  });

  testWidgets('メッセージを送ると、入力欄を空にして一覧に出す', (tester) async {
    final repo = await pumpChat(tester, c: chat());
    await tester.enterText(_key('chat_input'), '  発送しました  ');
    await tester.tap(_key('chat_send'));
    await tester.pumpAndSettle();
    expect(repo.sent.single, (chatId: 'p1_other', uid: 'me', text: '発送しました'));
    expect(find.text('発送しました'), findsOneWidget);
    expect(
      tester.widget<TextField>(_key('chat_input')).controller!.text,
      isEmpty,
    );
  });

  testWidgets('空のメッセージは送らない', (tester) async {
    final repo = await pumpChat(tester, c: chat());
    await tester.enterText(_key('chat_input'), '   ');
    await tester.tap(_key('chat_send'));
    await tester.pumpAndSettle();
    expect(repo.sent, isEmpty);
  });

  testWidgets('未読があれば、開いたときに既読にする', (tester) async {
    final repo = await pumpChat(
      tester,
      c: chat(lastMessage: '新着', lastMessageAt: DateTime(2026, 11, 6, 12)),
    );
    expect(repo.readMarks, [('p1_other', 'me')]);
  });

  testWidgets('既読なら、既読を書かない', (tester) async {
    final repo = await pumpChat(
      tester,
      c: chat(
        lastMessage: '既読',
        lastMessageAt: DateTime(2026, 11, 6, 12),
        lastReadAt: {'me': DateTime(2026, 11, 6, 13)},
      ),
    );
    expect(repo.readMarks, isEmpty);
  });

  testWidgets('取引終了は確認してから行い、送信できなくなる。再開もできる', (tester) async {
    final repo = await pumpChat(tester, c: chat());
    await tester.tap(_key('chat_menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取引終了にする'));
    await tester.pumpAndSettle();
    await tester.tap(_key('chat_close_confirm'));
    await tester.pumpAndSettle();
    expect(repo.statusChanges, [('p1_other', ChatStatus.closed)]);
    expect(_key('chat_input'), findsNothing);
    expect(_key('chat_closed'), findsOneWidget);

    // 再開は確認なし
    await tester.tap(_key('chat_menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取引を再開する'));
    await tester.pumpAndSettle();
    expect(repo.statusChanges.last, ('p1_other', ChatStatus.open));
    expect(_key('chat_input'), findsOneWidget);
  });

  testWidgets('送れなかったら伝える', (tester) async {
    final repo = await pumpChat(tester, c: chat());
    repo.chatError = Exception('失敗');
    await tester.enterText(_key('chat_input'), 'こんにちは');
    await tester.tap(_key('chat_send'));
    await tester.pumpAndSettle();
    expect(find.textContaining('送信できませんでした'), findsOneWidget);
  });

  testWidgets('チャットがなければその旨を出す', (tester) async {
    await pumpChat(tester);
    expect(find.text('チャットが見つかりません'), findsOneWidget);
  });
}
