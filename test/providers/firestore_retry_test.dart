import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/providers/oshi_providers.dart';
import 'package:oshiashi/repositories/auth_repository.dart';

FirebaseException _fe(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

class _FakeUser implements User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth implements FirebaseAuth {
  _FakeAuth(this.currentUser);

  @override
  User? currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('firestoreRetry', () {
    test('permission-denied は回数に関係なく再試行しない', () {
      for (final count in [0, 1, 5, 9, 10, 100]) {
        expect(
          firestoreRetry(count, _fe('permission-denied')),
          isNull,
          reason: '$count',
        );
      }
    });

    test('ほかの code の FirebaseException は defaultRetry と同じ', () {
      for (final code in ['unavailable', 'deadline-exceeded', 'internal']) {
        for (var count = 0; count <= 11; count++) {
          final error = _fe(code);
          expect(
            firestoreRetry(count, error),
            ProviderContainer.defaultRetry(count, error),
            reason: '$code / $count',
          );
        }
      }
    });

    test('0回目は再試行し、10回目は再試行しない（既定の上限）', () {
      expect(firestoreRetry(0, _fe('unavailable')), isNotNull);
      expect(firestoreRetry(10, _fe('unavailable')), isNull);
      expect(firestoreRetry(0, Exception('x')), isNotNull);
      expect(firestoreRetry(10, Exception('x')), isNull);
    });

    test('FirebaseException 以外のエラーも defaultRetry と同じ', () {
      for (final error in [Exception('x'), StateError('y'), 'string']) {
        for (var count = 0; count <= 11; count++) {
          expect(
            firestoreRetry(count, error),
            ProviderContainer.defaultRetry(count, error),
          );
        }
      }
    });

    test('code の大文字・小文字は区別する（Firestore の code は小文字）', () {
      expect(firestoreRetry(0, _fe('PERMISSION-DENIED')), isNotNull);
    });
  });

  group('currentUidProvider（回帰: 認証の読み込み中に一瞬 null にならない）', () {
    test('認証のストリームが値を流すまでは currentUser の uid、流したらその値', () async {
      final auth = StreamController<User?>();
      addTearDown(auth.close);
      final c = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            AuthRepository(_FakeAuth(_FakeUser('u1'))),
          ),
          authStateProvider.overrideWith((ref) => auth.stream),
        ],
      );
      addTearDown(c.dispose);
      final values = <String?>[];
      c.listen(
        currentUidProvider,
        (_, next) => values.add(next),
        fireImmediately: true,
      );

      expect(c.read(currentUidProvider), 'u1');

      auth.add(_FakeUser('u2'));
      await pumpEventQueue();
      expect(c.read(currentUidProvider), 'u2');

      auth.add(null);
      await pumpEventQueue();
      expect(c.read(currentUidProvider), isNull);
      expect(values, ['u1', 'u2', null]);
    });

    test('未ログインで起動したら、読み込み中も null', () {
      final c = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            AuthRepository(_FakeAuth(null)),
          ),
          authStateProvider.overrideWith((ref) => const Stream<User?>.empty()),
        ],
      );
      addTearDown(c.dispose);
      c.listen(currentUidProvider, (_, _) {});
      expect(c.read(currentUidProvider), isNull);
    });
  });
}
