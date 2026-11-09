// share_ticket.dart（シェア画像・投稿の文章の純粋関数）のテスト（Q1）。
//
// 座席について: ShareContent は座席の項目を持たず、buildCaption・layoutShareText は
// 座席を受け取る手段が無い。座席が文章・画像の文字に入らないことは、型（コンパイル）で守られる。
// 加えて、記録（LiveMemory）の座席に目印の文字列を入れ、ShareContent.fromMemory →
// buildCaption の結果に出ないことを、回帰テストとして確かめる。
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/live_memory.dart';
import 'package:oshiashi/utils/share_ticket.dart';

const _secretSeat = 'SEAT-SECRET-A12ブロック';

// 2026/12/19(土) 18:00 JST
final _start = DateTime.utc(2026, 12, 19, 9);

ShareContent _content({
  String title = 'ツアー2026',
  DateTime? startAt,
  String venue = '東京ドーム',
  String? artist,
  List<String> setlist = const [],
  String? impression,
  List<String> performerNames = const [],
}) => ShareContent(
  title: title,
  startAt: startAt ?? _start,
  venue: venue,
  artist: artist,
  setlist: setlist,
  impression: impression,
  performerNames: performerNames,
);

ShareConfig _cfg({
  Set<ShareLayer> info = const {},
  Set<ShareLayer> setlist = const {},
  Set<ShareLayer> memo = const {},
  Set<ShareLayer> tags = const {},
}) => ShareConfig(
  parts: {
    SharePart.info: info,
    SharePart.setlist: setlist,
    SharePart.memo: memo,
    SharePart.tags: tags,
  },
);

