// ヘルプの話題（5つのトップの画面）の対応と、文言（計画書 4.10）のテスト。
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/help/help_topic.dart';
import 'package:oshiashi/theme/brand_colors.dart';

void main() {
  group('helpTopicForPath', () {
    const tops = <String, HelpTopic>{
      '/': HelpTopic.home,
      '/oshi': HelpTopic.oshi,
      '/lives': HelpTopic.live,
      '/trade': HelpTopic.trade,
      '/memories': HelpTopic.memory,
    };
    tops.forEach((path, topic) {
      test('$path は $topic', () => expect(helpTopicForPath(path), topic));
      if (path != '/') {
        test('$path/（末尾のスラッシュ）も $topic', () {
          expect(helpTopicForPath('$path/'), topic);
        });
      }
    });

    for (final path in [
      '/lives/abc',
      '/lives/add',
      '/oshi/search',
      '/oshi/request',
      '/memories/p1',
      '/trade/new',
      '/trade/post/new',
      '/profile',
      '/chats/c1',
      '/chats',
      '/lives/abc/edit',
      '',
    ]) {
      test('「$path」は出さない（null）', () {
        expect(helpTopicForPath(path), isNull);
      });
    }
  });

  group('HelpTopic', () {
    test('画面名', () {
      expect(HelpTopic.values.map((t) => t.label), [
        'ホーム',
        '推し',
        'ライブ一覧',
        'グッズ交換',
        'メモリー',
      ]);
    });

    test('画面の色は、5つのタブの色と同じ', () {
      expect(HelpTopic.home.hue, BrandColors.hall3);
      expect(HelpTopic.oshi.hue, BrandColors.hall1);
      expect(HelpTopic.live.hue, BrandColors.hall5);
      expect(HelpTopic.trade.hue, BrandColors.hall6);
      expect(HelpTopic.memory.hue, BrandColors.hall4);
    });

    test('凡例はホーム（締切）とグッズ交換（譲・求）だけ', () {
      expect(HelpTopic.home.legend, HelpLegend.deadlines);
      expect(HelpTopic.trade.legend, HelpLegend.giveWant);
      expect(HelpTopic.oshi.legend, HelpLegend.none);
      expect(HelpTopic.live.legend, HelpLegend.none);
      expect(HelpTopic.memory.legend, HelpLegend.none);
    });

    test('項目の数は 3 件（メモリーだけ「みんなのメモリー」を足して 4 件）', () {
      for (final t in HelpTopic.values) {
        expect(t.items, hasLength(t == HelpTopic.memory ? 4 : 3), reason: '$t');
      }
    });

    // 計画書 4.10 の表（題, 本文）。一字一句同じであること
    const expected = <HelpTopic, List<(String, String)>>{
      HelpTopic.home: [
        ('締切をチェックする', '申込・入金・当落発表の期限が近い順に並びます。タップすると詳細を開けます。'),
        ('ライブを追加する', '上の「行きたいライブを追加」ボタンから、行きたいライブを登録できます。'),
        ('推し活費を見る', '今月の支出が予算を超えていないか、いつでも確認できます。'),
      ],
      HelpTopic.oshi: [
        ('推しを探して追加', '「推しを探す」から、気になるアーティストやグループを探せます。'),
        ('最推しを決める', '星マークをつけた推しが「最推し」になります。'),
        ('メンバーを見る', 'グループの右の丸い矢印のボタンで、所属メンバーを開いたり閉じたりできます。'),
      ],
      HelpTopic.live: [
        ('ライブの予定を見る', '登録したライブが、開催日の近い順に並びます。'),
        ('詳細を開く', 'ライブ名をタップすると、公演ごとの日時などを確認できます。'),
        ('ライブを追加する', '「今後のライブ」の下の「ライブを追加」から、新しく登録できます。'),
      ],
      HelpTopic.trade: [
        ('掲示板で探す', 'フォロー中の推しの交換募集を見て、気になる投稿を探します。'),
        ('マッチを確認する', 'あなたの投稿と条件が合う相手が表示されます。「相互」はぴったり合っている状態です。'),
        ('自分の投稿を管理する', '投稿の編集や、交換が決まったあとの「募集終了」はここから。'),
      ],
      HelpTopic.memory: [
        ('参戦予定を確認', 'これから行くライブの日時や会場、座席を確認できます。'),
        ('思い出を見返す', '参戦済みのライブがカードで並びます。'),
        ('記録を残す', 'ライブの詳細の公演から「記録する」を押すと、座席やセトリ、感想、写真を残せます。'),
        ('みんなのメモリーを見る', '「みんなのメモリー」のタブで、フォロー中の推しの公開されたメモリーを見られます。'),
      ],
    };
    expected.forEach((topic, items) {
      test('${topic.label} の題と本文が計画書 4.10 と同じ', () {
        expect([for (final i in topic.items) (i.title, i.body)], items);
      });
    });
  });
}
