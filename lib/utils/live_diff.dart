// 既存のライブと入力の差分（計画書 3.2・3.3・3.6）。Firestore に依存しない
// 純粋関数（値の形として Timestamp だけを使う）。
//
// 値の形: FieldChange・HistoryEntry の before / after は Firestore に保存する
// 形のまま（日時は Timestamp、料金は {seat, amount} の Map の List、受付種別は
// 文字列、出演者は String の List）。画面に出すときは formatHistoryValue を使う。
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../features/live_form/date_time_field.dart';
import '../features/live_form/live_draft_to_models.dart';
import '../models/history_entry.dart';
import '../models/live.dart';
import '../models/performance.dart';
import '../models/reception.dart';
import '../repositories/live_repository.dart';
import 'text_normalizer.dart';

// ---------------------------------------------------------------------------
// 選択のキー
// ---------------------------------------------------------------------------

/// 差分の確認画面で、チェックを付ける1行のキー（文字列）。ui は組み立てず、
/// [FieldChange.key]・[AddedDoc.key] をそのまま使う。
///
/// | 行 | キー |
/// |---|---|
/// | ライブの項目の変更 | `live/<field>`（例: `live/title`・`live/groupIds`） |
/// | 既存の公演・受付の項目の変更 | `performances/<既存の ID>/<field>`・`receptions/<既存の ID>/<field>` |
/// | 公演・受付の追加 | `performances/+<入力での順番>`・`receptions/+<入力での順番>`（0 始まり） |
///
/// キーは入力での順番と既存の ID だけから作るので、[pairManually]・
/// [withoutUnselected] を通しても、ほかの行のキーは変わらない。
abstract final class MergeKeys {
  static String liveField(String field) => 'live/$field';

  static String docField(HistoryCollection c, String docId, String field) =>
      '${c.name}/$docId/$field';

  static String added(HistoryCollection c, int inputIndex) =>
      '${c.name}/+$inputIndex';
}

// ---------------------------------------------------------------------------
// 差分の型
// ---------------------------------------------------------------------------

/// 項目1つの変更
@immutable
class FieldChange {
  const FieldChange({
    required this.key,
    required this.field,
    this.before,
    this.after,
    this.hasBefore = true,
    this.hasAfter = true,
  });

  /// 選択のキー（[MergeKeys]）
  final String key;

  /// 項目名（Firestore のフィールド名。例: `applyEndAt`）
  final String field;

  /// 変更前・変更後の値（Firestore の形）
  final Object? before;
  final Object? after;

  /// false なら、変更前は項目が無かった（値を入れる変更）
  final bool hasBefore;

  /// false なら、変更後は項目を消す（編集で空にした任意項目。ユーザー決定・案A）
  final bool hasAfter;

  @override
  String toString() => 'FieldChange($key: $before → $after)';
}

/// 既存の公演・受付1件と、それに対応付いた入力の差分
@immutable
class DocChange<T> {
  const DocChange({
    required this.existing,
    required this.merged,
    required this.changes,
    this.inputIndex,
  });

  /// 既存の値（ID 付き）
  final T existing;

  /// [changes] をすべて反映した後の値（ID は既存と同じ）
  final T merged;

  /// 変わる項目（1つ以上）
  final List<FieldChange> changes;

  /// 対応付いた入力での順番（0 始まり）
  final int? inputIndex;
}

/// 入力にだけある公演・受付（既存のライブに追加する）
@immutable
class AddedDoc<T> {
  const AddedDoc({
    required this.key,
    required this.inputIndex,
    required this.doc,
  });

  /// 選択のキー（`performances/+<inputIndex>` など）
  final String key;

  /// 入力での順番（0 始まり）
  final int inputIndex;

  /// 追加する値（id・liveId は null。groupIds・oshiIds は反映時に付ける）
  final T doc;
}

/// 外せない出演者が無いことを表す値
const ({List<String> groupIds, List<String> oshiIds}) noPerformerRemovals = (
  groupIds: <String>[],
  oshiIds: <String>[],
);

/// 既存のライブに入力を反映する計画（[diffLive] の結果）
@immutable
class LiveMergePlan {
  const LiveMergePlan({
    required this.base,
    required this.mergedLive,
    this.liveChanges = const [],
    this.addedPerformances = const [],
    this.changedPerformances = const [],
    this.unchangedPerformances = const [],
    this.existingOnlyPerformances = const [],
    this.addedReceptions = const [],
    this.changedReceptions = const [],
    this.unchangedReceptions = const [],
    this.existingOnlyReceptions = const [],
    this.editing = false,
    this.ignoredPerformerRemovals = noPerformerRemovals,
  });

  /// [diffLive] に渡した値（[pairManually] が同じ規則で比べるために持つ）
  final bool editing;

  /// 編集で外そうとしたが、外せない出演者の ID（ルールで出演者は減らせない。
  /// ui は「出演者は外せません（〇〇はそのまま残ります）」と文字で示す）。
  /// 照合（editing = false）では常に空。[withoutUnselected]・[pairManually] を
  /// 通しても変わらない
  final ({List<String> groupIds, List<String> oshiIds})
  ignoredPerformerRemovals;

  /// 差分を作ったときに読んだ既存のライブ一式（versions を含む）
  final ExistingLive base;

  /// [liveChanges] を反映した後のライブ（ID は既存と同じ）
  final Live mergedLive;

