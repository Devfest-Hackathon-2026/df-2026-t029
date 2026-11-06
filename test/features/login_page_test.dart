import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/auth/login_page.dart';
import 'package:oshiashi/features/live/official_url_link.dart';

Finder get notice => find.byKey(const Key('login_recaptcha_notice'));

Future<List<Uri>> pumpLogin(WidgetTester tester) async {
  final opened = <Uri>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        urlLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
      child: const MaterialApp(home: LoginPage()),
    ),
  );
  return opened;
}

void main() {
  testWidgets('reCAPTCHA の規約の文言が出る', (tester) async {
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

  testWidgets('プライバシーポリシーと利用規約を、正しい URL で開く', (tester) async {
    final opened = await pumpLogin(tester);
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
    expect(opened, [Uri.parse('https://policies.google.com/privacy')]);
    tapLink('利用規約');
    await tester.pump();
    expect(opened.last, Uri.parse('https://policies.google.com/terms'));
    expect(opened.length, 2);
  });

  testWidgets('スマホの幅（360px）でもはみ出さない。ログインボタンも出る', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpLogin(tester);
    expect(tester.takeException(), isNull);
    expect(notice, findsOneWidget);
    expect(find.text('Google でログイン'), findsOneWidget);
    expect(tester.getSize(notice).width, lessThanOrEqualTo(360));
  });
}
