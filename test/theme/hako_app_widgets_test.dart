import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';
import 'package:oshiashi/theme/brand_colors.dart';
import 'package:oshiashi/theme/hako_app_widgets.dart';

// AccountMenuButton が authStateProvider を読むので、Firebase 未初期化にならないよう差し替える
final _overrides = [
  authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
  currentUidProvider.overrideWithValue(null),
];

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpApp(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 800),
  Color hue = BrandColors.hall3,
}) async {
  _size(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides,
      child: MaterialApp(
        home: HakoHue(
          color: hue,
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

Color? _boxColor(WidgetTester tester, Finder f) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: f, matching: find.byType(DecoratedBox)).first,
  );
  return (box.decoration as BoxDecoration).color;
}

void main() {
  group('hueForPath', () {
    const cases = <String, Color>{
      '/': BrandColors.hall3,
      '/oshi': BrandColors.hall1,
      '/oshi/search': BrandColors.hall1,
      '/oshi/request': BrandColors.hall1,
      '/lives': BrandColors.hall5,
      '/lives/add': BrandColors.hall5,
      '/lives/abc': BrandColors.hall5,
      '/lives/abc/edit': BrandColors.hall5,
      '/lives/abc/memory/p1': BrandColors.hall5, // 青（メモリーの緑ではない）
      '/register': BrandColors.hall5,
      '/live-form': BrandColors.hall5,
      '/memories': BrandColors.hall4,
      '/memories/p1': BrandColors.hall4,
      '/trade': BrandColors.hall6,
      '/trade/post/new': BrandColors.hall6,
      '/chats': BrandColors.hall6,
      '/chats/c1': BrandColors.hall6,
      '/goods': BrandColors.hall6,
      '/goods/new': BrandColors.hall6,
      '/expenses': BrandColors.hall3,
      '/profile': BrandColors.hall3,
      '/unknown': BrandColors.hall3,
      '': BrandColors.hall3,
    };
    cases.forEach((path, color) {
      test('「$path」', () => expect(hueForPath(path), color));
    });

    test('前方一致だけで決めない（/oshiX・/livesX は黄）', () {
      expect(hueForPath('/oshiX'), BrandColors.hall3);
      expect(hueForPath('/livesX'), BrandColors.hall3);
      expect(hueForPath('/memoriesX'), BrandColors.hall3);
    });
  });

  group('HakoHue', () {
    testWidgets('見つからなければ黄', (tester) async {
      late Color c;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            c = HakoHue.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(c, BrandColors.hall3);
    });
  });

  group('HakoPageScaffold', () {
    Future<void> pumpScaffold(
      WidgetTester tester,
      Size size, {
      bool showBack = false,
      Color? barColor,
      Widget? bottomBar,
      Widget? fab,
      GoRouter? router,
    }) async {
      _size(tester, size);
      final page = HakoPageScaffold(
        title: 'テスト画面',
        showBack: showBack,
        backFallback: '/fallback',
        barColor: barColor,
        bottomBar: bottomBar,
        floatingActionButton: fab,
        body: const Text('本文'),
      );
      final r =
          router ??
          GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => page),
              GoRoute(
                path: '/fallback',
                builder: (_, _) => const Scaffold(body: Text('戻り先')),
              ),
            ],
          );
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides,
          child: HakoHue(
            color: BrandColors.hall5,
            child: MaterialApp.router(routerConfig: r),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('幅 390: 上のバーが出て、PC のタイトルは出ない', (tester) async {
      await pumpScaffold(tester, const Size(390, 800));
      expect(find.byKey(const Key('hako_app_bar')), findsOneWidget);
      expect(find.byKey(const Key('hako_page_title')), findsNothing);
      expect(tester.getSize(find.byKey(const Key('hako_app_bar'))).height, 56);
      expect(find.text('テスト画面'), findsOneWidget);
      expect(find.text('本文'), findsOneWidget);
      // 背景はページの色（青）
      final bar = tester.widget<AppBar>(find.byKey(const Key('hako_app_bar')));
      expect(bar.backgroundColor, BrandColors.hall5);
    });

    testWidgets('幅 1000: 上のバーは出ず、タイトルが本文の上に出る', (tester) async {
      await pumpScaffold(tester, const Size(1000, 800));
      expect(find.byKey(const Key('hako_app_bar')), findsNothing);
      expect(find.byKey(const Key('hako_page_title')), findsOneWidget);
      expect(find.text('テスト画面'), findsOneWidget);
      final titleY = tester.getTopLeft(
        find.byKey(const Key('hako_page_title')),
      );
      final bodyY = tester.getTopLeft(find.text('本文'));
      expect(titleY.dy, lessThan(bodyY.dy));
    });

    testWidgets('幅 720 は PC・719 はスマホ（境界）', (tester) async {
      await pumpScaffold(tester, const Size(720, 800));
      expect(find.byKey(const Key('hako_page_title')), findsOneWidget);
      await pumpScaffold(tester, const Size(719, 800));
      expect(find.byKey(const Key('hako_app_bar')), findsOneWidget);
    });

    testWidgets('幅 1000: 本文は最大 640 で中央', (tester) async {
      await pumpScaffold(tester, const Size(1000, 800));
      final w = tester.getSize(find.byKey(const Key('hako_page_title'))).width;
      expect(w, lessThanOrEqualTo(640));
    });

    testWidgets('showBack でないとき戻るは出ない', (tester) async {
      await pumpScaffold(tester, const Size(390, 800));
      expect(find.byKey(const Key('hako_back')), findsNothing);
      await pumpScaffold(tester, const Size(1000, 800));
      expect(find.byKey(const Key('hako_back')), findsNothing);
    });

    for (final size in const [Size(390, 800), Size(1000, 800)]) {
      testWidgets('幅 ${size.width.toInt()}: 戻れないとき backFallback へ移る', (
        tester,
      ) async {
        await pumpScaffold(tester, size, showBack: true);
        expect(find.byKey(const Key('hako_back')), findsOneWidget);
        await tester.tap(find.byKey(const Key('hako_back')));
        await tester.pumpAndSettle();
        expect(find.text('戻り先'), findsOneWidget);
      });

      testWidgets('幅 ${size.width.toInt()}: 戻れるとき前の画面へ戻る', (tester) async {
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('前の画面')),
            ),
            GoRoute(
              path: '/child',
              builder: (_, _) => const HakoPageScaffold(
                title: '子',
                showBack: true,
                backFallback: '/fallback',
                body: Text('子の本文'),
              ),
            ),
            GoRoute(
              path: '/fallback',
              builder: (_, _) => const Scaffold(body: Text('戻り先')),
            ),
          ],
        );
        await pumpScaffold(tester, size, router: router);
        router.push('/child');
        await tester.pumpAndSettle();
        expect(find.text('子の本文'), findsOneWidget);
        await tester.tap(find.byKey(const Key('hako_back')));
        await tester.pumpAndSettle();
        expect(find.text('前の画面'), findsOneWidget);
        expect(find.text('戻り先'), findsNothing);
      });
    }

    testWidgets('barColor が濃いときは、バーの文字が白になる', (tester) async {
      await pumpScaffold(
        tester,
        const Size(390, 800),
        barColor: const Color(0xFF283593),
      );
      final bar = tester.widget<AppBar>(find.byKey(const Key('hako_app_bar')));
      expect(bar.backgroundColor, const Color(0xFF283593));
      expect(bar.foregroundColor, Colors.white);
    });

    testWidgets('bottomBar と右下のボタンが出る（スマホ・PC）', (tester) async {
      for (final size in const [Size(390, 800), Size(1000, 800)]) {
        await pumpScaffold(
          tester,
          size,
          bottomBar: const HakoSaveBar(child: Text('保存')),
          fab: FloatingActionButton.extended(
            onPressed: () {},
            label: const Text('追加する'),
          ),
        );
        expect(find.byKey(const Key('hako_save_bar')), findsOneWidget);
        expect(find.text('追加する'), findsOneWidget);
      }
    });

    testWidgets('showDesktopTitle: 幅 1000 で false なら PC のタイトルを出さない', (
      tester,
    ) async {
      _size(tester, const Size(1000, 800));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides,
          child: MaterialApp(
            home: HakoPageScaffold(
              title: 'おしあし',
              showDesktopTitle: false,
              body: const Text('本文'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('hako_page_title')), findsNothing);
      expect(find.byKey(const Key('hako_app_bar')), findsNothing);
      expect(find.text('本文'), findsOneWidget);
    });

    testWidgets('showDesktopTitle: 幅 390 で false でも上のバーは出る', (tester) async {
      _size(tester, const Size(390, 800));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides,
          child: MaterialApp(
            home: HakoPageScaffold(
              title: 'おしあし',
              showDesktopTitle: false,
              body: const Text('本文'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('hako_app_bar')), findsOneWidget);
      expect(find.byKey(const Key('hako_page_title')), findsNothing);
    });

    testWidgets('showDesktopTitle: 幅 1000 で true（既定）なら PC のタイトルが出る', (
      tester,
    ) async {
      _size(tester, const Size(1000, 800));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides,
          child: MaterialApp(
            home: HakoPageScaffold(title: 'おしあし', body: const Text('本文')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('hako_page_title')), findsOneWidget);
    });

    testWidgets('幅 320 〜 1000 で、はみ出さない', (tester) async {
      for (final w in [320.0, 360.0, 390.0, 430.0, 720.0, 1000.0]) {
        await pumpScaffold(tester, Size(w, 700), showBack: true);
        expect(tester.takeException(), isNull, reason: 'w=$w');
      }
    });
  });

  group('HakoDateBadge', () {
    testWidgets('月・数字・曜日を出す。48×56・ページの色', (tester) async {
      // 2026-11-05 は木曜
      await _pumpApp(
        tester,
        HakoDateBadge(date: DateTime(2026, 11, 5)),
        hue: BrandColors.hall5,
      );
      expect(find.text('11月'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('木'), findsOneWidget);
      expect(tester.getSize(find.byType(HakoDateBadge)), const Size(48, 56));
      expect(_boxColor(tester, find.byType(HakoDateBadge)), BrandColors.hall5);
    });

    testWidgets('曜日: 月曜〜日曜が順に出る（境界: 日曜・月曜）', (tester) async {
      const names = ['月', '火', '水', '木', '金', '土', '日'];
      for (var i = 0; i < 7; i++) {
        // 2026-11-02 は月曜
        await _pumpApp(tester, HakoDateBadge(date: DateTime(2026, 11, 2 + i)));
        expect(find.text(names[i]), findsOneWidget, reason: names[i]);
      }
    });

    testWidgets('2桁の日・12月でも収まる', (tester) async {
      await _pumpApp(tester, HakoDateBadge(date: DateTime(2026, 12, 31)));
      expect(find.text('12月'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(HakoDateBadge)), const Size(48, 56));
    });

    testWidgets('読み上げない', (tester) async {
      await _pumpApp(tester, HakoDateBadge(date: DateTime(2026, 11, 5)));
      expect(
        find.descendant(
          of: find.byType(HakoDateBadge),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });
  });

  group('HakoStatusChip', () {
    test('種類ごとの色（申込＝赤・当落＝黄・入金＝緑・ふつう＝tonal）', () {
      expect(
        const HakoStatusChip('a', kind: HakoChipKind.apply).color,
        BrandColors.hall1,
      );
      expect(
        const HakoStatusChip('d', kind: HakoChipKind.draw).color,
        BrandColors.hall3,
      );
      expect(
        const HakoStatusChip('p', kind: HakoChipKind.pay).color,
        BrandColors.hall4,
      );
      expect(const HakoStatusChip('n').color, BrandColors.tonal);
    });

    testWidgets('文字が出て、背景がその色・枠 2px の墨', (tester) async {
      await _pumpApp(
        tester,
        const HakoStatusChip('申込', kind: HakoChipKind.apply),
      );
      expect(find.text('申込'), findsOneWidget);
      final f = find.byType(HakoStatusChip);
      expect(_boxColor(tester, f), BrandColors.hall1);
      final deco =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(of: f, matching: find.byType(DecoratedBox))
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      final side = (deco.border! as Border).top;
      expect(side.width, 2);
      expect(side.color, BrandColors.ink);
    });
  });

  group('HakoTagChip', () {
    testWidgets('通常は tonal・リンクは tonal2', (tester) async {
      await _pumpApp(tester, const HakoTagChip('グループ'));
      expect(_boxColor(tester, find.byType(HakoTagChip)), BrandColors.tonal);
      await _pumpApp(tester, const HakoTagChip('メンバーを見る ›', link: true));
      expect(_boxColor(tester, find.byType(HakoTagChip)), BrandColors.tonal2);
    });
  });

  group('HakoCountBadge', () {
    testWidgets('背景は墨・文字はページの色', (tester) async {
      await _pumpApp(
        tester,
        const HakoCountBadge('あと5日'),
        hue: BrandColors.hall4,
      );
      expect(find.text('あと5日'), findsOneWidget);
      expect(_boxColor(tester, find.byType(HakoCountBadge)), BrandColors.ink);
      expect(
        tester.widget<Text>(find.text('あと5日')).style!.color,
        BrandColors.hall4,
      );
    });
  });

  group('HakoSaveBar', () {
    testWidgets('キーがあり、紙の背景・中の子を出す', (tester) async {
      await _pumpApp(tester, const HakoSaveBar(child: Text('保存')));
      expect(find.byKey(const Key('hako_save_bar')), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      final deco =
          tester
                  .widget<DecoratedBox>(find.byKey(const Key('hako_save_bar')))
                  .decoration
              as BoxDecoration;
      expect(deco.color, BrandColors.paper);
    });

    testWidgets('幅いっぱいの子', (tester) async {
      await _pumpApp(
        tester,
        HakoSaveBar(
          child: FilledButton(onPressed: () {}, child: const Text('保存')),
        ),
      );
      // 左右の余白 16 を引いた幅
      expect(tester.getSize(find.byType(FilledButton)).width, 390 - 32);
    });
  });

  group('その他の部品', () {
    testWidgets('HakoSectionHeader: 見出しと「すべて見る」。押すと呼ばれる', (tester) async {
      var tapped = 0;
      await _pumpApp(
        tester,
        HakoSectionHeader(
          '次の締切',
          trailingLabel: 'すべて見る',
          onTrailing: () => tapped++,
        ),
      );
      expect(find.text('次の締切'), findsOneWidget);
      await tester.tap(find.text('すべて見る'));
      expect(tapped, 1);
    });

    testWidgets('HakoRow: タイトル・補足・チップが出て、押せる', (tester) async {
      var tapped = 0;
      await _pumpApp(
        tester,
        HakoRow(
          icon: Icons.calendar_today_outlined,
          title: 'ライブ名',
          subs: const ['補足1', '補足2'],
          chip: const HakoStatusChip('申込', kind: HakoChipKind.apply),
          onTap: () => tapped++,
        ),
      );
      expect(find.text('ライブ名'), findsOneWidget);
      expect(find.text('補足1'), findsOneWidget);
      expect(find.text('補足2'), findsOneWidget);
      expect(find.text('申込'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      await tester.tap(find.text('ライブ名'));
      expect(tapped, 1);
    });

    testWidgets('HakoRow: 長い文字・幅 320 でもはみ出さない', (tester) async {
      await _pumpApp(
        tester,
        SizedBox(
          width: 320,
          child: HakoRow(
            icon: Icons.mic,
            title: 'とても長いライブ名' * 12,
            subs: ['とても長い補足' * 12],
          ),
        ),
        size: const Size(320, 700),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('HakoBox・HakoEmpty・HakoMarked・HakoHardShadow', (tester) async {
      await _pumpApp(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HakoBox(child: Text('箱の中')),
            HakoEmpty('まだありません'),
            HakoMarked('見出し', style: TextStyle(fontSize: 15)),
            HakoHardShadow(child: SizedBox(width: 40, height: 40)),
          ],
        ),
      );
      expect(find.text('箱の中'), findsOneWidget);
      expect(find.text('まだありません'), findsOneWidget);
      expect(find.text('見出し'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('HakoHint（電球の行）', () {
    testWidgets('電球のアイコンと文字。電球は読み上げない', (tester) async {
      await _pumpApp(tester, const HakoHint('いちばん応援している推しです。'));
      expect(find.text('いちばん応援している推しです。'), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byIcon(Icons.lightbulb_outline),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
      expect(tester.getSize(find.byIcon(Icons.lightbulb_outline)).width, 18);
    });

    testWidgets('長い文でも折り返すだけではみ出さない（幅 320・文字 1.3 倍）', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpApp(
        tester,
        HakoHint('とても長い補足の文です。' * 20),
        size: const Size(320, 800),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('HakoGiveWantLine（譲・求のラベル）', () {
    const labels = {
      HakoGiveWantKind.give: '譲',
      HakoGiveWantKind.want: '求',
      HakoGiveWantKind.receive: 'もらえる',
      HakoGiveWantKind.offer: '出せる',
    };

    labels.forEach((kind, label) {
      testWidgets('$label: 札と本文が別の Text', (tester) async {
        await _pumpApp(tester, HakoGiveWantLine(kind: kind, text: 'アクスタ（A）'));
        expect(find.text(label), findsOneWidget);
        expect(find.text('アクスタ（A）'), findsOneWidget);
      });
    });

    testWidgets('札の色: 譲・もらえる=淡い桃、求・出せる=淡い黄。枠は墨 2px・角丸 6', (tester) async {
      const colors = {
        HakoGiveWantKind.give: BrandColors.hall6Soft,
        HakoGiveWantKind.receive: BrandColors.hall6Soft,
        HakoGiveWantKind.want: BrandColors.hall3Soft,
        HakoGiveWantKind.offer: BrandColors.hall3Soft,
      };
      for (final e in colors.entries) {
        await _pumpApp(tester, HakoGiveWantLine(kind: e.key, text: '本文'));
        final badge = tester.widget<Container>(
          find
              .ancestor(
                of: find.text(labels[e.key]!),
                matching: find.byType(Container),
              )
              .first,
        );
        final d = badge.decoration! as BoxDecoration;
        expect(d.color, e.value, reason: '${e.key}');
        expect(d.borderRadius, BorderRadius.circular(6));
        expect((d.border! as Border).top.width, 2);
        expect((d.border! as Border).top.color, BrandColors.ink);
      }
    });

    testWidgets('淡い色の値（計画書 4.7）', (tester) async {
      expect(BrandColors.hall3Soft, const Color(0xFFFBF0B4));
      expect(BrandColors.hall1Soft, const Color(0xFFFBD6CE));
      expect(BrandColors.hall5Soft, const Color(0xFFD3E5FA));
      expect(BrandColors.hall6Soft, const Color(0xFFFADCE9));
      expect(BrandColors.hall4Soft, const Color(0xFFCDEFDF));
    });

    testWidgets('読み上げ: 譲→「譲（手放せるグッズ）」、求→「求（ほしいグッズ）」、他はそのまま', (tester) async {
      final handle = tester.ensureSemantics();
      const expected = {
        HakoGiveWantKind.give: '譲（手放せるグッズ）',
        HakoGiveWantKind.want: '求（ほしいグッズ）',
        HakoGiveWantKind.receive: 'もらえる',
        HakoGiveWantKind.offer: '出せる',
      };
      for (final e in expected.entries) {
        await _pumpApp(tester, HakoGiveWantLine(kind: e.key, text: '本文'));
        expect(find.bySemanticsLabel(e.value), findsOneWidget, reason: e.value);
      }
      handle.dispose();
    });

    testWidgets('本文が長くても折り返すだけ（幅 320・文字 1.3 倍）で、札は崩れない', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final kind in HakoGiveWantKind.values) {
        await _pumpApp(
          tester,
          // 実際の画面と同じく、高さが決まっていない並びの中に置く
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [HakoGiveWantLine(kind: kind, text: 'とても長い品目の名前、' * 15)],
          ),
          size: const Size(320, 800),
        );
        expect(tester.takeException(), isNull, reason: '$kind');
        // 札は縦に伸びず、最小の大きさ（24）以上で、1行ぶんの高さに収まる
        final badge = tester.getSize(
          find
              .ancestor(
                of: find.text(labels[kind]!),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(badge.height, lessThan(60), reason: '$kind');
        expect(badge.width, greaterThanOrEqualTo(24), reason: '$kind');
      }
    });
  });
}