  /// ライブ名・公式 URL の変更と、出演者の追加（groupIds・oshiIds は和集合）
  final List<FieldChange> liveChanges;

  final List<AddedDoc<Performance>> addedPerformances;
  final List<DocChange<Performance>> changedPerformances;

  /// 対応が付いて、変わる項目が無い既存の公演
  final List<Performance> unchangedPerformances;

  /// 今回の入力に無い既存の公演（消さない。編集で行を消した公演もここに入る）
  final List<Performance> existingOnlyPerformances;

  final List<AddedDoc<Reception>> addedReceptions;
  final List<DocChange<Reception>> changedReceptions;
  final List<Reception> unchangedReceptions;
  final List<Reception> existingOnlyReceptions;

  /// 反映するもの（変更・追加）が無い
  bool get isEmpty => selectableKeys.isEmpty;

  /// チェックを付けられる行のキー（変更は項目ごと、追加はドキュメントごと）
  Set<String> get selectableKeys => {
    for (final c in liveChanges) c.key,
    for (final a in addedPerformances) a.key,
    for (final d in changedPerformances)
      for (final c in d.changes) c.key,
    for (final a in addedReceptions) a.key,
    for (final d in changedReceptions)
      for (final c in d.changes) c.key,
  };
}

// ---------------------------------------------------------------------------
// 日付・文字列・値の比べ方（照合 live_match.dart と共通）
// ---------------------------------------------------------------------------

/// 日本時間の日付（年月日だけを持つ UTC の DateTime）。端末のタイムゾーンに
/// よらず、日本時間の0時で日を区切る（計画書 3.2「日本時間の日」）
DateTime jstDayOf(DateTime t) {
  final j = t.toUtc().add(const Duration(hours: 9));
  return DateTime.utc(j.year, j.month, j.day);
}

/// 日本時間で同じ日か
bool isSameJstDay(DateTime a, DateTime b) => jstDayOf(a) == jstDayOf(b);

/// 公式 URL を比べる形にする（前後の空白・末尾の `/`・大文字小文字を無視）
String normalizeUrl(String url) {
  var s = url.trim().toLowerCase();
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// 比べる項目（Firestore のフィールド名）と必須の項目
abstract final class MergeFields {
  static const List<String> live = [
    'title',
    'officialUrl',
    'groupIds',
    'oshiIds',
  ];
  static const List<String> performance = [
    'startAt',
    'openAt',
    'venue',
    'prefecture',
  ];
  static const List<String> reception = [
    'type',
    'name',
    'applyStartAt',
    'applyEndAt',
    'resultAt',
    'paymentDeadline',
    'prices',
    'winnersOnly',
  ];

  /// 消せない（ルールで必須の）項目
  static const Map<HistoryCollection, Set<String>> required = {
    HistoryCollection.lives: {'title', 'groupIds', 'oshiIds'},
    HistoryCollection.performances: {'startAt', 'venue'},
    HistoryCollection.receptions: {'type', 'name', 'applyEndAt', 'winnersOnly'},
  };

  static List<String> of(HistoryCollection c) => switch (c) {
    HistoryCollection.lives => live,
    HistoryCollection.performances => performance,
    HistoryCollection.receptions => reception,
  };
}

/// 照合（false）か編集（true）か、と、空にした任意項目を消すか
typedef _Mode = ({bool editing, bool clearEmptyOptional});

/// 値が「空」か（null・空白だけの文字列・空の配列）
bool _isEmptyValue(Object? v) =>
    v == null || (v is String && v.trim().isEmpty) || (v is List && v.isEmpty);

/// 表記の揺れを吸収して比べる文字列の項目
const Set<String> _textFields = {'title', 'venue', 'name', 'prefecture'};

/// 2つの値（Firestore の形）が同じか。
/// 料金は順番を問わない。照合では、文字列は normalizeName、URL は
/// normalizeUrl で比べる（編集では文字どおり比べる）
bool _sameValue(String field, Object? a, Object? b, _Mode mode) {
  if (field == 'prices') {
    return _deepEquals(_canonicalPrices(a, mode), _canonicalPrices(b, mode));
  }
  if (!mode.editing && a is String && b is String) {
    if (_textFields.contains(field)) {
      return normalizeName(a) == normalizeName(b);
    }
    if (field == 'officialUrl') return normalizeUrl(a) == normalizeUrl(b);
  }
  return _deepEquals(a, b);
}

/// 料金を「席種・金額」の順に並べた形にする（順番の違いを無視するため）
List<String> _canonicalPrices(Object? v, _Mode mode) {
  final out = <String>[];
  for (final p in v is List ? v : const []) {
    if (p is! Map) continue;
    final seat = p['seat'] is String ? p['seat'] as String : '';
    final amount = p['amount'] is num ? (p['amount'] as num).toInt() : null;
    final s = mode.editing ? seat : normalizeName(seat);
    out.add('$s\u0000$amount');
  }
  return out..sort();
}

/// Firestore の値（Timestamp・List・Map など）が同じか（List は順番も比べる）
bool firestoreValueEquals(Object? a, Object? b) => _deepEquals(a, b);

bool _deepEquals(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_deepEquals(a[k], b[k])) return false;
    }
    return true;
  }
  return a == b;
}

