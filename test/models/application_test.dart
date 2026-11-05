import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/application.dart';

void main() {
  group('ApplicationStatus', () {
    test('code は DB 設計案 4章の値、label は日本語', () {
      expect(
        {for (final s in ApplicationStatus.values) s.code: s.label},
        {'applied': '申込済', 'won': '当選', 'lost': '落選', 'paid': '入金済'},
      );
      expect(ApplicationStatus.notAppliedLabel, '未申込');
    });

    test('fromCode: 既知の値は対応する状態', () {
      for (final s in ApplicationStatus.values) {
        expect(ApplicationStatus.fromCode(s.code), s);
      }
    });

    test('fromCode: 不明な値・null・型違い・大文字は null', () {
      for (final v in [null, '', 'unknown', 'APPLIED', 'won ', 1, true]) {
        expect(ApplicationStatus.fromCode(v), isNull, reason: '$v');
      }
    });
  });

  group('Application.fromFirestore', () {
    final ts = Timestamp.fromDate(DateTime.utc(2026, 11, 5, 3));

    test('正しいドキュメントを読める（ID は受付 ID）', () {
      final a = Application.fromFirestore('r1', {
        'liveId': 'l1',
        'status': 'won',
        'updatedAt': ts,
      });
      expect(
        a,
        Application(
          receptionId: 'r1',
          liveId: 'l1',
          status: ApplicationStatus.won,
          updatedAt: ts.toDate(),
        ),
      );
    });

    test('updatedAt が無い・null（サーバー時刻の確定前）・型違いでも読める', () {
      for (final data in <Map<String, dynamic>>[
        {'liveId': 'l1', 'status': 'paid'},
        {'liveId': 'l1', 'status': 'paid', 'updatedAt': null},
        {'liveId': 'l1', 'status': 'paid', 'updatedAt': 'yesterday'},
      ]) {
        final a = Application.fromFirestore('r1', data);
        expect(a, isNotNull, reason: '$data');
        expect(a!.status, ApplicationStatus.paid);
        expect(a.updatedAt, isNull);
      }
    });

    test('data が null（ドキュメントなし）なら null', () {
      expect(Application.fromFirestore('r1', null), isNull);
    });

    test('status が欠けている・不明・型違いなら null（例外を投げない）', () {
      for (final data in <Map<String, dynamic>>[
        {'liveId': 'l1'},
        {'liveId': 'l1', 'status': 'pending'},
        {'liveId': 'l1', 'status': 3},
        {'liveId': 'l1', 'status': null},
      ]) {
        expect(Application.fromFirestore('r1', data), isNull, reason: '$data');
      }
    });

    test('liveId が欠けている・文字列でないなら null', () {
      for (final data in <Map<String, dynamic>>[
        {'status': 'applied'},
        {'status': 'applied', 'liveId': null},
        {'status': 'applied', 'liveId': 12},
        {
          'status': 'applied',
          'liveId': ['l1'],
        },
      ]) {
        expect(Application.fromFirestore('r1', data), isNull, reason: '$data');
      }
    });

    test('知らない項目があっても読める', () {
      final a = Application.fromFirestore('r1', {
        'liveId': 'l1',
        'status': 'lost',
        'extra': {'x': 1},
      });
      expect(a?.status, ApplicationStatus.lost);
    });
  });

  group('Application の等価性', () {
    const a = Application(
      receptionId: 'r1',
      liveId: 'l1',
      status: ApplicationStatus.applied,
    );

    test('同じ値なら等しく、hashCode も同じ', () {
      const b = Application(
        receptionId: 'r1',
        liveId: 'l1',
        status: ApplicationStatus.applied,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('どれか1項目が違えば等しくない', () {
      for (final other in [
        const Application(
          receptionId: 'r2',
          liveId: 'l1',
          status: ApplicationStatus.applied,
        ),
        const Application(
          receptionId: 'r1',
          liveId: 'l2',
          status: ApplicationStatus.applied,
        ),
        const Application(
          receptionId: 'r1',
          liveId: 'l1',
          status: ApplicationStatus.won,
        ),
        Application(
          receptionId: 'r1',
          liveId: 'l1',
          status: ApplicationStatus.applied,
          updatedAt: DateTime.utc(2026),
        ),
      ]) {
        expect(a == other, isFalse, reason: '$other');
      }
    });
  });
}
