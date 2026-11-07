import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/utils/text_normalizer.dart';

void main() {
  group('normalizeName: 空・空白', () {
    test('空文字は空文字', () {
      expect(normalizeName(''), '');
    });

    test('半角・全角スペース、タブ、改行だけなら空文字', () {
      expect(normalizeName(' 　\t\n '), '');
    });

    test('前後と途中の空白（全角を含む）をすべて取り除く', () {
      expect(normalizeName('  さくら　みこ '), 'サクラミコ');
      expect(normalizeName('a b\tc'), 'abc');
    });
  });

  group('normalizeName: 全角英数字・記号', () {
    test('全角英数字を半角・小文字にする', () {
      expect(normalizeName('ＡＢＣ１２３ｘｙｚ'), 'abc123xyz');
    });

    test('範囲の端 U+FF01（！）と U+FF5E（～）も半角になる', () {
      expect(normalizeName('！'), '!');
      expect(normalizeName('～'), '~');
    });

    test('範囲の外側 U+FF00 と U+FF5F は変えない', () {
      expect(normalizeName('＀'), '＀');
      expect(normalizeName('｟'), '｟');
    });

    test('取り除く対象でない記号は残す', () {
      expect(normalizeName('A!B'), 'a!b');
      expect(normalizeName('μ\'s'), 'μ\'s');
    });
  });

  group('normalizeName: 大文字・小文字', () {
    test('英字を小文字にする', () {
      expect(normalizeName('SnowMan'), 'snowman');
      expect(normalizeName('snowman'), normalizeName('SNOWMAN'));
    });
  });

  group('normalizeName: ひらがな → カタカナ', () {
    test('ひらがなをカタカナにする', () {
      expect(normalizeName('さくら'), 'サクラ');
      expect(normalizeName('さくら'), normalizeName('サクラ'));
    });

    test('範囲の端 U+3041（ぁ）と U+3096（ゖ）も変換する', () {
      expect(normalizeName('ぁ'), 'ァ');
      expect(normalizeName('ゖ'), 'ヶ');
      expect(normalizeName('ゔ'), 'ヴ');
    });

    test('範囲の外側（ゝ U+309D）は変えない', () {
      expect(normalizeName('ゝ'), 'ゝ');
    });

    test('漢字はそのまま', () {
      expect(normalizeName('嵐'), '嵐');
    });
  });

  group('normalizeName: 半角カタカナ', () {
    test('半角カタカナを全角にする', () {
      expect(normalizeName('ｻｸﾗ'), 'サクラ');
      expect(normalizeName('ｦﾝ'), 'ヲン');
    });

    test('濁点・半濁点を直前の文字と結合する', () {
      expect(normalizeName('ｶﾞｷﾞﾊﾟﾋﾟ'), 'ガギパピ');
      expect(normalizeName('ｳﾞｨ'), 'ヴィ');
    });

    test('半角の長音は全角の長音になり、取り除かない', () {
      expect(normalizeName('ｾｰﾗｰ'), 'セーラー');
      expect(normalizeName('セーラー'), 'セーラー');
    });

    test('結合用の濁点（U+3099）・単独の濁点（゛）でも結合する', () {
      expect(normalizeName('ガ'), 'ガ');
      expect(normalizeName('が'), 'ガ');
      expect(normalizeName('カ゛'), 'ガ');
      expect(normalizeName('ハ゜'), 'パ');
      expect(normalizeName('パ'), 'パ');
    });

    test('半角・全角・ひらがなの表記ゆれが同じ値になる', () {
      final expected = normalizeName('ガールズ');
      expect(normalizeName('ｶﾞｰﾙｽﾞ'), expected);
      expect(normalizeName('がーるず'), expected);
    });

    test('結合できない半角濁点は単独の濁点（゛）になる', () {
      expect(normalizeName('ｱﾞ'), 'ア゛');
      expect(normalizeName('ﾞ'), '゛');
      expect(normalizeName('ﾟ'), '゜');
    });

    test('結合できない結合用の濁点・半濁点も単独の ゛ ゜ にそろえる（回帰テスト）', () {
      final dakuten = normalizeName('ア\u3099');
      expect(dakuten, 'ア゛');
      expect(dakuten, normalizeName('アﾞ'));
      expect(dakuten, normalizeName('ア゛'));
      final handakuten = normalizeName('ア\u309A');
      expect(handakuten, 'ア゜');
      expect(handakuten, normalizeName('アﾟ'));
      expect(handakuten, normalizeName('ア゜'));
      expect(normalizeName('\u3099'), '゛');
      // 結合できる場合はこれまでどおり
      expect(normalizeName('カ\u3099'), 'ガ');
    });

    test('既に濁音の文字に濁点を付けても結合しない', () {
      expect(normalizeName('ガﾞ'), 'ガ゛');
    });
  });

  group('normalizeName: 取り除く記号', () {
    test('中黒（全角・半角）を取り除く', () {
      expect(normalizeName('ア・イ･ウ'), 'アイウ');
    });

    test('ピリオド（全角・半角）とアンダースコア（全角・半角）を取り除く', () {
      expect(normalizeName('A.B．C_D＿E'), 'abcde');
    });

    test('ハイフン類を取り除く', () {
      for (final h in ['-', '－', '−', '‐', '‑', '‒', '–', '—', '―', '⁃', '﹣']) {
        expect(
          normalizeName('A${h}B'),
          'ab',
          reason: 'U+${h.runes.first.toRadixString(16)}',
        );
      }
    });

    test('記号だけなら空文字', () {
      expect(normalizeName('・-_.'), '');
      expect(normalizeName('　・　'), '');
    });
  });

  group('normalizeName: そのほか', () {
    test('絵文字は残す（サロゲートペアを壊さない）', () {
      expect(normalizeName('🍓 ぷりん'), '🍓プリン');
      expect(normalizeName('👨‍👩‍👧'), '👨‍👩‍👧');
    });

    test('2回かけても結果が変わらない', () {
      for (final s in ['ｶﾞｰﾙｽﾞ・ﾊﾟｰﾃｨ', 'ＳＮＯＷ　Ｍａｎ', 'さくら-みこ', 'ｱﾞ']) {
        expect(normalizeName(normalizeName(s)), normalizeName(s), reason: s);
      }
    });
  });
}