/// 項目1つを比べる。変わらなければ null（計画書 3.3）。
///
/// - 入力が空 → 既存のまま（編集で任意項目なら「消す変更」）
/// - 照合では、入力の winnersOnly が false なら既存のまま（読み取れなかった
///   ときの既定値で、既存の true を消さないため）
FieldChange? _compareField({
  required HistoryCollection collection,
  required String key,
  required String field,
  required Map<String, dynamic> existing,
  required Map<String, dynamic> input,
  required _Mode mode,
}) {
  final hasOld = existing.containsKey(field) && existing[field] != null;
  final old = hasOld ? existing[field] : null;
  final newValue = input[field];
  if (_isEmptyValue(newValue)) {
    final optional = !MergeFields.required[collection]!.contains(field);
    if (mode.clearEmptyOptional && optional && !_isEmptyValue(old)) {
      // 料金は空の配列にする（項目は残す）。ほかは項目を消す
      return field == 'prices'
          ? FieldChange(key: key, field: field, before: old, after: const [])
          : FieldChange(key: key, field: field, before: old, hasAfter: false);
    }
    return null;
  }
  if (!mode.editing && field == 'winnersOnly' && newValue == false) return null;
  if (hasOld && _sameValue(field, old, newValue, mode)) return null;
  return FieldChange(
    key: key,
    field: field,
    before: old,
    after: newValue,
    hasBefore: hasOld,
  );
}

// ---------------------------------------------------------------------------
// 変更を当てた値を作る
// ---------------------------------------------------------------------------

Map<String, dynamic> _applied(
  Map<String, dynamic> data,
  List<FieldChange> changes,
) {
  final d = {...data};
  for (final c in changes) {
    if (c.hasAfter) {
      d[c.field] = c.after;
    } else {
      d.remove(c.field);
    }
  }
  return d;
}

DateTime? _date(Object? v) => switch (v) {
  Timestamp t => t.toDate(),
  DateTime d => d,
  _ => null,
};

List<String> _ids(Object? v) => [
  for (final x in v is List ? v : const []) ?(x is String ? x : null),
];

/// [live] に [changes] を当てた値
Live liveWithChanges(Live live, List<FieldChange> changes) {
  final d = _applied(live.toFirestore(), changes);
  return Live(
    id: live.id,
    title: d['title'] as String,
    groupIds: List.unmodifiable(_ids(d['groupIds'])),
    oshiIds: List.unmodifiable(_ids(d['oshiIds'])),
    officialUrl: d['officialUrl'] as String?,
  );
}

/// [p] に [changes] を当てた値（ID・liveId・出演者は [p] のまま）
Performance performanceWithChanges(Performance p, List<FieldChange> changes) {
  final d = _applied(p.toFirestore(), changes);
  return Performance(
    id: p.id,
    liveId: p.liveId,
    groupIds: p.groupIds,
    oshiIds: p.oshiIds,
    startAt: _date(d['startAt'])!,
    openAt: _date(d['openAt']),
    venue: d['venue'] as String,
    prefecture: d['prefecture'] as String?,
  );
}

/// [r] に [changes] を当てた値（ID・liveId・出演者は [r] のまま）
Reception receptionWithChanges(Reception r, List<FieldChange> changes) {
  final d = _applied(r.toFirestore(), changes);
  return Reception(
    id: r.id,
    liveId: r.liveId,
    groupIds: r.groupIds,
    oshiIds: r.oshiIds,
    type: ReceptionType.values.asNameMap()[d['type']] ?? ReceptionType.other,
    name: d['name'] as String,
    applyStartAt: _date(d['applyStartAt']),
    applyEndAt: _date(d['applyEndAt'])!,
    resultAt: _date(d['resultAt']),
    paymentDeadline: _date(d['paymentDeadline']),
    prices: [
      for (final p in d['prices'] as List? ?? const [])
        Price.fromMap(Map<String, dynamic>.from(p as Map)),
    ],
    winnersOnly: d['winnersOnly'] as bool? ?? false,
  );
}

// ---------------------------------------------------------------------------
// 差分を作る
// ---------------------------------------------------------------------------

