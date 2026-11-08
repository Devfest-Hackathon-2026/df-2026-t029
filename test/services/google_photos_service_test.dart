// GooglePhotosService のテスト。http.Client は MockClient、トークンは tokenForTest、
// 時刻は clock で固定する。本物の Google・ネットワークは呼ばない。値はすべて架空。
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oshiashi/services/google_photos_service.dart';

import '../features/auth_test_helpers.dart';

const _token = 'fake-token-abc';
const _api = 'https://photospicker.googleapis.com/v1';

final _t0 = DateTime.utc(2026, 11, 8, 12);

Matcher _throwsKind(GooglePhotosFailure k) =>
    throwsA(isA<GooglePhotosException>().having((e) => e.kind, 'kind', k));

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _sessionJson({
  String id = 's1',
  bool set = false,
  Object? polling,
}) => {
  'id': id,
  'pickerUri': 'https://photos.example.com/picker/$id',
  'pollingConfig': ?polling,
  'mediaItemsSet': set,
};

Map<String, dynamic> _image(String id, {String mime = 'image/jpeg'}) => {
  'id': id,
  'mediaFile': {'baseUrl': 'https://img.example.com/$id', 'mimeType': mime},
};

void main() {
  late List<http.Request> requests;
  late DateTime now;

  GooglePhotosService make(
    Future<http.Response> Function(http.Request r) handler, {
    Future<String> Function()? tokenForTest,
  }) {
    requests = [];
    return GooglePhotosService(
      FakeFirebaseAuth(),
      client: MockClient((r) {
        requests.add(r);
        return handler(r);
      }),
      tokenForTest: tokenForTest ?? () async => _token,
      clock: () => now,
    );
  }

  setUp(() => now = _t0);

  group('認可（tokenForTest）', () {
    test('authorize のあと hasToken が true。ポップアップは使わない', () async {
      final s = make((_) async => _json({}));
      expect(s.hasToken, isFalse);
      await s.authorize();
      expect(s.hasToken, isTrue);
    });

    test('トークンは50分で切れる（49分59秒はあり、50分で無し）', () async {
      var calls = 0;
      final s = make(
        (_) async => _json({}),
        tokenForTest: () async {
          calls++;
          return _token;
        },
      );
      await s.authorize();
      now = _t0.add(const Duration(minutes: 49, seconds: 59));
      expect(s.hasToken, isTrue);
      await s.authorize();
      expect(calls, 1, reason: '有効なうちは取り直さない');
      now = _t0.add(const Duration(minutes: 50));
      expect(s.hasToken, isFalse);
      await s.authorize();
      expect(calls, 2);
    });

    test('tokenForTest が失敗したら noToken。例外の中身を含めない', () async {
      final s = make(
        (_) async => _json({}),
        tokenForTest: () async => throw Exception('secret-detail'),
      );
      await expectLater(
        s.authorize(),
        _throwsKind(GooglePhotosFailure.noToken),
      );
    });

    test('ログインしていなければ noToken', () async {
      final s = GooglePhotosService(FakeFirebaseAuth(), clock: () => now);
      await expectLater(
        s.authorize(),
        _throwsKind(GooglePhotosFailure.noToken),
      );
    });

    test(
      'google.com がある人: reauthenticateWithPopup・読み取りのスコープ・login_hint',
      () async {
        final user =
            FakeUser(email: 'me@example.com', providerIds: ['google.com'])
              ..onReauth = (_) async =>
                  FakeUserCredential(credential: FakeCredential(_token));
        final s = GooglePhotosService(
          FakeFirebaseAuth(user),
          client: MockClient((_) async => _json({})),
          clock: () => now,
        );
        await s.authorize();
        expect(s.hasToken, isTrue);
        expect(user.linkCalls, isEmpty);
        final p = user.reauthCalls.single as GoogleAuthProvider;
        expect(
          p.scopes,
          contains(
            'https://www.googleapis.com/auth/photospicker.mediaitems.readonly',
          ),
        );
        expect(p.parameters, {'login_hint': 'me@example.com'});
      },
    );

    test('google.com が無い人: linkWithPopup', () async {
      final user = FakeUser(email: 'me@example.com')
        ..onLink = (_) async =>
            FakeUserCredential(credential: FakeCredential(_token));
      final s = GooglePhotosService(FakeFirebaseAuth(user), clock: () => now);
      await s.authorize();
      expect(user.linkCalls, hasLength(1));
      expect(user.reauthCalls, isEmpty);
    });

    test('provider-already-linked は再認証に切り替える', () async {
      final user = FakeUser(email: 'me@example.com')
        ..onLink = ((_) async => throw authError('provider-already-linked'))
        ..onReauth = (_) async =>
            FakeUserCredential(credential: FakeCredential(_token));
      final s = GooglePhotosService(FakeFirebaseAuth(user), clock: () => now);
      await s.authorize();
      expect(user.reauthCalls, hasLength(1));
      expect(s.hasToken, isTrue);
    });

    test('トークンが取れなければ noToken', () async {
      final user =
          FakeUser(email: 'me@example.com', providerIds: ['google.com'])
            ..onReauth = (_) async =>
                FakeUserCredential(credential: FakeCredential(null));
      final s = GooglePhotosService(FakeFirebaseAuth(user), clock: () => now);
      await expectLater(
        s.authorize(),
        _throwsKind(GooglePhotosFailure.noToken),
      );
    });

    group('Firebase のエラーコード → 種類', () {
      final cases = {
        'popup-closed-by-user': GooglePhotosFailure.cancelled,
        'cancelled-popup-request': GooglePhotosFailure.cancelled,
        'popup-blocked': GooglePhotosFailure.popupBlocked,
        'network-request-failed': GooglePhotosFailure.network,
        'something-else': GooglePhotosFailure.other,
      };
      for (final e in cases.entries) {
        test(e.key, () async {
          final user = FakeUser(
            email: 'me@example.com',
            providerIds: ['google.com'],
          )..onReauth = ((_) async => throw authError(e.key));
          final s = GooglePhotosService(
            FakeFirebaseAuth(user),
            clock: () => now,
          );
          await expectLater(s.authorize(), _throwsKind(e.value));
        });
      }

      test('user-mismatch は accountMismatch。メールを持つ', () async {
        final user = FakeUser(
          email: 'me@example.com',
          providerIds: ['google.com'],
        )..onReauth = ((_) async => throw authError('user-mismatch'));
        final s = GooglePhotosService(FakeFirebaseAuth(user), clock: () => now);
        await expectLater(
          s.authorize(),
          throwsA(
            isA<GooglePhotosException>()
                .having(
                  (e) => e.kind,
                  'kind',
                  GooglePhotosFailure.accountMismatch,
                )
                .having((e) => e.email, 'email', 'me@example.com'),
          ),
        );
      });

      for (final code in [
        'credential-already-in-use',
        'email-already-in-use',
      ]) {
        test('link で $code は accountInUse', () async {
          final user = FakeUser(email: 'me@example.com')
            ..onLink = ((_) async => throw authError(code));
          final s = GooglePhotosService(
            FakeFirebaseAuth(user),
            clock: () => now,
          );
          await expectLater(
            s.authorize(),
            _throwsKind(GooglePhotosFailure.accountInUse),
          );
        });
      }
    });
  });

  group('createSession', () {
    test('URL・Authorization・本文（maxItemCount は文字列）', () async {
      final s = make((_) async => _json(_sessionJson()));
      await s.authorize();
      await s.createSession(maxItemCount: 30);
      final r = requests.single;
      expect(r.method, 'POST');
      expect(r.url.toString(), '$_api/sessions');
      expect(r.headers['Authorization'], 'Bearer $_token');
      expect(jsonDecode(r.body), {
        'pickingConfig': {'maxItemCount': '30'},
      });
    });

    test('PickerSession への変換: "5s" と timeoutIn、timeoutAt は取得時刻から', () async {
      final s = make(
        (_) async => _json(
          _sessionJson(polling: {'pollInterval': '3s', 'timeoutIn': '1800s'}),
        ),
      );
      await s.authorize();
      final session = await s.createSession();
      expect(session.id, 's1');
      expect(
        session.pickerUri,
        Uri.parse('https://photos.example.com/picker/s1'),
      );
      expect(session.pollInterval, const Duration(seconds: 3));
      expect(session.timeoutAt, _t0.add(const Duration(minutes: 30)));
      expect(session.mediaItemsSet, isFalse);
    });

    test('pollInterval が無ければ 5 秒', () async {
      final s = make((_) async => _json(_sessionJson()));
      await s.authorize();
      final session = await s.createSession();
      expect(session.pollInterval, const Duration(seconds: 5));
    });

    test('小数秒（"1.5s"）も読める', () async {
      final s = make(
        (_) async => _json(_sessionJson(polling: {'pollInterval': '1.5s'})),
      );
      await s.authorize();
      expect(
        (await s.createSession()).pollInterval,
        const Duration(milliseconds: 1500),
      );
    });

    test('id・pickerUri が無い応答は other', () async {
      final s = make((_) async => _json({'foo': 1}));
      await s.authorize();
      await expectLater(
        s.createSession(),
        _throwsKind(GooglePhotosFailure.other),
      );
    });

    test('本文が JSON でなければ other', () async {
      final s = make((_) async => http.Response('not json', 200));
      await s.authorize();
      await expectLater(
        s.createSession(),
        _throwsKind(GooglePhotosFailure.other),
      );
    });

    test('authorize 前は noToken（通信しない）', () async {
      final s = make((_) async => _json(_sessionJson()));
      await expectLater(
        s.createSession(),
        _throwsKind(GooglePhotosFailure.noToken),
      );
      expect(requests, isEmpty);
    });
  });

  group('getSession', () {
    test('GET で mediaItemsSet を読む', () async {
      final s = make((_) async => _json(_sessionJson(set: true)));
      await s.authorize();
      final session = await s.getSession('s1');
      expect(requests.single.method, 'GET');
      expect(requests.single.url.toString(), '$_api/sessions/s1');
      expect(requests.single.headers['Authorization'], 'Bearer $_token');
      expect(session.mediaItemsSet, isTrue);
    });
  });

  group('listPickedItems', () {
    test('複数ページを辿る（pageToken・sessionId）', () async {
      final s = make((r) async {
        if (r.url.queryParameters['pageToken'] == 'p2') {
          return _json({
            'mediaItems': [_image('b')],
          });
        }
        return _json({
          'mediaItems': [_image('a')],
          'nextPageToken': 'p2',
        });
      });
      await s.authorize();
      final items = await s.listPickedItems('s1');
      expect(items.map((e) => e.id), ['a', 'b']);
      expect(requests, hasLength(2));
      expect(requests.first.url.path, '/v1/mediaItems');
      expect(requests.first.url.queryParameters['sessionId'], 's1');
      expect(requests.last.url.queryParameters['pageToken'], 'p2');
    });

    test('動画（mimeType が image/ でない・type が VIDEO）を除く', () async {
      final s = make(
        (_) async => _json({
          'mediaItems': [
            _image('a'),
            _image('v', mime: 'video/mp4'),
            {
              'id': 'v2',
              'type': 'VIDEO',
              'mediaFile': {
                'baseUrl': 'https://img.example.com/v2',
                'mimeType': 'image/jpeg',
              },
            },
            _image('b', mime: 'image/png'),
          ],
        }),
      );
      await s.authorize();
      expect((await s.listPickedItems('s1')).map((e) => e.id), ['a', 'b']);
    });

    test('30枚で打ち切る', () async {
      final s = make(
        (_) async => _json({
          'mediaItems': [for (var i = 0; i < 45; i++) _image('i$i')],
        }),
      );
      await s.authorize();
      expect(await s.listPickedItems('s1'), hasLength(30));
    });

    test('入れ子の2通りの形（mediaFile.baseUrl と baseUrl）・createTime・幅・高さ', () async {
      final s = make(
        (_) async => _json({
          'mediaItems': [
            {
              'id': 'a',
              'createTime': '2026-12-19T09:00:00Z',
              'mediaFile': {
                'baseUrl': 'https://img.example.com/a',
                'mimeType': 'image/jpeg',
                'mediaFileMetadata': {'width': 4000, 'height': '3000'},
              },
            },
            {
              'id': 'b',
              'baseUrl': 'https://img.example.com/b',
              'mimeType': 'image/webp',
            },
          ],
        }),
      );
      await s.authorize();
      final items = await s.listPickedItems('s1');
      expect(items[0].baseUrl, 'https://img.example.com/a');
      expect(items[0].createTime, DateTime.utc(2026, 12, 19, 9));
      expect(items[0].width, 4000);
      expect(items[0].height, 3000);
      expect(items[1].baseUrl, 'https://img.example.com/b');
      expect(items[1].mimeType, 'image/webp');
      expect(items[1].createTime, isNull);
    });

    test('読めない要素は捨て、mediaItems が無ければ空', () async {
      final s = make(
        (_) async => _json({
          'mediaItems': [
            'x',
            1,
            {'id': 'z'},
            _image('a'),
          ],
        }),
      );
      await s.authorize();
      expect((await s.listPickedItems('s1')).map((e) => e.id), ['a']);
      final s2 = make((_) async => _json({}));
      await s2.authorize();
      expect(await s2.listPickedItems('s1'), isEmpty);
    });

    test('nextPageToken が続いても、ページ数の上限で止まる', () async {
      final s = make(
        (_) async =>
            _json({'mediaItems': <Object>[], 'nextPageToken': 'again'}),
      );
      await s.authorize();
      await s.listPickedItems('s1');
      expect(requests.length, lessThanOrEqualTo(10));
    });
  });

  group('fetchImage', () {
    const item = PickedItem(
      id: 'a',
      baseUrl: 'https://img.example.com/a',
      mimeType: 'image/jpeg',
    );

    test('=w768-h768 を付け、Authorization つきで取る', () async {
      final s = make((_) async => http.Response.bytes([1, 2, 3], 200));
      await s.authorize();
      final bytes = await s.fetchImage(item, maxSide: 768);
      expect(bytes, Uint8List.fromList([1, 2, 3]));
      expect(
        requests.single.url.toString(),
        'https://img.example.com/a=w768-h768',
      );
      expect(requests.single.headers['Authorization'], 'Bearer $_token');
    });

    test('200 以外は例外', () async {
      final s = make((_) async => http.Response('x', 500));
      await s.authorize();
      await expectLater(
        s.fetchImage(item, maxSide: 768),
        _throwsKind(GooglePhotosFailure.other),
      );
    });
  });

  group('エラーの種類', () {
    Future<void> expectStatus(int status, GooglePhotosFailure kind) async {
      final s = make((_) async => http.Response('body-with-secret', status));
      await s.authorize();
      await expectLater(s.createSession(), _throwsKind(kind));
    }

    test(
      '403 → apiUnavailable',
      () => expectStatus(403, GooglePhotosFailure.apiUnavailable),
    );
    test(
      '404 → apiUnavailable',
      () => expectStatus(404, GooglePhotosFailure.apiUnavailable),
    );
    test('500 → other', () => expectStatus(500, GooglePhotosFailure.other));
    test('400 → other', () => expectStatus(400, GooglePhotosFailure.other));

    test('401 → noToken で、トークンを捨てる（hasToken が false）', () async {
      final s = make((_) async => http.Response('', 401));
      await s.authorize();
      expect(s.hasToken, isTrue);
      await expectLater(
        s.createSession(),
        _throwsKind(GooglePhotosFailure.noToken),
      );
      expect(s.hasToken, isFalse);
    });

    test('通信の失敗 → network', () async {
      final s = make(
        (_) async => throw http.ClientException('boom https://x.example.com'),
      );
      await s.authorize();
      await expectLater(
        s.createSession(),
        _throwsKind(GooglePhotosFailure.network),
      );
    });

    test('例外の toString にトークン・メール・URL・応答の本文が入らない', () async {
      final s = make((_) async => http.Response('body-with-secret', 403));
      await s.authorize();
      try {
        await s.createSession();
        fail('投げるはず');
      } on GooglePhotosException catch (e) {
        final str = e.toString();
        expect(str, isNot(contains(_token)));
        expect(str, isNot(contains('http')));
        expect(str, isNot(contains('secret')));
      }
      const withMail = GooglePhotosException(
        GooglePhotosFailure.accountMismatch,
        email: 'me@example.com',
      );
      expect(withMail.toString(), isNot(contains('me@example.com')));
    });

    test('通信の失敗の例外にも、元の例外の中身（URL）が入らない', () async {
      final s = make(
        (_) async =>
            throw http.ClientException('boom https://x.example.com/$_token'),
      );
      await s.authorize();
      try {
        await s.createSession();
        fail('投げるはず');
      } on GooglePhotosException catch (e) {
        expect(e.toString(), isNot(contains('x.example.com')));
        expect(e.toString(), isNot(contains(_token)));
      }
    });
  });

  group('deleteSession', () {
    test('DELETE を送る', () async {
      final s = make((_) async => http.Response('', 200));
      await s.authorize();
      await s.deleteSession('s1');
      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.toString(), '$_api/sessions/s1');
    });

    test('失敗（500・通信の失敗）しても投げない', () async {
      final s = make((_) async => http.Response('', 500));
      await s.authorize();
      await s.deleteSession('s1');
      final s2 = make((_) async => throw http.ClientException('x'));
      await s2.authorize();
      await s2.deleteSession('s1');
    });

    test('トークンが無くても投げない', () async {
      final s = make((_) async => http.Response('', 200));
      await s.deleteSession('s1');
      expect(requests, isEmpty);
    });
  });
}
