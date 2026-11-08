import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/reception.dart';
import 'package:oshiashi/repositories/live_repository.dart';

// デモ用データ（tools/seed/demo_data.mjs）が、アプリの fromFirestore で全件読めるか。
// test/fixtures/demo_data.json は次のコマンドで作り直す（基準日は固定）:
//   node -e "import('./tools/seed/demo_data.mjs').then(m=>process.stdout.write(
//     JSON.stringify(m.buildDemoData('2026-11-05'),null,1)))" > test/fixtures/demo_data.json
// 日時は JSON では ISO 文字列になるので、*At・paymentDeadline を Timestamp に戻す。
dynamic revive(String key, dynamic v) {
  if (v is String &&
      (key.endsWith('At') || key == 'paymentDeadline') &&
      DateTime.tryParse(v) != null) {
    return Timestamp.fromDate(DateTime.parse(v));
  }
  if (v is Map) {
    return <String, dynamic>{
      for (final e in v.entries)
        e.key as String: revive(e.key as String, e.value),
    };
  }
  if (v is List) return [for (final x in v) revive(key, x)];
  return v;
}

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreLiveRepository repo;
  late Map<String, dynamic> data;

  setUp(() async {
    data = revive(
      '',
      jsonDecode(File('test/fixtures/demo_data.json').readAsStringSync()),
    ) as Map<String, dynamic>;
    db = FakeFirebaseFirestore();
    for (final c in data.entries) {
      for (final d in (c.value as Map<String, dynamic>).entries) {
        await db
            .collection(c.key)
            .doc(d.key)
            .set(d.value as Map<String, dynamic>);
      }
    }
    repo = FirestoreLiveRepository(db);
  });

  test('ライブ15・公演29・受付23が、全件読める', () async {
    final ids = (data['lives'] as Map).keys.cast<String>().toSet();
    final lives = await repo.watchLivesByIds(ids).first;
    final perfs = await repo.watchPerformancesOfLives(ids).first;
    final recs = await repo.watchReceptionsOfLives(ids).first;
    expect(lives.length, 15);
    expect(perfs.length, 29);
    expect(recs.length, 23);
    expect(
      lives.every(
        (l) =>
            l.title.isNotEmpty && l.groupIds.isNotEmpty || l.oshiIds.isNotEmpty,
      ),
      isTrue,
    );
    expect(perfs.every((p) => p.liveId != null && p.venue.isNotEmpty), isTrue);
    expect(recs.every((r) => r.liveId != null), isTrue);
  });

  test('受付の中身: アプグレは当選者のみ、料金・期限が読める', () async {
    final ids = (data['lives'] as Map).keys.cast<String>().toSet();
    final recs = await repo.watchReceptionsOfLives(ids).first;
    final upg = recs.firstWhere((r) => r.id == 'demo-rec-stella-tour-upgrade');
    expect(upg.winnersOnly, isTrue);
    expect(upg.type, ReceptionType.upgrade);
    expect(upg.prices, isNotEmpty);
    expect(upg.paymentDeadline, isNotNull);
    expect(recs.where((r) => r.winnersOnly).length, 1);
  });
}