/// 既存のライブ一式 [base] と入力 [input] の差分を作る（計画書 3.2・3.3）。
///
/// - [performanceIds]・[receptionIds]: 編集（3.7）のとき、入力の公演・受付が
///   既存のどの ID から来たか（入力と同じ順番。新しく足した行は null。
///   `LiveEditSeed.idsInOrder()` の値）。指定があれば ID で先に対応付け、
///   残りを 3.2 の規則で対応付ける
/// - [editing]: 編集（3.7）なら true（照合では false）。true のとき:
///   - 文字列・URL・料金の席種を文字どおり比べる（照合では normalizeName・
///     normalizeUrl で比べ、表記の揺れだけなら「変化なし」）
///   - winnersOnly の true → false も変更にする（照合では、入力の false は
///     読み取れなかった既定値とみなし、既存の true を消さない）
///   - 入力で空にした任意項目（公式 URL・開場日時・都道府県・申込開始・
///     当落発表・入金期限・料金）を「値を消す変更」にする（hasAfter = false。
///     料金は []）。照合では空の値で上書きしない。必須項目は消さない
///   - 外そうとした出演者を [LiveMergePlan.ignoredPerformerRemovals] に入れる
/// - 出演者は和集合（既存を外さない。ルールで減らせない）
/// - 既存の公演・受付は消さない。編集で行を消した公演・受付も、削除はせず
///   `existingOnly*`（今回の入力に無い）になる（削除は Step4 の範囲外）
LiveMergePlan diffLive(
  ExistingLive base,
  LiveModels input, {
  List<String?>? performanceIds,
  List<String?>? receptionIds,
  bool editing = false,
}) {
  final _Mode mode = (editing: editing, clearEmptyOptional: editing);
  final liveChanges = _diffLiveFields(base.live, input.live, mode);
  final ignored = editing
      ? (
          groupIds: List<String>.unmodifiable(
            base.live.groupIds.where((id) => !input.live.groupIds.contains(id)),
          ),
          oshiIds: List<String>.unmodifiable(
            base.live.oshiIds.where((id) => !input.live.oshiIds.contains(id)),
          ),
        )
      : noPerformerRemovals;

  final perfPairs = _pairPerformances(
    base.performances,
    input.performances,
    performanceIds,
  );
  final addedP = <AddedDoc<Performance>>[];
  final changedP = <DocChange<Performance>>[];
  final unchangedP = <Performance>[];
  for (final (i, p) in input.performances.indexed) {
    final ex = perfPairs[i];
    if (ex == null) {
      addedP.add(
        AddedDoc(
          key: MergeKeys.added(HistoryCollection.performances, i),
          inputIndex: i,
          doc: p,
        ),
      );
      continue;
    }
    final dc = _diffPerformance(ex, p, i, mode);
    if (dc.changes.isEmpty) {
      unchangedP.add(ex);
    } else {
      changedP.add(dc);
    }
  }
  final pairedP = {for (final e in perfPairs.values) e.id};

  final recPairs = _pairReceptions(
    base.receptions,
    input.receptions,
    receptionIds,
  );
  final addedR = <AddedDoc<Reception>>[];
  final changedR = <DocChange<Reception>>[];
  final unchangedR = <Reception>[];
  for (final (i, r) in input.receptions.indexed) {
    final ex = recPairs[i];
    if (ex == null) {
      addedR.add(
        AddedDoc(
          key: MergeKeys.added(HistoryCollection.receptions, i),
          inputIndex: i,
          doc: r,
        ),
      );
      continue;
    }
    final dc = _diffReception(ex, r, i, mode);
    if (dc.changes.isEmpty) {
      unchangedR.add(ex);
    } else {
      changedR.add(dc);
    }
  }
  final pairedR = {for (final e in recPairs.values) e.id};

  return LiveMergePlan(
    base: base,
    mergedLive: liveWithChanges(base.live, liveChanges),
    liveChanges: liveChanges,
    addedPerformances: addedP,
    changedPerformances: _inBaseOrder(
      changedP,
      base.performances,
      (d) => d.existing.id,
      (p) => p.id,
    ),
    unchangedPerformances: _inBaseOrder(
      unchangedP,
      base.performances,
      (p) => p.id,
      (p) => p.id,
    ),
    existingOnlyPerformances: [
      for (final p in base.performances)
        if (!pairedP.contains(p.id)) p,
    ],
    addedReceptions: addedR,
    changedReceptions: _inBaseOrder(
      changedR,
      base.receptions,
      (d) => d.existing.id,
      (r) => r.id,
    ),
    unchangedReceptions: _inBaseOrder(
      unchangedR,
      base.receptions,
      (r) => r.id,
      (r) => r.id,
    ),
    existingOnlyReceptions: [
      for (final r in base.receptions)
        if (!pairedR.contains(r.id)) r,
    ],
    editing: editing,
    ignoredPerformerRemovals: ignored,
  );
}

List<FieldChange> _diffLiveFields(Live existing, Live input, _Mode mode) {
  final ex = existing.toFirestore();
  final inp = input.toFirestore();
  final changes = <FieldChange>[
    for (final f in const ['title', 'officialUrl'])
      ?_compareField(
        collection: HistoryCollection.lives,
        key: MergeKeys.liveField(f),
        field: f,
        existing: ex,
        input: inp,
        mode: mode,
      ),
  ];
  // 出演者は追加だけ（既存の順番を保ち、新しいものを後ろに足す）
  for (final (f, old, added) in [
    ('groupIds', existing.groupIds, input.groupIds),
    ('oshiIds', existing.oshiIds, input.oshiIds),
  ]) {
    final union = <String>{...old, ...added}.toList();
    if (union.length != old.toSet().length) {
      changes.add(
        FieldChange(
          key: MergeKeys.liveField(f),
          field: f,
          before: List<String>.of(old),
          after: union,
        ),
      );
    }
  }
  return changes;
}

DocChange<Performance> _diffPerformance(
  Performance existing,
  Performance input,
  int inputIndex,
  _Mode mode,
) {
  final ex = existing.toFirestore();
  final inp = input.toFirestore();
  final changes = [
    for (final f in MergeFields.performance)
      ?_compareField(
        collection: HistoryCollection.performances,
        key: MergeKeys.docField(
          HistoryCollection.performances,
          existing.id!,
          f,
        ),
        field: f,
        existing: ex,
        input: inp,
        mode: mode,
      ),
  ];
  return DocChange(
    existing: existing,
    merged: performanceWithChanges(existing, changes),
    changes: changes,
    inputIndex: inputIndex,
  );
}

