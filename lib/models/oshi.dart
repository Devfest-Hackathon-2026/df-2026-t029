import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/text_normalizer.dart';

/// 推しの種別。group → `groups` コレクション、person → `oshis` コレクション
enum OshiKind {
  group('groups', 'グループ'),
  person('oshis', '個人');

  const OshiKind(this.collection, this.label);

  /// 保存先のコレクション名
  final String collection;

  /// 画面に出す名前
  final String label;
}

/// 公開状態（DB 設計案 4章）
enum OshiStatus {
  pending('pending'),
  approved('approved');

  const OshiStatus(this.code);

  /// Firestore に保存する値
  final String code;

  /// 不明な値なら null（一覧から除く）
  static OshiStatus? fromCode(Object? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// ジャンル（計画書 3.4）。Firestore には [code] を保存する
enum OshiGenre {
  idol('idol', 'アイドル'),
  voiceActor('voice_actor', '声優'),
  artist('artist', 'アーティスト・バンド'),
  animeGame('anime_game', 'アニメ・ゲーム'),
  actor('actor', '俳優'),
  vtuber('vtuber', 'VTuber・配信者'),
  sports('sports', 'スポーツ'),
  other('other', 'その他');

  const OshiGenre(this.code, this.label);

  final String code;
  final String label;

  /// 未知の値・欠けている値は [other] にする
  static OshiGenre fromCode(Object? code) {
    for (final g in values) {
      if (g.code == code) return g;
    }
    return other;
  }
}

/// 検索結果・フォロー一覧に出す1件分
class OshiSummary {
  const OshiSummary({
    required this.id,
    required this.kind,
    required this.name,
    required this.genre,
    required this.status,
    this.aliases = const [],
    this.groupIds = const [],
    this.agency,
    this.officialUrl,
    this.officialX,
    this.createdBy = '',
  });

  final String id;
  final OshiKind kind;
  final String name;
  final List<String> aliases;
  final OshiGenre genre;
  final OshiStatus status;

  /// 所属グループの ID（個人のみ。グループでは常に空）
  final List<String> groupIds;
  final String? agency;
  final String? officialUrl;

  /// `@` なしの X アカウント名
  final String? officialX;
  final String createdBy;

  bool get isPending => status == OshiStatus.pending;
  bool get isApproved => status == OshiStatus.approved;

  /// Firestore のドキュメントから作る。
  ///
  /// 欠けている・型が違う項目には既定値を入れる。ただし、名前が空か
  /// `status` が不明なものは表示できないので null を返す（一覧から除く）。
  static OshiSummary? fromFirestore(
    OshiKind kind,
    String id,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final name = _string(data['name'])?.trim() ?? '';
    final status = OshiStatus.fromCode(data['status']);
    if (name.isEmpty || status == null) return null;
    return OshiSummary(
      id: id,
      kind: kind,
      name: name,
      aliases: _stringList(data['aliases']),
      genre: OshiGenre.fromCode(data['genre']),
      status: status,
      groupIds: kind == OshiKind.person
          ? _stringList(data['groupIds'])
          : const [],
      agency: _nonEmpty(data['agency']),
      officialUrl: _nonEmpty(data['officialUrl']),
      officialX: _nonEmpty(data['officialX']),
      createdBy: _string(data['createdBy']) ?? '',
    );
  }

  /// 同じ推しかどうかの判定に使うキー（例: `group/abc123`）。
  /// [==] はすべての項目で比べるので、承認などで中身が変わると別の値になる。
  String get key => '${kind.name}/$id';

  @override
  bool operator ==(Object other) =>
      other is OshiSummary &&
      other.id == id &&
      other.kind == kind &&
      other.name == name &&
      _listEquals(other.aliases, aliases) &&
      other.genre == genre &&
      other.status == status &&
      _listEquals(other.groupIds, groupIds) &&
      other.agency == agency &&
      other.officialUrl == officialUrl &&
      other.officialX == officialX &&
      other.createdBy == createdBy;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    name,
    Object.hashAll(aliases),
    genre,
    status,
    Object.hashAll(groupIds),
    agency,
    officialUrl,
    officialX,
    createdBy,
  );

  @override
  String toString() => 'OshiSummary(${kind.name}/$id, $name, ${status.code})';
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String? _string(Object? v) => v is String ? v : null;

String? _nonEmpty(Object? v) {
  final s = _string(v)?.trim();
  return (s == null || s.isEmpty) ? null : s;
}

List<String> _stringList(Object? v) {
  if (v is! List) return const [];
  return List.unmodifiable(
    v.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty),
  );
}

/// 申請フォームの項目（検査結果のキーに使う）
enum OshiRequestField {
  kind,
  name,
  aliases,
  genre,
  agency,
  officialUrl,
  officialX,
  groupIds,
}

/// 推しの追加申請の入力（計画書 3.5）
///
/// 画面の入力をそのまま入れてよい。前後の空白の除去、空の別名の除去、
/// X の先頭の `@` の除去は、このクラスの getter と [toFirestore] が行う。
class OshiRequest {
  const OshiRequest({
    required this.kind,
    required this.name,
    required this.genre,
    this.aliases = const [],
    this.agency = '',
    this.officialUrl = '',
    this.officialX = '',
    this.groupIds = const [],
  });

