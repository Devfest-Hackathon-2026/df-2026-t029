import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/auth/verify_email_page.dart';
import 'package:oshiashi/repositories/auth_repository.dart';

import 'auth_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

const _notYet = 'まだ確認できていません。メールのリンクを開いてから、もう一度押してください。';

Future<FakeAuthRepository> pumpVerify(
  WidgetTester tester, {
  String? email = 'a@example.com',
  Size size = const Size(600, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeAuthRepository()
    ..user = email == null ? null : FakeUser(email: email);
  final router = GoRouter(
    initialLocation: '/verify-email',
    routes: [
      GoRoute(
        path: '/verify-email',
        builder: (_, _) => const VerifyEmailPage(),
      ),
      GoRoute(path: '/', builder: (_, _) => const Text('route:home')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  return repo;
}

/// 画面を閉じて、タイマーを残さない
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

Finder _spinnerIn(String key) => find.descendant(
  of: _key(key),
  matching: find.byType(CircularProgressIndicator),
);

void main() {
  group('表示', () {
    testWidgets('メールアドレスと案内を出す', (tester) async {
      await pumpVerify(tester);
      expect(_key('verify_email_page'), findsOneWidget);
      expect(find.text('確認メールを送りました'), findsOneWidget);
      expect(
        find.text('a@example.com に届いたメールのリンクを開いてから、下のボタンを押してください。'),
        findsOneWidget,
      );
      expect(find.text('届かないときは、迷惑メールのフォルダも見てください。'), findsOneWidget);
      expect(_key('verify_message'), findsNothing);
      await _close(tester);
    });

    testWidgets('メールアドレスが取れなくても、案内は出る', (tester) async {
      await pumpVerify(tester, email: null);
      expect(find.text('届いたメールのリンクを開いてから、下のボタンを押してください。'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('360px でもはみ出さない', (tester) async {
      await pumpVerify(tester, size: const Size(360, 640));
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(_key('verify_check_button'));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      await _close(tester);
    });
  });

  group('「確認しました」', () {
    testWidgets('まだなら、案内の帯を出し、画面に残る', (tester) async {
      final repo = await pumpVerify(tester);
      await tester.tap(_key('verify_check_button'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(repo.reloads, 1);
      expect(
        find.descendant(
          of: _key('verify_message'),
          matching: find.text(_notYet),
        ),
        findsOneWidget,
      );
      expect(find.text('route:home'), findsNothing);
      await _close(tester);
    });

    testWidgets('確認済みなら、/ へ移る', (tester) async {
      final repo = await pumpVerify(tester);
      repo.verified = true;
      await tester.tap(_key('verify_check_button'));
      await tester.pumpAndSettle();
      expect(find.text('route:home'), findsOneWidget);
    });

    testWidgets('確認中は、ボタンにくるくるを出し、すべて押せない', (tester) async {
      final repo = await pumpVerify(tester);
      repo.gate = Completer<void>();
      await tester.tap(_key('verify_check_button'));
      await tester.pump();
      expect(_spinnerIn('verify_check_button'), findsOneWidget);
      expect(
        tester.widget<TextButton>(_key('verify_resend_button')).onPressed,
        isNull,
      );
      expect(
        tester.widget<TextButton>(_key('verify_sign_out_button')).onPressed,
        isNull,
      );
      repo.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(_spinnerIn('verify_check_button'), findsNothing);
      await _close(tester);
    });

    testWidgets('通信などで失敗したら、手動のときだけ文言を出す', (tester) async {
      final repo = await pumpVerify(tester);
      repo.errors['reload'] = authError('network-request-failed');
      await tester.tap(_key('verify_check_button'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('通信できませんでした'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('想定外の例外でも、中身は出さずに汎用の文言', (tester) async {
      final repo = await pumpVerify(tester);
      repo.errors['reload'] = StateError('secret-detail');
      await tester.tap(_key('verify_check_button'));
      await tester.pump();
      await tester.pump();
      expect(find.text('うまくいきませんでした。もう一度お試しください。'), findsOneWidget);
      expect(find.textContaining('secret-detail'), findsNothing);
      await _close(tester);
    });
  });

  group('自動の確認（5秒ごと）', () {
    testWidgets('5秒ごとに確かめる。まだなら何も出さない', (tester) async {
      final repo = await pumpVerify(tester);
      await tester.pump(const Duration(seconds: 4));
      expect(repo.reloads, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(repo.reloads, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(repo.reloads, 2);
      expect(_key('verify_message'), findsNothing);
      expect(_spinnerIn('verify_check_button'), findsNothing);
      await _close(tester);
    });

    testWidgets('確認済みになったら、押さなくても / へ進み、タイマーを止める', (tester) async {
      final repo = await pumpVerify(tester);
      repo.verified = true;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('route:home'), findsOneWidget);
      final count = repo.reloads;
      await tester.pump(const Duration(seconds: 30));
      expect(repo.reloads, count);
    });

    testWidgets('自動の確認が失敗しても、何も出さず、次も確かめる', (tester) async {
      final repo = await pumpVerify(tester);
      repo.errors['reload'] = authError('network-request-failed');
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(_key('verify_message'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      expect(repo.reloads, 2);
      await _close(tester);
    });

    testWidgets('確認の途中は、次の確認を重ねない', (tester) async {
      final repo = await pumpVerify(tester);
      repo.gate = Completer<void>();
      await tester.pump(const Duration(seconds: 5));
      expect(repo.reloads, 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      expect(repo.reloads, 1);
      // 手動のボタンを押しても重ならない
      await tester.tap(_key('verify_check_button'));
      await tester.pump();
      expect(repo.reloads, 1);

      repo.gate!.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(repo.reloads, 2);
      await _close(tester);
    });

    testWidgets('画面を閉じたら、タイマーを止める', (tester) async {
      final repo = await pumpVerify(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(repo.reloads, 1);
      await _close(tester);
      await tester.pump(const Duration(seconds: 60));
      expect(repo.reloads, 1);
    });
  });

  group('確認メールの送り直し', () {
    testWidgets('送ると、案内を出し、60秒は押せない（残り秒数つき）', (tester) async {
      final repo = await pumpVerify(tester);
      await tester.tap(_key('verify_resend_button'));
      await tester.pump();
      await tester.pump();
      expect(repo.resends, 1);
      expect(find.text('確認メールを送りました。'), findsOneWidget);
      expect(find.text('確認メールを送り直す（あと60秒）'), findsOneWidget);
      expect(
        tester.widget<TextButton>(_key('verify_resend_button')).onPressed,
        isNull,
      );

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('確認メールを送り直す（あと30秒）'), findsOneWidget);
      await tester.pump(const Duration(seconds: 29));
      expect(find.text('確認メールを送り直す（あと1秒）'), findsOneWidget);
      expect(
        tester.widget<TextButton>(_key('verify_resend_button')).onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('確認メールを送り直す'), findsOneWidget);
      expect(
        tester.widget<TextButton>(_key('verify_resend_button')).onPressed,
        isNotNull,
      );

      // 60秒たったら、もう一度送れる
      await tester.tap(_key('verify_resend_button'));
      await tester.pump();
      await tester.pump();
      expect(repo.resends, 2);
      await _close(tester);
    });

    testWidgets('押せない間に押しても、送らない', (tester) async {
      final repo = await pumpVerify(tester);
      await tester.tap(_key('verify_resend_button'));
      await tester.pump();
      await tester.pump();
      await tester.tap(_key('verify_resend_button'), warnIfMissed: false);
      await tester.pump();
      expect(repo.resends, 1);
      await _close(tester);
    });

    testWidgets('too-many-requests は文言を出し、60秒の待ちは始めない', (tester) async {
      final repo = await pumpVerify(tester);
      repo.errors['resend'] = authError('too-many-requests');
      await tester.tap(_key('verify_resend_button'));
      await tester.pump();
      await tester.pump();
      expect(find.text('試した回数が多すぎます。しばらく待ってから、もう一度お試しください。'), findsOneWidget);
      expect(find.text('確認メールを送り直す'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('送っている間は、ボタンを押せない', (tester) async {
      final repo = await pumpVerify(tester);
      repo.gate = Completer<void>();
      await tester.tap(_key('verify_resend_button'));
      await tester.pump();
      expect(
        tester.widget<TextButton>(_key('verify_resend_button')).onPressed,
        isNull,
      );
      expect(
        tester.widget<TextButton>(_key('verify_sign_out_button')).onPressed,
        isNull,
      );
      repo.gate!.complete();
      await tester.pump();
      await tester.pump();
      await _close(tester);
    });

    testWidgets('待ちの途中で画面を閉じても、例外にならない', (tester) async {
      await pumpVerify(tester);
      await tester.tap(_key('verify_resend_button'));
      await tester.pump();
      await tester.pump();
      await _close(tester);
      await tester.pump(const Duration(seconds: 70));
      expect(tester.takeException(), isNull);
    });
  });

  group('別のアカウントでログインする', () {
    testWidgets('ログアウトする', (tester) async {
      final repo = await pumpVerify(tester);
      await tester.tap(_key('verify_sign_out_button'));
      await tester.pump();
      await tester.pump();
      expect(repo.signOuts, 1);
      await _close(tester);
    });
  });

  group('案6の見た目', () {
    testWidgets('幅 320 でもはみ出さない。戻るボタンは無い', (tester) async {
      await pumpVerify(tester, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      expect(_key('login_back_button'), findsNothing);
      expect(_key('hako_column'), findsOneWidget);
      for (final k in ['verify_check_button']) {
        final rect = tester.getRect(_key(k));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
      await _close(tester);
    });
  });
}