DocChange<Reception> _diffReception(
  Reception existing,
  Reception input,
  int inputIndex,
  _Mode mode,
) {
  final ex = existing.toFirestore();
  final inp = input.toFirestore();
  final changes = [
    for (final f in MergeFields.reception)
      ?_compareField(
        collection: HistoryCollection.receptions,
        key: MergeKeys.docField(HistoryCollection.receptions, existing.id!, f),
        field: f,
        existing: ex,
        input: inp,
        mode: mode,
      ),
  ];
  return DocChange(
    existing: existing,
    merged: receptionWithChanges(existing, changes),
    changes: changes,
    inputIndex: inputIndex,
  );
}

/// [items] を、[baseList] の順番に並べる
List<T> _inBaseOrder<T, B>(
  List<T> items,
  List<B> baseList,
  String? Function(T) idOfItem,
  String? Function(B) idOfBase,
) {
  final order = <String?, int>{
    for (final (i, b) in baseList.indexed) idOfBase(b): i,
  };
  return [...items]..sort(
    (a, b) => (order[idOfItem(a)] ?? 1 << 30).compareTo(
      order[idOfItem(b)] ?? 1 << 30,
    ),
  );
}

/// 入力の公演（順番）→ 対応する既存の公演（計画書 3.2）。
///
/// 1. [ids] で指定された既存の公演（編集）
/// 2. 開演日時がまったく同じで、正規化した会場名が同じ（空でない）
/// 3. 開演の日付（日本時間）が同じで、正規化した会場名が同じものが、入力・
///    既存とも1件ずつのとき（同じ日・同じ会場の昼公演と夜公演を取り違えない
///    ため。決まらなければ自動では対応付けず「追加」にし、手動の対応付けに任せる）
/// 4. 会場名がどちらかで空なら、同じ日の公演が入力・既存とも1件ずつのとき
Map<int, Performance> _pairPerformances(
  List<Performance> existing,
  List<Performance> input,
  List<String?>? ids,
) {
  final pairs = <int, Performance>{};
  final used = <String>{};
  _pairByIds(existing, input.length, ids, (e) => e.id, pairs, used);

  bool free(Performance e) => e.id != null && !used.contains(e.id);

  // 2. 開演日時と会場が同じ
  for (final (i, p) in input.indexed) {
    if (pairs.containsKey(i)) continue;
    final venue = normalizeName(p.venue);
    if (venue.isEmpty) continue;
    for (final e in existing) {
      if (free(e) &&
          e.startAt.isAtSameMomentAs(p.startAt) &&
          normalizeName(e.venue) == venue) {
        pairs[i] = e;
        used.add(e.id!);
        break;
      }
    }
  }

  // 3. 同じ日・同じ会場が入力・既存とも1件ずつ
  bool sameDayVenue(Performance a, Performance b) =>
      isSameJstDay(a.startAt, b.startAt) &&
      normalizeName(a.venue) == normalizeName(b.venue);
  for (final (i, p) in input.indexed) {
    if (pairs.containsKey(i) || normalizeName(p.venue).isEmpty) continue;
    final inputs = [
      for (final (j, q) in input.indexed)
        if (!pairs.containsKey(j) && sameDayVenue(q, p)) q,
    ];
    final candidates = [
      for (final e in existing)
        if (free(e) && sameDayVenue(e, p)) e,
    ];
    if (inputs.length == 1 && candidates.length == 1) {
      pairs[i] = candidates.single;
      used.add(candidates.single.id!);
    }
  }

  for (final (i, p) in input.indexed) {
    if (pairs.containsKey(i)) continue;
    final sameDayInputs = [
      for (final (j, q) in input.indexed)
        if (!pairs.containsKey(j) && isSameJstDay(q.startAt, p.startAt)) q,
    ];
    final sameDayExisting = [
      for (final e in existing)
        if (free(e) && isSameJstDay(e.startAt, p.startAt)) e,
    ];
    if (sameDayInputs.length != 1 || sameDayExisting.length != 1) continue;
    final e = sameDayExisting.single;
    if (normalizeName(p.venue).isEmpty || normalizeName(e.venue).isEmpty) {
      pairs[i] = e;
      used.add(e.id!);
    }
  }
  return pairs;
}

/// 入力の受付（順番）→ 対応する既存の受付（計画書 3.2）。
///
/// 1. [ids] で指定された既存の受付（編集）
/// 2. 種別が同じで、正規化した表示名が同じ（空でない）。申込期限まで同じものを
///    先に対応付け、残りは入力・既存とも1件ずつのときだけ
/// 3. 種別が同じで申込期限の日付（日本時間）が同じものが、入力・既存とも
///    1件ずつのとき
Map<int, Reception> _pairReceptions(
  List<Reception> existing,
  List<Reception> input,
  List<String?>? ids,
) {
  final pairs = <int, Reception>{};
  final used = <String>{};
  _pairByIds(existing, input.length, ids, (e) => e.id, pairs, used);

  bool free(Reception e) => e.id != null && !used.contains(e.id);

  bool sameName(Reception a, Reception b) =>
      a.type == b.type && normalizeName(a.name) == normalizeName(b.name);

  // 2a. 種別・表示名・申込期限がすべて同じ
  for (final (i, r) in input.indexed) {
    if (pairs.containsKey(i) || normalizeName(r.name).isEmpty) continue;
    for (final e in existing) {
      if (free(e) &&
          sameName(e, r) &&
          e.applyEndAt.isAtSameMomentAs(r.applyEndAt)) {
        pairs[i] = e;
        used.add(e.id!);
        break;
      }
    }
  }

  // 2b. 種別・表示名が同じものが、入力・既存とも1件ずつ
  for (final (i, r) in input.indexed) {
    if (pairs.containsKey(i) || normalizeName(r.name).isEmpty) continue;
    final inputs = [
      for (final (j, q) in input.indexed)
        if (!pairs.containsKey(j) && sameName(q, r)) q,
    ];
    final candidates = [
      for (final e in existing)
        if (free(e) && sameName(e, r)) e,
    ];
    if (inputs.length == 1 && candidates.length == 1) {
      pairs[i] = candidates.single;
      used.add(candidates.single.id!);
    }
  }

  bool sameSlot(Reception a, Reception b) =>
      a.type == b.type && isSameJstDay(a.applyEndAt, b.applyEndAt);

  for (final (i, r) in input.indexed) {
    if (pairs.containsKey(i)) continue;
    final inputs = [
      for (final (j, q) in input.indexed)
        if (!pairs.containsKey(j) && sameSlot(q, r)) q,
    ];
    final candidates = [
      for (final e in existing)
        if (free(e) && sameSlot(e, r)) e,
    ];
    if (inputs.length == 1 && candidates.length == 1) {
      pairs[i] = candidates.single;
      used.add(candidates.single.id!);
    }
  }
  return pairs;
}

