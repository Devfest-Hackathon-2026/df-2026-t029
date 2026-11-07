// Step4 の画面（Q4）: 保存時の照合 → 候補の選択 → 差分の確認 → 反映、
// 同時更新の知らせ、編集（/lives/:liveId/edit）、ライブ詳細の変更履歴と元に戻す。
// 本物のプロバイダを使い、リポジトリだけを偽物に差し替える。
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oshiashi/features/live/live_detail_page.dart';
import 'package:oshiashi/features/live_form/live_draft.dart';
import 'package:oshiashi/features/live_form/live_form_page.dart';
import 'package:oshiashi/features/live_merge/live_edit_page.dart';
import 'package:oshiashi/models/history_entry.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/models/reception.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';
import 'package:oshiashi/repositories/live_repository.dart';

import '../utils/live_merge_fixtures.dart';
import 'live_test_helpers.dart';
import 'oshi_test_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));
final _saveButton = _key('live_form_save_button');
final _applyButton = _key('merge_review_apply_button');

final _g1 = oshi('g1', 'グループ1');
final _g2 = oshi('g2', 'グループ2');
final _now = DateTime(2026, 11, 5, 12);

/// 既存のライブ L1（g1・公演 p1・受付 r1）
ExistingLive _existing({
  String title = 'ツアー2026',
  List<String> groupIds = const ['g1'],
}) => existingLive(
  title: title,
  groupIds: groupIds,
  performances: [existingPerf('p1', startAt: jst(2026, 12, 20, 18))],
  receptions: [existingRec('r1', applyEndAt: jst(2026, 11, 20, 23, 59))],
);

/// 既存の L1 と同じ内容の下書き（[change] で一部を変える）
LiveDraft _draft({
  String title = 'ツアー2026',
  DateTime? paymentDeadline,
  String venue = '東京ドーム',
}) => LiveDraft(
  title: title,
  selectedPerformers: [_g1],
  performances: [
    PerformanceDraft(startAt: jst(2026, 12, 20, 18), venue: venue),
  ],
  receptions: [
    ReceptionDraft(
      type: ReceptionType.fc,
      name: 'FC1次先行',
      applyEndAt: jst(2026, 11, 20, 23, 59),
      paymentDeadline: paymentDeadline,
    ),
  ],
);

