// テーマカラーの色見本（プロフィール）のテスト（Q1）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/profile/theme_color_picker.dart';
import 'package:oshiashi/models/user_profile.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/providers/profile_providers.dart';
import 'package:oshiashi/repositories/profile_repository.dart';

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository(this.profile);
  UserProfile? profile;
  final List<({String uid, int? color})> saved = [];
  Object? error;

  @override
  Stream<UserProfile?> watch(String uid) => Stream.value(profile);

  final List<({String name, String? x})> saves = [];

  @override
  Future<void> save(
    String uid, {
    required String displayName,
    String? xAccount,
  }) async {
    saves.add((name: displayName, x: xAccount));
  }

  @override
  Future<void> saveThemeColor(String uid, int? color) async {
    saved.add((uid: uid, color: color));
    if (error != null) throw error!;
  }
}

Future<void> pumpPicker(
  WidgetTester tester,
  FakeProfileRepository repo, {
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: ThemeColorPicker())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder swatch(Color c) =>
    find.byKey(Key('theme_color_${c.toARGB32().toRadixString(16)}'));

void main() {
  const profile = UserProfile(displayName: 'あ');

  testWidgets('色見本は12個、円は 44×44（輪を含めて 56）', (tester) async {
    await pumpPicker(tester, FakeProfileRepository(profile));
    expect(kThemeColorPresets.length, 12);
    for (final (_, c) in kThemeColorPresets) {
      expect(swatch(c), findsOneWidget);
    }
    expect(
      tester.getSize(swatch(kThemeColorPresets.first.$2)),
      const Size(56, 56),
    );
  });

  testWidgets('選んでいないときは check が出ない', (tester) async {
    await pumpPicker(tester, FakeProfileRepository(profile));
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('保存済みの色にだけ check。見本に無い色なら何も付かない', (tester) async {
    const c = Color(0xFF283593);
    await pumpPicker(
      tester,
      FakeProfileRepository(
        UserProfile(displayName: 'あ', themeColor: c.toARGB32()),
      ),
    );
    expect(
      find.descendant(of: swatch(c), matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check), findsOneWidget);

    await pumpPicker(
      tester,
      FakeProfileRepository(
        const UserProfile(displayName: 'あ', themeColor: 0xFF795548),
      ),
    );
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('check の色は onThemeColor（ネイビーは白・オレンジは墨）', (tester) async {
    for (final (c, white) in [
      (const Color(0xFF283593), true),
      (const Color(0xFFFF9F1C), false),
    ]) {
      await pumpPicker(
        tester,
        FakeProfileRepository(
          UserProfile(displayName: 'あ', themeColor: c.toARGB32()),
        ),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(icon.color == Colors.white, white);
    }
  });

  testWidgets('押すと saveThemeColor が ARGB で呼ばれる', (tester) async {
    final repo = FakeProfileRepository(profile);
    await pumpPicker(tester, repo);
    await tester.tap(swatch(const Color(0xFF8E24AA)));
    await tester.pumpAndSettle();
    expect(repo.saved, [(uid: 'u1', color: 0xFF8E24AA)]);
  });

  testWidgets('「初期の色に戻す」は色があるときだけ押せて、null で保存する', (tester) async {
    final repo = FakeProfileRepository(profile);
    await pumpPicker(tester, repo);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('theme_color_reset')))
          .onPressed,
      isNull,
    );

    final repo2 = FakeProfileRepository(
      const UserProfile(displayName: 'あ', themeColor: 0xFFE8452C),
    );
    await pumpPicker(tester, repo2);
    await tester.tap(find.byKey(const Key('theme_color_reset')));
    await tester.pumpAndSettle();
    expect(repo2.saved, [(uid: 'u1', color: null)]);
  });

  testWidgets('保存に失敗したら日本語の SnackBar', (tester) async {
    final repo = FakeProfileRepository(profile)..error = Exception('x');
    await pumpPicker(tester, repo);
    await tester.tap(swatch(const Color(0xFFE8452C)));
    await tester.pumpAndSettle();
    expect(find.text('テーマカラーを保存できませんでした'), findsOneWidget);
  });

  testWidgets('幅 320・360・390・1000 ではみ出さない', (tester) async {
    for (final w in [320.0, 360.0, 390.0, 1000.0]) {
      await pumpPicker(tester, FakeProfileRepository(profile), width: w);
      expect(tester.takeException(), isNull, reason: 'w=$w');
    }
  });
}