  static const int maxNameLength = 50;
  static const int maxAliases = 10;
  static const int maxAgencyLength = 50;
  static const int maxUrlLength = 200;
  static const int maxGroupIds = 10;
  static final RegExp xHandlePattern = RegExp(r'^[A-Za-z0-9_]{1,15}$');

  final OshiKind kind;
  final String name;
  final List<String> aliases;
  final OshiGenre genre;
  final String agency;
  final String officialUrl;
  final String officialX;

  /// 所属グループの ID（個人のときだけ）
  final List<String> groupIds;

  String get trimmedName => name.trim();

  /// 前後の空白を除き、空のものを除いた別名
  List<String> get cleanedAliases =>
      aliases.map((a) => a.trim()).where((a) => a.isNotEmpty).toList();

  String get trimmedAgency => agency.trim();
  String get trimmedOfficialUrl => officialUrl.trim();

  /// 前後の空白と、先頭の `@`（全角 `＠` も）を1つ除いた X アカウント名
  String get xHandle {
    final s = officialX.trim();
    if (s.startsWith('@') || s.startsWith('＠')) return s.substring(1);
    return s;
  }

  /// 前後の空白を除き、空のものを除いた所属グループ ID
  List<String> get cleanedGroupIds =>
      groupIds.map((g) => g.trim()).where((g) => g.isNotEmpty).toList();

  /// 入力を検査する。問題のある項目ごとに、日本語のエラー文を1つ返す。
  /// 空の Map なら申請できる。重複（既存の推しとの一致）はここでは見ない。
  Map<OshiRequestField, String> validate() {
    final errors = <OshiRequestField, String>{};

    // 名前
    final n = trimmedName;
    final normalizedName = normalizeName(n);
    if (n.isEmpty) {
      errors[OshiRequestField.name] = '名前を入力してください';
    } else if (_len(n) > maxNameLength) {
      errors[OshiRequestField.name] = '名前は$maxNameLength文字以内で入力してください';
    } else if (normalizedName.isEmpty) {
      errors[OshiRequestField.name] = '名前に文字（記号や空白以外）を含めてください';
    }

    // 別名
    final as = cleanedAliases;
    if (as.length > maxAliases) {
      errors[OshiRequestField.aliases] = '別名は$maxAliases個までです';
    } else {
      final seen = <String>{};
      for (final a in as) {
        final na = normalizeName(a);
        if (_len(a) > maxNameLength) {
          errors[OshiRequestField.aliases] =
              '別名は$maxNameLength文字以内で入力してください（$a）';
        } else if (na.isEmpty) {
          errors[OshiRequestField.aliases] = '別名に文字（記号や空白以外）を含めてください（$a）';
        } else if (normalizedName.isNotEmpty && na == normalizedName) {
          errors[OshiRequestField.aliases] = '名前と同じ別名は登録できません（$a）';
        } else if (!seen.add(na)) {
          errors[OshiRequestField.aliases] = '同じ別名が重複しています（$a）';
        }
        if (errors.containsKey(OshiRequestField.aliases)) break;
      }
    }

    // 事務所
    if (_len(trimmedAgency) > maxAgencyLength) {
      errors[OshiRequestField.agency] = '事務所は$maxAgencyLength文字以内で入力してください';
    }

    // 公式サイト
    final url = trimmedOfficialUrl;
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (!url.startsWith('https://') ||
          uri == null ||
          uri.host.isEmpty ||
          url.contains(RegExp(r'\s'))) {
        errors[OshiRequestField.officialUrl] =
            '公式サイトは https:// で始まる URL を入力してください';
      } else if (url.length > maxUrlLength) {
        errors[OshiRequestField.officialUrl] =
            '公式サイトの URL は$maxUrlLength文字以内で入力してください';
      }
    }

