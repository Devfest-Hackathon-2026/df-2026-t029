// ShareTicketView（シェア画像。プレビュー・ホームのミニのカード・保存する画像で共通）のテスト（Q3・S3）。
// デザイン3種 × 形 × 写真 0〜4 枚、空の枠、上限と注記、座席が出ないこと、はみ出し。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/memory/share/share_ticket_view.dart';
import 'package:oshiashi/models/live_memory.dart';
import 'package:oshiashi/utils/share_ticket.dart';

import 'google_photos_test_helpers.dart';

const _secretSeat = 'SEAT-SECRET-A12ブロック';

ShareContent _content({
  List<String> setlist = const ['曲A', '曲B'],
  String? impression = '最高でした',
  String title = 'ツアー2026',
}) => ShareContent(
  title: title,
  startAt: DateTime.utc(2026, 12, 19, 9),
  venue: '東京ドーム',
  artist: 'ひかり',
  setlist: setlist,
  impression: impression,
  performerNames: const ['ひかり'],
);

ShareConfig _cfg(
  ShareTarget t, {
  ShareDesign design = ShareDesign.ticket,
  int format = 0,
  int bg = 0,
  bool memoImage = true,
}) {
  var c = ShareConfig.defaults(t);
  if (memoImage && !c.isOn(SharePart.memo, ShareLayer.image)) {
    c = c.toggled(SharePart.memo, ShareLayer.image);
  }
  return c.copyWith(design: design, formatIndex: format, backgroundIndex: bg);
}

