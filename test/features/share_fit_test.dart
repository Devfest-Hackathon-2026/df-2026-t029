// computeShareFit（チケット画像の自動で絞る処理）のテスト（Q1）。
// フォントは取りに行かない設定なので、「ちょうど何曲」ではなく、単調さと順番を確かめる。
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/memory/share/share_fit.dart';
import 'package:oshiashi/utils/share_ticket.dart';

const _xWide = ShareFormat('横長 16:9', 16, 9, 1600, 900, 3, 36);
const _story = ShareFormat('ストーリー 9:16', 9, 16, 1080, 1920, 10, 150);

ShareContent _content({List<String> setlist = const [], String? impression}) =>
    ShareContent(
      title: 'ツアー2026',
      startAt: DateTime.utc(2026, 12, 19, 9),
      venue: '東京ドーム',
      setlist: setlist,
      impression: impression,
      performerNames: const [],
    );

ShareConfig _cfg({
  bool set = true,
  bool memo = true,
  ShareSizes sizes = ShareSizes.normal,
}) => ShareConfig(
  parts: {
    SharePart.setlist: {if (set) ShareLayer.image},
    SharePart.memo: {if (memo) ShareLayer.image},
  },
  sizes: sizes,
);

ShareFitResult _fit(
  ShareContent c, {
  required double height,
  ShareFormat f = _story,
  ShareConfig? cfg,
  double width = 300,
}) {
  final config = cfg ?? _cfg();
  return computeShareFit(
    width: width,
    height: height,
    u: 10,
    wide: f.aspectW > f.aspectH,
    content: c,
    config: config,
    text: layoutShareText(c, f),
  );
}

final _long = _content(
  setlist: List.generate(24, (i) => '曲名その$i'),
  impression: '感想はとても長い文章です。' * 30,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('computeShareFit', () {
    test('セトリが少なく高さが十分なら、全部入り、感想も落とさない', () {
      final r = _fit(
        _content(setlist: const ['A', 'B', 'C'], impression: 'よかった'),
        height: 2000,
      );
      expect(r.setCount, 3);
      expect(r.memoLines, 3);
      expect(r.fit.setShown, 3);
      expect(r.fit.setTotal, 3);
      expect(r.fit.memoDropped, isFalse);
    });

    test('セトリが多く高さが小さいと絞る。ただし最低1曲は残す', () {
      final r = _fit(_long, height: 40);
      expect(r.setCount, 1);
      expect(r.fit.setShown, 1);
      expect(r.fit.setTotal, 24);
    });

    test('高さが十分でも 24 曲まで（それ以上は text で切られる）', () {
      final c = _content(setlist: List.generate(30, (i) => '曲$i'));
      final r = _fit(c, height: 100000);
      expect(r.setCount, 24);
      expect(r.fit.setTotal, 30);
    });

    test('高さを大きくすると、入る曲数は減らない（単調）', () {
      var prev = 0;
      for (var h = 20.0; h <= 3000; h += 20) {
        final r = _fit(_long, height: h);
        expect(r.setCount, greaterThanOrEqualTo(prev), reason: 'h=$h');
        prev = r.setCount;
      }
    });

    test('セトリの文字を大きくすると、入る曲数は増えない', () {
      for (final h in [200.0, 400.0, 800.0]) {
        var prev = 1 << 30;
        for (final fs in [0.6, 0.8, 1.0, 1.2, 1.4]) {
          final cfg = _cfg(sizes: ShareSizes(setlist: fs));
          final r = _fit(_long, height: h, cfg: cfg);
          expect(r.setCount, lessThanOrEqualTo(prev), reason: 'h=$h fs=$fs');
          prev = r.setCount;
        }
      }
    });

    test('高さを小さくしていく順番: 感想の行数 → セトリ → 感想を消す', () {
      var prevLines = 3;
      var prevSet = layoutShareText(_long, _story).setShown.length;
      var sawLinesDrop = false;
      var sawSetDrop = false;
      var sawMemoDropped = false;
      for (var h = 3000.0; h >= 5; h -= 5) {
        final r = _fit(_long, height: h);
        final lines = r.memoLines;
        // 感想を消すのは、セトリが1曲まで絞られてから
        if (lines == 0) {
          expect(r.setCount, 1, reason: 'h=$h');
          expect(r.fit.memoDropped, isTrue);
          sawMemoDropped = true;
        }
        // セトリが減るのは、感想が1行になってから
        if (r.setCount < prevSet) {
          expect(prevLines <= 1 || lines <= 1, isTrue, reason: 'h=$h');
          expect(lines, lessThanOrEqualTo(1), reason: 'h=$h');
          sawSetDrop = true;
        }
        if (lines < prevLines && lines > 0) {
          expect(r.setCount, prevSet, reason: 'h=$h'); // 行数を減らす間は曲数が変わらない
          sawLinesDrop = true;
        }
        prevLines = lines;
        prevSet = r.setCount;
      }
      expect(sawLinesDrop || sawSetDrop, isTrue);
      expect(sawMemoDropped, isTrue);
    });

    test('セトリ0曲: 感想だけ。セトリの数は 0', () {
      final r = _fit(_content(impression: 'よかった'), height: 2000);
      expect(r.setCount, 0);
      expect(r.fit.setShown, 0);
      expect(r.fit.setTotal, 0);
      expect(r.memoLines, 3);
      expect(r.fit.memoDropped, isFalse);
    });

    test('感想なし: 感想の枠は出さない（memoDropped にもならない）', () {
      final r = _fit(_content(setlist: const ['A', 'B']), height: 10);
      expect(r.fit.memoDropped, isFalse);
      expect(r.memoLines, 0);
    });

    test('セトリを画像にのせていなければ、setShown は 0', () {
      final r = _fit(_long, height: 3000, cfg: _cfg(set: false));
      expect(r.fit.setShown, 0);
    });

    test('感想を画像にのせていなければ、感想を消した扱いにならない', () {
      final r = _fit(_long, height: 10, cfg: _cfg(memo: false));
      expect(r.fit.memoDropped, isFalse);
    });

    test('横長でも同じ順番・最低1曲', () {
      final r = _fit(_long, height: 30, f: _xWide, width: 400);
      expect(r.setCount, greaterThanOrEqualTo(1));
      expect(r.fit.setTotal, 24);
    });

    test('大きさを端（0.6・1.4）にしても、落ちない', () {
      for (final fs in [0.6, 1.4]) {
        for (final pm in [0.5, 1.5]) {
          final r = _fit(
            _long,
            height: 300,
            cfg: _cfg(
              sizes: ShareSizes(setlist: fs, photo: pm),
            ),
          );
          expect(r.setCount, inInclusiveRange(1, 24));
        }
      }
    });

    test('幅・高さが 0 以下でも落ちない', () {
      final r = _fit(_long, height: 0);
      expect(r.setCount, greaterThanOrEqualTo(0));
    });
  });
}
