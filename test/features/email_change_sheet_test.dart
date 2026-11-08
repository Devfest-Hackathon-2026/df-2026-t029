// メールアドレス変更のシート（EmailChangeSheetBody）のテスト
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_test_helpers.dart';
import 'email_change_test_helpers.dart';

const _newEmail = 'new@example.com';

FirebaseAuthException _ex(String code) => FirebaseAuthException(code: code);

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(k(key), text);
  await tester.pump();
}

Future<void> _send(WidgetTester tester) async {
  await tester.ensureVisible(k('email_send_button'));
  await tester.tap(k('email_send_button'));
  await tester.pump();
  await tester.pump();
}

/// ステップ2まで進める
Future<FakeAuthRepository> _toWaiting(WidgetTester tester) async {
  final repo = await pumpAccount(tester);
  await openSheet(tester);
  await _type(tester, 'email_new_field', _newEmail);
  await _send(tester);
  return repo;
}

void main() {
  testWidgets('開く: ステップ1の部品が出る', (tester) async {
    await pumpAccount(tester);
    await openSheet(tester);
    expect(find.text('メールアドレスを変更'), findsOneWidget);
    expect(k('email_sheet_stepper'), findsOneWidget);
    expect(find.textContaining('確認のメールを送ります'), findsOneWidget);
    expect(k('email_new_field'), findsOneWidget);
    expect(k('email_send_button'), findsOneWidget);
    expect(k('email_password_field'), findsNothing);
    expect(k('email_error'), findsOneWidget); // 空の入れ物（高さ 0）
    // いまのアドレスは伏せ字
    expect(find.text('ke******@example.com'), findsWidgets);
  });

  testWidgets('空のあいだボタンが押せず、入れると押せる', (tester) async {
    final repo = await pumpAccount(tester);
    await openSheet(tester);
    await tester.tap(k('email_send_button'), warnIfMissed: false);
    await tester.pump();
    expect(repo.emailChanges, isEmpty);
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: k('email_send_button'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await _type(tester, 'email_new_field', _newEmail);
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: k('email_send_button'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('シートの「表示／かくす」で、いまのアドレスの全体が出る', (tester) async {
    await pumpAccount(tester);
    await openSheet(tester);
    expect(find.text('ken-oshi@example.com'), findsNothing);
    await tester.tap(k('email_sheet_reveal_button'));
    await tester.pump();
    expect(find.text('ken-oshi@example.com'), findsOneWidget);
    await tester.tap(k('email_sheet_reveal_button'));
    await tester.pump();
    expect(find.text('ken-oshi@example.com'), findsNothing);
  });

  testWidgets('送る → ステップ2（アドレス・補足・ボタン・リンク・カウントダウン）', (tester) async {
    final repo = await _toWaiting(tester);
    expect(repo.emailChanges, [_newEmail]);
    expect(find.textContaining(_newEmail), findsWidgets);
    expect(find.textContaining('迷惑メールフォルダ'), findsOneWidget);
    expect(k('email_check_button'), findsOneWidget);
    expect(k('email_back_button'), findsOneWidget);
    expect(find.text('確認メールを再送する（あと3秒）'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('確認メールを再送する（あと2秒）'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('確認メールを再送する'), findsOneWidget);
  });

  testWidgets('エラーが欄の下に出て、入力を直すと消える', (tester) async {
    final repo = await pumpAccount(tester);
    repo.errors['startEmailChange'] = _ex('email-already-in-use');
    await openSheet(tester);
    await _type(tester, 'email_new_field', _newEmail);
    await _send(tester);
    expect(find.text('このメールアドレスは、すでに別のアカウントで使われています。'), findsOneWidget);
    await _type(tester, 'email_new_field', 'other@example.com');
    expect(find.text('このメールアドレスは、すでに別のアカウントで使われています。'), findsNothing);
  });

  testWidgets('形式エラーでは repository を呼ばない', (tester) async {
    final repo = await pumpAccount(tester);
    await openSheet(tester);
    await _type(tester, 'email_new_field', 'abc');
    await _send(tester);
    expect(find.textContaining('形式が正しくありません'), findsOneWidget);
    expect(repo.emailChanges, isEmpty);
  });

  testWidgets('requires-recent-login でパスワード欄が出て、再認証して送る', (tester) async {
    final repo = await pumpAccount(tester);
    repo.errors['startEmailChange'] = _ex('requires-recent-login');
    await openSheet(tester);
    await _type(tester, 'email_new_field', _newEmail);
    await _send(tester);
    expect(k('email_password_field'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('うまくいきませんでした'), findsNothing);
    await _type(tester, 'email_password_field', 'dummy-pass');
    await _send(tester);
    expect(repo.reauths, 1);
    expect(repo.emailChanges, [_newEmail, _newEmail]);
    expect(k('email_check_button'), findsOneWidget);
  });

  testWidgets('送れて確認待ちに進んだら、パスワード欄の入力は残らない', (tester) async {
    final repo = await pumpAccount(tester);
    repo.errors['startEmailChange'] = _ex('requires-recent-login');
    await openSheet(tester);
    await _type(tester, 'email_new_field', _newEmail);
    await _send(tester);
    await _type(tester, 'email_password_field', 'dummy-pass');
    await _send(tester);
    expect(k('email_check_button'), findsOneWidget);
    // 再送で再認証が要ると、パスワード欄つきで入力に戻る
    await tester.pump(const Duration(seconds: 3));
    repo.errors['startEmailChange'] = _ex('requires-recent-login');
    await tester.ensureVisible(k('email_resend_button'));
    await tester.tap(k('email_resend_button'));
    await tester.pump();
    await tester.pump();
    expect(k('email_password_field'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.descendant(
        of: k('email_password_field'),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('パスワードが違うと文が出る', (tester) async {
    final repo = await pumpAccount(tester);
    repo.errors['startEmailChange'] = _ex('requires-recent-login');
    await openSheet(tester);
    await _type(tester, 'email_new_field', _newEmail);
    await _send(tester);
    repo.errors['reauth'] = _ex('invalid-credential');
    await _type(tester, 'email_password_field', 'dummy-pass');
    await _send(tester);
    expect(find.text('パスワードが違います。'), findsOneWidget);
    expect(k('email_password_field'), findsOneWidget);
  });

  testWidgets('手動の確認: まだなら文が出る', (tester) async {
    final repo = await _toWaiting(tester);
    repo.reloadedEmail = 'ken-oshi@example.com';
    await tester.ensureVisible(k('email_check_button'));
    await tester.tap(k('email_check_button'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('まだ確認できていません。'), findsOneWidget);
  });

  testWidgets('確認できる → ステップ3 →「プロフィールに戻る」で閉じて SnackBar、行が新しい伏せ字', (
    tester,
  ) async {
    final repo = await _toWaiting(tester);
    repo.reloadedEmail = _newEmail;
    repo.email = _newEmail;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('メールアドレスを変更しました'), findsOneWidget);
    expect(find.textContaining('次回から、'), findsOneWidget);
    expect(k('email_done_button'), findsOneWidget);
    await tester.ensureVisible(k('email_done_button'));
    await tester.tap(k('email_done_button'));
    await tester.pumpAndSettle();
    expect(k('email_sheet'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('メールアドレスを変更しました'), findsOneWidget); // SnackBar
    expect(find.text('ne*****@example.com'), findsNothing);
    expect(find.text('ne***@example.com'), findsOneWidget);
  });

  testWidgets('sessionEnded の形・「ログイン画面へ」で signOut', (tester) async {
    final repo = await _toWaiting(tester);
    repo.errors['reloadCurrentEmail'] = _ex('user-token-expired');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('ログインの有効期限が切れました'), findsOneWidget);
    expect(find.text('ログイン画面へ'), findsOneWidget);
    expect(find.text('プロフィールに戻る'), findsNothing);
    await tester.ensureVisible(k('email_done_button'));
    await tester.tap(k('email_done_button'));
    await tester.pumpAndSettle();
    expect(repo.signOuts, 1);
    expect(k('email_sheet'), findsNothing);
  });

  testWidgets('再送: 待ちが終わると押せて、SnackBar が出る', (tester) async {
    final repo = await _toWaiting(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.ensureVisible(k('email_resend_button'));
    await tester.tap(k('email_resend_button'));
    await tester.pump();
    await tester.pump();
    expect(repo.emailChanges.length, 2);
    expect(find.text('確認メールを再送しました'), findsOneWidget);
    expect(find.text('確認メールを再送する（あと3秒）'), findsOneWidget);
  });

  testWidgets('待ちの間は再送を押しても送られない', (tester) async {
    final repo = await _toWaiting(tester);
    await tester.ensureVisible(k('email_resend_button'));
    await tester.tap(k('email_resend_button'), warnIfMissed: false);
    await tester.pump();
    expect(repo.emailChanges.length, 1);
  });

  testWidgets('入力し直す: ステップ1に戻り、入力が残る', (tester) async {
    await _toWaiting(tester);
    await tester.ensureVisible(k('email_back_button'));
    await tester.tap(k('email_back_button'));
    await tester.pump();
    expect(k('email_send_button'), findsOneWidget);
    expect(find.text(_newEmail), findsOneWidget);
  });

  testWidgets('閉じるボタンで閉じる', (tester) async {
    await pumpAccount(tester);
    await openSheet(tester);
    await tester.tap(k('email_sheet_close'));
    await tester.pumpAndSettle();
    expect(k('email_sheet'), findsNothing);
  });

  testWidgets('暗幕を押すと閉じる', (tester) async {
    await pumpAccount(tester);
    await openSheet(tester);
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
    expect(k('email_sheet'), findsNothing);
  });

  testWidgets('Esc で閉じる', (tester) async {
    await pumpAccount(tester);
    await openSheet(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(k('email_sheet'), findsNothing);
  });

  testWidgets('途中で閉じても自動の確認が止まる', (tester) async {
    final repo = await _toWaiting(tester);
    await tester.tap(k('email_sheet_close'));
    await tester.pumpAndSettle();
    final loads = repo.reloads;
    repo.reloadedEmail = _newEmail;
    await tester.pump(const Duration(seconds: 5));
    expect(k('email_sheet'), findsNothing);
    expect(repo.emailChanges.length, 1);
    expect(repo.reloads, loads);
  });

  testWidgets('PC 幅ではシートの幅が 640 以内', (tester) async {
    await pumpAccount(tester, width: 1200);
    await openSheet(tester);
    expect(tester.getSize(k('email_sheet')).width, lessThanOrEqualTo(640));
  });

  for (final width in [320.0, 390.0, 700.0, 1000.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('幅 $width・文字 $scale 倍・キーボードありで、全ステップではみ出さない', (tester) async {
        final repo = await pumpAccount(
          tester,
          width: width,
          height: 700,
          textScale: scale,
          keyboard: 300,
        );
        repo.errors['startEmailChange'] = _ex('requires-recent-login');
        await openSheet(tester);
        expect(tester.takeException(), isNull);
        await _type(
          tester,
          'email_new_field',
          'long-address-for-test@subdomain.example.com',
        );
        await _send(tester); // パスワード欄
        expect(tester.takeException(), isNull);
        await _type(tester, 'email_password_field', 'dummy-pass');
        await _send(tester); // ステップ2
        expect(tester.takeException(), isNull);
        repo.reloadedEmail = 'long-address-for-test@subdomain.example.com';
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(tester.takeException(), isNull); // ステップ3
      });
    }
  }
}