void main() {
  group('parseSetItems', () {
    test('番号の飾り（1. 2) ３、 4: など）を除く', () {
      expect(parseSetItems('1. 曲A\n2) 曲B\n３、曲C\n4: 曲D\n５．曲E\n６）曲F\n7：曲G'), [
        '曲A',
        '曲B',
        '曲C',
        '曲D',
        '曲E',
        '曲F',
        '曲G',
      ]);
    });

    test('番号が無い行はそのまま', () {
      expect(parseSetItems('曲A\n曲B'), ['曲A', '曲B']);
    });

    test('空行と前後の空白を捨てる', () {
      expect(parseSetItems('\n  曲A  \n\n   \n曲B\n'), ['曲A', '曲B']);
    });

    test('番号だけの行を捨てる', () {
      expect(parseSetItems('1.\n２）\n3\n曲A'), ['曲A']);
    });

    test('CRLF・CR の改行も分ける', () {
      expect(parseSetItems('曲A\r\n曲B\r曲C'), ['曲A', '曲B', '曲C']);
    });

    test('空の入力は空の一覧', () {
      expect(parseSetItems(''), isEmpty);
      expect(parseSetItems('  \n  '), isEmpty);
    });

    test('番号のあとの空白が無くても除く', () {
      expect(parseSetItems('1.曲A'), ['曲A']);
    });

    test('番号で始まらない曲名の数字は残す（区切りが無い）', () {
      expect(parseSetItems('1999 Medley'), ['1999 Medley']);
    });
  });

  group('oneLine', () {
    test('改行・連続する空白を1つの空白にし、前後を除く', () {
      expect(oneLine('  よかった\n\nまた  行きたい\t！ \n'), 'よかった また 行きたい ！');
    });

    test('空・空白だけは空', () {
      expect(oneLine(''), '');
      expect(oneLine(' \n '), '');
    });
  });

  group('日付', () {
    test('formatShareDate: 日本時間の日付と英語の曜日', () {
      expect(formatShareDate(_start), '12.19 SAT');
    });

    test('formatShareDate: 日本時間の深夜0時の境目（UTC では前日）', () {
      expect(formatShareDate(DateTime.utc(2026, 12, 18, 15, 0)), '12.19 SAT');
      expect(formatShareDate(DateTime.utc(2026, 12, 18, 14, 59)), '12.18 FRI');
    });

    test('formatShareDate: 1桁の月日は0埋め、全曜日', () {
      expect(formatShareDate(DateTime.utc(2026, 1, 4, 3)), '01.04 SUN');
      expect(formatShareDate(DateTime.utc(2026, 1, 5, 3)), '01.05 MON');
      expect(formatShareDate(DateTime.utc(2026, 1, 6, 3)), '01.06 TUE');
      expect(formatShareDate(DateTime.utc(2026, 1, 7, 3)), '01.07 WED');
      expect(formatShareDate(DateTime.utc(2026, 1, 8, 3)), '01.08 THU');
      expect(formatShareDate(DateTime.utc(2026, 1, 9, 3)), '01.09 FRI');
    });

    test('formatShareDate: 年末の境目（UTC の大みそか 15:00 は日本の元日）', () {
      expect(formatShareDate(DateTime.utc(2026, 12, 31, 15)), '01.01 FRI');
    });

    test('formatCaptionDate: 日本時間・年つき・日本語の曜日', () {
      expect(formatCaptionDate(_start), '2026/12/19(土)');
      expect(
        formatCaptionDate(DateTime.utc(2026, 12, 18, 15)),
        '2026/12/19(土)',
      );
      expect(
        formatCaptionDate(DateTime.utc(2026, 12, 18, 14, 59)),
        '2026/12/18(金)',
      );
      expect(
        formatCaptionDate(DateTime.utc(2026, 12, 31, 15)),
        '2027/01/01(金)',
      );
      expect(formatCaptionDate(DateTime.utc(2026, 1, 4, 3)), '2026/01/04(日)');
    });
  });

  group('hashtagsOf', () {
    test('先頭2つまで。最後に #おしあし', () {
      expect(hashtagsOf(['A', 'B', 'C']), ['#A', '#B', '#おしあし']);
    });

    test('名前の中の空白（半角・全角）を除く', () {
      expect(hashtagsOf(['ひかり の 旋律', '山田　太郎']), ['#ひかりの旋律', '#山田太郎', '#おしあし']);
    });

    test('1つだけ', () {
      expect(hashtagsOf(['A']), ['#A', '#おしあし']);
    });

    test('空のとき #おしあし だけ', () {
      expect(hashtagsOf(const []), ['#おしあし']);
    });

    test('空白だけの名前は数えない', () {
      expect(hashtagsOf([' ', '　', 'A']), ['#A', '#おしあし']);
    });
  });

  group('ShareConfig', () {
    test('X の既定（4.6 の表）', () {
      final c = ShareConfig.defaults(ShareTarget.x);
      expect(c.isOn(SharePart.photo, ShareLayer.image), isTrue);
      expect(c.isOn(SharePart.photo, ShareLayer.caption), isFalse);
      expect(c.isOn(SharePart.info, ShareLayer.image), isTrue);
      expect(c.isOn(SharePart.info, ShareLayer.caption), isTrue);
      expect(c.isOn(SharePart.setlist, ShareLayer.image), isTrue);
      expect(c.isOn(SharePart.setlist, ShareLayer.caption), isFalse);
      expect(c.isOn(SharePart.memo, ShareLayer.image), isFalse);
      expect(c.isOn(SharePart.memo, ShareLayer.caption), isTrue);
      expect(c.isOn(SharePart.tags, ShareLayer.caption), isTrue);
      expect(c.isOn(SharePart.tags, ShareLayer.image), isFalse);
      expect(c.isOn(SharePart.mark, ShareLayer.image), isTrue);
      expect(c.formatIndex, 0);
      expect(c.design, ShareDesign.ticket);
      expect(c.backgroundIndex, 0);
    });

    test('Instagram の既定: 感想だけが X と違い、画像にのる', () {
      final c = ShareConfig.defaults(ShareTarget.instagram);
      expect(c.isOn(SharePart.memo, ShareLayer.image), isTrue);
      expect(c.isOn(SharePart.memo, ShareLayer.caption), isFalse);
      expect(c.isOn(SharePart.info, ShareLayer.caption), isTrue);
      expect(c.isOn(SharePart.setlist, ShareLayer.image), isTrue);
      expect(c.isOn(SharePart.tags, ShareLayer.caption), isTrue);
    });

    test('toggled: 押せる組み合わせは入れ替わる', () {
      final c = ShareConfig.defaults(ShareTarget.x);
      final on = c.toggled(SharePart.setlist, ShareLayer.caption);
      expect(on.isOn(SharePart.setlist, ShareLayer.caption), isTrue);
      expect(on.isOn(SharePart.setlist, ShareLayer.image), isTrue);
      final off = on.toggled(SharePart.setlist, ShareLayer.caption);
      expect(off.isOn(SharePart.setlist, ShareLayer.caption), isFalse);
      // もとは変わらない（不変）
      expect(c.isOn(SharePart.setlist, ShareLayer.caption), isFalse);
    });

    test('toggled: 押せない組み合わせは何も変えない', () {
      final c = ShareConfig.defaults(ShareTarget.x);
      for (final (p, l) in [
        (SharePart.photo, ShareLayer.caption),
        (SharePart.mark, ShareLayer.caption),
        (SharePart.tags, ShareLayer.image),
      ]) {
        final t = c.toggled(p, l);
        expect(identical(t, c), isTrue, reason: '許さない組み合わせは同じインスタンス');
        expect(t.isOn(p, l), isFalse, reason: '$p $l');
        for (final part in SharePart.values) {
          for (final layer in ShareLayer.values) {
            expect(t.isOn(part, layer), c.isOn(part, layer));
          }
        }
      }
    });

    test('ShareDesign は ticket・photoMain の2つだけ', () {
      expect(ShareDesign.values, [ShareDesign.ticket, ShareDesign.photoMain]);
    });

    test('backgroundIndex が範囲外でも、toggled・copyWith で落ちない', () {
      final c = ShareConfig.defaults(ShareTarget.x)
          .copyWith(backgroundIndex: 99);
      expect(c.toggled(SharePart.memo, ShareLayer.image).backgroundIndex, 99);
      expect(c.copyWith(formatIndex: 1).backgroundIndex, 99);
    });

    test('toggled は形・デザイン・背景を引き継ぐ', () {
      final c = ShareConfig.defaults(ShareTarget.x).copyWith(
        formatIndex: 1,
        design: ShareDesign.photoMain,
        backgroundIndex: 6,
      );
      final t = c.toggled(SharePart.memo, ShareLayer.image);
      expect(t.formatIndex, 1);
      expect(t.design, ShareDesign.photoMain);
      expect(t.backgroundIndex, 6);
      expect(t.isOn(SharePart.memo, ShareLayer.image), isTrue);
    });

    test('copyWith: 渡した項目だけ変わる', () {
      final c = ShareConfig.defaults(ShareTarget.instagram);
      final d = c.copyWith(formatIndex: 1);
      expect(d.formatIndex, 1);
      expect(d.design, ShareDesign.ticket);
      expect(d.backgroundIndex, 0);
      expect(d.isOn(SharePart.memo, ShareLayer.image), isTrue);
      final e = c.copyWith(backgroundIndex: 2, design: ShareDesign.photoMain);
      expect(e.formatIndex, 0);
      expect(e.backgroundIndex, 2);
      expect(e.design, ShareDesign.photoMain);
    });

    test('shareFormats: 形の数・大きさ・上限（4.7）', () {
      final x = shareFormats[ShareTarget.x]!;
      final ig = shareFormats[ShareTarget.instagram]!;
      expect([for (final f in x) f.label], ['横長 16:9', '正方形 1:1']);
      expect([for (final f in ig) f.label], ['フィード 4:5', 'ストーリー 9:16']);
      expect(x, hasLength(2));
      expect(ig, hasLength(2));
      expect(
        [x[0].outWidth, x[0].outHeight, x[0].maxSetlist, x[0].maxMemoChars],
        [1600, 900, 3, 36],
      );
      expect(
        [x[1].outWidth, x[1].outHeight, x[1].maxSetlist, x[1].maxMemoChars],
        [1080, 1080, 4, 44],
      );
      expect(
        [ig[0].outWidth, ig[0].outHeight, ig[0].maxSetlist, ig[0].maxMemoChars],
        [1080, 1350, 6, 72],
      );
      expect(
        [ig[1].outWidth, ig[1].outHeight, ig[1].maxSetlist, ig[1].maxMemoChars],
        [1080, 1920, 10, 150],
      );
    });
  });

  group('ShareContent.fromMemory', () {
    LiveMemory mem({String? impression, String? seat}) => LiveMemory(
      performanceId: 'p1',
      liveId: 'l1',
      liveTitle: 'ツアー',
      startAt: _start,
      venue: '会場',
      seat: seat,
      setlist: const ['曲1', '曲2'],
      impression: impression,
      images: const ['a.jpg', 'b.jpg'],
    );

    test('記録の内容を写す。写真は枚数だけ', () {
      final c = ShareContent.fromMemory(
        mem(impression: '良かった'),
        artist: 'アーティスト',
        performerNames: const ['A'],
      );
      expect(c.title, 'ツアー');
      expect(c.startAt, _start);
      expect(c.venue, '会場');
      expect(c.artist, 'アーティスト');
      expect(c.setlist, ['曲1', '曲2']);
      expect(c.impression, '良かった');
      expect(c.performerNames, ['A']);
      expect(c.photoCount, 2);
    });

    test('感想の前後の空白を除き、空なら null', () {
      expect(
        ShareContent.fromMemory(mem(impression: '  感想 \n')).impression,
        '感想',
      );
      expect(
        ShareContent.fromMemory(mem(impression: '  \n')).impression,
        isNull,
      );
      expect(ShareContent.fromMemory(mem()).impression, isNull);
    });
  });

  group('buildCaption', () {
    final full = _content(
      setlist: const ['曲A', '曲B', '曲C', '曲D'],
      impression: '最高でした\nまた行きたい',
      performerNames: const ['ひかり', 'ほし', 'そら'],
    );

    test('X の既定: タイトル・日付と会場・感想・タグ。セトリは画像だけ', () {
      expect(
        buildCaption(ShareTarget.x, ShareConfig.defaults(ShareTarget.x), full),
        '【参戦記録】ツアー2026\n'
        '2026/12/19(土) @ 東京ドーム\n'
        '\n'
        '最高でした また行きたい\n'
        '\n'
        '#ひかり #ほし #おしあし',
      );
    });

    test('Instagram の既定: 感想は画像なので文章に出ない', () {
      expect(
        buildCaption(
          ShareTarget.instagram,
          ShareConfig.defaults(ShareTarget.instagram),
          full,
        ),
        '【参戦記録】ツアー2026\n'
        '2026/12/19(土) @ 東京ドーム\n'
        '\n'
        '#ひかり #ほし #おしあし',
      );
    });

    test('すべてオフなら、ライブ名の行だけ', () {
      expect(buildCaption(ShareTarget.x, _cfg(), full), '【参戦記録】ツアー2026');
    });

    test('セトリを文章にのせると、全曲が " / " でつながる（画像の上限で切らない）', () {
      final s = buildCaption(
        ShareTarget.x,
        _cfg(setlist: {ShareLayer.caption}),
        full,
      );
      expect(s, '【参戦記録】ツアー2026\nセトリ：曲A / 曲B / 曲C / 曲D');
    });

    test('セトリが空なら、オンでもセトリの行は出ない', () {
      final s = buildCaption(
        ShareTarget.x,
        _cfg(setlist: {ShareLayer.caption}),
        _content(),
      );
      expect(s, '【参戦記録】ツアー2026');
    });

    test('感想の改行・連続する空白は1つの空白になる', () {
      final s = buildCaption(
        ShareTarget.x,
        _cfg(memo: {ShareLayer.caption}),
        _content(impression: '一行目\n\n二行目   三行目'),
      );
      expect(s, '【参戦記録】ツアー2026\n\n一行目 二行目 三行目');
    });

    test('感想が null・空白だけなら、感想の段は出ない', () {
      final cfg = _cfg(memo: {ShareLayer.caption});
      expect(buildCaption(ShareTarget.x, cfg, _content()), '【参戦記録】ツアー2026');
      expect(
        buildCaption(ShareTarget.x, cfg, _content(impression: ' \n ')),
        '【参戦記録】ツアー2026',
      );
    });

    test('タグだけオン: 出演者が無ければ #おしあし だけ', () {
      final s = buildCaption(
        ShareTarget.x,
        _cfg(tags: {ShareLayer.caption}),
        _content(),
      );
      expect(s, '【参戦記録】ツアー2026\n\n#おしあし');
    });

    test('画像だけにのせた部分は文章に出ない', () {
      final s = buildCaption(
        ShareTarget.x,
        _cfg(
          info: {ShareLayer.image},
          setlist: {ShareLayer.image},
          memo: {ShareLayer.image},
        ),
        full,
      );
      expect(s, '【参戦記録】ツアー2026');
    });

    test('全部オン: 見出し→日付と会場→セトリ→空行→感想→空行→タグの順', () {
      final s = buildCaption(
        ShareTarget.x,
        _cfg(
          info: {ShareLayer.caption},
          setlist: {ShareLayer.caption},
          memo: {ShareLayer.caption},
          tags: {ShareLayer.caption},
        ),
        full,
      );
      expect(
        s,
        '【参戦記録】ツアー2026\n'
        '2026/12/19(土) @ 東京ドーム\n'
        'セトリ：曲A / 曲B / 曲C / 曲D\n'
        '\n'
        '最高でした また行きたい\n'
        '\n'
        '#ひかり #ほし #おしあし',
      );
    });

    test('座席が文章に出ない: 記録の座席に目印を入れても、どの設定でも出ない', () {
      final memory = LiveMemory(
        performanceId: 'p1',
        liveId: 'l1',
        liveTitle: 'ツアー',
        startAt: _start,
        venue: '会場',
        seat: _secretSeat,
        setlist: const ['曲1'],
        impression: '感想',
        images: const ['a.jpg'],
      );
      final content = ShareContent.fromMemory(
        memory,
        artist: 'アーティスト',
        performerNames: const ['A'],
      );
      for (final target in ShareTarget.values) {
        final defaults = ShareConfig.defaults(target);
        // 押せる組み合わせをすべてオンにした設定
        var all = defaults;
        for (final p in SharePart.values) {
          for (final l in ShareLayer.values) {
            if (!all.isOn(p, l)) all = all.toggled(p, l);
          }
        }
        for (final cfg in [defaults, all]) {
          final s = buildCaption(target, cfg, content);
          expect(s, isNot(contains(_secretSeat)));
          expect(s, isNot(contains('SEAT')));
          expect(s, isNot(contains('座席')));
          expect(s, isNot(contains('A12')));
        }
      }
    });
  });

  group('xWeightedLength', () {
    test('英数字・半角記号は1', () {
      expect(xWeightedLength('abcXYZ123 !?'), 12);
    });

    test('日本語（ひらがな・カタカナ・漢字・全角記号）は2', () {
      expect(xWeightedLength('あいう'), 6);
      expect(xWeightedLength('アイウ'), 6);
      expect(xWeightedLength('漢字'), 4);
      expect(xWeightedLength('！？'), 4);
    });

    test('絵文字は1つ（サロゲートペア）で2', () {
      expect(xWeightedLength('😀'), 2);
      expect(xWeightedLength('a😀b'), 4);
    });

    test('改行は1', () {
      expect(xWeightedLength('a\nb'), 3);
    });

    test('境目のコードポイント', () {
      expect(xWeightedLength(String.fromCharCode(4351)), 1);
      expect(xWeightedLength(String.fromCharCode(4352)), 2);
      expect(xWeightedLength(String.fromCharCode(8191)), 2);
      expect(xWeightedLength(String.fromCharCode(8192)), 1);
      expect(xWeightedLength(String.fromCharCode(8205)), 1);
      expect(xWeightedLength(String.fromCharCode(8206)), 2);
      expect(xWeightedLength(String.fromCharCode(8207)), 2);
      expect(xWeightedLength(String.fromCharCode(8208)), 1);
      expect(xWeightedLength(String.fromCharCode(8223)), 1);
      expect(xWeightedLength(String.fromCharCode(8224)), 2);
      expect(xWeightedLength(String.fromCharCode(8241)), 2);
      expect(xWeightedLength(String.fromCharCode(8242)), 1);
      expect(xWeightedLength(String.fromCharCode(8247)), 1);
      expect(xWeightedLength(String.fromCharCode(8248)), 2);
      expect(xWeightedLength(String.fromCharCode(0)), 1);
    });

    test('空は 0', () {
      expect(xWeightedLength(''), 0);
    });
  });

  group('captionLimit・isCaptionTooLong', () {
    test('上限: X は 280、Instagram は 2200', () {
      expect(captionLimit(ShareTarget.x), 280);
      expect(captionLimit(ShareTarget.instagram), 2200);
    });

    test('X: 日本語140字ちょうどは通り、141字で超える', () {
      expect(isCaptionTooLong(ShareTarget.x, 'あ' * 140), isFalse);
      expect(isCaptionTooLong(ShareTarget.x, 'あ' * 141), isTrue);
    });

    test('X: 英数字は280字ちょうどが通り、281字で超える', () {
      expect(isCaptionTooLong(ShareTarget.x, 'a' * 280), isFalse);
      expect(isCaptionTooLong(ShareTarget.x, 'a' * 281), isTrue);
    });

    test('X: 日本語139字＋英数字2字（278）は通り、日本語140字＋1字（281）は超える', () {
      expect(isCaptionTooLong(ShareTarget.x, '${'あ' * 139}ab'), isFalse);
      expect(isCaptionTooLong(ShareTarget.x, '${'あ' * 140}a'), isTrue);
    });

    test('Instagram: 素の文字数で 2200 ちょうどが通り、2201 で超える', () {
      expect(isCaptionTooLong(ShareTarget.instagram, 'あ' * 2200), isFalse);
      expect(isCaptionTooLong(ShareTarget.instagram, 'あ' * 2201), isTrue);
    });

    test('Instagram: 絵文字は1文字として数える', () {
      expect(isCaptionTooLong(ShareTarget.instagram, '😀' * 2200), isFalse);
      expect(isCaptionTooLong(ShareTarget.instagram, '😀' * 2201), isTrue);
    });

    test('空の文章は超えない', () {
      expect(isCaptionTooLong(ShareTarget.x, ''), isFalse);
      expect(isCaptionTooLong(ShareTarget.instagram, ''), isFalse);
    });
  });

  group('layoutShareText', () {
    const xWide = ShareFormat('横長 16:9', 16, 9, 1600, 900, 3, 36);
    const story = ShareFormat('ストーリー 9:16', 9, 16, 1080, 1920, 10, 150);

    test('上限以下ならそのまま。ほか○曲は 0・感想は切らない', () {
      final r = layoutShareText(
        _content(setlist: const ['A', 'B', 'C'], impression: 'あ' * 36),
        xWide,
      );
      expect(r.setShown, ['A', 'B', 'C']);
      expect(r.setMore, 0);
      expect(r.memoShown, 'あ' * 36);
      expect(r.memoCut, isFalse);
    });

    test('セトリが上限を超えると、先頭だけ残り、切った曲数が出る', () {
      final r = layoutShareText(
        _content(setlist: const ['A', 'B', 'C', 'D', 'E']),
        xWide,
        design: ShareDesign.photoMain,
      );
      expect(r.setShown, ['A', 'B', 'C']);
      expect(r.setMore, 2);
    });

    test('セトリが上限+1曲なら、ほか1曲', () {
      final r = layoutShareText(
        _content(setlist: const ['A', 'B', 'C', 'D']),
        xWide,
        design: ShareDesign.photoMain,
      );
      expect(r.setMore, 1);
    });

    test('感想が上限を1字超えると、上限の字数＋…', () {
      final r = layoutShareText(_content(impression: 'あ' * 37), xWide);
      expect(r.memoCut, isTrue);
      expect(r.memoShown, '${'あ' * 36}…');
    });

    test('感想の改行は空白にまとめてから数える', () {
      final r = layoutShareText(_content(impression: 'あ\n\n\nい'), xWide);
      expect(r.memoShown, 'あ い');
      expect(r.memoCut, isFalse);
    });

    test('感想の絵文字は1文字として数え、サロゲートペアの途中で切らない', () {
      final r = layoutShareText(_content(impression: '😀' * 40), xWide);
      expect(r.memoCut, isTrue);
      expect(r.memoShown, '${'😀' * 36}…');
    });

    test('空のセトリ・null の感想は空', () {
      final r = layoutShareText(_content(), story);
      expect(r.setShown, isEmpty);
      expect(r.setMore, 0);
      expect(r.memoShown, '');
      expect(r.memoCut, isFalse);
    });

    test('形ごとの上限: ストーリーは 10 曲・150 字', () {
      final r = layoutShareText(
        _content(
          setlist: List.generate(12, (i) => '曲$i'),
          impression: 'い' * 151,
        ),
        story,
        design: ShareDesign.photoMain,
      );
      expect(r.setShown, hasLength(10));
      expect(r.setMore, 2);
      expect(r.memoShown, '${'い' * 150}…');
    });

    test('ticket（既定）: セトリは kTicketSetlistCeiling(24) 曲まで、形によらない', () {
      for (final f in [xWide, story]) {
        final exact = layoutShareText(
          _content(setlist: List.generate(24, (i) => '曲$i')),
          f,
        );
        expect(exact.setShown, hasLength(24), reason: f.label);
        expect(exact.setMore, 0, reason: f.label);
        final over = layoutShareText(
          _content(setlist: List.generate(25, (i) => '曲$i')),
          f,
          design: ShareDesign.ticket,
        );
        expect(over.setShown, hasLength(24), reason: f.label);
        expect(over.setMore, 1, reason: f.label);
      }
    });

    test('ticket でも感想は maxMemoChars で切る（今のまま）', () {
      final r = layoutShareText(_content(impression: 'あ' * 37), xWide);
      expect(r.memoShown, '${'あ' * 36}…');
      expect(r.memoCut, isTrue);
    });

    test('実際の shareFormats の全形で、ちょうど上限は切れず、+1 で切れる', () {
      for (final formats in shareFormats.values) {
        for (final f in formats) {
          final exact = layoutShareText(
            _content(
              setlist: List.generate(f.maxSetlist, (i) => '曲$i'),
              impression: 'あ' * f.maxMemoChars,
            ),
            f,
            design: ShareDesign.photoMain,
          );
          expect(exact.setMore, 0, reason: f.label);
          expect(exact.memoCut, isFalse, reason: f.label);
          final over = layoutShareText(
            _content(
              setlist: List.generate(f.maxSetlist + 1, (i) => '曲$i'),
              impression: 'あ' * (f.maxMemoChars + 1),
            ),
            f,
            design: ShareDesign.photoMain,
          );
          expect(over.setMore, 1, reason: f.label);
          expect(over.memoCut, isTrue, reason: f.label);
          expect(over.memoShown.endsWith('…'), isTrue, reason: f.label);
        }
      }
    });
  });

  group('ShareSizes', () {
    test('既定は 1.0 で isNormal', () {
      expect(ShareSizes.normal.isNormal, isTrue);
      expect(const ShareSizes(info: 1.05).isNormal, isFalse);
    });

    test('範囲に収める（写真 0.5〜1.5・文字 0.6〜1.4）', () {
      final lo = ShareSizes.normal.copyWith(
        photo: 0.1,
        info: 0.1,
        setlist: 0.1,
      );
      expect([lo.photo, lo.info, lo.setlist], [0.5, 0.6, 0.6]);
      final hi = ShareSizes.normal.copyWith(photo: 9, info: 9, setlist: 9);
      expect([hi.photo, hi.info, hi.setlist], [1.5, 1.4, 1.4]);
    });

    test('0.05 の刻みに丸める', () {
      expect(ShareSizes.normal.copyWith(photo: 1.12).photo, 1.1);
      expect(ShareSizes.normal.copyWith(photo: 1.13).photo, 1.15);
    });

    test('渡さない項目は今のまま残る', () {
      final a = ShareSizes.normal.copyWith(photo: 1.3);
      final b = a.copyWith(info: 0.8);
      expect([b.photo, b.info, b.setlist], [1.3, 0.8, 1.0]);
    });

    test('== は値で比べる', () {
      expect(const ShareSizes(photo: 1.2), const ShareSizes(photo: 1.2));
      expect(const ShareSizes(photo: 1.2) == const ShareSizes(), isFalse);
    });
  });

  group('ShareConfig.sizes', () {
    test('既定は normal。toggled・copyWith で引き継ぐ', () {
      expect(ShareConfig.defaults(ShareTarget.x).sizes, ShareSizes.normal);
      final c = ShareConfig.defaults(ShareTarget.x)
          .copyWith(sizes: const ShareSizes(photo: 1.3, setlist: 0.7));
      final t = c.toggled(SharePart.memo, ShareLayer.image);
      expect(t.sizes, const ShareSizes(photo: 1.3, setlist: 0.7));
      final d = c.copyWith(design: ShareDesign.photoMain, formatIndex: 1);
      expect(d.sizes, const ShareSizes(photo: 1.3, setlist: 0.7));
      expect(d.design, ShareDesign.photoMain);
    });

    test('toggled・copyWith は他の項目（形・デザイン・背景）も引き継ぐ', () {
      final c = ShareConfig.defaults(ShareTarget.x).copyWith(
        formatIndex: 1,
        design: ShareDesign.photoMain,
        backgroundIndex: 3,
      );
      final t = c.toggled(SharePart.setlist, ShareLayer.caption);
      expect(
        [t.formatIndex, t.design, t.backgroundIndex],
        [1, ShareDesign.photoMain, 3],
      );
    });
  });

  group('shareImageNotes', () {
    const xWide = ShareFormat('横長 16:9', 16, 9, 1600, 900, 3, 36);
    ShareConfig cfg({
      ShareDesign design = ShareDesign.ticket,
      bool setImage = true,
      bool memoImage = true,
    }) => ShareConfig(
      parts: {
        SharePart.setlist: {if (setImage) ShareLayer.image},
        SharePart.memo: {if (memoImage) ShareLayer.image},
      },
      design: design,
    );
    final set10 = List.generate(10, (i) => '曲$i');

    test('何も切れていなければ空', () {
      expect(
        shareImageNotes(
          _content(setlist: const ['A'], impression: 'あ'),
          cfg(),
          xWide,
          null,
        ),
        isEmpty,
      );
    });

    test('ticket: fit で絞られていればセトリの注意（先頭○曲）', () {
      final n = shareImageNotes(
        _content(setlist: set10),
        cfg(),
        xWide,
        const ShareFit(setShown: 6, setTotal: 10, memoDropped: false),
      );
      expect(n, hasLength(1));
      expect(n.single, contains('先頭6曲'));
    });

    test('ticket: fit で全曲入っていれば出ない', () {
      expect(
        shareImageNotes(
          _content(setlist: set10),
          cfg(),
          xWide,
          const ShareFit(setShown: 10, setTotal: 10, memoDropped: false),
        ),
        isEmpty,
      );
    });

    test('photoMain: 形の上限を超えるとセトリの注意', () {
      final n = shareImageNotes(
        _content(setlist: set10),
        cfg(design: ShareDesign.photoMain),
        xWide,
        null,
      );
      expect(n.single, contains('先頭3曲'));
    });

    test('セトリを画像にのせていなければ出ない', () {
      expect(
        shareImageNotes(
          _content(setlist: set10),
          cfg(setImage: false),
          xWide,
          const ShareFit(setShown: 2, setTotal: 10, memoDropped: false),
        ),
        isEmpty,
      );
    });

    test('感想が入りきらず落とされたときの注意（ticket）', () {
      final n = shareImageNotes(
        _content(impression: 'あいう'),
        cfg(),
        xWide,
        const ShareFit(setShown: 0, setTotal: 0, memoDropped: true),
      );
      expect(n.single, contains('感想は'));
      expect(n.single, contains('入りきらない'));
    });

    test('感想が文字数で切れるときの注意', () {
      final n = shareImageNotes(
        _content(impression: 'あ' * 37),
        cfg(),
        xWide,
        null,
      );
      expect(n.single, contains('36文字まで'));
    });

    test('感想を画像にのせていない・空なら文字数の注意は出ない', () {
      expect(
        shareImageNotes(
          _content(impression: 'あ' * 37),
          cfg(memoImage: false),
          xWide,
          null,
        ),
        isEmpty,
      );
      expect(
        shareImageNotes(_content(impression: ''), cfg(), xWide, null),
        isEmpty,
      );
    });

    test('感想を消したとき、fit.memoDropped でも注意は出ない', () {
      expect(
        shareImageNotes(
          _content(impression: 'あ'),
          cfg(memoImage: false),
          xWide,
          const ShareFit(setShown: 0, setTotal: 0, memoDropped: true),
        ),
        isEmpty,
      );
    });

    test('座席の目印は注意文に出ない', () {
      final c = ShareContent.fromMemory(
        LiveMemory(
          performanceId: 'p1',
          liveId: 'l1',
          liveTitle: 'T',
          startAt: _start,
          venue: 'V',
          seat: _secretSeat,
          setlist: set10,
          images: const [],
        ),
        performerNames: const [],
      );
      final n = shareImageNotes(
        c,
        cfg(),
        xWide,
        const ShareFit(setShown: 3, setTotal: 10, memoDropped: false),
      );
      expect(n.join(), isNot(contains('SEAT')));
    });
  });
}