Future<void> pumpView(
  WidgetTester tester, {
  required ShareContent content,
  required ShareConfig config,
  ShareTarget target = ShareTarget.x,
  int photos = 0,
  bool hints = false,
  bool mini = false,
  double width = 360,
  double textScale = 1,
  void Function(SharePart)? onTapPart,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: ShareTicketView(
                content: content,
                config: config,
                target: target,
                photoBytes: [for (var i = 0; i < photos; i++) validPng],
                hints: hints,
                mini: mini,
                onTapPart: onTapPart,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _text(String s) => find.textContaining(s, findRichText: true);

void main() {
  final designs = ShareDesign.values;

  group('比率と大きさ', () {
    for (final entry in shareFormats.entries) {
      for (final (i, f) in entry.value.indexed) {
        testWidgets(
          '${entry.key.name}・${f.label}: 幅いっぱい・比率 ${f.aspectW}:${f.aspectH}',
          (tester) async {
            await pumpView(
              tester,
              content: _content(),
              config: _cfg(entry.key, format: i),
              target: entry.key,
            );
            final size = tester.getSize(find.byType(ShareTicketView));
            expect(size.width, 360);
            expect(
              size.width / size.height,
              closeTo(f.aspectW / f.aspectH, 0.01),
            );
          },
        );
      }
    }
  });

  group('デザイン × 形 × 写真の枚数（描ける・例外が出ない）', () {
    for (final design in designs) {
      for (final entry in shareFormats.entries) {
        for (var i = 0; i < entry.value.length; i++) {
          for (final photos in [0, 1, 2, 3, 4]) {
            testWidgets('${design.name}・${entry.key.name}[$i]・写真 $photos 枚', (
              tester,
            ) async {
              await pumpView(
                tester,
                content: _content(),
                config: _cfg(entry.key, design: design, format: i),
                target: entry.key,
                photos: photos,
              );
              expect(tester.takeException(), isNull);
              expect(_text('ツアー2026'), findsWidgets);
              expect(_text('東京ドーム'), findsWidgets);
              expect(_text('12.19 SAT'), findsWidgets);
            });
          }
        }
      }
    }
  });

  group('のせる部分のオンオフ', () {
    for (final design in designs) {
      testWidgets('${design.name}: セトリ・感想をオフにすると出ない', (tester) async {
        var cfg = _cfg(ShareTarget.instagram, design: design);
        cfg = cfg
            .toggled(SharePart.setlist, ShareLayer.image)
            .toggled(SharePart.memo, ShareLayer.image);
        await pumpView(
          tester,
          content: _content(),
          config: cfg,
          target: ShareTarget.instagram,
        );
        expect(_text('曲A'), findsNothing);
        expect(_text('最高でした'), findsNothing);
      });

      testWidgets('${design.name}: セトリ・感想をオンにすると出る', (tester) async {
        await pumpView(
          tester,
          content: _content(),
          config: _cfg(ShareTarget.instagram, design: design),
          target: ShareTarget.instagram,
        );
        expect(_text('曲A'), findsWidgets);
        expect(_text('最高でした'), findsWidgets);
      });
    }
  });

  group('空の枠（hints と mini）', () {
    final empty = _content(setlist: const [], impression: null);

    testWidgets('チケット・hints: 「+ セトリを書く」「+ 感想を書く」が出る', (tester) async {
      await pumpView(
        tester,
        content: empty,
        config: _cfg(ShareTarget.instagram),
        target: ShareTarget.instagram,
        hints: true,
      );
      expect(_text('+ セトリを書く'), findsOneWidget);
      expect(_text('+ 感想を書く'), findsOneWidget);
    });

    testWidgets('チケット・hints なし（保存する画像）: 空の枠は出ない', (tester) async {
      await pumpView(
        tester,
        content: empty,
        config: _cfg(ShareTarget.instagram),
        target: ShareTarget.instagram,
      );
      expect(_text('+ セトリを書く'), findsNothing);
      expect(_text('+ 感想を書く'), findsNothing);
      expect(_text('写真を選ぶ'), findsNothing);
    });

    testWidgets('チケット・mini: hints を渡しても、空の枠は出ない', (tester) async {
      await pumpView(
        tester,
        content: empty,
        config: _cfg(ShareTarget.instagram),
        target: ShareTarget.instagram,
        hints: true,
        mini: true,
      );
      expect(_text('+ セトリを書く'), findsNothing);
      expect(_text('+ 感想を書く'), findsNothing);
      expect(_text('写真を選ぶ'), findsNothing);
    });

    testWidgets('写真0枚: hints では「写真を選ぶ」、保存する画像では「LIVE」', (tester) async {
      await pumpView(
        tester,
        content: empty,
        config: _cfg(ShareTarget.x),
        hints: true,
      );
      expect(_text('写真を選ぶ'), findsOneWidget);
      await pumpView(tester, content: empty, config: _cfg(ShareTarget.x));
      expect(_text('LIVE'), findsWidgets);
      expect(_text('写真を選ぶ'), findsNothing);
    });

    for (final design in [ShareDesign.photoMain]) {
      testWidgets('${design.name}: hints でも空の枠（+ セトリを書く）は出ない', (tester) async {
        await pumpView(
          tester,
          content: empty,
          config: _cfg(ShareTarget.instagram, design: design),
          target: ShareTarget.instagram,
          hints: true,
        );
        expect(_text('+ セトリを書く'), findsNothing);
        expect(_text('+ 感想を書く'), findsNothing);
      });
    }
  });

  group('セトリと感想の上限', () {
    // X の横長: セトリ 3 曲・感想 36 文字
    final long = _content(
      setlist: [for (var i = 0; i < 10; i++) '曲$i'],
      impression: 'あ' * 50,
    );

    for (final design in designs) {
      testWidgets('${design.name}: セトリの上限と感想は…で切る', (tester) async {
        await pumpView(
          tester,
          content: long,
          config: _cfg(ShareTarget.x, design: design),
        );
        if (design == ShareDesign.photoMain) {
          // photoMain は形ごとの上限（X 横長は3曲）
          expect(_text('ほか7曲'), findsWidgets);
          expect(_text('曲0'), findsWidgets);
          expect(_text('曲2'), findsWidgets);
          expect(_text('曲3'), findsNothing);
        } else {
          // ticket は 24 曲まで出し、入る分は自動で絞る（10曲なら形の上限では切らない）
          expect(_text('曲0'), findsWidgets);
        }
        expect(_text('${'あ' * 36}…'), findsWidgets);
        expect(_text('あ' * 37), findsNothing);
      });

      testWidgets('${design.name}: ちょうど上限なら「ほか」も…も出ない', (tester) async {
        await pumpView(
          tester,
          content: _content(
            setlist: const ['曲0', '曲1', '曲2'],
            impression: 'あ' * 36,
          ),
          config: _cfg(ShareTarget.x, design: design),
        );
        expect(_text('ほか'), findsNothing);
        expect(_text('…'), findsNothing);
      });
    }

    testWidgets('ストーリーは 10 曲まで出る', (tester) async {
      await pumpView(
        tester,
        content: long,
        config: _cfg(ShareTarget.instagram, format: 1),
        target: ShareTarget.instagram,
      );
      expect(_text('曲9'), findsWidgets);
      expect(_text('ほか'), findsNothing);
    });
  });

  group('タップできる部分', () {
    for (final design in designs) {
      testWidgets('${design.name}: hints のとき、写真・セトリ・感想をタップできる', (tester) async {
        final tapped = <SharePart>[];
        await pumpView(
          tester,
          content: _content(),
          config: _cfg(ShareTarget.instagram, design: design),
          target: ShareTarget.instagram,
          photos: 1,
          hints: true,
          onTapPart: tapped.add,
        );
        for (final k in [
          'share_part_photo',
          'share_part_setlist',
          'share_part_memo',
        ]) {
          expect(
            find.byKey(Key(k)),
            findsOneWidget,
            reason: '${design.name} $k',
          );
          await tester.tap(find.byKey(Key(k)));
        }
        expect(tapped, [SharePart.photo, SharePart.setlist, SharePart.memo]);
      });

      testWidgets('${design.name}: hints なし・mini ではタップの部品が無い', (tester) async {
        await pumpView(
          tester,
          content: _content(),
          config: _cfg(ShareTarget.instagram, design: design),
          target: ShareTarget.instagram,
          photos: 1,
          onTapPart: (_) {},
        );
        expect(find.byKey(const Key('share_part_photo')), findsNothing);
        await pumpView(
          tester,
          content: _content(),
          config: _cfg(ShareTarget.instagram, design: design),
          target: ShareTarget.instagram,
          photos: 1,
          hints: true,
          mini: true,
          onTapPart: (_) {},
        );
        expect(find.byKey(const Key('share_part_photo')), findsNothing);
      });
    }
  });

  group('座席が出ない', () {
    for (final design in designs) {
      testWidgets('${design.name}: 記録の座席に目印を入れても、画像のどこにも出ない', (tester) async {
        final memory = LiveMemory(
          performanceId: 'p',
          liveId: 'l',
          liveTitle: 'ツアー',
          startAt: DateTime.utc(2026, 12, 19, 9),
          venue: '会場',
          seat: _secretSeat,
          setlist: const ['曲A'],
          impression: '感想',
        );
        await pumpView(
          tester,
          content: ShareContent.fromMemory(memory, artist: 'ひかり'),
          config: _cfg(ShareTarget.instagram, design: design),
          target: ShareTarget.instagram,
          photos: 2,
          hints: true,
        );
        expect(_text('SEAT'), findsNothing);
        expect(_text('A12'), findsNothing);
        expect(_text('座席'), findsNothing);
      });
    }
  });

  group('背景色の切り替え', () {
    testWidgets('背景 0〜6 で、それぞれの色が使われる', (tester) async {
      for (var i = 0; i < shareBackgrounds.length; i++) {
        await pumpView(
          tester,
          content: _content(),
          config: _cfg(ShareTarget.x, bg: i),
          photos: 3,
        );
        final colors = <Color>{};
        for (final box in tester.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(ShareTicketView),
            matching: find.byType(DecoratedBox),
          ),
        )) {
          final d = box.decoration;
          if (d is BoxDecoration && d.color != null) colors.add(d.color!);
        }
        for (final c in tester.widgetList<ColoredBox>(
          find.descendant(
            of: find.byType(ShareTicketView),
            matching: find.byType(ColoredBox),
          ),
        )) {
          colors.add(c.color);
        }
        for (final c in tester.widgetList<Container>(
          find.descendant(
            of: find.byType(ShareTicketView),
            matching: find.byType(Container),
          ),
        )) {
          final d = c.decoration;
          if (d is BoxDecoration && d.color != null) colors.add(d.color!);
          if (c.color != null) colors.add(c.color!);
        }
        expect(colors, contains(shareBackgrounds[i]), reason: '背景 $i');
      }
    });

    testWidgets('背景の色は 7 色（きいろ・みどり・ピンク・赤・青・オレンジ・紫。黒は無い）', (tester) async {
      expect(shareBackgrounds, hasLength(7));
      expect(shareBackgrounds.toSet(), hasLength(7));
      expect(shareBackgroundNames, [
        'きいろ',
        'みどり',
        'ピンク',
        '赤',
        '青',
        'オレンジ',
        '紫',
      ]);
      expect(shareBackgrounds, isNot(contains(const Color(0xFF1A1A1A))));
    });

    for (final design in designs) {
      for (final target in ShareTarget.values) {
        testWidgets('${design.name}・${target.name}: 背景 7 色すべてで、例外なく描ける', (
          tester,
        ) async {
          for (var i = 0; i < shareBackgrounds.length; i++) {
            for (final photos in [0, 3]) {
              await pumpView(
                tester,
                content: _content(),
                config: _cfg(target, design: design, bg: i),
                target: target,
                photos: photos,
              );
              final e = tester.takeException();
              expect(e, isNull, reason: '背景 $i 写真 $photos: $e');
            }
          }
        });
      }
    }

    testWidgets('backgroundIndex が範囲外（-1・7・99）でも落ちない', (tester) async {
      for (final i in [-1, 7, 99]) {
        for (final design in designs) {
          await pumpView(
            tester,
            content: _content(),
            config: _cfg(ShareTarget.x, design: design, bg: i),
            photos: 2,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: 'bg $i ${design.name}',
          );
        }
      }
    });
  });

  group('はみ出し（文字 1.3 倍でも画像の中の文字は拡大されない）', () {
    for (final w in [160.0, 190.0, 320.0, 390.0, 720.0, 1000.0]) {
      for (final design in designs) {
        testWidgets('幅 $w・${design.name}・長い内容・全部の形', (tester) async {
          final content = _content(
            title: 'とても長いライブ名' * 8,
            setlist: List.generate(12, (i) => '長い曲名' * 4 + '$i'),
            impression: '長い感想' * 50,
          );
          for (final entry in shareFormats.entries) {
            for (var i = 0; i < entry.value.length; i++) {
              for (final photos in [0, 3, 4]) {
                await pumpView(
                  tester,
                  content: content,
                  config: _cfg(entry.key, design: design, format: i),
                  target: entry.key,
                  photos: photos,
                  hints: true,
                  width: w,
                  textScale: 1.3,
                );
                final e = tester.takeException();
                expect(
                  e,
                  isNull,
                  reason: '${entry.key.name}[$i] 写真 $photos: $e',
                );
              }
            }
          }
        });
      }
    }

    testWidgets('文字の拡大の有無で、画像の大きさは変わらない', (tester) async {
      await pumpView(
        tester,
        content: _content(),
        config: _cfg(ShareTarget.x),
        textScale: 1,
      );
      final a = tester.getSize(find.byType(ShareTicketView));
      await pumpView(
        tester,
        content: _content(),
        config: _cfg(ShareTarget.x),
        textScale: 1.3,
      );
      expect(tester.getSize(find.byType(ShareTicketView)), a);
    });
  });
}
