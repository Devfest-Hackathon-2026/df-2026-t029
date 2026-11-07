import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/auth/login_page.dart';
import 'package:oshiashi/features/live/official_url_link.dart';
import 'package:oshiashi/repositories/auth_repository.dart';

import 'auth_test_helpers.dart';

// テストのパスワードは架空の値
const _pw = 'dummy-pass-0000';

Finder _key(String k) => find.byKey(Key(k));
Finder get notice => _key('login_recaptcha_notice');

/// 送信ボタンの文言
Finder _submitLabel(String text) =>
    find.descendant(of: _key('login_submit_button'), matching: find.text(text));

Finder _spinnerIn(String key) => find.descendant(
  of: _key(key),
  matching: find.byType(CircularProgressIndicator),
);

bool _obscured(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(of: _key(key), matching: find.byType(EditableText)),
    )
    .obscureText;

Future<({FakeAuthRepository repo, List<Uri> opened})> pumpLogin(
  WidgetTester tester, {
  LoginMode mode = LoginMode.signIn,
  Size size = const Size(600, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeAuthRepository();
  final opened = <Uri>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        urlLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
      child: MaterialApp(home: LoginPage(initialMode: mode)),
    ),
  );
  return (repo: repo, opened: opened);
}

Future<void> _fill(
  WidgetTester tester, {
  String? email,
  String? password,
  String? confirm,
}) async {
  if (email != null) {
    await tester.enterText(_key('login_email_field'), email);
  }
  if (password != null) {
    await tester.enterText(_key('login_password_field'), password);
  }
  if (confirm != null) {
    await tester.enterText(_key('login_password_confirm_field'), confirm);
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(_key(key));
  await tester.pump();
}

void main() {
  group('モードの初期値と切り替え', () {
    testWidgets('既定は「ログイン」: 確認欄が無く、「パスワードを忘れた方」がある', (tester) async {
      await pumpLogin(tester);
      expect(_key('login_password_confirm_field'), findsNothing);
      expect(_key('login_forgot_password_button'), findsOneWidget);
      expect(_submitLabel('ログイン'), findsOneWidget);
      expect(find.text('8文字以上'), findsNothing);
      expect(find.textContaining('登録すると確認メールが届きます'), findsNothing);
      expect(
        find.text('Google カレンダーへの追加は、使うときに Google アカウントの許可を求めます。'),
        findsOneWidget,
      );
    });

    testWidgets('initialMode が signUp なら「新規登録」で開く', (tester) async {
      await pumpLogin(tester, mode: LoginMode.signUp);
      expect(_key('login_password_confirm_field'), findsOneWidget);
      expect(_key('login_forgot_password_button'), findsNothing);
      expect(_submitLabel('登録して確認メールを送る'), findsOneWidget);
      expect(find.text('8文字以上'), findsOneWidget);
      expect(find.textContaining('登録すると確認メールが届きます'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<LoginMode>>(
              find.byType(SegmentedButton<LoginMode>),
            )
            .selected,
        {LoginMode.signUp},
      );
    });

    testWidgets('切り替えると欄が出たり消えたりし、メールアドレスは残る', (tester) async {
      await pumpLogin(tester);
      await _fill(tester, email: 'a@example.com');
      await _tap(tester, 'login_mode_signup');
      expect(_key('login_password_confirm_field'), findsOneWidget);
      expect(_key('login_forgot_password_button'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(_key('login_email_field'))
            .controller!
            .text,
        'a@example.com',
      );
      await _tap(tester, 'login_mode_signin');
      expect(_key('login_password_confirm_field'), findsNothing);
      expect(_key('login_forgot_password_button'), findsOneWidget);
    });

    testWidgets('切り替えると、エラーの帯と各欄のエラーが消える', (tester) async {
      final t = await pumpLogin(tester);
      t.repo.errors['signIn'] = authError('invalid-credential');
      await _fill(tester, email: 'a@example.com', password: _pw);
      await _tap(tester, 'login_submit_button');
      await tester.pumpAndSettle();
      expect(_key('login_error'), findsOneWidget);

      await _tap(tester, 'login_mode_signup');
      expect(_key('login_error'), findsNothing);

      // 検査エラーも消える
      await _fill(tester, email: 'bad');
      await _tap(tester, 'login_submit_button');
      expect(find.text('メールアドレスの形が正しくありません。'), findsOneWidget);
      await _tap(tester, 'login_mode_signin');
      expect(find.text('メールアドレスの形が正しくありません。'), findsNothing);
    });
  });

  group('入力の検査', () {
    testWidgets('ログイン: 空のまま送ると、各欄にエラーが出て、送らない', (tester) async {
      final t = await pumpLogin(tester);
      await _tap(tester, 'login_submit_button');
      expect(find.text('メールアドレスを入れてください。'), findsOneWidget);
      expect(find.text('パスワードを入れてください。'), findsOneWidget);
      expect(t.repo.signIns, isEmpty);
    });

    testWidgets('ログイン: 短いパスワードでも長さでは止めない', (tester) async {
      final t = await pumpLogin(tester);
      await _fill(tester, email: 'a@example.com', password: 'a');
      await _tap(tester, 'login_submit_button');
      expect(t.repo.signIns, hasLength(1));
    });

    testWidgets('新規登録: 形の違うメール・7文字・確認の不一致', (tester) async {
      final t = await pumpLogin(tester, mode: LoginMode.signUp);
      await _fill(tester, email: 'abc', password: 'a' * 7, confirm: 'b' * 7);
      await _tap(tester, 'login_submit_button');
      expect(find.text('メールアドレスの形が正しくありません。'), findsOneWidget);
      expect(find.text('パスワードは8文字以上にしてください。'), findsOneWidget);
      expect(find.text('パスワードが一致しません。'), findsOneWidget);
      expect(t.repo.signUps, isEmpty);
    });

    testWidgets('新規登録: 8文字で一致していれば送れる（境界）', (tester) async {
      final t = await pumpLogin(tester, mode: LoginMode.signUp);
      await _fill(
        tester,
        email: 'a@example.com',
        password: 'a' * 8,
        confirm: 'a' * 8,
      );
      await _tap(tester, 'login_submit_button');
      expect(t.repo.signUps, hasLength(1));
    });
  });

  group('送信', () {
    testWidgets('ログイン: メールの前後の空白を除き、パスワードはそのまま渡す', (tester) async {
      final t = await pumpLogin(tester);
      await _fill(tester, email: '  a@example.com ', password: ' $_pw ');
      await _tap(tester, 'login_submit_button');
      expect(t.repo.signIns, [(email: 'a@example.com', password: ' $_pw ')]);
      expect(t.repo.signUps, isEmpty);
    });

    testWidgets('新規登録: signUpWithEmail を呼ぶ', (tester) async {
      final t = await pumpLogin(tester, mode: LoginMode.signUp);
      await _fill(tester, email: 'a@example.com', password: _pw, confirm: _pw);
      await _tap(tester, 'login_submit_button');
      expect(t.repo.signUps, [(email: 'a@example.com', password: _pw)]);
      expect(t.repo.signIns, isEmpty);
    });

    testWidgets('ログインのパスワード欄で Enter を押すと送信する', (tester) async {
      final t = await pumpLogin(tester);
      await _fill(tester, email: 'a@example.com', password: _pw);
      await tester.tap(_key('login_password_field'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(t.repo.signIns, hasLength(1));
    });

    testWidgets('新規登録の確認欄で Enter を押すと送信する', (tester) async {
      final t = await pumpLogin(tester, mode: LoginMode.signUp);
      await _fill(tester, email: 'a@example.com', password: _pw, confirm: _pw);
      await tester.tap(_key('login_password_confirm_field'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(t.repo.signUps, hasLength(1));
    });

    testWidgets('「Google で続ける」で signInWithGoogle を呼ぶ', (tester) async {
      final t = await pumpLogin(tester);
      expect(find.text('Google で続ける'), findsOneWidget);
      await _tap(tester, 'login_google_button');
      expect(t.repo.googleSignIns, 1);
    });

    testWidgets('目のアイコンでパスワードの表示・非表示を切り替える', (tester) async {
      await pumpLogin(tester, mode: LoginMode.signUp);
      expect(_obscured(tester, 'login_password_field'), isTrue);
      expect(_obscured(tester, 'login_password_confirm_field'), isTrue);
      await _tap(tester, 'login_password_toggle');
      expect(_obscured(tester, 'login_password_field'), isFalse);
      await _tap(tester, 'login_password_toggle');
      expect(_obscured(tester, 'login_password_field'), isTrue);
    });
  });

  group('処理中', () {
    testWidgets('メールで送信中は、すべてのボタンと切り替えが押せず、押した送信にだけくるくる', (tester) async {
      final t = await pumpLogin(tester);
      t.repo.gate = Completer<void>();
      await _fill(tester, email: 'a@example.com', password: _pw);
      await _tap(tester, 'login_submit_button');

      expect(_spinnerIn('login_submit_button'), findsOneWidget);
      expect(_spinnerIn('login_google_button'), findsNothing);
      expect(
        tester.widget<OutlinedButton>(_key('login_google_button')).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(_key('login_forgot_password_button'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<SegmentedButton<LoginMode>>(
              find.byType(SegmentedButton<LoginMode>),
            )
            .onSelectionChanged,
        isNull,
      );
      expect(
        tester.widget<TextFormField>(_key('login_email_field')).enabled,
        isFalse,
      );

      // 二重に送れない
      await tester.tap(_key('login_submit_button'), warnIfMissed: false);
      await tester.tap(_key('login_google_button'), warnIfMissed: false);
      await tester.pump();
      expect(t.repo.signIns, hasLength(1));
      expect(t.repo.googleSignIns, 0);

      t.repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(_spinnerIn('login_submit_button'), findsNothing);
      expect(
        tester.widget<OutlinedButton>(_key('login_google_button')).onPressed,
        isNotNull,
      );
    });

    testWidgets('Google の処理中は、Google のボタンにくるくる。送信は押せない', (tester) async {
      final t = await pumpLogin(tester);
      t.repo.gate = Completer<void>();
      await _tap(tester, 'login_google_button');
      expect(_spinnerIn('login_google_button'), findsOneWidget);
      expect(_spinnerIn('login_submit_button'), findsNothing);
      await _fill(tester, email: 'a@example.com', password: _pw);
      await tester.tap(_key('login_submit_button'), warnIfMissed: false);
      await tester.pump();
      expect(t.repo.signIns, isEmpty);
      t.repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(t.repo.googleSignIns, 1);
    });

    testWidgets('処理が終わる前に画面を閉じても、例外にならない', (tester) async {
      final t = await pumpLogin(tester);
      t.repo.gate = Completer<void>();
      await _fill(tester, email: 'a@example.com', password: _pw);
      await _tap(tester, 'login_submit_button');
      await tester.pumpWidget(const SizedBox());
      t.repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('エラーの帯', () {
    testWidgets('メールのログインに失敗したら、カードの中に文言を出す', (tester) async {
      final t = await pumpLogin(tester);
      t.repo.errors['signIn'] = authError('invalid-credential');
      await _fill(tester, email: 'a@example.com', password: _pw);
      await _tap(tester, 'login_submit_button');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _key('login_error'),
          matching: find.text('メールアドレスかパスワードが違います。'),
        ),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      // 失敗の後は、また押せる
      expect(_spinnerIn('login_submit_button'), findsNothing);
    });

    testWidgets('新規登録で登録済みなら、案内を出す', (tester) async {
      final t = await pumpLogin(tester, mode: LoginMode.signUp);
      t.repo.errors['signUp'] = authError('email-already-in-use');
      await _fill(tester, email: 'a@example.com', password: _pw, confirm: _pw);
      await _tap(tester, 'login_submit_button');
      await tester.pumpAndSettle();
      expect(
        find.text('このメールアドレスはすでに登録されています。「ログイン」から入ってください。'),
        findsOneWidget,
      );
    });

    testWidgets('Google のポップアップがブロックされたら、文言を出す', (tester) async {
      final t = await pumpLogin(tester);
      t.repo.errors['google'] = authError('popup-blocked');
      await _tap(tester, 'login_google_button');
      await tester.pumpAndSettle();
      expect(_key('login_error'), findsOneWidget);
      expect(find.textContaining('ポップアップがブロックされました'), findsOneWidget);
    });

    testWidgets('想定外の例外でも、中身は出さずに汎用の文言を出し、また押せる', (tester) async {
      final t = await pumpLogin(tester);
      t.repo.errors['signIn'] = StateError('secret-detail');
      await _fill(tester, email: 'a@example.com', password: _pw);
      await _tap(tester, 'login_submit_button');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _key('login_error'),
          matching: find.text('うまくいきませんでした。もう一度お試しください。'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('secret-detail'), findsNothing);
      expect(_spinnerIn('login_submit_button'), findsNothing);
    });

    testWidgets('Google でも、想定外の例外は汎用の文言', (tester) async {
      final t = await pumpLogin(tester);
      t.repo.errors['google'] = StateError('secret-detail');
      await _tap(tester, 'login_google_button');
      await tester.pumpAndSettle();
      expect(find.text('うまくいきませんでした。もう一度お試しください。'), findsOneWidget);
    });

    testWidgets('自分でポップアップを閉じたときは、何も出さない', (tester) async {
      final t = await pumpLogin(tester);
      t.repo.errors['google'] = authError('popup-closed-by-user');
      await _tap(tester, 'login_google_button');
      await tester.pumpAndSettle();
      expect(_key('login_error'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester.widget<OutlinedButton>(_key('login_google_button')).onPressed,
        isNotNull,
      );
    });

    testWidgets('次の送信を始めたら、前のエラーは消える', (tester) async {
      final t = await pumpLogin(tester);
      t.repo.errors['signIn'] = authError('invalid-credential');
      await _fill(tester, email: 'a@example.com', password: _pw);
      await _tap(tester, 'login_submit_button');
      await tester.pumpAndSettle();
      expect(_key('login_error'), findsOneWidget);
      await _tap(tester, 'login_submit_button');
      await tester.pumpAndSettle();
      expect(_key('login_error'), findsNothing);
    });

    testWidgets('エラーの文言にパスワードを含めない', (tester) async {
      final t = await pumpLogin(tester);
      t.repo.errors['signIn'] = authError('wrong-password');
      await _fill(tester, email: 'a@example.com', password: _pw);
      await _tap(tester, 'login_submit_button');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _key('login_error'),
          matching: find.textContaining(_pw),
        ),
        findsNothing,
      );
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('パスワードの再設定', () {
    Future<FakeAuthRepository> openDialog(
      WidgetTester tester, {
      String email = '',
    }) async {
      final t = await pumpLogin(tester);
      if (email.isNotEmpty) await _fill(tester, email: email);
      await _tap(tester, 'login_forgot_password_button');
      await tester.pumpAndSettle();
      return t.repo;
    }

    String resetFieldText(WidgetTester tester) => tester
        .widget<TextFormField>(_key('reset_email_field'))
        .controller!
        .text;

    testWidgets('ログイン画面のメールアドレスを入れた状態で開く', (tester) async {
      await openDialog(tester, email: ' a@example.com ');
      expect(resetFieldText(tester), 'a@example.com');
    });

    testWidgets('送ると、成功の文言を出し、送るボタンは消える。メールは前後の空白なしで渡る', (tester) async {
      final repo = await openDialog(tester);
      await tester.enterText(_key('reset_email_field'), ' a@example.com ');
      await _tap(tester, 'reset_send_button');
      await tester.pumpAndSettle();
      expect(repo.resets, [' a@example.com ']);
      expect(
        find.text('入力したメールアドレスが登録されていれば、パスワードを再設定するメールを送りました。'),
        findsOneWidget,
      );
      expect(_key('reset_send_button'), findsNothing);
      await _tap(tester, 'reset_close_button');
      await tester.pumpAndSettle();
      expect(_key('reset_email_field'), findsNothing);
    });

    testWidgets('user-not-found でも、同じ文言（登録の有無を知らせない）', (tester) async {
      final repo = await openDialog(tester, email: 'nobody@example.com');
      repo.errors['reset'] = authError('user-not-found');
      await _tap(tester, 'reset_send_button');
      await tester.pumpAndSettle();
      expect(
        find.text('入力したメールアドレスが登録されていれば、パスワードを再設定するメールを送りました。'),
        findsOneWidget,
      );
      expect(_key('reset_error'), findsNothing);
    });

    testWidgets('想定外の例外でも、中身は出さずに汎用の文言を出す。送るボタンは残る', (tester) async {
      final repo = await openDialog(tester, email: 'a@example.com');
      repo.errors['reset'] = StateError('secret-detail');
      await _tap(tester, 'reset_send_button');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _key('reset_error'),
          matching: find.text('うまくいきませんでした。もう一度お試しください。'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('secret-detail'), findsNothing);
      expect(_key('reset_sent_message'), findsNothing);
      expect(_key('reset_send_button'), findsOneWidget);
    });

    testWidgets('それ以外のエラーは、エラーの文言。送るボタンは残る', (tester) async {
      final repo = await openDialog(tester, email: 'a@example.com');
      repo.errors['reset'] = authError('too-many-requests');
      await _tap(tester, 'reset_send_button');
      await tester.pumpAndSettle();
      expect(_key('reset_sent_message'), findsNothing);
      expect(
        find.descendant(
          of: _key('reset_error'),
          matching: find.text('試した回数が多すぎます。しばらく待ってから、もう一度お試しください。'),
        ),
        findsOneWidget,
      );
      expect(_key('reset_send_button'), findsOneWidget);
    });

    testWidgets('形の違うメールアドレスは送らず、検査のエラーを出す', (tester) async {
      final repo = await openDialog(tester, email: 'abc');
      await _tap(tester, 'reset_send_button');
      expect(find.text('メールアドレスの形が正しくありません。'), findsOneWidget);
      expect(repo.resets, isEmpty);
    });

    testWidgets('空のままでも送らない', (tester) async {
      final repo = await openDialog(tester);
      await _tap(tester, 'reset_send_button');
      expect(find.text('メールアドレスを入れてください。'), findsOneWidget);
      expect(repo.resets, isEmpty);
    });

    testWidgets('送信中は、送るボタンと閉じるが押せず、二重に送れない', (tester) async {
      final repo = await openDialog(tester, email: 'a@example.com');
      repo.gate = Completer<void>();
      await _tap(tester, 'reset_send_button');
      expect(_spinnerIn('reset_send_button'), findsOneWidget);
      expect(
        tester.widget<TextButton>(_key('reset_close_button')).onPressed,
        isNull,
      );
      await tester.tap(_key('reset_send_button'), warnIfMissed: false);
      await tester.pump();
      expect(repo.resets, hasLength(1));
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(_key('reset_sent_message'), findsOneWidget);
    });
  });

  group('戻るボタン', () {
    testWidgets('紹介ページ（/welcome）へ移す', (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
          GoRoute(
            path: '/welcome',
            builder: (_, _) => const Text('route:welcome'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await _tap(tester, 'login_back_button');
      await tester.pumpAndSettle();
      expect(find.text('route:welcome'), findsOneWidget);
    });
  });

  group('reCAPTCHA の文言', () {
    testWidgets('規約の文言が出る', (tester) async {
      await pumpLogin(tester);
      expect(notice, findsOneWidget);
      expect(
        find.textContaining(
          'このサイトは reCAPTCHA で保護されており、Google のプライバシーポリシーと利用規約が適用されます。',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('新規登録のモードでも出る', (tester) async {
      await pumpLogin(tester, mode: LoginMode.signUp);
      expect(notice, findsOneWidget);
    });

    testWidgets('プライバシーポリシーと利用規約を、正しい URL で開く', (tester) async {
      final t = await pumpLogin(tester);
      // テスト用フォントではタップ位置の特定が不安定なので、リンクの onTap を直接呼ぶ
      void tapLink(String text) {
        final root = tester.widget<Text>(notice).textSpan! as TextSpan;
        final span = root.children!.whereType<TextSpan>().firstWhere(
          (s) => s.text == text,
        );
        (span.recognizer! as TapGestureRecognizer).onTap!();
      }

      tapLink('プライバシーポリシー');
      await tester.pump();
      expect(t.opened, [Uri.parse('https://policies.google.com/privacy')]);
      tapLink('利用規約');
      await tester.pump();
      expect(t.opened.last, Uri.parse('https://policies.google.com/terms'));
      expect(t.opened.length, 2);
    });
  });

  group('スマホの幅（360px）', () {
    for (final mode in LoginMode.values) {
      testWidgets('${mode.name}: はみ出さず、下まで届く', (tester) async {
        await pumpLogin(tester, mode: mode, size: const Size(360, 640));
        expect(tester.takeException(), isNull);
        expect(find.text('Google で続ける'), findsOneWidget);
        // 縦はスクロールで届く
        await tester.ensureVisible(notice);
        await tester.pump();
        expect(tester.getSize(notice).width, lessThanOrEqualTo(360));
        // 横にはみ出す部品がない
        for (final k in [
          'login_google_button',
          'login_email_field',
          'login_password_field',
          'login_submit_button',
        ]) {
          final rect = tester.getRect(_key(k));
          expect(rect.left, greaterThanOrEqualTo(0), reason: k);
          expect(rect.right, lessThanOrEqualTo(360), reason: k);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('エラーの帯が出ても、はみ出さない', (tester) async {
      final t = await pumpLogin(tester, size: const Size(360, 640));
      t.repo.errors['signIn'] = authError('operation-not-allowed');
      await _fill(tester, email: 'a@example.com', password: _pw);
      await tester.ensureVisible(_key('login_submit_button'));
      await _tap(tester, 'login_submit_button');
      await tester.pumpAndSettle();
      expect(_key('login_error'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
