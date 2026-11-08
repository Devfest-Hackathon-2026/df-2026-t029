import 'package:flutter/painting.dart';

import '../../theme/brand_colors.dart';

/// シートの凡例の種類
enum HelpLegend { none, deadlines, giveWant }

/// 手順1つ分（題と本文）
class HelpItem {
  const HelpItem(this.title, this.body);
  final String title;
  final String body;
}

/// ヘルプを出す5つのトップの画面
enum HelpTopic {
  home('ホーム'),
  oshi('推し'),
  live('ライブ一覧'),
  trade('グッズ交換'),
  memory('メモリー');

  const HelpTopic(this.label);

  /// 画面名
  final String label;

  /// その画面の色
  Color get hue => switch (this) {
    HelpTopic.home => BrandColors.hall3,
    HelpTopic.oshi => BrandColors.hall1,
    HelpTopic.live => BrandColors.hall5,
    HelpTopic.trade => BrandColors.hall6,
    HelpTopic.memory => BrandColors.hall4,
  };

  HelpLegend get legend => switch (this) {
    HelpTopic.home => HelpLegend.deadlines,
    HelpTopic.trade => HelpLegend.giveWant,
    _ => HelpLegend.none,
  };

  List<HelpItem> get items => switch (this) {
    HelpTopic.home => const [
      HelpItem('締切をチェックする', '申込・入金・当落発表の期限が近い順に並びます。タップすると詳細を開けます。'),
      HelpItem('ライブを追加する', '上の「行きたいライブを追加」ボタンから、行きたいライブを登録できます。'),
      HelpItem('推し活費を見る', '今月の支出が予算を超えていないか、いつでも確認できます。'),
    ],
    HelpTopic.oshi => const [
      HelpItem('推しを探して追加', '「推しを探す」から、気になるアーティストやグループを探せます。'),
      HelpItem('最推しを決める', '星マークをつけた推しが「最推し」になります。'),
      HelpItem('メンバーを見る', 'グループの右の丸い矢印のボタンで、所属メンバーを開いたり閉じたりできます。'),
    ],
    HelpTopic.live => const [
      HelpItem('ライブの予定を見る', '登録したライブが、開催日の近い順に並びます。'),
      HelpItem('詳細を開く', 'ライブ名をタップすると、公演ごとの日時などを確認できます。'),
      HelpItem('ライブを追加する', '「今後のライブ」の下の「ライブを追加」から、新しく登録できます。'),
    ],
    HelpTopic.trade => const [
      HelpItem('掲示板で探す', 'フォロー中の推しの交換募集を見て、気になる投稿を探します。'),
      HelpItem('マッチを確認する', 'あなたの投稿と条件が合う相手が表示されます。「相互」はぴったり合っている状態です。'),
      HelpItem('自分の投稿を管理する', '投稿の編集や、交換が決まったあとの「募集終了」はここから。'),
    ],
    HelpTopic.memory => const [
      HelpItem('参戦予定を確認', 'これから行くライブの日時や会場、座席を確認できます。'),
      HelpItem('思い出を見返す', '参戦済みのライブがカードで並びます。'),
      HelpItem('記録を残す', 'ライブの詳細の公演から「記録する」を押すと、座席やセトリ、感想、写真を残せます。'),
      HelpItem('みんなのメモリーを見る', '「みんなのメモリー」のタブで、フォロー中の推しの公開されたメモリーを見られます。'),
    ],
  };
}

/// パスから話題を決める。5つのトップだけ。末尾の `/` は無視する。
HelpTopic? helpTopicForPath(String path) {
  var p = path;
  while (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return switch (p) {
    '/' => HelpTopic.home,
    '/oshi' => HelpTopic.oshi,
    '/lives' => HelpTopic.live,
    '/trade' => HelpTopic.trade,
    '/memories' => HelpTopic.memory,
    _ => null,
  };
}
