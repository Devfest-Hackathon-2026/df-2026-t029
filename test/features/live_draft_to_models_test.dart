import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/live_form/live_draft.dart';
import 'package:oshiashi/features/live_form/live_draft_to_models.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/models/reception.dart';

final start = DateTime(2026, 12, 1, 18);
final applyEnd = DateTime(2026, 11, 20, 23, 59);

OshiSummary performer(String id, OshiKind kind) => OshiSummary(
  id: id,
  kind: kind,
  name: id,
  genre: OshiGenre.idol,
  status: OshiStatus.approved,
);

PerformanceDraft perfDraft({String venue = '東京ドーム', String prefecture = ''}) =>
    PerformanceDraft(startAt: start, venue: venue, prefecture: prefecture);

ReceptionDraft recDraft({String name = 'FC先行', List<PriceDraft>? prices}) =>
    ReceptionDraft(
      type: ReceptionType.fc,
      name: name,
      applyEndAt: applyEnd,
      prices: prices,
    );

/// validate() と checkLimits() の両方が通る入力
LiveDraft validDraft({
  String title = 'ツアー2026',
  String officialUrl = '',
  List<PerformanceDraft>? performances,
  List<ReceptionDraft>? receptions,
}) => LiveDraft(
  title: title,
  officialUrl: officialUrl,
  selectedPerformers: [performer('g1', OshiKind.group)],
  performances: performances ?? [perfDraft()],
  receptions: receptions ?? [],
);

String chars(int n) => 'あ' * n;

