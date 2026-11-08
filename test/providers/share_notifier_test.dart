// ShareNotifier（投稿の画面の状態）・currentCaption・shareContentProvider のテスト。
// 座席が文章・画像の内容に出ないことの確認を含む。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/live_memory.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/memory_providers.dart';
import 'package:oshiashi/providers/memory_ticket_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/providers/share_providers.dart';
import 'package:oshiashi/utils/share_ticket.dart';

import '../features/live_test_helpers.dart';
import '../features/memory_form_page_test.dart' show FakeMemoryRepository;
import '../features/oshi_test_helpers.dart';

const _secretSeat = 'SEAT-SECRET-A12ブロック';

final _content = ShareContent(
  title: 'ツアー',
  startAt: DateTime.utc(2026, 12, 19, 9),
  venue: '会場',
  setlist: const ['曲A'],
  impression: '感想',
  performerNames: const ['ひかり'],
);

void main() {
  late ProviderContainer container;

  ShareNotifier notifier() => container.read(shareProvider('p1').notifier);
  ShareState state() => container.read(shareProvider('p1'));

  setUp(() {
    container = ProviderContainer();
    container.listen(shareProvider('p1'), (_, _) {});
    addTearDown(container.dispose);
  });

  group('初期状態', () {
    test('投稿先は X。設定は 4.6 の既定。手直しなし・保存の印なし', () {
      final s = state();
      expect(s.target, ShareTarget.x);
      expect(s.config.isOn(SharePart.memo, ShareLayer.caption), isTrue);
      expect(
        s.configs[ShareTarget.instagram]!.isOn(
          SharePart.memo,
          ShareLayer.image,
        ),
        isTrue,
      );
      expect(s.captionOverride[ShareTarget.x], isNull);
      expect(s.imageSaved, isFalse);
      expect(s.captionCopied, isFalse);
    });

    test('performanceId ごとに別の状態', () {
      container.listen(shareProvider('p2'), (_, _) {});
      notifier().setCaption('手直し');
      expect(container.read(shareProvider('p2')).captionOverride, isEmpty);
    });
  });

  group('selectTarget', () {
    test('投稿先が切り替わり、画像の形は 1 つめに戻る', () {
      notifier().setFormat(1);
      expect(state().config.formatIndex, 1);
      notifier().selectTarget(ShareTarget.instagram);
      notifier().setFormat(1);
      notifier().selectTarget(ShareTarget.x);
      expect(state().target, ShareTarget.x);
      expect(state().config.formatIndex, 0);
      notifier().selectTarget(ShareTarget.instagram);
      expect(state().config.formatIndex, 0);
    });

    test('投稿先ごとに設定が別々', () {
      notifier().toggle(SharePart.setlist, ShareLayer.caption);
      expect(
        state().config.isOn(SharePart.setlist, ShareLayer.caption),
        isTrue,
      );
      notifier().selectTarget(ShareTarget.instagram);
      expect(
        state().config.isOn(SharePart.setlist, ShareLayer.caption),
        isFalse,
      );
      notifier().selectTarget(ShareTarget.x);
      expect(
        state().config.isOn(SharePart.setlist, ShareLayer.caption),
        isTrue,
      );
    });

    test('投稿先ごとに文章の手直しも別々', () {
      notifier().setCaption('Xの文章');
      notifier().selectTarget(ShareTarget.instagram);
      expect(state().captionOverride[ShareTarget.instagram], isNull);
      notifier().setCaption('IGの文章');
      notifier().selectTarget(ShareTarget.x);
      expect(state().captionOverride[ShareTarget.x], 'Xの文章');
    });
  });

  group('toggle', () {
    test('のせる部分を切り替えても、手直し済みの文章は残る。resetCaption で自動に戻る', () {
      notifier().setCaption('手直し');
      notifier().toggle(SharePart.setlist, ShareLayer.caption);
      expect(
        state().config.isOn(SharePart.setlist, ShareLayer.caption),
        isTrue,
      );
      expect(state().captionOverride[ShareTarget.x], '手直し');
      expect(currentCaption(state(), _content), '手直し');
      notifier().resetCaption();
      expect(state().captionOverride[ShareTarget.x], isNull);
      expect(currentCaption(state(), _content), contains('セトリ：曲A'));
    });

    test('押せない組み合わせは何も変えない（手直しも残る）', () {
      notifier().setCaption('手直し');
      final before = state().config;
      notifier().toggle(SharePart.photo, ShareLayer.caption);
      expect(identical(state().config, before), isTrue);
      expect(state().captionOverride[ShareTarget.x], '手直し');
    });

    test('別の投稿先の手直しは捨てない', () {
      notifier().selectTarget(ShareTarget.instagram);
      notifier().setCaption('IG手直し');
      notifier().selectTarget(ShareTarget.x);
      notifier().toggle(SharePart.setlist, ShareLayer.caption);
      expect(state().captionOverride[ShareTarget.instagram], 'IG手直し');
    });
  });

  group('形・デザイン・背景', () {
    test('setFormat は範囲内だけ', () {
      notifier().setFormat(1);
      expect(state().config.formatIndex, 1);
      notifier().setFormat(2);
      notifier().setFormat(-1);
      expect(state().config.formatIndex, 1);
    });

    test('setDesign・setBackground', () {
      notifier().setDesign(ShareDesign.photoMain);
      notifier().setBackground(6);
      expect(state().config.design, ShareDesign.photoMain);
      expect(state().config.backgroundIndex, 6);
      notifier().selectTarget(ShareTarget.instagram);
      expect(state().config.design, ShareDesign.ticket);
    });
  });

  group('文章', () {
    test('currentCaption: 手直しが無ければ自動、あればそれ', () {
      expect(
        currentCaption(state(), _content),
        buildCaption(ShareTarget.x, state().config, _content),
      );
      notifier().setCaption('手直しした文章');
      expect(currentCaption(state(), _content), '手直しした文章');
    });

    test('手直しが空文字でも、手直し済みとして扱う（自動に戻らない）', () {
      notifier().setCaption('');
      expect(currentCaption(state(), _content), '');
    });

    test('resetCaption で自動に戻る', () {
      notifier().setCaption('手直し');
      notifier().resetCaption();
      expect(
        currentCaption(state(), _content),
        buildCaption(ShareTarget.x, state().config, _content),
      );
    });

    test('のせる部分を変えると自動で作り直される（手直し前）', () {
      final before = currentCaption(state(), _content);
      notifier().toggle(SharePart.setlist, ShareLayer.caption);
      final after = currentCaption(state(), _content);
      expect(before, isNot(contains('セトリ')));
      expect(after, contains('セトリ：曲A'));
    });
  });

  group('Instagram の番号の丸', () {
    test('markImageSaved・markCaptionCopied', () {
      notifier().markImageSaved();
      expect(state().imageSaved, isTrue);
      expect(state().captionCopied, isFalse);
      notifier().markCaptionCopied();
      expect(state().captionCopied, isTrue);
    });
  });

  group('shareContentProvider: 座席が入らない', () {
    final memory = LiveMemory(
      performanceId: 'p1',
      liveId: 'l1',
      liveTitle: 'ツアー',
      startAt: DateTime.utc(2026, 12, 19, 9),
      venue: '東京ドーム',
      seat: _secretSeat,
      setlist: const ['曲A', '曲B'],
      impression: '最高',
      images: const ['a.jpg', 'b.jpg'],
    );

    ProviderContainer make({List<LiveMemory> init = const []}) {
      final c = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('u1'),
          memoryRepositoryProvider.overrideWithValue(
            FakeMemoryRepository(init),
          ),
          liveRepositoryProvider.overrideWithValue(
            FakeLiveRepository(
              lives: [
                const Live(id: 'l1', title: 'ツアー', groupIds: ['g1']),
              ],
            ),
          ),
          oshiRepositoryProvider.overrideWithValue(
            FakeOshiRepository([
              oshi('g1', 'ひかり'),
              oshi('o1', '別人', kind: OshiKind.person),
            ]),
          ),
        ],
        retry: (_, _) => null,
      );
      addTearDown(c.dispose);
      c.listen(shareContentProvider('p1'), (_, _) {});
      return c;
    }

    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('内容は記録から作られ、出演者名・写真の数が入る', () async {
      final c = make(init: [memory]);
      await settle();
      final content = c.read(shareContentProvider('p1')).value!;
      expect(content!.title, 'ツアー');
      expect(content.venue, '東京ドーム');
      expect(content.setlist, ['曲A', '曲B']);
      expect(content.artist, 'ひかり');
      expect(content.performerNames, ['ひかり']);
      expect(content.photoCount, 2);
    });

    test('どの設定でも、文章に座席が出ない', () async {
      final c = make(init: [memory]);
      await settle();
      final content = c.read(shareContentProvider('p1')).value!;
      for (final target in ShareTarget.values) {
        var cfg = ShareConfig.defaults(target);
        for (final p in SharePart.values) {
          for (final l in ShareLayer.values) {
            if (!cfg.isOn(p, l)) cfg = cfg.toggled(p, l);
          }
        }
        final text = buildCaption(target, cfg, content!);
        expect(text, isNot(contains(_secretSeat)));
        expect(text, isNot(contains('A12')));
        final image = layoutShareText(content, shareFormats[target]!.first);
        expect(
          [...image.setShown, image.memoShown].join(' '),
          isNot(contains('A12')),
        );
      }
    });

    test('記録が無ければ null（エラーではない）', () async {
      final c = make();
      await settle();
      final v = c.read(shareContentProvider('p1'));
      expect(v.hasValue, isTrue);
      expect(v.value, isNull);
    });
  });
}
