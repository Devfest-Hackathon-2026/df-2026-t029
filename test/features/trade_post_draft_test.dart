// lib/features/trade/trade_post_draft.dart（G-2-4）のテスト
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/trade/trade_post_draft.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/models/performance.dart';
import 'package:oshiashi/models/trade_post.dart';

import 'oshi_test_helpers.dart';

final g1 = oshi('g1', 'グループ1');
const p1 = OshiSummary(
  id: 'p1',
  kind: OshiKind.person,
  name: '個人1',
  genre: OshiGenre.idol,
  status: OshiStatus.approved,
  groupIds: ['g2'],
);

/// 必須項目がそろった入力
TradePostDraft validDraft() => TradePostDraft(
  groupIds: ['g1'],
  tags: {TradeTag.trade},
  handover: {HandoverMethod.mail},
);

void main() {
  group('validate', () {
    test('必須項目がそろっていればエラーなし', () {
      expect(validDraft().validate(), isEmpty);
    });

    test('空のときは、推し・タグ・受け渡し方法のエラーを出す', () {
      expect(TradePostDraft().validate(), [
        '対象の推しを1つ以上選んでください',
        '取引のタグを1つ以上選んでください',
        '受け渡し方法を1つ以上選んでください',
      ]);
    });

    test('個人だけを選んでも推しのエラーは出ない', () {
      final d = validDraft()
        ..groupIds.clear()
        ..oshiIds.add('p1');
      expect(d.validate(), isEmpty);
    });

    test('譲渡・買取希望では価格の区分が必須', () {
      for (final t in [TradeTag.sell, TradeTag.buy]) {
        final d = validDraft()..tags.add(t);
        expect(d.validate(), ['譲渡・買取希望の価格（定価／定価以下）を選んでください']);
        d.priceType = PriceType.below;
        expect(d.validate(), isEmpty);
      }
    });

    test('X アカウントは先頭の @ と空白を除いて検査する', () {
      final d = validDraft()..xAccount = ' @oshi_fan1 ';
      expect(d.validate(), isEmpty);
      expect(d.cleanedXAccount, 'oshi_fan1');
      d.xAccount = '＠abc';
      expect(d.cleanedXAccount, 'abc');
    });

    test('X アカウントに使えない文字や16文字以上はエラー', () {
      for (final x in ['oshi-fan', 'あいう', 'a' * 16]) {
        final d = validDraft()..xAccount = x;
        expect(d.validate(), hasLength(1), reason: x);
      }
    });

    test('備考は1000文字まで（前後の空白は数えない）', () {
      final d = validDraft()..note = ' ${'あ' * 1000} ';
      expect(d.validate(), isEmpty);
      d.note = 'あ' * 1001;
      expect(d.validate(), ['備考は1000文字以内で入力してください']);
    });
  });

  group('toggleTarget / togglePerformance', () {
    test('グループは groupIds、個人は oshiIds に入れ、もう一度で外す', () {
      final d = TradePostDraft();
      d.toggleTarget(g1);
      d.toggleTarget(p1);
      expect(d.groupIds, ['g1']);
      expect(d.oshiIds, ['p1']);
      expect(d.isTarget(g1), isTrue);
      d.toggleTarget(g1);
      expect(d.groupIds, isEmpty);
    });

    test('上限（20個）を超えて選ぶと false で、追加しない', () {
      final d = TradePostDraft(groupIds: [for (var i = 0; i < 20; i++) 'x$i']);
      expect(d.toggleTarget(g1), isFalse);
      expect(d.groupIds, hasLength(20));
      // 個人は別に数える
      expect(d.toggleTarget(p1), isTrue);
    });

    test('公演も20個まで', () {
      final d = TradePostDraft(
        performanceIds: [for (var i = 0; i < 20; i++) 'f$i'],
      );
      expect(d.togglePerformance('new'), isFalse);
      expect(d.togglePerformance('f0'), isTrue);
      expect(d.performanceIds, hasLength(19));
    });
  });

  group('toPost', () {
    test('タグ・受け渡し方法は定義の順にそろえ、空の任意項目は null', () {
      final d = TradePostDraft(
        groupIds: ['g1'],
        tags: {TradeTag.buy, TradeTag.trade},
        priceType: PriceType.face,
        handover: {HandoverMethod.hand, HandoverMethod.mail},
        performanceIds: ['f1'],
        xAccount: '  ',
        note: '  ',
      );
      final p = d.toPost();
      expect(p.id, isNull);
      expect(p.tags, [TradeTag.trade, TradeTag.buy]);
      expect(p.handover, [HandoverMethod.mail, HandoverMethod.hand]);
      expect(p.priceType, PriceType.face);
      expect(p.performanceIds, ['f1']);
      expect(p.xAccount, isNull);
      expect(p.note, isNull);
      expect(p.gives, isEmpty);
      expect(p.images, isEmpty);
    });

    test('交換だけなら価格の区分を、手渡しでなければ公演を落とす', () {
      final d = validDraft()
        ..priceType = PriceType.face
        ..performanceIds.add('f1');
      final p = d.toPost();
      expect(p.priceType, isNull);
      expect(p.performanceIds, isEmpty);
    });

    test('編集では ID・写真を base から、譲・求を入力から作る', () {
      const give = GiveSet(
        items: [GiveItem(goodsId: 'a', variantId: 'v1', label: 'A')],
        pickCount: 1,
        images: ['img/set.jpg'],
        note: 'セット',
      );
      const want = WantSet(
        targets: [
          WantTarget(type: WantType.member, oshiId: 'p1', label: '個人1'),
        ],
      );
      const base = TradePost(
        id: 'post1',
        groupIds: ['g1'],
        tags: [TradeTag.trade],
        handover: [HandoverMethod.mail],
        gives: [give],
        wants: [want],
        images: ['img/1.jpg'],
        xAccount: 'old',
      );
      final d = TradePostDraft.fromPost(base)
        ..tags.add(TradeTag.sell)
        ..priceType = PriceType.below
        ..xAccount = '';
      final p = d.toPost(base: base);
      expect(p.id, 'post1');
      expect([for (final s in p.gives) s.toMap()], [give.toMap()]);
      expect([for (final s in p.wants) s.toMap()], [want.toMap()]);
      expect(p.images, ['img/1.jpg']);
      expect(p.tags, [TradeTag.trade, TradeTag.sell]);
      expect(p.xAccount, isNull);
    });

    test('fromPost は元の投稿の配列を変更しない', () {
      const base = TradePost(
        groupIds: ['g1'],
        tags: [TradeTag.trade],
        handover: [HandoverMethod.mail],
      );
      TradePostDraft.fromPost(base).toggleTarget(g1);
      expect(base.groupIds, ['g1']);
    });
  });

  group('handoverPerformanceCandidates', () {
    final now = DateTime(2026, 11, 5, 12);
    Performance perf(
      String id,
      DateTime startAt, {
      List<String> groupIds = const [],
      List<String> oshiIds = const [],
    }) => Performance(
      id: id,
      liveId: 'l1',
      groupIds: groupIds,
      oshiIds: oshiIds,
      startAt: startAt,
      venue: '会場$id',
    );

    final performances = [
      perf('late', DateTime(2026, 12, 1), groupIds: ['g1']),
      perf('soon', DateTime(2026, 11, 6), groupIds: ['g1']),
      perf('past', DateTime(2026, 11, 1), groupIds: ['g1']),
      perf('other', DateTime(2026, 11, 7), groupIds: ['g9']),
      perf('solo', DateTime(2026, 11, 8), oshiIds: ['p1']),
      perf('p1group', DateTime(2026, 11, 9), groupIds: ['g2']),
      perf('now', now, groupIds: ['g1']),
    ];

    List<String> ids(List<Performance> list) => [for (final p in list) p.id!];

    test('グループの、今以降の公演を開演の早い順に返す', () {
      final r = handoverPerformanceCandidates(
        performances: performances,
        groupIds: ['g1'],
        oshiIds: const [],
        all: [g1, p1],
        now: now,
      );
      expect(ids(r), ['now', 'soon', 'late']);
    });

    test('個人なら本人名義の公演と、所属グループの公演を含む', () {
      final r = handoverPerformanceCandidates(
        performances: performances,
        groupIds: const [],
        oshiIds: ['p1'],
        all: [g1, p1],
        now: now,
      );
      expect(ids(r), ['solo', 'p1group']);
    });

    test('選択済みの公演は、過去でも残す', () {
      final r = handoverPerformanceCandidates(
        performances: performances,
        groupIds: ['g1'],
        oshiIds: const [],
        all: [g1, p1],
        now: now,
        selectedIds: ['past'],
      );
      expect(ids(r), ['past', 'now', 'soon', 'late']);
    });
  });
}
