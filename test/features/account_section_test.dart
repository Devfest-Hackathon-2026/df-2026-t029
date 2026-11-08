// 「アカウント」の区画（AccountSection）のテスト
import 'package:flutter_test/flutter_test.dart';

import 'email_change_test_helpers.dart';

void main() {
  testWidgets('メール登録の人: 行・説明・伏せ字が出る', (tester) async {
    await pumpAccount(tester);
    expect(k('profile_account_section'), findsOneWidget);
    expect(find.text('アカウント'), findsOneWidget);
    expect(k('profile_email_row'), findsOneWidget);
    expect(find.text('ke******@example.com'), findsOneWidget);
    expect(find.text('ken-oshi@example.com'), findsNothing);
    expect(find.text('ログインに使うメールアドレスです。タップして変更できます。'), findsOneWidget);
    expect(k('profile_google_row'), findsNothing);
  });

  testWidgets('パスワードと Google の両方を持つ人は、メール登録の形', (tester) async {
    await pumpAccount(tester, providers: ['google.com', 'password']);
    expect(k('profile_email_row'), findsOneWidget);
    expect(k('profile_google_row'), findsNothing);
  });

  testWidgets('行を押すとシートが開く', (tester) async {
    await pumpAccount(tester);
    expect(k('email_sheet'), findsNothing);
    await openSheet(tester);
    expect(k('email_sheet'), findsOneWidget);
  });

  testWidgets('Google の人: 押せない行・説明が出る。行を押してもシートは開かない', (tester) async {
    await pumpAccount(tester, providers: ['google.com']);
    expect(k('profile_google_row'), findsOneWidget);
    expect(k('profile_email_row'), findsNothing);
    expect(find.text('Googleアカウントでログイン中'), findsOneWidget);
    expect(find.textContaining('Googleアカウント側で管理されています'), findsOneWidget);
    await tester.tap(k('profile_google_row'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(k('email_sheet'), findsNothing);
  });

  testWidgets('Google の人: 「表示」で全体、「かくす」で伏せ字に戻る', (tester) async {
    await pumpAccount(tester, providers: ['google.com']);
    expect(find.text('ke******@example.com'), findsOneWidget);
    expect(find.text('表示'), findsOneWidget);
    await tester.tap(k('email_reveal_button'));
    await tester.pump();
    expect(find.text('ken-oshi@example.com'), findsOneWidget);
    expect(find.text('かくす'), findsOneWidget);
    await tester.tap(k('email_reveal_button'));
    await tester.pump();
    expect(find.text('ke******@example.com'), findsOneWidget);
    expect(find.text('ken-oshi@example.com'), findsNothing);
  });

  testWidgets('other・メールなしでは、何も出ない', (tester) async {
    await pumpAccount(tester, providers: ['phone']);
    expect(k('profile_account_section'), findsNothing);
    await pumpAccount(tester, providers: []);
    expect(k('profile_account_section'), findsNothing);
    await pumpAccount(tester, email: null);
    expect(k('profile_account_section'), findsNothing);
    await pumpAccount(tester, email: '');
    expect(k('profile_account_section'), findsNothing);
  });

  for (final width in [320.0, 390.0, 700.0, 1000.0]) {
    for (final scale in [1.0, 1.3]) {
      for (final provider in ['password', 'google.com']) {
        testWidgets('幅 $width・文字 $scale 倍・$provider ではみ出さない', (tester) async {
          await pumpAccount(
            tester,
            width: width,
            textScale: scale,
            providers: [provider],
            email:
                'a-very-long-address-for-overflow-check@subdomain.example.com',
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
