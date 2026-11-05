// ライブ詳細の公式 URL のリンク（lib/features/live/official_url_link.dart）。
// 公式 URL は共通データ（誰でも登録できる）なので、https 以外はリンクにしない。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/live/official_url_link.dart';

/// 開く処理の呼び出しを記録する偽物
class _Opener {
  _Opener({this.result = true, this.error});

  final bool result;
  final Object? error;
  final calls = <Uri>[];

  Future<bool> call(Uri uri) async {
    calls.add(uri);
    if (error case final e?) throw e;
    return result;
  }
}

Future<void> _pumpLink(WidgetTester tester, String url, _Opener opener) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [urlLauncherProvider.overrideWithValue(opener.call)],
      child: MaterialApp(
        home: Scaffold(
          body: OfficialUrlLink(key: const Key('link'), url: url),
        ),
      ),
    ),
  );
}

Finder get _inkWell => find.descendant(
  of: find.byKey(const Key('link')),
  matching: find.byType(InkWell),
);

void main() {
  group('officialLinkUri', () {
    test('https の URL は Uri になる', () {
      for (final url in [
        'https://example.com',
        'https://example.com/live/2026?id=1#top',
        'https://例え.jp/パス',
        'https://example.com:8443/a',
      ]) {
        final uri = officialLinkUri(url);
        expect(uri, isNotNull, reason: url);
        expect(uri!.scheme, 'https', reason: url);
        expect(uri.host, isNotEmpty, reason: url);
      }
      expect(officialLinkUri('https://example.com/a')!.path, '/a');
    });

    test('https 以外・壊れたものは null（リンクにしない）', () {
      for (final url in <String?>[
        null,
        '',
        'http://example.com',
        'HTTPS://example.com',
        'javascript:alert(1)',
        'https://',
        'https:///path',
        'https:// example.com',
        'https://exa mple.com',
        'https://example.com/a\tb',
        'https://example.com/a\nb',
        'https://example.com/a　b',
        ' https://example.com',
        'ftp://example.com',
        'data:text/html,<script>alert(1)</script>',
        'example.com',
      ]) {
        expect(officialLinkUri(url), isNull, reason: '$url');
      }
    });
  });

  group('officialLinkUri: userinfo 付きの URL（回帰テスト）', () {
    test('userinfo があれば null（見た目と開く先が違うリンクを作らせない）', () {
      for (final url in [
        'https://example.com@evil.example/x',
        'https://user:pass@example.com/',
        'https://user@example.com',
        'https://:@example.com',
      ]) {
        expect(officialLinkUri(url), isNull, reason: url);
      }
    });

    test('パスやクエリに @ があるだけなら、今までどおり Uri', () {
      for (final url in [
        'https://example.com/a@b',
        'https://example.com/?mail=a@b.jp',
        'https://example.com/#@top',
      ]) {
        final uri = officialLinkUri(url);
        expect(uri, isNotNull, reason: url);
        expect(uri!.host, 'example.com', reason: url);
      }
    });

    testWidgets('userinfo 付きの URL は、文字だけで押しても開かない', (tester) async {
      const url = 'https://example.com@evil.example/x';
      final opener = _Opener();
      await _pumpLink(tester, url, opener);
      expect(find.text(url), findsOneWidget);
      expect(_inkWell, findsNothing);
      await tester.tap(find.text(url));
      await tester.pumpAndSettle();
      expect(opener.calls, isEmpty);
    });
  });

  group('OfficialUrlLink', () {
    testWidgets('https の URL を押すと、開く処理を1回、その Uri で呼ぶ', (tester) async {
      final opener = _Opener();
      await _pumpLink(tester, 'https://example.com/tour', opener);
      expect(find.text('https://example.com/tour'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);

      await tester.tap(_inkWell);
      await tester.pumpAndSettle();
      expect(opener.calls, [Uri.parse('https://example.com/tour')]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('https 以外はリンクにせず、文字だけを出す（押しても開かない）', (tester) async {
      for (final url in [
        'http://example.com',
        'javascript:alert(1)',
        'https://exa mple.com',
        'https://',
      ]) {
        final opener = _Opener();
        await _pumpLink(tester, url, opener);
        expect(find.text(url), findsOneWidget, reason: url);
        expect(_inkWell, findsNothing, reason: url);
        expect(find.byIcon(Icons.open_in_new), findsNothing, reason: url);
        await tester.tap(find.text(url));
        await tester.pumpAndSettle();
        expect(opener.calls, isEmpty, reason: url);
      }
    });

    testWidgets('開けなかったとき（false）は SnackBar', (tester) async {
      final opener = _Opener(result: false);
      await _pumpLink(tester, 'https://example.com', opener);
      await tester.tap(_inkWell);
      await tester.pumpAndSettle();
      expect(opener.calls, hasLength(1));
      expect(find.text('公式サイトを開けませんでした'), findsOneWidget);
    });

    testWidgets('開く処理が例外を投げても落ちず、SnackBar', (tester) async {
      final opener = _Opener(error: Exception('no browser'));
      await _pumpLink(tester, 'https://example.com', opener);
      await tester.tap(_inkWell);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('公式サイトを開けませんでした'), findsOneWidget);
    });

    testWidgets('開いている間に画面が消えても落ちない（context.mounted）', (tester) async {
      final gate = Completer<bool>();
      final calls = <Uri>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            urlLauncherProvider.overrideWithValue((uri) {
              calls.add(uri);
              return gate.future;
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: OfficialUrlLink(
                key: const Key('link'),
                url: 'https://example.com',
              ),
            ),
          ),
        ),
      );
      await tester.tap(_inkWell);
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      gate.complete(false);
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('スマホの幅（360px）で長い URL でもはみ出さない', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpLink(tester, 'https://example.com/${'a' * 180}', _Opener());
      expect(tester.takeException(), isNull);
    });
  });

  group('連打の防止（回帰テスト）', () {
    /// 呼ばれるたびに Completer を作り、外から完了させる偽物
    final gates = <Completer<bool>>[];
    final calls = <Uri>[];
    setUp(() {
      gates.clear();
      calls.clear();
    });
    Future<bool> gated(Uri uri) {
      calls.add(uri);
      final c = Completer<bool>();
      gates.add(c);
      return c.future;
    }

    Future<void> pumpGated(WidgetTester tester) => tester.pumpWidget(
      ProviderScope(
        overrides: [urlLauncherProvider.overrideWithValue(gated)],
        child: const MaterialApp(
          home: Scaffold(
            body: OfficialUrlLink(key: Key('link'), url: 'https://example.com'),
          ),
        ),
      ),
    );

    testWidgets('開く処理の途中に何度押しても、呼ぶのは1回', (tester) async {
      await pumpGated(tester);
      await tester.tap(_inkWell);
      await tester.pump();
      await tester.tap(_inkWell);
      await tester.pump();
      await tester.tap(_inkWell);
      await tester.pump();
      expect(calls, hasLength(1));

      gates.single.complete(true);
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('開き終わった後に押せば、また開く', (tester) async {
      await pumpGated(tester);
      await tester.tap(_inkWell);
      await tester.pump();
      gates.last.complete(true);
      await tester.pumpAndSettle();

      await tester.tap(_inkWell);
      await tester.pump();
      expect(calls, hasLength(2));
      gates.last.complete(true);
      await tester.pumpAndSettle();
    });

    testWidgets('開けなかった（false）後も、また押せる', (tester) async {
      await pumpGated(tester);
      await tester.tap(_inkWell);
      await tester.pump();
      gates.last.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('公式サイトを開けませんでした'), findsOneWidget);

      await tester.tap(_inkWell);
      await tester.pump();
      expect(calls, hasLength(2));
      gates.last.complete(true);
      await tester.pumpAndSettle();
    });

    testWidgets('例外の後も、また押せる', (tester) async {
      await pumpGated(tester);
      await tester.tap(_inkWell);
      await tester.pump();
      gates.last.completeError(Exception('no browser'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('公式サイトを開けませんでした'), findsOneWidget);

      await tester.tap(_inkWell);
      await tester.pump();
      expect(calls, hasLength(2));
      gates.last.complete(true);
      await tester.pumpAndSettle();
    });

    testWidgets('見た目は押せるリンクのまま（開く処理の途中も）', (tester) async {
      await pumpGated(tester);
      await tester.tap(_inkWell);
      await tester.pump();
      expect(tester.widget<InkWell>(_inkWell).onTap, isNotNull);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
      gates.last.complete(true);
      await tester.pumpAndSettle();
    });
  });
}
