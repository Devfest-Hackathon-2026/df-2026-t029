// MemoryEditor（記録の保存の窓口）のテスト。偽のリポジトリを使い、Firebase に触れない。
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/features/common/photo_items.dart';
import 'package:oshiashi/models/live.dart';
import 'package:oshiashi/models/live_memory.dart';
import 'package:oshiashi/providers/memory_ticket_providers.dart';
import 'package:oshiashi/utils/photo_picker.dart';

import '../features/live_test_helpers.dart';
import '../features/memory_form_page_test.dart' show FakeMemoryRepository;
import '../features/photo_test_helpers.dart';
import '../features/public_memory_test_helpers.dart';

/// 公開の写しを書けない偽物
class _FailingPublics extends FakePublicMemoryRepository {
  bool failPublish = false;

  @override
  Future<void> publish(
    LiveMemory memory, {
    required String uid,
    required String displayName,
    required List<String> groupIds,
    required List<String> oshiIds,
  }) async {
    if (failPublish) throw Exception('publish failed');
    await super.publish(
      memory,
      uid: uid,
      displayName: displayName,
      groupIds: groupIds,
      oshiIds: oshiIds,
    );
  }
}

/// n 回目（0 始まり）のアップロードで失敗する偽物
class _FailingPhotos extends FakePhotoRepository {
  int? failAt;

  @override
  Future<String> upload(String dir, PickedPhoto photo) async {
    if (uploaded.length == failAt) throw Exception('upload failed');
    return super.upload(dir, photo);
  }
}

PickedPhoto _photo() =>
    PickedPhoto(bytes: fakeBytes, contentType: 'image/jpeg', extension: 'jpg');

final fakeBytes = Uint8List.fromList([1, 2, 3]);

final _start = DateTime.utc(2026, 12, 19, 9);

LiveMemory _memory({
  String? seat = 'A1',
  List<String> setlist = const ['曲1'],
  String? impression = '感想',
  List<String> images = const [],
  bool isPublic = false,
  bool publicSeat = false,
  DateTime? postedAt,
}) => LiveMemory(
  performanceId: 'p1',
  liveId: 'l1',
  liveTitle: 'ツアー',
  startAt: _start,
  venue: '会場',
  seat: seat,
  setlist: setlist,
  impression: impression,
  images: images,
  isPublic: isPublic,
  publicSeat: publicSeat,
  postedAt: postedAt,
);