void _pairByIds<T>(
  List<T> existing,
  int inputLength,
  List<String?>? ids,
  String? Function(T) idOf,
  Map<int, T> pairs,
  Set<String> used,
) {
  if (ids == null) return;
  final byId = <String, T>{for (final e in existing) ?idOf(e): e};
  for (final (i, id) in ids.indexed) {
    if (i >= inputLength || id == null) continue;
    final e = byId[id];
    if (e != null && used.add(id)) pairs[i] = e;
  }
}

// ---------------------------------------------------------------------------
// 差分を変える（手動の対応付け・選択の除外）
// ---------------------------------------------------------------------------

/// 「追加」の公演・受付（[addedKey]）を、今回の入力に無い既存の公演・受付
/// （[existingId]）の変更として対応付け直した計画を返す（3.2 の手動の対応付け）。
///
/// - [existingId] は `existingOnlyPerformances`・`existingOnlyReceptions` の
///   いずれかで、[addedKey] と同じ種類であること（違えば [ArgumentError]）
/// - 対応付けた結果、変わる項目が無ければ `unchanged*` に入る
/// - ほかの行のキーは変わらない。元に戻すときは、呼ぶ前の計画を使う
LiveMergePlan pairManually(
  LiveMergePlan plan, {
  required String addedKey,
  required String existingId,
}) {
  final _Mode mode = (editing: plan.editing, clearEmptyOptional: plan.editing);
  final base = plan.base;

  final ip = plan.addedPerformances.indexWhere((a) => a.key == addedKey);
  if (ip >= 0) {
    final ex = plan.existingOnlyPerformances
        .where((e) => e.id == existingId)
        .firstOrNull;
    if (ex == null) {
      throw ArgumentError.value(
        existingId,
        'existingId',
        '今回の入力に無い既存の公演ではありません',
      );
    }
    final added = plan.addedPerformances[ip];
    final dc = _diffPerformance(ex, added.doc, added.inputIndex, mode);
    return _copy(
      plan,
      addedPerformances: [...plan.addedPerformances]..removeAt(ip),
      changedPerformances: dc.changes.isEmpty
          ? plan.changedPerformances
          : _inBaseOrder(
              [...plan.changedPerformances, dc],
              base.performances,
              (d) => d.existing.id,
              (p) => p.id,
            ),
      unchangedPerformances: dc.changes.isEmpty
          ? _inBaseOrder(
              [...plan.unchangedPerformances, ex],
              base.performances,
              (p) => p.id,
              (p) => p.id,
            )
          : plan.unchangedPerformances,
      existingOnlyPerformances: [
        for (final p in plan.existingOnlyPerformances)
          if (p.id != existingId) p,
      ],
    );
  }

  final ir = plan.addedReceptions.indexWhere((a) => a.key == addedKey);
  if (ir >= 0) {
    final ex = plan.existingOnlyReceptions
        .where((e) => e.id == existingId)
        .firstOrNull;
    if (ex == null) {
      throw ArgumentError.value(
        existingId,
        'existingId',
        '今回の入力に無い既存の受付ではありません',
      );
    }
    final added = plan.addedReceptions[ir];
    final dc = _diffReception(ex, added.doc, added.inputIndex, mode);
    return _copy(
      plan,
      addedReceptions: [...plan.addedReceptions]..removeAt(ir),
      changedReceptions: dc.changes.isEmpty
          ? plan.changedReceptions
          : _inBaseOrder(
              [...plan.changedReceptions, dc],
              base.receptions,
              (d) => d.existing.id,
              (r) => r.id,
            ),
      unchangedReceptions: dc.changes.isEmpty
          ? _inBaseOrder(
              [...plan.unchangedReceptions, ex],
              base.receptions,
              (r) => r.id,
              (r) => r.id,
            )
          : plan.unchangedReceptions,
      existingOnlyReceptions: [
        for (final r in plan.existingOnlyReceptions)
          if (r.id != existingId) r,
      ],
    );
  }
  throw ArgumentError.value(addedKey, 'addedKey', '追加の公演・受付のキーではありません');
}

