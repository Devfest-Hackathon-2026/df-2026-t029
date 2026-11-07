// プロフィール画面（/profile）のテスト。作成・編集・検査・色見本・はみ出し。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/profile/profile_page.dart';
import 'package:oshiashi/models/user_profile.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/providers/profile_providers.dart';
import 'package:oshiashi/providers/theme_providers.dart';
import 'package:oshiashi/theme/app_theme.dart';
import 'package:oshiashi/theme/brand_colors.dart';

import 'theme_color_picker_test.dart' show FakeProfileRepository;

Finder _key(String k) => find.byKey(Key(k));

Future<GoRouter> pumpProfile(
  WidgetTester tester,
  FakeProfileRepository repo, {
  double width = 390,
  double textScale = 1,
  bool canPop = true,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: canPop ? '/from' : '/profile',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Text('route:/'),
        routes: [
          GoRoute(path: 'profile', builder: (_, _) => const ProfilePage()),
        ],
      ),
      GoRoute(
        path: '/from',
        builder: (c, _) => TextButton(
          onPressed: () => c.push('/profile'),
          child: const Text('開く'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(
        theme: buildAppTheme(
          Color(repo.profile?.themeColor ?? kDefaultSeedColor.toARGB32()),
        ),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (canPop) {
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
  }
  return router;
}

void main() {
  const profile = UserProfile(displayName: 'ルナ', xAccount: 'luna_x');

  testWidgets('編集: 上のバーはテーマカラー。名前・X が入り、色見本が12個ある', (tester) async {
    await pumpProfile(tester, FakeProfileRepository(profile));
    expect(find.text('プロフィールを編集'), findsOneWidget);
    expect(find.text('ルナ'), findsOneWidget);
    expect(find.text('luna_x'), findsOneWidget);
    final bar = tester.widget<AppBar>(_key('hako_app_bar'));
    expect(bar.backgroundColor, const Color(0xFFFF9F1C));
    expect(_key('hako_back'), findsOneWidget);
    // 色見本
    expect(find.text('テーマカラー'), findsOneWidget);
    expect(find.byKey(const Key('theme_color_reset')), findsOneWidget);
  });

  testWidgets('上のバーにアカウントのボタンは出ない', (tester) async {
    await pumpProfile(tester, FakeProfileRepository(profile));
    expect(find.byIcon(Icons.person_outline), findsNothing);
  });

  testWidgets('初回作成: 戻るが無く、テーマカラーは出ない', (tester) async {
    await pumpProfile(tester, FakeProfileRepository(null), canPop: false);
    expect(find.text('プロフィールを作成'), findsOneWidget);
    expect(_key('hako_back'), findsNothing);
    expect(find.text('テーマカラー'), findsNothing);
  });

  testWidgets('名前が空なら保存せず、エラーを出す', (tester) async {
    final repo = FakeProfileRepository(profile);
    await pumpProfile(tester, repo);
    await tester.enterText(find.byType(TextFormField).first, '  ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('ハンドルネームを入力してください'), findsOneWidget);
    expect(repo.saves, isEmpty);
  });

  testWidgets('X アカウントの検査（15文字・英数字と _）。先頭の @ は外す', (tester) async {
    final repo = FakeProfileRepository(profile);
    await pumpProfile(tester, repo);
    final x = find.byType(TextFormField).at(1);
    await tester.enterText(x, 'a' * 16);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('英数字と _ の15文字以内で入力してください'), findsOneWidget);
    await tester.enterText(x, 'あい');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repo.saves, isEmpty);

    await tester.enterText(x, '@${'a' * 15}');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repo.saves.single.x, 'a' * 15);
  });

  testWidgets('名前は20文字まで（入力欄の上限）', (tester) async {
    await pumpProfile(tester, FakeProfileRepository(profile));
    await tester.enterText(find.byType(TextFormField).first, 'あ' * 25);
    await tester.pump();
    expect(find.text('20/20'), findsOneWidget);
  });

  testWidgets('保存すると repo.save が呼ばれ、戻れる画面へ戻る', (tester) async {
    final repo = FakeProfileRepository(profile);
    await pumpProfile(tester, repo);
    await tester.enterText(find.byType(TextFormField).first, '新しい名前');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repo.saves.single.name, '新しい名前');
    expect(find.text('開く'), findsOneWidget);
  });

  testWidgets('色見本を押すと保存され、選んだ色に check', (tester) async {
    final repo = FakeProfileRepository(profile);
    await pumpProfile(tester, repo);
    final navy = find.byKey(const Key('theme_color_ff283593'));
    await tester.ensureVisible(navy);
    await tester.tap(navy);
    await tester.pumpAndSettle();
    expect(repo.saved.single.color, 0xFF283593);
  });

  testWidgets('テーマカラーが濃い色のとき、上のバーの文字は白', (tester) async {
    await pumpProfile(
      tester,
      FakeProfileRepository(
        const UserProfile(displayName: 'ルナ', themeColor: 0xFF283593),
      ),
    );
    final bar = tester.widget<AppBar>(_key('hako_app_bar'));
    expect(bar.backgroundColor, const Color(0xFF283593));
    expect(bar.foregroundColor, Colors.white);
    expect(BrandColors.ink, isNotNull);
  });

  for (final w in [320.0, 360.0, 390.0, 720.0, 1000.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('幅 ${w.toInt()}・文字 $scale 倍ではみ出さない', (tester) async {
        await pumpProfile(
          tester,
          FakeProfileRepository(profile),
          width: w,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