void main() {
  late FakeMemoryRepository memories;
  late _FailingPhotos photos;
  late _FailingPublics publics;
  late FakeLiveRepository lives;

  MemoryEditor editor({String? uid = 'u1', String name = 'ハンドル'}) =>
      MemoryEditor(
        uid: uid,
        memories: memories,
        photos: photos,
        publics: publics,
        lives: lives,
        displayName: () async => name,
      );

  setUp(() {
    memories = FakeMemoryRepository();
    photos = _FailingPhotos();
    publics = _FailingPublics();
    lives = FakeLiveRepository(
      lives: [
        const Live(id: 'l1', title: 'ツアー', groupIds: ['g1'], oshiIds: ['o1']),
      ],
    );
  });

  group('saveFields', () {
    test('前後の空白を除き、空なら項目を消す。セトリの空行は捨てる', () async {
      final m = _memory();
      memories.store['p1'] = m;
      final r = await editor().saveFields(
        m,
        seat: '  B2  ',
        setlist: const [' 曲A ', '', '  ', '曲B'],
        impression: '  よかった \n',
      );
      expect(r.memory.seat, 'B2');
      expect(r.memory.setlist, ['曲A', '曲B']);
      expect(r.memory.impression, 'よかった');
      expect(memories.store['p1']!.seat, 'B2');
      expect(r.publicSynced, isTrue);

      final r2 = await editor().saveFields(
        r.memory,
        seat: '   ',
        setlist: const [],
        impression: null,
      );
      expect(r2.memory.seat, isNull);
      expect(r2.memory.setlist, isEmpty);
      expect(r2.memory.impression, isNull);
    });

    test('写真・公開の設定・複製した項目は変えない', () async {
      final m = _memory(images: const ['a.jpg'], isPublic: false);
      final r = await editor().saveFields(m, seat: 'X', setlist: const []);
      expect(r.memory.images, ['a.jpg']);
      expect(r.memory.liveTitle, 'ツアー');
      expect(r.memory.venue, '会場');
    });

    test('公開していなければ、写しは書かず消す（念のため）', () async {
      await editor().saveFields(_memory(), seat: 'X', setlist: const []);
      expect(publics.published, isEmpty);
      expect(publics.unpublished, ['u1_p1']);
    });

    test('公開中なら、写しを書き直す（出演者・ハンドルネームつき）', () async {
      final r = await editor().saveFields(
        _memory(isPublic: true),
        seat: 'X',
        setlist: const ['曲A'],
        impression: '新しい感想',
      );
      expect(r.publicSynced, isTrue);
      expect(publics.published, hasLength(1));
      expect(publics.published.single.impression, '新しい感想');
    });

    test('写しの失敗は publicSynced: false で、記録は保存済み', () async {
      publics.failPublish = true;
      final r = await editor().saveFields(
        _memory(isPublic: true),
        seat: 'X',
        setlist: const [],
      );
      expect(r.publicSynced, isFalse);
      expect(memories.calls, ['update']);
      expect(memories.store['p1']!.seat, 'X');
    });

    test('記録の保存の失敗は例外で、写しは書かない', () async {
      memories.error = Exception('x');
      await expectLater(
        editor().saveFields(
          _memory(isPublic: true),
          seat: 'X',
          setlist: const [],
        ),
        throwsA(isA<Exception>()),
      );
      expect(publics.published, isEmpty);
      expect(publics.unpublished, isEmpty);
    });

    test('未ログインなら StateError で、何も書かない', () async {
      await expectLater(
        editor(uid: null).saveFields(_memory(), setlist: const []),
        throwsA(isA<StateError>()),
      );
      expect(memories.calls, isEmpty);
    });
  });

  group('savePhotos', () {
    final newPhoto = NewPhoto(_photo());

    test('新しい写真を上げ、並びどおりのパスで保存し、外した写真を消す', () async {
      final m = _memory(images: const ['old1', 'old2']);
      memories.store['p1'] = m;
      final r = await editor().savePhotos(m, [
        const SavedPhoto('old1'),
        newPhoto,
      ]);
      expect(r.memory.images, ['old1', 'users/u1/memories/p1/fake_0.jpg']);
      expect(photos.uploaded, ['users/u1/memories/p1/fake_0.jpg']);
      expect(photos.deleted, ['old2']);
      expect(memories.store['p1']!.images, r.memory.images);
      expect(r.publicSynced, isTrue);
    });

    test('アップロードの失敗: 上げた分を消して例外。記録は保存しない', () async {
      final m = _memory();
      photos.failAt = 1;
      await expectLater(
        editor().savePhotos(m, [newPhoto, NewPhoto(_photo())]),
        throwsA(isA<Exception>()),
      );
      expect(photos.deleted, ['users/u1/memories/p1/fake_0.jpg']);
      expect(memories.calls, isEmpty);
    });

    test('記録の保存の失敗: 上げた分を消して例外', () async {
      final m = _memory(images: const ['old1']);
      memories.error = Exception('x');
      await expectLater(
        editor().savePhotos(m, [newPhoto]),
        throwsA(isA<Exception>()),
      );
      expect(photos.deleted, ['users/u1/memories/p1/fake_0.jpg']);
      expect(photos.deleted, isNot(contains('old1')));
    });

    test('写しを書けなかったら、外した写真は消さない', () async {
      publics.failPublish = true;
      final m = _memory(images: const ['old1'], isPublic: true);
      final r = await editor().savePhotos(m, [newPhoto]);
      expect(r.publicSynced, isFalse);
      expect(photos.deleted, isEmpty);
      expect(memories.store['p1']!.images, hasLength(1));
    });

    test('並べ替えだけ（アップロード無し・外した写真無し）', () async {
      final m = _memory(images: const ['a', 'b']);
      final r = await editor().savePhotos(m, const [
        SavedPhoto('b'),
        SavedPhoto('a'),
      ]);
      expect(r.memory.images, ['b', 'a']);
      expect(photos.uploaded, isEmpty);
      expect(photos.deleted, isEmpty);
    });
  });

  group('setPublic', () {
    test('公開にすると写しを書き、座席の公開も保存する', () async {
      final r = await editor().setPublic(
        _memory(),
        isPublic: true,
        publicSeat: true,
      );
      expect(r.memory.isPublic, isTrue);
      expect(r.memory.publicSeat, isTrue);
      expect(publics.published, hasLength(1));
      expect(r.publicSynced, isTrue);
    });

    test('非公開にすると写しを消す', () async {
      await editor().setPublic(
        _memory(isPublic: true),
        isPublic: false,
        publicSeat: false,
      );
      expect(publics.unpublished, ['u1_p1']);
    });

    test('記録の保存の失敗は例外', () async {
      memories.error = Exception('x');
      await expectLater(
        editor().setPublic(_memory(), isPublic: true, publicSeat: false),
        throwsA(isA<Exception>()),
      );
      expect(publics.published, isEmpty);
    });
  });

  group('markPosted', () {
    test('postedAt が無ければ書く', () async {
      await editor().markPosted(_memory());
      expect(memories.postedIds, ['p1']);
    });

    test('すでにあれば呼ばない', () async {
      await editor().markPosted(_memory(postedAt: _start));
      expect(memories.postedIds, isEmpty);
      expect(memories.calls, isEmpty);
    });

    test('失敗しても例外を投げない', () async {
      memories.error = Exception('x');
      await editor().markPosted(_memory());
      expect(memories.calls, ['markPosted']);
    });

    test('未ログインなら何もしない', () async {
      await editor(uid: null).markPosted(_memory());
      expect(memories.calls, isEmpty);
    });

    test('updatedAt を動かす update は呼ばない（markPosted だけ）', () async {
      await editor().markPosted(_memory());
      expect(memories.calls, ['markPosted']);
    });
  });
}