void main() {
  group('LiveLimits（計画書 3.1 の値）', () {
    test('ルールと同じ上限', () {
      expect(LiveLimits.maxTitleLength, 100);
      expect(LiveLimits.maxVenueLength, 100);
      expect(LiveLimits.maxPrefectureLength, 10);
      expect(LiveLimits.maxReceptionNameLength, 50);
      expect(LiveLimits.maxSeatLength, 50);
      // ユーザーの判断で10個（ルールの式の上限のため）。test_rules/lives.test.js の MAX_PRICES と同じ
      expect(LiveLimits.maxPricesPerReception, 10);
      expect(LiveLimits.minAmount, 0);
      expect(LiveLimits.maxAmount, 1000000);
      expect(LiveLimits.minPerformances, 1);
      expect(LiveLimits.maxPerformances, 50);
      expect(LiveLimits.maxReceptions, 30);
      expect(LiveLimits.maxUrlLength, 200);
      expect(LiveLimits.maxPerformersPerKind, 20);
    });
  });

  group('checkLimits', () {
    test('正しい入力ならエラーなし', () {
      expect(validDraft().checkLimits(), isEmpty);
    });

    group('ライブ名', () {
      test('100文字は通り、101文字はエラー', () {
        expect(validDraft(title: chars(100)).checkLimits(), isEmpty);
        expect(validDraft(title: chars(101)).checkLimits(), [
          'ライブ名は100文字以内で入力してください',
        ]);
      });

      test('前後の空白は数えない（101文字でも trim して100文字なら通る）', () {
        expect(validDraft(title: ' ${chars(100)}').checkLimits(), isEmpty);
        expect(validDraft(title: '\n${chars(100)}　').checkLimits(), isEmpty);
      });

      test('文字数は UTF-16 単位（絵文字は2と数える。ルールの size() と同じ）', () {
        // 😀 は UTF-16 で2単位。50個で100、51個で102
        expect(validDraft(title: '😀' * 50).checkLimits(), isEmpty);
        expect(validDraft(title: '😀' * 51).checkLimits(), hasLength(1));
      });
    });

    group('公式 URL', () {
      test('空・空白だけなら検査しない', () {
        expect(validDraft(officialUrl: '').checkLimits(), isEmpty);
        expect(validDraft(officialUrl: '   ').checkLimits(), isEmpty);
      });

      test('https:// で始まる URL は通る（前後の空白は除く）', () {
        for (final url in [
          'https://example.com',
          'https://example.com/live?id=1#a',
          ' https://example.jp/パス ',
        ]) {
          expect(
            validDraft(officialUrl: url).checkLimits(),
            isEmpty,
            reason: url,
          );
        }
      });

      test('http://・https:// だけ・空白を含む・スキーム無しはエラー', () {
        for (final url in [
          'http://example.com',
          'https://',
          'https:// example.com',
          'https://exa mple.com',
          'https://example.com/a　b',
          'example.com',
          'HTTPS://example.com',
          'javascript:alert(1)',
        ]) {
          expect(validDraft(officialUrl: url).checkLimits(), [
            '公式 URL は https:// で始まる URL を入力してください',
          ], reason: url);
        }
      });

      test('200文字は通り、201文字はエラー', () {
        const prefix = 'https://example.com/';
        String url(int len) => prefix + 'a' * (len - prefix.length);
        expect(url(200), hasLength(200));
        expect(validDraft(officialUrl: url(200)).checkLimits(), isEmpty);
        expect(validDraft(officialUrl: url(201)).checkLimits(), [
          '公式 URL は200文字以内で入力してください',
        ]);
      });
    });

    group('公演', () {
      test('0件はエラー（validate() は通るので、ここで止める）', () {
        final d = validDraft(performances: []);
        expect(d.validate(), isEmpty);
        expect(d.checkLimits(), ['公演を1件以上入力してください']);
      });

      test('50件は通り、51件はエラー', () {
        expect(
          validDraft(performances: [for (var i = 0; i < 50; i++) perfDraft()])
              .checkLimits(),
          isEmpty,
        );
        expect(
          validDraft(performances: [for (var i = 0; i < 51; i++) perfDraft()])
              .checkLimits(),
          ['公演は50件までです'],
        );
      });

      test('会場名は100文字まで（trim 後）、何件目かを添える', () {
        expect(
          validDraft(performances: [perfDraft(venue: ' ${chars(100)} ')])
              .checkLimits(),
          isEmpty,
        );
        expect(
          validDraft(
            performances: [
              perfDraft(),
              perfDraft(venue: chars(101)),
            ],
          ).checkLimits(),
          ['公演2：会場名は100文字以内で入力してください'],
        );
      });

      test('都道府県は10文字まで、空は可', () {
        expect(
          validDraft(performances: [perfDraft(prefecture: '')]).checkLimits(),
          isEmpty,
        );
        expect(
          validDraft(performances: [perfDraft(prefecture: chars(10))])
              .checkLimits(),
          isEmpty,
        );
        expect(
          validDraft(performances: [perfDraft(prefecture: chars(11))])
              .checkLimits(),
          ['公演1：都道府県は10文字以内で入力してください'],
        );
      });
    });

    group('受付', () {
      test('0件は可、30件は通り、31件はエラー', () {
        expect(validDraft(receptions: []).checkLimits(), isEmpty);
        expect(
          validDraft(receptions: [for (var i = 0; i < 30; i++) recDraft()])
              .checkLimits(),
          isEmpty,
        );
        expect(
          validDraft(receptions: [for (var i = 0; i < 31; i++) recDraft()])
              .checkLimits(),
          ['受付は30件までです'],
        );
      });

      test('表示名は50文字まで（trim 後）', () {
        expect(
          validDraft(receptions: [recDraft(name: '　${chars(50)}')])
              .checkLimits(),
          isEmpty,
        );
        expect(
          validDraft(receptions: [recDraft(name: chars(51))]).checkLimits(),
          ['受付1：表示名は50文字以内で入力してください'],
        );
      });

      test('席種は maxPricesPerReception 個まで', () {
        const max = LiveLimits.maxPricesPerReception;
        List<PriceDraft> prices(int n) => [
          for (var i = 0; i < n; i++) PriceDraft(seat: 'S$i', amount: 1000),
        ];
        expect(
          validDraft(receptions: [recDraft(prices: prices(max))]).checkLimits(),
          isEmpty,
        );
        expect(
          validDraft(receptions: [recDraft(prices: prices(max + 1))])
              .checkLimits(),
          ['受付1：席種は$max個までです'],
        );
      });

      test('席種の名前は50文字まで（複数あってもエラーは1つ）', () {
        expect(
          validDraft(
            receptions: [
              recDraft(prices: [PriceDraft(seat: chars(50), amount: 1)]),
            ],
          ).checkLimits(),
          isEmpty,
        );
        expect(
          validDraft(
            receptions: [
              recDraft(
                prices: [
                  PriceDraft(seat: chars(51), amount: 1),
                  PriceDraft(seat: chars(60), amount: 1),
                ],
              ),
            ],
          ).checkLimits(),
          ['受付1：席種は50文字以内で入力してください'],
        );
      });

      test('料金は 0〜1,000,000 円', () {
        List<String> check(int amount) => validDraft(
          receptions: [
            recDraft(
              prices: [PriceDraft(seat: 'S席', amount: amount)],
            ),
          ],
        ).checkLimits();
        expect(check(0), isEmpty);
        expect(check(1000000), isEmpty);
        expect(check(-1), ['受付1：料金は0〜1,000,000円で入力してください']);
        expect(check(1000001), ['受付1：料金は0〜1,000,000円で入力してください']);
      });

      test('金額が null なら検査しない（validate() が見る）', () {
        final d = validDraft(
          receptions: [
            recDraft(prices: [PriceDraft(seat: 'S席')]),
          ],
        );
        expect(d.checkLimits(), isEmpty);
        expect(d.validate(), isNotEmpty);
      });
    });

    group('出演者の件数（種類ごとに20まで）', () {
      LiveDraft withPerformers(int groups, int persons) => LiveDraft(
        title: 'A',
        selectedPerformers: [
          for (var i = 0; i < groups; i++) performer('g$i', OshiKind.group),
          for (var i = 0; i < persons; i++) performer('p$i', OshiKind.person),
        ],
        performances: [perfDraft()],
      );

      test('グループ20・個人20（合計40）は通る', () {
        expect(withPerformers(20, 20).checkLimits(), isEmpty);
      });

      test('グループ21はエラー', () {
        expect(withPerformers(21, 0).checkLimits(), ['出演グループは20件まで選べます']);
      });

      test('個人21はエラー', () {
        expect(withPerformers(0, 21).checkLimits(), ['個人の出演者は20人まで選べます']);
      });

      test('両方21なら2つのエラー', () {
        expect(withPerformers(21, 21).checkLimits(), hasLength(2));
      });
    });

    test('複数のエラーはまとめて返す', () {
      final errors = validDraft(
        title: chars(101),
        officialUrl: 'http://x',
        performances: [],
        receptions: [recDraft(name: chars(51))],
      ).checkLimits();
      expect(errors, hasLength(4));
    });
  });

  group('toModels', () {
    test('文字列を trim し、groupIds・oshiIds は Live にだけ入れる', () {
      final d = LiveDraft(
        title: '  ツアー2026 ',
        officialUrl: ' https://example.com ',
        selectedPerformers: [
          performer('g1', OshiKind.group),
          performer('p1', OshiKind.person),
          performer('g2', OshiKind.group),
        ],
        performances: [
          PerformanceDraft(
            startAt: start,
            openAt: start.subtract(const Duration(hours: 1)),
            venue: ' 東京ドーム ',
            prefecture: ' 東京都 ',
          ),
        ],
        receptions: [
          ReceptionDraft(
            type: ReceptionType.upgrade,
            name: ' アプグレ ',
            applyStartAt: DateTime(2026, 11, 10),
            applyEndAt: applyEnd,
            resultAt: DateTime(2026, 11, 22),
            paymentDeadline: DateTime(2026, 11, 25),
            prices: [PriceDraft(seat: ' S席 ', amount: 9800)],
            winnersOnly: true,
          ),
        ],
      );
      final m = d.toModels();

      expect(m.live.id, isNull);
      expect(m.live.title, 'ツアー2026');
      expect(m.live.officialUrl, 'https://example.com');
      expect(m.live.groupIds, ['g1', 'g2']);
      expect(m.live.oshiIds, ['p1']);

      final p = m.performances.single;
      expect(p.id, isNull);
      expect(p.liveId, isNull);
      expect(p.groupIds, isEmpty);
      expect(p.oshiIds, isEmpty);
      expect(p.startAt, start);
      expect(p.openAt, start.subtract(const Duration(hours: 1)));
      expect(p.venue, '東京ドーム');
      expect(p.prefecture, '東京都');

      final r = m.receptions.single;
      expect(r.id, isNull);
      expect(r.liveId, isNull);
      expect(r.groupIds, isEmpty);
      expect(r.oshiIds, isEmpty);
      expect(r.type, ReceptionType.upgrade);
      expect(r.name, 'アプグレ');
      expect(r.applyStartAt, DateTime(2026, 11, 10));
      expect(r.applyEndAt, applyEnd);
      expect(r.resultAt, DateTime(2026, 11, 22));
      expect(r.paymentDeadline, DateTime(2026, 11, 25));
      expect(r.prices.single.seat, 'S席');
      expect(r.prices.single.amount, 9800);
      expect(r.winnersOnly, isTrue);
    });

    test('空・空白だけの officialUrl・prefecture は null で、toFirestore にキーが出ない', () {
      final m = validDraft(
        officialUrl: '  ',
        performances: [perfDraft(prefecture: '　')],
      ).toModels();
      expect(m.live.officialUrl, isNull);
      expect(m.live.toFirestore().containsKey('officialUrl'), isFalse);
      expect(m.performances.single.prefecture, isNull);
      expect(
        m.performances.single.toFirestore().containsKey('prefecture'),
        isFalse,
      );
      expect(
        m.performances.single.toFirestore().containsKey('openAt'),
        isFalse,
      );
    });

    test('件数と順番を保つ', () {
      final m = validDraft(
        performances: [
          perfDraft(venue: 'A'),
          perfDraft(venue: 'B'),
          perfDraft(venue: 'C'),
        ],
        receptions: [
          recDraft(name: 'X'),
          recDraft(name: 'Y'),
        ],
      ).toModels();
      expect([for (final p in m.performances) p.venue], ['A', 'B', 'C']);
      expect([for (final r in m.receptions) r.name], ['X', 'Y']);
    });

    test('Live の groupIds・oshiIds は後から変えられない', () {
      final m = validDraft().toModels();
      expect(() => m.live.groupIds.add('x'), throwsUnsupportedError);
      expect(() => m.live.oshiIds.add('x'), throwsUnsupportedError);
    });

    test('validate() でエラーになる入力では StateError', () {
      final d = validDraft(title: '  ');
      expect(d.validate(), isNotEmpty);
      expect(d.toModels, throwsStateError);
    });

    test('出演者が0件なら StateError', () {
      final d = LiveDraft(title: 'A', performances: [perfDraft()]);
      expect(d.toModels, throwsStateError);
    });

    test('checkLimits() でエラーになる入力では StateError', () {
      for (final d in [
        validDraft(performances: []),
        validDraft(title: chars(101)),
        validDraft(officialUrl: 'http://example.com'),
      ]) {
        expect(d.validate(), isEmpty);
        expect(d.toModels, throwsStateError);
      }
    });

    test('開演日時・申込期限が欠けていても、! で落ちる前に StateError', () {
      final noStart = validDraft(performances: [PerformanceDraft(venue: '会場')]);
      expect(noStart.toModels, throwsStateError);
      final noApplyEnd = validDraft(receptions: [ReceptionDraft(name: 'FC')]);
      expect(noApplyEnd.toModels, throwsStateError);
    });
  });

  group('formatYen', () {
    test('3桁ごとにカンマを入れる（「円」は付けない）', () {
      expect(formatYen(0), '0');
      expect(formatYen(999), '999');
      expect(formatYen(1000), '1,000');
      expect(formatYen(9800), '9,800');
      expect(formatYen(100000), '100,000');
      expect(formatYen(1000000), '1,000,000');
      expect(formatYen(-1000), '-1,000');
    });
  });
}
