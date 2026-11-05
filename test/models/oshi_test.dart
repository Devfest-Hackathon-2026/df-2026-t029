import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/models/oshi.dart';

OshiRequest _req({
  OshiKind kind = OshiKind.person,
  String name = 'さくら',
  OshiGenre genre = OshiGenre.idol,
  List<String> aliases = const [],
  String agency = '',
  String officialUrl = '',
  String officialX = '',
  List<String> groupIds = const [],
}) {
  return OshiRequest(
    kind: kind,
    name: name,
    genre: genre,
    aliases: aliases,
    agency: agency,
    officialUrl: officialUrl,
    officialX: officialX,
    groupIds: groupIds,
  );
}

Set<OshiRequestField> _errorFields(OshiRequest r) => r.validate().keys.toSet();

void main() {
  group('OshiGenre', () {
    test('8つの英字コードを持つ', () {
      expect(OshiGenre.values.map((g) => g.code).toList(), [
        'idol',
        'voice_actor',
        'artist',
        'anime_game',
        'actor',
        'vtuber',
        'sports',
        'other',
      ]);
    });

    test('未知・欠け・型違いの値は「その他」', () {
      expect(OshiGenre.fromCode('voice_actor'), OshiGenre.voiceActor);
      expect(OshiGenre.fromCode('unknown'), OshiGenre.other);
      expect(OshiGenre.fromCode(null), OshiGenre.other);
      expect(OshiGenre.fromCode(1), OshiGenre.other);
      expect(OshiGenre.fromCode('IDOL'), OshiGenre.other);
    });
  });

  group('OshiSummary.fromFirestore', () {
    test('すべての項目がそろっていれば読み込める', () {
      final o = OshiSummary.fromFirestore(OshiKind.person, 'p1', {
        'name': 'さくら',
        'aliases': ['サクラ', 'sakura'],
        'genre': 'idol',
        'status': 'approved',
        'groupIds': ['g1'],
        'agency': '事務所',
        'officialUrl': 'https://example.com',
        'officialX': 'sakura',
        'createdBy': 'uid1',
        'createdAt': Timestamp.now(),
      })!;
      expect(o.id, 'p1');
      expect(o.kind, OshiKind.person);
      expect(o.name, 'さくら');
      expect(o.aliases, ['サクラ', 'sakura']);
      expect(o.genre, OshiGenre.idol);
      expect(o.status, OshiStatus.approved);
      expect(o.groupIds, ['g1']);
      expect(o.agency, '事務所');
      expect(o.officialUrl, 'https://example.com');
      expect(o.officialX, 'sakura');
      expect(o.createdBy, 'uid1');
    });

    test('データが null なら null', () {
      expect(OshiSummary.fromFirestore(OshiKind.group, 'g', null), isNull);
    });

    test('name が欠けている・空白だけ・型違いなら null', () {
      for (final name in [
        null,
        '',
        '　 ',
        123,
        ['さくら'],
      ]) {
        expect(
          OshiSummary.fromFirestore(OshiKind.group, 'g', {
            'name': name,
            'status': 'approved',
          }),
          isNull,
          reason: '$name',
        );
      }
    });

    test('status が欠けている・未知なら null', () {
      for (final status in [null, 'rejected', 'APPROVED', 1]) {
        expect(
          OshiSummary.fromFirestore(OshiKind.group, 'g', {
            'name': 'さくら',
            'status': status,
          }),
          isNull,
          reason: '$status',
        );
      }
    });

    test('任意項目が欠けていても既定値で読み込める', () {
      final o = OshiSummary.fromFirestore(OshiKind.person, 'p', {
        'name': 'さくら',
        'status': 'pending',
      })!;
      expect(o.aliases, isEmpty);
      expect(o.groupIds, isEmpty);
      expect(o.genre, OshiGenre.other);
      expect(o.agency, isNull);
      expect(o.officialUrl, isNull);
      expect(o.officialX, isNull);
      expect(o.createdBy, '');
      expect(o.isPending, isTrue);
    });

    test('型が違う項目は既定値にし、配列からは文字列以外と空文字を除く', () {
      final o = OshiSummary.fromFirestore(OshiKind.person, 'p', {
        'name': ' さくら ',
        'status': 'approved',
        'aliases': ['a', 1, null, '', '  ', ' b '],
        'groupIds': 'g1',
        'genre': 5,
        'agency': 1,
        'officialUrl': '   ',
        'officialX': true,
        'createdBy': 1,
      })!;
      expect(o.name, 'さくら');
      expect(o.aliases, ['a', 'b']);
      expect(o.groupIds, isEmpty);
      expect(o.genre, OshiGenre.other);
      expect(o.agency, isNull);
      expect(o.officialUrl, isNull);
      expect(o.officialX, isNull);
      expect(o.createdBy, '');
    });

    test('グループでは groupIds を常に空にする', () {
      final o = OshiSummary.fromFirestore(OshiKind.group, 'g', {
        'name': 'さくら',
        'status': 'approved',
        'groupIds': ['g0'],
      })!;
      expect(o.groupIds, isEmpty);
    });

    test('key は種別と ID で決まり、== は中身まで比べる', () {
      const a = OshiSummary(
        id: 'x',
        kind: OshiKind.group,
        name: 'A',
        genre: OshiGenre.idol,
        status: OshiStatus.pending,
      );
      const approved = OshiSummary(
        id: 'x',
        kind: OshiKind.group,
        name: 'A',
        genre: OshiGenre.idol,
        status: OshiStatus.approved,
      );
      const person = OshiSummary(
        id: 'x',
        kind: OshiKind.person,
        name: 'A',
        genre: OshiGenre.idol,
        status: OshiStatus.pending,
      );
      // 承認で status が変わると別の値（画面が再描画される）
      expect(a.key, 'group/x');
      expect(person.key, 'person/x');
      expect(a.key, approved.key);
      expect(a == approved, isFalse);
      expect(a.key == person.key, isFalse);
      expect(a == person, isFalse);
    });

    test('中身が同じなら == と hashCode が一致する（リストは要素で比べる）', () {
      final a = OshiSummary.fromFirestore(OshiKind.person, 'p', {
        'name': 'さくら',
        'status': 'approved',
        'aliases': ['a', 'b'],
        'groupIds': ['g1'],
      });
      final b = OshiSummary.fromFirestore(OshiKind.person, 'p', {
        'name': 'さくら',
        'status': 'approved',
        'aliases': ['a', 'b'],
        'groupIds': ['g1'],
      });
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('OshiRequest.validate: 名前', () {
    test('普通の名前なら OK', () {
      expect(_req().validate(), isEmpty);
    });

    test('空・空白だけはエラー', () {
      expect(_errorFields(_req(name: '')), {OshiRequestField.name});
      expect(_errorFields(_req(name: ' 　 ')), {OshiRequestField.name});
    });

    test('正規化して空になる（記号だけ）名前はエラー', () {
      expect(_errorFields(_req(name: '・・・')), {OshiRequestField.name});
      expect(_errorFields(_req(name: '-_.')), {OshiRequestField.name});
    });

    test('1文字は OK', () {
      expect(_req(name: 'あ').validate(), isEmpty);
    });

    test('50文字は OK、51文字はエラー', () {
      expect(_req(name: 'あ' * 50).validate(), isEmpty);
      expect(_errorFields(_req(name: 'あ' * 51)), {OshiRequestField.name});
    });

    test('前後の空白は文字数に数えない', () {
      expect(_req(name: '  ${'あ' * 50}  ').validate(), isEmpty);
    });

    test('文字数は UTF-16 単位（ルールの size() と同じ。絵文字は2文字と数える）', () {
      expect(_req(name: '🍓' * 25).validate(), isEmpty);
      expect(_errorFields(_req(name: '🍓' * 26)), {OshiRequestField.name});
      expect(_req(name: '${'あ' * 48}🍓').validate(), isEmpty);
      expect(_errorFields(_req(name: '${'あ' * 49}🍓')), {
        OshiRequestField.name,
      });
    });
  });

  group('OshiRequest.validate: 別名', () {
    test('空欄の別名は無視する', () {
      expect(_req(aliases: ['', '  ']).validate(), isEmpty);
      expect(_req(aliases: ['', '  ']).cleanedAliases, isEmpty);
    });

    test('10個は OK、11個はエラー', () {
      final ten = [for (var i = 0; i < 10; i++) '別名$i'];
      expect(_req(aliases: ten).validate(), isEmpty);
      expect(_errorFields(_req(aliases: [...ten, '別名10'])), {
        OshiRequestField.aliases,
      });
    });

    test('空欄を除いて10個なら OK', () {
      final ten = [for (var i = 0; i < 10; i++) '別名$i'];
      expect(_req(aliases: [...ten, '', ' ']).validate(), isEmpty);
    });

    test('各50文字は OK、51文字はエラー', () {
      expect(_req(aliases: ['い' * 50]).validate(), isEmpty);
      expect(_errorFields(_req(aliases: ['い' * 51])), {
        OshiRequestField.aliases,
      });
    });

    test('正規化して空になる別名はエラー（黙って除かない）', () {
      expect(_errorFields(_req(aliases: ['・'])), {OshiRequestField.aliases});
    });

    test('名前と正規化後に同じ別名はエラー', () {
      expect(_errorFields(_req(name: 'さくら', aliases: ['ｻｸﾗ'])), {
        OshiRequestField.aliases,
      });
    });

    test('別名どうしが正規化後に同じならエラー', () {
      expect(_errorFields(_req(aliases: ['もも', 'モモ'])), {
        OshiRequestField.aliases,
      });
    });
  });

  group('OshiRequest.validate: 事務所', () {
    test('50文字は OK、51文字はエラー', () {
      expect(_req(agency: 'あ' * 50).validate(), isEmpty);
      expect(_errorFields(_req(agency: 'あ' * 51)), {OshiRequestField.agency});
    });
  });

  group('OshiRequest.validate: 公式サイト URL', () {
    test('空なら OK', () {
      expect(_req(officialUrl: '').validate(), isEmpty);
      expect(_req(officialUrl: '  ').validate(), isEmpty);
    });

    test('https:// で始まる URL は OK', () {
      expect(
        _req(officialUrl: 'https://example.com/a?b=c').validate(),
        isEmpty,
      );
    });

    test('http:// やスキーム無し、https:// だけ、空白を含むものはエラー', () {
      for (final url in [
        'http://example.com',
        'example.com',
        'HTTPS://example.com',
        'https://',
        'https:// example.com',
        'https://exa mple.com',
        'javascript:alert(1)',
      ]) {
        expect(_errorFields(_req(officialUrl: url)), {
          OshiRequestField.officialUrl,
        }, reason: url);
      }
    });

    test('200文字は OK、201文字はエラー', () {
      const prefix = 'https://example.com/';
      final url200 = prefix + 'a' * (200 - prefix.length);
      expect(url200.length, 200);
      expect(_req(officialUrl: url200).validate(), isEmpty);
      expect(_errorFields(_req(officialUrl: '${url200}a')), {
        OshiRequestField.officialUrl,
      });
    });
  });

  group('OshiRequest.validate: 公式 X', () {
    test('空なら OK', () {
      expect(_req(officialX: '').validate(), isEmpty);
    });

    test('英数字と _ の1〜15文字は OK', () {
      for (final x in ['a', 'A_1', 'a' * 15, '_']) {
        expect(_req(officialX: x).validate(), isEmpty, reason: x);
      }
    });

    test('先頭の @（全角 ＠ も）を1つだけ取り除く', () {
      expect(_req(officialX: '@sakura').xHandle, 'sakura');
      expect(_req(officialX: '＠sakura').xHandle, 'sakura');
      expect(_req(officialX: ' @sakura ').xHandle, 'sakura');
      expect(_req(officialX: '@${'a' * 15}').validate(), isEmpty);
    });

    test('16文字、@ だけ、@@、記号・日本語・空白入りはエラー', () {
      for (final x in [
        'a' * 16,
        '@',
        '＠',
        '@@sakura',
        'sa-kura',
        'さくら',
        'sa kura',
        'ｓａｋｕｒａ',
      ]) {
        expect(_errorFields(_req(officialX: x)), {
          OshiRequestField.officialX,
        }, reason: x);
      }
    });
  });

  group('OshiRequest.validate: 所属グループ', () {
    test('個人なら10個まで OK、11個はエラー', () {
      final ten = [for (var i = 0; i < 10; i++) 'g$i'];
      expect(_req(groupIds: ten).validate(), isEmpty);
      expect(_errorFields(_req(groupIds: [...ten, 'g10'])), {
        OshiRequestField.groupIds,
      });
    });

    test('重複はエラー', () {
      expect(_errorFields(_req(groupIds: ['g1', 'g1'])), {
        OshiRequestField.groupIds,
      });
    });

    test('グループの申請で所属グループを指定するとエラー', () {
      expect(_errorFields(_req(kind: OshiKind.group, groupIds: ['g1'])), {
        OshiRequestField.groupIds,
      });
    });
  });

  group('OshiRequest.validate: 複数のエラー', () {
    test('問題のある項目ごとに1つずつ返す', () {
      final errors = _req(
        name: '',
        agency: 'あ' * 51,
        officialUrl: 'http://x',
        officialX: '@',
      ).validate();
      expect(errors.keys.toSet(), {
        OshiRequestField.name,
        OshiRequestField.agency,
        OshiRequestField.officialUrl,
        OshiRequestField.officialX,
      });
      expect(errors.values.every((m) => m.isNotEmpty), isTrue);
    });
  });

  group('OshiRequest.toFirestore', () {
    test('必須の項目だけなら、任意項目のキーを省く', () {
      final map = _req(name: ' さくら ').toFirestore('uid1');
      expect(map.keys.toSet(), {
        'name',
        'genre',
        'status',
        'createdBy',
        'createdAt',
      });
      expect(map['name'], 'さくら');
      expect(map['genre'], 'idol');
      expect(map['status'], 'pending');
      expect(map['createdBy'], 'uid1');
      expect(map['createdAt'], isA<FieldValue>());
    });

    test('すべての項目を trim して保存し、X は @ を除く', () {
      final map = _req(
        name: 'ｻｸﾗ',
        aliases: [' さくちゃん ', ''],
        agency: ' 事務所 ',
        officialUrl: ' https://example.com ',
        officialX: ' @sakura ',
        groupIds: [' g1 ', ''],
      ).toFirestore('uid1');
      // 正規化前の表記で保存する
      expect(map['name'], 'ｻｸﾗ');
      expect(map['aliases'], ['さくちゃん']);
      expect(map['agency'], '事務所');
      expect(map['officialUrl'], 'https://example.com');
      expect(map['officialX'], 'sakura');
      expect(map['groupIds'], ['g1']);
    });

    test('グループの申請では groupIds を書かない', () {
      final map = _req(kind: OshiKind.group, groupIds: ['g1']).toFirestore('u');
      expect(map.containsKey('groupIds'), isFalse);
    });

    test('空欄だけの別名・所属グループはキーごと省く', () {
      final map = _req(aliases: ['', ' '], groupIds: ['']).toFirestore('u');
      expect(map.containsKey('aliases'), isFalse);
      expect(map.containsKey('groupIds'), isFalse);
    });
  });

  group('FollowState', () {
    test('ドキュメントが無い・項目が欠けている・型違いなら空', () {
      expect(FollowState.fromFirestore(null).isEmpty, isTrue);
      expect(FollowState.fromFirestore({}).isEmpty, isTrue);
      expect(
        FollowState.fromFirestore({
          'followingGroupIds': 'g1',
          'followingOshiIds': {'a': 1},
        }).isEmpty,
        isTrue,
      );
    });

    test('配列を種別ごとに読み、文字列以外を除く', () {
      final s = FollowState.fromFirestore({
        'followingGroupIds': ['g1', 1, 'g1'],
        'followingOshiIds': ['p1'],
      });
      expect(s.groupIds, {'g1'});
      expect(s.oshiIds, {'p1'});
      expect(s.idsOf(OshiKind.group), {'g1'});
      expect(s.idsOf(OshiKind.person), {'p1'});
    });

    test('isFollowing は種別ごとに判定する（同じ ID でも種別が違えば別）', () {
      const s = FollowState(groupIds: {'x'});
      const group = OshiSummary(
        id: 'x',
        kind: OshiKind.group,
        name: 'A',
        genre: OshiGenre.idol,
        status: OshiStatus.approved,
      );
      const person = OshiSummary(
        id: 'x',
        kind: OshiKind.person,
        name: 'A',
        genre: OshiGenre.idol,
        status: OshiStatus.approved,
      );
      expect(s.isFollowing(group), isTrue);
      expect(s.isFollowing(person), isFalse);
    });

    test('fieldOf は Firestore の項目名を返す', () {
      expect(FollowState.fieldOf(OshiKind.group), 'followingGroupIds');
      expect(FollowState.fieldOf(OshiKind.person), 'followingOshiIds');
    });
  });
}