Future<GoRouter> _pump(
  WidgetTester tester,
  FakeLiveRepository repo, {
  LiveDraft? draft,
  String initialLocation = '/start',
  FakeOshiRepository? oshiRepo,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Text('route:/'),
        routes: [
          GoRoute(
            path: 'lives',
            builder: (_, _) => const Text('route:/lives'),
            routes: [
              GoRoute(
                path: ':liveId',
                builder: (_, s) =>
                    LiveDetailPage(liveId: s.pathParameters['liveId']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, s) =>
                        LiveEditPage(liveId: s.pathParameters['liveId']!),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/start',
        builder: (c, _) => Scaffold(
          body: TextButton(
            onPressed: () => c.push('/live-form', extra: draft ?? _draft()),
            child: const Text('入力を開く'),
          ),
        ),
      ),
      GoRoute(
        path: '/live-form',
        builder: (_, s) => LiveFormPage(initial: s.extra as LiveDraft?),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        oshiRepositoryProvider.overrideWithValue(
          oshiRepo ?? FakeOshiRepository([_g1, _g2]),
        ),
        followRepositoryProvider.overrideWithValue(
          FakeFollowRepository(const FollowState(groupIds: {'g1'})),
        ),
        liveRepositoryProvider.overrideWithValue(repo),
        applicationRepositoryProvider.overrideWithValue(
          FakeApplicationRepository(),
        ),
        nowProvider.overrideWithValue(_now),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  if (initialLocation == '/start') {
    await tester.tap(find.text('入力を開く'));
    await tester.pumpAndSettle();
  }
  return router;
}

/// 保存中・反映中は進捗表示が回り続けて pumpAndSettle が終わらないので、
/// 一定の時間だけ進める
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 保存・反映の後に出る Google カレンダーの追加シートを「追加しない」で閉じる
Future<void> _skipCalendar(WidgetTester tester) async {
  if (find.text('追加しない').evaluate().isNotEmpty) {
    await tester.tap(find.text('追加しない'));
    await _settle(tester);
  }
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(_saveButton);
  await tester.tap(_saveButton);
  await _settle(tester);
}

String _location(GoRouter r) =>
    r.routerDelegate.currentConfiguration.uri.toString();

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('保存時の照合と候補の選択', () {
    testWidgets('候補が無ければ、今までどおり新規作成する', (tester) async {
      final repo = FakeLiveRepository();
      final router = await _pump(tester, repo);
      await _tapSave(tester);
      // カレンダーの追加シートを閉じる
      await _skipCalendar(tester);
      expect(repo.candidateCalls.single.groupIds, ['g1']);
      expect(repo.created, hasLength(1));
      expect(repo.merged, isEmpty);
      expect(_key('merge_candidates_sheet'), findsNothing);
      expect(_location(router), '/lives/new-live-1');
    });

    testWidgets('候補があればシートを出す。閉じたら何もせず、入力は残り、もう一度保存できる', (tester) async {
      final repo = FakeLiveRepository()..candidates = [_existing()];
      await _pump(
        tester,
        repo,
        draft: _draft(paymentDeadline: jst(2026, 11, 28)),
      );
      await _tapSave(tester);
      expect(_key('merge_candidates_sheet'), findsOneWidget);
      expect(_key('merge_candidate_L1'), findsOneWidget);
      expect(find.text('ライブ名が同じ'), findsOneWidget);
      // シートの外を押して閉じる
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
      expect(_key('merge_candidates_sheet'), findsNothing);
      expect(repo.created, isEmpty);
      expect(repo.merged, isEmpty);
      expect(find.text('ツアー2026'), findsWidgets); // 入力は残る
      // もう一度保存できる（保存中のまま固まらない）
      await _tapSave(tester);
      expect(_key('merge_candidates_sheet'), findsOneWidget);
    });

    testWidgets('「別のライブとして新しく登録する」なら新規作成', (tester) async {
      final repo = FakeLiveRepository()..candidates = [_existing()];
      await _pump(tester, repo);
      await _tapSave(tester);
      await tester.ensureVisible(_key('merge_candidate_new_button'));
      await tester.tap(_key('merge_candidate_new_button'));
      await _settle(tester);
      await _skipCalendar(tester);
      expect(repo.created, hasLength(1));
      expect(repo.merged, isEmpty);
    });

    testWidgets('既存に反映して差分が無ければ「すでに登録済みです」で詳細へ。書き込まない', (tester) async {
      final repo = FakeLiveRepository()..candidates = [_existing()];
      final router = await _pump(tester, repo);
      await _tapSave(tester);
      await tester.tap(_key('merge_candidate_use_L1'));
      await tester.pump();
      expect(find.text('すでに登録済みです'), findsOneWidget);
      await _settle(tester);
      expect(repo.created, isEmpty);
      expect(repo.merged, isEmpty);
      expect(_location(router), '/lives/L1');
    });

    testWidgets('照合の読み取りに失敗したら知らせ、新規作成はしない', (tester) async {
      final repo = FakeLiveRepository()..fetchError = permissionDenied();
      await _pump(tester, repo);
      await _tapSave(tester);
      expect(
        find.text('登録済みのライブを確認できませんでした。通信状況を確かめて、もう一度お試しください'),
        findsOneWidget,
      );
      expect(repo.created, isEmpty);
      // 保存ボタンは押せるまま
      final button = tester.widget<ButtonStyleButton>(_saveButton);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('360px 幅で候補の選択シートがはみ出さない', (tester) async {
      _usePhone(tester);
      final repo = FakeLiveRepository()
        ..candidates = [
          _existing(),
          existingLive(
            id: 'L2',
            title: 'ツアー2026 ${'とても長い名前' * 5}',
            performances: [existingPerf('x')],
          ),
        ];
      await _pump(tester, repo);
      await _tapSave(tester);
      expect(_key('merge_candidates_sheet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('差分の確認と反映', () {
    Future<GoRouter> openReview(
      WidgetTester tester,
      FakeLiveRepository repo, {
      LiveDraft? draft,
    }) async {
      repo.candidates = [_existing()];
      final router = await _pump(
        tester,
        repo,
        draft:
            draft ??
            _draft(
              paymentDeadline: jst(2026, 11, 28, 23, 59),
              title: 'ツアー2026 改',
            ),
      );
      await _tapSave(tester);
      await tester.tap(_key('merge_candidate_use_L1'));
      await _settle(tester);
      return router;
    }

    testWidgets('変更が項目ごとにチェック付きで並び、外した変更は反映しない', (tester) async {
      final repo = FakeLiveRepository();
      final router = await openReview(tester, repo);
      expect(_key('merge_review_list'), findsOneWidget);
      expect(_key('merge_review_check_live/title'), findsOneWidget);
      expect(
        _key('merge_review_check_receptions/r1/paymentDeadline'),
        findsOneWidget,
      );
      expect(find.textContaining('反映する（2件）'), findsOneWidget);
      // 変化なしの公演は折りたたみ
      expect(_key('merge_review_unchanged_performance'), findsOneWidget);

      await tester.tap(_key('merge_review_check_live/title'));
      await tester.pump();
      expect(find.textContaining('反映する（1件）'), findsOneWidget);
      await tester.tap(_applyButton);
      await tester.pump();
      expect(find.text('反映しました'), findsOneWidget);
      await _settle(tester);

      final plan = repo.merged.single.plan;
      expect(repo.merged.single.uid, 'u1');
      expect(plan.liveChanges, isEmpty);
      expect(
        plan.changedReceptions.single.changes.single.field,
        'paymentDeadline',
      );
      expect(repo.created, isEmpty);
      expect(_location(router), '/lives/L1');
    });

    testWidgets('すべて外すと反映ボタンは押せない', (tester) async {
      final repo = FakeLiveRepository();
      await openReview(tester, repo);
      await tester.tap(_key('merge_review_check_live/title'));
      await tester.tap(
        _key('merge_review_check_receptions/r1/paymentDeadline'),
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(_applyButton).onPressed, isNull);
      expect(find.text('反映する変更が選ばれていません'), findsOneWidget);
    });

    testWidgets('反映中はボタンを押せず、2回押しても1回だけ反映する', (tester) async {
      final repo = FakeLiveRepository()..mergeGate = Completer<void>();
      await openReview(tester, repo);
      await tester.tap(_applyButton);
      await tester.pump();
      await tester.tap(_applyButton, warnIfMissed: false);
      await tester.pump();
      expect(tester.widget<FilledButton>(_applyButton).onPressed, isNull);
      expect(repo.merged, hasLength(1));
      repo.mergeGate!.complete();
      await _settle(tester);
      expect(repo.merged, hasLength(1));
    });

    testWidgets('同時更新: 知らせて最新の内容で差分を作り直し、入力は残る（上書きしない）', (tester) async {
      final repo = FakeLiveRepository()
        ..mergeError = const LiveConflictException(['lives/L1'])
        // 読み直すと、ほかの人がライブ名を同じ名前に変えていた
        ..existing = {'L1': _existing(title: 'ツアー2026 改')};
      await openReview(tester, repo);
      await tester.tap(_applyButton);
      await _settle(tester);
      expect(find.text('ほかの人が先に更新しました。最新の内容で確認し直してください'), findsOneWidget);
      expect(_key('merge_review_list'), findsOneWidget); // 画面に残る
      // 読み直した結果、ライブ名の変更は無くなり、入金期限だけが残る
      expect(_key('merge_review_check_live/title'), findsNothing);
      expect(find.textContaining('反映する（1件）'), findsOneWidget);
      // もう一度反映すると、作り直した計画で反映する
      repo.mergeError = null;
      await tester.tap(_applyButton);
      await _settle(tester);
      expect(repo.merged, hasLength(2));
      expect(repo.merged.last.plan.base.live.title, 'ツアー2026 改');
      expect(repo.merged.last.plan.liveChanges, isEmpty);
    });

    testWidgets('同時更新で読み直したら変更が無くなったときは「すでに登録済みです」', (tester) async {
      final repo = FakeLiveRepository()
        ..mergeError = const LiveConflictException(['lives/L1']);
      final latest = _existing(title: 'ツアー2026 改');
      repo.existing = {
        'L1': ExistingLive(
          live: latest.live,
          performances: latest.performances,
          receptions: [
            existingRec(
              'r1',
              applyEndAt: jst(2026, 11, 20, 23, 59),
              paymentDeadline: jst(2026, 11, 28, 23, 59),
            ),
          ],
        ),
      };
      final router = await openReview(tester, repo);
      await tester.tap(_applyButton);
      await _settle(tester);
      expect(repo.merged, hasLength(1)); // 失敗した1回だけ
      expect(_location(router), '/lives/L1');
    });

    testWidgets('反映に失敗（通信など）したら知らせ、画面に残ってもう一度押せる', (tester) async {
      final repo = FakeLiveRepository()..mergeError = permissionDenied();
      await openReview(tester, repo);
      await tester.tap(_applyButton);
      await _settle(tester);
      expect(find.text('反映できませんでした。通信状況を確かめて、もう一度お試しください'), findsOneWidget);
      expect(tester.widget<FilledButton>(_applyButton).onPressed, isNotNull);
    });

    testWidgets('日程変更: 追加の公演を「登録済みのものの変更として扱う」で対応付け、取り消せる', (tester) async {
      final repo = FakeLiveRepository();
      final draft = _draft()
        ..performances.first.startAt = jst(2026, 12, 27, 18);
      await openReview(tester, repo, draft: draft);
      expect(_key('merge_review_row_performances/+0'), findsOneWidget);
      expect(
        _key('merge_review_row_performances/p1'),
        findsOneWidget,
      ); // 今回の入力に無い
      expect(find.text('今回の入力に無い（消さずに残します）'), findsOneWidget);

      await tester.ensureVisible(_key('merge_review_pair_performances/+0'));
      await tester.tap(_key('merge_review_pair_performances/+0'));
      await _settle(tester);
      expect(_key('merge_review_pair_sheet'), findsOneWidget);
      await tester.tap(_key('merge_review_pair_choice_p1'));
      await _settle(tester);
      expect(_key('merge_review_row_performances/+0'), findsNothing);
      expect(
        _key('merge_review_check_performances/p1/startAt'),
        findsOneWidget,
      );

      await tester.ensureVisible(_key('merge_review_unpair_performances/p1'));
      await tester.tap(_key('merge_review_unpair_performances/p1'));
      await _settle(tester);
      expect(_key('merge_review_row_performances/+0'), findsOneWidget);
      expect(_key('merge_review_check_performances/p1/startAt'), findsNothing);

      // 対応付けて反映すると、計画は p1 の変更になる
      await tester.ensureVisible(_key('merge_review_pair_performances/+0'));
      await tester.tap(_key('merge_review_pair_performances/+0'));
      await _settle(tester);
      await tester.tap(_key('merge_review_pair_choice_p1'));
      await _settle(tester);
      await tester.tap(_applyButton);
      await _settle(tester);
      final plan = repo.merged.single.plan;
      expect(plan.addedPerformances, isEmpty);
      expect(plan.changedPerformances.single.existing.id, 'p1');
    });

    testWidgets('戻るで閉じたら何もせず、入力画面に戻る', (tester) async {
      final repo = FakeLiveRepository();
      await openReview(tester, repo);
      await tester.pageBack();
      await _settle(tester);
      expect(_key('merge_review_list'), findsNothing);
      expect(_saveButton, findsOneWidget);
      expect(repo.merged, isEmpty);
      expect(
        tester.widget<ButtonStyleButton>(_saveButton).onPressed,
        isNotNull,
      );
    });

    testWidgets('360px 幅で差分の確認がはみ出さない', (tester) async {
      _usePhone(tester);
      final repo = FakeLiveRepository();
      await openReview(
        tester,
        repo,
        draft: _draft(
          title: 'ツアー2026 ${'とても長いライブ名' * 6}',
          paymentDeadline: jst(2026, 11, 28),
        ),
      );
      expect(_key('merge_review_list'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('編集（/lives/:liveId/edit）', () {
    testWidgets('読み込み中 → 内容の入った入力画面。何も変えずに保存すると「変更はありません」で書き込まない', (
      tester,
    ) async {
      final repo = FakeLiveRepository()..existing = {'L1': _existing()};
      final router = await _pump(
        tester,
        repo,
        initialLocation: '/lives/L1/edit',
      );
      expect(find.text('ライブ情報の編集'), findsOneWidget);
      expect(find.text('ツアー2026'), findsWidgets);
      await _tapSave(tester);
      expect(repo.candidateCalls, isEmpty); // 照合は飛ばす
      expect(repo.merged, isEmpty);
      expect(repo.created, isEmpty);
      expect(_location(router), '/lives/L1');
    });

    testWidgets('無いライブは「見つかりませんでした」', (tester) async {
      final repo = FakeLiveRepository();
      await _pump(tester, repo, initialLocation: '/lives/none/edit');
      expect(_key('live_edit_not_found'), findsOneWidget);
    });

    testWidgets('読み込みに失敗したらエラーと「もう一度読み込む」', (tester) async {
      final repo = FakeLiveRepository()..fetchError = permissionDenied();
      await _pump(tester, repo, initialLocation: '/lives/L1/edit');
      expect(_key('live_edit_error'), findsOneWidget);
      repo
        ..fetchError = null
        ..existing = {'L1': _existing()};
      await tester.tap(find.text('もう一度読み込む'));
      await _settle(tester);
      expect(find.text('ライブ情報の編集'), findsOneWidget);
      expect(_saveButton, findsOneWidget);
    });

    testWidgets('会場名を直して保存すると、ID で対応した変更として差分の確認に出る', (tester) async {
      final repo = FakeLiveRepository()..existing = {'L1': _existing()};
      await _pump(tester, repo, initialLocation: '/lives/L1/edit');
      final venue = find.widgetWithText(TextField, '東京ドーム');
      await tester.ensureVisible(venue);
      await tester.enterText(venue, '東京ドーム（変更）');
      await _tapSave(tester);
      expect(_key('merge_review_check_performances/p1/venue'), findsOneWidget);
      expect(_key('merge_review_unremovable_performers'), findsNothing);
      await tester.tap(_applyButton);
      await _settle(tester);
      final plan = repo.merged.single.plan;
      expect(plan.editing, isTrue);
      expect(plan.changedPerformances.single.existing.id, 'p1');
    });

    testWidgets('出演者を外しても外れないことを文字で知らせる', (tester) async {
      final repo = FakeLiveRepository()
        ..existing = {
          'L1': _existing(groupIds: ['g1', 'g2']),
        };
      await _pump(tester, repo, initialLocation: '/lives/L1/edit');
      // 出演者の g2 を外す（チップの削除）
      final chip = find.ancestor(
        of: find.text('グループ2'),
        matching: find.byType(InputChip),
      );
      await tester.ensureVisible(chip);
      // 削除アイコンの見た目はテーマで変わるので、削除の操作を直接呼ぶ
      tester.widget<InputChip>(chip).onDeleted!();
      await tester.pump();
      // ほかに会場も直す（変更が無いと「変更はありません」になるため）
      final venue = find.widgetWithText(TextField, '東京ドーム');
      await tester.ensureVisible(venue);
      await tester.enterText(venue, '別会場');
      await _tapSave(tester);
      expect(_key('merge_review_unremovable_performers'), findsOneWidget);
      expect(find.textContaining('出演者は外せません（グループ2はそのまま残ります）'), findsOneWidget);
    });

    testWidgets('回帰: 出演者を外す「だけ」なら、外れないことを名前つきで知らせ、書き込まない', (tester) async {
      final repo = FakeLiveRepository()
        ..existing = {
          'L1': _existing(groupIds: ['g1', 'g2']),
        };
      final router = await _pump(
        tester,
        repo,
        initialLocation: '/lives/L1/edit',
      );
      final chip = find.ancestor(
        of: find.text('グループ2'),
        matching: find.byType(InputChip),
      );
      await tester.ensureVisible(chip);
      tester.widget<InputChip>(chip).onDeleted!();
      await tester.pump();
      await _tapSave(tester);
      expect(find.text('出演者は外せません（グループ2はそのまま残ります）'), findsOneWidget);
      expect(repo.merged, isEmpty);
      expect(_location(router), '/lives/L1');
    });
  });

  group('ライブ詳細: 変更あり・変更履歴・元に戻す', () {
    final created = DateTime(2026, 10, 1);
    const live = HistoryTarget(HistoryCollection.lives, 'L1');
    const r1 = HistoryTarget(HistoryCollection.receptions, 'r1');
    final changedAt = _now.subtract(const Duration(hours: 2));

    HistoryEntry deadlineChange({String id = 'h1', String by = 'u2'}) =>
        HistoryEntry(
          id: id,
          target: r1,
          field: 'applyEndAt',
          before: Timestamp.fromDate(DateTime(2026, 11, 20, 23, 59)),
          after: Timestamp.fromDate(DateTime(2026, 11, 18, 23, 59)),
          hasBefore: true,
          hasAfter: true,
          changedBy: by,
          changedAt: changedAt,
        );

    FakeLiveRepository detailRepo({List<HistoryEntry>? history}) {
      final e = _existing();
      return FakeLiveRepository(
          lives: [e.live],
          performances: e.performances,
          receptions: [
            existingRec('r1', applyEndAt: DateTime(2026, 11, 18, 23, 59)),
          ],
        )
        ..docStamps = {
          'L1': [
            DocStamp(target: live, createdAt: created),
            const DocStamp(
              target: HistoryTarget(HistoryCollection.performances, 'p1'),
            ),
            DocStamp(target: r1, createdAt: created),
          ],
        }
        ..history = {
          r1: history ?? [deadlineChange()],
        };
    }

    testWidgets('7日以内に変わった受付に「変更あり」と変更の内容、履歴に「ほかのユーザー」', (tester) async {
      final repo = detailRepo();
      await _pump(tester, repo, initialLocation: '/lives/L1');
      expect(_key('live_detail_changed_r1'), findsOneWidget);
      expect(find.text('変更あり'), findsOneWidget);
      expect(find.textContaining('申込期限'), findsWidgets);
      expect(find.textContaining('2時間前'), findsWidgets);
      await tester.scrollUntilVisible(
        _key('live_detail_history_entry_h1'),
        200,
      );
      expect(find.textContaining('ほかのユーザー'), findsOneWidget);
      expect(_key('live_detail_edit_button'), findsOneWidget);
    });

    testWidgets('履歴が無ければ「変更はまだありません」で印も無い', (tester) async {
      final repo = detailRepo(history: const []);
      await _pump(tester, repo, initialLocation: '/lives/L1');
      expect(_key('live_detail_changed_r1'), findsNothing);
      await tester.scrollUntilVisible(_key('live_detail_history_empty'), 200);
      expect(find.text('変更はまだありません'), findsOneWidget);
    });

    testWidgets('元に戻す: 確認ダイアログ → revert。やめるなら何もしない', (tester) async {
      final repo = detailRepo();
      await _pump(tester, repo, initialLocation: '/lives/L1');
      final revert = _key('live_detail_history_revert_h1');
      await tester.scrollUntilVisible(revert, 200);
      await tester.ensureVisible(revert);
      await _settle(tester);
      await tester.tap(revert);
      await _settle(tester);
      await tester.tap(find.text('やめる'));
      await _settle(tester);
      expect(repo.reverted, isEmpty);

      await tester.ensureVisible(revert);
      await tester.tap(revert);
      await _settle(tester);
      await tester.tap(_key('live_detail_history_revert_confirm'));
      await _settle(tester);
      expect(repo.reverted.single.entry.id, 'h1');
      expect(repo.reverted.single.uid, 'u1');
      expect(find.text('元に戻しました'), findsOneWidget);
    });

    testWidgets('回帰: ダイアログを開いている間は「元に戻す」を押せず、閉じれば戻る', (tester) async {
      final repo = detailRepo();
      await _pump(tester, repo, initialLocation: '/lives/L1');
      final revert = _key('live_detail_history_revert_h1');
      await tester.scrollUntilVisible(revert, 200);
      await tester.ensureVisible(revert);
      await _settle(tester);
      await tester.tap(revert);
      await _settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      // ダイアログの裏では、その行は進捗表示になり「元に戻す」は無い
      expect(revert, findsNothing);
      // 外側をタップして閉じると、また押せる（何もしていない）
      await tester.tapAt(const Offset(5, 5));
      await _settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(revert, findsOneWidget);
      expect(repo.reverted, isEmpty);
      // 「やめる」で閉じても戻る
      await tester.ensureVisible(revert);
      await tester.tap(revert);
      await _settle(tester);
      await tester.tap(find.text('やめる'));
      await _settle(tester);
      expect(revert, findsOneWidget);
      expect(repo.reverted, isEmpty);
    });

    testWidgets('元に戻す: その後に別の変更があれば知らせる', (tester) async {
      final repo = detailRepo()
        ..revertError = const LiveConflictException(['receptions/r1']);
      await _pump(tester, repo, initialLocation: '/lives/L1');
      final revert = _key('live_detail_history_revert_h1');
      await tester.scrollUntilVisible(revert, 200);
      await tester.ensureVisible(revert);
      await _settle(tester);
      await tester.ensureVisible(revert);
      await tester.tap(revert);
      await _settle(tester);
      await tester.tap(_key('live_detail_history_revert_confirm'));
      await _settle(tester);
      expect(find.text('その後に別の変更があります。最新の内容を確かめてください'), findsOneWidget);
    });

    testWidgets('出演者の履歴には「元に戻す」が無い。自分の変更は「あなた」', (tester) async {
      final repo = detailRepo()
        ..history = {
          live: [
            HistoryEntry(
              id: 'g',
              target: live,
              field: 'groupIds',
              before: const ['g1'],
              after: const ['g1', 'g2'],
              hasBefore: true,
              hasAfter: true,
              changedBy: 'u1',
              changedAt: changedAt,
            ),
          ],
        };
      await _pump(tester, repo, initialLocation: '/lives/L1');
      await tester.scrollUntilVisible(_key('live_detail_history_entry_g'), 200);
      expect(_key('live_detail_history_revert_g'), findsNothing);
      expect(find.textContaining('あなた'), findsOneWidget);
      expect(find.textContaining('グループ1、グループ2'), findsWidgets);
    });

    testWidgets('「このライブを編集」で編集画面へ', (tester) async {
      final repo = detailRepo()..existing = {'L1': _existing()};
      final router = await _pump(tester, repo, initialLocation: '/lives/L1');
      await tester.ensureVisible(_key('live_detail_edit_button'));
      await tester.tap(_key('live_detail_edit_button'));
      await _settle(tester);
      expect(_location(router), '/lives/L1/edit');
      expect(find.text('ライブ情報の編集'), findsOneWidget);
    });
  });
}
