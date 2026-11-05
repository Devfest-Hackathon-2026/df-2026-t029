import '../../models/live.dart';
import '../../models/oshi.dart';

/// 名前の分からない出演者の表示
const unknownPerformerLabel = '（不明な出演者）';

/// 推しの一覧から、ライブの出演者名を引く（名前の表を1回だけ作る）
class PerformerNames {
  PerformerNames(List<OshiSummary> oshis)
    : _namesByKey = {for (final o in oshis) o.key: o.name};

  final Map<String, String> _namesByKey;

  /// [live] の出演者の名前（グループ → 個人の順）。見つからない ID が
  /// あれば、最後に [unknownPerformerLabel] を1つだけ入れる
  List<String> of(Live live) => _performerNames(live, _namesByKey);
}

/// [live] の出演者の名前（[PerformerNames.of] と同じ）
List<String> performerNamesOf(Live live, List<OshiSummary> oshis) =>
    PerformerNames(oshis).of(live);

/// 同じ推しは1回だけ出す。重複の判定は種別と ID で行う（名前ではない。
/// ソロ名義とグループ名が同じでも、両方出す）
List<String> _performerNames(Live live, Map<String, String> namesByKey) {
  final names = <String>[];
  final seenKeys = <String>{};
  var unknown = false;
  void add(OshiKind kind, String id) {
    final key = '${kind.name}/$id';
    if (!seenKeys.add(key)) return;
    final name = namesByKey[key];
    if (name == null) {
      unknown = true;
    } else {
      names.add(name);
    }
  }

  for (final id in live.groupIds) {
    add(OshiKind.group, id);
  }
  for (final id in live.oshiIds) {
    add(OshiKind.person, id);
  }
  if (unknown) names.add(unknownPerformerLabel);
  return names;
}