/// ユーザーが外した行（[unselectedKeys]）を除いた計画を返す。
/// 項目がすべて外れた変更は `unchanged*` に移る。出演者の追加を外したら、
/// mergedLive の出演者も既存のままになる（追加する公演・受付の出演者は、
/// 反映時に mergedLive から付ける）。知らないキーは無視する
LiveMergePlan withoutUnselected(
  LiveMergePlan plan,
  Set<String> unselectedKeys,
) {
  if (unselectedKeys.isEmpty) return plan;
  bool keep(String key) => !unselectedKeys.contains(key);
  final base = plan.base;

  final liveChanges = [
    for (final c in plan.liveChanges)
      if (keep(c.key)) c,
  ];

  final changedP = <DocChange<Performance>>[];
  final unchangedP = [...plan.unchangedPerformances];
  for (final d in plan.changedPerformances) {
    final cs = [
      for (final c in d.changes)
        if (keep(c.key)) c,
    ];
    if (cs.isEmpty) {
      unchangedP.add(d.existing);
    } else {
      changedP.add(
        cs.length == d.changes.length
            ? d
            : DocChange(
                existing: d.existing,
                merged: performanceWithChanges(d.existing, cs),
                changes: cs,
                inputIndex: d.inputIndex,
              ),
      );
    }
  }

  final changedR = <DocChange<Reception>>[];
  final unchangedR = [...plan.unchangedReceptions];
  for (final d in plan.changedReceptions) {
    final cs = [
      for (final c in d.changes)
        if (keep(c.key)) c,
    ];
    if (cs.isEmpty) {
      unchangedR.add(d.existing);
    } else {
      changedR.add(
        cs.length == d.changes.length
            ? d
            : DocChange(
                existing: d.existing,
                merged: receptionWithChanges(d.existing, cs),
                changes: cs,
                inputIndex: d.inputIndex,
              ),
      );
    }
  }

  return _copy(
    plan,
    mergedLive: liveWithChanges(base.live, liveChanges),
    liveChanges: liveChanges,
    addedPerformances: [
      for (final a in plan.addedPerformances)
        if (keep(a.key)) a,
    ],
    changedPerformances: changedP,
    unchangedPerformances: _inBaseOrder(
      unchangedP,
      base.performances,
      (p) => p.id,
      (p) => p.id,
    ),
    addedReceptions: [
      for (final a in plan.addedReceptions)
        if (keep(a.key)) a,
    ],
    changedReceptions: changedR,
    unchangedReceptions: _inBaseOrder(
      unchangedR,
      base.receptions,
      (r) => r.id,
      (r) => r.id,
    ),
  );
}

LiveMergePlan _copy(
  LiveMergePlan p, {
  Live? mergedLive,
  List<FieldChange>? liveChanges,
  List<AddedDoc<Performance>>? addedPerformances,
  List<DocChange<Performance>>? changedPerformances,
  List<Performance>? unchangedPerformances,
  List<Performance>? existingOnlyPerformances,
  List<AddedDoc<Reception>>? addedReceptions,
  List<DocChange<Reception>>? changedReceptions,
  List<Reception>? unchangedReceptions,
  List<Reception>? existingOnlyReceptions,
}) => LiveMergePlan(
  base: p.base,
  mergedLive: mergedLive ?? p.mergedLive,
  liveChanges: liveChanges ?? p.liveChanges,
  addedPerformances: addedPerformances ?? p.addedPerformances,
  changedPerformances: changedPerformances ?? p.changedPerformances,
  unchangedPerformances: unchangedPerformances ?? p.unchangedPerformances,
  existingOnlyPerformances:
      existingOnlyPerformances ?? p.existingOnlyPerformances,
  addedReceptions: addedReceptions ?? p.addedReceptions,
  changedReceptions: changedReceptions ?? p.changedReceptions,
  unchangedReceptions: unchangedReceptions ?? p.unchangedReceptions,
  existingOnlyReceptions: existingOnlyReceptions ?? p.existingOnlyReceptions,
  editing: p.editing,
  ignoredPerformerRemovals: p.ignoredPerformerRemovals,
);

// ---------------------------------------------------------------------------
// ライブ詳細の「変更あり」と変更履歴
// ---------------------------------------------------------------------------

/// 「変更あり」の印を付ける期間（計画書 3.6）
const Duration recentChangeWindow = Duration(days: 7);

/// ライブと同じバッチで作られたとみなす createdAt の差。本物の Firestore では
/// 同じバッチのサーバー時刻は同じだが、fake_cloud_firestore では項目ごとに
/// わずかにずれるため、1秒以内の差は「同じバッチ」とみなす
const Duration sameBatchTolerance = Duration(seconds: 1);

/// ライブ詳細に出す変更を、新しい順に並べる（日時が未確定のものは先頭。
/// 同じ日時はパス → 履歴 ID の順）。
///
/// - [history] の各履歴 → [FieldEdited]
/// - [stamps] のうち、公演・受付で createdAt がライブ本体の createdAt より後の
///   もの（[sameBatchTolerance] より後）→ [DocAdded]（既存のライブに後から
///   追加されたもの）。ライブと同じバッチで作られたもの（createdAt が同じ）や、
///   createdAt が欠けているもの、
///   ライブ本体の stamp が無いときは含めない
List<LiveChange> buildLiveChanges({
  required List<DocStamp> stamps,
  required List<HistoryEntry> history,
}) {
  final liveCreatedAt = stamps
      .where((s) => s.target.collection == HistoryCollection.lives)
      .firstOrNull
      ?.createdAt;
  final changes = <LiveChange>[
    for (final h in history) FieldEdited(h),
    if (liveCreatedAt != null)
      for (final s in stamps)
        if (s.target.collection != HistoryCollection.lives &&
            s.createdAt != null &&
            s.createdAt!.isAfter(liveCreatedAt.add(sameBatchTolerance)))
          DocAdded(target: s.target, at: s.createdAt),
  ];
  return changes..sort(_newestFirst);
}

