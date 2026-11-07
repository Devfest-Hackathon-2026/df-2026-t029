import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/oshi.dart';
import 'package:oshiashi/providers/live_providers.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';
import 'package:oshiashi/repositories/follow_repository.dart';
import 'package:oshiashi/repositories/oshi_repository.dart';

import 'live_test_helpers.dart';

OshiSummary oshi(
  String id,
  String name, {
  OshiKind kind = OshiKind.group,
  OshiStatus status = OshiStatus.approved,
  List<String> aliases = const [],
}) => OshiSummary(
  id: id,
  kind: kind,
  name: name,
  aliases: aliases,
  genre: OshiGenre.idol,
  status: status,
);

/// 購読のエラーに使う例外。allOshisProvider・followStateProvider は
/// `retry: firestoreRetry` を持ち、コンテナの retry より優先されるので、
/// permission-denied 以外のエラーを流すと再試行のタイマーが残る。
FirebaseException permissionDenied() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

/// watchAll の中身を外から操作できる偽のリポジトリ
class FakeOshiRepository implements OshiRepository {
  FakeOshiRepository([List<OshiSummary>? initial]) : _current = initial;

  /// null なら、値を流さない（読み込み中のまま）
  List<OshiSummary>? _current;
  final _updates = StreamController<List<OshiSummary>>.broadcast();

  /// true なら watchAll がエラーを流す
  bool fail = false;
  int watchCount = 0;

  final requests = <OshiRequest>[];

  /// 設定すると、request はこれが完了するまで待つ
  Completer<void>? requestGate;

  /// 設定すると、request はこれを投げる
  Object? requestError;

  void emit(List<OshiSummary> list) {
    _current = list;
    _updates.add(list);
  }

  @override
  Stream<List<OshiSummary>> watchAll() async* {
    watchCount++;
    if (fail) throw permissionDenied();
    if (_current != null) yield _current!;
    yield* _updates.stream;
  }

  @override
  Future<String> request(OshiRequest request, {required String uid}) async {
    requests.add(request);
    await requestGate?.future;
    if (requestError case final e?) throw e;
    return 'new-id';
  }
}

/// フォロー状態を覚えておく偽のリポジトリ
class FakeFollowRepository implements FollowRepository {
  FakeFollowRepository([this.state = FollowState.empty]);

  FollowState state;
  final _updates = StreamController<FollowState>.broadcast();
  bool fail = false;

  /// false なら watch は値を流さない（読み込み中のまま）
  bool emitInitial = true;

  final followCalls = <String>[];
  final unfollowCalls = <String>[];

  /// 設定すると、follow / unfollow はこれが完了するまで待つ
  Completer<void>? gate;

  /// 設定すると、follow / unfollow はこれを投げる
  Object? error;

  void _set(FollowState s) {
    state = s;
    _updates.add(s);
  }

  @override
  Stream<FollowState> watch(String uid) async* {
    if (fail) throw permissionDenied();
    if (emitInitial) yield state;
    yield* _updates.stream;
  }

  @override
  Future<void> follow(
    String uid,
    OshiSummary target, {
    String? displayName,
  }) async {
    followCalls.add(target.key);
    await gate?.future;
    if (error case final e?) throw e;
    _set(
      FollowState(
        groupIds: {
          ...state.groupIds,
          if (target.kind == OshiKind.group) target.id,
        },
        oshiIds: {
          ...state.oshiIds,
          if (target.kind == OshiKind.person) target.id,
        },
      ),
    );
  }

  @override
  Future<void> unfollow(String uid, OshiSummary target) async {
    unfollowCalls.add(target.key);
    await gate?.future;
    if (error case final e?) throw e;
    _set(
      FollowState(
        groupIds: {...state.groupIds}..remove(target.id),
        oshiIds: {...state.oshiIds}..remove(target.id),
      ),
    );
  }
}

/// 画面の幅をスマホ（360 x 640）にする
void usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

List<Override> overridesFor(
  FakeOshiRepository oshiRepo,
  FakeFollowRepository followRepo, {
  String? uid = 'u1',
}) => [
  currentUidProvider.overrideWithValue(uid),
  authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
  oshiRepositoryProvider.overrideWithValue(oshiRepo),
  followRepositoryProvider.overrideWithValue(followRepo),
  // ホームの「次の締切」（Step2）が Firestore や1分のタイマーを使わないように
  liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
  applicationRepositoryProvider.overrideWithValue(FakeApplicationRepository()),
  nowProvider.overrideWithValue(DateTime(2026, 11, 5, 12)),
];

Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  required FakeOshiRepository oshiRepo,
  required FakeFollowRepository followRepo,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overridesFor(oshiRepo, followRepo),
      // エラーの自動再試行を止める
      retry: (_, _) => null,
      child: MaterialApp(home: page),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// ListView の中の Scrollable（TextField の中の Scrollable と区別する）
Finder listScrollable() => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

VoidCallback? onPressedOf(WidgetTester tester, Finder finder) {
  final widget = tester.widget(finder);
  if (widget is ButtonStyleButton) return widget.onPressed;
  if (widget is IconButton) return widget.onPressed;
  throw StateError('ボタンではない: $widget');
}