    // 公式 X
    final x = xHandle;
    if (officialX.trim().isNotEmpty && !xHandlePattern.hasMatch(x)) {
      errors[OshiRequestField.officialX] = 'X のアカウント名は英数字と _ の1〜15文字で入力してください';
    }

    // 所属グループ
    final gs = cleanedGroupIds;
    if (kind == OshiKind.group && gs.isNotEmpty) {
      errors[OshiRequestField.groupIds] = '所属グループは個人のときだけ選べます';
    } else if (gs.length > maxGroupIds) {
      errors[OshiRequestField.groupIds] = '所属グループは$maxGroupIds個までです';
    } else if (gs.toSet().length != gs.length) {
      errors[OshiRequestField.groupIds] = '同じ所属グループが重複しています';
    }

    return errors;
  }

  /// Firestore に書き込む Map。空の任意項目はキーごと省く。
  ///
  /// 書き出すキーは次のとおり（ルールの `hasOnly` と一致させる）。
  /// 必ず: name, genre, status, createdBy, createdAt
  /// 値があるときだけ: aliases, agency, officialUrl, officialX,
  /// groupIds（個人のみ）
  Map<String, dynamic> toFirestore(String uid) {
    final as = cleanedAliases;
    final gs = cleanedGroupIds;
    return {
      'name': trimmedName,
      'genre': genre.code,
      'status': OshiStatus.pending.code,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      if (as.isNotEmpty) 'aliases': as,
      if (trimmedAgency.isNotEmpty) 'agency': trimmedAgency,
      if (trimmedOfficialUrl.isNotEmpty) 'officialUrl': trimmedOfficialUrl,
      if (xHandle.isNotEmpty) 'officialX': xHandle,
      if (kind == OshiKind.person && gs.isNotEmpty) 'groupIds': gs,
    };
  }
}

/// 文字数。Firestore ルールの `size()` と同じく UTF-16 の単位で数える
/// （絵文字の多くは2文字と数える）。エミュレータで確認済み。
int _len(String s) => s.length;

/// 申請の入力に問題があるとき（[OshiRequest.validate] の結果が空でない等）
class OshiRequestException implements Exception {
  const OshiRequestException(this.messages);

  final List<String> messages;

  @override
  String toString() => messages.join('\n');
}

/// 同じ種別に、正規化後の名前・別名が完全に一致する推しが既にあるとき
class OshiDuplicateException implements Exception {
  const OshiDuplicateException(this.duplicates);

  final List<OshiSummary> duplicates;

  @override
  String toString() =>
      '同じ名前の推しが既にあります: ${duplicates.map((d) => d.name).join('、')}';
}

/// ログイン中のユーザーのフォロー状態（`users/{uid}`）
class FollowState {
  const FollowState({this.groupIds = const {}, this.oshiIds = const {}});

  static const empty = FollowState();

  /// フォローの上限。`followingGroupIds` と `followingOshiIds` の
  /// **それぞれに** 200 件まで（合計ではない。計画書 3.7 のルールと同じ）
  static const int maxFollows = 200;

  /// `followingGroupIds`
  final Set<String> groupIds;

  /// `followingOshiIds`
  final Set<String> oshiIds;

  /// ドキュメントが無い・項目が欠けている・型が違うときは空として扱う
  factory FollowState.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return empty;
    return FollowState(
      groupIds: _stringList(data['followingGroupIds']).toSet(),
      oshiIds: _stringList(data['followingOshiIds']).toSet(),
    );
  }

  Set<String> idsOf(OshiKind kind) =>
      kind == OshiKind.group ? groupIds : oshiIds;

  bool isFollowing(OshiSummary oshi) => idsOf(oshi.kind).contains(oshi.id);

  bool get isEmpty => groupIds.isEmpty && oshiIds.isEmpty;

  /// `users/{uid}` の配列項目名
  static String fieldOf(OshiKind kind) =>
      kind == OshiKind.group ? 'followingGroupIds' : 'followingOshiIds';
}