int _newestFirst(LiveChange a, LiveChange b) {
  final at = a.at, bt = b.at;
  if (at == null && bt != null) return -1;
  if (at != null && bt == null) return 1;
  if (at != null && bt != null) {
    final c = bt.compareTo(at);
    if (c != 0) return c;
  }
  final p = a.target.path.compareTo(b.target.path);
  if (p != 0) return p;
  return _idOf(a).compareTo(_idOf(b));
}

String _idOf(LiveChange c) => switch (c) {
  FieldEdited(:final entry) => entry.id,
  DocAdded() => '',
};

/// [changes] のうち、[now] から [recentChangeWindow] 以内のもの（新しい順）。
/// 日時が未確定（null）のものは「今」とみなして含める。ちょうど7日前は含める
List<LiveChange> recentChanges(List<LiveChange> changes, DateTime now) {
  final since = now.subtract(recentChangeWindow);
  return [
    for (final c in changes)
      if (c.at == null || !c.at!.isBefore(since)) c,
  ]..sort(_newestFirst);
}

/// 「変更あり」の印を付けるドキュメントと、その直近の変更
/// （[recentChanges] の結果から作る。ui は印と1行の説明に使う）
Map<HistoryTarget, LiveChange> latestRecentChangeByTarget(
  List<LiveChange> changes,
  DateTime now,
) {
  final out = <HistoryTarget, LiveChange>{};
  for (final c in recentChanges(changes, now)) {
    out.putIfAbsent(c.target, () => c);
  }
  return out;
}

// ---------------------------------------------------------------------------
// 表示（項目名の日本語・値の形）
// ---------------------------------------------------------------------------

const Map<HistoryCollection, Map<String, String>> _fieldLabels = {
  HistoryCollection.lives: {
    'title': 'ライブ名',
    'officialUrl': '公式 URL',
    'groupIds': '出演グループ',
    'oshiIds': '個人の出演者',
  },
  HistoryCollection.performances: {
    'startAt': '開演日時',
    'openAt': '開場日時',
    'venue': '会場名',
    'prefecture': '都道府県',
  },
  HistoryCollection.receptions: {
    'type': '受付種別',
    'name': '受付名',
    'applyStartAt': '申込開始',
    'applyEndAt': '申込期限',
    'resultAt': '当落発表',
    'paymentDeadline': '入金期限',
    'prices': '料金',
    'winnersOnly': '当選者のみの受付',
  },
};

const Map<String, String> _receptionTypeLabels = {
  'fc': 'FC先行',
  'general': '一般',
  'upgrade': 'アプグレ',
  'other': 'その他',
};

/// 項目名の日本語ラベル（例: `applyEndAt` → 「申込期限」）。知らない項目は
/// そのまま返す
String historyFieldLabel(HistoryCollection collection, String field) =>
    _fieldLabels[collection]?[field] ?? field;

/// 値を画面に出す形にする（日時は「2026/11/20(金) 23:59」、料金は
/// 「S席 9,800円、A席 7,800円」、受付種別は「FC先行」など、
/// 真偽値は「はい／いいえ」）。
///
/// - [present] が false（項目が無い）・null・空の配列・空文字なら「（なし）」
/// - 出演者（groupIds・oshiIds）は [nameOf] で ID を名前にする（無ければ ID）
String formatHistoryValue(
  String field,
  Object? value, {
  bool present = true,
  String Function(String id)? nameOf,
}) {
  if (!present || _isEmptyValue(value)) return '（なし）';
  if (_date(value) case final d?) return formatDateTime(d.toLocal());
  if (field == 'prices' && value is List) {
    return [
      for (final p in value)
        if (p is Map)
          '${p['seat'] ?? ''} ${p['amount'] is num ? formatYen((p['amount'] as num).toInt()) : '?'}円',
    ].join('、');
  }
  if (field == 'type' && value is String) {
    return _receptionTypeLabels[value] ?? value;
  }
  if (value is bool) return value ? 'はい' : 'いいえ';
  if (value is List) {
    return [for (final x in value) x is String ? (nameOf?.call(x) ?? x) : '$x']
        .join('、');
  }
  return '$value';
}

/// その履歴を「元に戻す」ことができるか。
///
/// 戻せないもの: 出演者（groupIds・oshiIds。ルールで減らせない）、
/// 知らない項目、変更前が無かった必須項目（戻すと項目が消えてルールに反する）
bool canRevert(HistoryEntry entry) {
  final field = entry.field;
  if (field == 'groupIds' || field == 'oshiIds') return false;
  if (!MergeFields.of(entry.target.collection).contains(field)) return false;
  if (!entry.hasBefore &&
      MergeFields.required[entry.target.collection]!.contains(field)) {
    return false;
  }
  return true;
}
